import SpriteKit
#if canImport(UIKit)
import UIKit
#endif
@testable import FishyFlop

@MainActor
extension GameScene {
    func sceneLayoutMetricsForTesting() -> SceneLayoutMetrics {
        sceneLayoutMetrics
    }

    func setSafeAreaInsetsForTesting(_ insets: UIEdgeInsets) {
        setSafeAreaInsetsOverride(insets)
    }

    func resetSandboxForTesting() {
        resetRound()
    }

    func triggerGameOverForTesting() {
        enterGameOver()
    }

    func obstaclePairNodesForTesting() -> [SKNode] {
        obstacleManager.obstacleLayer.children
    }

    func scoreLabelNodeForTesting() -> SKLabelNode {
        hudManager.scoreLabelNode
    }

    func readyLabelNodeForTesting() -> SKLabelNode {
        hudManager.readyLabelNode
    }

    func gameOverTitleLabelNodeForTesting() -> SKLabelNode {
        hudManager.gameOverTitleLabelNode
    }

    func gameOverSubtitleLabelNodeForTesting() -> SKLabelNode {
        hudManager.gameOverSubtitleLabelNode
    }

    func gameplayContainerPositionForTesting() -> CGPoint {
        gameplayNode.position
    }

    func gameplayNodeForTesting() -> SKNode {
        gameplayNode
    }

    func effectsNodeForTesting() -> SKNode {
        effectsNode
    }

    func deathBurstNodesForTesting() -> [SKNode] {
        effectsNode.children.filter { $0.name == GameConfig.Effects.DeathBurst.containerNodeName }
    }

    func backgroundNodeForTesting() -> SKNode {
        backgroundNode
    }

    func backgroundSpriteNodeForTesting() -> SKSpriteNode {
        backgroundSpriteNode
    }

    static func backgroundAspectFillSizeForTesting(textureSize: CGSize, containerSize: CGSize) -> CGSize {
        SceneLayout.aspectFillSize(textureSize: textureSize, containerSize: containerSize)
    }

    static func allowedGapCenterYRange(
        playableRange: ClosedRange<CGFloat>,
        startY: CGFloat,
        maximumReachableDelta: CGFloat,
        spawnedObstaclePairCount: Int,
        lastGapCenterY: CGFloat?
    ) -> ClosedRange<CGFloat> {
        ObstacleManager.allowedGapCenterYRange(
            playableRange: playableRange,
            startY: startY,
            maximumReachableDelta: maximumReachableDelta,
            spawnedObstaclePairCount: spawnedObstaclePairCount,
            lastGapCenterY: lastGapCenterY
        )
    }

    func currentObstacleSpeedForTesting() -> CGFloat {
        obstacleManager.currentSpeed(for: score)
    }

    func currentGapSizeForTesting() -> CGFloat {
        obstacleManager.currentGapSize(for: score)
    }

    func currentObstacleSpawnIntervalForTesting() -> TimeInterval {
        obstacleManager.currentSpawnInterval(for: score)
    }

    func effectiveGravityForTesting() -> CGVector {
        effectiveGravity()
    }

    func effectiveFlapImpulseForTesting() -> CGFloat {
        effectiveFlapImpulse()
    }

    func effectiveMaxFallSpeedForTesting() -> CGFloat {
        effectiveMaxFallSpeed()
    }

    func fishHitboxSizeForTesting() -> CGSize {
        GameConfig.Fish.hitboxSize
    }

    func fishNodeForTesting() -> SKSpriteNode {
        playerController.fishNode
    }

    func fishHasIdleAnimationForTesting() -> Bool {
        playerController.fishAnimationTextures.hasIdleAnimation
    }

    func fishHasSwimAnimationForTesting() -> Bool {
        playerController.fishAnimationTextures.hasSwimAnimation
    }

    func fishAnimationActionIsRunningForTesting() -> Bool {
        playerController.fishAnimationActionIsRunning()
    }

    func fishVisualStateForTesting() -> FishVisualState {
        playerController.fishVisualState
    }

    func debugOutlineNodeForTesting(on node: SKNode) -> SKShapeNode? {
        node.childNode(withName: GameConfig.Debug.outlineNodeName) as? SKShapeNode
    }

    func floorNodeForTesting() -> SKNode {
        floorNode
    }

    func ceilingNodeForTesting() -> SKNode {
        ceilingNode
    }

    func setScoreForTesting(_ value: Int) {
        scoreManager.setScore(value)
        hudManager.updateScore(scoreManager.score)
    }

    func spawnObstaclePairForTesting(gapCenterY: CGFloat) {
        obstacleManager.spawnPair(
            gapCenterY: gapCenterY,
            playableRect: playableRect,
            sceneFrame: frame,
            score: score,
            startY: currentStartPosition().y
        )
    }

    func obstacleGapCenterYRangeForTesting() -> ClosedRange<CGFloat> {
        obstacleManager.obstacleGapCenterYRange(playableRect: playableRect, score: score)
    }

    func allowedGapCenterYRangeForNextSpawnForTesting() -> ClosedRange<CGFloat> {
        obstacleManager.allowedGapCenterYRangeForNextSpawn(
            playableRect: playableRect,
            score: score,
            startY: currentStartPosition().y
        )
    }

    func simulateObstacleContactForTesting() {
        if CollisionHandler.isLethalContact(GameConfig.Physics.Category.fish | GameConfig.Physics.Category.obstacle) {
            enterGameOver()
        }
    }

    func simulateFloorContactForTesting() {
        if CollisionHandler.isLethalContact(GameConfig.Physics.Category.fish | GameConfig.Physics.Category.floor) {
            enterGameOver()
        }
    }

    func simulateCeilingContactForTesting() {}

    func simulateScoreZoneContactForTesting(at index: Int = 0) {
        guard obstaclePairNodesForTesting().indices.contains(index),
              let scoreZone = obstaclePairNodesForTesting()[index].childNode(withName: GameConfig.Obstacle.scoreTriggerNodeName)
        else {
            return
        }

        handleScoreContact(with: scoreZone)
    }

    func simulateScoreZoneContactDuringLethalCollisionForTesting(at index: Int = 0) {
        guard obstaclePairNodesForTesting().indices.contains(index),
              let scoreZone = obstaclePairNodesForTesting()[index].childNode(withName: GameConfig.Obstacle.scoreTriggerNodeName)
        else {
            return
        }

        handleScoreContact(with: scoreZone, lethalCollisionActive: true)
    }
}
