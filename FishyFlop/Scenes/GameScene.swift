//
//  GameScene.swift
//  FishyFlop
//
//  Created by Polina on 2026-04-28.
//

import SpriteKit
import UIKit

final class GameScene: SKScene, SKPhysicsContactDelegate {
    private enum DebugLineWidth {
        static let worldBounds: CGFloat = GameConfig.Debug.strokeWidth
    }

    private enum ActionKey {
        static let collisionShake = "collisionShake"
    }

    let stateManager = GameStateManager()
    let playerController: PlayerController
    let obstacleManager = ObstacleManager()
    let hudManager = HUDManager()
    let scoreManager = ScoreManager()
    let hapticManager = HapticManager()

    let backgroundNode = SKNode()
    let backgroundSpriteNode: SKSpriteNode
    let gameplayNode = SKNode()
    let effectsNode = SKNode()
    let floorNode = SKNode()
    let ceilingNode = SKNode()

    var score: Int {
        scoreManager.score
    }
    private var lastUpdateTime: TimeInterval?
    private(set) var sceneLayoutMetrics = SceneLayoutMetrics(
        sceneFrame: CGRect(origin: .zero, size: GameConfig.Scene.initialSize),
        safeAreaInsets: .zero,
        playableRect: CGRect(origin: .zero, size: GameConfig.Scene.initialSize)
    )
    private var safeAreaInsetsOverride: UIEdgeInsets?

    private(set) var fishAnimationTextures: FishAnimationTextures

    var gameState: GameState {
        stateManager.state
    }

    override init(size: CGSize) {
        let fishAnimationTextures = FishAnimationTextures.loadFromAssets()
        self.fishAnimationTextures = fishAnimationTextures
        playerController = PlayerController(fishAnimationTextures: fishAnimationTextures)
        backgroundSpriteNode = GameScene.makeBackgroundSpriteNode()
        super.init(size: size)
        configureScene()
    }

    init(size: CGSize, fishAnimationTextures: FishAnimationTextures) {
        self.fishAnimationTextures = fishAnimationTextures
        playerController = PlayerController(fishAnimationTextures: fishAnimationTextures)
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
        hudManager.configureIfNeeded()
        layoutInterface()
        resetRound()
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

        obstacleManager.update(
            deltaTime: deltaTime,
            playableRect: playableRect,
            sceneFrame: frame,
            score: scoreManager.score,
            startY: currentStartPosition().y
        )
        playerController.update(
            deltaTime: deltaTime,
            flapImpulse: effectiveFlapImpulse(),
            maxFallSpeed: effectiveMaxFallSpeed()
        )
    }

    func didBegin(_ contact: SKPhysicsContact) {
        switch CollisionHandler.outcome(for: contact, gameState: gameState) {
        case .none:
            return
        case .gameOver:
            enterGameOver()
        case .score(let scoreZoneNode):
            handleScoreContact(with: scoreZoneNode)
        }
    }

    private func configureScene() {
        scaleMode = GameConfig.Scene.scaleMode
        backgroundColor = GameConfig.Background.fallbackColor
        applyCurrentMotionTuning()
        physicsWorld.contactDelegate = self
    }

