"""Bakes the front of the cards as layers, from River's drawing and the game's two fonts.

Run: python tools/make-card-art.py <folder holding PPFraktionMono-Regular.otf and -Bold.otf>
Reads assets/cards/source/base.svg (River's micrographics, 1280 by 2048).
Writes assets/cards/layers/*.png (white on clear, tinted by the game) and assets/cards/flat/*.png
(one finished still card per card and look, for the card held in hand).

Every box here matches src/shared/CardCore/CardLayout.luau: change both together.
The design is docs/specs/card-face-redesign.md.
"""
import math
import os
import sys
import xml.etree.ElementTree as ET

from fontTools.pens.recordingPen import RecordingPen
from fontTools.svgLib.path import parse_path
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

WIDTH, HEIGHT = 1280, 2048
CORNER = 85
SOURCE = "assets/cards/source/base.svg"
LAYERS = "assets/cards/layers"
FLAT = "assets/cards/flat"
KH = "assets/fonts/KHInterferencePRO-Bold.otf"
SUPER = 3  # drawn this many times too big, then shrunk, for smooth edges
STROKE = 5  # River's file says 2. 5 keeps hairlines alive when a card is shown small.
GLOBE_DROP = 170  # River, 2026-11-11: "come a bit lower on the card"
CURVE_STEPS = 24

MONOGRAM = (45, 69, 645, 1061)
RAYS = (773, 308, 462, 172)
STAR_BIG = (706, 443, 386, 386)
STAR_SMALL = (948, 559, 154, 154)
NAME = (36, 1800, 760, 104)
NAME_LINE = 1891
NAME_SIZE = 112
NAME_STROKE = 0.024  # of the size, added round each letter: Regular thickened into a medium
BARCODE = (839, 1919, 396, 84)
LOW_SERIAL = (860, 1780, 400, 240)
LOW_GLOW = (800, 1730, 480, 318)
LOW_ORIGIN = (905, 2003)
LOW_SIZE = 275
GLOW_BLUR = 15
CROSSHAIR = (520, 1356, 240, 240)
MEASURE = (45, 1140, 645, 60)
GRID_TILE = 80
GRID_LINE = 3
SWIRL_LINE = 3
SWIRLS = [(860, 9, 0.2, 16), (470, 7, 0.28, 14), (190, 5, 0.35, 10)]  # radius, lobes, depth, curves
# Each bar's left edge and width, in a strip 330 wide.
BARS = [(0, 10), (20, 4), (34, 16), (60, 4), (72, 8), (92, 20), (120, 4), (132, 4), (146, 12), (168, 6),
        (182, 18), (208, 4), (222, 10), (240, 4), (254, 16), (278, 6), (292, 4), (306, 24)]

CARDS = {"phase_dash": ("PD", "Phase Dash"), "overclock": ("OC", "Overclock"),
         "recon_pulse": ("RP", "Recon Pulse"), "aegis_shell": ("AS", "Aegis Shell")}
NAVY, BONE, ACID = (41, 50, 79), (232, 230, 223), (194, 254, 11)
RED, CYAN, VOID = (255, 13, 26), (1, 255, 255), (14, 16, 24)
LOOKS = {  # background, acronym, ink
    "Field": (NAVY, BONE, BONE),
    "Redline": (BONE, RED, NAVY),
    "Prototype": (ACID, NAVY, NAVY),
    "ZeroDay": (VOID, CYAN, BONE),
}


def px(value):
    return round(value * SUPER)


def blank():
    return Image.new("L", (WIDTH * SUPER, HEIGHT * SUPER), 0)


def finish(image):
    """Shrinks a drawing to one pixel per unit."""
    return image.resize((WIDTH, HEIGHT), Image.LANCZOS)


def tag(element):
    return element.tag.split("}")[1]


def number(element, name):
    return float(element.get(name))


def points(text):
    values = [float(v) for v in text.replace(",", " ").split()]
    return list(zip(values[0::2], values[1::2]))


def flatten(d):
    """A path's outline as straight pieces."""
    pen = RecordingPen()
    parse_path(d, pen)
    outline, at = [], (0, 0)
    for kind, args in pen.value:
        if kind in ("moveTo", "lineTo"):
            at = args[0]
            outline.append(at)
        elif kind == "curveTo":
            a, b, c = args
            for step in range(1, CURVE_STEPS + 1):
                t = step / CURVE_STEPS
                u = 1 - t
                outline.append(tuple(u ** 3 * at[i] + 3 * u * u * t * a[i] + 3 * u * t * t * b[i] + t ** 3 * c[i]
                                     for i in (0, 1)))
            at = c
    return outline


def line(draw, x0, y0, x1, y1, width=STROKE):
    draw.line([px(x0), px(y0), px(x1), px(y1)], fill=255, width=px(width))


