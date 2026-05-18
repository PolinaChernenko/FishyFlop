import SpriteKit
import UIKit

enum DeathEffectFactory {
    static func makeDeathBurst(at position: CGPoint, initialVelocity: CGVector?) -> SKNode {
        let container = SKNode()
        container.name = GameConfig.Effects.DeathBurst.containerNodeName
        container.position = position
        container.zPosition = GameConfig.Effects.zPosition
        let motionBias = normalizedBias(from: initialVelocity)

        container.addChild(makeCoreBlot())
        container.addChild(makePrimaryBurst(motionBias: motionBias))
        container.addChild(makeDustBurst(motionBias: motionBias))
        container.addChild(makeHighlightBurst(motionBias: motionBias))
        container.run(
            .sequence([
                .wait(forDuration: GameConfig.Effects.DeathBurst.cleanupDelay),
                .removeFromParent()
            ])
        )

        return container
    }

    private static func makeCoreBlot() -> SKSpriteNode {
        let blot = SKSpriteNode(texture: inkTexture, color: .black, size: CGSize(width: 56.0, height: 56.0))
        blot.name = GameConfig.Effects.DeathBurst.coreNodeName
        blot.colorBlendFactor = 1.0
        blot.alpha = 0.0
        blot.setScale(GameConfig.Effects.DeathBurst.Core.initialScale)
        blot.run(
            .sequence([
                .group([
                    .fadeAlpha(to: GameConfig.Effects.DeathBurst.Core.maxAlpha,
                               duration: GameConfig.Effects.DeathBurst.Core.fadeInDuration),
                    .scale(to: GameConfig.Effects.DeathBurst.Core.expandedScale,
                           duration: GameConfig.Effects.DeathBurst.Core.expandDuration)
                ]),
                .group([
                    .fadeOut(withDuration: GameConfig.Effects.DeathBurst.Core.fadeOutDuration),
                    .scale(to: GameConfig.Effects.DeathBurst.Core.flashOutScale,
                           duration: GameConfig.Effects.DeathBurst.Core.fadeOutDuration)
                ]),
                .removeFromParent()
            ])
        )
        return blot
    }

    private static func makePrimaryBurst(motionBias: CGVector) -> SKEmitterNode {
        let emitter = makeBaseEmitter(
            name: GameConfig.Effects.DeathBurst.primaryEmitterNodeName,
            particleCount: GameConfig.Effects.DeathBurst.Primary.particleCount,
            emissionDuration: GameConfig.Effects.DeathBurst.Primary.emissionDuration,
            particleLifetime: GameConfig.Effects.DeathBurst.Primary.particleLifetime,
            particleLifetimeRange: GameConfig.Effects.DeathBurst.Primary.particleLifetimeRange,
            emissionRadius: GameConfig.Effects.DeathBurst.Primary.emissionRadius,
            particleSpeed: GameConfig.Effects.DeathBurst.Primary.particleSpeed,
            particleSpeedRange: GameConfig.Effects.DeathBurst.Primary.particleSpeedRange
        )
        emitter.particleAlpha = GameConfig.Effects.DeathBurst.Primary.alpha
        emitter.particleAlphaRange = GameConfig.Effects.DeathBurst.Primary.alphaRange
        emitter.particleAlphaSpeed = GameConfig.Effects.DeathBurst.Primary.alphaSpeed
        emitter.particleScale = GameConfig.Effects.DeathBurst.Primary.scale
        emitter.particleScaleRange = GameConfig.Effects.DeathBurst.Primary.scaleRange
        emitter.particleScaleSpeed = GameConfig.Effects.DeathBurst.Primary.scaleSpeed
        emitter.particleColor = UIColor(white: 0.06, alpha: 1.0)
        emitter.xAcceleration = motionBias.dx
        emitter.yAcceleration = motionBias.dy - GameConfig.Effects.DeathBurst.Primary.radialAcceleration
        return emitter
    }

