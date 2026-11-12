# Bakes the HUD's shapes to white PNGs the game can tint (docs/specs/hud-redesign.md).
# Two come from River's HUD shape pack; the cut-corner button images and the gun icon are drawn here.
#
#   python tools/make-hud-shapes.py "H:/graphj/assets/hudassets/hudassets/PNG (telegram - @all4designer)"
#
# Writes assets/hud/shapes/. Upload them with tools/upload-group-assets.py and put the ids in
# src/shared/Guns/Hud/HudShapes.luau.
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = "assets/hud/shapes"
WIDTH = 512
PACK = {"Plate": 94, "Stripe": 91}
OUTLINE = 15  # an odd number: the plate outline's thickness is half of it, in pixels at full width
CUT_SIZE = 64
CUT = 24  # how much of each cut corner is taken off, in pixels
CUT_LINE = 2
SCALE = 4  # drawn this much bigger, then shrunk, for smooth edges


def white(alpha):
    out = Image.new("RGBA", alpha.size, (255, 255, 255, 0))
    out.putalpha(alpha)
    return out


def from_pack(folder, number):
    image = Image.open(os.path.join(folder, f"Asset {number} (telegram - @all4designer).png")).convert("RGBA")
    height = round(image.height * WIDTH / image.width)
    return white(image.resize((WIDTH, height), Image.LANCZOS).split()[3])


def cut_points(size, cut, inset=0.0):
    # A square with its top right and bottom left corners cut at 45 degrees.
    low, high = inset, size - inset
    lean = inset * 0.4142  # keeps the slanted edge the same distance in as the straight ones
    return [
        (low, low),
        (high - cut + lean, low),
        (high, low + cut - lean),
        (high, high),
        (low + cut - lean, high),
        (low, high - cut + lean),
    ]


def cut_corner(outline):
    big = CUT_SIZE * SCALE
    mask = Image.new("L", (big, big), 0)
    draw = ImageDraw.Draw(mask)
    draw.polygon(cut_points(big, CUT * SCALE), fill=255)
    if outline:
        draw.polygon(cut_points(big, CUT * SCALE, CUT_LINE * SCALE), fill=0)
    return white(mask.resize((CUT_SIZE, CUT_SIZE), Image.LANCZOS))


def gun():
    # A pistol, pointing left like a kill feed's: slide, trigger guard and grip.
    width, height = 96 * SCALE, 64 * SCALE
    mask = Image.new("L", (width, height), 0)
    draw = ImageDraw.Draw(mask)

    def box(points, fill=255):
        draw.polygon([(x * SCALE, y * SCALE) for x, y in points], fill=fill)

    box([(4, 12), (90, 12), (92, 16), (92, 28), (4, 28)])  # slide and barrel
    box([(4, 8), (9, 8), (9, 12), (4, 12)])  # front sight
    box([(84, 8), (90, 8), (90, 12), (84, 12)])  # rear sight
    box([(58, 28), (90, 28), (84, 60), (62, 60)])  # grip
    box([(38, 28), (60, 28), (60, 44), (44, 44), (38, 36)])  # trigger guard
    box([(43, 31), (56, 31), (56, 40), (46, 40), (43, 36)], fill=0)  # its hole
    box([(50, 30), (53, 30), (52, 38), (50, 38)])  # trigger
    return white(mask.resize((96, 64), Image.LANCZOS))


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: python tools/make-hud-shapes.py <pack folder>")
    os.makedirs(OUT, exist_ok=True)
    images = {name: from_pack(sys.argv[1], number) for name, number in PACK.items()}
    # The pack's own outline (asset 108) is a hairline that vanishes at a menu button's size, so the outline is
    # cut from the solid plate instead.
    plate = images["Plate"].split()[3]
    padded = Image.new("L", (plate.width + OUTLINE * 2, plate.height + OUTLINE * 2), 0)  # so the edges erode too
    padded.paste(plate, (OUTLINE, OUTLINE))
    inner = padded.filter(ImageFilter.MinFilter(OUTLINE)).crop((OUTLINE, OUTLINE, OUTLINE + plate.width, OUTLINE + plate.height))
    images["PlateOutline"] = white(ImageChops.subtract(plate, inner))
    images["CutFill"] = cut_corner(False)
    images["CutOutline"] = cut_corner(True)
    images["Gun"] = gun()
    for name, image in images.items():
        image.save(os.path.join(OUT, f"{name}.png"))
        print(name, image.size)


main()
