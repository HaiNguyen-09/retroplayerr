import UIKit

enum MediaKind: String, Sendable {
    case audio
    case video

    static func from(fileExtension: String) -> MediaKind? {
        switch fileExtension.lowercased() {
        case "mp3", "m4a", "wav", "flac", "aac", "aiff", "aif", "caf":
            return .audio
        case "mp4", "mov", "m4v":
            return .video
        default:
            return nil
        }
    }
}

struct MediaItem: Identifiable, Equatable, Sendable {
    let id: String
    let url: URL
    let kind: MediaKind
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let artworkData: Data?

    var artworkImage: UIImage? {
        guard let artworkData else { return nil }
        return UIImage(data: artworkData)
    }

    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
        lhs.id == rhs.id && lhs.url == rhs.url
    }
}
