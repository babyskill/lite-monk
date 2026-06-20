#!/usr/bin/env python3
"""Generate Mac App Store screenshots for LiteMonk.

Outputs RGB PNGs at Apple's accepted Mac resolutions:
- 2880x1800
- 1280x800
"""

from __future__ import annotations

import math
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = Path(
    "/var/folders/n5/c8_jz78s76q491115txvpn2r0000gn/T/"
    "codex-clipboard-f6d4a641-b035-49f1-be3f-e4c60c7b86ea.png"
)
OUT = ROOT / "assets" / "appstore"
FULL = OUT / "mac-2880x1800"
SMALL = OUT / "mac-1280x800"
W, H = 2880, 1800

FONT_REG = "/System/Library/Fonts/SFNS.ttf"
FONT_ROUND = "/System/Library/Fonts/SFNSRounded.ttf"
FONT_FALLBACK = "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"


def font(size: int, rounded: bool = False) -> ImageFont.FreeTypeFont:
    for path in ([FONT_ROUND, FONT_REG, FONT_FALLBACK] if rounded else [FONT_REG, FONT_FALLBACK]):
        try:
            return ImageFont.truetype(path, size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def gradient(size: tuple[int, int], top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    w, h = size
    img = Image.new("RGB", size)
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        color = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
        for x in range(w):
            px[x, y] = color
    return img


def cover(img: Image.Image, size: tuple[int, int]) -> Image.Image:
    img = img.convert("RGB")
    w, h = img.size
    tw, th = size
    scale = max(tw / w, th / h)
    nw, nh = int(w * scale), int(h * scale)
    img = img.resize((nw, nh), Image.Resampling.LANCZOS)
    return img.crop(((nw - tw) // 2, (nh - th) // 2, (nw + tw) // 2, (nh + th) // 2))


def rounded_paste(base: Image.Image, img: Image.Image, box: tuple[int, int, int, int], radius: int, shadow: int = 40) -> None:
    x, y, w, h = box
    img = cover(img, (w, h)).convert("RGBA")
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w, h), radius=radius, fill=255)
    if shadow:
        sh = Image.new("RGBA", base.size, (0, 0, 0, 0))
        sd = ImageDraw.Draw(sh)
        sd.rounded_rectangle((x, y + shadow // 3, x + w, y + h + shadow // 3), radius=radius, fill=(52, 28, 13, 70))
        sh = sh.filter(ImageFilter.GaussianBlur(shadow))
        base.alpha_composite(sh)
    clipped = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    clipped.alpha_composite(img)
    clipped.putalpha(mask)
    base.alpha_composite(clipped, (x, y))


def card(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], fill=(255, 249, 240, 218), outline=(255, 255, 255, 160), radius=42) -> None:
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=2)


def text(draw: ImageDraw.ImageDraw, xy: tuple[int, int], value: str, size: int, fill=(58, 27, 15), rounded=False, spacing=10) -> None:
    draw.multiline_text(xy, value, font=font(size, rounded), fill=fill, spacing=spacing)


def pill(draw: ImageDraw.ImageDraw, xy: tuple[int, int], value: str, accent=(175, 112, 45), w_pad=30) -> int:
    f = font(36, True)
    bbox = draw.textbbox((0, 0), value, font=f)
    w = bbox[2] - bbox[0] + w_pad * 2
    x, y = xy
    draw.rounded_rectangle((x, y, x + w, y + 72), radius=36, fill=(255, 246, 232, 210), outline=(222, 191, 151, 150), width=2)
    draw.text((x + w_pad, y + 17), value, font=f, fill=accent)
    return w


def make_bg(source: Image.Image, dark: bool = False) -> Image.Image:
    if dark:
        bg = gradient((W, H), (43, 27, 20), (18, 13, 11)).convert("RGBA")
        blur = cover(source, (W, H)).filter(ImageFilter.GaussianBlur(48)).convert("RGBA")
        blur.putalpha(70)
    else:
        bg = gradient((W, H), (252, 244, 233), (224, 197, 161)).convert("RGBA")
        blur = cover(source, (W, H)).filter(ImageFilter.GaussianBlur(58)).convert("RGBA")
        blur.putalpha(92)
    bg.alpha_composite(blur)
    d = ImageDraw.Draw(bg, "RGBA")
    for cx, cy, r, alpha in [(2500, 240, 520, 70), (360, 1570, 430, 60), (2180, 1510, 380, 44)]:
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 239, 203, alpha))
    return bg


