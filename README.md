# LiteMonk (An Mộ)

LiteMonk là một ứng dụng gọn nhẹ chạy trên thanh Menu Bar của macOS, mang đến một người bạn đồng hành thiền môn nhỏ bé ngay trên màn hình của bạn. Ứng dụng giúp nhắc nhở chánh niệm, hiển thị các câu kệ Kinh Pháp Cú, hỗ trợ tiếng chuông chánh niệm và các tương tác chạm thú vị để tạo ra không gian làm việc an lành, thư thái.

## Các tính năng chi tiết

### 1. Nhân vật thiền môn nổi (Floating Desktop Character)
- Chú tiểu nhỏ hiển thị trực tiếp trên màn hình của bạn với khả năng tự do di chuyển (kéo thả).
- Hỗ trợ tuỳ chỉnh kích thước nhân vật động (Presets S, M, L hoặc kéo thanh trượt).
- Chế độ **Luôn hiển thị trên cùng** (Keep pet on top) giúp nhân vật không bị che bởi các cửa sổ ứng dụng khác.

### 2. Quản lý và Biên tập gói nhân vật (Character Packs)
- Duyệt thư viện nhân vật online để tải về.
- Nhập và tạo mới các gói nhân vật tùy chỉnh từ ảnh Spritesheet thông qua công cụ cắt ảnh tích hợp (Sprite Slicer).
- Xóa các gói nhân vật không dùng đến để tiết kiệm dung lượng.

### 3. Tương tác và Phản ứng chạm (Interaction)
- Click vào chú tiểu để kích hoạt các phản ứng ngộ nghĩnh: nhảy bật, hiển thị bong bóng thoại giao tiếp ấm áp cùng hiệu ứng tim bay.
- Âm thanh gõ khánh/mõ trầm ấm đi kèm theo mỗi lần chạm (hỗ trợ điều chỉnh bật/tắt).

### 4. Dữ liệu Kinh Pháp Cú đa ngôn ngữ & Fallback thông minh
- Hiển thị các câu kệ Kinh Pháp Cú (gồm 423 câu kệ chia làm 26 phẩm) trực tiếp trên bong bóng thoại của nhân vật và trên cửa sổ popover của thanh menu.
- **Hỗ trợ đa ngôn ngữ**: Bản địa hoá giao diện và nội dung Kinh Pháp Cú sang Tiếng Việt và Tiếng Anh (sẵn sàng mở rộng thêm các ngôn ngữ khác).
- **Cơ chế Fallback thông minh**: Nếu người dùng chọn một ngôn ngữ chưa có bản dịch cho câu kệ đó, ứng dụng sẽ tự động fallback hiển thị tiếng Anh (en), và sau cùng là tiếng Việt (vi).
- Tự động xoay vòng câu kệ mỗi 5 phút để duy trì chánh niệm.

### 5. Cập nhật dữ liệu từ GitHub ZIP
- Cho phép đồng bộ và cập nhật cơ sở dữ liệu câu kệ Kinh Pháp Cú trực tiếp từ một đường dẫn file ZIP trên GitHub.
- Cơ chế giải nén và gộp (merge) thông minh: Quét các file ngôn ngữ độc lập như `vi.json`, `en.json` rồi tự động gộp chúng thành một cơ sở dữ liệu đa ngôn ngữ thống nhất dựa theo mã phẩm và câu kệ. Giúp cộng đồng dễ dàng đóng góp bản dịch mới bằng cách tạo thêm file `<language_code>.json`.

### 6. Quản lý và Biên tập nội dung tùy chỉnh
- Thêm mới, chỉnh sửa chi tiết (Tên phẩm, số câu, người dịch, nguồn tài liệu, nội dung kệ) hoặc xóa bớt câu kệ trực tiếp từ giao diện cài đặt của ứng dụng.
- Tìm kiếm nhanh chóng các câu kệ theo từ khoá hoặc số câu/phẩm.

### 7. Chuông chánh niệm (Mindfulness Bell)
- Đặt lịch rung chuông chánh niệm theo chu kỳ (ví dụ: mỗi 15 phút, 30 phút...).
- Hỗ trợ chỉnh âm lượng chuông, số lần lặp và chọn âm thanh mặc định (Mõ, Khánh, Chuông xoay Tây Tạng) hoặc tải lên file âm thanh tùy chỉnh.
- Chế độ **Giờ yên lặng** (Quiet Hours) giúp tắt âm thanh chuông tự động trong khoảng thời gian nghỉ ngơi hoặc ban đêm.
- Tự động đồng bộ hiển thị câu kệ mới mỗi khi chuông reo.

### 8. Nâng cấp tự động và Migration dữ liệu an toàn
- Tích hợp Sparkle updater để tự động kiểm tra và nâng cấp phiên bản ứng dụng.
- **Tự động chuyển đổi dữ liệu (Auto-migration)**: Khi khởi động ứng dụng phiên bản mới, nếu phát hiện file dữ liệu tùy chỉnh của phiên bản cũ lưu tại `~/.litemonk`, ứng dụng sẽ tự động di chuyển và nâng cấp dữ liệu sang thư mục cấu hình mới `~/.litemonk` một cách an toàn mà không làm mất mát dữ liệu của bạn.

---

## Cấu trúc thư mục dữ liệu

Ứng dụng lưu trữ dữ liệu tại thư mục cấu hình cục bộ của người dùng:
- **Dữ liệu tĩnh đi kèm ứng dụng**: `Sources/App/Resources/Dhammapada.json` (định dạng đa ngôn ngữ).
- **Dữ liệu tùy chỉnh của người dùng**: `~/.litemonk/dhammapada-custom.json`.
- **Thư mục chứa các gói nhân vật đã cài đặt**: `~/.litemonk/pets/`.
- **Thư mục lưu âm thanh chuông tùy chỉnh**: `~/.litemonk/sounds/`.

---

## Hướng dẫn Build ứng dụng

Ứng dụng được viết bằng Swift 6 + SwiftUI, chạy trên macOS 13+.

### 1. Build phiên bản chạy thử cục bộ
Để compile ứng dụng nhanh dưới dạng bundle `.app`:
```bash
awkit build -- -destination 'platform=macOS,arch=arm64'
```
Ứng dụng sau khi build xong sẽ nằm ở đường dẫn: `build/LiteMonk.app`.

### 2. Đóng gói thành file cài đặt DMG
Chạy script đóng gói tự động:
```bash
./scripts/ci-dmg.sh
```
Kết quả thu được file DMG tại thư mục `build/` (ví dụ: `build/LiteMonk-1.0.dmg`). File này có thể kéo thả cài đặt trực tiếp vào thư mục Applications của macOS.

---

## Kiểm thử (Unit Tests)

Chạy bộ test suite của ứng dụng để kiểm tra hoạt động của model, fallback ngôn ngữ, nắn cắt ảnh spritesheet:
```bash
swift test
```
