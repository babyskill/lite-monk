import Foundation
import AVFoundation

/// Loại âm thanh dẫn đầu trước khi phát giọng đọc câu kệ.
enum VerseIntroSound: String, CaseIterable, Identifiable {
    case none    = "none"
    case mo      = "bonk_1"   // Tiếng gõ mõ
    case bell    = "bell"     // Tiếng chuông

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none:  return "Không có"
        case .mo:    return "Tiếng mõ"
        case .bell:  return "Tiếng chuông"
        }
    }
}

/// Trình phát âm thanh cho các câu kệ Kinh Pháp Cú offline.
/// Hỗ trợ phát âm thanh dẫn đầu (mõ/chuông) trước khi phát giọng đọc.
@MainActor
final class VerseAudioPlayer: NSObject, ObservableObject {
    static let shared = VerseAudioPlayer()

    private var introPlayer: AVAudioPlayer?
    private var versePlayer: AVAudioPlayer?
    private var pendingVerseTimer: Timer?

    private override init() {
        super.init()
    }

    /// Phát giọng đọc câu kệ, có thể có intro sound phát trước.
    /// - Parameters:
    ///   - chapter: Số phẩm
    ///   - verse: Số câu
    ///   - intro: Loại âm thanh dẫn đầu (mõ/chuông/không có)
    ///   - volume: Âm lượng (0.0 – 1.0)
    func play(chapter: Int, verse: Int, intro: VerseIntroSound, volume: Float = 1.0) {
        stop()

        let resourceName = "verse-\(chapter)-\(verse)"

        guard let verseURL = Bundle.module.url(forResource: resourceName, withExtension: "wav") ??
                             Bundle.module.url(forResource: resourceName, withExtension: "wav", subdirectory: "Voices") else {
            print("[VerseAudioPlayer] Không tìm thấy file: \(resourceName)")
            return
        }

        guard intro != .none,
              let introURL = Bundle.module.url(forResource: intro.rawValue, withExtension: "mp3"),
              let iPlayer = try? AVAudioPlayer(contentsOf: introURL) else {
            // Không có intro → phát thẳng voice
            playVerseURL(verseURL, volume: volume)
            return
        }

        // Phát intro, sau đó delay theo đúng duration rồi phát voice
        iPlayer.volume = min(max(volume, 0), 1)
        iPlayer.prepareToPlay()
        iPlayer.play()
        introPlayer = iPlayer

        let delay = max(iPlayer.duration + 0.2, 0.3)
        pendingVerseTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.playVerseURL(verseURL, volume: volume)
            }
        }
        RunLoop.main.add(pendingVerseTimer!, forMode: .common)
    }

    /// Backward-compat: phát không có intro
    func playVoice(chapter: Int, verse: Int, volume: Float = 1.0) {
        play(chapter: chapter, verse: verse, intro: .none, volume: volume)
    }

    /// Dừng tất cả âm thanh và huỷ timer đang chờ
    func stop() {
        pendingVerseTimer?.invalidate()
        pendingVerseTimer = nil
        introPlayer?.stop()
        introPlayer = nil
        versePlayer?.stop()
        versePlayer = nil
    }

    // MARK: - Private

    private func playVerseURL(_ url: URL, volume: Float) {
        do {
            versePlayer = try AVAudioPlayer(contentsOf: url)
            versePlayer?.volume = min(max(volume, 0), 1)
            versePlayer?.prepareToPlay()
            versePlayer?.play()
        } catch {
            print("[VerseAudioPlayer] Lỗi phát voice: \(error.localizedDescription)")
        }
    }
}

