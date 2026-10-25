import Foundation
import UIKit

enum WheelSensitivity: String, CaseIterable, Equatable, Sendable {
    case low = "low"
    case medium = "medium"
    case high = "high"

    var degreesPerStep: Double {
        switch self {
        case .low:
            return 36.0
        case .medium:
            return 28.0
        case .high:
            return 20.0
        }
    }

    var displayName: String {
        switch self {
        case .low:
            return "Low (36°)"
        case .medium:
            return "Medium (28°)"
        case .high:
            return "High (20°)"
        }
    }

    var shortLabel: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }

    func next() -> WheelSensitivity {
        switch self {
        case .low:
            return .medium
        case .medium:
            return .high
        case .high:
            return .low
        }
    }
}

enum MenuAction: Equatable {
    case pushSubmenu(title: String, items: [MenuRowItem])
    case playQueue(items: [MediaItem], startIndex: Int)
    case shuffleAllAudio
    case openNowPlaying
    case importFiles
    case cycleWheelSensitivity
    case setWheelSensitivity(WheelSensitivity)
    case toggleClicker
    case toggleHoldLock
    case rescanLibrary
}

struct MenuRowItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String?
    let valueText: String?
    let showsChevron: Bool
    let previewArtworkData: Data?
    let previewTitle: String?
    let previewSubtitle: String?
    let action: MenuAction

    init(
        id: String = UUID().uuidString,
        title: String,
        subtitle: String? = nil,
        valueText: String? = nil,
        showsChevron: Bool = true,
        previewArtworkData: Data? = nil,
        previewTitle: String? = nil,
        previewSubtitle: String? = nil,
        action: MenuAction
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.valueText = valueText
        self.showsChevron = showsChevron
        self.previewArtworkData = previewArtworkData
        self.previewTitle = previewTitle
        self.previewSubtitle = previewSubtitle
        self.action = action
    }

    var previewImage: UIImage? {
        guard let previewArtworkData else { return nil }
        return UIImage(data: artworkDataOrNil(previewArtworkData))
    }

    private func artworkDataOrNil(_ data: Data) -> Data {
        data
    }
}

struct MenuPage: Identifiable, Equatable {
    let id: String
    let title: String
    var rows: [MenuRowItem]
    var selectedIndex: Int

    init(id: String = UUID().uuidString, title: String, rows: [MenuRowItem], selectedIndex: Int = 0) {
        self.id = id
        self.title = title
        self.rows = rows
        self.selectedIndex = rows.isEmpty ? 0 : min(max(0, selectedIndex), rows.count - 1)
    }

    var selectedRow: MenuRowItem? {
        guard rows.indices.contains(selectedIndex) else { return nil }
        return rows[selectedIndex]
    }
}

enum ActiveScreenMode: Equatable {
    case splitBrowser
    case audioNowPlaying
    case videoFullCanvas
}
