import SpriteKit

final class PlayerController {
    private enum ActionKey {
        static let tapScale = "tapScale"
        static let fishFrameAnimation = "fishFrameAnimation"
    }

    let fishNode: SKSpriteNode
    let fishAnimationTextures: FishAnimationTextures

    private(set) var fishVisualState: FishVisualState = .stopped
    private var remainingSwimBurstDuration: TimeInterval = 0.0
    private var targetFishRotation: CGFloat = 0.0

    init(fishAnimationTextures: FishAnimationTextures) {
        self.fishAnimationTextures = fishAnimationTextures
        fishNode = PlayerController.makeFishNode(initialTexture: fishAnimationTextures.initialTexture)
    }

    func attachIfNeeded(to parent: SKNode) {
        guard fishNode.parent == nil else {
            return
        }

        parent.addChild(fishNode)
    }

    func resetForReadyState(startPosition: CGPoint) {
        freezePhysics()
        fishNode.removeAllActions()
        restoreLiveFishTexture()
        fishNode.zRotation = 0.0
        fishNode.xScale = 1.0
        fishNode.yScale = 1.0
        fishNode.position = startPosition
        startReadyIdleAnimation()
    }

    func startPlaying() {
        fishNode.physicsBody?.isDynamic = true
        fishNode.physicsBody?.isResting = false
    }

    func flap(impulse: CGVector) {
        guard let physicsBody = fishNode.physicsBody else {
            return
        }

        physicsBody.velocity = CGVector(dx: physicsBody.velocity.dx, dy: 0.0)
        targetFishRotation = GameConfig.Fish.Motion.maxUpRotation
        physicsBody.applyImpulse(impulse)
        runTapScaleBounce()
        playSwimBurstAnimation()
    }

    func update(deltaTime: TimeInterval, flapImpulse: CGFloat, maxFallSpeed: CGFloat) {
        clampFallSpeed(maxFallSpeed)
        updateFishVisualState(deltaTime: deltaTime)
        updateFishRotation(deltaTime: deltaTime, flapImpulse: flapImpulse)
    }

    func freezeForGameOver() {
        targetFishRotation = 0.0
        fishNode.removeAction(forKey: ActionKey.tapScale)
        applyDeadFishTexture()
        stopFishAnimation()
        freezePhysics()
    }

    func moveToGameOverPosition(_ position: CGPoint) {
        fishNode.position = position
    }

    func startPosition(in playableRect: CGRect) -> CGPoint {
        CGPoint(
            x: playableRect.minX + (playableRect.width * GameConfig.Fish.startPosition.x),
            y: playableRect.minY + (playableRect.height * GameConfig.Fish.startPosition.y)
        )
    }

    func fishAnimationActionIsRunning() -> Bool {
        fishNode.action(forKey: ActionKey.fishFrameAnimation) != nil
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
        PhysicsBodySupport.configure(
            spriteNode.physicsBody,
            isDynamic: false,
            affectedByGravity: true,
            allowsRotation: false,
            category: GameConfig.Physics.Category.fish,
            collision: GameConfig.Physics.Mask.fishCollision,
            contact: GameConfig.Physics.Mask.fishLethalContact
        )
        DebugOutlineSupport.attachRectIfNeeded(
            to: spriteNode,
            size: GameConfig.Fish.hitboxSize,
            color: GameConfig.Debug.fishColor
        )
        return spriteNode
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
        guard fishAnimationTextures.hasSwimAnimation else {
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
        guard fishVisualState == .swimBurst else {
            return
        }

        remainingSwimBurstDuration = max(0.0, remainingSwimBurstDuration - deltaTime)
        if remainingSwimBurstDuration == 0.0 {
            startPlayingLoopAnimation()
        }
    }

    private func freezePhysics() {
        fishNode.physicsBody?.isDynamic = false
        fishNode.physicsBody?.velocity = .zero
        fishNode.physicsBody?.angularVelocity = 0.0
        fishNode.physicsBody?.isResting = true
    }

    private func clampFallSpeed(_ maxFallSpeed: CGFloat) {
        guard let physicsBody = fishNode.physicsBody else {
            return
        }

        physicsBody.velocity.dy = max(physicsBody.velocity.dy, -maxFallSpeed)
    }

    private func updateFishRotation(deltaTime: TimeInterval, flapImpulse: CGFloat) {
        guard let physicsBody = fishNode.physicsBody else {
            return
        }

        let velocityRatio = flapImpulse == 0.0 ? 0.0 : physicsBody.velocity.dy / flapImpulse
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

    private func clampRotation(_ rotation: CGFloat) -> CGFloat {
        let lowerBound = min(GameConfig.Fish.Motion.maxUpRotation, GameConfig.Fish.Motion.maxDownRotation)
        let upperBound = max(GameConfig.Fish.Motion.maxUpRotation, GameConfig.Fish.Motion.maxDownRotation)
        return min(max(rotation, lowerBound), upperBound)
    }

    private func frameAdjustedSmoothing(deltaTime: TimeInterval) -> CGFloat {
        let baseSmoothing = max(0.0, min(1.0, GameConfig.Fish.Motion.rotationSmoothing))
        let frameScale = CGFloat(deltaTime * 60.0)
        return 1.0 - pow(1.0 - baseSmoothing, frameScale)
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
}
