import LiteMonkCore
import AppKit
import UniformTypeIdentifiers
@preconcurrency import AVFoundation

/// Plays a mindfulness bell on a repeating interval while the app is running.
/// Uses the bundled wood-block sound by default, but can also use a custom file.
@MainActor
final class MindfulnessBellSettings: ObservableObject {
    static let shared = MindfulnessBellSettings()

    enum DefaultSound: String, CaseIterable, Identifiable {
        case bonk
        case bell

        var id: String { rawValue }
        var label: String {
            switch self {
            case .bonk: return NSLocalizedString("Go mo", comment: "mindfulness bell default sound")
            case .bell: return NSLocalizedString("Bell", comment: "mindfulness bell default sound")
            }
        }

        var bundledSound: BundledSound {
            switch self {
            case .bonk: return .bonk
            case .bell: return .bell
            }
        }
    }

    @Published var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: Keys.enabled)
            reschedule()
        }
    }
    @Published var intervalMinutes: Double {
        didSet {
            let value = Self.clampedInterval(intervalMinutes)
            UserDefaults.standard.set(value, forKey: Keys.intervalMinutes)
            reschedule()
        }
    }
    @Published var syncMessage: Bool {
        didSet {
            UserDefaults.standard.set(syncMessage, forKey: Keys.syncMessage)
            PetController.shared.refreshPeriodicIdleMessageSchedule()
            reschedule()
        }
    }
    @Published var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: Keys.soundEnabled)
        }
    }
    @Published var volume: Double {
        didSet {
            let value = Self.clampedVolume(volume)
            UserDefaults.standard.set(value, forKey: Keys.volume)
        }
    }
    @Published var defaultSoundRaw: String {
        didSet {
            if DefaultSound(rawValue: defaultSoundRaw) == nil {
                defaultSoundRaw = DefaultSound.bonk.rawValue
            }
            UserDefaults.standard.set(defaultSoundRaw, forKey: Keys.defaultSound)
        }
    }
    @Published var repeatCount: Int {
        didSet {
            let value = Self.clampedRepeatCount(repeatCount)
            UserDefaults.standard.set(value, forKey: Keys.repeatCount)
        }
    }
    @Published var quietHoursEnabled: Bool {
        didSet {
            UserDefaults.standard.set(quietHoursEnabled, forKey: Keys.quietHoursEnabled)
        }
    }
    @Published var allowedStartMinutes: Int {
        didSet {
            let value = Self.clampedMinutesOfDay(allowedStartMinutes)
            UserDefaults.standard.set(value, forKey: Keys.allowedStartMinutes)
        }
    }
    @Published var allowedEndMinutes: Int {
        didSet {
            let value = Self.clampedMinutesOfDay(allowedEndMinutes)
            UserDefaults.standard.set(value, forKey: Keys.allowedEndMinutes)
        }
    }
    @Published var customPath: String {
        didSet {
            UserDefaults.standard.set(customPath, forKey: Keys.customPath)
            reschedule()
        }
    }

    var defaultSound: DefaultSound {
        DefaultSound(rawValue: defaultSoundRaw) ?? .bonk
    }

    var sourceLabel: String {
        customPath.isEmpty
            ? String(
                format: NSLocalizedString("Default: %@", comment: "default sound label"),
                defaultSound.label)
            : (customPath as NSString).lastPathComponent
    }

    var allowedStartDate: Date {
        get { Self.date(fromMinutesOfDay: allowedStartMinutes) }
        set { allowedStartMinutes = Self.minutesOfDay(from: newValue) }
    }

    var allowedEndDate: Date {
        get { Self.date(fromMinutesOfDay: allowedEndMinutes) }
        set { allowedEndMinutes = Self.minutesOfDay(from: newValue) }
    }

    var quietHoursSummary: String {
        let start = Self.timeFormatter.string(from: allowedStartDate)
        let end = Self.timeFormatter.string(from: allowedEndDate)
        return String(
            format: NSLocalizedString(
                "Allowed from %@ to %@", comment: "allowed sound window summary"), start, end)
    }

    private enum Keys {
        static let enabled = "litemonk.mindfulnessBell.enabled"
        static let intervalMinutes = "litemonk.mindfulnessBell.intervalMinutes"
        static let syncMessage = "litemonk.mindfulnessBell.syncMessage"
        static let soundEnabled = "litemonk.mindfulnessBell.soundEnabled"
        static let volume = "litemonk.mindfulnessBell.volume"
        static let defaultSound = "litemonk.mindfulnessBell.defaultSound"
        static let repeatCount = "litemonk.mindfulnessBell.repeatCount"
        static let quietHoursEnabled = "litemonk.mindfulnessBell.quietHoursEnabled"
        static let allowedStartMinutes = "litemonk.mindfulnessBell.allowedStartMinutes"
        static let allowedEndMinutes = "litemonk.mindfulnessBell.allowedEndMinutes"
        static let customPath = "litemonk.mindfulnessBell.customPath"
    }

    private var timer: Timer?
    private var customPlayer: AVAudioPlayer?
    private var customRepeatTimer: Timer?
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private var soundsDir: URL {
        URL(fileURLWithPath: LiteMonkPaths.baseDir).appendingPathComponent("sounds")
    }

    private init() {
        let defaults = UserDefaults.standard
        enabled = (defaults.object(forKey: Keys.enabled) as? Bool) ?? false
        intervalMinutes = Self.clampedInterval(
            (defaults.object(forKey: Keys.intervalMinutes) as? Double) ?? 15)
        syncMessage = (defaults.object(forKey: Keys.syncMessage) as? Bool) ?? false
        soundEnabled = (defaults.object(forKey: Keys.soundEnabled) as? Bool) ?? true
        volume = Self.clampedVolume((defaults.object(forKey: Keys.volume) as? Double) ?? 0.8)
        defaultSoundRaw = defaults.string(forKey: Keys.defaultSound) ?? DefaultSound.bonk.rawValue
        repeatCount = Self.clampedRepeatCount(
            (defaults.object(forKey: Keys.repeatCount) as? Int) ?? 1)
        quietHoursEnabled = (defaults.object(forKey: Keys.quietHoursEnabled) as? Bool) ?? false
        allowedStartMinutes = Self.clampedMinutesOfDay(
            (defaults.object(forKey: Keys.allowedStartMinutes) as? Int) ?? (8 * 60)
        )
        allowedEndMinutes = Self.clampedMinutesOfDay(
            (defaults.object(forKey: Keys.allowedEndMinutes) as? Int) ?? (22 * 60)
        )
        customPath = defaults.string(forKey: Keys.customPath) ?? ""
    }

    func start() {
        PetController.shared.refreshPeriodicIdleMessageSchedule()
        reschedule()
    }

    func playPreview() {
        playBell(force: true)
    }

    func upload() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Choose a mindfulness bell sound"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let fm = FileManager.default
        try? fm.createDirectory(at: soundsDir, withIntermediateDirectories: true)
        let dest = soundsDir.appendingPathComponent("mindfulness-bell.\(url.pathExtension)")
        try? fm.removeItem(at: dest)
        guard (try? fm.copyItem(at: url, to: dest)) != nil else { return }
        customPath = dest.path
        playPreview()
    }

    func resetToDefault() {
        customPath = ""
    }

    private func reschedule() {
        timer?.invalidate()
        timer = nil
        guard enabled else { return }
        let interval = Self.clampedInterval(intervalMinutes)

        let timer = Timer.scheduledTimer(withTimeInterval: interval * 60, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleTick()
            }
        }
        timer.tolerance = min(10, interval * 5)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func handleTick() {
        if syncMessage {
            PetController.shared.showPeriodicMindfulnessMessage()
        }
        if soundEnabled {
            playBell()
        }
    }

    private func playBell(force: Bool = false) {
        guard force || canPlaySound(at: Date()) else { return }
        if !customPath.isEmpty, FileManager.default.fileExists(atPath: customPath) {
            playCustomSound(repeatCount: repeatCount, volume: Float(volume))
            return
        }

        customRepeatTimer?.invalidate()
        customRepeatTimer = nil
        defaultSound.bundledSound.play(
            repeatCount: repeatCount,
            fallbackNamed: "Glass",
            volume: Float(volume)
        )
    }

    private func playCustomSound(repeatCount: Int, volume: Float) {
        customRepeatTimer?.invalidate()
        customRepeatTimer = nil
        
        let url = URL(fileURLWithPath: customPath)
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        self.customPlayer = player
        player.volume = min(max(volume, 0), 1)
        player.currentTime = 0
        player.play()

        let remainingPlays = max(1, repeatCount) - 1
        guard remainingPlays > 0 else { return }
        let interval = max(player.duration, 0.18)
        scheduleCustomRepeat(
            player: player, playsLeft: remainingPlays, interval: interval, volume: volume)
    }

    private func scheduleCustomRepeat(
        player: AVAudioPlayer, playsLeft: Int, interval: TimeInterval, volume: Float
    ) {
        guard playsLeft > 0 else {
            customRepeatTimer = nil
            return
        }

        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) {
            [weak self] timer in
            timer.invalidate()
            Task { @MainActor [weak self] in
                player.volume = min(max(volume, 0), 1)
                player.currentTime = 0
                player.play()
                self?.scheduleCustomRepeat(
                    player: player, playsLeft: playsLeft - 1, interval: interval, volume: volume)
            }
        }
        customRepeatTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func canPlaySound(at date: Date) -> Bool {
        guard quietHoursEnabled else { return true }
        let current = Self.minutesOfDay(from: date)
        let start = Self.clampedMinutesOfDay(allowedStartMinutes)
        let end = Self.clampedMinutesOfDay(allowedEndMinutes)
        if start == end { return true }
        if start < end {
            return current >= start && current < end
        }
        return current >= start || current < end
    }

    private static func clampedInterval(_ minutes: Double) -> Double {
        min(max(minutes, 1), 180)
    }

    private static func clampedRepeatCount(_ count: Int) -> Int {
        min(max(count, 1), 10)
    }

    private static func clampedVolume(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private static func clampedMinutesOfDay(_ value: Int) -> Int {
        min(max(value, 0), (24 * 60) - 1)
    }

    private static func minutesOfDay(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return ((components.hour ?? 0) * 60) + (components.minute ?? 0)
    }

    private static func date(fromMinutesOfDay value: Int) -> Date {
        let minutes = clampedMinutesOfDay(value)
        let hour = minutes / 60
        let minute = minutes % 60
        let now = Date()
        return Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: now
        ) ?? now
    }
}
