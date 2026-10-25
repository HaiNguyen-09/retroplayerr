import AVFoundation
import Foundation
import UIKit

actor MediaLibraryService {
    static let shared = MediaLibraryService()

    private let supportedExtensions: Set<String> = [
        "mp3", "m4a", "wav", "flac", "aac", "aiff", "aif", "caf",
        "mp4", "mov", "m4v"
    ]

    /// Scans the app's sandboxed Documents directory and all of its subfolders for supported local audio and video files.
    func scanDocumentsDirectory() async -> [MediaItem] {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }

        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)

        // If any files were shared via "Open In" into Documents/Inbox, move them into Documents permanently
        let inboxURL = documentsURL.appendingPathComponent("Inbox", isDirectory: true)
        if let inboxFiles = try? fileManager.contentsOfDirectory(at: inboxURL, includingPropertiesForKeys: nil) {
            for inboxFile in inboxFiles {
                let dest = documentsURL.appendingPathComponent(inboxFile.lastPathComponent)
                if fileManager.fileExists(atPath: dest.path) {
                    try? fileManager.removeItem(at: dest)
                }
                try? fileManager.moveItem(at: inboxFile, to: dest)
            }
        }

        let fileURLs = discoverMediaURLs(in: documentsURL)
        var items: [MediaItem] = []
        items.reserveCapacity(fileURLs.count)

        for url in fileURLs {
            if let item = await extractMediaItem(from: url) {
                items.append(item)
            }
        }

        return items.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    /// Recursively enumerates `rootURL` and all nested subfolders for supported audio/video files.
    private func discoverMediaURLs(in rootURL: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .nameKey]
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var results: [URL] = []
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
               values.isDirectory == true {
                continue
            }

            let ext = fileURL.pathExtension.lowercased()
            if supportedExtensions.contains(ext) {
                results.append(fileURL)
            }
        }
        return results
    }

    private func extractMediaItem(from url: URL) async -> MediaItem? {
        guard let kind = MediaKind.from(fileExtension: url.pathExtension) else {
            return nil
        }

        let fallbackTitle = url.deletingPathExtension().lastPathComponent
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: false])

        var title = fallbackTitle
        var artist = kind == .video ? "Video Clip" : "Unknown Artist"
        var album = kind == .video ? "Videos" : "Unknown Album"
        var durationSeconds: TimeInterval = 0
        var artworkData: Data?

        if let cmDuration = try? await asset.load(.duration) {
            let seconds = CMTimeGetSeconds(cmDuration)
            if seconds.isFinite && seconds > 0 {
                durationSeconds = seconds
            }
        }

        if let metadata = try? await asset.load(.commonMetadata) {
            for item in metadata {
                guard let commonKey = item.commonKey else { continue }
                switch commonKey {
                case .commonKeyTitle:
                    if let val = try? await item.load(.stringValue),
                       !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        title = val
                    }
                case .commonKeyArtist, .commonKeyCreator, .commonKeyAuthor:
                    if let val = try? await item.load(.stringValue),
                       !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        artist = val
                    }
                case .commonKeyAlbumName:
                    if let val = try? await item.load(.stringValue),
                       !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        album = val
                    }
                case .commonKeyArtwork:
                    if let data = try? await item.load(.dataValue), !data.isEmpty {
                        artworkData = data
                    }
                default:
                    break
                }
            }
        }

        if artworkData == nil && kind == .video {
            artworkData = await generateVideoThumbnailData(for: asset, duration: durationSeconds)
        }

        return MediaItem(
            id: url.lastPathComponent + "_" + url.deletingLastPathComponent().lastPathComponent,
            url: url,
            kind: kind,
            title: title,
            artist: artist,
            album: album,
            duration: durationSeconds,
            artworkData: artworkData
        )
    }

    private func generateVideoThumbnailData(for asset: AVAsset, duration: TimeInterval) async -> Data? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)

        let sampleSecond = min(max(0.5, duration * 0.1), max(0.0, duration - 0.1))
        let time = CMTime(seconds: sampleSecond, preferredTimescale: 600)

        do {
            let (cgImage, _) = try await generator.image(at: time)
            let uiImage = UIImage(cgImage: cgImage)
            return uiImage.jpegData(compressionQuality: 0.82)
        } catch {
            return nil
        }
    }
}
