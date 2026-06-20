# Kế hoạch triển khai cấu trúc đa ngôn ngữ và cập nhật dữ liệu từ GitHub cho Kinh Pháp Cú

Yêu cầu:
- Thiết kế và chuyển đổi dữ liệu Kinh Pháp Cú sang cấu trúc đa ngôn ngữ.
- Hỗ trợ tải dữ liệu ZIP từ GitHub, giải nén cục bộ, phân tích cú pháp các file ngôn ngữ `<lang>.json` và đồng bộ vào kho lưu trữ.
- Cơ chế fallback: Nếu không có bản dịch cho ngôn ngữ hiện tại của app, tự động hiển thị tiếng Anh (en), sau đó là tiếng Việt (vi).

## User Review Required

> [!IMPORTANT]
> - **Cơ chế cập nhật qua GitHub ZIP**: Tải file ZIP từ GitHub (mặc định: `https://github.com/babyskill/dhammapada-data/archive/refs/heads/main.zip` hoặc một URL cấu hình), giải nén bằng lệnh `/usr/bin/unzip` tích hợp sẵn trong macOS qua API Foundation `Process` (không thêm 3rd party dependency).
> - **Cấu trúc File ZIP**: File ZIP giải nén có thể chứa các file JSON ngôn ngữ độc lập (ví dụ: `vi.json`, `en.json`). App sẽ tự động gộp các file này dựa vào cặp `chapterNumber` và `verseNumber` làm khoá chính để tạo thành cơ sở dữ liệu đa ngôn ngữ. Điều này giúp cộng đồng dễ dàng đóng góp bản dịch mới bằng cách tạo thêm một file `<lang_code>.json`.
> - **Migration tự động**: Khi mở app lần đầu sau cập nhật, nếu phát hiện file dữ liệu tùy chỉnh cũ `dhammapada-custom.vi.json` thì sẽ tự động chuyển đổi sang cấu trúc đa ngôn ngữ mới lưu tại `dhammapada-custom.json`.

## Proposed Changes

### 1. Dữ liệu tĩnh (JSON)

#### [NEW] [Dhammapada.json](file:///Volumes/SSD/MacOS/litemonk/Sources/App/Resources/Dhammapada.json)
Thay thế file chỉ có tiếng Việt bằng cấu trúc đa ngôn ngữ tĩnh đi kèm app (chứa bản dịch mẫu cho tiếng Việt và tiếng Anh).

#### [DELETE] [Dhammapada.vi.json](file:///Volumes/SSD/MacOS/litemonk/Sources/App/Resources/Dhammapada.vi.json)
Xóa file dữ liệu cũ để tránh trùng lặp.

---

### 2. Định nghĩa Model và Cập nhật Kho Lưu Trữ (Swift)

#### [MODIFY] [DhammapadaStore.swift](file:///Volumes/SSD/MacOS/litemonk/Sources/App/DhammapadaStore.swift)
- **Định nghĩa `DhammapadaVerse`**:
  ```swift
  struct DhammapadaVerse: Codable, Equatable, Identifiable {
      var id: String
      var chapterNumber: Int
      var verseNumber: Int
      var translations: [String: Translation]
      
      struct Translation: Codable, Equatable {
          var chapterTitle: String
          var text: String
          var translator: String
          var source: String
      }
      
      // Thuộc tính tương thích ngược & Fallback sang tiếng Anh
      var currentTranslation: Translation { ... }
      var chapterTitle: String { currentTranslation.chapterTitle }
      var text: String { currentTranslation.text }
      var translator: String { currentTranslation.translator }
      var source: String { currentTranslation.source }
  }
  ```
- **Phương thức Cập nhật từ GitHub ZIP**:
  - `func updateFromGitHub(zipURL: URL) async throws`: Thực hiện tải file ZIP về thư mục tạm, dùng `Process` chạy `/usr/bin/unzip`, đọc tất cả các file JSON ngôn ngữ được giải nén, thực hiện merge theo `chapterNumber` và `verseNumber`, cập nhật vào `verses` và ghi đè vào file `dhammapada-custom.json`.
- **Hỗ trợ Migration**:
  - Đọc file `dhammapada-custom.vi.json` cũ nếu có, map sang `dhammapada-custom.json` mới và xóa file cũ.

---

### 3. Logic hiển thị và Biên tập (Swift)

#### [MODIFY] [IdleBoost.swift](file:///Volumes/SSD/MacOS/litemonk/Sources/App/IdleBoost.swift)
- Cập nhật cách lấy danh sách các câu kinh Pháp cú (`dhammapadaVerses`) dựa trên ngôn ngữ hiện tại của app (tự động lấy `.text` tương ứng từ `verses` đa ngôn ngữ).

#### [MODIFY] [SetupView.swift](file:///Volumes/SSD/MacOS/litemonk/Sources/App/SetupView.swift)
- **Bổ sung UI Cập nhật**: Thêm một button "Cập nhật dữ liệu từ GitHub" cùng trạng thái loading/thành công/lỗi trong `ContentTab`.
- Cho phép người dùng tuỳ chỉnh URL của file ZIP từ GitHub nếu muốn.
- Cập nhật `DhammapadaVerseEditor` để lưu thay đổi vào đúng ngôn ngữ hiện tại của ứng dụng.

#### [MODIFY] [IdleBoostTests.swift](file:///Volumes/SSD/MacOS/litemonk/Tests/LiteMonkAppTests/IdleBoostTests.swift)
- Cập nhật các test cases kiểm tra load dữ liệu Pháp Cú cho phù hợp với cấu trúc đa ngôn ngữ mới và cơ chế fallback ngôn ngữ.

---

## Verification Plan

### Automated Tests
- Chạy toàn bộ test suite để đảm bảo không lỗi biên dịch và logic:
  ```bash
  swift test
  ```

### Manual Verification
- **Kiểm tra Fallback**: Chuyển app sang một ngôn ngữ chưa có bản dịch (ví dụ: Tiếng Trung). Đảm bảo app hiển thị bản dịch tiếng Anh làm fallback.
- **Kiểm tra Cập nhật từ GitHub**: Click vào nút "Cập nhật dữ liệu từ GitHub" trong màn hình Cài đặt, đợi quá trình hoàn tất và kiểm tra xem danh sách câu kinh có được cập nhật mới nhất không.
