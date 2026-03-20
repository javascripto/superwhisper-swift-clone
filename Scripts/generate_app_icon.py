#!/usr/bin/env python3
from __future__ import annotations

import math
import os
import shutil
import struct
import subprocess
import tempfile
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "Resources" / "AppIcon.icns"


def clamp(value: float) -> int:
    return max(0, min(255, int(round(value))))


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def blend(base: tuple[int, int, int, int], top: tuple[int, int, int, int], alpha: float) -> tuple[int, int, int, int]:
    return (
        clamp(lerp(base[0], top[0], alpha)),
        clamp(lerp(base[1], top[1], alpha)),
        clamp(lerp(base[2], top[2], alpha)),
        clamp(lerp(base[3], top[3], alpha)),
    )


def write_png(path: Path, width: int, height: int, pixels: bytes) -> None:
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)
        raw.extend(pixels[y * stride:(y + 1) * stride])

    png = bytearray()
    png.extend(b"\x89PNG\r\n\x1a\n")
    png.extend(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)))
    png.extend(chunk(b"IDAT", zlib.compress(bytes(raw), level=9)))
    png.extend(chunk(b"IEND", b""))
    path.write_bytes(bytes(png))


def rounded_rect_mask(x: float, y: float, size: float, radius: float) -> float:
    cx = min(max(x, radius), size - radius)
    cy = min(max(y, radius), size - radius)
    dx = x - cx
    dy = y - cy
    return 1.0 if dx * dx + dy * dy <= radius * radius else 0.0


def render_icon(size: int) -> bytes:
    pixels = bytearray(size * size * 4)
    bg1 = (11, 16, 23, 255)
    bg2 = (4, 8, 13, 255)
    glow = (44, 195, 232, 255)
    accent = (104, 247, 174, 255)
    white = (240, 244, 248, 255)

    cx = cy = size / 2.0
    rounded = size * 0.18
    mic_center_x = size * 0.50
    mic_center_y = size * 0.46
    mic_radius = size * 0.16

    for y in range(size):
        for x in range(size):
            i = (y * size + x) * 4
            nx = x / (size - 1)
            ny = y / (size - 1)
            grad = ny * 0.75 + nx * 0.1
            r, g, b, a = blend(bg1, bg2, grad)

            dx = (x - cx) / size
            dy = (y - cy) / size
            vignette = max(0.0, 1.0 - math.sqrt(dx * dx + dy * dy) * 1.55)
            r = clamp(r + vignette * 10)
            g = clamp(g + vignette * 8)
            b = clamp(b + vignette * 12)

            mask = rounded_rect_mask(x, y, size, rounded)
            if not mask:
                pixels[i:i + 4] = b"\x00\x00\x00\x00"
                continue

            glow_dx = x - mic_center_x
            glow_dy = y - mic_center_y
            glow_dist = math.sqrt(glow_dx * glow_dx + glow_dy * glow_dy)
            glow_alpha = max(0.0, 1.0 - glow_dist / (size * 0.38)) ** 2
            r = clamp(r + glow[0] * glow_alpha * 0.35)
            g = clamp(g + glow[1] * glow_alpha * 0.35)
            b = clamp(b + glow[2] * glow_alpha * 0.35)

            outer = max(0.0, 1.0 - abs(glow_dist - mic_radius) / (size * 0.06))
            ring = outer ** 1.8
            r = clamp(r + glow[0] * ring * 0.45)
            g = clamp(g + glow[1] * ring * 0.45)
            b = clamp(b + glow[2] * ring * 0.45)

            mic_dx = x - mic_center_x
            mic_dy = y - mic_center_y
            mic_dist = math.sqrt(mic_dx * mic_dx + mic_dy * mic_dy)
            if mic_dist <= mic_radius:
                fill = 1.0 - (mic_dist / mic_radius)
                r = clamp(lerp(r, white[0], fill * 0.58))
                g = clamp(lerp(g, white[1], fill * 0.58))
                b = clamp(lerp(b, white[2], fill * 0.58))

            # Wave bars below the mic.
            wave_y = size * 0.62
            bar_specs = [
                (size * 0.33, size * 0.045, size * 0.11),
                (size * 0.43, size * 0.045, size * 0.18),
                (size * 0.53, size * 0.045, size * 0.14),
                (size * 0.63, size * 0.045, size * 0.22),
            ]
            for bar_x, bar_w, bar_h in bar_specs:
                if abs(x - bar_x) <= bar_w and abs(y - wave_y) <= bar_h:
                    y_falloff = 1.0 - abs(y - wave_y) / bar_h
                    x_falloff = 1.0 - abs(x - bar_x) / bar_w
                    bar_alpha = max(0.0, min(y_falloff, x_falloff)) ** 1.5
                    r = clamp(lerp(r, accent[0], bar_alpha))
                    g = clamp(lerp(g, accent[1], bar_alpha))
                    b = clamp(lerp(b, accent[2], bar_alpha))

            pixels[i:i + 4] = bytes((r, g, b, a))

    return bytes(pixels)


def build_icns(output: Path) -> None:
    icon_sizes = [16, 32, 64, 128, 256, 512, 1024]
    with tempfile.TemporaryDirectory(prefix="whisperoverlay-icon-") as tmp:
        iconset = Path(tmp) / "AppIcon.iconset"
        iconset.mkdir()

        for size in icon_sizes:
            pixels = render_icon(size)
            write_png(iconset / f"icon_{size}x{size}.png", size, size, pixels)
            if size < 1024:
                # Add the retina entry for the canonical macOS icon sizes.
                if size in {16, 32, 128, 256, 512}:
                    retina_size = size * 2
                    retina_pixels = render_icon(retina_size)
                    write_png(iconset / f"icon_{size}x{size}@2x.png", retina_size, retina_size, retina_pixels)

        if output.exists():
            output.unlink()

        subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(output)], check=True)


def main() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    build_icns(OUTPUT)
    print(f"Generated {OUTPUT}")


if __name__ == "__main__":
    main()
