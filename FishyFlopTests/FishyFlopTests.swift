//
//  FishyFlopTests.swift
//  FishyFlopTests
//
//  Created by Polina on 2026-04-28.
//

import Testing
import SpriteKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
@testable import FishyFlop

@MainActor
struct FishyFlopTests {

    private func makeScene() -> GameScene {
        GameScene(size: GameConfig.Scene.initialSize)
    }

    private func makeScene(fishAnimationTextures: FishAnimationTextures) -> GameScene {
        GameScene(size: GameConfig.Scene.initialSize, fishAnimationTextures: fishAnimationTextures)
    }

    private func withDebugMode<T>(_ isEnabled: Bool, perform work: () throws -> T) rethrows -> T {
        let previousValue = GameConfig.isDebugMode
        GameConfig.isDebugMode = isEnabled
        defer { GameConfig.isDebugMode = previousValue }
        return try work()
    }

    private func attachScene(_ scene: GameScene) {
        let view = SKView(frame: CGRect(origin: .zero, size: GameConfig.Scene.initialSize))
        scene.didMove(to: view)
    }

    private func countChildren(named name: String, in node: SKNode) -> Int {
        node.children.filter { $0.name == name }.count
    }

    private func expectedMotionScale(for scene: GameScene) -> CGFloat {
        scene.sceneLayoutMetricsForTesting().playableRect.height / GameConfig.Fish.Motion.referencePlayableHeight
    }

    private func expectedProtectedOpeningHalfHeight(for scene: GameScene) -> CGFloat {
        let playableHeight = scene.sceneLayoutMetricsForTesting().playableRect.height
        let maximumReachableDelta = min(
            scene.currentGapSizeForTesting() * GameConfig.Obstacle.Generation.maximumGapStepGapMultiplier,
            playableHeight * GameConfig.Obstacle.Generation.maximumGapStepPlayableHeightMultiplier
        )

        return maximumReachableDelta * GameConfig.Obstacle.Generation.openingReachableBandGapMultiplier
    }

    private func expectedGameOverVerticalSpacing(for scene: GameScene) -> CGFloat {
        max(
            scene.sceneLayoutMetricsForTesting().playableRect.height * GameConfig.HUD.overlayVerticalSpacingRatio,
            GameConfig.HUD.Overlay.minimumVerticalSpacing
        )
    }

    private func expectedGameOverCenterY(for scene: GameScene) -> CGFloat {
        let playableRect = scene.sceneLayoutMetricsForTesting().playableRect
        return playableRect.minY + (playableRect.height * GameConfig.HUD.Overlay.gameOverCenterYRatio)
    }

    private func expectedDeadFishPosition(for scene: GameScene) -> CGPoint {
        let spacing = expectedGameOverVerticalSpacing(for: scene)
        return CGPoint(
            x: scene.sceneLayoutMetricsForTesting().playableRect.midX + GameConfig.HUD.Overlay.gameOverFishOffsetX,
            y: expectedGameOverCenterY(for: scene) + (spacing * (0.5 + GameConfig.HUD.Overlay.gameOverFishOffsetYMultiplier))
        )
    }

    private func obstacleSegmentVisualNode(_ segmentNode: SKNode) throws -> SKSpriteNode {
        try #require(segmentNode.childNode(withName: "visual") as? SKSpriteNode)
    }

    private func obstacleSegmentColliderNode(_ segmentNode: SKNode) throws -> SKSpriteNode {
        try #require(segmentNode.childNode(withName: "collider") as? SKSpriteNode)
    }

    private func makeFishAnimationTextures(
        idleFrameCount: Int = 2,
        swimFrameCount: Int = 2
    ) -> FishAnimationTextures {
        FishAnimationTextures(
            idle: (0..<idleFrameCount).map { makeTexture(hue: CGFloat($0) * 0.1) },
            swim: (0..<swimFrameCount).map { makeTexture(hue: 0.5 + (CGFloat($0) * 0.1)) },
            dead: nil
        )
    }

