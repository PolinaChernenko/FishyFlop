import SpriteKit

final class ObstacleManager {
    private enum ObstacleSegmentNodeName {
        static let visual = "visual"
        static let collider = "collider"
    }

    let obstacleLayer = SKNode()

    private var obstacleSpawnAccumulator: TimeInterval = 0.0
    private var spawnedObstaclePairCount: Int = 0
    private var lastSpawnedGapCenterY: CGFloat?

    init() {}

    func attachIfNeeded(to parent: SKNode) {
        guard obstacleLayer.parent == nil else {
            return
        }

        parent.addChild(obstacleLayer)
    }

    func reset() {
        obstacleSpawnAccumulator = 0.0
        spawnedObstaclePairCount = 0
        lastSpawnedGapCenterY = nil
        obstacleLayer.removeAllChildren()
    }

    func update(
        deltaTime: TimeInterval,
        playableRect: CGRect,
        sceneFrame: CGRect,
        score: Int,
        startY: CGFloat
    ) {
        obstacleSpawnAccumulator += deltaTime
        let spawnInterval = currentSpawnInterval(for: score)

        while obstacleSpawnAccumulator >= spawnInterval {
            obstacleSpawnAccumulator -= spawnInterval
            spawnPair(playableRect: playableRect, sceneFrame: sceneFrame, score: score, startY: startY)
        }

        let distance = currentSpeed(for: score) * deltaTime
        for obstaclePair in obstacleLayer.children {
            obstaclePair.position.x -= distance
        }

        removeOffscreenObstacles(playableRect: playableRect)
    }

    func spawnPair(
        gapCenterY: CGFloat? = nil,
        playableRect: CGRect,
        sceneFrame: CGRect,
        score: Int,
        startY: CGFloat
    ) {
        let resolvedGapCenterY = gapCenterY ?? randomGapCenterY(playableRect: playableRect, score: score, startY: startY)
        let pairNode = SKNode()
        pairNode.name = GameConfig.Obstacle.pairNodeName
        pairNode.position = CGPoint(
            x: playableRect.maxX + (GameConfig.Obstacle.width / 2.0),
            y: 0.0
        )

        let gapSize = currentGapSize(for: score)
        let halfGap = gapSize / 2.0
        let bottomCollisionHeight = max(0.0, resolvedGapCenterY - halfGap - playableRect.minY)
        let topCollisionHeight = max(0.0, playableRect.maxY - (resolvedGapCenterY + halfGap))
        let bottomVisualHeight = max(0.0, resolvedGapCenterY - halfGap - sceneFrame.minY)
        let topVisualHeight = max(0.0, sceneFrame.maxY - (resolvedGapCenterY + halfGap))

        let bottomNode = makeObstacleSegment(
            name: GameConfig.Obstacle.bottomNodeName,
            visualHeight: bottomVisualHeight,
            collisionHeight: bottomCollisionHeight,
            collisionCenterY: playableRect.minY + (bottomCollisionHeight / 2.0),
            sceneFrame: sceneFrame
        )
        let topNode = makeObstacleSegment(
            name: GameConfig.Obstacle.topNodeName,
            visualHeight: topVisualHeight,
            collisionHeight: topCollisionHeight,
            collisionCenterY: playableRect.maxY - (topCollisionHeight / 2.0),
            sceneFrame: sceneFrame
        )
        let scoreZoneNode = makeScoreZoneNode(gapCenterY: resolvedGapCenterY, gapSize: gapSize)

        pairNode.addChild(bottomNode)
        pairNode.addChild(topNode)
        pairNode.addChild(scoreZoneNode)
        obstacleLayer.addChild(pairNode)

        lastSpawnedGapCenterY = resolvedGapCenterY
        spawnedObstaclePairCount += 1
    }

    func currentSpeed(for score: Int) -> CGFloat {
        min(
            GameConfig.Obstacle.Difficulty.maxSpeed,
            GameConfig.Obstacle.Difficulty.startingSpeed +
                (speedDifficultyProgress(for: score) * GameConfig.Obstacle.Difficulty.speedIncreasePerScore)
        )
    }

    func currentGapSize(for score: Int) -> CGFloat {
        max(
            GameConfig.Obstacle.Difficulty.minimumGapSize,
            GameConfig.Obstacle.Difficulty.startingGapSize -
                (obstacleDifficultyProgress(for: score) * GameConfig.Obstacle.Difficulty.gapDecreasePerScore)
        )
    }

