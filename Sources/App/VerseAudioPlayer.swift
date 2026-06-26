import Foundation
import AVFoundation

/// Trình phát âm thanh cho các câu kệ Kinh Pháp Cú offline.
@MainActor
final class VerseAudioPlayer: NSObject, ObservableObject {
    static let shared = VerseAudioPlayer()
    
    private var player: AVAudioPlayer?
    
    private override init() {
        super.init()
    }
    
    /// Phát giọng đọc cho câu kệ xác định qua chapter và verse.
    func playVoice(chapter: Int, verse: Int, volume: Float = 1.0) {
        let resourceName = "verse-\(chapter)-\(verse)"
        
        // Tìm file ở thư mục gốc của module bundle hoặc trong thư mục con Voices
        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "wav") ??
                        Bundle.module.url(forResource: resourceName, withExtension: "wav", subdirectory: "Voices") else {
            print("[VerseAudioPlayer] Không tìm thấy file âm thanh cho câu kệ: \(resourceName)")
            return
        }
        
        do {
            player?.stop()
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = min(max(volume, 0), 1)
            player?.prepareToPlay()
            player?.play()
            print("[VerseAudioPlayer] Đang phát: \(resourceName)")
        } catch {
            print("[VerseAudioPlayer] Không thể phát âm thanh: \(error.localizedDescription)")
        }
    }
    
    /// Dừng phát âm thanh
    func stop() {
        player?.stop()
    }
}