    private func makeTexture(hue: CGFloat) -> SKTexture {
        let size = CGSize(width: 8.0, height: 8.0)
        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor(
                hue: min(max(hue, 0.0), 1.0),
                saturation: 0.9,
                brightness: 0.9,
                alpha: 1.0
            ).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: image)
        #elseif canImport(AppKit)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(
            hue: min(max(hue, 0.0), 1.0),
            saturation: 0.9,
            brightness: 0.9,
            alpha: 1.0
        ).setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        return SKTexture(image: image)
        #endif
    }

    @Test func spriteAssetNamesAreRegisteredInOnePlace() async throws {
        #expect(
            Set(GameConfig.Assets.allNames) == Set([
                "backdrop",
                "bottom_coral",
                "top_coral",
                "main_fish",
                "dead_fish"
            ])
        )
    }

    @Test func missingAssetsResolveToPlaceholderSprites() async throws {
        #expect(SpriteAssetLoader.textureIfAvailable(named: "missing_asset") == nil)

        let spriteNode = SpriteAssetLoader.makeSpriteNode(
            assetName: "missing_asset",
            fallbackColor: GameConfig.Fish.placeholderColor,
            size: GameConfig.Fish.size
        )

        #expect(spriteNode.texture == nil)
        #expect(spriteNode.color == GameConfig.Fish.placeholderColor)
        #expect(spriteNode.size == GameConfig.Fish.size)
    }

    @Test func sceneSetupCreatesFishSandbox() async throws {
        let scene = makeScene()
        attachScene(scene)

        let backgroundNode = try #require(scene.childNode(withName: GameConfig.Background.nodeName))
        let backgroundSpriteNode = scene.backgroundSpriteNodeForTesting()
        let fishNode = try #require(scene.childNode(withName: GameConfig.Fish.nodeName) as? SKSpriteNode)
        let floorNode = try #require(scene.childNode(withName: GameConfig.World.floorNodeName))
        let ceilingNode = try #require(scene.childNode(withName: GameConfig.World.ceilingNodeName))
        let effectsNode = scene.effectsNodeForTesting()
        let scoreLabelNode = scene.scoreLabelNodeForTesting()
        let readyLabelNode = scene.readyLabelNodeForTesting()
        let gameOverTitleLabelNode = scene.gameOverTitleLabelNodeForTesting()
        let gameOverSubtitleLabelNode = scene.gameOverSubtitleLabelNodeForTesting()
        let physicsBody = try #require(fishNode.physicsBody)
        let floorPhysicsBody = try #require(floorNode.physicsBody)
        let ceilingPhysicsBody = try #require(ceilingNode.physicsBody)

        #expect(scene.physicsWorld.gravity == scene.effectiveGravityForTesting())
        #expect(scene.gameState == .ready)
        #expect(scene.score == 0)
        #expect(backgroundNode.parent === scene)
        #expect(backgroundSpriteNode.parent === backgroundNode)
        #expect(effectsNode.parent === scene.gameplayNodeForTesting())
        #expect(effectsNode.name == GameConfig.Effects.nodeName)
        #expect(effectsNode.zPosition == GameConfig.Effects.zPosition)
        #expect(backgroundNode.zPosition == GameConfig.Background.zPosition)
        #expect(backgroundSpriteNode.position == CGPoint(x: scene.frame.midX, y: scene.frame.midY))
        #expect(backgroundSpriteNode.size == scene.frame.size)
        #expect(backgroundNode.zPosition < GameConfig.Obstacle.zPosition)
        #expect(effectsNode.zPosition > GameConfig.Fish.zPosition)
        #expect(effectsNode.zPosition < GameConfig.HUD.Overlay.zPosition)
        #expect(fishNode.position == scene.currentStartPosition())
        #expect(fishNode.size == GameConfig.Fish.size)
        #expect(scene.fishHitboxSizeForTesting() == GameConfig.Fish.hitboxSize)
        #expect(scene.fishHitboxSizeForTesting().width < fishNode.size.width)
        #expect(scene.fishHitboxSizeForTesting().height < fishNode.size.height)
        #expect(fishNode.zRotation == 0.0)
        #expect(fishNode.xScale == 1.0)
        #expect(fishNode.yScale == 1.0)
        #expect(scene.fishHasIdleAnimationForTesting() == false)
        #expect(scene.fishHasSwimAnimationForTesting() == false)
        #expect(scene.fishAnimationActionIsRunningForTesting() == false)
        #expect(scene.fishVisualStateForTesting() == .stopped)
        #expect(physicsBody.allowsRotation == false)
        #expect(physicsBody.isDynamic == false)
        #expect(physicsBody.categoryBitMask == GameConfig.Physics.Category.fish)
        #expect(
            physicsBody.collisionBitMask ==
            GameConfig.Physics.Mask.fishCollision
        )
        #expect(
            physicsBody.contactTestBitMask ==
            GameConfig.Physics.Mask.fishLethalContact
        )
        #expect(floorPhysicsBody.categoryBitMask == GameConfig.Physics.Category.floor)
        #expect(floorPhysicsBody.collisionBitMask == GameConfig.Physics.Mask.floorCollision)
        #expect(floorPhysicsBody.contactTestBitMask == GameConfig.Physics.Mask.floorContact)
        #expect(ceilingPhysicsBody.categoryBitMask == GameConfig.Physics.Category.ceiling)
        #expect(ceilingPhysicsBody.collisionBitMask == GameConfig.Physics.Mask.ceilingCollision)
        #expect(ceilingPhysicsBody.contactTestBitMask == GameConfig.Physics.Mask.ceilingContact)
        #expect(scoreLabelNode.text == "0")
        let playableRect = scene.sceneLayoutMetricsForTesting().playableRect
        #expect(scoreLabelNode.position == CGPoint(
            x: playableRect.midX,
            y: playableRect.maxY - GameConfig.HUD.scoreTopPadding
        ))
        #expect(readyLabelNode.text == GameConfig.HUD.Overlay.readyText)
        #expect(readyLabelNode.position == CGPoint(x: playableRect.midX, y: playableRect.midY))
        #expect(readyLabelNode.isHidden == false)
        #expect(scene.effectiveFlapImpulseForTesting() == GameConfig.Fish.Motion.flapImpulse * expectedMotionScale(for: scene))
        #expect(scene.effectiveMaxFallSpeedForTesting() == GameConfig.Fish.Motion.maxFallSpeed * expectedMotionScale(for: scene))
        #expect(gameOverTitleLabelNode.text == GameConfig.HUD.Overlay.gameOverTitleText)
        #expect(gameOverTitleLabelNode.isHidden == true)
        #expect(gameOverSubtitleLabelNode.text == GameConfig.HUD.Overlay.gameOverSubtitleText)
        #expect(gameOverSubtitleLabelNode.isHidden == true)
        #expect(gameOverTitleLabelNode.position == CGPoint(
            x: playableRect.midX,
            y: expectedGameOverCenterY(for: scene) + (expectedGameOverVerticalSpacing(for: scene) / 2.0)
        ))
        #expect(gameOverSubtitleLabelNode.position == CGPoint(
            x: playableRect.midX,
            y: expectedGameOverCenterY(for: scene) - (expectedGameOverVerticalSpacing(for: scene) / 2.0)
        ))
        #expect(scene.debugOutlineNodeForTesting(on: fishNode) == nil)
        #expect(scene.debugOutlineNodeForTesting(on: floorNode) == nil)
        #expect(scene.debugOutlineNodeForTesting(on: ceilingNode) == nil)
    }

    @Test func backgroundRelayoutCoversResizedScene() async throws {
        let scene = makeScene()
        attachScene(scene)

        scene.size = CGSize(width: 428.0, height: 926.0)

        let backgroundSpriteNode = scene.backgroundSpriteNodeForTesting()

        #expect(backgroundSpriteNode.position == CGPoint(x: scene.frame.midX, y: scene.frame.midY))
        #expect(backgroundSpriteNode.size == scene.frame.size)
    }

    @Test func resizedSceneScalesFishMotionWithPlayableHeight() async throws {
        let scene = makeScene()
        attachScene(scene)

        scene.size = CGSize(width: 428.0, height: 926.0)

        let expectedScale = expectedMotionScale(for: scene)

        #expect(expectedScale > 1.0)
        #expect(scene.effectiveGravityForTesting().dy == GameConfig.Fish.Motion.gravityStrength * expectedScale)
        #expect(scene.effectiveFlapImpulseForTesting() == GameConfig.Fish.Motion.flapImpulse * expectedScale)
        #expect(scene.effectiveMaxFallSpeedForTesting() == GameConfig.Fish.Motion.maxFallSpeed * expectedScale)
        #expect(scene.physicsWorld.gravity == scene.effectiveGravityForTesting())
    }

    @Test func backgroundAspectFillSizingUsesLargestScaleFactor() async throws {
        let size = GameScene.backgroundAspectFillSizeForTesting(
            textureSize: CGSize(width: 100.0, height: 50.0),
            containerSize: CGSize(width: 390.0, height: 844.0)
        )

        #expect(size.width == 1688.0)
        #expect(size.height == 844.0)
    }

    @Test func backgroundStaysOutsideGameplayShakeHierarchy() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.handleTap()
        scene.simulateFloorContactForTesting()

        let backgroundNode = scene.backgroundNodeForTesting()
        let gameplayNode = scene.gameplayNodeForTesting()

        #expect(backgroundNode.parent === scene)
        #expect(gameplayNode.parent === scene)
        #expect(backgroundNode.hasActions() == false)
        #expect(gameplayNode.hasActions() == true)
    }

    @Test func repeatedSceneAttachmentDoesNotDuplicateRuntimeNodes() async throws {
        let scene = makeScene()
        attachScene(scene)
        attachScene(scene)

        let gameplayNode = scene.gameplayNodeForTesting()

        #expect(countChildren(named: GameConfig.Background.nodeName, in: scene) == 1)
        #expect(countChildren(named: GameConfig.HUD.ScoreLabel.nodeName, in: scene) == 1)
        #expect(countChildren(named: GameConfig.HUD.Overlay.readyNodeName, in: scene) == 1)
        #expect(countChildren(named: GameConfig.HUD.Overlay.gameOverTitleNodeName, in: scene) == 1)
        #expect(countChildren(named: GameConfig.HUD.Overlay.gameOverSubtitleNodeName, in: scene) == 1)
        #expect(countChildren(named: GameConfig.World.floorNodeName, in: scene) == 1)
        #expect(countChildren(named: GameConfig.World.ceilingNodeName, in: scene) == 1)
        #expect(countChildren(named: GameConfig.Fish.nodeName, in: gameplayNode) == 1)
        #expect(countChildren(named: GameConfig.Obstacle.pairNodeName, in: gameplayNode) == 0)
    }

    @Test func debugModeDefaultsToOff() async throws {
        #expect(GameConfig.isDebugMode == false)
    }

    @Test func debugModeAddsOverlaysWithoutPhysicsBodies() async throws {
        try withDebugMode(true) {
            let scene = makeScene()
            attachScene(scene)
            scene.spawnObstaclePairForTesting(gapCenterY: scene.obstacleGapCenterYRangeForTesting().lowerBound)

            let fishNode = scene.fishNodeForTesting()
            let floorNode = scene.floorNodeForTesting()
            let ceilingNode = scene.ceilingNodeForTesting()
            let pairNode = try #require(scene.obstaclePairNodesForTesting().first)
            let topNode = try #require(pairNode.childNode(withName: GameConfig.Obstacle.topNodeName))
            let bottomNode = try #require(pairNode.childNode(withName: GameConfig.Obstacle.bottomNodeName))
            let scoreZoneNode = try #require(pairNode.childNode(withName: GameConfig.Obstacle.scoreTriggerNodeName))

            let topColliderNode = try obstacleSegmentColliderNode(topNode)
            let bottomColliderNode = try obstacleSegmentColliderNode(bottomNode)
            let fishDebugNode = try #require(scene.debugOutlineNodeForTesting(on: fishNode))
            let floorDebugNode = try #require(scene.debugOutlineNodeForTesting(on: floorNode))
            let ceilingDebugNode = try #require(scene.debugOutlineNodeForTesting(on: ceilingNode))
            let topDebugNode = try #require(scene.debugOutlineNodeForTesting(on: topColliderNode))
            let bottomDebugNode = try #require(scene.debugOutlineNodeForTesting(on: bottomColliderNode))
            let scoreZoneDebugNode = try #require(scene.debugOutlineNodeForTesting(on: scoreZoneNode))

            #expect(fishDebugNode.physicsBody == nil)
            #expect(floorDebugNode.physicsBody == nil)
            #expect(ceilingDebugNode.physicsBody == nil)
            #expect(topDebugNode.physicsBody == nil)
            #expect(bottomDebugNode.physicsBody == nil)
            #expect(scoreZoneDebugNode.physicsBody == nil)
        }
    }

    @Test func debugWorldBoundsRebuildAfterSizeChange() async throws {
        try withDebugMode(true) {
            let scene = makeScene()
            attachScene(scene)

            let floorNode = scene.floorNodeForTesting()
            let originalOutline = try #require(scene.debugOutlineNodeForTesting(on: floorNode))
            let originalPathBounds = try #require(originalOutline.path?.boundingBox)

            scene.size = CGSize(width: 428.0, height: 926.0)

            let resizedOutline = try #require(scene.debugOutlineNodeForTesting(on: floorNode))
            let resizedPathBounds = try #require(resizedOutline.path?.boundingBox)

            #expect(resizedPathBounds.width == scene.frame.width)
            #expect(resizedPathBounds.width != originalPathBounds.width)
        }
    }

    @Test func obstacleConfigSupportsPlayableGapRange() async throws {
        #expect(GameConfig.Obstacle.Difficulty.startingSpeed > 0.0)
        #expect(GameConfig.Obstacle.Difficulty.spawnInterval > 0.0)
        #expect(GameConfig.Obstacle.width > 0.0)
        #expect(GameConfig.Obstacle.Difficulty.startingGapSize > 0.0)
        #expect(GameConfig.Obstacle.gapEdgeInset >= 0.0)
        #expect(
            (GameConfig.Obstacle.Difficulty.startingGapSize + (GameConfig.Obstacle.gapEdgeInset * 2.0)) <
            GameConfig.Scene.initialSize.height
        )
        #expect(GameConfig.Obstacle.Difficulty.minimumGapSize <= GameConfig.Obstacle.Difficulty.startingGapSize)
        #expect(GameConfig.Obstacle.Difficulty.minimumSpawnInterval <= GameConfig.Obstacle.Difficulty.spawnInterval)
        #expect(GameConfig.Obstacle.Difficulty.startingSpeed <= GameConfig.Obstacle.Difficulty.maxSpeed)
    }

    @Test func firstTapStartsSandboxAppliesImpulseAndTiltsUpward() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.handleTap()

        let fishNode = try #require(scene.childNode(withName: GameConfig.Fish.nodeName) as? SKSpriteNode)
        let physicsBody = try #require(fishNode.physicsBody)
        let readyLabelNode = scene.readyLabelNodeForTesting()
        let gameOverTitleLabelNode = scene.gameOverTitleLabelNodeForTesting()
        let gameOverSubtitleLabelNode = scene.gameOverSubtitleLabelNodeForTesting()
        let scoreLabelNode = scene.scoreLabelNodeForTesting()

        #expect(scene.gameState == .playing)
        #expect(scene.fishVisualStateForTesting() == .stopped)
        #expect(physicsBody.isDynamic == true)
        #expect(physicsBody.velocity.dy > 0.0)
        #expect(readyLabelNode.isHidden == true)
        #expect(gameOverTitleLabelNode.isHidden == true)
        #expect(gameOverSubtitleLabelNode.isHidden == true)
        #expect(scoreLabelNode.isHidden == false)

        scene.update(1.0 / 60.0)

        #expect(fishNode.zRotation > 0.0)
        #expect(fishNode.zRotation <= GameConfig.Fish.Motion.maxUpRotation)
    }

    @Test func readyStateStartsIdleAnimationWhenIdleTexturesExist() async throws {
        let scene = makeScene(fishAnimationTextures: makeFishAnimationTextures())
        attachScene(scene)

        let fishNode = scene.fishNodeForTesting()

        #expect(scene.gameState == .ready)
        #expect(scene.fishHasIdleAnimationForTesting() == true)
        #expect(scene.fishAnimationActionIsRunningForTesting() == true)
        #expect(scene.fishVisualStateForTesting() == .readyIdle)
        #expect(fishNode.texture != nil)
        #expect(fishNode.size == GameConfig.Fish.size)
    }

    @Test func firstTapImmediatelyStartsSwimBurstWhenSwimTexturesExist() async throws {
        let scene = makeScene(fishAnimationTextures: makeFishAnimationTextures())
        attachScene(scene)
        scene.handleTap()

        let physicsBody = try #require(scene.fishNodeForTesting().physicsBody)

        #expect(scene.gameState == .playing)
        #expect(scene.fishVisualStateForTesting() == .swimBurst)
        #expect(scene.fishAnimationActionIsRunningForTesting() == true)
        #expect(physicsBody.isDynamic == true)
        #expect(scene.fishNodeForTesting().size == GameConfig.Fish.size)
    }

    @Test func swimBurstTransitionsBackToPlayingLoopAfterBurstDuration() async throws {
        let scene = makeScene(fishAnimationTextures: makeFishAnimationTextures())
        attachScene(scene)
        scene.handleTap()

        let burstDuration =
            GameConfig.Fish.Animation.swimBurstFrameDuration *
            Double(2 * GameConfig.Fish.Animation.swimBurstRepeatCount)

        scene.update(1.0 / 60.0)
        scene.update((1.0 / 60.0) + burstDuration + 0.01)

        #expect(scene.fishVisualStateForTesting() == .playingLoop)
        #expect(scene.fishAnimationActionIsRunningForTesting() == true)
    }

    @Test func tapResetsVerticalVelocityBeforeImpulse() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.handleTap()

        let fishNode = try #require(scene.childNode(withName: GameConfig.Fish.nodeName) as? SKSpriteNode)
        let physicsBody = try #require(fishNode.physicsBody)

        physicsBody.velocity = CGVector(dx: 3.0, dy: -12.0)
        scene.handleTap()

        #expect(physicsBody.velocity.dx == 3.0)
        #expect(physicsBody.velocity.dy > 0.0)
    }

    @Test func updateKeepsFishStillInReadyState() async throws {
        let scene = makeScene()
        attachScene(scene)

        let fishNode = try #require(scene.childNode(withName: GameConfig.Fish.nodeName) as? SKSpriteNode)
        let physicsBody = try #require(fishNode.physicsBody)
        let startPosition = fishNode.position

        scene.update(1.0 / 60.0)

        #expect(scene.gameState == .ready)
        #expect(fishNode.position == startPosition)
        #expect(physicsBody.velocity == .zero)
        #expect(scene.obstaclePairNodesForTesting().isEmpty)
    }

    @Test func sizeChangeKeepsFishAnchoredBeforeStart() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.size = CGSize(width: 428.0, height: 926.0)

        let fishNode = try #require(scene.childNode(withName: GameConfig.Fish.nodeName) as? SKSpriteNode)
        let readyLabelNode = scene.readyLabelNodeForTesting()
        let gameOverTitleLabelNode = scene.gameOverTitleLabelNodeForTesting()
        let gameOverSubtitleLabelNode = scene.gameOverSubtitleLabelNodeForTesting()
        let scoreLabelNode = scene.scoreLabelNodeForTesting()
        let playableRect = scene.sceneLayoutMetricsForTesting().playableRect
        #expect(fishNode.position == scene.currentStartPosition())
        #expect(scoreLabelNode.position == CGPoint(
            x: playableRect.midX,
            y: playableRect.maxY - GameConfig.HUD.scoreTopPadding
        ))
        #expect(readyLabelNode.position == CGPoint(x: playableRect.midX, y: playableRect.midY))
        #expect(gameOverTitleLabelNode.position == CGPoint(
            x: playableRect.midX,
            y: expectedGameOverCenterY(for: scene) + (expectedGameOverVerticalSpacing(for: scene) / 2.0)
        ))
        #expect(gameOverSubtitleLabelNode.position == CGPoint(
            x: playableRect.midX,
            y: expectedGameOverCenterY(for: scene) - (expectedGameOverVerticalSpacing(for: scene) / 2.0)
        ))
    }

    @Test func fishStartLaneSitsBelowPlayableMidline() async throws {
        let scene = makeScene()
        attachScene(scene)

        let playableRect = scene.sceneLayoutMetricsForTesting().playableRect

        #expect(scene.currentStartPosition().y < playableRect.midY)
        #expect(scene.currentStartPosition().y == playableRect.minY + (playableRect.height * GameConfig.Fish.startPosition.y))
    }

    @Test func updateClampsRotationForRisingAndFalling() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.handleTap()

        let fishNode = try #require(scene.childNode(withName: GameConfig.Fish.nodeName) as? SKSpriteNode)
        let physicsBody = try #require(fishNode.physicsBody)

        physicsBody.velocity = CGVector(dx: 0.0, dy: scene.effectiveFlapImpulseForTesting() * 4.0)
        scene.update(1.0 / 60.0)

        let upwardRotation = fishNode.zRotation
        #expect(upwardRotation > 0.0)
        #expect(upwardRotation <= GameConfig.Fish.Motion.maxUpRotation)

        physicsBody.velocity = CGVector(dx: 0.0, dy: -scene.effectiveFlapImpulseForTesting() * 4.0)
        scene.update(2.0 / 60.0)

        #expect(fishNode.zRotation < upwardRotation)
        #expect(fishNode.zRotation >= GameConfig.Fish.Motion.maxDownRotation)
    }

    @Test func earlyScoresKeepEasyDifficultyValues() async throws {
        let scene = makeScene()
        attachScene(scene)

        scene.setScoreForTesting(GameConfig.Obstacle.Difficulty.easyScoreThreshold)

        #expect(scene.currentObstacleSpeedForTesting() > GameConfig.Obstacle.Difficulty.startingSpeed)
        #expect(scene.currentGapSizeForTesting() == GameConfig.Obstacle.Difficulty.startingGapSize)
        #expect(scene.currentObstacleSpawnIntervalForTesting() == GameConfig.Obstacle.Difficulty.spawnInterval)
    }

    @Test func zeroScoreKeepsStartingObstacleSpeed() async throws {
        let scene = makeScene()
        attachScene(scene)

        scene.setScoreForTesting(0)

        #expect(scene.currentObstacleSpeedForTesting() == GameConfig.Obstacle.Difficulty.startingSpeed)
    }

    @Test func obstacleSpeedStartsIncreasingAtThresholdScore() async throws {
        let scene = makeScene()
        attachScene(scene)

        scene.setScoreForTesting(GameConfig.Obstacle.Difficulty.speedScoreThreshold)

        #expect(
            scene.currentObstacleSpeedForTesting() ==
            GameConfig.Obstacle.Difficulty.startingSpeed + GameConfig.Obstacle.Difficulty.speedIncreasePerScore
        )
    }

    @Test func speedScalesWhileGapAndSpawnIntervalStayFixed() async throws {
        let scene = makeScene()
        attachScene(scene)

        scene.setScoreForTesting(GameConfig.Obstacle.Difficulty.easyScoreThreshold + 3)

        #expect(
            scene.currentObstacleSpeedForTesting() ==
            GameConfig.Obstacle.Difficulty.startingSpeed +
            (CGFloat(GameConfig.Obstacle.Difficulty.easyScoreThreshold + 3) * GameConfig.Obstacle.Difficulty.speedIncreasePerScore)
        )
        #expect(scene.currentGapSizeForTesting() == GameConfig.Obstacle.Difficulty.startingGapSize)
        #expect(scene.currentObstacleSpawnIntervalForTesting() == GameConfig.Obstacle.Difficulty.spawnInterval)
    }

    @Test func difficultyScalingKeepsFixedGapAndTimingWhileRespectingSpeedCap() async throws {
        let scene = makeScene()
        attachScene(scene)

        scene.setScoreForTesting(99)

        #expect(scene.currentObstacleSpeedForTesting() == GameConfig.Obstacle.Difficulty.maxSpeed)
        #expect(scene.currentGapSizeForTesting() == GameConfig.Obstacle.Difficulty.startingGapSize)
        #expect(scene.currentObstacleSpawnIntervalForTesting() == GameConfig.Obstacle.Difficulty.spawnInterval)
    }

    @Test func updateClampsFishMaximumFallSpeed() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.handleTap()

        let physicsBody = try #require(scene.fishNodeForTesting().physicsBody)
        physicsBody.velocity = CGVector(dx: 0.0, dy: -(scene.effectiveMaxFallSpeedForTesting() + 180.0))

        scene.update(1.0 / 60.0)

        #expect(physicsBody.velocity.dy == -scene.effectiveMaxFallSpeedForTesting())
    }

    @Test func floorContactTriggersGameOver() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.handleTap()

        let fishNode = try #require(scene.childNode(withName: GameConfig.Fish.nodeName) as? SKSpriteNode)
        let physicsBody = try #require(fishNode.physicsBody)
        let readyLabelNode = scene.readyLabelNodeForTesting()
        let gameOverTitleLabelNode = scene.gameOverTitleLabelNodeForTesting()
        let gameOverSubtitleLabelNode = scene.gameOverSubtitleLabelNodeForTesting()
        let scoreLabelNode = scene.scoreLabelNodeForTesting()
        fishNode.position.y += 12.0
        let impactPosition = fishNode.position

        scene.simulateFloorContactForTesting()

        let deathBurstNode = try #require(scene.deathBurstNodesForTesting().first)
        #expect(scene.gameState == .gameOver)
        #expect(physicsBody.isDynamic == false)
        #expect(physicsBody.velocity == .zero)
        #expect(deathBurstNode.parent === scene.effectsNodeForTesting())
        #expect(deathBurstNode.position == impactPosition)
        #expect(fishNode.position == expectedDeadFishPosition(for: scene))
        #expect(readyLabelNode.isHidden == true)
        #expect(gameOverTitleLabelNode.isHidden == false)
        #expect(gameOverSubtitleLabelNode.isHidden == false)
        #expect(scoreLabelNode.isHidden == false)
    }

    @Test func gameOverDeathBurstUsesConfiguredBubbleCount() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.handleTap()

        scene.triggerGameOverForTesting()

        let deathBurstNode = try #require(scene.deathBurstNodesForTesting().first)
        let dustEmitter = try #require(
            deathBurstNode.childNode(withName: GameConfig.Effects.DeathBurst.dustEmitterNodeName) as? SKEmitterNode
        )

        #expect(dustEmitter.numParticlesToEmit == GameConfig.Effects.DeathBurst.Dust.particleCount)
        #expect(dustEmitter.numParticlesToEmit == 16)
    }

    @Test func ceilingContactDoesNotTriggerGameOver() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.handleTap()

        let fishNode = scene.fishNodeForTesting()
        let physicsBody = try #require(fishNode.physicsBody)
        let originalPosition = fishNode.position

        scene.simulateCeilingContactForTesting()

        #expect(scene.gameState == .playing)
        #expect(physicsBody.isDynamic == true)
        #expect(fishNode.position == originalPosition)
    }

    @Test func tapDuringGameOverResetsSceneToReady() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.handleTap()

        let fishNode = try #require(scene.childNode(withName: GameConfig.Fish.nodeName) as? SKSpriteNode)
        let physicsBody = try #require(fishNode.physicsBody)
        let readyLabelNode = scene.readyLabelNodeForTesting()
        let gameOverTitleLabelNode = scene.gameOverTitleLabelNodeForTesting()
        let gameOverSubtitleLabelNode = scene.gameOverSubtitleLabelNodeForTesting()

        fishNode.position.y += 42.0
        physicsBody.velocity = CGVector(dx: 2.0, dy: -8.0)
        fishNode.zRotation = GameConfig.Fish.Motion.maxDownRotation
        fishNode.setScale(1.0 + GameConfig.Effects.tapScaleAmount)

        scene.triggerGameOverForTesting()
        #expect(scene.deathBurstNodesForTesting().count == 1)
        scene.handleTap()

        #expect(scene.gameState == .ready)
        #expect(scene.deathBurstNodesForTesting().isEmpty)
        #expect(scene.fishVisualStateForTesting() == .stopped)
        #expect(fishNode.position == scene.currentStartPosition())
        #expect(fishNode.zRotation == 0.0)
        #expect(fishNode.xScale == 1.0)
        #expect(fishNode.yScale == 1.0)
        #expect(physicsBody.isDynamic == false)
        #expect(physicsBody.isResting == true)
        #expect(physicsBody.velocity == .zero)
        #expect(scene.obstaclePairNodesForTesting().isEmpty)
        #expect(readyLabelNode.isHidden == false)
        #expect(gameOverTitleLabelNode.isHidden == true)
        #expect(gameOverSubtitleLabelNode.isHidden == true)
    }

    @Test func resetSandboxClearsTransformState() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.handleTap()

        let fishNode = try #require(scene.childNode(withName: GameConfig.Fish.nodeName) as? SKSpriteNode)
        let physicsBody = try #require(fishNode.physicsBody)

        physicsBody.velocity = CGVector(dx: 0.0, dy: scene.effectiveFlapImpulseForTesting())
        scene.update(1.0 / 60.0)
        fishNode.setScale(1.0 + GameConfig.Effects.tapScaleAmount)

        scene.resetSandboxForTesting()

        #expect(scene.gameState == .ready)
        #expect(scene.fishVisualStateForTesting() == .stopped)
        #expect(scene.gameplayContainerPositionForTesting() == .zero)
        #expect(fishNode.zRotation == 0.0)
        #expect(fishNode.xScale == 1.0)
        #expect(fishNode.yScale == 1.0)
        #expect(physicsBody.isDynamic == false)
        #expect(physicsBody.isResting == true)
        #expect(physicsBody.velocity == .zero)
    }

    @Test func resetSandboxRestoresDifficultyToBaseline() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.setScoreForTesting(GameConfig.Obstacle.Difficulty.easyScoreThreshold + 8)

        #expect(scene.currentObstacleSpeedForTesting() > GameConfig.Obstacle.Difficulty.startingSpeed)
        #expect(scene.currentGapSizeForTesting() == GameConfig.Obstacle.Difficulty.startingGapSize)
        #expect(scene.currentObstacleSpawnIntervalForTesting() == GameConfig.Obstacle.Difficulty.spawnInterval)

        scene.resetSandboxForTesting()

        #expect(scene.score == 0)
        #expect(scene.currentObstacleSpeedForTesting() == GameConfig.Obstacle.Difficulty.startingSpeed)
        #expect(scene.currentGapSizeForTesting() == GameConfig.Obstacle.Difficulty.startingGapSize)
        #expect(scene.currentObstacleSpawnIntervalForTesting() == GameConfig.Obstacle.Difficulty.spawnInterval)
    }

    @Test func tapsDuringPlayingRestartBurstWithoutChangingPhysicsBodySize() async throws {
        let scene = makeScene(fishAnimationTextures: makeFishAnimationTextures())
        attachScene(scene)
        scene.handleTap()

        let fishNode = scene.fishNodeForTesting()
        let physicsBody = try #require(fishNode.physicsBody)

        scene.update(1.0 / 60.0)
        scene.update((1.0 / 60.0) + 1.0)
        #expect(scene.fishVisualStateForTesting() == .playingLoop)

        scene.handleTap()

        #expect(scene.fishVisualStateForTesting() == .swimBurst)
        #expect(fishNode.size == GameConfig.Fish.size)
        #expect(physicsBody.node === fishNode)
    }

    @Test func gameOverStopsAnimationAndPreservesCurrentFishTexture() async throws {
        let scene = makeScene(fishAnimationTextures: makeFishAnimationTextures())
        attachScene(scene)
        scene.handleTap()

        let fishNode = scene.fishNodeForTesting()
        let textureAtImpact = fishNode.texture

        scene.simulateFloorContactForTesting()

        #expect(scene.gameState == .gameOver)
        #expect(scene.fishVisualStateForTesting() == .stopped)
        #expect(scene.fishAnimationActionIsRunningForTesting() == false)
        #expect(fishNode.texture === textureAtImpact)
    }

    @Test func missingSwimTexturesKeepsTapBehaviorWorkingWithoutFrameAnimation() async throws {
        let scene = makeScene(
            fishAnimationTextures: makeFishAnimationTextures(idleFrameCount: 2, swimFrameCount: 1)
        )
        attachScene(scene)

        #expect(scene.fishHasIdleAnimationForTesting() == true)
        #expect(scene.fishHasSwimAnimationForTesting() == false)
        #expect(scene.fishVisualStateForTesting() == .readyIdle)

        scene.handleTap()

        let physicsBody = try #require(scene.fishNodeForTesting().physicsBody)
        #expect(scene.gameState == .playing)
        #expect(scene.fishVisualStateForTesting() == .stopped)
        #expect(scene.fishAnimationActionIsRunningForTesting() == false)
        #expect(physicsBody.velocity.dy > 0.0)
        #expect(scene.fishNodeForTesting().size == GameConfig.Fish.size)
    }

    @Test func partialTextureSetsOnlyEnableFullyAvailableModes() async throws {
        let scene = makeScene(
            fishAnimationTextures: makeFishAnimationTextures(idleFrameCount: 1, swimFrameCount: 2)
        )
        attachScene(scene)

        #expect(scene.fishHasIdleAnimationForTesting() == false)
        #expect(scene.fishHasSwimAnimationForTesting() == true)
        #expect(scene.fishVisualStateForTesting() == .stopped)
        #expect(scene.fishAnimationActionIsRunningForTesting() == false)

        scene.handleTap()

        #expect(scene.fishVisualStateForTesting() == .swimBurst)
    }

    @Test func obstaclesSpawnOnlyWhilePlaying() async throws {
        let scene = makeScene()
        attachScene(scene)

        scene.update(GameConfig.Obstacle.Difficulty.spawnInterval + 0.1)
        #expect(scene.obstaclePairNodesForTesting().isEmpty)

        scene.handleTap()
        scene.update((GameConfig.Obstacle.Difficulty.spawnInterval + 0.1) * 2.0)

        #expect(scene.obstaclePairNodesForTesting().count == 1)
    }

    @Test func spawnedObstaclePairUsesConfiguredGapRange() async throws {
        let scene = makeScene()
        attachScene(scene)

        let gapRange = scene.obstacleGapCenterYRangeForTesting()
        let gapCenterY = (gapRange.lowerBound + gapRange.upperBound) / 2.0
        scene.spawnObstaclePairForTesting(gapCenterY: gapCenterY)

        let pairNode = try #require(scene.obstaclePairNodesForTesting().first)
        let topNode = try #require(pairNode.childNode(withName: GameConfig.Obstacle.topNodeName))
        let bottomNode = try #require(pairNode.childNode(withName: GameConfig.Obstacle.bottomNodeName))
        let scoreZoneNode = try #require(pairNode.childNode(withName: GameConfig.Obstacle.scoreTriggerNodeName) as? SKSpriteNode)
        let topVisualNode = try obstacleSegmentVisualNode(topNode)
        let bottomVisualNode = try obstacleSegmentVisualNode(bottomNode)
        let topColliderNode = try obstacleSegmentColliderNode(topNode)
        let bottomColliderNode = try obstacleSegmentColliderNode(bottomNode)
        let measuredGapCenterY =
            ((bottomColliderNode.position.y + (bottomColliderNode.size.height / 2.0)) +
            (topColliderNode.position.y - (topColliderNode.size.height / 2.0))) / 2.0
        let measuredGapSize =
            (topColliderNode.position.y - (topColliderNode.size.height / 2.0)) -
            (bottomColliderNode.position.y + (bottomColliderNode.size.height / 2.0))
        let halfGap = GameConfig.Obstacle.Difficulty.startingGapSize / 2.0
        let expectedBottomVisualHeight = gapCenterY - halfGap - scene.frame.minY
        let expectedTopVisualHeight = scene.frame.maxY - (gapCenterY + halfGap)

        #expect(pairNode.name == GameConfig.Obstacle.pairNodeName)
        #expect(
            topVisualNode.size == CGSize(
                width: GameConfig.Obstacle.width,
                height: expectedTopVisualHeight
            )
        )
        #expect(
            bottomVisualNode.size == CGSize(
                width: GameConfig.Obstacle.width,
                height: expectedBottomVisualHeight
            )
        )
        #expect(topVisualNode.position.y == scene.frame.maxY + GameConfig.Obstacle.topVisualTuning.verticalOffset)
        #expect(bottomVisualNode.position.y == scene.frame.minY + GameConfig.Obstacle.bottomVisualTuning.verticalOffset)
        #expect(measuredGapCenterY >= gapRange.lowerBound)
        #expect(measuredGapCenterY <= gapRange.upperBound)
        #expect(measuredGapSize == GameConfig.Obstacle.Difficulty.startingGapSize)
        #expect(scoreZoneNode.position == CGPoint(x: 0.0, y: gapCenterY))
        #expect(scoreZoneNode.size == CGSize(width: GameConfig.Obstacle.scoreTriggerWidth, height: GameConfig.Obstacle.Difficulty.startingGapSize))
    }

    @Test func obstacleGapRangeTracksSceneFrameSafely() async throws {
        let scene = makeScene()
        attachScene(scene)

        let initialRange = scene.obstacleGapCenterYRangeForTesting()
        let halfGap = GameConfig.Obstacle.Difficulty.startingGapSize / 2.0

        #expect(initialRange.lowerBound == scene.frame.minY + halfGap + GameConfig.Obstacle.gapEdgeInset)
        #expect(initialRange.upperBound == scene.frame.maxY - halfGap - GameConfig.Obstacle.gapEdgeInset)

        scene.size = CGSize(width: 428.0, height: 926.0)

        let resizedRange = scene.obstacleGapCenterYRangeForTesting()

        #expect(resizedRange.lowerBound == scene.frame.minY + halfGap + GameConfig.Obstacle.gapEdgeInset)
        #expect(resizedRange.upperBound == scene.frame.maxY - halfGap - GameConfig.Obstacle.gapEdgeInset)
    }

    @Test func firstAllowedGapRangeStaysNearStartHeightAndExcludesExtremes() async throws {
        let scene = makeScene()
        attachScene(scene)

        let playableRange = scene.obstacleGapCenterYRangeForTesting()
        let allowedRange = scene.allowedGapCenterYRangeForNextSpawnForTesting()
        let startY = scene.currentStartPosition().y
        let safeBandHalfHeight = expectedProtectedOpeningHalfHeight(for: scene)
        let expectedRange = (startY - safeBandHalfHeight)...(startY + safeBandHalfHeight)

        #expect(allowedRange == expectedRange)
        #expect(allowedRange.lowerBound > playableRange.lowerBound)
        #expect(allowedRange.upperBound < playableRange.upperBound)
    }

    @Test func firstThreeSpawnWindowsRemainInsideProtectedOpeningBand() async throws {
        let scene = makeScene()
        attachScene(scene)

        let startY = scene.currentStartPosition().y
        let safeBandHalfHeight = expectedProtectedOpeningHalfHeight(for: scene)
        let openingBand = (startY - safeBandHalfHeight)...(startY + safeBandHalfHeight)

        for gapCenterY in [openingBand.upperBound, openingBand.lowerBound] {
            scene.spawnObstaclePairForTesting(gapCenterY: gapCenterY)
            let nextAllowedRange = scene.allowedGapCenterYRangeForNextSpawnForTesting()

            #expect(nextAllowedRange.lowerBound >= openingBand.lowerBound)
            #expect(nextAllowedRange.upperBound <= openingBand.upperBound)
        }

        scene.spawnObstaclePairForTesting(gapCenterY: startY)
        let fourthAllowedRange = scene.allowedGapCenterYRangeForNextSpawnForTesting()

        #expect(fourthAllowedRange.lowerBound < openingBand.lowerBound)
        #expect(fourthAllowedRange.upperBound > openingBand.upperBound)
    }

    @Test func laterSpawnWindowIsLimitedByGlobalGapJumpCap() async throws {
        let scene = makeScene()
        attachScene(scene)

        let playableRange = scene.obstacleGapCenterYRangeForTesting()
        let lastGapCenterY = playableRange.lowerBound
        let jumpBandHalfHeight = min(
            scene.currentGapSizeForTesting() * GameConfig.Obstacle.Generation.maximumGapStepGapMultiplier,
            scene.sceneLayoutMetricsForTesting().playableRect.height * GameConfig.Obstacle.Generation.maximumGapStepPlayableHeightMultiplier
        )
        let expectedRange = playableRange.lowerBound...(playableRange.lowerBound + jumpBandHalfHeight)

        let allowedRange = GameScene.allowedGapCenterYRange(
            playableRange: playableRange,
            startY: scene.currentStartPosition().y,
            maximumReachableDelta: jumpBandHalfHeight,
            spawnedObstaclePairCount: 3,
            lastGapCenterY: lastGapCenterY
        )

        #expect(allowedRange == expectedRange)
    }

    @Test func spawnWindowRemainsReachableAfterFifthSpawn() async throws {
        let scene = makeScene()
        attachScene(scene)

        let playableRange = scene.obstacleGapCenterYRangeForTesting()
        let jumpBandHalfHeight = min(
            scene.currentGapSizeForTesting() * GameConfig.Obstacle.Generation.maximumGapStepGapMultiplier,
            scene.sceneLayoutMetricsForTesting().playableRect.height * GameConfig.Obstacle.Generation.maximumGapStepPlayableHeightMultiplier
        )
        let allowedRange = GameScene.allowedGapCenterYRange(
            playableRange: playableRange,
            startY: scene.currentStartPosition().y,
            maximumReachableDelta: jumpBandHalfHeight,
            spawnedObstaclePairCount: 5,
            lastGapCenterY: playableRange.lowerBound
        )

        #expect(allowedRange == playableRange.lowerBound...(playableRange.lowerBound + jumpBandHalfHeight))
    }

    @Test func spawnedObstaclesMoveLeftAcrossUpdates() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.handleTap()
        scene.spawnObstaclePairForTesting(gapCenterY: scene.obstacleGapCenterYRangeForTesting().lowerBound)

        let pairNode = try #require(scene.obstaclePairNodesForTesting().first)
        let startX = pairNode.position.x

        scene.update(1.0)

        #expect(pairNode.position.x < startX)
    }

    @Test func spawnedObstacleSegmentsUseConfiguredPhysicsCategories() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.spawnObstaclePairForTesting(gapCenterY: scene.obstacleGapCenterYRangeForTesting().lowerBound)

        let pairNode = try #require(scene.obstaclePairNodesForTesting().first)
        let topNode = try #require(pairNode.childNode(withName: GameConfig.Obstacle.topNodeName))
        let bottomNode = try #require(pairNode.childNode(withName: GameConfig.Obstacle.bottomNodeName))
        let scoreZoneNode = try #require(pairNode.childNode(withName: GameConfig.Obstacle.scoreTriggerNodeName) as? SKSpriteNode)
        let topColliderNode = try obstacleSegmentColliderNode(topNode)
        let bottomColliderNode = try obstacleSegmentColliderNode(bottomNode)
        let topPhysicsBody = try #require(topColliderNode.physicsBody)
        let bottomPhysicsBody = try #require(bottomColliderNode.physicsBody)
        let scoreZonePhysicsBody = try #require(scoreZoneNode.physicsBody)

        #expect(topPhysicsBody.categoryBitMask == GameConfig.Physics.Category.obstacle)
        #expect(topPhysicsBody.collisionBitMask == GameConfig.Physics.Mask.obstacleCollision)
        #expect(topPhysicsBody.contactTestBitMask == GameConfig.Physics.Mask.obstacleContact)
        #expect(bottomPhysicsBody.categoryBitMask == GameConfig.Physics.Category.obstacle)
        #expect(bottomPhysicsBody.collisionBitMask == GameConfig.Physics.Mask.obstacleCollision)
        #expect(bottomPhysicsBody.contactTestBitMask == GameConfig.Physics.Mask.obstacleContact)
        #expect(scoreZonePhysicsBody.categoryBitMask == GameConfig.Physics.Category.scoreTrigger)
        #expect(scoreZonePhysicsBody.collisionBitMask == 0)
        #expect(scoreZonePhysicsBody.contactTestBitMask == GameConfig.Physics.Mask.scoreTriggerContact)
    }

    @Test func spawnedObstacleVisualsExtendToFullSceneBounds() async throws {
        let scene = makeScene()
        attachScene(scene)

        let gapCenterY = scene.obstacleGapCenterYRangeForTesting().lowerBound
        scene.spawnObstaclePairForTesting(gapCenterY: gapCenterY)

        let pairNode = try #require(scene.obstaclePairNodesForTesting().first)
        let topNode = try #require(pairNode.childNode(withName: GameConfig.Obstacle.topNodeName))
        let bottomNode = try #require(pairNode.childNode(withName: GameConfig.Obstacle.bottomNodeName))
        let topVisualNode = try obstacleSegmentVisualNode(topNode)
        let bottomVisualNode = try obstacleSegmentVisualNode(bottomNode)

        #expect(bottomVisualNode.frame.minY <= scene.frame.minY)
        #expect(topVisualNode.frame.maxY >= scene.frame.maxY)
    }

    @Test func obstacleVisualTuningDoesNotChangeColliderCoverage() async throws {
        let scene = makeScene()
        attachScene(scene)

        let gapRange = scene.obstacleGapCenterYRangeForTesting()
        let gapCenterY = (gapRange.lowerBound + gapRange.upperBound) / 2.0
        scene.spawnObstaclePairForTesting(gapCenterY: gapCenterY)

        let pairNode = try #require(scene.obstaclePairNodesForTesting().first)
        let topNode = try #require(pairNode.childNode(withName: GameConfig.Obstacle.topNodeName))
        let bottomNode = try #require(pairNode.childNode(withName: GameConfig.Obstacle.bottomNodeName))
        let topVisualNode = try obstacleSegmentVisualNode(topNode)
        let bottomVisualNode = try obstacleSegmentVisualNode(bottomNode)
        let topColliderNode = try obstacleSegmentColliderNode(topNode)
        let bottomColliderNode = try obstacleSegmentColliderNode(bottomNode)

        #expect(topVisualNode.size.width > topColliderNode.size.width)
        #expect(bottomVisualNode.size.width > bottomColliderNode.size.width)
        #expect(
            topColliderNode.size.width ==
            GameConfig.Obstacle.width - (GameConfig.Obstacle.topVisualTuning.colliderHorizontalInset * 2.0)
        )
        #expect(
            bottomColliderNode.size.width ==
            GameConfig.Obstacle.width - (GameConfig.Obstacle.bottomVisualTuning.colliderHorizontalInset * 2.0)
        )
        #expect(topVisualNode.size.height > topColliderNode.size.height)
        #expect(bottomVisualNode.size.height > bottomColliderNode.size.height)
    }

    @Test func obstacleVisualsDoNotIntrudeIntoGap() async throws {
        let scene = makeScene()
        attachScene(scene)

        let gapRange = scene.obstacleGapCenterYRangeForTesting()
        let gapCenterY = (gapRange.lowerBound + gapRange.upperBound) / 2.0
        scene.spawnObstaclePairForTesting(gapCenterY: gapCenterY)

        let pairNode = try #require(scene.obstaclePairNodesForTesting().first)
        let topNode = try #require(pairNode.childNode(withName: GameConfig.Obstacle.topNodeName))
        let bottomNode = try #require(pairNode.childNode(withName: GameConfig.Obstacle.bottomNodeName))
        let topVisualNode = try obstacleSegmentVisualNode(topNode)
        let bottomVisualNode = try obstacleSegmentVisualNode(bottomNode)

        let topVisualFrame = topVisualNode.calculateAccumulatedFrame()
        let bottomVisualFrame = bottomVisualNode.calculateAccumulatedFrame()
        let halfGap = scene.currentGapSizeForTesting() / 2.0
        let expectedTopGapEdge = gapCenterY + halfGap
        let expectedBottomGapEdge = gapCenterY - halfGap
        let tolerance: CGFloat = 0.5

        #expect(abs(topVisualFrame.minY - expectedTopGapEdge) <= tolerance)
        #expect(abs(bottomVisualFrame.maxY - expectedBottomGapEdge) <= tolerance)
    }

    @Test func spawnedObstacleCollidersRemainInsidePlayableBounds() async throws {
        let scene = makeScene()
        attachScene(scene)

        let gapCenterY = scene.obstacleGapCenterYRangeForTesting().lowerBound
        scene.spawnObstaclePairForTesting(gapCenterY: gapCenterY)

        let pairNode = try #require(scene.obstaclePairNodesForTesting().first)
        let metrics = scene.sceneLayoutMetricsForTesting()
        let topNode = try #require(pairNode.childNode(withName: GameConfig.Obstacle.topNodeName))
        let bottomNode = try #require(pairNode.childNode(withName: GameConfig.Obstacle.bottomNodeName))
        let topColliderNode = try obstacleSegmentColliderNode(topNode)
        let bottomColliderNode = try obstacleSegmentColliderNode(bottomNode)
        let topColliderFrame = topColliderNode.calculateAccumulatedFrame()
        let bottomColliderFrame = bottomColliderNode.calculateAccumulatedFrame()

        #expect(bottomColliderFrame.minY > metrics.playableRect.minY)
        #expect(topColliderFrame.maxY < metrics.playableRect.maxY)
    }

    @Test func offscreenObstaclesAreRemoved() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.handleTap()
        scene.spawnObstaclePairForTesting(gapCenterY: scene.obstacleGapCenterYRangeForTesting().lowerBound)

        let pairNode = try #require(scene.obstaclePairNodesForTesting().first)
        pairNode.position.x = scene.frame.minX - pairNode.calculateAccumulatedFrame().width

        scene.update(1.0 / 60.0)

        #expect(scene.obstaclePairNodesForTesting().isEmpty)
    }

    @Test func obstaclesRemainVisibleUntilTheirRenderedBoundsExitScreen() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.handleTap()
        scene.spawnObstaclePairForTesting(gapCenterY: scene.obstacleGapCenterYRangeForTesting().lowerBound)

        let pairNode = try #require(scene.obstaclePairNodesForTesting().first)
        let pairFrame = pairNode.calculateAccumulatedFrame()

        let fixedWidthRemovalX = scene.frame.minX - (GameConfig.Obstacle.width / 2.0) - 1.0
        let stillVisibleX = scene.frame.minX - pairFrame.maxX + 1.0

        #expect(fixedWidthRemovalX < stillVisibleX)

        pairNode.position.x = fixedWidthRemovalX
        #expect(pairNode.calculateAccumulatedFrame().maxX > scene.frame.minX)

        scene.update(1.0 / 60.0)

        #expect(scene.obstaclePairNodesForTesting().count == 1)

        pairNode.position.x = scene.frame.minX - pairNode.calculateAccumulatedFrame().maxX - 1.0
        #expect(pairNode.calculateAccumulatedFrame().maxX < scene.frame.minX)

        scene.update(1.0 / 60.0)

        #expect(scene.obstaclePairNodesForTesting().isEmpty)
    }

    @Test func resetClearsObstaclesAndStopsFutureSpawnsUntilRestart() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.handleTap()
        scene.spawnObstaclePairForTesting(gapCenterY: scene.obstacleGapCenterYRangeForTesting().upperBound)

        #expect(scene.obstaclePairNodesForTesting().count == 1)

        scene.triggerGameOverForTesting()
        scene.handleTap()

        #expect(scene.gameState == .ready)
        #expect(scene.obstaclePairNodesForTesting().isEmpty)

        scene.update(GameConfig.Obstacle.Difficulty.spawnInterval + 0.2)

        #expect(scene.obstaclePairNodesForTesting().isEmpty)
    }

    @Test func tapAfterGameOverDoesNotResumePhysicsUntilNextTap() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.handleTap()

        let fishNode = try #require(scene.childNode(withName: GameConfig.Fish.nodeName) as? SKSpriteNode)
        let physicsBody = try #require(fishNode.physicsBody)

        scene.simulateObstacleContactForTesting()
        scene.handleTap()

        #expect(scene.gameState == .ready)
        #expect(physicsBody.isDynamic == false)
        #expect(physicsBody.isResting == true)
        #expect(physicsBody.velocity == .zero)
        #expect(scene.obstaclePairNodesForTesting().isEmpty)

        scene.handleTap()

        #expect(scene.gameState == .playing)
        #expect(physicsBody.isDynamic == true)
        #expect(physicsBody.velocity.dy > 0.0)
    }

    @Test func obstacleContactTriggersGameOver() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.handleTap()

        scene.simulateObstacleContactForTesting()

        #expect(scene.gameState == .gameOver)
    }

    @Test func repeatedLethalContactsOnlyTriggerGameOverOnce() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.handleTap()

        scene.simulateObstacleContactForTesting()
        scene.simulateFloorContactForTesting()
        scene.simulateObstacleContactForTesting()

        #expect(scene.gameState == .gameOver)
        #expect(scene.score == 0)
        #expect(scene.deathBurstNodesForTesting().count == 1)
    }

    @Test func gameOverStopsObstacleMovementAndFutureSpawns() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.handleTap()
        scene.spawnObstaclePairForTesting(gapCenterY: scene.obstacleGapCenterYRangeForTesting().lowerBound)

        let pairNode = try #require(scene.obstaclePairNodesForTesting().first)
        let frozenX = pairNode.position.x

        scene.simulateObstacleContactForTesting()
        scene.update(GameConfig.Obstacle.Difficulty.spawnInterval + 0.5)

        #expect(scene.gameState == .gameOver)
        #expect(scene.obstaclePairNodesForTesting().count == 1)
        #expect(pairNode.position.x == frozenX)
    }

    @Test func gameOverShakeResetsOnNextTap() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.handleTap()

        scene.simulateObstacleContactForTesting()

        #expect(scene.gameplayContainerPositionForTesting() == .zero)

        scene.handleTap()

        #expect(scene.gameState == .ready)
        #expect(scene.gameplayContainerPositionForTesting() == .zero)
    }

    @Test func scoreZoneContactIncrementsScoreAndUpdatesLabel() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.handleTap()
        scene.spawnObstaclePairForTesting(gapCenterY: scene.obstacleGapCenterYRangeForTesting().lowerBound)

        scene.simulateScoreZoneContactForTesting()

        #expect(scene.score == 1)
        #expect(scene.scoreLabelNodeForTesting().text == "1")
    }

    @Test func scoreZoneDoesNotDoubleScore() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.handleTap()
        scene.spawnObstaclePairForTesting(gapCenterY: scene.obstacleGapCenterYRangeForTesting().lowerBound)

        scene.simulateScoreZoneContactForTesting()
        scene.simulateScoreZoneContactForTesting()

        #expect(scene.score == 1)
    }

    @Test func separateScoreZonesIncrementCumulatively() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.handleTap()
        let gapRange = scene.obstacleGapCenterYRangeForTesting()
        scene.spawnObstaclePairForTesting(gapCenterY: gapRange.lowerBound)
        scene.spawnObstaclePairForTesting(gapCenterY: gapRange.upperBound)

        scene.simulateScoreZoneContactForTesting(at: 0)
        scene.simulateScoreZoneContactForTesting(at: 1)

        #expect(scene.score == 2)
        #expect(scene.scoreLabelNodeForTesting().text == "2")
    }

    @Test func obstacleContactDoesNotChangeScore() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.handleTap()
        scene.spawnObstaclePairForTesting(gapCenterY: scene.obstacleGapCenterYRangeForTesting().lowerBound)

        scene.simulateObstacleContactForTesting()

        #expect(scene.gameState == .gameOver)
        #expect(scene.score == 0)
        #expect(scene.scoreLabelNodeForTesting().text == "0")
    }

    @Test func lethalCollisionPreventsScoreFromIncrementing() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.handleTap()
        scene.spawnObstaclePairForTesting(gapCenterY: scene.obstacleGapCenterYRangeForTesting().lowerBound)

        scene.simulateScoreZoneContactDuringLethalCollisionForTesting()

        #expect(scene.gameState == .gameOver)
        #expect(scene.score == 0)
        #expect(scene.scoreLabelNodeForTesting().text == "0")
    }

    @Test func restartResetsScoreToZero() async throws {
        let scene = makeScene()
        attachScene(scene)
        scene.handleTap()
        scene.spawnObstaclePairForTesting(gapCenterY: scene.obstacleGapCenterYRangeForTesting().lowerBound)
        scene.simulateScoreZoneContactForTesting()

        scene.triggerGameOverForTesting()
        scene.handleTap()

        #expect(scene.gameState == .ready)
        #expect(scene.score == 0)
        #expect(scene.scoreLabelNodeForTesting().text == "0")
    }

    @Test func restartResetsProtectedOpeningGeneratorState() async throws {
        let scene = makeScene()
        attachScene(scene)

        let initialAllowedRange = scene.allowedGapCenterYRangeForNextSpawnForTesting()

        scene.handleTap()
        scene.spawnObstaclePairForTesting(gapCenterY: initialAllowedRange.upperBound)

        let constrainedFollowupRange = scene.allowedGapCenterYRangeForNextSpawnForTesting()
        #expect(constrainedFollowupRange != initialAllowedRange)

        scene.triggerGameOverForTesting()
        scene.handleTap()

        #expect(scene.gameState == .ready)
        #expect(scene.allowedGapCenterYRangeForNextSpawnForTesting() == initialAllowedRange)
    }

}
