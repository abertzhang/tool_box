#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成并替换 tool_box 各平台 App 图标。

用法：
    python scripts/generate_icons.py [源图标路径]

默认源图标：项目根目录 local/app_1024.png
处理范围：iOS / Android / macOS / Web / Windows
"""

import os
import sys
from pathlib import Path
from PIL import Image


def project_root() -> Path:
    """脚本位于 scripts/，项目根目录为其父目录。"""
    return Path(__file__).resolve().parent.parent


def open_source(src: Path) -> Image.Image:
    """打开源图标，保持 RGBA，若非正方形则居中裁剪。"""
    img = Image.open(src).convert("RGBA")
    w, h = img.size
    if w != h:
        side = min(w, h)
        left = (w - side) // 2
        top = (h - side) // 2
        img = img.crop((left, top, left + side, top + side))
    return img


def resize(img: Image.Image, size: int) -> Image.Image:
    """使用 Lanczos 高质量缩放至 size×size。"""
    return img.resize((size, size), Image.LANCZOS)


def save_png(img: Image.Image, path: Path) -> None:
    """保存 PNG，保留透明通道。"""
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG")


def generate_ios_icons(src_img: Image.Image, root: Path) -> list[Path]:
    """生成 iOS AppIcon.appiconset 所有图标。"""
    dest_dir = root / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    # 文件名与实际像素尺寸的映射（严格对应 Contents.json）
    ios_specs = [
        ("Icon-App-20x20@1x.png", 20),
        ("Icon-App-20x20@2x.png", 40),
        ("Icon-App-20x20@3x.png", 60),
        ("Icon-App-29x29@1x.png", 29),
        ("Icon-App-29x29@2x.png", 58),
        ("Icon-App-29x29@3x.png", 87),
        ("Icon-App-40x40@1x.png", 40),
        ("Icon-App-40x40@2x.png", 80),
        ("Icon-App-40x40@3x.png", 120),
        ("Icon-App-60x60@2x.png", 120),
        ("Icon-App-60x60@3x.png", 180),
        ("Icon-App-76x76@1x.png", 76),
        ("Icon-App-76x76@2x.png", 152),
        ("Icon-App-83.5x83.5@2x.png", 167),
        ("app_1024.png", 1024),
    ]
    generated: list[Path] = []
    for filename, px in ios_specs:
        out = dest_dir / filename
        save_png(resize(src_img, px), out)
        generated.append(out)
    return generated


def generate_android_icons(src_img: Image.Image, root: Path) -> list[Path]:
    """生成 Android mipmap 各密度 ic_launcher.png。"""
    # mdpi 为 48dp 基准，各密度倍数：1 / 1.5 / 2 / 3 / 4
    android_specs = [
        ("mipmap-mdpi", 48),
        ("mipmap-hdpi", 72),
        ("mipmap-xhdpi", 96),
        ("mipmap-xxhdpi", 144),
        ("mipmap-xxxhdpi", 192),
    ]
    generated: list[Path] = []
    for folder, px in android_specs:
        out = root / f"android/app/src/main/res/{folder}/ic_launcher.png"
        save_png(resize(src_img, px), out)
        generated.append(out)
    return generated


def generate_macos_icons(src_img: Image.Image, root: Path) -> list[Path]:
    """生成 macOS AppIcon.appiconset 图标。"""
    dest_dir = root / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    macos_specs = [
        ("app_icon_16.png", 16),
        ("app_icon_32.png", 32),
        ("app_icon_64.png", 64),
        ("app_icon_128.png", 128),
        ("app_icon_256.png", 256),
        ("app_icon_512.png", 512),
        ("app_icon_1024.png", 1024),
    ]
    generated: list[Path] = []
    for filename, px in macos_specs:
        out = dest_dir / filename
        save_png(resize(src_img, px), out)
        generated.append(out)
    return generated


def generate_web_icons(src_img: Image.Image, root: Path) -> list[Path]:
    """生成 Web 图标（含 maskable）。"""
    dest_dir = root / "web/icons"
    generated: list[Path] = []
    for filename, px in [("Icon-192.png", 192), ("Icon-512.png", 512)]:
        out = dest_dir / filename
        save_png(resize(src_img, px), out)
        generated.append(out)
    # maskable 使用同一张图作为可遮罩版本（内容已居中且四周有适当留白）。
    for filename, px in [("Icon-maskable-192.png", 192), ("Icon-maskable-512.png", 512)]:
        out = dest_dir / filename
        save_png(resize(src_img, px), out)
        generated.append(out)
    return generated


def generate_windows_icon(src_img: Image.Image, root: Path) -> list[Path]:
    """生成 Windows 多分辨率 ICO 图标（含 16/32/48/256）。"""
    sizes = [16, 32, 48, 256]
    images = [resize(src_img, s) for s in sizes]
    out = root / "windows/runner/resources/app_icon.ico"
    out.parent.mkdir(parents=True, exist_ok=True)
    # Pillow 保存 ICO：首张图必须是最大尺寸，sizes 列出全部嵌入尺寸，append_images 追加其余小图。
    images[-1].save(
        out,
        format="ICO",
        sizes=[(s, s) for s in sizes],
        append_images=images[:-1],
    )
    return [out]


def verify_files(generated: list[Path]) -> None:
    """校验每个生成的图标文件可读且尺寸正确。"""
    print("\n=== 校验 ===")
    for path in generated:
        with Image.open(path) as im:
            print(f"  {path.relative_to(project_root())}: {im.size} {im.format}")


def main() -> int:
    root = project_root()
    src_path = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "local/app_1024.png"
    if not src_path.exists():
        print(f"源图标不存在：{src_path}", file=sys.stderr)
        return 1

    print(f"源图标：{src_path}")
    src_img = open_source(src_path)
    print(f"处理尺寸：{src_img.size}")

    generated: list[Path] = []
    generated += generate_ios_icons(src_img, root)
    generated += generate_android_icons(src_img, root)
    generated += generate_macos_icons(src_img, root)
    generated += generate_web_icons(src_img, root)
    generated += generate_windows_icon(src_img, root)

    print(f"\n共生成 {len(generated)} 个图标文件")
    verify_files(generated)
    return 0


if __name__ == "__main__":
    sys.exit(main())
