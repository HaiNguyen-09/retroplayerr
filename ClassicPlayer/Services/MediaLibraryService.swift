import AVFoundation
import Foundation
import UIKit

actor MediaLibraryService {
    static let shared = MediaLibraryService()

    private let supportedExtensions: Set<String> = ["mp3", "m4a", "wav", "flac", "mp4", "mov"]

    /// Scans the app's sandboxed Documents directory and all of its subfolders for supported local audio and video files.
    func scanDocumentsDirectory() async -> [MediaItem] {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return []
        }

        try? FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)

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

    /// Copies user-selected media files (or folders of media files) from UIDocumentPickerViewController into the sandboxed Documents directory.
    @discardableResult
    func importFilesToDocuments(_ pickedURLs: [URL]) async -> Int {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return 0
        }

        try? FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        let fileManager = FileManager.default
        var importedCount = 0

        for externalURL in pickedURLs {
            let hasScope = externalURL.startAccessingSecurityScopedResource()
            defer {
                if hasScope {
                    externalURL.stopAccessingSecurityScopedResource()
                }
            }

            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: externalURL.path, isDirectory: &isDir) else {
                continue
            }

            if isDir.boolValue {
                let nestedMediaURLs = discoverMediaURLs(in: externalURL)
                for mediaURL in nestedMediaURLs {
                    if copyMediaFileIfNeeded(from: mediaURL, toDirectory: documentsURL) {
                        importedCount += 1
                    }
                }
            } else {
                let ext = externalURL.pathExtension.lowercased()
                if supportedExtensions.contains(ext) {
                    if copyMediaFileIfNeeded(from: externalURL, toDirectory: documentsURL) {
                        importedCount += 1
                    }
                }
            }
        }

        return importedCount
    }

    private func copyMediaFileIfNeeded(from sourceURL: URL, toDirectory documentsURL: URL) -> Bool {
        let fileManager = FileManager.default
        let standardizedSource = sourceURL.standardizedFileURL
        let standardizedDocs = documentsURL.standardizedFileURL

        // If the file is already inside the sandboxed Documents folder or one of its subfolders, no copy needed
        if standardizedSource.path.hasPrefix(standardizedDocs.path) {
            return true
        }

        let destinationURL = documentsURL.appendingPathComponent(sourceURL.lastPathComponent)
        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }

        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            return true
        } catch {
            return false
        }
    }

    /// Recursively enumerates `rootURL` and all nested subfolders for supported audio/video files.
    private func discoverMediaURLs(in rootURL: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .nameKey]
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL.resolvingSymlinksInPath(),
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var results: [URL] = []
        for case let rawURL as URL in enumerator {
            let fileURL = rawURL.resolvingSymlinksInPath()
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue else {
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
        var album = kind == .video ? "Videos" : "Documents"
        var durationSeconds: TimeInterval = 0
        var artworkData: Data?

        // Show subfolder name as Album if located in a subfolder of Documents
        if let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let parentName = url.deletingLastPathComponent().lastPathComponent
            if parentName != docsURL.lastPathComponent && !parentName.isEmpty {
                album = parentName
            }
        }

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
            id: url.standardizedFileURL.path,
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
