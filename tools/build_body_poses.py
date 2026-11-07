"""Builds the third-person pose modules from the JSON written by tools/export_body_poses.py.

Run: python tools/build_body_poses.py <folder with M57.json, B33.json, ...>
Writes src/shared/Movement/BodyPoses/<Gun>.luau and checks every pose by rebuilding each body part from
its joint and comparing it with the frame Blender exported.

Each pose stores, for the game's R15 joints, the joint's Transform (Part1 = Part0 * C0 * Transform * C1^-1),
using the soldier rig's C0 and C1. The soldier body's HumanoidRootPart sits ROOT_DROP lower in the game than
in Blender (3 studs above the feet, like the default rig), which moves only the Root joint's C0; Transforms
don't change. The gun is given from the part holding it, so it follows that part's jitter.
"""
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "src", "shared", "Movement", "BodyPoses")
GROUND = -5.009  # the feet's floor in the rig's root space
ROOT_DROP = round(-GROUND - 3, 4)  # how much lower the game's root part sits

# Blender pose-file gun name -> the game's display name (GunConfig) and module file name.
GUNS = {
    "M57": ("M57", "M57"),
    "B33": ("B33", "B33"),
    "SMG": ("SMG", "SMG"),
    "Longscope": ("Longscope", "Longscope"),
    "Shotgun": ("Shotgun", "Shotgun"),
    "Pistol": ("Energy Pistol", "EnergyPistol"),
}
# The game's R15 joint names, by the part each one moves.
JOINT_OF = {
    "LowerTorso": "Root",
    "UpperTorso": "Waist",
    "Head": "Neck",
    "RightUpperArm": "RightShoulder",
    "RightLowerArm": "RightElbow",
    "RightHand": "RightWrist",
    "LeftUpperArm": "LeftShoulder",
    "LeftLowerArm": "LeftElbow",
    "LeftHand": "LeftWrist",
    "RightUpperLeg": "RightHip",
    "RightLowerLeg": "RightKnee",
    "RightFoot": "RightAnkle",
    "LeftUpperLeg": "LeftHip",
    "LeftLowerLeg": "LeftKnee",
    "LeftFoot": "LeftAnkle",
}
TP_POSES = [
    "Stand", "Fire", "Reload", "Walk_Contact", "Walk_Pass", "Sprint_Contact", "Sprint_Pass", "Crouch_Idle",
    "Crouch_Walk", "Slide", "Jump_Up", "Fall", "Land",
]
EXTRA = {"Longscope": ["Scoped", "Scoped_Crouch"]}


# ---- 4x4 matrices as nested lists
def mat(f):
    x, y, z, a, b, c, d, e, g, h, i, j = f
    return [[a, b, c, x], [d, e, g, y], [h, i, j, z], [0, 0, 0, 1]]


def mul(p, q):
    return [[sum(p[r][k] * q[k][col] for k in range(4)) for col in range(4)] for r in range(4)]


def inv(m):
    rt = [[m[c][r] for c in range(3)] for r in range(3)]  # rigid: transpose the rotation
    t = [m[r][3] for r in range(3)]
    nt = [-sum(rt[r][k] * t[k] for k in range(3)) for r in range(3)]
    return [rt[0] + [nt[0]], rt[1] + [nt[1]], rt[2] + [nt[2]], [0, 0, 0, 1]]


def translate(x, y, z):
    return [[1, 0, 0, x], [0, 1, 0, y], [0, 0, 1, z], [0, 0, 0, 1]]


