# Copies River's gun takes into assets/sounds with silence added to the front.
# The silence lets the game start a late shot partway in, so it still lands on the beat.
# Keep PADDING_SECONDS the same as paddingSeconds in src/shared/Guns/GunSounds.luau.
import os
import struct

PADDING_SECONDS = 0.02
SOURCE = "E:/sound effects for game/GUN VARIATIONS/GUN VARIATIONS/"
TARGET = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
GUNS = {"AK": "ak47", "M4": "m4", "SMG": "smg", "PISTOL": "pistol", "SNIPER": "sniper", "SHOTGUN": "shotgun"}
SKIP = {("SMG", 30), ("SNIPER", 12)}  # silent; starts late and much louder


def pad(source_path, target_path):
    raw = open(source_path, "rb").read()
    position = 12
    fmt = data = None
    while position < len(raw) - 8:
        name = raw[position : position + 4]
        size = struct.unpack("<I", raw[position + 4 : position + 8])[0]
        body = raw[position + 8 : position + 8 + size]
        if name == b"fmt ":
            fmt = body
        elif name == b"data":
            data = body
        position += 8 + size + (size & 1)
    channels, rate, _, block = struct.unpack("<HIIH", fmt[2:14])
    padded = bytes(block * round(rate * PADDING_SECONDS)) + data
    chunks = b"fmt " + struct.pack("<I", len(fmt)) + fmt
    chunks += b"data" + struct.pack("<I", len(padded)) + padded + bytes(len(padded) & 1)
    with open(target_path, "wb") as out:
        out.write(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)


for folder, name in GUNS.items():
    for take in range(1, 31):
        if (folder, take) not in SKIP:
            pad(f"{SOURCE}{folder}/{folder} ({take}).wav", os.path.join(TARGET, f"gun-{name}-{take}.wav"))
print("Padded")
