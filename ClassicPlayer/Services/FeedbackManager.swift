import AudioToolbox
import UIKit

final class FeedbackManager {
    static let shared = FeedbackManager()
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

    var isClickerEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: "isClickerEnabled") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "isClickerEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "isClickerEnabled")
        }
    }

    init() {
        selectionFeedback.prepare()
        impactFeedback.prepare()
    }

    // Triggered on every click wheel step/tick
    func playWheelTick() {
        guard isClickerEnabled else { return }
        AudioServicesPlaySystemSound(1104) // Native mechanical tick sound
        selectionFeedback.selectionChanged()
        selectionFeedback.prepare()
    }

    // Triggered on physical button presses (MENU, Center, Play/Pause, Rewind, Fast-Forward)
    func playButtonPress() {
        guard isClickerEnabled else { return }
        AudioServicesPlaySystemSound(1105) // Crisp button tap sound
        impactFeedback.impactOccurred()
        impactFeedback.prepare()
    }

    func triggerWheelTick() {
        playWheelTick()
    }

    func triggerButtonPress() {
        playButtonPress()
    }
}
