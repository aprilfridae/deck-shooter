# Bakes the pack wrappers into assets/packs/, which git ignores. Needs the KH Interference font in
# assets/fonts/. Then upload the images with upload-group-assets.py
# and put their ids in src/shared/CardCore/PackArt.luau. The name, stripes and effects are live.
#
#   python tools/make-pack-art.py
import importlib.util
import os

from PIL import Image, ImageDraw, ImageFilter

spec = importlib.util.spec_from_file_location("card_art", "tools/make-card-art.py")
card_art = importlib.util.module_from_spec(spec)
spec.loader.exec_module(card_art)

units = card_art.units
NAVY, BONE, ACID, RED, CYAN, VOID = (
    card_art.NAVY,
    card_art.BONE,
    card_art.ACID,
    card_art.RED,
    card_art.CYAN,
    card_art.VOID,
)

WIDTH, HEIGHT = 150, 230
CRIMP = 14  # how deep the crimped ends are
TOOTH = 5  # width of each tooth along the ends
TOOTH_DEPTH = 4
PLEAT = 5  # spacing of the pleats in the crimped ends
SIDE_INSET = 8  # the outline, from the wrapper's sides
OUTLINE = 2
BOX = (20, 30, 130, 158)  # where the S1 sits: left, top, right, bottom
GLOW_BLUR = 22
OUT = "assets/packs"

PACKS = {  # background, art, glow
    "Field": (NAVY, BONE, None),
    "BlackSite": (BONE, RED, RED),
    "Prototype": (ACID, NAVY, None),
    "ZeroDay": (VOID, CYAN, CYAN),
}


def wrapper_mask():
    """The wrapper's shape: a rectangle with toothed top and bottom edges."""
    width, height = units(WIDTH), units(HEIGHT)
    tooth, depth = units(TOOTH), units(TOOTH_DEPTH)
    points = []
    for index, x in enumerate(range(0, width + tooth, tooth)):
        points.append((min(x, width), depth if index % 2 else 0))
    for index, x in enumerate(range(width, -tooth, -tooth)):
        points.append((max(x, 0), height - depth if index % 2 else height))
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    return mask


def shaded(colour, amount):
    """The colour moved towards black, or towards white for a negative amount."""
    target = 255 if amount < 0 else 0
    return tuple(round(c + (target - c) * abs(amount)) for c in colour)


def crimps(image, colour):
    """The pressed ends: a darker band with pleats running along the wrapper."""
    draw = ImageDraw.Draw(image)
    width, height = image.size
    deep = units(CRIMP)
    dark = shaded(colour, 0.16) + (255,)
    pleat = shaded(colour, 0.3) + (255,)
    for top, bottom in ((0, deep), (height - deep, height)):
        draw.rectangle([0, top, width, bottom], fill=dark)
        for x in range(0, width, units(PLEAT)):
            draw.line([x, top, x, bottom], fill=pleat, width=units(1))


def foil(image):
    """Soft light down the wrapper, so it reads as a foil bag."""
    width, height = image.size
    light = Image.new("L", (width, 1), 0)
    for x in range(width):
        across = x / width
        amount = 0.09 * (1 - min(abs(across - 0.3) / 0.3, 1)) + 0.05 * (1 - min(abs(across - 0.82) / 0.14, 1))
        light.putpixel((x, 0), round(255 * amount))
    light = light.resize((width, height))
    image.paste(Image.new("RGBA", image.size, (255, 255, 255, 255)), (0, 0), light)


def fitted_s1():
    """The set's name as a wrapper-sized mask, reading up the wrapper and filling BOX."""
    left, top, right, bottom = BOX
    tall, wide = units(bottom - top), units(right - left)
    mask = card_art.letters("S1").resize((tall, wide), Image.LANCZOS).rotate(90, expand=True)
    sheet = Image.new("L", (units(WIDTH), units(HEIGHT)), 0)
    sheet.paste(mask, (units(left), units(top)))
    return sheet


def wrapper(background, art, glow):
    size = (units(WIDTH), units(HEIGHT))
    image = Image.new("RGBA", size, background + (255,))
    letters = fitted_s1()
    if glow:
        haze = letters.filter(ImageFilter.GaussianBlur(units(GLOW_BLUR) / 2)).point(lambda value: value // 2)
        image.paste(Image.new("RGBA", size, glow + (255,)), (0, 0), haze)
    image.paste(Image.new("RGBA", size, art + (255,)), (0, 0), letters)
    foil(image)
    crimps(image, background)
    draw = ImageDraw.Draw(image)
    inset = units(SIDE_INSET)
    deep = units(CRIMP + 4)
    draw.rectangle(
        [inset, deep, size[0] - inset, size[1] - deep],
        outline=art + (255,),
        width=units(OUTLINE),
    )
    image.putalpha(wrapper_mask())
    return image


def main():
    os.makedirs(OUT, exist_ok=True)
    for pack, (background, art, glow) in PACKS.items():
        wrapper(background, art, glow).save(f"{OUT}/{pack}.png")


if __name__ == "__main__":
    main()