def menu_bar(draw: ImageDraw.ImageDraw, y: int = 84) -> None:
    draw.rounded_rectangle((180, y, W - 180, y + 82), radius=32, fill=(255, 250, 244, 178), outline=(255, 255, 255, 130), width=2)
    text(draw, (230, y + 22), "LiteMonk", 34, fill=(58, 27, 15), rounded=True)
    x0 = W - 610
    for i in range(3):
        draw.rounded_rectangle((x0 + i * 44, y + 25, x0 + i * 44 + 24, y + 57), radius=3, fill=(58, 27, 15))
    draw.ellipse((x0 + 155, y + 27, x0 + 185, y + 57), outline=(58, 27, 15), width=4)
    draw.line((x0 + 178, y + 50, x0 + 195, y + 65), fill=(58, 27, 15), width=4)
    draw.rounded_rectangle((x0 + 230, y + 29, x0 + 282, y + 55), radius=6, outline=(58, 27, 15), width=4)
    draw.rectangle((x0 + 284, y + 37, x0 + 290, y + 48), fill=(58, 27, 15))
    text(draw, (W - 360, y + 22), "Sat 10:30 AM", 32, fill=(58, 27, 15), rounded=True)


def quote_bubble(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int]) -> None:
    card(draw, box, radius=48)
    x1, y1, x2, _ = box
    text(draw, (x1 + 78, y1 + 58), "“", 100, fill=(205, 180, 148), rounded=True)
    text(draw, (x1 + 210, y1 + 88), "Chiến thắng vạn quân\nkhông bằng thắng chính mình.", 50, fill=(48, 31, 23), spacing=18)
    text(draw, (x1 + 520, y1 + 250), "– Kinh Pháp Cú", 36, fill=(130, 89, 58), rounded=True)