def quat(m):
    """Unit quaternion (x, y, z, w) of a rotation matrix."""
    tr = m[0][0] + m[1][1] + m[2][2]
    if tr > 0:
        s = math.sqrt(tr + 1) * 2
        w, x, y, z = s / 4, (m[2][1] - m[1][2]) / s, (m[0][2] - m[2][0]) / s, (m[1][0] - m[0][1]) / s
    elif m[0][0] > m[1][1] and m[0][0] > m[2][2]:
        s = math.sqrt(1 + m[0][0] - m[1][1] - m[2][2]) * 2
        w, x, y, z = (m[2][1] - m[1][2]) / s, s / 4, (m[0][1] + m[1][0]) / s, (m[0][2] + m[2][0]) / s
    elif m[1][1] > m[2][2]:
        s = math.sqrt(1 + m[1][1] - m[0][0] - m[2][2]) * 2
        w, x, y, z = (m[0][2] - m[2][0]) / s, (m[0][1] + m[1][0]) / s, s / 4, (m[1][2] + m[2][1]) / s
    else:
        s = math.sqrt(1 + m[2][2] - m[0][0] - m[1][1]) * 2
        w, x, y, z = (m[1][0] - m[0][1]) / s, (m[0][2] + m[2][0]) / s, (m[1][2] + m[2][1]) / s, s / 4
    n = math.sqrt(x * x + y * y + z * z + w * w)
    return [x / n, y / n, z / n, w / n]


def num(v):
    s = ("%.4f" % v).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def cf(m):
    return "{ " + ", ".join(num(v) for v in [m[0][3], m[1][3], m[2][3]] + quat(m)) + " }"


def close(a, b, eps=2e-3):
    return all(abs(a[r][c] - b[r][c]) < eps for r in range(3) for c in range(4))


# ---- hinge clean-up
# The poser aimed each limb segment along the right line but sometimes left a segment rolled around its own
# length, so an elbow or knee came out twisted (up to 180 degrees). Here the upper and lower segment of each
# limb are re-rolled so the elbow or knee turns only about its own X axis, the way the joint hinges. Every
# joint position, the hands and the feet stay exactly where they were.
HINGES = (  # upper, lower, the sign of a normal bend about X
    ("RightUpperArm", "RightLowerArm", 1),
    ("LeftUpperArm", "LeftLowerArm", 1),
    ("RightUpperLeg", "RightLowerLeg", -1),
    ("LeftUpperLeg", "LeftLowerLeg", -1),
)


def col(m, i):
    return [m[0][i], m[1][i], m[2][i]]


def cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def unit(a):
    n = math.sqrt(dot(a, a))
    return [x / n for x in a]


def with_axes(m, x, y):
    """m's position, turned to have these X and Y axes."""
    z = cross(x, y)
    return [[x[0], y[0], z[0], m[0][3]], [x[1], y[1], z[1], m[1][3]], [x[2], y[2], z[2], m[2][3]], [0, 0, 0, 1]]


def rolled(m, x):
    """m turned about its own Y axis so its X axis points as near x as it can."""
    y = col(m, 1)
    x = [a - b * dot(x, y) for a, b in zip(x, y)]
    return with_axes(m, unit(x), y)


def fix_hinges(part):
    for upper, lower, sign in HINGES:
        yu, yl = unit(col(part[upper], 1)), unit(col(part[lower], 1))
        n = cross(yu, yl)
        if dot(n, n) < 1e-6:  # straight: keep the upper segment's roll
            x = col(part[upper], 0)
        else:
            x = [v * sign for v in unit(n)]
        part[upper] = rolled(part[upper], x)
        part[lower] = rolled(part[lower], x)
    return part


def build(gun, data):
    joints = data["joints"]
    c0 = {k: mat(v["c0"]) for k, v in joints.items()}
    c1 = {k: mat(v["c1"]) for k, v in joints.items()}
    drop = translate(0, -ROOT_DROP, 0)  # the game's root part, in the rig's root space
    names = [n for n in TP_POSES + EXTRA.get(gun, [])]
    lines = []
    for name in names:
        frames = data["poses"]["TP_%s_%s" % (gun, name)]
        lines += pose_lines(name, frames, joints, c0, c1, drop)
    return lines


