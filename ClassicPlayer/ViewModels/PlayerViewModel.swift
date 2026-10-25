import Combine
import Foundation
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

    func reloadLibrary() async {
        let discovered = await MediaLibraryService.shared.scanDocumentsDirectory()
        self.allMedia = discovered
        buildMenuStackPreservingSelection()
    }

    // MARK: - Click Wheel Interactions

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
            menuStack.removeLast()
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
            playbackEngine.loadQueue(allMedia, startIndex: 0, autoPlay: true)
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

    // MARK: - Menu Tree Construction

    private func execute(action: MenuAction) {
        switch action {
        case .pushSubmenu(let title, let items):
            let page = MenuPage(title: title, rows: items, selectedIndex: 0)
            menuStack.append(page)

        case .playQueue(let items, let startIndex):
            guard items.indices.contains(startIndex) else { return }
            let selectedMedia = items[startIndex]
            playbackEngine.loadQueue(items, startIndex: startIndex, autoPlay: true)
            transitionToActivePlayerScreen(for: selectedMedia)

        case .shuffleAllAudio:
            let audioItems = allMedia.filter { $0.kind == .audio }.shuffled()
            let pool = audioItems.isEmpty ? allMedia.shuffled() : audioItems
            guard let first = pool.first else { return }
            playbackEngine.loadQueue(pool, startIndex: 0, autoPlay: true)
            transitionToActivePlayerScreen(for: first)

        case .openNowPlaying:
            guard let current = playbackEngine.currentItem else { return }
            transitionToActivePlayerScreen(for: current)

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

        // Refresh Settings page if currently open
        if menuStack.count == 2 && menuStack[1].title == "Settings" {
            let selected = menuStack[1].selectedIndex
            menuStack[1] = MenuPage(
                id: menuStack[1].id,
                title: "Settings",
                rows: makeSettingsRows(),
                selectedIndex: selected
            )
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
                action: .pushSubmenu(title: "Music", items: makeMusicMenuRows(audioItems: audioItems))
            ),
            MenuRowItem(
                id: "root_videos",
                title: "Videos",
                showsChevron: true,
                previewArtworkData: firstVideoArtwork,
                action: .pushSubmenu(title: "Videos", items: makeVideoMenuRows(videoItems: videoItems))
            ),
            MenuRowItem(
                id: "root_files",
                title: "Documents",
                showsChevron: true,
                previewArtworkData: firstAnyArtwork,
                action: .pushSubmenu(title: "Documents", items: makeMediaRows(for: allMedia, emptyLabel: "No Files in Documents"))
            ),
            MenuRowItem(
                id: "root_shuffle",
                title: "Shuffle Songs",
                showsChevron: false,
                previewArtworkData: firstAudioArtwork ?? firstAnyArtwork,
                action: .shuffleAllAudio
            ),
            MenuRowItem(
                id: "root_settings",
                title: "Settings",
                showsChevron: true,
                previewArtworkData: nil,
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
                action: .pushSubmenu(title: album, items: makeMediaRows(for: tracks, emptyLabel: "No Songs"))
            )
        }

        return [
            MenuRowItem(
                id: "music_all_songs",
                title: "All Songs",
                showsChevron: true,
                previewArtworkData: firstArt,
                action: .pushSubmenu(
                    title: "All Songs",
                    items: makeMediaRows(for: audioItems, emptyLabel: "Add Audio to Documents")
                )
            ),
            MenuRowItem(
                id: "music_artists",
                title: "Artists",
                showsChevron: true,
                previewArtworkData: firstArt,
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
                action: .pushSubmenu(
                    title: "Albums",
                    items: albumRows.isEmpty ? makeEmptyPlaceholderRows("No Albums Found") : albumRows
                )
            )
        ]
    }

    private func makeVideoMenuRows(videoItems: [MediaItem]) -> [MenuRowItem] {
        makeMediaRows(for: videoItems, emptyLabel: "Add .mp4/.mov to Documents")
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
                action: .playQueue(items: items, startIndex: index)
            )
        }
    }

    private func makeEmptyPlaceholderRows(_ message: String) -> [MenuRowItem] {
        [
            MenuRowItem(
                id: "empty_\(message)",
                title: message,
                showsChevron: false,
                previewArtworkData: nil,
                action: .rescanLibrary
            ),
            MenuRowItem(
                id: "rescan_prompt",
                title: "Rescan Documents",
                showsChevron: false,
                previewArtworkData: nil,
                action: .rescanLibrary
            )
        ]
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
                action: .rescanLibrary
            ),
            MenuRowItem(
                id: "about_songs",
                title: "Songs",
                valueText: "\(audioCount)",
                showsChevron: false,
                action: .rescanLibrary
            ),
            MenuRowItem(
                id: "about_videos",
                title: "Videos",
                valueText: "\(videoCount)",
                showsChevron: false,
                action: .rescanLibrary
            ),
            MenuRowItem(
                id: "about_storage",
                title: "Source",
                valueText: "Documents",
                showsChevron: false,
                action: .rescanLibrary
            ),
            MenuRowItem(
                id: "about_net",
                title: "Network",
                valueText: "Offline",
                showsChevron: false,
                action: .rescanLibrary
            )
        ]

        return [
            MenuRowItem(
                id: "settings_about",
                title: "About",
                showsChevron: true,
                action: .pushSubmenu(title: "About", items: aboutRows)
            ),
            MenuRowItem(
                id: "settings_clicker",
                title: "Clicker",
                valueText: isClickerEnabled ? "On" : "Off",
                showsChevron: false,
                action: .toggleClicker
            ),
            MenuRowItem(
                id: "settings_hold",
                title: "Hold Lock",
                valueText: isHoldLocked ? "Locked" : "Off",
                showsChevron: false,
                action: .toggleHoldLock
            ),
            MenuRowItem(
                id: "settings_rescan",
                title: "Rescan Documents",
                showsChevron: false,
                action: .rescanLibrary
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
        // On Simulator, UIDevice.current.batteryLevel is -1.0; default to 0.85 for realistic retro bar display
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

        // Ensure the Documents directory exists so it appears in the iOS Files app immediately
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
