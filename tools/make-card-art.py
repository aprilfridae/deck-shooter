# Bakes the card art into assets/cards/, which git ignores. Needs Jost's variable font in
# assets/fonts/, from the google/fonts repo. Then upload the images with upload-group-assets.py
# and put their ids in src/shared/CardCore/CardArt.luau.
#
#   python tools/make-card-art.py
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

SCALE = 4  # pixels per card unit
WIDTH, HEIGHT = 150, 240
CORNER = 10
FONT = "assets/fonts/Jost[wght].ttf"
WEIGHT = 600
FONT_SIZE = 600
GAP = 0.0  # between the two letters, in font sizes
BOX = (12, 12, 104, 158)  # where the monogram sits: left, top, right, bottom
HAIRLINE = 1.2
GLOW_BLUR = 20
OUT = "assets/cards"

NAVY = (41, 50, 79)
BONE = (232, 230, 223)
ACID = (194, 254, 11)
RED = (255, 13, 26)
CYAN = (1, 255, 255)
VOID = (14, 16, 24)

MONOGRAMS = ["PD", "OC", "RP", "AS"]
LOOKS = {  # background, monogram, ink, glow
    "Field": (NAVY, BONE, BONE, BONE),
    "Redline": (BONE, RED, NAVY, RED),
    "Prototype": (ACID, NAVY, NAVY, None),
    "ZeroDay": (VOID, CYAN, BONE, CYAN),
}


def units(value):
    return round(value * SCALE)


def letters(monogram):
    """The two letters as a white mask, cropped to their ink."""
    font = ImageFont.truetype(FONT, FONT_SIZE)
    font.set_variation_by_axes([WEIGHT])
    mask = Image.new("L", (FONT_SIZE * 3, FONT_SIZE * 2), 0)
    draw = ImageDraw.Draw(mask)
    x = FONT_SIZE // 4
    first, second = monogram
    draw.text((x, FONT_SIZE // 4), first, font=font, fill=255)
    x += font.getlength(first) + GAP * FONT_SIZE
    layer = Image.new("L", mask.size, 0)
    ImageDraw.Draw(layer).text((x, FONT_SIZE // 4), second, font=font, fill=255)
    mask = ImageChops.lighter(mask, layer)
    return mask.crop(mask.getbbox())


def fitted(monogram):
    """The monogram as a card-sized mask, reading up the card and filling BOX exactly."""
    left, top, right, bottom = BOX
    tall, wide = units(bottom - top), units(right - left)
    mask = letters(monogram).resize((tall, wide), Image.LANCZOS).rotate(90, expand=True)
    card = Image.new("L", (units(WIDTH), units(HEIGHT)), 0)
    card.paste(mask, (units(left), units(top)))
    return card


def details(image, ink):
    """The parts every card shares: crosshair, ticks, slashes and rule."""
    draw = ImageDraw.Draw(image)
    width = units(HAIRLINE)

    def line(x0, y0, x1, y1):
        draw.line([units(x0), units(y0), units(x1), units(y1)], fill=ink, width=width)

    draw.ellipse([units(123), units(35), units(137), units(49)], outline=ink, width=width)
    line(130, 32, 130, 52)
    line(120, 42, 140, 42)
    for y in range(62, 95, 8):
        line(125, y, 135, y)
    for x in range(116, 135, 6):
        line(x, 192, x + 6, 182)
    line(10, 204, 140, 204)


def base(monogram, look):
    background, colour, ink, glow = LOOKS[look]
    image = Image.new("RGB", (units(WIDTH), units(HEIGHT)), background)
    mask = fitted(monogram)
    if glow:
        soft = mask.filter(ImageFilter.GaussianBlur(GLOW_BLUR))
        image.paste(Image.new("RGB", image.size, glow), (0, 0), soft)
    image.paste(Image.new("RGB", image.size, colour), (0, 0), mask)
    details(image, ink)
    return image


def rounded(image):
    """Clear corners, so the card's shape holds wherever it sits."""
    corners = Image.new("L", image.size, 0)
    ImageDraw.Draw(corners).rounded_rectangle([0, 0, image.width - 1, image.height - 1], units(CORNER), fill=255)
    image = image.convert("RGBA")
    image.putalpha(corners)
    return image


def outline(monogram):
    """The monogram's edge only, in white, for Prototype's pulse."""
    mask = fitted(monogram)
    grown = mask.filter(ImageFilter.MaxFilter(9))
    edge = ImageChops.subtract(grown, mask)
    image = Image.new("RGBA", mask.size, (255, 255, 255, 0))
    image.putalpha(edge)
    return image


def stripes():
    """One tile of white hazard stripes, for the game to tint and scroll."""
    size = units(14)
    image = Image.new("RGBA", (size * 2, size * 2), (255, 255, 255, 0))
    draw = ImageDraw.Draw(image)
    band = units(5)
    for offset in range(-size * 2, size * 4, size):
        draw.line([offset, size * 2, offset + size * 2, 0], fill=(255, 255, 255, 255), width=band)
    return image


def main():
    os.makedirs(OUT, exist_ok=True)
    for monogram in MONOGRAMS:
        for look in LOOKS:
            rounded(base(monogram, look)).save(f"{OUT}/{monogram}_{look}.png")
        outline(monogram).save(f"{OUT}/{monogram}_outline.png")
    stripes().save(f"{OUT}/stripes.png")


if __name__ == "__main__":
    main()
