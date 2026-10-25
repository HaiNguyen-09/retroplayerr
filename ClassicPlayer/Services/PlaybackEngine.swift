import AVFoundation
import Combine
import MediaPlayer
import UIKit

enum PlaybackState: Equatable {
    case stopped
    case playing
    case paused
}

@MainActor
final class PlaybackEngine: ObservableObject {
    @Published private(set) var playbackState: PlaybackState = .stopped
    @Published private(set) var currentItem: MediaItem?
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var queue: [MediaItem] = []
    @Published private(set) var queueIndex: Int = 0
    @Published var repeatMode: RepeatMode = .off
    @Published private(set) var isShuffleEnabled: Bool = false

    let player = AVPlayer()

    private var originalQueue: [MediaItem] = []
    private var timeObserverToken: Any?
    private var endObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var isHoldingRemoteSeek: Bool = false
    private var remoteSeekTimer: Timer?

    init() {
        configureAudioSession()
        configurePlayer()
        configureRemoteCommands()
        observeAudioSessionInterruptions()
    }

    /// Configures AVAudioSession to .playback with .moviePlayback mode for uninterrupted lock-screen and background playback.
    func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true)
        } catch {
            // Non-fatal in simulator environments
        }
    }

    private func configurePlayer() {
        player.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        player.actionAtItemEnd = .none
        player.automaticallyWaitsToMinimizeStalling = false

        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let seconds = CMTimeGetSeconds(time)
                if seconds.isFinite && seconds >= 0 {
                    self.currentTime = seconds
                }
                if let itemDuration = self.player.currentItem?.duration {
                    let durSeconds = CMTimeGetSeconds(itemDuration)
                    if durSeconds.isFinite && durSeconds > 0 {
                        let didChangeDuration = abs(self.duration - durSeconds) > 0.1
                        self.duration = durSeconds
                        if didChangeDuration {
                            self.updateNowPlayingMetadata()
                        }
                    }
                }
            }
        }
    }

    /// Cycles Repeat Mode: Off -> Repeat Once -> Repeat Forever -> Off
    func cycleRepeatMode() {
        repeatMode = repeatMode.next()
    }

    /// Updates Shuffle mode and reorganizes the active playback queue without interrupting the current song.
    func setShuffleEnabled(_ enabled: Bool) {
        guard isShuffleEnabled != enabled else { return }
        isShuffleEnabled = enabled

        guard !originalQueue.isEmpty else { return }
        if enabled {
            if let current = currentItem {
                let others = originalQueue.filter { $0.id != current.id }.shuffled()
                queue = [current] + others
                queueIndex = 0
            } else {
                queue = originalQueue.shuffled()
                queueIndex = 0
            }
        } else {
            queue = originalQueue
            if let current = currentItem,
               let restoredIdx = originalQueue.firstIndex(where: { $0.id == current.id }) {
                queueIndex = restoredIdx
            } else {
                queueIndex = 0
            }
        }
    }

    /// Starts playback of the specified file URL, or continues seamlessly if the same track is already active.
    func playMedia(url: URL, inQueue items: [MediaItem], startIndex: Int) {
        guard !items.isEmpty else { return }
        let clampedIndex = min(max(0, startIndex), items.count - 1)
        let selectedItem = items[clampedIndex]
        self.originalQueue = items

        if isShuffleEnabled {
            let others = items.enumerated().compactMap { idx, element in
                idx == clampedIndex ? nil : element
            }.shuffled()
            self.queue = [selectedItem] + others
            self.queueIndex = 0
        } else {
            self.queue = items
            self.queueIndex = clampedIndex
        }

        // If the user selects the same track that is already loaded, continue playing without resetting to 0:00
        if let activeItem = currentItem,
           activeItem.url.standardizedFileURL == url.standardizedFileURL,
           player.currentItem != nil {
            if playbackState != .playing {
                play()
            } else {
                updateNowPlayingMetadata()
            }
            return
        }

        startPlayback(for: url, metadataItem: selectedItem, autoPlay: true)
    }

    func loadQueue(_ items: [MediaItem], startIndex: Int = 0, autoPlay: Bool = true) {
        guard !items.isEmpty else { return }
        let clampedIndex = min(max(0, startIndex), items.count - 1)
        let targetItem = items[clampedIndex]
        self.originalQueue = items

        if isShuffleEnabled {
            let others = items.enumerated().compactMap { idx, element in
                idx == clampedIndex ? nil : element
            }.shuffled()
            self.queue = [targetItem] + others
            self.queueIndex = 0
        } else {
            self.queue = items
            self.queueIndex = clampedIndex
        }

        startPlayback(for: targetItem.url, metadataItem: targetItem, autoPlay: autoPlay)
    }

    private func startPlayback(for url: URL, metadataItem: MediaItem?, autoPlay: Bool) {
        currentItem = metadataItem
        currentTime = 0
        duration = metadataItem?.duration ?? 0

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }

        configureAudioSession()
        UIApplication.shared.beginReceivingRemoteControlEvents()

        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: playerItem)

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.advanceAfterTrackEnd()
            }
        }

        if autoPlay {
            player.playImmediately(atRate: 1.0)
            playbackState = .playing
        } else {
            player.pause()
            playbackState = .paused
        }

        updateNowPlayingMetadata()
    }

    func togglePlayPause() {
        switch playbackState {
        case .playing:
            pause()
        case .paused:
            play()
        case .stopped:
            if queue.indices.contains(queueIndex) {
                let targetItem = queue[queueIndex]
                startPlayback(for: targetItem.url, metadataItem: targetItem, autoPlay: true)
            }
        }
    }

    func play() {
        guard currentItem != nil else { return }
        configureAudioSession()
        player.playImmediately(atRate: 1.0)
        playbackState = .playing
        updateNowPlayingMetadata()
    }

    func pause() {
        player.pause()
        playbackState = .paused
        updateNowPlayingMetadata()
    }

    func stop() {
        stopRemoteSeekTimer()
        player.pause()
        player.replaceCurrentItem(with: nil)
        playbackState = .stopped
        currentItem = nil
        currentTime = 0
        duration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func nextTrack() {
        guard !queue.isEmpty else { return }
        if queueIndex + 1 < queue.count {
            queueIndex += 1
            let item = queue[queueIndex]
            startPlayback(for: item.url, metadataItem: item, autoPlay: true)
        } else {
            queueIndex = 0
            let item = queue[0]
            startPlayback(for: item.url, metadataItem: item, autoPlay: true)
        }
    }

    func previousTrack() {
        guard !queue.isEmpty else { return }
        if currentTime > 3.0 {
            seek(to: 0)
        } else if queueIndex > 0 {
            queueIndex -= 1
            let item = queue[queueIndex]
            startPlayback(for: item.url, metadataItem: item, autoPlay: playbackState == .playing)
        } else {
            seek(to: 0)
        }
    }

    func seek(by deltaSeconds: TimeInterval) {
        let effectiveDuration = resolvedDuration()
        let target = min(max(0, currentTime + deltaSeconds), max(effectiveDuration, 0))
        seek(to: target)
    }

    func seek(to seconds: TimeInterval) {
        let effectiveDuration = resolvedDuration()
        let clamped = effectiveDuration > 0 ? min(max(0, seconds), effectiveDuration) : max(0, seconds)
        let cmTime = CMTime(seconds: clamped, preferredTimescale: 600)
        currentTime = clamped
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateNowPlayingMetadata()
            }
        }
        updateNowPlayingMetadata()
    }

    private func resolvedDuration() -> TimeInterval {
        if duration > 0 {
            return duration
        }
        if let itemDur = player.currentItem?.duration {
            let secs = CMTimeGetSeconds(itemDur)
            if secs.isFinite && secs > 0 {
                return secs
            }
        }
        return currentItem?.duration ?? 0
    }

    private func advanceAfterTrackEnd() {
        guard !queue.isEmpty else {
            stop()
            return
        }

        switch repeatMode {
        case .once:
            // Repeat the current song 1 time, then reset repeatMode to .off
            repeatMode = .off
            seek(to: 0)
            play()

        case .forever:
            // Repeat the current song forever
            seek(to: 0)
            play()

        case .off:
            if queueIndex + 1 < queue.count {
                queueIndex += 1
                let item = queue[queueIndex]
                startPlayback(for: item.url, metadataItem: item, autoPlay: true)
            } else {
                player.pause()
                seek(to: 0)
                playbackState = .paused
                updateNowPlayingMetadata()
            }
        }
    }

    private func configureRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Ensure skip interval buttons are disabled so iOS Lock Screen / Control Center shows Next/Previous track buttons
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in self.play() }
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in self.pause() }
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in self.togglePlayPause() }
            return .success
        }

        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in self.nextTrack() }
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in self.previousTrack() }
            return .success
        }

        // Enable scrubbing / moving the slider in iOS Lock Screen & Control Center media player
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                self.seek(to: positionEvent.positionTime)
            }
            return .success
        }

        // Enable press-and-hold fast-forward / rewind on iOS Lock Screen / Control Center buttons
        commandCenter.seekForwardCommand.isEnabled = true
        commandCenter.seekForwardCommand.addTarget { [weak self] event in
            guard let self, let seekEvent = event as? MPSeekCommandEvent else { return .commandFailed }
            Task { @MainActor in
                if seekEvent.type == .beginSeeking {
                    self.startRemoteSeekTimer(deltaSeconds: 5.0)
                } else {
                    self.stopRemoteSeekTimer()
                }
            }
            return .success
        }

        commandCenter.seekBackwardCommand.isEnabled = true
        commandCenter.seekBackwardCommand.addTarget { [weak self] event in
            guard let self, let seekEvent = event as? MPSeekCommandEvent else { return .commandFailed }
            Task { @MainActor in
                if seekEvent.type == .beginSeeking {
                    self.startRemoteSeekTimer(deltaSeconds: -5.0)
                } else {
                    self.stopRemoteSeekTimer()
                }
            }
            return .success
        }
    }

    private func startRemoteSeekTimer(deltaSeconds: TimeInterval) {
        stopRemoteSeekTimer()
        seek(by: deltaSeconds)
        remoteSeekTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.seek(by: deltaSeconds)
            }
        }
    }

    private func stopRemoteSeekTimer() {
        remoteSeekTimer?.invalidate()
        remoteSeekTimer = nil
    }

    private func observeAudioSessionInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            guard
                let userInfo = notification.userInfo,
                let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                let type = AVAudioSession.InterruptionType(rawValue: typeValue)
            else { return }

            let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch type {
                case .began:
                    self.pause()
                case .ended:
                    if let optionsValue {
                        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                        if options.contains(.shouldResume) {
                            self.play()
                        }
                    }
                @unknown default:
                    break
                }
            }
        }
    }

    private func updateNowPlayingMetadata() {
        guard let item = currentItem else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        let effectiveDuration = resolvedDuration()
        let actualElapsed: TimeInterval
        if let playerItem = player.currentItem {
            let secs = CMTimeGetSeconds(playerItem.currentTime())
            actualElapsed = (secs.isFinite && secs >= 0) ? secs : currentTime
        } else {
            actualElapsed = currentTime
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: item.title,
            MPMediaItemPropertyArtist: item.artist,
            MPMediaItemPropertyPlaybackDuration: effectiveDuration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: actualElapsed,
            MPNowPlayingInfoPropertyPlaybackRate: playbackState == .playing ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0
        ]

        if let image = item.artworkImage {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
