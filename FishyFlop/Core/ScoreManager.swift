import SpriteKit

enum ScoreContactOutcome {
    case none
    case scored(Int)
    case gameOver
}

final class ScoreManager {
    private(set) var score: Int = 0

    func reset() {
        score = 0
    }

    func setScore(_ value: Int) {
        score = value
    }

    func consumeScoreContact(
        with scoreZoneNode: SKNode,
        gameState: GameState,
        lethalCollisionActive: Bool = false,
        fishIsInLethalContact: () -> Bool
    ) -> ScoreContactOutcome {
        guard gameState == .playing else {
            return .none
        }

        guard let physicsBody = scoreZoneNode.physicsBody,
              physicsBody.contactTestBitMask != 0
        else {
            return .none
        }

        if lethalCollisionActive || fishIsInLethalContact() {
            return .gameOver
        }

        physicsBody.contactTestBitMask = 0
        score += 1
        return .scored(score)
    }
}
