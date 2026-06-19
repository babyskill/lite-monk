import AppKit

/// Plays short sounds bundled with the app target resources.
@MainActor
enum BundledSound: String {
    case bonk = "bonk_1"
    case bigBonk = "big_bonk_1"
    case bell = "bell"

    private static var cache: [String: NSSound] = [:]
    private static var repeatTimers: [String: Timer] = [:]

    func play(repeatCount: Int = 1, fallbackNamed fallback: String? = nil, volume: Float = 1.0) {
        Self.repeatTimers[rawValue]?.invalidate()
        Self.repeatTimers[rawValue] = nil

        guard let sound = load() ?? fallback.flatMap({ NSSound(named: $0) }) else {
            return
        }

        sound.volume = min(max(volume, 0), 1)
        sound.stop()
        sound.play()

        let remainingPlays = max(1, repeatCount) - 1
        guard remainingPlays > 0 else { return }

        let interval = max(sound.duration, 0.18)
        scheduleRepeat(sound: sound, playsLeft: remainingPlays, interval: interval, volume: volume)
    }

    private func load() -> NSSound? {
        if let cached = Self.cache[rawValue] {
            return cached
        }
        guard let url = Bundle.module.url(forResource: rawValue, withExtension: "mp3"),
            let sound = NSSound(contentsOf: url, byReference: true)
        else {
            return nil
        }
        Self.cache[rawValue] = sound
        return sound
    }

    private func scheduleRepeat(sound: NSSound, playsLeft: Int, interval: TimeInterval, volume: Float) {
        guard playsLeft > 0 else {
            Self.repeatTimers[rawValue] = nil
            return
        }

        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [rawValue] timer in
            timer.invalidate()
            Task { @MainActor in
                sound.volume = min(max(volume, 0), 1)
                sound.stop()
                sound.play()
                BundledSound(rawValue: rawValue)?.scheduleRepeat(
                    sound: sound,
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