    private static func makeDustBurst(motionBias: CGVector) -> SKEmitterNode {
        let emitter = makeBaseEmitter(
            name: GameConfig.Effects.DeathBurst.dustEmitterNodeName,
            particleCount: GameConfig.Effects.DeathBurst.Dust.particleCount,
            emissionDuration: GameConfig.Effects.DeathBurst.Dust.emissionDuration,
            particleLifetime: GameConfig.Effects.DeathBurst.Dust.particleLifetime,
            particleLifetimeRange: GameConfig.Effects.DeathBurst.Dust.particleLifetimeRange,
            emissionRadius: GameConfig.Effects.DeathBurst.Dust.emissionRadius,
            particleSpeed: GameConfig.Effects.DeathBurst.Dust.particleSpeed,
            particleSpeedRange: GameConfig.Effects.DeathBurst.Dust.particleSpeedRange
        )
        emitter.particleAlpha = GameConfig.Effects.DeathBurst.Dust.alpha
        emitter.particleAlphaRange = GameConfig.Effects.DeathBurst.Dust.alphaRange
        emitter.particleAlphaSpeed = GameConfig.Effects.DeathBurst.Dust.alphaSpeed
        emitter.particleScale = GameConfig.Effects.DeathBurst.Dust.scale
        emitter.particleScaleRange = GameConfig.Effects.DeathBurst.Dust.scaleRange
        emitter.particleScaleSpeed = GameConfig.Effects.DeathBurst.Dust.scaleSpeed
        emitter.particleTexture = bubbleTexture
        emitter.particleColor = UIColor(white: 0.94, alpha: 1.0)
        emitter.particleColorBlendFactor = 0.0
        emitter.particleBlendMode = .alpha
        emitter.particleRotationRange = 0.0
        emitter.xAcceleration = motionBias.dx * 0.12
        emitter.yAcceleration = motionBias.dy * 0.1 + GameConfig.Effects.DeathBurst.Dust.upwardDrift
        return emitter
    }

    private static func makeHighlightBurst(motionBias: CGVector) -> SKEmitterNode {
        let emitter = makeBaseEmitter(
            name: GameConfig.Effects.DeathBurst.highlightEmitterNodeName,
            particleCount: GameConfig.Effects.DeathBurst.Highlights.particleCount,
            emissionDuration: GameConfig.Effects.DeathBurst.Highlights.emissionDuration,
            particleLifetime: GameConfig.Effects.DeathBurst.Highlights.particleLifetime,
            particleLifetimeRange: GameConfig.Effects.DeathBurst.Highlights.particleLifetimeRange,
            emissionRadius: GameConfig.Effects.DeathBurst.Highlights.emissionRadius,
            particleSpeed: GameConfig.Effects.DeathBurst.Highlights.particleSpeed,
            particleSpeedRange: GameConfig.Effects.DeathBurst.Highlights.particleSpeedRange
        )
        emitter.particleAlpha = GameConfig.Effects.DeathBurst.Highlights.alpha
        emitter.particleAlphaRange = GameConfig.Effects.DeathBurst.Highlights.alphaRange
        emitter.particleAlphaSpeed = GameConfig.Effects.DeathBurst.Highlights.alphaSpeed
        emitter.particleScale = GameConfig.Effects.DeathBurst.Highlights.scale
        emitter.particleScaleRange = GameConfig.Effects.DeathBurst.Highlights.scaleRange
        emitter.particleScaleSpeed = GameConfig.Effects.DeathBurst.Highlights.scaleSpeed
        emitter.particleColor = UIColor(white: 0.96, alpha: 1.0)
        emitter.xAcceleration = motionBias.dx * 0.7
        emitter.yAcceleration = motionBias.dy * 0.7
        return emitter
    }

