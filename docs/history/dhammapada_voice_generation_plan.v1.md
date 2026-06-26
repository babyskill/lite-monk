# Brainstorm & Kế hoạch tích hợp giọng đọc Kinh Pháp Cú bằng API LucyLab

Bản kế hoạch này mô tả giải pháp tạo voice (giọng đọc) cho 423 câu Kinh Pháp Cú (tiếng Việt) dựa trên API của LucyLab (Vivibe), và cơ chế phát âm thanh tương ứng mỗi khi ứng dụng LiteMonk chuyển câu kệ.

---

## 1. So sánh hai phương án triển khai

### Phương án A: Offline Pre-generation (Tải trước toàn bộ âm thanh - ĐỀ XUẤT)
* **Cách thực hiện:** Chạy một script offline (Node.js/Python) đọc file [Dhammapada.json](file:///Users/trungkientn/Dev2/MacOS/agentpet/Sources/App/Resources/Dhammapada.json), gửi văn bản tiếng Việt của từng câu kệ sang API LucyLab để lấy link `.wav`, sau đó tải về và lưu vào thư mục `Resources` của dự án với định dạng tên `verse-{chapterNumber}-{verseNumber}.mp3/wav`.
* **Ưu điểm:**
  * **Chạy Offline:** Ứng dụng không cần kết nối mạng để phát âm thanh.
  * **Tốc độ:** Phát ngay lập tức khi chuyển câu, không có độ trễ tải mạng.
  * **Tiết kiệm Credit:** Chỉ tốn credit API một lần duy nhất lúc tạo file ban đầu (423 lượt gọi).
  * **Tính ổn định:** Token của LucyLab API có thời hạn rất ngắn (JWT token trong `log.txt` chỉ có hiệu lực khoảng vài tiếng), nếu tích hợp Online trong app thì app sẽ lỗi khi token hết hạn. Tải trước offline sẽ loại bỏ hoàn toàn vấn đề này.
* **Nhược điểm:** Tăng dung lượng App Bundle lên thêm khoảng 15–30 MB (nếu nén sang `.mp3` chất lượng tốt). Với app macOS, dung lượng này hoàn toàn chấp nhận được.

### Phương án B: Online On-demand (Sinh giọng nói trực tuyến tại runtime)
* **Cách thực hiện:** Khi ứng dụng hiển thị câu kệ mới, nó sẽ gọi API trực tiếp qua mạng, lấy link file `.wav` về và phát (hoặc lưu tạm/cache).
* **Ưu điểm:** Giữ dung lượng tải app ban đầu nhỏ gọn.
* **Nhược điểm:**
  * Cần kết nối Internet liên tục để nghe giọng đọc.
  * Gặp vấn đề nghiêm trọng với **Authentication Token hết hạn**. Người dùng không thể tự đăng nhập LucyLab qua ứng dụng trừ khi chúng ta làm thêm cả hệ thống đăng nhập.
  * Trễ (lag) 1–3 giây trước khi phát âm thanh do phải đợi API xử lý.
  * Tốn credit của tài khoản liên tục khi người dùng chạy app và chuyển câu lặp lại.

> [!IMPORTANT]
> **Đề xuất:** Chọn **Phương án A (Offline Pre-generation)** để đảm bảo app chạy mượt mà, ổn định, độc lập với kết nối mạng và token của LucyLab.

---

## 2. Kế hoạch triển khai chi tiết

### Bước 1: Tạo Script offline sinh file âm thanh
Chúng ta sẽ viết một script Node.js tại [scripts/generate_dhammapada_voices.js](file:///Users/trungkientn/Dev2/MacOS/agentpet/scripts/generate_dhammapada_voices.js) (hoặc python) để sinh tất cả các file âm thanh và lưu chúng vào thư mục tài nguyên.

#### Code mẫu cho script (`generate_dhammapada_voices.js`):
```javascript
const fs = require('fs');
const path = require('path');
const https = require('https');

// CẤU HÌNH BẮT BUỘC: Thay Bearer Token mới lấy từ Vivibe.app vào đây
const BEARER_TOKEN = "eyJhbGciOiJSUzI1Ni..."; 
const VOICE_ID = "cACFxDTEUiNBcCSpmJbgwj"; // Giọng đọc nam/nữ từ Vivibe
const INPUT_JSON_PATH = path.join(__dirname, '../Sources/App/Resources/Dhammapada.json');
const OUTPUT_DIR = path.join(__dirname, '../Sources/App/Resources/Voices');

if (!fs.existsSync(OUTPUT_DIR)) {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}

// Đọc file dữ liệu Dhammapada
const verses = JSON.parse(fs.readFileSync(INPUT_JSON_PATH, 'utf8'));

// Hàm helper để tạo request HTTP POST
function requestTTS(text) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({
      method: "tts",
      input: {
        text: text,
        userVoiceId: VOICE_ID,
        speed: 1.0,
        blockVersion: 0
      }
    });

    const options = {
      hostname: 'api.lucylab.io',
      path: '/json-rpc',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${BEARER_TOKEN}`,
        'Accept': '*/*',
        'Origin': 'https://vivibe.app',
        'Referer': 'https://vivibe.app/'
      }
    };

    const req = https.request(options, (res) => {
      let responseBody = '';
      res.on('data', (chunk) => { responseBody += chunk; });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(responseBody);
          if (parsed.result && parsed.result.url) {
            resolve(parsed.result.url);
          } else {
            reject(new Error(`API Error: ${responseBody}`));
          }
        } catch (e) {
          reject(e);
        }
      });
    });

    req.on('error', (err) => reject(err));
    req.write(data);
    req.end();
  });
}

