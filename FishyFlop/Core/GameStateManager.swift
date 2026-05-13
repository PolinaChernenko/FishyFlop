import Foundation

final class GameStateManager {
    private(set) var state: GameState = .ready

    @discardableResult
    func startPlaying() -> Bool {
        guard state == .ready else {
            return false
        }

        state = .playing
        return true
    }

    @discardableResult
    func enterGameOver() -> Bool {
        guard state == .playing else {
            return false
        }

        state = .gameOver
        return true
    }

    func resetToReady() {
        state = .ready
    }
}