def box(draw, x, y, w, h):
    draw.rectangle([px(x), px(y), px(x + w), px(y + h)], outline=255, width=px(STROKE))


def polygon(draw, corners):
    scaled = [(px(x), px(y)) for x, y in corners]
    draw.polygon(scaled, fill=255)
    draw.line(scaled + scaled[:1], fill=255, width=px(STROKE), joint="curve")


def ring(draw, cx, cy, rx, ry, width=STROKE):
    draw.ellipse([px(cx - rx), px(cy - ry), px(cx + rx), px(cy + ry)], outline=255, width=px(width))


def drawing():
    """River's file as full-card masks: the still parts, the rays, the burst's dot and the two sparkles."""
    root = ET.parse(SOURCE).getroot()
    still, rays, dot = blank(), blank(), blank()
    stars = []
    still_draw, rays_draw = ImageDraw.Draw(still), ImageDraw.Draw(rays)
    for element in root:
        kind = tag(element)
        if kind == "polygon":
            polygon(still_draw, points(element.get("points")))
        elif kind == "rect":
            # One box carries a quarter turn about its own middle. It's a square, so it lands where it started.
            box(still_draw, number(element, "x"), number(element, "y"), number(element, "width"), number(element, "height"))
        elif kind == "line":
            line(rays_draw, number(element, "x1"), number(element, "y1"), number(element, "x2"), number(element, "y2"))
        elif kind == "circle":
            cx, cy, r = number(element, "cx"), number(element, "cy"), number(element, "r")
            ImageDraw.Draw(dot).ellipse([px(cx - r), px(cy - r), px(cx + r), px(cy + r)], fill=255)
        elif kind == "path":
            star = blank()
            ImageDraw.Draw(star).polygon([(px(x), px(y)) for x, y in flatten(element.get("d"))], fill=255)
            stars.append(star)
        elif kind == "g":  # the globe
            for part in element:
                if tag(part) == "ellipse":
                    ring(still_draw, number(part, "cx"), number(part, "cy") + GLOBE_DROP, number(part, "rx"), number(part, "ry"))
                else:
                    line(still_draw, number(part, "x1"), number(part, "y1") + GLOBE_DROP,
                         number(part, "x2"), number(part, "y2") + GLOBE_DROP)
    assert len(stars) == 2, "expected two sparkles in the drawing"
    return finish(still), finish(rays), finish(dot), finish(stars[0]), finish(stars[1])


