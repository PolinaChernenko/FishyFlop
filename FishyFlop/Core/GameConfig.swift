//
//  GameConfig.swift
//  FishyFlop
//
//  Created by Polina on 2026-04-28.
//

import CoreGraphics
import SpriteKit

enum GameConfig {
    static var isDebugMode = false

    enum Scene {
        static let initialSize = CGSize(width: 390.0, height: 844.0)
        static let scaleMode: SKSceneScaleMode = .resizeFill
        static let backgroundColor = SKColor(red: 0.0, green: 0.42, blue: 0.63, alpha: 1.0)
    }

    enum Assets {
        static let backdrop = "backdrop"
        static let bottomCoral = "bottom_coral"
        static let topCoral = "top_coral"
        static let mainFish = "main_fish"
        static let deadFish = "dead_fish"

        static let allNames = [
            backdrop,
            bottomCoral,
            topCoral,
            mainFish,
            deadFish
        ]
    }

    enum Physics {
        enum Category {
            static let fish: UInt32 = 1 << 0
            static let obstacle: UInt32 = 1 << 1
            static let floor: UInt32 = 1 << 2
            static let ceiling: UInt32 = 1 << 3
            static let scoreTrigger: UInt32 = 1 << 4
        }

        enum Mask {
            static let fishLethalContact = Category.floor | Category.obstacle
            static let fishCollision = Category.floor | Category.ceiling | Category.obstacle
            static let floorContact = Category.fish
            static let floorCollision = Category.fish
            static let ceilingContact = Category.fish
            static let ceilingCollision = Category.fish
            static let obstacleContact = Category.fish
            static let obstacleCollision = Category.fish
            static let scoreTriggerContact = Category.fish
            static let scoreTriggerCollision: UInt32 = 0
        }
    }

    enum Background {
        static let nodeName = "background"
        static let spriteNodeName = "backgroundSprite"
        static let assetName = Assets.backdrop
        static let fallbackColor = Scene.backgroundColor
        static let zPosition: CGFloat = -1.0
    }

    enum Fish {
        static let nodeName = "fish"
        static let defaultAssetName = Assets.mainFish
        static let placeholderColor = SKColor(red: 0.98, green: 0.55, blue: 0.24, alpha: 1.0)
        static let size = CGSize(width: 90.0, height: 63.0)
        static let hitboxSize = CGSize(width: 60.0, height: 40.0)
        static let startPosition = CGPoint(x: 0.32, y: 0.44)
        static let zPosition: CGFloat = 1.0

        enum Motion {
            static let gravityStrength: CGFloat = -6.8
            static let flapImpulse: CGFloat = 36.0
            static let maxFallSpeed: CGFloat = 420.0
            static let maxUpRotation: CGFloat = .pi / 7.0
            static let maxDownRotation: CGFloat = -.pi / 3.5
            static let rotationSmoothing: CGFloat = 0.18
            static let referencePlayableHeight =
                GameConfig.Scene.initialSize.height - GameConfig.HUD.bottomSafePadding
        }

        enum Animation {
            static let idleFrameDuration: TimeInterval = 0.28
            static let playingLoopFrameDuration: TimeInterval = 0.18
            static let swimBurstFrameDuration: TimeInterval = 0.09
            static let swimBurstRepeatCount = 2
        }
    }

    enum Obstacle {
        struct VisualTuning {
            let verticalOffset: CGFloat
            let colliderHorizontalInset: CGFloat
            let colliderVerticalInset: CGFloat
            let colliderVerticalOffset: CGFloat
        }

        static let pairNodeName = "obstaclePair"
        static let topNodeName = "obstacleTop"
        static let bottomNodeName = "obstacleBottom"
        static let scoreTriggerNodeName = "obstacleScoreZone"
        static let topAssetName = Assets.topCoral
        static let bottomAssetName = Assets.bottomCoral
        static let placeholderColor = SKColor(red: 0.87, green: 0.42, blue: 0.35, alpha: 1.0)
        static let width: CGFloat = 72.0
        static let gapEdgeInset: CGFloat = 24.0
        static let scoreTriggerWidth: CGFloat = 8.0
        static let zPosition: CGFloat = 0.5
        static let topVisualTuning = VisualTuning(
            verticalOffset: 0.0,
            colliderHorizontalInset: 14.0,
            colliderVerticalInset: 16.0,
            colliderVerticalOffset: -6.0
        )
        static let bottomVisualTuning = VisualTuning(
            verticalOffset: 0.0,
            colliderHorizontalInset: 14.0,
            colliderVerticalInset: 18.0,
            colliderVerticalOffset: 6.0
        )

        static func visualTuning(anchoredToTop: Bool) -> VisualTuning {
            anchoredToTop ? topVisualTuning : bottomVisualTuning
        }

        enum Generation {
            static let protectedOpeningPairCount = 3
            static let openingReachableBandGapMultiplier: CGFloat = 0.30
            static let maximumGapStepGapMultiplier: CGFloat = 0.45
            static let maximumGapStepPlayableHeightMultiplier: CGFloat = 0.16
        }

        enum Difficulty {
            static let startingSpeed: CGFloat = 130.0
            static let maxSpeed: CGFloat = 190.0
            static let startingGapSize: CGFloat = 136.0
            static let minimumGapSize: CGFloat = 136.0
            static let spawnInterval: TimeInterval = 1.95
            static let minimumSpawnInterval: TimeInterval = 1.95
            static let easyScoreThreshold: Int = 5
            static let speedScoreThreshold: Int = 1
            static let speedIncreasePerScore: CGFloat = 6.0
            static let gapDecreasePerScore: CGFloat = 0.0
            static let spawnIntervalDecreasePerScore: TimeInterval = 0.0
        }
    }

