"""Builds the first-person clips for the soldier's own arms from the JSON written by tools/export_body_poses.py.

Run: python tools/build_first_person_clips.py <folder with M57.json, B33.json, ...> <soldier_manifest.json>
Writes src/shared/Guns/FirstPersonClips/<Gun>.luau (+ init.luau) and src/shared/Guns/SoldierRig.luau.

Every first-person pose is stored relative to the first-person camera, which sits at the centre of the red eye
bar (FPView in the export): each arm, hand and finger part, the gun's handle (Gun), and the magazine and the
charging handle or pump relative to the gun (Mag, Action). Clips only name poses: a frame is one pose, or two
poses and how far to blend from the first to the second. FirstPersonClip.luau expands them in the game. Reload
clips are marked scaled: the game stretches them to the gun's reload time from GunConfig.

SoldierRig.luau holds, for every piece of the exported FirstPersonArms and SoldierBody models, the part (or finger)
it belongs to and its offset from that part, plus the material colours.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_body_poses import GUNS, cf, inv, mat, mul, num, translate  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "src", "shared", "Guns", "FirstPersonClips")
RIG_OUT = os.path.join(ROOT, "src", "shared", "Guns", "SoldierRig.luau")

SIDES = ("Right", "Left")
FINGERS = ("Thumb", "Index", "Middle", "Ring", "Pinky")
ARM_PARTS = [s + p for s in SIDES for p in ("UpperArm", "LowerArm", "Hand")] + [
    s + f + str(i) for s in SIDES for f in FINGERS for i in (1, 2, 3)
]

# Reload keys as (share of the reload time, pose). The game samples them at RELOAD_FRAMES held frames.
RIFLE_RELOAD = [(0, "Idle"), (0.12, "Reload_Start"), (0.24, "Reload_Start"), (0.36, "Reload_Out"), (0.5, "Reload_Mid"),
                (0.6, "Reload_Mid"), (0.72, "Reload_In"), (0.82, "Reload_End"), (0.9, "Reload_End"), (1, "Idle")]
RELOADS = {
    "M57": RIFLE_RELOAD,
    "B33": RIFLE_RELOAD,
    "SMG": RIFLE_RELOAD,
    "Longscope": [(0, "Idle"), (0.1, "Reload_Start"), (0.2, "Reload_Start"), (0.3, "Reload_Out"), (0.42, "Reload_Mid"),
                  (0.5, "Reload_Mid"), (0.6, "Reload_In"), (0.7, "Reload_End"), (0.8, "BoltOrCycle"),
                  (0.88, "BoltOrCycle"), (1, "Idle")],
    "Pistol": [(0, "Idle"), (0.15, "Reload_Start"), (0.3, "Reload_Start"), (0.5, "Reload_Mid"), (0.62, "Reload_Mid"),
               (0.8, "Reload_End"), (0.88, "Reload_End"), (1, "Idle")],
    # One shell: the clip loops for as long as the gun keeps reloading, one loop per shell.
    "Shotgun": [(0, "Reload_Start"), (0.35, "ShellLoad"), (0.6, "Reload_Mid"), (0.8, "Reload_Mid"), (1, "Reload_Start")],
}
RELOAD_FRAMES = {"Shotgun": 6, "SMG": 18, "Longscope": 16}
DEFAULT_RELOAD_FRAMES = 12


def ease(s):
    return s * s * (3 - 2 * s)


def sample(keys, count):
    """Held frames along a key timeline: each is (pose,) or (from, to, share)."""
    frames = []
    for i in range(count):
        t = (i + 0.5) / count
        for (t0, a), (t1, b) in zip(keys, keys[1:]):
            if t0 <= t <= t1:
                s = round(ease((t - t0) / (t1 - t0)), 2) if t1 > t0 else 0
                if a == b or s <= 0.02:
                    frames.append((a,))
                elif s >= 0.98:
                    frames.append((b,))
                else:
                    frames.append((a, b, s))
                break
    return frames


def clip_set(gun, names):
    has = lambda n: n in names  # noqa: E731
    fire = [("Fire",), ("Fire", "Idle", 0.5)]
    aim_fire = [("Aim_Fire",), ("Aim_Fire", "Aim", 0.5)]
    if gun == "Shotgun" and has("Pump_Back"):
        fire = [("Fire",), ("Fire", "Pump_Back", 0.5), ("Pump_Back",), ("Pump_Back",), ("Pump_Back", "Idle", 0.5)]
        aim_fire = [("Aim_Fire",), ("Aim_Fire",), ("Aim_Fire", "Aim", 0.5)]
    if gun == "Longscope" and has("BoltOrCycle"):
        fire = [("Fire",), ("Fire", "BoltOrCycle", 0.5), ("BoltOrCycle",), ("BoltOrCycle",), ("BoltOrCycle", "Idle", 0.5)]
        aim_fire = [("Aim_Fire",), ("Aim_Fire",), ("Aim_Fire", "Aim", 0.5)]
    reload = sample(RELOADS[gun], RELOAD_FRAMES.get(gun, DEFAULT_RELOAD_FRAMES))
    return {
        "idle": dict(fps=2, loop=True, frames=[("Idle",)]),
        "aim": dict(fps=2, loop=True, frames=[("Aim",)]),
        "aimIn": dict(fps=12, loop=False, frames=[("Idle", "Aim", 0.5)]),
        "aimOut": dict(fps=12, loop=False, frames=[("Aim", "Idle", 0.5)]),
        "fire": dict(fps=12, loop=False, frames=fire),
        "aimFire": dict(fps=12, loop=False, frames=aim_fire),
        "run": dict(fps=2, loop=True, frames=[("Sprint",)]),
        "equip": dict(fps=12, loop=False, frames=[("Draw_Start",), ("Draw_Start", "Idle", 0.5)]),
        "holster": dict(fps=12, loop=False, frames=[("Idle", "Holster", 0.5), ("Holster",)]),
        "reload": dict(fps=12, loop=gun == "Shotgun", scaled=True, frames=reload),
    }


def pose_lines(name, frames):
    part = {k: mat(v) for k, v in frames.items()}
    view = inv(part["FPView"])
    out = ["\t\t%s = {" % name]
    for p in ARM_PARTS:
        out.append("\t\t\t%s = %s," % (p, cf(mul(view, part[p]))))
    out.append("\t\t\tGun = %s," % cf(mul(view, part["GunMount"])))
    out.append("\t\t\tMag = %s," % cf(mul(inv(part["GunMount"]), part["MagProp"])))
    out.append("\t\t\tAction = %s," % cf(mul(inv(part["GunMount"]), part["ActionProp"])))
    out.append("\t\t},")
    return out


def muzzle(parts):
    """The middle of the gun's front face, in handle space (forward is -Z)."""
    body = [p for p in parts if p["bone"] == "GunMount"]
    front = min(p["min"][2] for p in body)
    tip = [p for p in body if p["min"][2] < front + 0.02]
    x = sum((p["min"][0] + p["max"][0]) / 2 for p in tip) / len(tip)
    y = sum((p["min"][1] + p["max"][1]) / 2 for p in tip) / len(tip)
    return [x, y, front]


