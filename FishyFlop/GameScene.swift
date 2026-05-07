//
//  GameScene.swift
//  FishyFlop
//
//  Created by Polina on 2026-04-28.
//

import SpriteKit
import UIKit

enum GameState {
    case ready
    case playing
    case gameOver
}

struct FishAnimationTextures {
    let idle: [SKTexture]
    let swim: [SKTexture]
    let dead: SKTexture?

    var initialTexture: SKTexture? {
        idle.first
    }

    var hasIdleAnimation: Bool {
        idle.count == 2
    }

    var hasSwimAnimation: Bool {
        swim.count == 2
    }

    static func loadFromAssets() -> FishAnimationTextures {
        let mainFishTexture = SpriteAssetLoader.textureIfAvailable(named: GameConfig.Assets.mainFish)
        return FishAnimationTextures(
            idle: mainFishTexture.map { [$0] } ?? [],
            swim: mainFishTexture.map { [$0] } ?? [],
            dead: SpriteAssetLoader.textureIfAvailable(named: GameConfig.Assets.deadFish)
        )
    }
}

enum FishVisualState {
    case readyIdle
    case playingLoop
    case swimBurst
    case stopped
}

final class GameScene: SKScene, SKPhysicsContactDelegate {
    struct SceneLayoutMetrics: Equatable {
        let sceneFrame: CGRect
        let safeAreaInsets: UIEdgeInsets
        let playableRect: CGRect
    }

    private enum ActionKey {
        static let tapScale = "tapScale"
        static let fishFrameAnimation = "fishFrameAnimation"
        static let collisionShake = "collisionShake"
    }

    private enum DebugLineWidth {
        static let worldBounds: CGFloat = GameConfig.Debug.strokeWidth
    }

    private enum ObstacleSegmentNodeName {
        static let visual = "visual"
        static let collider = "collider"
    }

    private let fishNode: SKSpriteNode
    private let fishAnimationTextures: FishAnimationTextures
    private let backgroundNode = SKNode()
    private let backgroundSpriteNode: SKSpriteNode
    private let gameplayNode = SKNode()
    private let floorNode = SKNode()
    private let ceilingNode = SKNode()
    private let obstacleLayer = SKNode()
    private let scoreLabelNode = SKLabelNode(fontNamed: GameConfig.HUD.ScoreLabel.fontName)
    private let readyLabelNode = SKLabelNode(fontNamed: GameConfig.HUD.Overlay.fontName)
    private let gameOverTitleLabelNode = SKLabelNode(fontNamed: GameConfig.HUD.Overlay.fontName)
    private let gameOverSubtitleLabelNode = SKLabelNode(fontNamed: GameConfig.HUD.Overlay.fontName)
    private(set) var gameState: GameState = .ready
    private(set) var score: Int = 0
    private var fishVisualState: FishVisualState = .stopped
    private var gameOverTransitionCount: Int = 0
    private var targetFishRotation: CGFloat = 0.0
    private var lastUpdateTime: TimeInterval?
    private var obstacleSpawnAccumulator: TimeInterval = 0.0
    private var remainingSwimBurstDuration: TimeInterval = 0.0
    private var spawnedObstaclePairCount: Int = 0
    private var lastSpawnedGapCenterY: CGFloat?
    private var sceneLayoutMetrics = SceneLayoutMetrics(
        sceneFrame: CGRect(origin: .zero, size: GameConfig.Scene.initialSize),
        safeAreaInsets: .zero,
        playableRect: CGRect(origin: .zero, size: GameConfig.Scene.initialSize)
    )
    private var safeAreaInsetsOverride: UIEdgeInsets?

    override init(size: CGSize) {
        let fishAnimationTextures = FishAnimationTextures.loadFromAssets()
        self.fishAnimationTextures = fishAnimationTextures
        fishNode = GameScene.makeFishNode(initialTexture: fishAnimationTextures.initialTexture)
        backgroundSpriteNode = GameScene.makeBackgroundSpriteNode()
        super.init(size: size)
        configureScene()
    }

    init(size: CGSize, fishAnimationTextures: FishAnimationTextures) {
        self.fishAnimationTextures = fishAnimationTextures
        fishNode = GameScene.makeFishNode(initialTexture: fishAnimationTextures.initialTexture)
        backgroundSpriteNode = GameScene.makeBackgroundSpriteNode()
        super.init(size: size)
        configureScene()
    }

    override convenience init() {
        self.init(size: GameConfig.Scene.initialSize)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        attachRuntimeNodesIfNeeded()

        updateSceneLayoutMetrics()
        configureWorldBounds()
        configureBackground()
        configureScoreLabel()
        configureOverlayLabels()
        resetSandbox()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)

        updateSceneLayoutMetrics()
        configureWorldBounds()
        layoutInterface()

        if gameState == .ready {
            resetFishPosition()
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)

        guard !touches.isEmpty else {
            return
        }