    enum World {
        static let floorNodeName = "floor"
        static let ceilingNodeName = "ceiling"
    }

    enum HUD {
        static let scoreTopPadding: CGFloat = 28.0
        static let bottomSafePadding: CGFloat = 20.0
        static let overlayVerticalSpacingRatio: CGFloat = 0.05

        enum ScoreLabel {
            static let nodeName = "scoreLabel"
            static let fontName = "AvenirNext-Bold"
            static let fontSize: CGFloat = 56.0
            static let fontColor = SKColor.white
            static let zPosition: CGFloat = 5.0
        }

        enum Overlay {
            static let fontName = "AvenirNext-Bold"
            static let fontColor = SKColor.white
            static let zPosition: CGFloat = 5.0
            static let readyNodeName = "readyLabel"
            static let gameOverTitleNodeName = "gameOverTitleLabel"
            static let gameOverSubtitleNodeName = "gameOverSubtitleLabel"
            static let readyText = "Tap to Swim"
            static let gameOverTitleText = "Game Over"
            static let gameOverSubtitleText = "Tap to Restart"
            static let readyFontSize: CGFloat = 38.0
            static let gameOverTitleFontSize: CGFloat = 42.0
            static let gameOverSubtitleFontSize: CGFloat = 28.0
            static let minimumVerticalSpacing: CGFloat = 28.0
            static let gameOverCenterYRatio: CGFloat = 0.62
            static let gameOverFishOffsetX: CGFloat = -18.0
            static let gameOverFishOffsetYMultiplier: CGFloat = -0.15
        }
    }

    enum Layout {
        static let playableSideInset: CGFloat = 16.0
    }

    enum Effects {
        static let tapScaleAmount: CGFloat = 0.08
        static let tapScaleDuration: TimeInterval = 0.12
        static let collisionShakeOffset: CGFloat = 8.0
        static let collisionShakeStepDuration: TimeInterval = 0.04
        static let nodeName = "effects"
        static let zPosition: CGFloat = 2.0

        enum DeathBurst {
            static let containerNodeName = "deathBurst"
            static let coreNodeName = "deathBurstCore"
            static let primaryEmitterNodeName = "deathBurstPrimaryEmitter"
            static let dustEmitterNodeName = "deathBurstDustEmitter"
            static let highlightEmitterNodeName = "deathBurstHighlightEmitter"
            static let cleanupDelay: TimeInterval = 1.0
            static let motionBiasFallback = CGVector(dx: -20.0, dy: 18.0)
            static let motionBiasStrength: CGFloat = 24.0

            enum Core {
                static let initialScale: CGFloat = 0.2
                static let expandedScale: CGFloat = 1.18
                static let flashOutScale: CGFloat = 1.52
                static let fadeInDuration: TimeInterval = 0.04
                static let expandDuration: TimeInterval = 0.16
                static let fadeOutDuration: TimeInterval = 0.24
                static let maxAlpha: CGFloat = 0.96
            }

            enum Primary {
                static let particleCount = 54
                static let emissionDuration: TimeInterval = 0.08
                static let particleLifetime: TimeInterval = 0.3
                static let particleLifetimeRange: TimeInterval = 0.1
                static let emissionRadius: CGFloat = 16.0
                static let particleSpeed: CGFloat = 148.0
                static let particleSpeedRange: CGFloat = 62.0
                static let radialAcceleration: CGFloat = -54.0
                static let alpha: CGFloat = 0.98
                static let alphaRange: CGFloat = 0.08
                static let alphaSpeed: CGFloat = -3.2
                static let scale: CGFloat = 0.32
                static let scaleRange: CGFloat = 0.2
                static let scaleSpeed: CGFloat = -0.32
            }

            enum Dust {
                static let particleCount = 16
                static let emissionDuration: TimeInterval = 0.2
                static let particleLifetime: TimeInterval = 0.5
                static let particleLifetimeRange: TimeInterval = 0.08
                static let emissionRadius: CGFloat = 16.0
                static let particleSpeed: CGFloat = 46.0
                static let particleSpeedRange: CGFloat = 12.0
                static let upwardDrift: CGFloat = 18.0
                static let alpha: CGFloat = 0.88
                static let alphaRange: CGFloat = 0.04
                static let alphaSpeed: CGFloat = -1.1
                static let scale: CGFloat = 0.26
                static let scaleRange: CGFloat = 0.04
                static let scaleSpeed: CGFloat = 0.0
            }

            enum Highlights {
                static let particleCount = 10
                static let emissionDuration: TimeInterval = 0.1
                static let particleLifetime: TimeInterval = 0.22
                static let particleLifetimeRange: TimeInterval = 0.08
                static let emissionRadius: CGFloat = 8.0
                static let particleSpeed: CGFloat = 166.0
                static let particleSpeedRange: CGFloat = 48.0
                static let alpha: CGFloat = 0.9
                static let alphaRange: CGFloat = 0.08
                static let alphaSpeed: CGFloat = -3.8
                static let scale: CGFloat = 0.12
                static let scaleRange: CGFloat = 0.06
                static let scaleSpeed: CGFloat = -0.14
            }
        }
    }

    enum Debug {
        static let outlineNodeName = "debugOutline"
        static let strokeWidth: CGFloat = 2.0
        static let zPosition: CGFloat = 20.0
        static let fishColor = SKColor.systemYellow
        static let obstacleColor = SKColor.systemRed
        static let scoreTriggerColor = SKColor.systemGreen
        static let worldColor = SKColor.systemCyan
    }
}
