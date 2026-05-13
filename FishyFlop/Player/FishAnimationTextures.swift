import SpriteKit

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