    private static func makeBaseEmitter(
        name: String,
        particleCount: Int,
        emissionDuration: TimeInterval,
        particleLifetime: TimeInterval,
        particleLifetimeRange: TimeInterval,
        emissionRadius: CGFloat,
        particleSpeed: CGFloat,
        particleSpeedRange: CGFloat
    ) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.name = name
        emitter.particleTexture = inkTexture
        emitter.particleBirthRate = CGFloat(particleCount) / CGFloat(max(emissionDuration, 0.01))
        emitter.numParticlesToEmit = particleCount
        emitter.particleLifetime = CGFloat(particleLifetime)
        emitter.particleLifetimeRange = CGFloat(particleLifetimeRange)
        emitter.emissionAngleRange = .pi * 2.0
        emitter.particlePositionRange = CGVector(dx: emissionRadius, dy: emissionRadius)
        emitter.particleSpeed = particleSpeed
        emitter.particleSpeedRange = particleSpeedRange
        emitter.particleRotationRange = .pi * 2.0
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .alpha
        emitter.targetNode = nil
        emitter.shader = monochromeShader
        return emitter
    }

    private static func normalizedBias(from velocity: CGVector?) -> CGVector {
        let source = velocity ?? GameConfig.Effects.DeathBurst.motionBiasFallback
        let length = max(sqrt((source.dx * source.dx) + (source.dy * source.dy)), 0.001)
        let normalized = CGVector(dx: source.dx / length, dy: source.dy / length)
        return CGVector(
            dx: normalized.dx * GameConfig.Effects.DeathBurst.motionBiasStrength,
            dy: normalized.dy * GameConfig.Effects.DeathBurst.motionBiasStrength
        )
    }

    private static let inkTexture: SKTexture = {
        let size = CGSize(width: 42.0, height: 42.0)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cg = context.cgContext
            let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            let baseRadius = min(size.width, size.height) / 2.1
            let blobs: [(CGPoint, CGFloat, CGFloat)] = [
                (center, baseRadius, 0.92),
                (CGPoint(x: center.x - 7.0, y: center.y - 4.0), baseRadius * 0.62, 0.76),
                (CGPoint(x: center.x + 6.0, y: center.y + 5.0), baseRadius * 0.48, 0.68)
            ]

            for blob in blobs {
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let colors = [
                    UIColor(white: 1.0, alpha: blob.2).cgColor,
                    UIColor(white: 1.0, alpha: 0.0).cgColor
                ] as CFArray

                guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) else {
                    continue
                }

                cg.drawRadialGradient(
                    gradient,
                    startCenter: blob.0,
                    startRadius: 0.0,
                    endCenter: blob.0,
                    endRadius: blob.1,
                    options: [.drawsAfterEndLocation]
                )
            }
        }

        return SKTexture(image: image)
    }()

    private static let bubbleTexture: SKTexture = {
        let size = CGSize(width: 42.0, height: 42.0)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cg = context.cgContext
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 4.0, dy: 4.0)

            cg.setFillColor(UIColor(white: 1.0, alpha: 0.07).cgColor)
            cg.fillEllipse(in: rect)

            cg.setStrokeColor(UIColor(white: 1.0, alpha: 0.82).cgColor)
            cg.setLineWidth(1.8)
            cg.strokeEllipse(in: rect)

            cg.setStrokeColor(UIColor(white: 1.0, alpha: 0.36).cgColor)
            cg.setLineWidth(1.0)
            cg.strokeEllipse(in: rect.insetBy(dx: 3.5, dy: 3.5))

            let highlightRect = CGRect(
                x: rect.minX + 7.0,
                y: rect.maxY - 15.0,
                width: rect.width * 0.22,
                height: rect.height * 0.1
            )
            cg.setFillColor(UIColor(white: 1.0, alpha: 0.72).cgColor)
            cg.fillEllipse(in: highlightRect)
        }

        return SKTexture(image: image)
    }()

    private static let monochromeShader = SKShader(source:
        """
        void main() {
            vec4 color = texture2D(u_texture, v_tex_coord) * v_color_mix.a;
            float luminance = dot(color.rgb, vec3(0.299, 0.587, 0.114));
            gl_FragColor = vec4(vec3(luminance), color.a);
        }
        """
    )
}
