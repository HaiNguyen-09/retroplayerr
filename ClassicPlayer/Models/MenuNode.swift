import Foundation
import UIKit

enum MenuAction: Equatable {
    case pushSubmenu(title: String, items: [MenuRowItem])
    case playQueue(items: [MediaItem], startIndex: Int)
    case shuffleAllAudio
    case openNowPlaying
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
    let action: MenuAction

    init(
        id: String = UUID().uuidString,
        title: String,
        subtitle: String? = nil,
        valueText: String? = nil,
        showsChevron: Bool = true,
        previewArtworkData: Data? = nil,
        action: MenuAction
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.valueText = valueText
        self.showsChevron = showsChevron
        self.previewArtworkData = previewArtworkData
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
