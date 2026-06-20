# Nhật ký thay đổi (Walkthrough) - Dữ liệu Kinh Pháp Cú đa ngôn ngữ & cập nhật qua GitHub

Chúng ta đã hoàn thành việc thiết kế cấu trúc dữ liệu đa ngôn ngữ cho Kinh Pháp Cú, hỗ trợ cơ chế tự động fallback ngôn ngữ và tính năng tải/cập nhật dữ liệu từ GitHub dưới dạng ZIP. Đồng thời, cấu hình tự động đóng gói ứng dụng thành file DMG và xuất lên GitHub Actions Artifacts.

## Các thay đổi chính

### 1. Dữ liệu tĩnh (JSON)
- **Tạo mới**: [Dhammapada.json](file:///Volumes/SSD/MacOS/agentpet/Sources/App/Resources/Dhammapada.json) có cấu trúc đa ngôn ngữ (chứa sẵn tiếng Việt và các bản dịch tiếng Anh mẫu).
- **Xóa**: `Dhammapada.vi.json` cũ để tránh dư thừa.

### 2. Thiết kế Model & Kho Lưu Trữ
- **Model `DhammapadaVerse`**: Cập nhật định nghĩa với dictionary `translations: [String: Translation]`.
- **Computed Properties**: Thêm các thuộc tính tương thích ngược (`chapterTitle`, `text`, `translator`, `source`) để tự động lấy dữ liệu theo ngôn ngữ hiện tại của app (`AppLanguage.shared.lang`).
- **Cơ chế Fallback**: Tự động hiển thị tiếng Anh (`en`) nếu ngôn ngữ hiện tại không có bản dịch, và hiển thị tiếng Việt (`vi`) nếu tiếng Anh cũng không có.
- **Tự động Migration**: Khi load custom data, nếu thấy file cũ `dhammapada-custom.vi.json` thì tự động nâng cấp sang định dạng đa ngôn ngữ mới lưu tại `dhammapada-custom.json`, sau đó xóa file cũ.
- **GitHub ZIP Updater**: Sử dụng lệnh `/usr/bin/unzip` trên macOS qua `Process` (không thêm dependency bên ngoài) để tải và giải nén ZIP từ GitHub, sau đó nạp các file `<lang>.json` và merge theo `chapterNumber` và `verseNumber`.

### 3. Giao diện Cài đặt & Lịch trình
- [SetupView.swift](file:///Volumes/SSD/MacOS/agentpet/Sources/App/SetupView.swift):
  - Bổ sung section **Cập nhật dữ liệu từ GitHub** trong tab *Nội dung* với input URL ZIP, nút bấm và trạng thái Loading / Success / Error.
  - Cập nhật `DhammapadaVerseEditor` để cho phép chỉnh sửa bản dịch tương ứng với ngôn ngữ đang được chọn trong ứng dụng và hỗ trợ biên tập thêm các trường `translator` (Người dịch) và `source` (Nguồn tài liệu).
- [IdleBoost.swift](file:///Volumes/SSD/MacOS/agentpet/Sources/App/IdleBoost.swift): Cập nhật để lấy text của câu kệ thay đổi động theo ngôn ngữ hiển thị.

### 4. Tài liệu & CI/CD GitHub Build
- [README.md](file:///Volumes/SSD/MacOS/agentpet/README.md): Cập nhật lại đường dẫn lưu trữ tĩnh/tùy chỉnh mới, bổ sung các tính năng đa ngôn ngữ, hướng dẫn build app và đóng gói DMG.
- [.github/workflows/ci.yml](file:///Volumes/SSD/MacOS/agentpet/.github/workflows/ci.yml): Cập nhật workflow tích hợp thêm bước tự động chạy `./scripts/ci-dmg.sh` sau khi test pass để đóng gói ứng dụng thành file `.dmg` và upload lên GitHub Actions Artifacts (`AgentPet-macOS-DMG`). Nhờ đó, người dùng có thể tải về file chạy của bất kỳ commit nào ngay trên trang GitHub.

## Kết quả kiểm thử (Verification Results)

Chúng ta đã cập nhật và chạy bộ test suite thành công qua lệnh `swift test`.
Toàn bộ 13 bài test đều đã Passed:
- `testIdleMessagesLoadFromBundledDataset` - Đạt.
- `testDhammapadaStoreKeepsTranslatorMetadata` - Đạt.
- `testDhammapadaLinesStayExactVietnameseVerses` - Đạt.
- `testDhammapadaLineSwitchesToEnglishAndFallback` - Đạt (Xác nhận chuyển ngôn ngữ app sang tiếng Anh hiển thị đúng bản dịch tiếng Anh, và tự động fallback về tiếng Việt đối với các câu kinh chưa có bản dịch tiếng Anh).
- Các test cases khác của `PetControllerTests` và `SpriteSlicerTests` đều chạy thành công.
