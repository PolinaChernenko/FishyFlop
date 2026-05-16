import UIKit

final class HapticManager {
    private enum DeathRumbleStep {
        static let delays: [TimeInterval] = [0.0, 0.06, 0.12]
        static let styles: [UIImpactFeedbackGenerator.FeedbackStyle] = [.heavy, .medium, .heavy]
    }

    private let flapGenerator: UIImpactFeedbackGenerator = {
        if #available(iOS 13.0, *) {
            return UIImpactFeedbackGenerator(style: .soft)
        }

        return UIImpactFeedbackGenerator(style: .light)
    }()

    private var deathRumbleGeneration = UUID()

    func playFlapTap() {
        DispatchQueue.main.async { [flapGenerator] in
            flapGenerator.prepare()

            if #available(iOS 13.0, *) {
                flapGenerator.impactOccurred(intensity: 0.5)
            } else {
                flapGenerator.impactOccurred()
            }
        }
    }

    func playDeathRumble() {
        let generation = UUID()
        deathRumbleGeneration = generation

        for (delay, style) in zip(DeathRumbleStep.delays, DeathRumbleStep.styles) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.deathRumbleGeneration == generation else {
                    return
                }

                let generator = UIImpactFeedbackGenerator(style: style)
                generator.prepare()

                if #available(iOS 13.0, *) {
                    let intensity: CGFloat = style == .medium ? 0.8 : 1.0
                    generator.impactOccurred(intensity: intensity)
                } else {
                    generator.impactOccurred()
                }
            }
        }
    }

    func cancelPendingDeathRumble() {
        deathRumbleGeneration = UUID()
    }
}
