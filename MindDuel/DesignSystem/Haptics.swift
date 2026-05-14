import UIKit

enum HapticEvent {
    case correct
    case wrong
    case skip
    case modalOpen
}

struct Haptics {
    static func trigger(_ event: HapticEvent) {
        switch event {
        case .correct:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .wrong:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .skip:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .modalOpen:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}
