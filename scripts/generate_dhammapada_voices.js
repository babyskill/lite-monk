const fs = require('fs');
const path = require('path');
const https = require('https');

// ==========================================
// CẤU HÌNH CẦN THIẾT
// ==========================================
// THAY BEARER TOKEN MỚI LẤY TỪ VIVIBE.APP VÀO ĐÂY
const BEARER_TOKEN = process.env.VIVIBE_TOKEN || "PLACEHOLDER_TOKEN"; 
const VOICE_ID = "cACFxDTEUiNBcCSpmJbgwj"; // Giọng nam/nữ từ Vivibe
const INPUT_JSON_PATH = path.join(__dirname, '../Sources/App/Resources/Dhammapada.json');
const OUTPUT_DIR = path.join(__dirname, '../Sources/App/Resources/Voices');

// THỜI GIAN CHỜ GIỮA CÁC YÊU CẦU (để tránh bị IP block)
const MIN_DELAY_MS = 2000; // Thời gian chờ tối thiểu (2 giây)
const MAX_DELAY_MS = 5000; // Thời gian chờ tối đa (5 giây)

// CHẾ ĐỘ PREVIEW (Mặc định là true để kiểm tra trước 1 câu)
// Nếu đặt là false (hoặc truyền tham số --all khi chạy), script sẽ chạy tải toàn bộ 423 câu.
const PREVIEW_MODE = !process.argv.includes('--all'); 
const PREVIEW_VERSE_ID = "verse-1-1"; // Câu kệ để preview (Phẩm 1 - Câu 1)
// ==========================================

if (!fs.existsSync(OUTPUT_DIR)) {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}

if (!fs.existsSync(INPUT_JSON_PATH)) {
  console.error(`❌ Không tìm thấy file dữ liệu tại: ${INPUT_JSON_PATH}`);
  process.exit(1);
}

// Đọc dữ liệu Dhammapada
const verses = JSON.parse(fs.readFileSync(INPUT_JSON_PATH, 'utf8'));

// Gửi request TTS đến LucyLab API
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

// Tải file audio từ URL
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

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Tính thời gian chờ ngẫu nhiên trong khoảng cấu hình
function getRandomDelay() {
  return Math.floor(Math.random() * (MAX_DELAY_MS - MIN_DELAY_MS + 1)) + MIN_DELAY_MS;
}

// Lớp Queue đơn giản để quản lý tuần tự
class TaskQueue {
  constructor() {
    this.queue = [];
    this.running = false;
  }

  enqueue(task) {
    this.queue.push(task);
    this.runNext();
  }

  async runNext() {
    if (this.running || this.queue.length === 0) return;
    this.running = true;
    const task = this.queue.shift();
    try {
      await task();
    } catch (err) {
      console.error("❌ Lỗi hàng đợi:", err.message);
      console.log("🛑 Dừng hàng đợi để kiểm tra lỗi.");
      process.exit(1);
    }
    this.running = false;
    this.runNext();
  }
}

async function processVerse(verse, index, total) {
  const viTranslation = verse.translations && verse.translations.vi;
  if (!viTranslation || !viTranslation.text) return;

  const filename = `verse-${verse.chapterNumber}-${verse.verseNumber}.wav`;
  const destPath = path.join(OUTPUT_DIR, filename);

  if (fs.existsSync(destPath)) {
    console.log(`[${index}/${total}] Bỏ qua: ${filename} đã tồn tại.`);
    return;
  }

  const cleanedText = viTranslation.text.replace(/\n/g, ', ');
  console.log(`[${index}/${total}] Đang gửi yêu cầu: Phẩm ${verse.chapterNumber} - Câu ${verse.verseNumber}...`);

  try {
    const audioUrl = await requestTTS(cleanedText);
    await downloadFile(audioUrl, destPath);
    console.log(`    -> Tải thành công và lưu: ${filename}`);
  } catch (err) {
    console.error(`❌ Lỗi tại Phẩm ${verse.chapterNumber} - Câu ${verse.verseNumber}:`, err.message);
    throw err; // Ném lỗi để dừng hàng đợi
  }
}

async function run() {
  if (BEARER_TOKEN === "PLACEHOLDER_TOKEN" || !BEARER_TOKEN.startsWith("eyJ")) {
    console.error("❌ CẢNH BÁO: Vui lòng thay BEARER_TOKEN hợp lệ của Vivibe trước khi chạy.");
    console.log("Hướng dẫn lấy token:");
    console.log("1. Đăng nhập vào vivibe.app");
    console.log("2. Mở Developer Tools (F12) -> tab Network");
    console.log("3. Kích hoạt một giọng đọc bất kỳ, tìm request gửi tới 'api.lucylab.io/json-rpc'");
    console.log("4. Copy giá trị header 'Authorization' (bỏ chữ 'Bearer ') và dán vào script này.");
    process.exit(1);
  }

  let targets = verses;
  
  if (PREVIEW_MODE) {
    console.log("⚡ CHẾ ĐỘ PREVIEW ĐANG BẬT (Chỉ sinh 1 câu thử nghiệm).");
    console.log("👉 Chạy `node scripts/generate_dhammapada_voices.js --all` để tải toàn bộ các câu.");
    const previewVerse = verses.find(v => v.id === PREVIEW_VERSE_ID);
    if (!previewVerse) {
      console.error(`Không tìm thấy câu preview với ID: ${PREVIEW_VERSE_ID}`);
      return;
    }
    targets = [previewVerse];
  } else {
    console.log("🚀 CHẾ ĐỘ TẢI TOÀN BỘ ĐANG BẬT (423 câu kệ).");
  }

  console.log(`Khởi tạo hàng đợi tải voice. Tổng cộng: ${targets.length} câu.`);
  const queue = new TaskQueue();
  
  let currentIdx = 0;
  for (const verse of targets) {
    currentIdx++;
    const idx = currentIdx;
    
    queue.enqueue(async () => {
      await processVerse(verse, idx, targets.length);
      
      // Nếu không phải câu cuối cùng, áp dụng delay ngẫu nhiên an toàn
      if (idx < targets.length) {
        const delay = getRandomDelay();
        console.log(`    -> Chờ ${delay}ms để tránh spam API...`);
        await sleep(delay);
      } else {
        console.log("✨ Hoàn thành tiến trình hàng đợi!");
      }
    });
  }
}

run();
