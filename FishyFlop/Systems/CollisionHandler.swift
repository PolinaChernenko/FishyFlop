import SpriteKit

enum CollisionOutcome {
    case none
    case score(SKNode)
    case gameOver
}

enum CollisionHandler {
    static func outcome(
        for contact: SKPhysicsContact,
        gameState: GameState
    ) -> CollisionOutcome {
        guard gameState == .playing else {
            return .none
        }

        let categoryMask = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        if isLethalContact(categoryMask) {
            return .gameOver
        }

        if let scoreZoneNode = scoreZoneNode(from: contact.bodyA, and: contact.bodyB) {
            return .score(scoreZoneNode)
        }

        return .none
    }

    static func isLethalContact(_ categoryMask: UInt32) -> Bool {
        let fishHitFloor =
            categoryMask == (GameConfig.Physics.Category.fish | GameConfig.Physics.Category.floor)
        let fishHitObstacle =
            categoryMask == (GameConfig.Physics.Category.fish | GameConfig.Physics.Category.obstacle)

        return fishHitFloor || fishHitObstacle
    }

    static func scoreZoneNode(from firstBody: SKPhysicsBody, and secondBody: SKPhysicsBody) -> SKNode? {
        if firstBody.categoryBitMask == GameConfig.Physics.Category.scoreTrigger &&
            secondBody.categoryBitMask == GameConfig.Physics.Category.fish {
            return firstBody.node
        }

        if secondBody.categoryBitMask == GameConfig.Physics.Category.scoreTrigger &&
            firstBody.categoryBitMask == GameConfig.Physics.Category.fish {
            return secondBody.node
        }

        return nil
    }
}
