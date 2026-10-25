import AudioToolbox
import UIKit

@MainActor
final class FeedbackManager {
    static let shared = FeedbackManager()

    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let buttonGenerator = UIImpactFeedbackGenerator(style: .rigid)
    var isClickerEnabled: Bool = true

    private init() {
        selectionGenerator.prepare()
        buttonGenerator.prepare()
    }

    /// Plays iOS system sound ID 1104 (classic hardware wheel tick) coupled with UISelectionFeedbackGenerator.
    func triggerWheelTick() {
        if isClickerEnabled {
            AudioServicesPlaySystemSound(1104)
        }
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    /// Tactile click when pressing physical wheel buttons (MENU, Center, Play/Pause, Next, Previous).
    func triggerButtonPress() {
        if isClickerEnabled {
            AudioServicesPlaySystemSound(1104)
        }
        buttonGenerator.impactOccurred(intensity: 0.85)
        buttonGenerator.prepare()
    }
}
