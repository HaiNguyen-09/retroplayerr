import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DocumentImporterSheet: UIViewControllerRepresentable {
    let onPickURLs: ([URL]) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPickURLs: onPickURLs, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        var contentTypes: [UTType] = [
            .audio,
            .movie,
            .video,
            .mp3,
            .mpeg4Audio,
            .wav,
            .mpeg4Movie,
            .quickTimeMovie,
            .item
        ]
        if let flacType = UTType(filenameExtension: "flac") {
            contentTypes.append(flacType)
        }
        if let m4aType = UTType(filenameExtension: "m4a") {
            contentTypes.append(m4aType)
        }

        // Using asCopy: true ensures iOS materializes a local copy from Files/iCloud/Downloads
        // and immediately triggers the Open button callback when the user selects files.
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.shouldShowFileExtensions = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPickURLs: ([URL]) -> Void
        let onCancel: () -> Void

        init(onPickURLs: @escaping ([URL]) -> Void, onCancel: @escaping () -> Void) {
            self.onPickURLs = onPickURLs
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // Copy picked files into the permanent sandboxed Documents directory immediately
            // while the temporary picker URLs / security scopes are still active.
            let persistedURLs = Self.persistFilesToDocuments(urls)
            onPickURLs(persistedURLs)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }

        static func persistFilesToDocuments(_ pickedURLs: [URL]) -> [URL] {
            guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return []
            }

            let fileManager = FileManager.default
            try? fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)

            var savedURLs: [URL] = []

            for sourceURL in pickedURLs {
                let hasScope = sourceURL.startAccessingSecurityScopedResource()
                defer {
                    if hasScope {
                        sourceURL.stopAccessingSecurityScopedResource()
                    }
                }

                let fileName = sourceURL.lastPathComponent
                guard !fileName.isEmpty else { continue }

                let destinationURL = documentsURL.appendingPathComponent(fileName)

                // If the user picked a file that is already inside our sandboxed Documents directory, keep it directly
                if sourceURL.standardizedFileURL.path == destinationURL.standardizedFileURL.path {
                    savedURLs.append(destinationURL)
                    continue
                }

                // Replace any stale copy at the same filename so re-importing updates cleanly
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try? fileManager.removeItem(at: destinationURL)
                }

                var didCopy = false
                if (try? fileManager.copyItem(at: sourceURL, to: destinationURL)) != nil {
                    didCopy = true
                } else {
                    // Fallback with NSFileCoordinator for iCloud / external file provider URLs
                    let coordinator = NSFileCoordinator()
                    var coordError: NSError?
                    coordinator.coordinate(readingItemAt: sourceURL, options: .withoutChanges, error: &coordError) { coordinatedURL in
                        if (try? fileManager.copyItem(at: coordinatedURL, to: destinationURL)) != nil {
                            didCopy = true
                        } else if let data = try? Data(contentsOf: coordinatedURL) {
                            if (try? data.write(to: destinationURL, options: .atomic)) != nil {
                                didCopy = true
                            }
                        }
                    }
                }

                if didCopy {
                    // Ensure file is not excluded from backup / purge and remains permanently in Documents
                    var resourceValues = URLResourceValues()
                    resourceValues.isExcludedFromBackup = false
                    var mutableDest = destinationURL
                    try? mutableDest.setResourceValues(resourceValues)
                    savedURLs.append(destinationURL)
                }
            }

            return savedURLs
        }
    }
}