def draw_icon(base: Image.Image, icon: Image.Image, x: int, y: int, size: int) -> None:
    rounded_paste(base, icon, (x, y, size, size), radius=size // 5, shadow=20)


def slide_hero(source: Image.Image, icon: Image.Image) -> Image.Image:
    img = make_bg(source)
    d = ImageDraw.Draw(img, "RGBA")
    menu_bar(d)
    draw_icon(img, icon, 250, 330, 190)
    text(d, (250, 570), "Chú Tiểu\nGõ Mõ", 150, fill=(68, 29, 14), rounded=True, spacing=0)
    text(d, (258, 915), "Một người bạn nhỏ\ntrên thanh menu Mac.", 60, fill=(82, 45, 29), spacing=16)
    x = 250
    for label in ["Dừng lại một nhịp", "Nhận câu kinh đúng lúc", "Không làm phiền"]:
        w = pill(d, (x, 1120), label)
        x += w + 24
    rounded_paste(img, source, (1480, 290, 1130, 1130), radius=78, shadow=60)
    text(d, (705, 1580), "Không phải làm thêm điều gì,\nchỉ là nhớ trở về với chính mình.", 56, fill=(153, 94, 35), rounded=True, spacing=12)
    return img


def slide_menu(source: Image.Image, icon: Image.Image) -> Image.Image:
    img = make_bg(source)
    d = ImageDraw.Draw(img, "RGBA")
    text(d, (230, 215), "Ở ngay\nthanh menu", 132, fill=(58, 27, 15), rounded=True, spacing=4)
    text(d, (235, 520), "Một biểu tượng nhỏ, đủ để nhắc bạn\nthở chậm lại giữa ngày bận rộn.", 50, fill=(86, 54, 38), spacing=16)
    desktop = cover(source, (1460, 940)).filter(ImageFilter.GaussianBlur(8))
    rounded_paste(img, desktop, (1170, 380, 1420, 900), radius=64, shadow=54)
    d.rounded_rectangle((1210, 420, 2550, 500), radius=25, fill=(255, 249, 240, 210))
    draw_icon(img, icon, 2290, 428, 64)
    text(d, (1265, 442), "LiteMonk", 28, fill=(60, 34, 24), rounded=True)
    text(d, (2380, 443), "10:30 AM", 28, fill=(60, 34, 24), rounded=True)
    card(d, (1370, 560, 2410, 1130), fill=(47, 32, 27, 225), outline=(255, 255, 255, 80), radius=46)
    draw_icon(img, icon, 1438, 628, 110)
    text(d, (1585, 635), "Chú Tiểu Gõ Mõ", 48, fill=(255, 240, 220), rounded=True)
    text(d, (1588, 703), "Đang chờ khoảnh khắc phù hợp", 30, fill=(214, 184, 148), rounded=True)
    for i, label in enumerate(["Hiện lời nhắc", "Chuông chánh niệm", "Khởi động cùng Mac"]):
        y = 805 + i * 82
        text(d, (1450, y), label, 34, fill=(255, 241, 222), rounded=True)
        d.rounded_rectangle((2200, y - 4, 2320, y + 54), radius=30, fill=(210, 151, 70))
        d.ellipse((2264, y + 2, 2312, y + 50), fill=(255, 250, 242))
    return img


def slide_bell(source: Image.Image, icon: Image.Image) -> Image.Image:
    img = make_bg(source, dark=True)
    d = ImageDraw.Draw(img, "RGBA")
    text(d, (220, 230), "Một tiếng chuông,\nđủ nhẹ", 130, fill=(255, 239, 216), rounded=True, spacing=6)
    text(d, (226, 535), "Đặt nhịp nhắc theo giờ.\nGiữ quiet hours khi cần tập trung.", 50, fill=(222, 190, 151), spacing=16)
    card(d, (270, 770, 1080, 1230), fill=(255, 248, 236, 226), radius=46)
    d.ellipse((337, 848, 390, 901), fill=(183, 116, 41))
    text(d, (410, 845), "Chuông chánh niệm", 56, fill=(59, 31, 19), rounded=True)
    text(d, (342, 945), "Mỗi 2 giờ", 44, fill=(112, 72, 45), rounded=True)
    text(d, (342, 1025), "Không báo trong giờ yên lặng", 34, fill=(140, 99, 70), rounded=True)
    d.rounded_rectangle((785, 930, 1010, 1010), radius=40, fill=(183, 116, 41))
    text(d, (835, 948), "Bật", 36, fill=(255, 248, 236), rounded=True)
    rounded_paste(img, source, (1320, 285, 1180, 1180), radius=82, shadow=70)
    quote_bubble(d, (1380, 1180, 2440, 1510))
    return img


def slide_quote(source: Image.Image, icon: Image.Image) -> Image.Image:
    img = make_bg(source)
    d = ImageDraw.Draw(img, "RGBA")
    text(d, (260, 205), "Kinh Pháp Cú\nhiện đúng lúc", 126, fill=(58, 27, 15), rounded=True, spacing=6)
    text(d, (266, 510), "Ứng dụng chọn ngẫu nhiên một câu,\nnhư một lời nhắc nhỏ trong ngày.", 50, fill=(88, 54, 36), spacing=16)
    quote_bubble(d, (310, 820, 1395, 1165))
    card(d, (1570, 285, 2450, 1365), fill=(255, 250, 243, 226), radius=54)
    text(d, (1650, 365), "Hôm nay", 42, fill=(152, 94, 39), rounded=True)
    verses = [
        ("01", "Tâm dẫn đầu các pháp."),
        ("05", "Lấy từ bi thắng hận thù."),
        ("17", "Người tỉnh thức không sợ hãi."),
        ("23", "Tự thắng mình là tối thượng."),
    ]
    for i, (num, verse) in enumerate(verses):
        y = 470 + i * 180
        d.rounded_rectangle((1650, y, 2365, y + 126), radius=30, fill=(247, 235, 218, 190))
        text(d, (1695, y + 34), num, 34, fill=(168, 104, 40), rounded=True)
        text(d, (1790, y + 31), verse, 38, fill=(59, 34, 23), rounded=True)
    draw_icon(img, icon, 2200, 1180, 145)
    return img


def slide_custom(source: Image.Image, icon: Image.Image) -> Image.Image:
    img = make_bg(source, dark=True)
    d = ImageDraw.Draw(img, "RGBA")
    text(d, (230, 205), "Nhỏ thôi,\nnhưng có hồn", 132, fill=(255, 240, 220), rounded=True, spacing=6)
    text(d, (236, 520), "Chọn nhân vật, âm thanh, nhịp hiện.\nGiữ mọi thứ tinh tế trên desktop.", 50, fill=(226, 196, 158), spacing=16)
    card(d, (1180, 230, 2500, 1410), fill=(48, 35, 29, 230), outline=(255, 255, 255, 70), radius=56)
    text(d, (1260, 320), "Tùy biến", 58, fill=(255, 240, 220), rounded=True)
    for idx in range(12):
        col, row = idx % 4, idx // 4
        x, y = 1290 + col * 260, 460 + row * 230
        d.rounded_rectangle((x, y, x + 178, y + 178), radius=34, fill=(255, 246, 231, 210 if idx == 1 else 115), outline=(205, 144, 70, 220 if idx == 1 else 70), width=4 if idx == 1 else 2)
        draw_icon(img, icon, x + 31, y + 25, 116)
    d.rounded_rectangle((1280, 1210, 2350, 1285), radius=38, fill=(255, 246, 231, 140))
    d.ellipse((1930, 1220, 1992, 1278), fill=(222, 155, 64))
    text(d, (1285, 1330), "Kích thước nhân vật", 36, fill=(231, 203, 170), rounded=True)
    return img


SLIDES = [
    ("01-hero", slide_hero),
    ("02-menubar", slide_menu),
    ("03-bell", slide_bell),
    ("04-dhammapada", slide_quote),
    ("05-customize", slide_custom),
]


def make_contact_sheet(files: list[Path]) -> None:
    thumbs = []
    for file in files:
        im = Image.open(file).convert("RGB")
        im.thumbnail((576, 360))
        thumbs.append((file.name, im.copy()))
    sheet = Image.new("RGB", (1800, 1320), (245, 239, 231))
    d = ImageDraw.Draw(sheet)
    for i, (name, im) in enumerate(thumbs):
        x = 70 + (i % 2) * 840
        y = 70 + (i // 2) * 420
        sheet.paste(im, (x, y))
        d.text((x, y + im.height + 18), name, font=font(32, True), fill=(64, 38, 25))
    sheet.save(OUT / "preview-contact-sheet.jpg", quality=92)


def main() -> int:
    source_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SOURCE
    if not source_path.exists():
        print(f"Source image missing: {source_path}", file=sys.stderr)
        return 2
    source = Image.open(source_path).convert("RGB")
    icon_path = ROOT / "scripts" / "AppIcon-1024.png"
    icon = Image.open(icon_path).convert("RGB")
    FULL.mkdir(parents=True, exist_ok=True)
    SMALL.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source_path, OUT / "source-reference.png")

    full_files: list[Path] = []
    for name, factory in SLIDES:
        im = factory(source, icon).convert("RGB")
        full_path = FULL / f"{name}-vi-2880x1800.png"
        small_path = SMALL / f"{name}-vi-1280x800.png"
        im.save(full_path, optimize=True)
        im.resize((1280, 800), Image.Resampling.LANCZOS).save(small_path, optimize=True)
        full_files.append(full_path)
        print(full_path)
        print(small_path)
    make_contact_sheet(full_files)
    print(OUT / "preview-contact-sheet.jpg")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
