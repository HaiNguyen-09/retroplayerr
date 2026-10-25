import Combine
import Foundation
import SwiftUI
import UIKit

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published private(set) var allMedia: [MediaItem] = []
    @Published var menuStack: [MenuPage] = []
    @Published var screenMode: ActiveScreenMode = .splitBrowser
    @Published var isHoldLocked: Bool = false
    @Published var isClickerEnabled: Bool = true
    @Published var batteryLevel: Float = 0.85
    @Published var isScrubbingInNowPlaying: Bool = false
    @Published var isPresentingDocumentPicker: Bool = false

    @AppStorage("wheelSensitivity") var wheelSensitivityRaw: String = WheelSensitivity.medium.rawValue {
        didSet {
            objectWillChange.send()
            buildMenuStackPreservingSelection()
        }
    }

    var wheelSensitivity: WheelSensitivity {
        get { WheelSensitivity(rawValue: wheelSensitivityRaw) ?? .medium }
        set { wheelSensitivityRaw = newValue.rawValue }
    }

    let playbackEngine = PlaybackEngine()
    private var cancellables = Set<AnyCancellable>()
    private var directoryMonitorSource: DispatchSourceFileSystemObject?
    private var directoryFileDescriptor: CInt = -1

    init() {
        setupBatteryMonitoring()
        bindPlaybackEngine()
        buildMenuStackPreservingSelection()
        startDocumentsDirectoryMonitor()

        Task {
            await reloadLibrary()
        }
    }

    var currentPage: MenuPage {
        menuStack.last ?? MenuPage(title: "Player", rows: [])
    }

    var statusBarTitle: String {
        "Player"
    }

    var previewImageForCurrentSelection: UIImage? {
        if let rowImage = currentPage.selectedRow?.previewImage {
            return rowImage
        }
        return playbackEngine.currentItem?.artworkImage
    }

    var previewTitleForCurrentSelection: String? {
        if let row = currentPage.selectedRow {
            return row.previewTitle ?? row.title
        }
        return playbackEngine.currentItem?.title
    }

    var previewSubtitleForCurrentSelection: String? {
        if let row = currentPage.selectedRow {
            return row.previewSubtitle ?? row.subtitle ?? row.valueText
        }
        return playbackEngine.currentItem?.artist
    }

    func reloadLibrary() async {
        let discovered = await MediaLibraryService.shared.scanDocumentsDirectory()
        self.allMedia = discovered
        buildMenuStackPreservingSelection()
    }

    func handleImportedDocuments(urls: [URL]) {
        isPresentingDocumentPicker = false
        guard !urls.isEmpty else { return }
        Task {
            await MediaLibraryService.shared.importFilesToDocuments(urls)
            await reloadLibrary()
        }
    }

    // MARK: - Click Wheel Interactions (Strictly Read-Only Navigation)

    func handleWheelStep(direction: Int) {
        guard !isHoldLocked, direction != 0 else { return }

        switch screenMode {
        case .splitBrowser:
            guard !menuStack.isEmpty else { return }
            let lastIdx = menuStack.count - 1
            let rowCount = menuStack[lastIdx].rows.count
            guard rowCount > 0 else { return }

            let currentSelection = menuStack[lastIdx].selectedIndex
            let nextSelection = min(max(0, currentSelection + (direction > 0 ? 1 : -1)), rowCount - 1)
            if nextSelection != currentSelection {
                menuStack[lastIdx].selectedIndex = nextSelection
                FeedbackManager.shared.triggerWheelTick()
            }

        case .audioNowPlaying, .videoFullCanvas:
            if isScrubbingInNowPlaying {
                let delta = Double(direction) * 5.0
                playbackEngine.seek(by: delta)
                FeedbackManager.shared.triggerWheelTick()
            } else {
                FeedbackManager.shared.triggerWheelTick()
            }
        }
    }

    func handleMenuButton() {
        guard !isHoldLocked else { return }
        FeedbackManager.shared.triggerButtonPress()

        if screenMode != .splitBrowser {
            isScrubbingInNowPlaying = false
            screenMode = .splitBrowser
            buildMenuStackPreservingSelection()
            return
        }

        if menuStack.count > 1 {
            withAnimation(.easeInOut(duration: 0.21)) {
                _ = menuStack.removeLast()
            }
        }
    }

    func handleCenterSelectButton() {
        guard !isHoldLocked else { return }
        FeedbackManager.shared.triggerButtonPress()

        switch screenMode {
        case .splitBrowser:
            guard let row = currentPage.selectedRow else { return }
            execute(action: row.action)

        case .audioNowPlaying, .videoFullCanvas:
            isScrubbingInNowPlaying.toggle()
        }
    }

    func handlePlayPauseButton() {
        guard !isHoldLocked else { return }
        FeedbackManager.shared.triggerButtonPress()

        if playbackEngine.currentItem == nil && !allMedia.isEmpty {
            let firstItem = allMedia[0]
            playbackEngine.playMedia(url: firstItem.url, inQueue: allMedia, startIndex: 0)
            transitionToActivePlayerScreen(for: firstItem)
        } else {
            playbackEngine.togglePlayPause()
        }
    }

    func handleNextButton() {
        guard !isHoldLocked else { return }
        FeedbackManager.shared.triggerButtonPress()
        playbackEngine.nextTrack()
        if let current = playbackEngine.currentItem, screenMode != .splitBrowser {
            transitionToActivePlayerScreen(for: current)
        }
    }

    func handlePreviousButton() {
        guard !isHoldLocked else { return }
        FeedbackManager.shared.triggerButtonPress()
        playbackEngine.previousTrack()
        if let current = playbackEngine.currentItem, screenMode != .splitBrowser {
            transitionToActivePlayerScreen(for: current)
        }
    }

    func toggleHoldSwitch() {
        isHoldLocked.toggle()
        FeedbackManager.shared.triggerButtonPress()
        buildMenuStackPreservingSelection()
    }

    // MARK: - Menu Tree Execution & Construction

    private func execute(action: MenuAction) {
        switch action {
        case .pushSubmenu(let title, let items):
            let page = MenuPage(title: title, rows: items, selectedIndex: 0)
            withAnimation(.easeInOut(duration: 0.21)) {
                menuStack.append(page)
            }

        case .playQueue(let items, let startIndex):
            guard items.indices.contains(startIndex) else { return }
            let selectedMedia = items[startIndex]
            playbackEngine.playMedia(url: selectedMedia.url, inQueue: items, startIndex: startIndex)
            transitionToActivePlayerScreen(for: selectedMedia)

        case .shuffleAllAudio:
            let audioItems = allMedia.filter { $0.kind == .audio }.shuffled()
            let pool = audioItems.isEmpty ? allMedia.shuffled() : audioItems
            guard let first = pool.first else { return }
            playbackEngine.playMedia(url: first.url, inQueue: pool, startIndex: 0)
            transitionToActivePlayerScreen(for: first)

        case .openNowPlaying:
            guard let current = playbackEngine.currentItem else { return }
            transitionToActivePlayerScreen(for: current)

        case .importFiles:
            isPresentingDocumentPicker = true

        case .cycleWheelSensitivity:
            wheelSensitivity = wheelSensitivity.next()
            buildMenuStackPreservingSelection()

        case .setWheelSensitivity(let newSensitivity):
            wheelSensitivity = newSensitivity
            buildMenuStackPreservingSelection()

        case .toggleClicker:
            isClickerEnabled.toggle()
            FeedbackManager.shared.isClickerEnabled = isClickerEnabled
            buildMenuStackPreservingSelection()

        case .toggleHoldLock:
            isHoldLocked.toggle()
            buildMenuStackPreservingSelection()

        case .rescanLibrary:
            Task {
                await reloadLibrary()
            }
        }
    }

    private func transitionToActivePlayerScreen(for item: MediaItem) {
        isScrubbingInNowPlaying = false
        switch item.kind {
        case .video:
            screenMode = .videoFullCanvas
        case .audio:
            screenMode = .audioNowPlaying
        }
    }

    private func buildMenuStackPreservingSelection() {
        let rootRows = makeRootRows()
        if menuStack.isEmpty {
            menuStack = [MenuPage(title: "Player", rows: rootRows, selectedIndex: 0)]
            return
        }

        let previousRootSelection = menuStack[0].selectedIndex
        menuStack[0] = MenuPage(
            id: menuStack[0].id,
            title: "Player",
            rows: rootRows,
            selectedIndex: previousRootSelection
        )

        // Refresh open submenus so imported files or updated Settings reflect immediately
        for idx in 1..<menuStack.count {
            let pageTitle = menuStack[idx].title
            let pageId = menuStack[idx].id
            let selected = menuStack[idx].selectedIndex
            let audioItems = allMedia.filter { $0.kind == .audio }
            let videoItems = allMedia.filter { $0.kind == .video }

            switch pageTitle {
            case "Settings":
                menuStack[idx] = MenuPage(id: pageId, title: pageTitle, rows: makeSettingsRows(), selectedIndex: selected)
            case "Sensitivity":
                menuStack[idx] = MenuPage(id: pageId, title: pageTitle, rows: makeSensitivitySubmenuRows(), selectedIndex: selected)
            case "Music":
                menuStack[idx] = MenuPage(id: pageId, title: pageTitle, rows: makeMusicMenuRows(audioItems: audioItems), selectedIndex: selected)
            case "All Songs":
                menuStack[idx] = MenuPage(id: pageId, title: pageTitle, rows: makeMediaRows(for: audioItems, emptyLabel: "No Audio Files"), selectedIndex: selected)
            case "Videos":
                menuStack[idx] = MenuPage(id: pageId, title: pageTitle, rows: makeVideoMenuRows(videoItems: videoItems), selectedIndex: selected)
            case "Documents":
                menuStack[idx] = MenuPage(id: pageId, title: pageTitle, rows: makeMediaRows(for: allMedia, emptyLabel: "No Files in Documents"), selectedIndex: selected)
            default:
                break
            }
        }
    }

    private func makeRootRows() -> [MenuRowItem] {
        let audioItems = allMedia.filter { $0.kind == .audio }
        let videoItems = allMedia.filter { $0.kind == .video }
        let firstAudioArtwork = audioItems.first(where: { $0.artworkData != nil })?.artworkData
        let firstVideoArtwork = videoItems.first(where: { $0.artworkData != nil })?.artworkData
        let firstAnyArtwork = allMedia.first(where: { $0.artworkData != nil })?.artworkData

        var rows: [MenuRowItem] = [
            MenuRowItem(
                id: "root_music",
                title: "Music",
                showsChevron: true,
                previewArtworkData: firstAudioArtwork,
                previewTitle: "Music",
                previewSubtitle: "\(audioItems.count) Songs",
                action: .pushSubmenu(title: "Music", items: makeMusicMenuRows(audioItems: audioItems))
            ),
            MenuRowItem(
                id: "root_videos",
                title: "Videos",
                showsChevron: true,
                previewArtworkData: firstVideoArtwork,
                previewTitle: "Videos",
                previewSubtitle: "\(videoItems.count) Videos",
                action: .pushSubmenu(title: "Videos", items: makeVideoMenuRows(videoItems: videoItems))
            ),
            MenuRowItem(
                id: "root_files",
                title: "Documents",
                showsChevron: true,
                previewArtworkData: firstAnyArtwork,
                previewTitle: "Documents",
                previewSubtitle: "\(allMedia.count) Local Files",
                action: .pushSubmenu(title: "Documents", items: makeMediaRows(for: allMedia, emptyLabel: "No Files in Documents"))
            ),
            MenuRowItem(
                id: "root_import",
                title: "Import Files",
                showsChevron: true,
                previewArtworkData: nil,
                previewTitle: "Import Files",
                previewSubtitle: "Add from iOS Files",
                action: .importFiles
            ),
            MenuRowItem(
                id: "root_shuffle",
                title: "Shuffle Songs",
                showsChevron: false,
                previewArtworkData: firstAudioArtwork ?? firstAnyArtwork,
                previewTitle: "Shuffle Songs",
                previewSubtitle: "\(audioItems.count) Tracks",
                action: .shuffleAllAudio
            ),
            MenuRowItem(
                id: "root_settings",
                title: "Settings",
                showsChevron: true,
                previewArtworkData: nil,
                previewTitle: "Settings",
                previewSubtitle: "Wheel: \(wheelSensitivity.displayName)",
                action: .pushSubmenu(title: "Settings", items: makeSettingsRows())
            )
        ]

        if let current = playbackEngine.currentItem {
            rows.append(
                MenuRowItem(
                    id: "root_now_playing",
                    title: "Now Playing",
                    showsChevron: true,
                    previewArtworkData: current.artworkData,
                    previewTitle: current.title,
                    previewSubtitle: current.artist,
                    action: .openNowPlaying
                )
            )
        }

        return rows
    }

    private func makeMusicMenuRows(audioItems: [MediaItem]) -> [MenuRowItem] {
        let firstArt = audioItems.first(where: { $0.artworkData != nil })?.artworkData

        // Group by Artist
        let groupedByArtist = Dictionary(grouping: audioItems, by: { $0.artist })
        let artistRows: [MenuRowItem] = groupedByArtist.keys.sorted().map { artist in
            let tracks = groupedByArtist[artist] ?? []
            let art = tracks.first(where: { $0.artworkData != nil })?.artworkData
            return MenuRowItem(
                id: "artist_\(artist)",
                title: artist,
                showsChevron: true,
                previewArtworkData: art,
                previewTitle: artist,
                previewSubtitle: "\(tracks.count) Songs",
                action: .pushSubmenu(title: artist, items: makeMediaRows(for: tracks, emptyLabel: "No Songs"))
            )
        }

        // Group by Album
        let groupedByAlbum = Dictionary(grouping: audioItems, by: { $0.album })
        let albumRows: [MenuRowItem] = groupedByAlbum.keys.sorted().map { album in
            let tracks = groupedByAlbum[album] ?? []
            let art = tracks.first(where: { $0.artworkData != nil })?.artworkData
            return MenuRowItem(
                id: "album_\(album)",
                title: album,
                showsChevron: true,
                previewArtworkData: art,
                previewTitle: album,
                previewSubtitle: "\(tracks.count) Songs",
                action: .pushSubmenu(title: album, items: makeMediaRows(for: tracks, emptyLabel: "No Songs"))
            )
        }

        return [
            MenuRowItem(
                id: "music_all_songs",
                title: "All Songs",
                showsChevron: true,
                previewArtworkData: firstArt,
                previewTitle: "All Songs",
                previewSubtitle: "\(audioItems.count) Songs",
                action: .pushSubmenu(
                    title: "All Songs",
                    items: makeMediaRows(for: audioItems, emptyLabel: "No Audio Files")
                )
            ),
            MenuRowItem(
                id: "music_artists",
                title: "Artists",
                showsChevron: true,
                previewArtworkData: firstArt,
                previewTitle: "Artists",
                previewSubtitle: "\(artistRows.count) Artists",
                action: .pushSubmenu(
                    title: "Artists",
                    items: artistRows.isEmpty ? makeEmptyPlaceholderRows("No Artists Found") : artistRows
                )
            ),
            MenuRowItem(
                id: "music_albums",
                title: "Albums",
                showsChevron: true,
                previewArtworkData: firstArt,
                previewTitle: "Albums",
                previewSubtitle: "\(albumRows.count) Albums",
                action: .pushSubmenu(
                    title: "Albums",
                    items: albumRows.isEmpty ? makeEmptyPlaceholderRows("No Albums Found") : albumRows
                )
            ),
            MenuRowItem(
                id: "music_import",
                title: "Import Files",
                showsChevron: true,
                previewArtworkData: nil,
                previewTitle: "Import Audio",
                previewSubtitle: ".mp3, .m4a, .wav, .flac",
                action: .importFiles
            )
        ]
    }

    private func makeVideoMenuRows(videoItems: [MediaItem]) -> [MenuRowItem] {
        var rows = makeMediaRows(for: videoItems, emptyLabel: "No Video Files")
        if !videoItems.isEmpty {
            rows.append(
                MenuRowItem(
                    id: "video_import",
                    title: "Import Files",
                    showsChevron: true,
                    previewArtworkData: nil,
                    previewTitle: "Import Videos",
                    previewSubtitle: ".mp4, .mov",
                    action: .importFiles
                )
            )
        }
        return rows
    }

    private func makeMediaRows(for items: [MediaItem], emptyLabel: String) -> [MenuRowItem] {
        guard !items.isEmpty else {
            return makeEmptyPlaceholderRows(emptyLabel)
        }

        return items.enumerated().map { index, item in
            MenuRowItem(
                id: item.id,
                title: item.title,
                subtitle: item.artist,
                showsChevron: true,
                previewArtworkData: item.artworkData,
                previewTitle: item.title,
                previewSubtitle: item.artist,
                action: .playQueue(items: items, startIndex: index)
            )
        }
    }

    private func makeEmptyPlaceholderRows(_ message: String) -> [MenuRowItem] {
        [
            MenuRowItem(
                id: "empty_import_\(message)",
                title: "Import Files",
                showsChevron: true,
                previewArtworkData: nil,
                previewTitle: message,
                previewSubtitle: "Select from Files app",
                action: .importFiles
            ),
            MenuRowItem(
                id: "rescan_prompt_\(message)",
                title: "Rescan Documents",
                showsChevron: false,
                previewArtworkData: nil,
                previewTitle: "Rescan Documents",
                previewSubtitle: "Refresh Sandbox",
                action: .rescanLibrary
            )
        ]
    }

    private func makeSensitivitySubmenuRows() -> [MenuRowItem] {
        WheelSensitivity.allCases.map { option in
            let isCurrent = (option == wheelSensitivity)
            return MenuRowItem(
                id: "sens_\(option.rawValue)",
                title: option.displayName,
                valueText: isCurrent ? "✓" : nil,
                showsChevron: false,
                previewTitle: "Wheel Sensitivity",
                previewSubtitle: option.displayName,
                action: .setWheelSensitivity(option)
            )
        }
    }

    private func makeSettingsRows() -> [MenuRowItem] {
        let audioCount = allMedia.filter { $0.kind == .audio }.count
        let videoCount = allMedia.filter { $0.kind == .video }.count

        let aboutRows: [MenuRowItem] = [
            MenuRowItem(
                id: "about_model",
                title: "ClassicPlayer",
                valueText: "1.0",
                showsChevron: false,
                previewTitle: "ClassicPlayer",
                previewSubtitle: "Version 1.0",
                action: .rescanLibrary
            ),
            MenuRowItem(
                id: "about_songs",
                title: "Songs",
                valueText: "\(audioCount)",
                showsChevron: false,
                previewTitle: "Songs",
                previewSubtitle: "\(audioCount) Audio Tracks",
                action: .rescanLibrary
            ),
            MenuRowItem(
                id: "about_videos",
                title: "Videos",
                valueText: "\(videoCount)",
                showsChevron: false,
                previewTitle: "Videos",
                previewSubtitle: "\(videoCount) Video Clips",
                action: .rescanLibrary
            ),
            MenuRowItem(
                id: "about_storage",
                title: "Source",
                valueText: "Documents",
                showsChevron: false,
                previewTitle: "Local Storage",
                previewSubtitle: "Sandbox Documents",
                action: .rescanLibrary
            ),
            MenuRowItem(
                id: "about_net",
                title: "Network",
                valueText: "Offline",
                showsChevron: false,
                previewTitle: "Zero Network",
                previewSubtitle: "100% Local Sandbox",
                action: .rescanLibrary
            )
        ]

        return [
            MenuRowItem(
                id: "settings_sensitivity",
                title: "Sensitivity",
                valueText: wheelSensitivity.shortLabel,
                showsChevron: false,
                previewTitle: "Wheel Sensitivity",
                previewSubtitle: wheelSensitivity.displayName,
                action: .cycleWheelSensitivity
            ),
            MenuRowItem(
                id: "settings_sensitivity_menu",
                title: "Sensitivity Preset",
                showsChevron: true,
                previewTitle: "Wheel Presets",
                previewSubtitle: "Low 36° / Med 28° / High 20°",
                action: .pushSubmenu(title: "Sensitivity", items: makeSensitivitySubmenuRows())
            ),
            MenuRowItem(
                id: "settings_clicker",
                title: "Clicker",
                valueText: isClickerEnabled ? "On" : "Off",
                showsChevron: false,
                previewTitle: "Wheel Clicker",
                previewSubtitle: isClickerEnabled ? "Sound 1104 Enabled" : "Muted",
                action: .toggleClicker
            ),
            MenuRowItem(
                id: "settings_hold",
                title: "Hold Lock",
                valueText: isHoldLocked ? "Locked" : "Off",
                showsChevron: false,
                previewTitle: "Hold Switch",
                previewSubtitle: isHoldLocked ? "Wheel Locked" : "Unlocked",
                action: .toggleHoldLock
            ),
            MenuRowItem(
                id: "settings_import",
                title: "Import Files",
                showsChevron: true,
                previewTitle: "Import Media",
                previewSubtitle: "From iOS Files App",
                action: .importFiles
            ),
            MenuRowItem(
                id: "settings_rescan",
                title: "Rescan Documents",
                showsChevron: false,
                previewTitle: "Rescan Library",
                previewSubtitle: "Documents & Subfolders",
                action: .rescanLibrary
            ),
            MenuRowItem(
                id: "settings_about",
                title: "About",
                showsChevron: true,
                previewTitle: "About Player",
                previewSubtitle: "\(audioCount) Songs, \(videoCount) Videos",
                action: .pushSubmenu(title: "About", items: aboutRows)
            )
        ]
    }

    // MARK: - Bindings & System Monitoring

    private func bindPlaybackEngine() {
        playbackEngine.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        playbackEngine.$currentItem
            .receive(on: RunLoop.main)
            .sink { [weak self] newItem in
                guard let self else { return }
                self.buildMenuStackPreservingSelection()
                if let newItem, self.screenMode != .splitBrowser {
                    self.transitionToActivePlayerScreen(for: newItem)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task {
                    await self.reloadLibrary()
                }
            }
            .store(in: &cancellables)
    }

    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        updateBatteryLevel()

        NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateBatteryLevel()
            }
            .store(in: &cancellables)
    }

    private func updateBatteryLevel() {
        let level = UIDevice.current.batteryLevel
        if level >= 0.0 && level <= 1.0 {
            batteryLevel = level
        } else {
            batteryLevel = 0.85
        }
    }

    private func startDocumentsDirectoryMonitor() {
        guard let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        try? FileManager.default.createDirectory(at: docsURL, withIntermediateDirectories: true)

        directoryFileDescriptor = open(docsURL.path, O_EVTONLY)
        guard directoryFileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: directoryFileDescriptor,
            eventMask: [.write, .rename, .delete, .extend],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.reloadLibrary()
            }
        }

        source.setCancelHandler { [fd = directoryFileDescriptor] in
            if fd >= 0 {
                close(fd)
            }
        }

        source.resume()
        directoryMonitorSource = source
    }
}