def pose_lines(name, frames, joints, c0, c1, drop, slung=False):
    part = fix_hinges({k: mat(v) for k, v in frames.items()})
    out = ["\t%s = {" % name, "\t\tjoints = {"]
    for child, joint in JOINT_OF.items():
        parent = joints[child]["part0"]
        t = mul(mul(mul(inv(c0[child]), inv(part[parent])), part[child]), c1[child])
        # check: the part rebuilt from its joint lands where Blender had it
        rebuilt = mul(mul(mul(part[parent], c0[child]), t), inv(c1[child]))
        assert close(rebuilt, part[child]), (name, child)
        out.append("\t\t\t%s = %s," % (joint, cf(t)))
    out.append("\t\t},")
    # The gun rides the part that holds it, so it moves with the hand through the body's jitter. The
    # magazine and the pump or bolt ride the gun, and the loose shotgun shell rides the left hand.
    holder = "UpperTorso" if slung else "RightHand"
    out.append("\t\tgunOn = \"%s\"," % holder)
    out.append("\t\tgun = %s," % cf(mul(inv(part[holder]), part["GunMount"])))
    out.append("\t\tmag = %s," % cf(mul(inv(part["GunMount"]), part["MagProp"])))
    out.append("\t\taction = %s," % cf(mul(inv(part["GunMount"]), part["ActionProp"])))
    out.append("\t\tshell = %s," % cf(mul(inv(part["LeftHand"]), part["ShellProp"])))
    out.append("\t},")
    return out


def rig_lines(data):
    """The soldier rig's joints, for building the game body and for checks."""
    out = ["\trig = {", "\t\trootDrop = %s," % num(ROOT_DROP)]
    for child, joint in JOINT_OF.items():
        j = data["joints"][child]
        a, b = mat(j["c0"]), mat(j["c1"])
        out.append("\t\t%s = { part0 = \"%s\", part1 = \"%s\", c0 = %s, c1 = %s }," % (joint, j["part0"], child, cf(a), cf(b)))
    out.append("\t},")
    return out


def parts_lines(data):
    out = ["\tparts = {"]
    for p in data["parts"]:
        out.append("\t\t{ name = \"%s\", bone = \"%s\", min = { %s }, max = { %s } }," % (
            p["name"], p["bone"], ", ".join(num(v) for v in p["min"]), ", ".join(num(v) for v in p["max"])))
    out.append("\t},")
    return out


def main(folder):
    os.makedirs(OUT, exist_ok=True)
    index = ["-- Third-person gun poses, by the gun's display name. Made by tools/build_body_poses.py.", "return {"]
    empty = None
    for src, (display, module) in GUNS.items():
        path = os.path.join(folder, src + ".json")
        data = json.load(open(path, encoding="utf8"))
        lines = ["-- Made by tools/build_body_poses.py from SplitDeck_Poses_%s. Don't edit by hand." % src,
                 "-- Each pose: joints = each R15 joint's Transform. gun = the gun's handle frame from the part named by",
                 "-- gunOn; mag and action = from the gun; shell = from the LeftHand. Values are { x, y, z, qx, qy, qz, qw }.",
                 "return {", "\tgunScale = %s," % num(data["gunScale"])]
        lines += parts_lines(data)
        lines += ["\tposes = {"] + ["\t" + l for l in build(src, data)] + ["\t},", "}"]
        open(os.path.join(OUT, module + ".luau"), "w", encoding="utf8", newline="\n").write("\n".join(lines) + "\n")
        index.append("\t[\"%s\"] = require(script.%s)," % (display, module))
        if empty is None:
            empty = data
    # The empty-handed stance and the rig are the same in every file; take them from the first.
    empty_lines = ["-- Made by tools/build_body_poses.py. Don't edit by hand.",
                   "-- The empty-handed stance (gun slung) and the soldier rig's joints.", "return {"]
    empty_lines += rig_lines(empty)
    empty_lines += ["\tposes = {"]
    empty_lines += ["\t" + l for l in pose_lines("Stand", empty["poses"]["TP_Empty_Stand"], empty["joints"],
                                                 {k: mat(v["c0"]) for k, v in empty["joints"].items()},
                                                 {k: mat(v["c1"]) for k, v in empty["joints"].items()},
                                                 translate(0, -ROOT_DROP, 0), slung=True)]
    empty_lines += ["\t},", "}"]
    open(os.path.join(OUT, "Empty.luau"), "w", encoding="utf8", newline="\n").write("\n".join(empty_lines) + "\n")
    index.append("\tEmpty = require(script.Empty),")
    index.append("}")
    open(os.path.join(OUT, "init.luau"), "w", encoding="utf8", newline="\n").write("\n".join(index) + "\n")


if __name__ == "__main__":
    main(sys.argv[1])