def monogram(letters):
    """The two letters, turned to read up the card and stretched to fill their box exactly."""
    size = 600
    font = ImageFont.truetype(KH, size)
    mask = Image.new("L", (size * 3, size * 2), 0)
    draw = ImageDraw.Draw(mask)
    draw.text((size // 4, size // 4), letters[0], font=font, fill=255)
    second = Image.new("L", mask.size, 0)
    ImageDraw.Draw(second).text((size // 4 + font.getlength(letters[0]), size // 4), letters[1], font=font, fill=255)
    mask = ImageChops.lighter(mask, second)
    mask = mask.crop(mask.getbbox())
    x, y, w, h = MONOGRAM
    turned = mask.resize((h, w), Image.LANCZOS).rotate(90, expand=True)
    card = Image.new("L", (WIDTH, HEIGHT), 0)
    card.paste(turned, (x, y))
    return card


def text(font_path, size, words, origin, stroke=0.0):
    """Text with its left origin and baseline at this point on the card."""
    font = ImageFont.truetype(font_path, px(size))
    card = blank()
    ImageDraw.Draw(card).text((px(origin[0]), px(origin[1])), words, font=font, fill=255, anchor="ls",
                              stroke_width=round(size * stroke / 2 * SUPER), stroke_fill=255)
    return finish(card)


def barcode():
    card = blank()
    draw = ImageDraw.Draw(card)
    x, y, w, h = BARCODE
    scale = w / 330
    for left, width in BARS:
        draw.rectangle([px(x + left * scale), px(y), px(x + (left + width) * scale) - 1, px(y + h) - 1], fill=255)
    return finish(card)


def swirl():
    """Fine looping lines like the engraving on a banknote, for Zero-Day's background."""
    card = blank()
    draw = ImageDraw.Draw(card)
    steps = 480
    for radius, lobes, depth, curves in SWIRLS:
        for k in range(curves):
            loop = []
            for step in range(steps + 1):
                angle = step / steps * 2 * math.pi
                r = radius * (1 + depth * math.sin(lobes * angle + k * 2 * math.pi / curves))
                loop.append((px(640 + r * math.cos(angle)), px(1024 + r * math.sin(angle))))
            draw.line(loop, fill=255, width=px(SWIRL_LINE))
    return finish(card)


def crosshair():
    card = blank()
    draw = ImageDraw.Draw(card)
    cx, cy = CROSSHAIR[0] + CROSSHAIR[2] / 2, CROSSHAIR[1] + CROSSHAIR[3] / 2
    ring(draw, cx, cy, 56, 56)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        line(draw, cx + dx * 30, cy + dy * 30, cx + dx * 90, cy + dy * 90)
    for sx in (-1, 1):
        for sy in (-1, 1):
            line(draw, cx + sx * 110, cy + sy * 80, cx + sx * 110, cy + sy * 110)
            line(draw, cx + sx * 110, cy + sy * 110, cx + sx * 80, cy + sy * 110)
    return finish(card)


def measure():
    """A dimension line: end ticks, the line, an arrowhead at each end."""
    card = blank()
    draw = ImageDraw.Draw(card)
    x, y, w, h = MEASURE
    middle = y + h / 2
    line(draw, x + 2, y, x + 2, y + h, 4)
    line(draw, x + w - 2, y, x + w - 2, y + h, 4)
    line(draw, x, middle, x + w, middle, 4)
    draw.polygon([(px(x), px(middle)), (px(x + 34), px(middle - 16)), (px(x + 34), px(middle + 16))], fill=255)
    draw.polygon([(px(x + w), px(middle)), (px(x + w - 34), px(middle - 16)), (px(x + w - 34), px(middle + 16))], fill=255)
    return finish(card)


def grid():
    """Two repeats each way of one tile: a line along its top and its left."""
    image = Image.new("L", (GRID_TILE * 2, GRID_TILE * 2), 0)
    draw = ImageDraw.Draw(image)
    for start in (0, GRID_TILE):
        draw.rectangle([0, start, GRID_TILE * 2 - 1, start + GRID_LINE - 1], fill=255)
        draw.rectangle([start, 0, start + GRID_LINE - 1, GRID_TILE * 2 - 1], fill=255)
    return image


def white(mask):
    image = Image.new("RGBA", mask.size, (255, 255, 255, 0))
    image.putalpha(mask)
    return image


def save(mask, name, rect=None, scale=1.0):
    if rect:
        x, y, w, h = rect
        mask = mask.crop((x, y, x + w, y + h))
    if scale != 1:
        mask = mask.resize((round(mask.width * scale), round(mask.height * scale)), Image.LANCZOS)
    white(mask).save(f"{LAYERS}/{name}.png")


def flat(look, masks_in_ink, acronym):
    """A finished still card, for the hand."""
    background, mark, ink = LOOKS[look]
    card = Image.new("RGB", (WIDTH, HEIGHT), background)
    card.paste(Image.new("RGB", card.size, mark), (0, 0), acronym)
    for mask in masks_in_ink:
        card.paste(Image.new("RGB", card.size, ink), (0, 0), mask)
    corners = Image.new("L", card.size, 0)
    ImageDraw.Draw(corners).rounded_rectangle([0, 0, WIDTH - 1, HEIGHT - 1], CORNER, fill=255)
    card = card.convert("RGBA")
    card.putalpha(corners)
    return card.resize((600, 960), Image.LANCZOS)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    regular = os.path.join(sys.argv[1], "PPFraktionMono-Regular.otf")
    bold = os.path.join(sys.argv[1], "PPFraktionMono-Bold.otf")
    os.makedirs(LAYERS, exist_ok=True)
    os.makedirs(FLAT, exist_ok=True)

    still, rays, dot, star_big, star_small = drawing()
    bars = barcode()
    save(still, "still", scale=0.5)
    save(rays, "rays", RAYS)
    save(star_big, "star_big", STAR_BIG)
    save(star_small, "star_small", STAR_SMALL)
    save(bars, "barcode", BARCODE)
    save(swirl(), "swirl", scale=0.5)
    save(crosshair(), "crosshair", CROSSHAIR)
    save(measure(), "measure", MEASURE)
    white(grid()).save(f"{LAYERS}/grid.png")

    for card_id, (letters, name) in CARDS.items():
        acronym = monogram(letters)
        printed = text(regular, NAME_SIZE, name.upper().replace(" ", ""), (NAME[0], NAME_LINE), NAME_STROKE)
        save(acronym, f"mono_{letters}", MONOGRAM)
        save(printed, f"name_{card_id}", NAME)
        for look in LOOKS:
            flat(look, [still, rays, dot, star_big, star_small, printed, bars], acronym).save(f"{FLAT}/{letters}_{look}.png")

    for serial in range(1, 11):
        digits = text(bold, LOW_SIZE, f"{serial:02d}", LOW_ORIGIN)
        save(digits, f"low_{serial:02d}", LOW_SERIAL)
        save(digits.filter(ImageFilter.GaussianBlur(GLOW_BLUR)), f"low_glow_{serial:02d}", LOW_GLOW)

    print(len(os.listdir(LAYERS)), "layers,", len(os.listdir(FLAT)), "flat cards")


if __name__ == "__main__":
    main()
