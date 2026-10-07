#!/usr/bin/env python3
"""Render cuplikan terminal dari output pengujian tersimpan (opsional)."""

from pathlib import Path
import subprocess

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent
FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 19)
FONT_BOLD = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", 19)
OUTPUT = ROOT / "screenshots"


def capture(command):
    completed = subprocess.run(
        ["bash", "-c", command], cwd=ROOT, check=True, capture_output=True, text=True
    )
    return [f"$ {command}", *completed.stdout.rstrip("\n").splitlines()]


def render(filename, title, lines):
    lines = [line.expandtabs(20) for line in lines]
    width = max(1150, max(FONT.getlength(line) for line in lines) + 76)
    height = 78 + len(lines) * 29 + 35
    image = Image.new("RGB", (int(width), height), "#0d1117")
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, width, 53), fill="#21262d")
    for x, color in [(29, "#f85149"), (52, "#e3b341"), (75, "#3fb950")]:
        draw.ellipse((x - 7, 19, x + 7, 33), fill=color)
    draw.text((103, 16), title, font=FONT_BOLD, fill="#c9d1d9")

    y = 76
    for line in lines:
        color = "#7ee787" if line.startswith("$ ") else "#c9d1d9"
        draw.text((34, y), line, font=FONT, fill=color)
        y += 29
    image.save(OUTPUT / filename)


def main():
    OUTPUT.mkdir(exist_ok=True)
    render(
        "hasil-paralel.png",
        "Hasil 4 worker | output/uji-4c",
        [
            *capture("wc -l output/uji-4c/manifests/*.txt"),
            "",
            *capture("cat output/uji-4c/summary.tsv"),
        ],
    )
    render(
        "waktu-pengujian.png",
        "Waktu 3 percobaan per konfigurasi",
        capture(
            "awk -F '\\t' '$1==\"elapsed_seconds\" {print FILENAME \": \" $2 \" s\"}' "
            "output/uji-{1,2,4}{a,b,c}/summary.tsv"
        ),
    )
    print("Gambar dibuat: screenshots/hasil-paralel.png dan screenshots/waktu-pengujian.png")


if __name__ == "__main__":
    main()