    func currentSpawnInterval(for score: Int) -> TimeInterval {
        max(
            GameConfig.Obstacle.Difficulty.minimumSpawnInterval,
            GameConfig.Obstacle.Difficulty.spawnInterval -
                (TimeInterval(obstacleDifficultyProgress(for: score)) * GameConfig.Obstacle.Difficulty.spawnIntervalDecreasePerScore)
        )
    }

    func obstacleGapCenterYRange(playableRect: CGRect, score: Int) -> ClosedRange<CGFloat> {
        let halfGap = currentGapSize(for: score) / 2.0
        let minimumGapCenterY = playableRect.minY + halfGap + GameConfig.Obstacle.gapEdgeInset
        let maximumGapCenterY = playableRect.maxY - halfGap - GameConfig.Obstacle.gapEdgeInset

        guard minimumGapCenterY < maximumGapCenterY else {
            let fallbackGapCenterY = playableRect.midY
            return fallbackGapCenterY...fallbackGapCenterY
        }

        return minimumGapCenterY...maximumGapCenterY
    }

    func allowedGapCenterYRangeForNextSpawn(
        playableRect: CGRect,
        score: Int,
        startY: CGFloat
    ) -> ClosedRange<CGFloat> {
        Self.allowedGapCenterYRange(
            playableRange: obstacleGapCenterYRange(playableRect: playableRect, score: score),
            startY: startY,
            maximumReachableDelta: maximumReachableGapCenterDelta(playableRect: playableRect, score: score),
            spawnedObstaclePairCount: spawnedObstaclePairCount,
            lastGapCenterY: lastSpawnedGapCenterY
        )
    }

    static func allowedGapCenterYRange(
        playableRange: ClosedRange<CGFloat>,
        startY: CGFloat,
        maximumReachableDelta: CGFloat,
        spawnedObstaclePairCount: Int,
        lastGapCenterY: CGFloat?
    ) -> ClosedRange<CGFloat> {
        var allowedRange = playableRange

        if spawnedObstaclePairCount < GameConfig.Obstacle.Generation.protectedOpeningPairCount {
            let openingBandHalfHeight =
                maximumReachableDelta * GameConfig.Obstacle.Generation.openingReachableBandGapMultiplier
            let openingBand = (startY - openingBandHalfHeight)...(startY + openingBandHalfHeight)
            allowedRange = intersectOrCollapse(
                baseRange: allowedRange,
                constraintRange: openingBand,
                fallbackAnchor: startY
            )
        }

        if let lastGapCenterY {
            let jumpBand = (lastGapCenterY - maximumReachableDelta)...(lastGapCenterY + maximumReachableDelta)
            allowedRange = intersectOrCollapse(
                baseRange: allowedRange,
                constraintRange: jumpBand,
                fallbackAnchor: lastGapCenterY
            )
        }

        return allowedRange
    }

    private func speedDifficultyProgress(for score: Int) -> CGFloat {
        CGFloat(max(0, score - (GameConfig.Obstacle.Difficulty.speedScoreThreshold - 1)))
    }

    private func obstacleDifficultyProgress(for score: Int) -> CGFloat {
        CGFloat(max(0, score - GameConfig.Obstacle.Difficulty.easyScoreThreshold))
    }

    private func maximumReachableGapCenterDelta(playableRect: CGRect, score: Int) -> CGFloat {
        min(
            currentGapSize(for: score) * GameConfig.Obstacle.Generation.maximumGapStepGapMultiplier,
            playableRect.height * GameConfig.Obstacle.Generation.maximumGapStepPlayableHeightMultiplier
        )
    }

    private func randomGapCenterY(playableRect: CGRect, score: Int, startY: CGFloat) -> CGFloat {
        CGFloat.random(in: allowedGapCenterYRangeForNextSpawn(playableRect: playableRect, score: score, startY: startY))
    }

