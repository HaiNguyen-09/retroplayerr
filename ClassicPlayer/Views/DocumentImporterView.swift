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
            .mp3,
            .mpeg4Audio,
            .wav,
            .mpeg4Movie,
            .quickTimeMovie,
            .audio,
            .movie,
            .folder
        ]
        if let flacType = UTType(filenameExtension: "flac") {
            contentTypes.append(flacType)
        }
        if let m4aType = UTType(filenameExtension: "m4a") {
            contentTypes.append(m4aType)
        }

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: false)
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
            onPickURLs(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}
