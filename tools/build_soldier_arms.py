"""Builds src/shared/Guns/SoldierArmsData.luau from the soldier's manifest.

Run: python tools/build_soldier_arms.py <path to soldier_manifest.json>
"""
import json
import sys

OUT = "src/shared/Guns/SoldierArmsData.luau"
SIDES = ("Right", "Left")
ARM = ("UpperArm", "LowerArm", "Hand")
DIGITS = ("Thumb", "Index", "Middle", "Ring", "Pinky")


def main():
    with open(sys.argv[1], encoding="utf8") as source:
        manifest = json.load(source)
    frames = manifest["partFrames"]
    names = []
    for side in SIDES:
        names += [side + part for part in ARM]
        names += [f"{side}{digit}{joint}" for digit in DIGITS for joint in (1, 2, 3)]
    joints = manifest["joints"]
    lines = [
        "-- Made by tools/build_soldier_arms.py from soldier_manifest.json. Don't edit by hand.",
        "-- Each part's rest frame, { x, y, z, qx, qy, qz, qw }, in the soldier's root space, facing -Z.",
        "return {",
        f'\tshoulder = {joints["RightUpperArm"]["c1"][1]}, -- from the upper arm up to its shoulder',
        f'\telbow = {joints["RightLowerArm"]["c1"][1]}, -- from the lower arm up to its elbow',
        f'\twrist = {joints["RightHand"]["c1"][1]}, -- from the hand up to its wrist',
        "\tframes = {",
    ]
    for name in names:
        values = ", ".join(str(value) for value in frames[name])
        lines.append(f"\t\t{name} = {{ {values} }},")
    lines += ["\t},", "}", ""]
    with open(OUT, "w", encoding="utf8", newline="\n") as out:
        out.write("\n".join(lines))


main()