        handleTap()
    }

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)

        refreshSceneLayoutIfNeeded()

        guard gameState == .playing else {
            lastUpdateTime = currentTime
            return
        }

        let deltaTime: TimeInterval
        if let lastUpdateTime {
            deltaTime = min(max(currentTime - lastUpdateTime, 0.0), 1.0 / 15.0)
        } else {
            deltaTime = 1.0 / 60.0
        }

        lastUpdateTime = currentTime
        clampFishFallSpeed()
        updateObstacles(deltaTime: deltaTime)
        updateFishVisualState(deltaTime: deltaTime)
        updateFishRotation(deltaTime: deltaTime)
    }

    private func configureScene() {
        scaleMode = GameConfig.Scene.scaleMode
        backgroundColor = GameConfig.Background.fallbackColor
        applyCurrentMotionTuning()
        physicsWorld.contactDelegate = self
    }

    private func applyCurrentMotionTuning() {
        physicsWorld.gravity = effectiveGravity()
    }

    private func motionScale() -> CGFloat {
        let referenceHeight = GameConfig.Fish.Motion.referencePlayableHeight
        guard referenceHeight > 0.0 else {
            return 1.0
        }

        return playableRect.height / referenceHeight
    }

    private func effectiveGravity() -> CGVector {
        CGVector(dx: 0.0, dy: GameConfig.Fish.Motion.gravityStrength * motionScale())
    }

    private func effectiveFlapImpulse() -> CGFloat {
        GameConfig.Fish.Motion.flapImpulse * motionScale()
    }

    private func effectiveFlapImpulseVector() -> CGVector {
        CGVector(dx: 0.0, dy: effectiveFlapImpulse())
    }

    private func effectiveMaxFallSpeed() -> CGFloat {
        GameConfig.Fish.Motion.maxFallSpeed * motionScale()
    }

    private func attachRuntimeNodesIfNeeded() {
        attachNodeIfNeeded(backgroundNode, to: self)
        attachNodeIfNeeded(backgroundSpriteNode, to: backgroundNode)
        attachNodeIfNeeded(gameplayNode, to: self)
        attachNodeIfNeeded(fishNode, to: gameplayNode)
        attachNodeIfNeeded(obstacleLayer, to: gameplayNode)
        attachNodeIfNeeded(scoreLabelNode, to: self)
        attachNodeIfNeeded(readyLabelNode, to: self)
        attachNodeIfNeeded(gameOverTitleLabelNode, to: self)
        attachNodeIfNeeded(gameOverSubtitleLabelNode, to: self)
    }

    private func attachNodeIfNeeded(_ node: SKNode, to parent: SKNode) {
        guard node.parent == nil else {
            return
        }

        parent.addChild(node)
    }

    private func configureBackground() {
        backgroundNode.name = GameConfig.Background.nodeName
        backgroundNode.zPosition = GameConfig.Background.zPosition
        backgroundSpriteNode.name = GameConfig.Background.spriteNodeName
        layoutBackground()
    }

    private func configureScoreLabel() {
        scoreLabelNode.name = GameConfig.HUD.ScoreLabel.nodeName
        scoreLabelNode.fontSize = GameConfig.HUD.ScoreLabel.fontSize
        scoreLabelNode.fontColor = GameConfig.HUD.ScoreLabel.fontColor
        scoreLabelNode.zPosition = GameConfig.HUD.ScoreLabel.zPosition
        scoreLabelNode.verticalAlignmentMode = .center
        scoreLabelNode.horizontalAlignmentMode = .center
        layoutScoreLabel()
        updateScoreDisplay()
    }

    private func configureOverlayLabels() {
        configureOverlayLabel(
            readyLabelNode,
            name: GameConfig.HUD.Overlay.readyNodeName,
            text: GameConfig.HUD.Overlay.readyText,
            fontSize: GameConfig.HUD.Overlay.readyFontSize
        )
        configureOverlayLabel(
            gameOverTitleLabelNode,
            name: GameConfig.HUD.Overlay.gameOverTitleNodeName,
            text: GameConfig.HUD.Overlay.gameOverTitleText,
            fontSize: GameConfig.HUD.Overlay.gameOverTitleFontSize
        )
        configureOverlayLabel(
            gameOverSubtitleLabelNode,
            name: GameConfig.HUD.Overlay.gameOverSubtitleNodeName,
            text: GameConfig.HUD.Overlay.gameOverSubtitleText,
            fontSize: GameConfig.HUD.Overlay.gameOverSubtitleFontSize
        )
        layoutInterface()
        updateOverlayVisibility()
    }

    private func configureOverlayLabel(_ labelNode: SKLabelNode, name: String, text: String, fontSize: CGFloat) {
        labelNode.name = name
        labelNode.text = text
        labelNode.fontSize = fontSize
        labelNode.fontColor = GameConfig.HUD.Overlay.fontColor
        labelNode.zPosition = GameConfig.HUD.Overlay.zPosition
        labelNode.verticalAlignmentMode = .center
        labelNode.horizontalAlignmentMode = .center
    }

    private func layoutInterface() {
        layoutBackground()
        layoutScoreLabel()
        layoutOverlayLabels()
    }

    private func layoutBackground() {
        backgroundNode.position = .zero
        backgroundSpriteNode.position = CGPoint(x: frame.midX, y: frame.midY)
        backgroundSpriteNode.zPosition = 0.0

        if let texture = backgroundSpriteNode.texture {
            backgroundSpriteNode.size = Self.aspectFillSize(
                textureSize: texture.size(),
                containerSize: frame.size
            )
        } else {
            backgroundSpriteNode.size = frame.size
        }
    }

    private func layoutScoreLabel() {
        scoreLabelNode.position = CGPoint(
            x: playableRect.midX,
            y: playableRect.maxY - GameConfig.HUD.scoreTopPadding
        )
    }

    private func layoutOverlayLabels() {
        let readyCenterPoint = CGPoint(x: playableRect.midX, y: playableRect.midY)
        let verticalSpacing = max(
            playableRect.height * GameConfig.HUD.overlayVerticalSpacingRatio,
            GameConfig.HUD.Overlay.minimumVerticalSpacing
        )
        let gameOverCenterPoint = CGPoint(
            x: playableRect.midX,
            y: playableRect.minY + (playableRect.height * GameConfig.HUD.Overlay.gameOverCenterYRatio)
        )

        readyLabelNode.position = readyCenterPoint
        gameOverTitleLabelNode.position = CGPoint(
            x: gameOverCenterPoint.x,
            y: gameOverCenterPoint.y + (verticalSpacing / 2.0)
        )
        gameOverSubtitleLabelNode.position = CGPoint(
            x: gameOverCenterPoint.x,
            y: gameOverCenterPoint.y - (verticalSpacing / 2.0)
        )

        if gameState == .gameOver {
            layoutDeadFish()
        }
    }

    private func updateOverlayVisibility() {
        switch gameState {
        case .ready:
            readyLabelNode.isHidden = false
            gameOverTitleLabelNode.isHidden = true
            gameOverSubtitleLabelNode.isHidden = true
        case .playing:
            readyLabelNode.isHidden = true
            gameOverTitleLabelNode.isHidden = true
            gameOverSubtitleLabelNode.isHidden = true
        case .gameOver:
            readyLabelNode.isHidden = true
            gameOverTitleLabelNode.isHidden = false
            gameOverSubtitleLabelNode.isHidden = false
        }
    }

    private func configureWorldBounds() {
        configureBoundNode(
            floorNode,
            name: GameConfig.World.floorNodeName,
            from: CGPoint(x: playableRect.minX, y: playableRect.minY),
            to: CGPoint(x: playableRect.maxX, y: playableRect.minY)
        )
        configureBoundNode(
            ceilingNode,
            name: GameConfig.World.ceilingNodeName,
            from: CGPoint(x: playableRect.minX, y: playableRect.maxY),
            to: CGPoint(x: playableRect.maxX, y: playableRect.maxY)
        )
    }

    private func configureBoundNode(_ node: SKNode, name: String, from start: CGPoint, to end: CGPoint) {
        let isFloor = name == GameConfig.World.floorNodeName
        node.name = name
        node.physicsBody = SKPhysicsBody(edgeFrom: start, to: end)
        Self.configurePhysicsBody(
            node.physicsBody,
            isDynamic: false,
            affectedByGravity: nil,
            allowsRotation: nil,
            category: isFloor ? GameConfig.Physics.Category.floor : GameConfig.Physics.Category.ceiling,
            collision: isFloor ? GameConfig.Physics.Mask.floorCollision : GameConfig.Physics.Mask.ceilingCollision,
            contact: isFloor ? GameConfig.Physics.Mask.floorContact : GameConfig.Physics.Mask.ceilingContact
        )
        attachDebugLineIfNeeded(
            to: node,
            from: start,
            to: end,
            color: GameConfig.Debug.worldColor,
            lineWidth: DebugLineWidth.worldBounds
        )
        attachNodeIfNeeded(node, to: self)
    }

    private static func configurePhysicsBody(
        _ physicsBody: SKPhysicsBody?,
        isDynamic: Bool,
        affectedByGravity: Bool?,
        allowsRotation: Bool?,
        category: UInt32,
        collision: UInt32,
        contact: UInt32
    ) {
        physicsBody?.isDynamic = isDynamic
        if let affectedByGravity {
            physicsBody?.affectedByGravity = affectedByGravity
        }
        if let allowsRotation {
            physicsBody?.allowsRotation = allowsRotation
        }
        physicsBody?.categoryBitMask = category
        physicsBody?.collisionBitMask = collision
        physicsBody?.contactTestBitMask = contact
    }

    private func resetFishPosition() {
        fishNode.position = currentStartPosition()
    }

    private func resetSandbox() {
        gameState = .ready
        resetTransientGameplayState()
        resetFishForReadyState()
        clearObstacles()
        updateScoreDisplay()
        updateOverlayVisibility()
    }

    private static func makeFishNode(initialTexture: SKTexture?) -> SKSpriteNode {
        let spriteNode: SKSpriteNode
        if let initialTexture {
            spriteNode = SKSpriteNode(texture: initialTexture, color: .clear, size: GameConfig.Fish.size)
        } else {
            spriteNode = SpriteAssetLoader.makeSpriteNode(
                assetName: GameConfig.Fish.defaultAssetName,
                fallbackColor: GameConfig.Fish.placeholderColor,
                size: GameConfig.Fish.size
            )
        }
        spriteNode.name = GameConfig.Fish.nodeName
        spriteNode.zPosition = GameConfig.Fish.zPosition
        spriteNode.physicsBody = SKPhysicsBody(rectangleOf: GameConfig.Fish.hitboxSize)
        configurePhysicsBody(
            spriteNode.physicsBody,
            isDynamic: false,
            affectedByGravity: true,
            allowsRotation: false,
            category: GameConfig.Physics.Category.fish,
            collision: GameConfig.Physics.Mask.fishCollision,
            contact: GameConfig.Physics.Mask.fishLethalContact
        )
        attachDebugRectIfNeeded(
            to: spriteNode,
            size: GameConfig.Fish.hitboxSize,
            color: GameConfig.Debug.fishColor
        )
        return spriteNode
    }

    private static func makeBackgroundSpriteNode() -> SKSpriteNode {
        let spriteNode = SpriteAssetLoader.makeSpriteNode(
            assetName: GameConfig.Background.assetName,
            fallbackColor: GameConfig.Background.fallbackColor,
            size: GameConfig.Scene.initialSize
        )
        spriteNode.name = GameConfig.Background.spriteNodeName
        return spriteNode
    }

    private static func aspectFillSize(textureSize: CGSize, containerSize: CGSize) -> CGSize {
        guard textureSize.width > 0.0,
              textureSize.height > 0.0,
              containerSize.width > 0.0,
              containerSize.height > 0.0
        else {
            return containerSize
        }

        let widthScale = containerSize.width / textureSize.width
        let heightScale = containerSize.height / textureSize.height
        let scale = max(widthScale, heightScale)

        return CGSize(
            width: textureSize.width * scale,
            height: textureSize.height * scale
        )
    }

    func handleTap() {
        switch gameState {
        case .ready:
            startPlaying()
            flapFish()
        case .playing:
            flapFish()
        case .gameOver:
            resetSandbox()
        }
    }

    func currentStartPosition() -> CGPoint {
        CGPoint(
            x: playableRect.minX + (playableRect.width * GameConfig.Fish.startPosition.x),
            y: playableRect.minY + (playableRect.height * GameConfig.Fish.startPosition.y)
        )
    }

    func sceneLayoutMetricsForTesting() -> SceneLayoutMetrics {
        sceneLayoutMetrics
    }

    func setSafeAreaInsetsForTesting(_ insets: UIEdgeInsets) {
        safeAreaInsetsOverride = insets
        updateSceneLayoutMetrics()
        configureWorldBounds()
        layoutInterface()

        if gameState == .ready {
            resetFishPosition()
        }
    }

    func resetSandboxForTesting() {
        resetSandbox()
    }

    func triggerGameOverForTesting() {
        enterGameOver()
    }

    func obstaclePairNodesForTesting() -> [SKNode] {
        obstacleLayer.children
    }

    func scoreLabelNodeForTesting() -> SKLabelNode {
        scoreLabelNode
    }

    func readyLabelNodeForTesting() -> SKLabelNode {
        readyLabelNode
    }

    func gameOverTitleLabelNodeForTesting() -> SKLabelNode {
        gameOverTitleLabelNode
    }

    func gameOverSubtitleLabelNodeForTesting() -> SKLabelNode {
        gameOverSubtitleLabelNode
    }

    func gameplayContainerPositionForTesting() -> CGPoint {
        gameplayNode.position
    }

    func gameplayNodeForTesting() -> SKNode {
        gameplayNode
    }

    func backgroundNodeForTesting() -> SKNode {
        backgroundNode
    }

    func backgroundSpriteNodeForTesting() -> SKSpriteNode {
        backgroundSpriteNode
    }

    static func backgroundAspectFillSizeForTesting(textureSize: CGSize, containerSize: CGSize) -> CGSize {
        aspectFillSize(textureSize: textureSize, containerSize: containerSize)
    }

    func currentObstacleSpeedForTesting() -> CGFloat {
        currentObstacleSpeed()
    }

    func currentGapSizeForTesting() -> CGFloat {
        currentGapSize()
    }

    func currentObstacleSpawnIntervalForTesting() -> TimeInterval {
        currentObstacleSpawnInterval()
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
        fishNode
    }

    func fishHasIdleAnimationForTesting() -> Bool {
        fishAnimationTextures.hasIdleAnimation
    }

    func fishHasSwimAnimationForTesting() -> Bool {
        fishAnimationTextures.hasSwimAnimation
    }

    func fishAnimationActionIsRunningForTesting() -> Bool {
        fishNode.action(forKey: ActionKey.fishFrameAnimation) != nil
    }

    func fishVisualStateForTesting() -> FishVisualState {
        fishVisualState
    }

    func gameOverTransitionCountForTesting() -> Int {
        gameOverTransitionCount
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
        score = value
        updateScoreDisplay()
    }

    func spawnObstaclePairForTesting(gapCenterY: CGFloat) {
        spawnObstaclePair(gapCenterY: gapCenterY)
    }

    func obstacleGapCenterYRangeForTesting() -> ClosedRange<CGFloat> {
        obstacleGapCenterYRange()
    }

    func allowedGapCenterYRangeForNextSpawnForTesting() -> ClosedRange<CGFloat> {
        allowedGapCenterYRangeForNextSpawn()
    }

    func simulateObstacleContactForTesting() {
        handleContact(categoryMask: GameConfig.Physics.Category.fish | GameConfig.Physics.Category.obstacle)
    }

    func simulateFloorContactForTesting() {
        handleContact(categoryMask: GameConfig.Physics.Category.fish | GameConfig.Physics.Category.floor)
    }

    func simulateCeilingContactForTesting() {
        handleContact(categoryMask: GameConfig.Physics.Category.fish | GameConfig.Physics.Category.ceiling)
    }

    func simulateScoreZoneContactForTesting(at index: Int = 0) {
        guard obstacleLayer.children.indices.contains(index),
              let scoreZone = obstacleLayer.children[index].childNode(withName: GameConfig.Obstacle.scoreTriggerNodeName)
        else {
            return
        }

        handleScoreContact(with: scoreZone)
    }

    func simulateScoreZoneContactDuringLethalCollisionForTesting(at index: Int = 0) {
        guard obstacleLayer.children.indices.contains(index),
              let scoreZone = obstacleLayer.children[index].childNode(withName: GameConfig.Obstacle.scoreTriggerNodeName)
        else {
            return
        }

        handleScoreContact(with: scoreZone, lethalCollisionActive: true)
    }

    func didBegin(_ contact: SKPhysicsContact) {
        guard gameState == .playing else {
            return
        }

        let categoryMask = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        if isLethalContact(categoryMask) {
            handleContact(categoryMask: categoryMask)
            return
        }

        if handleScoreContact(contact) {
            return
        }
        handleContact(categoryMask: categoryMask)
    }

    private func startPlaying() {
        gameState = .playing
        lastUpdateTime = nil
        obstacleSpawnAccumulator = 0.0
        fishNode.physicsBody?.isDynamic = true
        fishNode.physicsBody?.isResting = false
        updateOverlayVisibility()
    }

    private func flapFish() {
        guard let physicsBody = fishNode.physicsBody else {
            return
        }

        physicsBody.velocity = CGVector(dx: physicsBody.velocity.dx, dy: 0.0)
        targetFishRotation = GameConfig.Fish.Motion.maxUpRotation
        physicsBody.applyImpulse(effectiveFlapImpulseVector())
        runTapScaleBounce()
        playSwimBurstAnimation()
    }

    private func enterGameOver() {
        guard gameState == .playing else {
            return
        }

        gameState = .gameOver
        gameOverTransitionCount += 1
        freezeGameplay()
        runCollisionShake()
        updateOverlayVisibility()
        layoutDeadFish()
    }

    private func resetTransientGameplayState() {
        score = 0
        gameOverTransitionCount = 0
        lastUpdateTime = nil
        obstacleSpawnAccumulator = 0.0
        remainingSwimBurstDuration = 0.0
        spawnedObstaclePairCount = 0
        lastSpawnedGapCenterY = nil
        targetFishRotation = 0.0
        gameplayNode.removeAllActions()
        gameplayNode.position = .zero
    }

    private func resetFishForReadyState() {
        freezeFishPhysics()
        fishNode.removeAllActions()
        restoreLiveFishTexture()
        fishNode.zRotation = 0.0
        fishNode.xScale = 1.0
        fishNode.yScale = 1.0
        resetFishPosition()
        startReadyIdleAnimation()
    }

    private func freezeGameplay() {
        lastUpdateTime = nil
        obstacleSpawnAccumulator = 0.0
        targetFishRotation = 0.0
        fishNode.removeAction(forKey: ActionKey.tapScale)
        applyDeadFishTexture()
        stopFishAnimation()
        freezeFishPhysics()
    }

    private func layoutDeadFish() {
        let verticalSpacing = max(
            playableRect.height * GameConfig.HUD.overlayVerticalSpacingRatio,
            GameConfig.HUD.Overlay.minimumVerticalSpacing
        )
        fishNode.position = CGPoint(
            x: playableRect.midX + GameConfig.HUD.Overlay.gameOverFishOffsetX,
            y: gameOverTitleLabelNode.position.y + (verticalSpacing * GameConfig.HUD.Overlay.gameOverFishOffsetYMultiplier)
        )
    }

    private func restoreLiveFishTexture() {
        if let texture = fishAnimationTextures.initialTexture {
            fishNode.texture = texture
            fishNode.color = .clear
            fishNode.colorBlendFactor = 0.0
        } else {
            fishNode.texture = nil
            fishNode.color = GameConfig.Fish.placeholderColor
            fishNode.colorBlendFactor = 1.0
        }
    }

    private func applyDeadFishTexture() {
        if let texture = fishAnimationTextures.dead {
            fishNode.texture = texture
            fishNode.color = .clear
            fishNode.colorBlendFactor = 0.0
        } else if let texture = fishAnimationTextures.initialTexture {
            fishNode.texture = texture
            fishNode.color = .clear
            fishNode.colorBlendFactor = 0.0
        } else {
            fishNode.texture = nil
            fishNode.color = GameConfig.Fish.placeholderColor
            fishNode.colorBlendFactor = 1.0
        }
    }

    private func startReadyIdleAnimation() {
        guard fishAnimationTextures.hasIdleAnimation else {
            stopFishAnimation()
            return
        }

        fishVisualState = .readyIdle
        runFishLoopAnimation(
            textures: fishAnimationTextures.idle,
            timePerFrame: GameConfig.Fish.Animation.idleFrameDuration
        )
    }

    private func startPlayingLoopAnimation() {
        guard gameState == .playing, fishAnimationTextures.hasSwimAnimation else {
            stopFishAnimation()
            return
        }

        fishVisualState = .playingLoop
        remainingSwimBurstDuration = 0.0
        runFishLoopAnimation(
            textures: fishAnimationTextures.swim,
            timePerFrame: GameConfig.Fish.Animation.playingLoopFrameDuration
        )
    }

    private func playSwimBurstAnimation() {
        guard fishAnimationTextures.hasSwimAnimation else {
            stopFishAnimation()
            return
        }

        fishVisualState = .swimBurst
        remainingSwimBurstDuration =
            GameConfig.Fish.Animation.swimBurstFrameDuration *
            Double(fishAnimationTextures.swim.count * GameConfig.Fish.Animation.swimBurstRepeatCount)
        let burst = SKAction.repeat(
            SKAction.animate(
                with: fishAnimationTextures.swim,
                timePerFrame: GameConfig.Fish.Animation.swimBurstFrameDuration,
                resize: false,
                restore: false
            ),
            count: GameConfig.Fish.Animation.swimBurstRepeatCount
        )

        fishNode.removeAction(forKey: ActionKey.fishFrameAnimation)
        fishNode.run(burst, withKey: ActionKey.fishFrameAnimation)
    }

    private func runFishLoopAnimation(textures: [SKTexture], timePerFrame: TimeInterval) {
        guard !textures.isEmpty else {
            stopFishAnimation()
            return
        }

        let loop = SKAction.repeatForever(
            SKAction.animate(
                with: textures,
                timePerFrame: timePerFrame,
                resize: false,
                restore: false
            )
        )

        fishNode.removeAction(forKey: ActionKey.fishFrameAnimation)
        fishNode.run(loop, withKey: ActionKey.fishFrameAnimation)
    }

    private func stopFishAnimation() {
        fishVisualState = .stopped
        remainingSwimBurstDuration = 0.0
        fishNode.removeAction(forKey: ActionKey.fishFrameAnimation)
    }

    private func updateFishVisualState(deltaTime: TimeInterval) {
        guard gameState == .playing, fishVisualState == .swimBurst else {
            return
        }

        remainingSwimBurstDuration = max(0.0, remainingSwimBurstDuration - deltaTime)
        if remainingSwimBurstDuration == 0.0 {
            startPlayingLoopAnimation()
        }
    }

    private func freezeFishPhysics() {
        fishNode.physicsBody?.isDynamic = false
        fishNode.physicsBody?.velocity = .zero
        fishNode.physicsBody?.angularVelocity = 0.0
        fishNode.physicsBody?.isResting = true
    }

    private func updateFishRotation(deltaTime: TimeInterval) {
        guard let physicsBody = fishNode.physicsBody else {
            return
        }

        let velocityRatio = physicsBody.velocity.dy / effectiveFlapImpulse()
        let clampedVelocityRatio = max(-1.0, min(1.0, velocityRatio))
        let upwardWeight = max(0.0, clampedVelocityRatio)
        let downwardWeight = max(0.0, -clampedVelocityRatio)

        let desiredRotation = clampRotation(
            (GameConfig.Fish.Motion.maxUpRotation * upwardWeight) +
            (GameConfig.Fish.Motion.maxDownRotation * downwardWeight)
        )
        targetFishRotation = desiredRotation

        let smoothing = frameAdjustedSmoothing(deltaTime: deltaTime)
        fishNode.zRotation += (targetFishRotation - fishNode.zRotation) * smoothing
        fishNode.zRotation = clampRotation(fishNode.zRotation)
    }

    private func updateObstacles(deltaTime: TimeInterval) {
        obstacleSpawnAccumulator += deltaTime
        let spawnInterval = currentObstacleSpawnInterval()

        while obstacleSpawnAccumulator >= spawnInterval {
            obstacleSpawnAccumulator -= spawnInterval
            spawnObstaclePair()
        }

        let distance = currentObstacleSpeed() * deltaTime
        for obstaclePair in obstacleLayer.children {
            obstaclePair.position.x -= distance
        }

        removeOffscreenObstacles()
    }

    private func spawnObstaclePair(gapCenterY: CGFloat? = nil) {
        let resolvedGapCenterY = gapCenterY ?? randomGapCenterY()
        let pairNode = SKNode()
        pairNode.name = GameConfig.Obstacle.pairNodeName
        pairNode.position = CGPoint(
            x: playableRect.maxX + (GameConfig.Obstacle.width / 2.0),
            y: 0.0
        )

        let gapSize = currentGapSize()
        let halfGap = gapSize / 2.0
        let bottomCollisionHeight = max(0.0, resolvedGapCenterY - halfGap - playableRect.minY)
        let topCollisionHeight = max(0.0, playableRect.maxY - (resolvedGapCenterY + halfGap))
        let bottomVisualHeight = max(0.0, resolvedGapCenterY - halfGap - frame.minY)
        let topVisualHeight = max(0.0, frame.maxY - (resolvedGapCenterY + halfGap))

        let bottomNode = makeObstacleSegment(
            name: GameConfig.Obstacle.bottomNodeName,
            visualHeight: bottomVisualHeight,
            collisionHeight: bottomCollisionHeight,
            collisionCenterY: playableRect.minY + (bottomCollisionHeight / 2.0)
        )
        let topNode = makeObstacleSegment(
            name: GameConfig.Obstacle.topNodeName,
            visualHeight: topVisualHeight,
            collisionHeight: topCollisionHeight,
            collisionCenterY: playableRect.maxY - (topCollisionHeight / 2.0)
        )
        let scoreZoneNode = makeScoreZoneNode(gapCenterY: resolvedGapCenterY)

        pairNode.addChild(bottomNode)
        pairNode.addChild(topNode)
        pairNode.addChild(scoreZoneNode)
        obstacleLayer.addChild(pairNode)

        lastSpawnedGapCenterY = resolvedGapCenterY
        spawnedObstaclePairCount += 1
    }

    private func makeObstacleSegment(
        name: String,
        visualHeight: CGFloat,
        collisionHeight: CGFloat,
        collisionCenterY: CGFloat
    ) -> SKNode {
        let anchoredToTop = name == GameConfig.Obstacle.topNodeName
        let assetName =
            anchoredToTop
            ? GameConfig.Obstacle.topAssetName
            : GameConfig.Obstacle.bottomAssetName
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
                ? frame.maxY + visualTuning.verticalOffset
                : frame.minY + visualTuning.verticalOffset
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
        Self.configurePhysicsBody(
            colliderNode.physicsBody,
            isDynamic: false,
            affectedByGravity: false,
            allowsRotation: nil,
            category: GameConfig.Physics.Category.obstacle,
            collision: GameConfig.Physics.Mask.obstacleCollision,
            contact: GameConfig.Physics.Mask.obstacleContact
        )
        Self.attachDebugRectIfNeeded(
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
            resolvedSize = Self.aspectFillSize(
                textureSize: texture.size(),
                containerSize: containerSize
            )
            spriteNode.colorBlendFactor = 0.0
        }

        spriteNode.size = resolvedSize

        spriteNode.anchorPoint = CGPoint(x: 0.5, y: anchoredToTop ? 1.0 : 0.0)
        return spriteNode
    }

    private func makeScoreZoneNode(gapCenterY: CGFloat) -> SKSpriteNode {
        let gapSize = currentGapSize()
        let node = SKSpriteNode(
            color: .clear,
            size: CGSize(width: GameConfig.Obstacle.scoreTriggerWidth, height: gapSize)
        )
        node.name = GameConfig.Obstacle.scoreTriggerNodeName
        node.position = CGPoint(x: 0.0, y: gapCenterY)
        node.physicsBody = SKPhysicsBody(rectangleOf: node.size)
        Self.configurePhysicsBody(
            node.physicsBody,
            isDynamic: false,
            affectedByGravity: false,
            allowsRotation: nil,
            category: GameConfig.Physics.Category.scoreTrigger,
            collision: GameConfig.Physics.Mask.scoreTriggerCollision,
            contact: GameConfig.Physics.Mask.scoreTriggerContact
        )
        Self.attachDebugRectIfNeeded(
            to: node,
            size: node.size,
            color: GameConfig.Debug.scoreTriggerColor
        )
        return node
    }

    private func attachDebugLineIfNeeded(
        to node: SKNode,
        from start: CGPoint,
        to end: CGPoint,
        color: SKColor,
        lineWidth: CGFloat
    ) {
        guard GameConfig.isDebugMode else {
            Self.removeDebugOutline(from: node)
            return
        }

        let path = CGMutablePath()
        path.move(to: CGPoint(x: start.x - node.position.x, y: start.y - node.position.y))
        path.addLine(to: CGPoint(x: end.x - node.position.x, y: end.y - node.position.y))
        Self.attachDebugOutline(
            makeLineDebugShape(path: path, color: color, lineWidth: lineWidth),
            to: node
        )
    }

    private static func attachDebugRectIfNeeded(to node: SKNode, size: CGSize, color: SKColor) {
        guard GameConfig.isDebugMode else {
            removeDebugOutline(from: node)
            return
        }

        let rect = CGRect(
            x: -(size.width / 2.0),
            y: -(size.height / 2.0),
            width: size.width,
            height: size.height
        )
        attachDebugOutline(
            makeRectDebugShape(rect: rect, color: color),
            to: node
        )
    }

    private static func attachDebugOutline(_ outlineNode: SKShapeNode, to node: SKNode) {
        removeDebugOutline(from: node)
        node.addChild(outlineNode)
    }

    private static func removeDebugOutline(from node: SKNode) {
        node.childNode(withName: GameConfig.Debug.outlineNodeName)?.removeFromParent()
    }

    private static func makeRectDebugShape(rect: CGRect, color: SKColor) -> SKShapeNode {
        let shapeNode = SKShapeNode(rect: rect)
        configureDebugShape(shapeNode, color: color, lineWidth: GameConfig.Debug.strokeWidth)
        return shapeNode
    }

    private func makeLineDebugShape(path: CGPath, color: SKColor, lineWidth: CGFloat) -> SKShapeNode {
        let shapeNode = SKShapeNode(path: path)
        Self.configureDebugShape(shapeNode, color: color, lineWidth: lineWidth)
        return shapeNode
    }

    private static func configureDebugShape(_ shapeNode: SKShapeNode, color: SKColor, lineWidth: CGFloat) {
        shapeNode.name = GameConfig.Debug.outlineNodeName
        shapeNode.strokeColor = color
        shapeNode.lineWidth = lineWidth
        shapeNode.fillColor = .clear
        shapeNode.isUserInteractionEnabled = false
        shapeNode.zPosition = GameConfig.Debug.zPosition
    }

    private func randomGapCenterY() -> CGFloat {
        let gapRange = allowedGapCenterYRangeForNextSpawn()
        return CGFloat.random(in: gapRange)
    }

    private func allowedGapCenterYRangeForNextSpawn() -> ClosedRange<CGFloat> {
        Self.allowedGapCenterYRange(
            playableRange: obstacleGapCenterYRange(),
            startY: currentStartPosition().y,
            maximumReachableDelta: maximumReachableGapCenterDelta(),
            spawnedObstaclePairCount: spawnedObstaclePairCount,
            lastGapCenterY: lastSpawnedGapCenterY
        )
    }

    private func obstacleGapCenterYRange() -> ClosedRange<CGFloat> {
        let halfGap = currentGapSize() / 2.0
        let minimumGapCenterY = playableRect.minY + halfGap + GameConfig.Obstacle.gapEdgeInset
        let maximumGapCenterY = playableRect.maxY - halfGap - GameConfig.Obstacle.gapEdgeInset

        guard minimumGapCenterY < maximumGapCenterY else {
            let fallbackGapCenterY = playableRect.midY
            return fallbackGapCenterY...fallbackGapCenterY
        }

        return minimumGapCenterY...maximumGapCenterY
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

    private func removeOffscreenObstacles() {
        for obstaclePair in obstacleLayer.children {
            let rightEdge = obstaclePair.position.x + (GameConfig.Obstacle.width / 2.0)
            if rightEdge < playableRect.minX {
                obstaclePair.removeFromParent()
            }
        }
    }

    private func clearObstacles() {
        obstacleLayer.removeAllChildren()
    }

    private func clampFishFallSpeed() {
        guard let physicsBody = fishNode.physicsBody else {
            return
        }

        physicsBody.velocity.dy = max(physicsBody.velocity.dy, -effectiveMaxFallSpeed())
    }

    private func speedDifficultyProgress() -> CGFloat {
        CGFloat(max(0, score - (GameConfig.Obstacle.Difficulty.speedScoreThreshold - 1)))
    }

    private func obstacleDifficultyProgress() -> CGFloat {
        CGFloat(max(0, score - GameConfig.Obstacle.Difficulty.easyScoreThreshold))
    }

    private func currentObstacleSpeed() -> CGFloat {
        min(
            GameConfig.Obstacle.Difficulty.maxSpeed,
            GameConfig.Obstacle.Difficulty.startingSpeed + (speedDifficultyProgress() * GameConfig.Obstacle.Difficulty.speedIncreasePerScore)
        )
    }

    private func currentGapSize() -> CGFloat {
        max(
            GameConfig.Obstacle.Difficulty.minimumGapSize,
            GameConfig.Obstacle.Difficulty.startingGapSize - (obstacleDifficultyProgress() * GameConfig.Obstacle.Difficulty.gapDecreasePerScore)
        )
    }

    private func currentObstacleSpawnInterval() -> TimeInterval {
        max(
            GameConfig.Obstacle.Difficulty.minimumSpawnInterval,
            GameConfig.Obstacle.Difficulty.spawnInterval - (TimeInterval(obstacleDifficultyProgress()) * GameConfig.Obstacle.Difficulty.spawnIntervalDecreasePerScore)
        )
    }

    private func isLethalContact(_ categoryMask: UInt32) -> Bool {
        let fishHitFloor =
            categoryMask == (GameConfig.Physics.Category.fish | GameConfig.Physics.Category.floor)
        let fishHitObstacle =
            categoryMask == (GameConfig.Physics.Category.fish | GameConfig.Physics.Category.obstacle)

        return fishHitFloor || fishHitObstacle
    }

    private func handleContact(categoryMask: UInt32) {
        if isLethalContact(categoryMask) {
            enterGameOver()
        }
    }

    private func handleScoreContact(_ contact: SKPhysicsContact) -> Bool {
        guard let scoreZoneNode = scoreZoneNode(from: contact.bodyA, and: contact.bodyB) else {
            return false
        }

        handleScoreContact(with: scoreZoneNode)
        return true
    }

    private func scoreZoneNode(from firstBody: SKPhysicsBody, and secondBody: SKPhysicsBody) -> SKNode? {
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

    private func handleScoreContact(with scoreZoneNode: SKNode, lethalCollisionActive: Bool = false) {
        guard gameState == .playing else {
            return
        }

        guard let physicsBody = scoreZoneNode.physicsBody,
              physicsBody.contactTestBitMask != 0
        else {
            return
        }

        if lethalCollisionActive || fishIsInLethalContact() {
            enterGameOver()
            return
        }

        physicsBody.contactTestBitMask = 0
        incrementScore()
    }

    private func fishIsInLethalContact() -> Bool {
        guard let fishPhysicsBody = fishNode.physicsBody else {
            return false
        }

        return fishPhysicsBody.allContactedBodies().contains { body in
            body.categoryBitMask == GameConfig.Physics.Category.obstacle ||
            body.categoryBitMask == GameConfig.Physics.Category.floor
        }
    }

    private func incrementScore() {
        score += 1
        updateScoreDisplay()
    }

    private func updateScoreDisplay() {
        scoreLabelNode.text = "\(score)"
    }

    private func frameAdjustedSmoothing(deltaTime: TimeInterval) -> CGFloat {
        let baseSmoothing = max(0.0, min(1.0, GameConfig.Fish.Motion.rotationSmoothing))
        let frameScale = CGFloat(deltaTime * 60.0)
        return 1.0 - pow(1.0 - baseSmoothing, frameScale)
    }

    private func refreshSceneLayoutIfNeeded() {
        let latestInsets = resolvedSafeAreaInsets()
        guard latestInsets != sceneLayoutMetrics.safeAreaInsets else {
            return
        }

        updateSceneLayoutMetrics()
        configureWorldBounds()
        layoutInterface()

        if gameState == .ready {
            resetFishPosition()
        }
    }

    private func updateSceneLayoutMetrics() {
        let frameRect = frame
        let safeInsets = resolvedSafeAreaInsets()
        let sideInset = GameConfig.Layout.playableSideInset
        let safePlayableRect = frameRect.inset(by: UIEdgeInsets(
            top: safeInsets.top,
            left: sideInset + safeInsets.left,
            bottom: GameConfig.HUD.bottomSafePadding + safeInsets.bottom,
            right: sideInset + safeInsets.right
        ))
        let minimumPlayableHeight = max(GameConfig.Obstacle.Difficulty.minimumGapSize + (GameConfig.Obstacle.gapEdgeInset * 2.0), 1.0)
        let resolvedPlayableRect = Self.clampPlayableRect(
            safePlayableRect,
            inside: frameRect,
            minimumHeight: minimumPlayableHeight
        )

        sceneLayoutMetrics = SceneLayoutMetrics(
            sceneFrame: frameRect,
            safeAreaInsets: safeInsets,
            playableRect: resolvedPlayableRect
        )
        applyCurrentMotionTuning()
    }

    private func resolvedSafeAreaInsets() -> UIEdgeInsets {
        if let safeAreaInsetsOverride {
            return safeAreaInsetsOverride
        }

        return view?.safeAreaInsets ?? .zero
    }

    private var playableRect: CGRect {
        sceneLayoutMetrics.playableRect
    }

    private func maximumReachableGapCenterDelta() -> CGFloat {
        min(
            currentGapSize() * GameConfig.Obstacle.Generation.maximumGapStepGapMultiplier,
            playableRect.height * GameConfig.Obstacle.Generation.maximumGapStepPlayableHeightMultiplier
        )
    }

    private func clampRotation(_ rotation: CGFloat) -> CGFloat {
        let lowerBound = min(GameConfig.Fish.Motion.maxUpRotation, GameConfig.Fish.Motion.maxDownRotation)
        let upperBound = max(GameConfig.Fish.Motion.maxUpRotation, GameConfig.Fish.Motion.maxDownRotation)
        return min(max(rotation, lowerBound), upperBound)
    }

    private func runTapScaleBounce() {
        let peakScale = 1.0 + GameConfig.Effects.tapScaleAmount
        let halfDuration = GameConfig.Effects.tapScaleDuration / 2.0
        let bounce = SKAction.sequence([
            SKAction.scale(to: peakScale, duration: halfDuration),
            SKAction.scale(to: 1.0, duration: halfDuration)
        ])

        fishNode.removeAction(forKey: ActionKey.tapScale)
        fishNode.run(bounce, withKey: ActionKey.tapScale)
    }

    private func runCollisionShake() {
        let offset = GameConfig.Effects.collisionShakeOffset
        let stepDuration = GameConfig.Effects.collisionShakeStepDuration
        let shake = SKAction.sequence([
            SKAction.moveTo(x: -offset, duration: stepDuration),
            SKAction.moveTo(x: offset, duration: stepDuration),
            SKAction.moveTo(x: -(offset * 0.5), duration: stepDuration),
            SKAction.moveTo(x: 0.0, duration: stepDuration)
        ])

        gameplayNode.removeAction(forKey: ActionKey.collisionShake)
        gameplayNode.run(shake, withKey: ActionKey.collisionShake)
    }

    private static func clampPlayableRect(_ rect: CGRect, inside bounds: CGRect, minimumHeight: CGFloat) -> CGRect {
        let clampedMinX = min(max(rect.minX, bounds.minX), bounds.maxX)
        let clampedMaxX = max(clampedMinX, min(rect.maxX, bounds.maxX))
        let minimumResolvedHeight = min(max(minimumHeight, 1.0), bounds.height)
        let rawMinY = min(max(rect.minY, bounds.minY), bounds.maxY)
        let rawMaxY = max(rawMinY, min(rect.maxY, bounds.maxY))

        if (rawMaxY - rawMinY) >= minimumResolvedHeight {
            return CGRect(
                x: clampedMinX,
                y: rawMinY,
                width: clampedMaxX - clampedMinX,
                height: rawMaxY - rawMinY
            )
        }

        let centeredMidY = min(max(bounds.midY, bounds.minY + (minimumResolvedHeight / 2.0)), bounds.maxY - (minimumResolvedHeight / 2.0))
        return CGRect(
            x: clampedMinX,
            y: centeredMidY - (minimumResolvedHeight / 2.0),
            width: clampedMaxX - clampedMinX,
            height: minimumResolvedHeight
        )
    }
}
