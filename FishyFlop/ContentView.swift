//
//  ContentView.swift
//  FishyFlop
//
//  Created by Polina on 2026-04-28.
//

import SpriteKit
import SwiftUI

struct ContentView: View {
    @State private var gameScene = GameScene()

    var body: some View {
        SpriteView(scene: gameScene)
            .ignoresSafeArea()
            .accessibilityIdentifier("gameSpriteView")
            .statusBarHidden(true)
    }
}

#Preview {
    ContentView()
}
