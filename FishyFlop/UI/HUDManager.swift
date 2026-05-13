import SpriteKit

final class HUDManager {
    let scoreLabelNode = SKLabelNode(fontNamed: GameConfig.HUD.ScoreLabel.fontName)
    let readyLabelNode = SKLabelNode(fontNamed: GameConfig.HUD.Overlay.fontName)
    let gameOverTitleLabelNode = SKLabelNode(fontNamed: GameConfig.HUD.Overlay.fontName)
    let gameOverSubtitleLabelNode = SKLabelNode(fontNamed: GameConfig.HUD.Overlay.fontName)

    func attachIfNeeded(to scene: SKScene) {
        attachNodeIfNeeded(scoreLabelNode, to: scene)
        attachNodeIfNeeded(readyLabelNode, to: scene)
        attachNodeIfNeeded(gameOverTitleLabelNode, to: scene)
        attachNodeIfNeeded(gameOverSubtitleLabelNode, to: scene)
    }

    func configureIfNeeded() {
        scoreLabelNode.name = GameConfig.HUD.ScoreLabel.nodeName
        scoreLabelNode.fontSize = GameConfig.HUD.ScoreLabel.fontSize
        scoreLabelNode.fontColor = GameConfig.HUD.ScoreLabel.fontColor
        scoreLabelNode.zPosition = GameConfig.HUD.ScoreLabel.zPosition
        scoreLabelNode.verticalAlignmentMode = .center
        scoreLabelNode.horizontalAlignmentMode = .center

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
    }

    func layout(in playableRect: CGRect) {
        scoreLabelNode.position = CGPoint(
            x: playableRect.midX,
            y: playableRect.maxY - GameConfig.HUD.scoreTopPadding
        )

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
    }

    func showReady() {
        readyLabelNode.isHidden = false
        gameOverTitleLabelNode.isHidden = true
        gameOverSubtitleLabelNode.isHidden = true
    }

    func showPlaying() {
        readyLabelNode.isHidden = true
        gameOverTitleLabelNode.isHidden = true
        gameOverSubtitleLabelNode.isHidden = true
    }

    func showGameOver() {
        readyLabelNode.isHidden = true
        gameOverTitleLabelNode.isHidden = false
        gameOverSubtitleLabelNode.isHidden = false
    }

    func gameOverFishPosition(in playableRect: CGRect) -> CGPoint {
        let verticalSpacing = max(
            playableRect.height * GameConfig.HUD.overlayVerticalSpacingRatio,
            GameConfig.HUD.Overlay.minimumVerticalSpacing
        )
        let gameOverCenterPoint = CGPoint(
            x: playableRect.midX,
            y: playableRect.minY + (playableRect.height * GameConfig.HUD.Overlay.gameOverCenterYRatio)
        )

        return CGPoint(
            x: playableRect.midX + GameConfig.HUD.Overlay.gameOverFishOffsetX,
            y: gameOverCenterPoint.y + (verticalSpacing * (0.5 + GameConfig.HUD.Overlay.gameOverFishOffsetYMultiplier))
        )
    }

    func updateScore(_ score: Int) {
        scoreLabelNode.text = "\(score)"
    }

    private func attachNodeIfNeeded(_ node: SKNode, to parent: SKNode) {
        guard node.parent == nil else {
            return
        }

        parent.addChild(node)
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
}
