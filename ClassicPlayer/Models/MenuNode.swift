import Foundation
import SwiftUI
import UIKit

enum ChassisTheme: String, CaseIterable, Equatable, Sendable {
    case light = "light"
    case gray = "gray"
    case darkGray = "darkGray"

    var displayName: String {
        switch self {
        case .light:
            return "Light"
        case .gray:
            return "Gray"
        case .darkGray:
            return "Dark Gray"
        }
    }

    func next() -> ChassisTheme {
        switch self {
        case .light:
            return .gray
        case .gray:
            return .darkGray
        case .darkGray:
            return .light
        }
    }

    var faceplateGradientColors: [Color] {
        switch self {
        case .light:
            return [Color(hex: 0xECEEF2), Color(hex: 0xDCDEE4), Color(hex: 0xC8CBD2)]
        case .gray:
            return [Color(hex: 0xA8ADB7), Color(hex: 0x8F949F), Color(hex: 0x767B86)]
        case .darkGray:
            return [Color(hex: 0x484B54), Color(hex: 0x33363E), Color(hex: 0x22242A)]
        }
    }

    var chassisBorderGradientColors: [Color] {
        switch self {
        case .light:
            return [Color.white.opacity(0.75), Color(hex: 0x9CA1AA).opacity(0.55)]
        case .gray:
            return [Color.white.opacity(0.45), Color(hex: 0x52565F).opacity(0.65)]
        case .darkGray:
            return [Color.white.opacity(0.22), Color(hex: 0x111215).opacity(0.80)]
        }
    }

    var wheelRingStops: [Gradient.Stop] {
        switch self {
        case .light:
            return [
                .init(color: Color(hex: 0xF7F7F7), location: 0.35),
                .init(color: Color(hex: 0xF2F2F2), location: 0.82),
                .init(color: Color(hex: 0xE2E3E6), location: 1.0)
            ]
        case .gray:
            return [
                .init(color: Color(hex: 0x43464E), location: 0.35),
                .init(color: Color(hex: 0x363940), location: 0.82),
                .init(color: Color(hex: 0x282A30), location: 1.0)
            ]
        case .darkGray:
            return [
                .init(color: Color(hex: 0x26282E), location: 0.35),
                .init(color: Color(hex: 0x1C1E22), location: 0.82),
                .init(color: Color(hex: 0x131417), location: 1.0)
            ]
        }
    }

    var wheelOuterStrokeColors: [Color] {
        switch self {
        case .light:
            return [Color(hex: 0xD0D2D6), Color(hex: 0xB8BBC2)]
        case .gray:
            return [Color(hex: 0x555963), Color(hex: 0x24262B)]
        case .darkGray:
            return [Color(hex: 0x383B43), Color(hex: 0x101114)]
        }
    }

    var centerButtonGradientColors: [Color] {
        switch self {
        case .light:
            return [Color(hex: 0xC9CDD4), Color(hex: 0xDCE0E6), Color(hex: 0xEFF1F5)]
        case .gray:
            return [Color(hex: 0x7A7F8A), Color(hex: 0x9095A0), Color(hex: 0xA8ADB8)]
        case .darkGray:
            return [Color(hex: 0x2B2E35), Color(hex: 0x383B44), Color(hex: 0x4A4E59)]
        }
    }

    var centerButtonStrokeColors: [Color] {
        switch self {
        case .light:
            return [Color(hex: 0x9FA4AE), Color(hex: 0xCFD3DA)]
        case .gray:
            return [Color(hex: 0x25272C), Color(hex: 0x626772)]
        case .darkGray:
            return [Color(hex: 0x111216), Color(hex: 0x4A4E58)]
        }
    }

    var wheelLabelColor: Color {
        switch self {
        case .light:
            return Color(hex: 0x3E3E42)
        case .gray, .darkGray:
            return Color(hex: 0xECEEF2)
        }
    }

    var topBarTextColor: Color {
        switch self {
        case .light:
            return Color(hex: 0x555860)
        case .gray:
            return Color(hex: 0x26282E)
        case .darkGray:
            return Color(hex: 0xD5D8E0)
        }
    }
}

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
    case cycleChassisTheme
    case setChassisTheme(ChassisTheme)
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