    private func makeObstacleSegment(
        name: String,
        visualHeight: CGFloat,
        collisionHeight: CGFloat,
        collisionCenterY: CGFloat,
        sceneFrame: CGRect
    ) -> SKNode {
        let anchoredToTop = name == GameConfig.Obstacle.topNodeName
        let assetName = anchoredToTop ? GameConfig.Obstacle.topAssetName : GameConfig.Obstacle.bottomAssetName
        let visualTuning = GameConfig.Obstacle.visualTuning(anchoredToTop: anchoredToTop)

        let segmentNode = SKNode()
        segmentNode.name = name

        let visualNode = makeObstacleVisualNode(
            assetName: assetName,
            visualHeight: visualHeight,
            anchoredToTop: anchoredToTop
        )
        visualNode.name = ObstacleSegmentNodeName.visual
        visualNode.zPosition = GameConfig.Obstacle.zPosition
        visualNode.position = CGPoint(
            x: 0.0,
            y: anchoredToTop
                ? sceneFrame.maxY + visualTuning.verticalOffset
                : sceneFrame.minY + visualTuning.verticalOffset
        )

        let colliderNode = SKSpriteNode(
            color: .clear,
            size: CGSize(
                width: max(GameConfig.Obstacle.width - (visualTuning.colliderHorizontalInset * 2.0), 1.0),
                height: max(collisionHeight - (visualTuning.colliderVerticalInset * 2.0), 1.0)
            )
        )
        colliderNode.name = ObstacleSegmentNodeName.collider
        colliderNode.zPosition = GameConfig.Obstacle.zPosition
        colliderNode.position = CGPoint(
            x: 0.0,
            y: collisionCenterY + visualTuning.colliderVerticalOffset
        )
        colliderNode.physicsBody = SKPhysicsBody(rectangleOf: colliderNode.size)
        PhysicsBodySupport.configure(
            colliderNode.physicsBody,
            isDynamic: false,
            affectedByGravity: false,
            allowsRotation: nil,
            category: GameConfig.Physics.Category.obstacle,
            collision: GameConfig.Physics.Mask.obstacleCollision,
            contact: GameConfig.Physics.Mask.obstacleContact
        )
        DebugOutlineSupport.attachRectIfNeeded(
            to: colliderNode,
            size: colliderNode.size,
            color: GameConfig.Debug.obstacleColor
        )

        segmentNode.addChild(visualNode)
        segmentNode.addChild(colliderNode)
        return segmentNode
    }

    private func makeObstacleVisualNode(
        assetName: String,
        visualHeight: CGFloat,
        anchoredToTop: Bool
    ) -> SKSpriteNode {
        let containerSize = CGSize(
            width: GameConfig.Obstacle.width,
            height: max(visualHeight, 1.0)
        )
        let spriteNode = SpriteAssetLoader.makeSpriteNode(
            assetName: assetName,
            fallbackColor: GameConfig.Obstacle.placeholderColor,
            size: containerSize
        )

        var resolvedSize = containerSize
        if let texture = spriteNode.texture {
            resolvedSize = SceneLayout.aspectFillSize(
                textureSize: texture.size(),
                containerSize: containerSize
            )
            spriteNode.colorBlendFactor = 0.0
        }

        spriteNode.size = resolvedSize
        spriteNode.anchorPoint = CGPoint(x: 0.5, y: anchoredToTop ? 1.0 : 0.0)
        return spriteNode
    }

    private func makeScoreZoneNode(gapCenterY: CGFloat, gapSize: CGFloat) -> SKSpriteNode {
        let node = SKSpriteNode(
            color: .clear,
            size: CGSize(width: GameConfig.Obstacle.scoreTriggerWidth, height: gapSize)
        )
        node.name = GameConfig.Obstacle.scoreTriggerNodeName
        node.position = CGPoint(x: 0.0, y: gapCenterY)
        node.physicsBody = SKPhysicsBody(rectangleOf: node.size)
        PhysicsBodySupport.configure(
            node.physicsBody,
            isDynamic: false,
            affectedByGravity: false,
            allowsRotation: nil,
            category: GameConfig.Physics.Category.scoreTrigger,
            collision: GameConfig.Physics.Mask.scoreTriggerCollision,
            contact: GameConfig.Physics.Mask.scoreTriggerContact
        )
        DebugOutlineSupport.attachRectIfNeeded(
            to: node,
            size: node.size,
            color: GameConfig.Debug.scoreTriggerColor
        )
        return node
    }

    private func removeOffscreenObstacles(playableRect: CGRect) {
        for obstaclePair in obstacleLayer.children {
            let rightEdge = obstaclePair.position.x + (GameConfig.Obstacle.width / 2.0)
            if rightEdge < playableRect.minX {
                obstaclePair.removeFromParent()
            }
        }
    }

    private static func intersectOrCollapse(
        baseRange: ClosedRange<CGFloat>,
        constraintRange: ClosedRange<CGFloat>,
        fallbackAnchor: CGFloat
    ) -> ClosedRange<CGFloat> {
        let lowerBound = max(baseRange.lowerBound, constraintRange.lowerBound)
        let upperBound = min(baseRange.upperBound, constraintRange.upperBound)

        guard lowerBound <= upperBound else {
            let clampedAnchor = min(max(fallbackAnchor, baseRange.lowerBound), baseRange.upperBound)
            return clampedAnchor...clampedAnchor
        }

        return lowerBound...upperBound
    }
}
