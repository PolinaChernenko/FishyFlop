import CoreGraphics
import SpriteKit

#if canImport(UIKit)
import UIKit
#endif

struct SceneLayoutMetrics: Equatable {
    let sceneFrame: CGRect
    let safeAreaInsets: UIEdgeInsets
    let playableRect: CGRect
}

enum SceneLayout {
    static func makeMetrics(
        frame: CGRect,
        safeAreaInsets: UIEdgeInsets
    ) -> SceneLayoutMetrics {
        let sideInset = GameConfig.Layout.playableSideInset
        let safePlayableRect = frame.inset(by: UIEdgeInsets(
            top: safeAreaInsets.top,
            left: sideInset + safeAreaInsets.left,
            bottom: GameConfig.HUD.bottomSafePadding + safeAreaInsets.bottom,
            right: sideInset + safeAreaInsets.right
        ))
        let minimumPlayableHeight = max(
            GameConfig.Obstacle.Difficulty.minimumGapSize + (GameConfig.Obstacle.gapEdgeInset * 2.0),
            1.0
        )

        return SceneLayoutMetrics(
            sceneFrame: frame,
            safeAreaInsets: safeAreaInsets,
            playableRect: clampPlayableRect(
                safePlayableRect,
                inside: frame,
                minimumHeight: minimumPlayableHeight
            )
        )
    }

    static func aspectFillSize(textureSize: CGSize, containerSize: CGSize) -> CGSize {
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

    static func clampPlayableRect(_ rect: CGRect, inside bounds: CGRect, minimumHeight: CGFloat) -> CGRect {
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

        let centeredMidY = min(
            max(bounds.midY, bounds.minY + (minimumResolvedHeight / 2.0)),
            bounds.maxY - (minimumResolvedHeight / 2.0)
        )

        return CGRect(
            x: clampedMinX,
            y: centeredMidY - (minimumResolvedHeight / 2.0),
            width: clampedMaxX - clampedMinX,
            height: minimumResolvedHeight
        )
    }
}
