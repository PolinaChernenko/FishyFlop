//
//  SpriteAssetLoader.swift
//  FishyFlop
//
//  Created by Polina on 2026-04-28.
//

import Foundation
import SpriteKit

#if canImport(UIKit)
import UIKit
private typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
private typealias PlatformImage = NSImage
#endif

enum SpriteAssetLoader {
    static func textureIfAvailable(named name: String) -> SKTexture? {
        guard let image = platformImage(named: name) else {
            return nil
        }

        return SKTexture(image: image)
    }

    static func makeSpriteNode(
        assetName: String,
        fallbackColor: SKColor,
        size: CGSize
    ) -> SKSpriteNode {
        if let texture = textureIfAvailable(named: assetName) {
            return SKSpriteNode(texture: texture, color: .clear, size: size)
        }

        return SKSpriteNode(color: fallbackColor, size: size)
    }

    private static func platformImage(named name: String) -> PlatformImage? {
        for bundle in candidateBundles {
            #if canImport(UIKit)
            if let image = PlatformImage(named: name, in: bundle, compatibleWith: nil) {
                return image
            }
            #elseif canImport(AppKit)
            if let image = bundle.image(forResource: NSImage.Name(name)) {
                return image
            }
            #endif
        }

        return nil
    }

    private static var candidateBundles: [Bundle] {
        [Bundle.main, Bundle(for: BundleLocator.self)].uniquedByIdentifier()
    }
}

private final class BundleLocator {}

private extension Array where Element == Bundle {
    func uniquedByIdentifier() -> [Bundle] {
        var seenIdentifiers = Set<String>()

        return filter { bundle in
            let identifier = bundle.bundleIdentifier ?? bundle.bundlePath
            return seenIdentifiers.insert(identifier).inserted
        }
    }
}
