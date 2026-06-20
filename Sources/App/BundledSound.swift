import Foundation
@preconcurrency import AVFoundation

/// Plays short sounds bundled with the app target resources.
@MainActor
enum BundledSound: String {
    case bonk = "bonk_1"
    case bigBonk = "big_bonk_1"
    case bell = "bell"

    private static var cache: [String: AVAudioPlayer] = [:]
    private static var repeatTimers: [String: Timer] = [:]

    func play(repeatCount: Int = 1, fallbackNamed fallback: String? = nil, volume: Float = 1.0) {
        Self.repeatTimers[rawValue]?.invalidate()
        Self.repeatTimers[rawValue] = nil

        guard let player = load() else {
            return
        }

        player.volume = min(max(volume, 0), 1)
        player.currentTime = 0
        player.play()

        let remainingPlays = max(1, repeatCount) - 1
        guard remainingPlays > 0 else { return }

        let interval = max(player.duration, 0.18)
        scheduleRepeat(player: player, playsLeft: remainingPlays, interval: interval, volume: volume)
    }

    private func load() -> AVAudioPlayer? {
        if let cached = Self.cache[rawValue] {
            return cached
        }
        guard let url = Bundle.module.url(forResource: rawValue, withExtension: "mp3"),
              let player = try? AVAudioPlayer(contentsOf: url)
        else {
            return nil
        }
        player.prepareToPlay()
        Self.cache[rawValue] = player
        return player
    }

    private func scheduleRepeat(player: AVAudioPlayer, playsLeft: Int, interval: TimeInterval, volume: Float) {
        guard playsLeft > 0 else {
            Self.repeatTimers[rawValue] = nil
            return
        }

        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [rawValue] timer in
            timer.invalidate()
            Task { @MainActor in
                player.volume = min(max(volume, 0), 1)
                player.currentTime = 0
                player.play()
                BundledSound(rawValue: rawValue)?.scheduleRepeat(
                    player: player,
                    playsLeft: playsLeft - 1,
                    interval: interval,
                    volume: volume
                )
            }
        }
        Self.repeatTimers[rawValue] = timer
        RunLoop.main.add(timer, forMode: .common)
    }
}
