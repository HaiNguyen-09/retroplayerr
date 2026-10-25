import Foundation
import UIKit

enum WheelSensitivity: String, CaseIterable, Equatable, Sendable {
    case deg60 = "60"
    case deg75 = "75"
    case deg45 = "45"

    var degreesPerStep: Double {
        switch self {
        case .deg60:
            return 60.0
        case .deg75:
            return 75.0
        case .deg45:
            return 45.0
        }
    }

    var displayName: String {
        switch self {
        case .deg60:
            return "Standard (60°)"
        case .deg75:
            return "Low (75°)"
        case .deg45:
            return "High (45°)"
        }
    }

    var shortLabel: String {
        switch self {
        case .deg60:
            return "60°"
        case .deg75:
            return "75°"
        case .deg45:
            return "45°"
        }
    }

    func next() -> WheelSensitivity {
        switch self {
        case .deg60:
            return .deg75
        case .deg75:
            return .deg45
        case .deg45:
            return .deg60
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
        return UIImage(data: previewArtworkData)
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
