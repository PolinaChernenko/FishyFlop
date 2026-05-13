import SpriteKit

enum PhysicsBodySupport {
    static func configure(
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
}

enum DebugOutlineSupport {
    static func attachRectIfNeeded(to node: SKNode, size: CGSize, color: SKColor) {
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
        attachDebugOutline(makeRectDebugShape(rect: rect, color: color), to: node)
    }

    static func attachLineIfNeeded(
        to node: SKNode,
        from start: CGPoint,
        to end: CGPoint,
        color: SKColor,
        lineWidth: CGFloat
    ) {
        guard GameConfig.isDebugMode else {
            removeDebugOutline(from: node)
            return
        }

        let path = CGMutablePath()
        path.move(to: CGPoint(x: start.x - node.position.x, y: start.y - node.position.y))
        path.addLine(to: CGPoint(x: end.x - node.position.x, y: end.y - node.position.y))
        attachDebugOutline(makeLineDebugShape(path: path, color: color, lineWidth: lineWidth), to: node)
    }

    static func removeDebugOutline(from node: SKNode) {
        node.childNode(withName: GameConfig.Debug.outlineNodeName)?.removeFromParent()
    }

    private static func attachDebugOutline(_ outlineNode: SKShapeNode, to node: SKNode) {
        removeDebugOutline(from: node)
        node.addChild(outlineNode)
    }

    private static func makeRectDebugShape(rect: CGRect, color: SKColor) -> SKShapeNode {
        let shapeNode = SKShapeNode(rect: rect)
        configureDebugShape(shapeNode, color: color, lineWidth: GameConfig.Debug.strokeWidth)
        return shapeNode
    }

    private static func makeLineDebugShape(path: CGPath, color: SKColor, lineWidth: CGFloat) -> SKShapeNode {
        let shapeNode = SKShapeNode(path: path)
        configureDebugShape(shapeNode, color: color, lineWidth: lineWidth)
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
}
