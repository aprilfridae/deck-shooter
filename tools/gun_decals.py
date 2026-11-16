# Where each gun's markings go, for tools/texture_model.py. Each layout is drawn on an exact side render of the gun
# (+Y to the right, muzzle on the left, +Z up), in that render's pixels; lo and hi are the render's bounds in the
# gun's metres (Y, Z). The colours are the game's palette: Bone for text, Signal Acid for accents.
BONE = (232, 230, 223, 255)
BONE_FAINT = (232, 230, 223, 150)
ACID = (194, 254, 11, 255)
CYAN = (1, 255, 255, 255)

M57 = {
    "size": (2048, 568),
    "lo": (-0.604, -0.1827),
    "hi": (0.33, 0.0765),
    "decals": [
        # receiver: the model, the maker and the calibre, and an acid selector box in the recess
        {"kind": "text", "font": "title", "text": "M57", "rect": (1056, 131, 1142, 163)},
        {"kind": "text", "text": "SPLIT/DECK ARMS  7.62x39", "rect": (1153, 143, 1367, 155)},
        {"kind": "frame", "rect": (1390, 134, 1445, 156), "color": ACID},
        {"kind": "rect", "rect": (1398, 140, 1414, 150), "color": ACID},
        # top cover: serial
        {"kind": "text", "text": "SD-0451 // FRIDAE", "rect": (1163, 70, 1460, 85)},
        # stock: barcode, a label, a faint number and acid hazard stripes by the butt
        {"kind": "barcode", "rect": (1550, 128, 1673, 152), "seed": 57},
        {"kind": "text", "text": "DECK READY", "rect": (1550, 158, 1700, 171)},
        {"kind": "text", "font": "title", "text": "01", "rect": (1740, 205, 1830, 262), "color": BONE_FAINT},
        {"kind": "stripes", "rect": (1836, 156, 1960, 186), "color": ACID, "step": 9},
        # handguard: chevrons pointing downrange and an acid line along the bottom
        {"kind": "chevrons", "rect": (617, 151, 663, 165), "color": ACID, "count": 3},
        {"kind": "rect", "rect": (673, 157, 979, 160), "color": ACID},
        # magazine: rounds and calibre
        {"kind": "text", "font": "title", "text": "30", "rect": (1030, 219, 1081, 253)},
        {"kind": "text", "text": "7.62", "rect": (1027, 259, 1081, 271)},
    ],
}

ENERGY_PISTOL = {
    "size": (2048, 844),
    "lo": (-0.204, -0.065),
    "hi": (0.0945, 0.058),
    "decals": [
        # slide front: the model and its charge
        {"kind": "text", "font": "title", "text": "EP-9", "rect": (901, 77, 1034, 121)},
        {"kind": "text", "text": "ENERGY 9.0kV", "rect": (901, 131, 1065, 146)},
        {"kind": "rect", "rect": (891, 176, 1331, 179), "color": ACID},
        # slide rear: the maker and acid stripes
        {"kind": "text", "text": "SPLIT/DECK", "rect": (1741, 77, 1905, 93)},
        {"kind": "stripes", "rect": (1741, 152, 1905, 172), "color": ACID, "step": 8},
        # frame: serial and barcode, chevrons forward
        {"kind": "text", "text": "SD-0217 // FRIDAE", "rect": (1485, 228, 1741, 244)},
        {"kind": "barcode", "rect": (1485, 254, 1597, 274), "seed": 9},
        {"kind": "chevrons", "rect": (901, 218, 973, 239), "color": ACID, "count": 3},
        # suppressor: a label and two acid bands
        {"kind": "text", "text": "QUIET // ZONE", "rect": (61, 87, 430, 118)},
        {"kind": "rect", "rect": (512, 15, 524, 195), "color": ACID},
        {"kind": "rect", "rect": (538, 15, 550, 195), "color": ACID},
    ],
}

LONGSCOPE = {
    "size": (2048, 424),
    "lo": (-0.7007, -0.1194),
    "hi": (0.36, 0.1001),
    "decals": [
        # receiver: the model, the maker, an acid plate and the serial
        {"kind": "text", "font": "title", "text": "LS-1", "rect": (1157, 160, 1262, 193)},
        {"kind": "text", "text": "SPLIT/DECK ARMS .338", "rect": (1275, 172, 1470, 186)},
        {"kind": "rect", "rect": (1183, 215, 1229, 238), "color": ACID},
        {"kind": "text", "text": "SD-0901 // FRIDAE", "rect": (1249, 220, 1464, 236)},
        # scope: a label and an acid ring by the eyepiece
        {"kind": "text", "text": "OPTIC x12 // 34MM", "rect": (942, 56, 1106, 74)},
        {"kind": "rect", "rect": (1505, 41, 1514, 97), "color": ACID},
        # handguard: chevrons and an acid line
        {"kind": "chevrons", "rect": (717, 220, 778, 238), "color": ACID, "count": 3},
        {"kind": "rect", "rect": (788, 227, 1106, 231), "color": ACID},
        # stock: barcode, a label, a faint number and acid stripes
        {"kind": "barcode", "rect": (1597, 200, 1720, 220), "seed": 1},
        {"kind": "text", "text": "DECK READY", "rect": (1597, 227, 1741, 242)},
        {"kind": "text", "font": "title", "text": "07", "rect": (1802, 235, 1874, 287), "color": BONE_FAINT},
        {"kind": "stripes", "rect": (1864, 184, 1971, 210), "color": ACID, "step": 8},
    ],
}