// Hàm tải file từ URL về máy
function downloadFile(url, destPath) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(destPath);
    https.get(url, (response) => {
      response.pipe(file);
      file.on('finish', () => {
        file.close(resolve);
      });
    }).on('error', (err) => {
      fs.unlink(destPath, () => reject(err));
    });
  });
}

// Hàm delay để tránh spam API liên tục
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function run() {
  console.log(`Bắt đầu tạo voice cho ${verses.length} câu kệ...`);
  
  for (let i = 0; i < verses.length; i++) {
    const verse = verses[i];
    const viTranslation = verse.translations && verse.translations.vi;
    if (!viTranslation || !viTranslation.text) {
      continue;
    }

    const filename = `verse-${verse.chapterNumber}-${verse.verseNumber}.wav`;
    const destPath = path.join(OUTPUT_DIR, filename);

    // Kiểm tra xem file đã tồn tại chưa để resume nếu bị ngắt quãng
    if (fs.existsSync(destPath)) {
      console.log(`[${i+1}/${verses.length}] Bỏ quan: ${filename} đã tồn tại.`);
      continue;
    }

    // Làm sạch text (loại bỏ ký tự xuống dòng dư thừa để giọng đọc tự nhiên)
    const cleanedText = viTranslation.text.replace(/\n/g, ', ');

    try {
      console.log(`[${i+1}/${verses.length}] Đang xử lý: Phẩm ${verse.chapterNumber} - Câu ${verse.verseNumber}...`);
      const audioUrl = await requestTTS(cleanedText);
      await downloadFile(audioUrl, destPath);
      console.log(`    -> Tải thành công: ${filename}`);
      
      // Delay 1.5 giây giữa các lượt request để an toàn
      await sleep(1500);
    } catch (err) {
      console.error(`❌ Lỗi tại Phẩm ${verse.chapterNumber} - Câu ${verse.verseNumber}:`, err.message);
      console.log("Dừng script để bạn kiểm tra lại Token hoặc kết nối.");
      break;
    }
  }
  console.log("Hoàn thành tiến trình!");
}

run();
```

---

### Bước 2: Tích hợp và cập nhật file cấu hình dự án (SwiftPM)
Chúng ta cần nhúng các file `.wav` này vào App Bundle bằng cách cập nhật [Package.swift](file:///Users/trungkientn/Dev2/MacOS/agentpet/Package.swift).

---

### Bước 3: Sửa đổi code Swift trong App
(Xem chi tiết trong tài liệu v1)