    private func attachRuntimeNodesIfNeeded() {
        attachNodeIfNeeded(backgroundNode, to: self)
        attachNodeIfNeeded(backgroundSpriteNode, to: backgroundNode)
        attachNodeIfNeeded(gameplayNode, to: self)
        effectsNode.name = GameConfig.Effects.nodeName
        effectsNode.zPosition = GameConfig.Effects.zPosition
        attachNodeIfNeeded(effectsNode, to: gameplayNode)
        playerController.attachIfNeeded(to: gameplayNode)
        obstacleManager.attachIfNeeded(to: gameplayNode)
        hudManager.attachIfNeeded(to: self)
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

    private func layoutInterface() {
        layoutBackground()
        hudManager.layout(in: playableRect)

        if gameState == .gameOver {
            layoutDeadFish()
        }
    }

    private func layoutBackground() {
        backgroundNode.position = .zero
        backgroundSpriteNode.position = CGPoint(x: frame.midX, y: frame.midY)
        backgroundSpriteNode.zPosition = 0.0

        if let texture = backgroundSpriteNode.texture {
            backgroundSpriteNode.size = SceneLayout.aspectFillSize(
                textureSize: texture.size(),
                containerSize: frame.size
            )
        } else {
            backgroundSpriteNode.size = frame.size
        }
    }

    private func updateHUDForCurrentState() {
        switch gameState {
        case .ready:
            hudManager.showReady()
        case .playing:
            hudManager.showPlaying()
        case .gameOver:
            hudManager.showGameOver()
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
        PhysicsBodySupport.configure(
            node.physicsBody,
            isDynamic: false,
            affectedByGravity: nil,
            allowsRotation: nil,
            category: isFloor ? GameConfig.Physics.Category.floor : GameConfig.Physics.Category.ceiling,
            collision: isFloor ? GameConfig.Physics.Mask.floorCollision : GameConfig.Physics.Mask.ceilingCollision,
            contact: isFloor ? GameConfig.Physics.Mask.floorContact : GameConfig.Physics.Mask.ceilingContact
        )
        DebugOutlineSupport.attachLineIfNeeded(
            to: node,
            from: start,
            to: end,
            color: GameConfig.Debug.worldColor,
            lineWidth: DebugLineWidth.worldBounds
        )
        attachNodeIfNeeded(node, to: self)
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

    func effectiveGravity() -> CGVector {
        CGVector(dx: 0.0, dy: GameConfig.Fish.Motion.gravityStrength * motionScale())
    }

    func effectiveFlapImpulse() -> CGFloat {
        GameConfig.Fish.Motion.flapImpulse * motionScale()
    }

    private func effectiveFlapImpulseVector() -> CGVector {
        CGVector(dx: 0.0, dy: effectiveFlapImpulse())
    }

    func effectiveMaxFallSpeed() -> CGFloat {
        GameConfig.Fish.Motion.maxFallSpeed * motionScale()
    }

    func handleTap() {
        switch gameState {
        case .ready:
            startPlaying()
            playerController.flap(impulse: effectiveFlapImpulseVector())
            hapticManager.playFlapTap()
        case .playing:
            playerController.flap(impulse: effectiveFlapImpulseVector())
            hapticManager.playFlapTap()
        case .gameOver:
            resetRound()
        }
    }

    func startPlaying() {
        guard stateManager.startPlaying() else {
            return
        }

        lastUpdateTime = nil
        playerController.startPlaying()
        updateHUDForCurrentState()
    }

    func enterGameOver() {
        guard stateManager.enterGameOver() else {
            return
        }

        lastUpdateTime = nil
        let deathPosition = playerController.fishNode.position
        let deathVelocity = playerController.fishNode.physicsBody?.velocity
        hapticManager.playDeathRumble()
        playerController.freezeForGameOver()
        effectsNode.addChild(DeathEffectFactory.makeDeathBurst(at: deathPosition, initialVelocity: deathVelocity))
        runCollisionShake()
        updateHUDForCurrentState()
        layoutDeadFish()
    }

    private func layoutDeadFish() {
        playerController.moveToGameOverPosition(hudManager.gameOverFishPosition(in: playableRect))
    }

    func resetRound() {
        hapticManager.cancelPendingDeathRumble()
        stateManager.resetToReady()
        scoreManager.reset()
        lastUpdateTime = nil
        gameplayNode.removeAllActions()
        gameplayNode.position = .zero
        effectsNode.removeAllChildren()
        obstacleManager.reset()
        playerController.resetForReadyState(startPosition: currentStartPosition())
        hudManager.updateScore(scoreManager.score)
        updateHUDForCurrentState()
    }

    private func resetFishPosition() {
        playerController.fishNode.position = currentStartPosition()
    }

    func currentStartPosition() -> CGPoint {
        playerController.startPosition(in: playableRect)
    }

    func handleScoreContact(with scoreZoneNode: SKNode, lethalCollisionActive: Bool = false) {
        switch scoreManager.consumeScoreContact(
            with: scoreZoneNode,
            gameState: gameState,
            lethalCollisionActive: lethalCollisionActive,
            fishIsInLethalContact: fishIsInLethalContact
        ) {
        case .none:
            return
        case .gameOver:
            enterGameOver()
        case .scored(let updatedScore):
            hudManager.updateScore(updatedScore)
        }
    }

    private func fishIsInLethalContact() -> Bool {
        guard let fishPhysicsBody = playerController.fishNode.physicsBody else {
            return false
        }

        return fishPhysicsBody.allContactedBodies().contains { body in
            body.categoryBitMask == GameConfig.Physics.Category.obstacle ||
            body.categoryBitMask == GameConfig.Physics.Category.floor
        }
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
        sceneLayoutMetrics = SceneLayout.makeMetrics(
            frame: frame,
            safeAreaInsets: resolvedSafeAreaInsets()
        )
        applyCurrentMotionTuning()
    }

    private func resolvedSafeAreaInsets() -> UIEdgeInsets {
        if let safeAreaInsetsOverride {
            return safeAreaInsetsOverride
        }

        return view?.safeAreaInsets ?? .zero
    }

    var playableRect: CGRect {
        sceneLayoutMetrics.playableRect
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

    func setSafeAreaInsetsOverride(_ insets: UIEdgeInsets?) {
        safeAreaInsetsOverride = insets
        updateSceneLayoutMetrics()
        configureWorldBounds()
        layoutInterface()

        if gameState == .ready {
            resetFishPosition()
        }
    }
}