def frame_ref(ref):
    if len(ref) == 1:
        return '{ "%s" }' % ref[0]
    return '{ "%s", "%s", %s }' % (ref[0], ref[1], num(ref[2]))


def build(gun, data):
    prefix = "FP_%s_" % gun
    names = sorted(k[len(prefix):] for k in data["poses"] if k.startswith(prefix))
    clips = clip_set(gun, names)
    used = sorted({r for c in clips.values() for f in c["frames"] for r in f if isinstance(r, str)})
    missing = [n for n in used if n not in names]
    assert not missing, (gun, missing)
    display, module = GUNS[gun]
    lines = [
        "-- Made by tools/build_first_person_clips.py from SplitDeck_Poses_%s. Don't edit by hand." % gun,
        "-- First-person poses on the soldier's own arms, relative to the camera at the centre of the red eye bar.",
        "-- Each value is { x, y, z, qx, qy, qz, qw }. Gun is the gun's handle; Mag and Action are from the gun.",
        "-- A clip frame is { pose } or { from, to, share }. Reload clips are stretched to the gun's reload time.",
        "return {",
        "\tmuzzle = { %s }," % ", ".join(num(v) for v in muzzle(data["parts"])),
        "\tparts = {",
    ]
    for p in data["parts"]:
        lines.append('\t\t{ name = "%s", bone = "%s", min = { %s }, max = { %s } },' % (
            p["name"], p["bone"], ", ".join(num(v) for v in p["min"]), ", ".join(num(v) for v in p["max"])))
    lines.append("\t},")
    lines.append("\tposes = {")
    for n in used:
        lines += pose_lines(n, data["poses"][prefix + n])
    lines.append("\t},")
    lines.append("\tclips = {")
    for cname, c in clips.items():
        extra = ", scaled = true" if c.get("scaled") else ""
        lines.append("\t\t%s = {" % cname)
        lines.append("\t\t\tfps = %d, loop = %s%s," % (c["fps"], "true" if c["loop"] else "false", extra))
        lines.append("\t\t\tframes = { %s }," % ", ".join(frame_ref(f) for f in c["frames"]))
        lines.append("\t\t},")
    lines.append("\t},")
    lines.append("}")
    with open(os.path.join(OUT, module + ".luau"), "w", encoding="utf8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    return display, module


def rig(manifest):
    frames = {k: v for k, v in manifest["partFrames"].items()}

    def rest(part):
        x, y, z, qx, qy, qz, qw = frames[part]
        # quaternion -> matrix
        m = [[1 - 2 * (qy * qy + qz * qz), 2 * (qx * qy - qz * qw), 2 * (qx * qz + qy * qw), x],
             [2 * (qx * qy + qz * qw), 1 - 2 * (qx * qx + qz * qz), 2 * (qy * qz - qx * qw), y],
             [2 * (qx * qz - qy * qw), 2 * (qy * qz + qx * qw), 1 - 2 * (qx * qx + qy * qy), z],
             [0, 0, 0, 1]]
        return m

    lines = [
        "-- Made by tools/build_first_person_clips.py from soldier_manifest.json. Don't edit by hand.",
        "-- The soldier models' pieces (MeshParts named <Part>_<material>), each with the part or finger it",
        "-- belongs to and its offset from that part. arms = FirstPersonArms (first person), body = SoldierBody.",
        "return {",
        "\tcolors = {",
    ]
    for k, v in sorted(manifest["materialColors"].items()):
        lines.append("\t\t%s = { %d, %d, %d }," % (k[3:], v[0], v[1], v[2]))
    lines.append("\t},")
    for key, fname in (("arms", "FirstPersonArms.fbx"), ("body", "SoldierBody.fbx")):
        lines.append("\t%s = {" % key)
        for name, piece in sorted(manifest[fname].items()):
            offset = mul(inv(rest(piece["part"])), translate(*piece["centre"]))
            lines.append('\t\t["%s"] = { part = "%s", material = "%s", offset = %s },' % (
                name, piece["part"], piece["material"], cf(offset)))
        lines.append("\t},")
    lines.append("}")
    with open(RIG_OUT, "w", encoding="utf8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")


def main(folder, manifest_path):
    os.makedirs(OUT, exist_ok=True)
    index = []
    for gun in GUNS:
        with open(os.path.join(folder, gun + ".json"), encoding="utf8") as fh:
            display, module = build(gun, json.load(fh))
        index.append('\t["%s"] = require(script.%s),' % (display, module))
    with open(os.path.join(OUT, "init.luau"), "w", encoding="utf8", newline="\n") as fh:
        fh.write("-- First-person soldier clips, by the gun's display name. Made by tools/build_first_person_clips.py.\nreturn {\n"
                 + "\n".join(index) + "\n}\n")
    with open(manifest_path, encoding="utf8") as fh:
        rig(json.load(fh))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
