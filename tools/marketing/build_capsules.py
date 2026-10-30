"""Build Steam capsule and library variants from the project key art."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "marketing/steam/source"
OUTPUT = ROOT / "marketing/steam/capsules"
FONT = ROOT / "assets/fonts/barlow/Barlow-Black.ttf"
OUTPUT.mkdir(parents=True, exist_ok=True)

WIDE = Image.open(SOURCE / "key_art_wide.png").convert("RGB")
PORTRAIT = Image.open(SOURCE / "key_art_portrait.png").convert("RGB")


def fit(image: Image.Image, size: tuple[int, int], centering=(0.5, 0.5)) -> Image.Image:
    return ImageOps.fit(image, size, method=Image.Resampling.LANCZOS, centering=centering).convert("RGBA")


def darken(image: Image.Image, strength: int, start: float = 0.35) -> None:
    width, height = image.size
    shade = Image.new("RGBA", image.size, (0, 0, 0, 0))
    alpha = Image.new("L", (1, height))
    for y in range(height):
        amount = max(0.0, (y / height - start) / (1.0 - start))
        alpha.putpixel((0, y), round(strength * min(1.0, amount)))
    shade.putalpha(alpha.resize(image.size))
    image.alpha_composite(shade)


def title(image: Image.Image, scale: float, bottom: float = 0.92) -> None:
    draw = ImageDraw.Draw(image)
    width, height = image.size
    main_font = ImageFont.truetype(FONT, max(18, int(height * scale)))
    sub_font = ImageFont.truetype(FONT, max(15, int(height * scale * 0.47)))
    line1 = "911"
    line2 = "THE LAST CALL"
    bbox1 = draw.textbbox((0, 0), line1, font=main_font, stroke_width=0)
    bbox2 = draw.textbbox((0, 0), line2, font=sub_font, stroke_width=0)
    # Keep the title inside the smallest Steam crop.
    max_width = width * 0.9
    if bbox2[2] > max_width:
        sub_font = ImageFont.truetype(FONT, int(sub_font.size * max_width / bbox2[2]))
        bbox2 = draw.textbbox((0, 0), line2, font=sub_font)
    y2 = int(height * bottom) - (bbox2[3] - bbox2[1])
    y1 = y2 - (bbox1[3] - bbox1[1]) - int(height * 0.025)
    draw.text((width / 2, y1), line1, font=main_font, anchor="ma", fill="#f2f2ed", stroke_width=max(2, height // 300), stroke_fill="#071019")
    draw.text((width / 2, y2), line2, font=sub_font, anchor="ma", fill="#f6ba62", stroke_width=max(1, height // 480), stroke_fill="#071019")


def capsule(name: str, size: tuple[int, int], source: Image.Image, scale: float, centering=(0.5, 0.5)) -> None:
    image = fit(source, size, centering)
    darken(image, 225, 0.25)
    title(image, scale)
    image.convert("RGB").save(OUTPUT / name, quality=94, subsampling=0)


capsule("header_capsule.jpg", (920, 430), WIDE, 0.24)
capsule("small_capsule.jpg", (462, 174), WIDE, 0.34)
capsule("main_capsule.jpg", (1232, 706), WIDE, 0.22)
capsule("vertical_capsule.jpg", (748, 896), PORTRAIT, 0.21, (0.5, 0.52))
capsule("library_capsule.jpg", (600, 900), PORTRAIT, 0.22, (0.5, 0.52))
capsule("library_header.jpg", (920, 430), WIDE, 0.24)

hero = fit(WIDE, (3840, 1240))
hero.convert("RGB").save(OUTPUT / "library_hero.jpg", quality=94, subsampling=0)

logo = Image.new("RGBA", (1280, 720), (0, 0, 0, 0))
title(logo, 0.34, 0.76)
logo.save(OUTPUT / "library_logo.png")

icon = fit(PORTRAIT, (256, 256), (0.5, 0.82))
darken(icon, 230, 0.08)
title(icon, 0.39, 0.92)
icon.save(OUTPUT / "shortcut_icon.png")
icon.convert("RGB").resize((184, 184), Image.Resampling.LANCZOS).save(OUTPUT / "app_icon.jpg", quality=95)

for path in sorted(OUTPUT.iterdir()):
    image = Image.open(path)
    print(f"{path.name}: {image.width}x{image.height}")
