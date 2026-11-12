# Works out third-person arm joints for the Energy Pistol so the body matches first person: the pistol held out
# sideways (rolled flat) and level, pointing where the body faces, and the free left arm hanging at the side.
# The pose file from Blender (BodyPoses/EnergyPistol.luau) had the gun tipped and the left hand in a poor place.
#
# For every pose in that file except Reload it reads the body's own Root and Waist, places the hands in the
# root's space, solves the shoulder, elbow and wrist turns, and writes src/shared/Movement/PistolArms.luau.
# RemotePoses lays those joints over the pose file's.
#
#   python tools/fix_pistol_arms.py
import math
import re

import numpy as np

POSES = "src/shared/Movement/BodyPoses/EnergyPistol.luau"
RIG = "src/shared/Movement/BodyPoses/Empty.luau"
OUT = "src/shared/Movement/PistolArms.luau"
SKIP = {"Reload"}
# Poses whose torso is stood up straight: the pose file leans it back about 13 degrees (hips 4, waist 9) and tips
# it a little, and River wanted the base pose upright. The turn of the hips and shoulders is kept, so the stance is
# still side-on; only the lean and tip are taken out, and the head faces dead ahead.
UPRIGHT = {"Stand", "Fire"}

UPPER = 0.55 + 0.62  # shoulder to elbow
FORE = 0.55 + 0.6  # elbow to wrist
WRIST_TO_HAND = 0.25
REST_ELBOW = math.radians(10)

# Where the gun's handle goes, from the middle of the head, in the root's space (x right, y up, -z ahead).
# First person holds it 0.565 right, 0.7 down and 1.5 ahead of the eye.
GUN_FROM_HEAD = np.array([0.55, -0.75, -2.2])  # further ahead than first person, so the arm is nearly straight
GUN_ROLL = math.radians(90)  # top of the gun turned to the body's left, as in first person
# The left wrist, from the left shoulder: the arm hangs loose at the side, a little out and ahead, slightly bent.
# It was raised as if to snap, but the rig has no fingers to snap with, so River had it put down.
LEFT_WRIST = np.array([-0.3, -2.12, -0.3])
LEFT_ELBOW_WAY = np.array([-0.3, 0.0, 1.0])  # the elbow points back
RIGHT_REACH = 2.2  # the right arm is never quite straight


def quat_to_mat(q):
    x, y, z, w = q
    return np.array(
        [
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ]
    )


def mat_to_quat(m):
    trace = m[0, 0] + m[1, 1] + m[2, 2]
    if trace > 0:
        s = math.sqrt(trace + 1) * 2
        q = [(m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s, s / 4]
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        s = math.sqrt(1 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
        q = [s / 4, (m[0, 1] + m[1, 0]) / s, (m[0, 2] + m[2, 0]) / s, (m[2, 1] - m[1, 2]) / s]
    elif m[1, 1] > m[2, 2]:
        s = math.sqrt(1 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
        q = [(m[0, 1] + m[1, 0]) / s, s / 4, (m[1, 2] + m[2, 1]) / s, (m[0, 2] - m[2, 0]) / s]
    else:
        s = math.sqrt(1 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
        q = [(m[0, 2] + m[2, 0]) / s, (m[1, 2] + m[2, 1]) / s, s / 4, (m[1, 0] - m[0, 1]) / s]
    if q[3] < 0:
        q = [-v for v in q]
    return q


class Frame:
    def __init__(self, p, r):
        self.p, self.r = np.array(p, dtype=float), np.array(r, dtype=float)

    @staticmethod
    def of(values):
        return Frame(values[:3], quat_to_mat(values[3:]))

    def __mul__(self, other):
        return Frame(self.p + self.r @ other.p, self.r @ other.r)

    def inverse(self):
        return Frame(-(self.r.T @ self.p), self.r.T)

    def point(self, v):
        return self.p + self.r @ np.array(v, dtype=float)


def numbers(text):
    return [float(v) for v in text.split(",")]


def read_rig():
    text = open(RIG, encoding="utf-8").read()
    rig = {}
    for name, c0, c1 in re.findall(r"(\w+) = \{ part0 = \"\w+\", part1 = \"\w+\", c0 = \{ ([^}]*) \}, c1 = \{ ([^}]*) \} \}", text):
        rig[name] = (Frame.of(numbers(c0)), Frame.of(numbers(c1)))
    return rig


def read_poses():
    text = open(POSES, encoding="utf-8").read()
    poses = {}
    for name, body in re.findall(r"\n\t\t(\w+) = \{\n\t\t\tjoints = \{(.*?)\n\t\t\tshell", text, re.S):
        joints = {joint: numbers(values) for joint, values in re.findall(r"\t\t\t\t(\w+) = \{ ([^}]*) \}", body)}
        gun = numbers(re.search(r"\bgun = \{ ([^}]*) \}", body).group(1))
        poses[name] = (joints, gun)
    return poses


def unit(v):
    return v / np.linalg.norm(v)


def rot_x(angle):
    c, s = math.cos(angle), math.sin(angle)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def rot_z(angle):
    c, s = math.cos(angle), math.sin(angle)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def angle_of(m):
    return math.degrees(math.acos(max(-1, min(1, (np.trace(m) - 1) / 2))))


# The upper arm's turn and the elbow's bend that put the wrist at `wrist` from a shoulder at `shoulder`, with the
# elbow swung `swivel` round the line between them from the way `elbow_way` points.
def arm(shoulder, wrist, elbow_way, swivel):
    reach = wrist - shoulder
    distance = min(np.linalg.norm(reach), UPPER + FORE - 0.02)
    along = unit(reach)
    wrist = shoulder + along * distance
    cos_inside = (UPPER**2 + FORE**2 - distance**2) / (2 * UPPER * FORE)
    bend = math.pi - math.acos(max(-1, min(1, cos_inside)))
    cos_lead = (UPPER**2 + distance**2 - FORE**2) / (2 * UPPER * distance)
    lead = math.acos(max(-1, min(1, cos_lead)))
    side = unit(elbow_way - (elbow_way @ along) * along)
    other = np.cross(along, side)
    side = side * math.cos(swivel) + other * math.sin(swivel)
    elbow = shoulder + UPPER * (math.cos(lead) * along + math.sin(lead) * side)
    up = unit(shoulder - elbow)
    fore = unit(wrist - elbow)
    back = -unit(fore - (fore @ up) * up)
    across = np.cross(up, back)
    upper = np.column_stack([across, up, back])
    return upper, bend, wrist


def turn_only(values):
    """A joint's values with its lean and tip taken out, keeping only its turn about the upright axis."""
    m = quat_to_mat(values[3:])
    yaw = math.atan2(m[0, 2], m[2, 2])
    return values[:3] + [0.0, math.sin(yaw / 2), 0.0, math.cos(yaw / 2)], yaw


def solve(rig, joints, gun, upright=False):
    root = Frame([0, 0, 0], np.eye(3))
    result = {}
    if upright:
        joints = dict(joints)
        joints["Root"], hips = turn_only(joints["Root"])
        joints["Waist"], waist = turn_only(joints["Waist"])
        facing = -(hips + waist)  # the head undoes the body's turn
        joints["Neck"] = [0.0, 0.0, 0.0, 0.0, math.sin(facing / 2), 0.0, math.cos(facing / 2)]
        for name in ("Root", "Waist", "Neck"):
            result[name] = joints[name]

    def joint(parent, name):
        c0, c1 = rig[name]
        return parent * c0 * Frame.of(joints[name]) * c1.inverse()

    lower = joint(root, "Root")
    upper = joint(lower, "Waist")
    head = joint(upper, "Neck")

    # Right: the gun where first person has it, flat and level, pointing ahead.
    handle = Frame(head.p + GUN_FROM_HEAD, rot_z(GUN_ROLL))
    hand = handle * Frame.of(gun).inverse()
    base = upper * rig["RightShoulder"][0]
    wrist = hand.point([0, WRIST_TO_HAND, 0])
    reach = wrist - base.p
    if np.linalg.norm(reach) > RIGHT_REACH:
        # Too far for the arm: bring the whole gun back along the way the body faces until it reaches.
        for _ in range(60):
            handle.p[2] += 0.03
            hand = handle * Frame.of(gun).inverse()
            wrist = hand.point([0, WRIST_TO_HAND, 0])
            if np.linalg.norm(wrist - base.p) <= RIGHT_REACH:
                break
    best = None
    for step in range(-16, 17):
        swivel = math.radians(step * 7.5)
        turn, bend, _ = arm(base.p, wrist, np.array([0.5, -1.0, 0.3]), swivel)
        fore = turn @ rot_x(bend)
        twist = fore.T @ hand.r
        cost = angle_of(twist) + abs(step) * 0.3
        if best is None or cost < best[0]:
            best = (cost, turn, bend, twist)
    _, turn, bend, twist = best
    result["RightShoulder"] = base.r.T @ turn
    result["RightElbow"] = rot_x(bend - REST_ELBOW)
    result["RightWrist"] = twist

    # Left: down at the side.
    base = upper * rig["LeftShoulder"][0]
    target = base.p + root.r @ LEFT_WRIST
    turn, bend, _ = arm(base.p, target, LEFT_ELBOW_WAY, 0)
    result["LeftShoulder"] = base.r.T @ turn
    result["LeftElbow"] = rot_x(bend - REST_ELBOW)
    result["LeftWrist"] = rot_x(math.radians(8))  # the hand curled in a touch
    return result, angle_of(twist), handle.p - head.p


def main():
    rig, poses = read_rig(), read_poses()
    lines = [
        "-- Made by tools/fix_pistol_arms.py. Don't edit by hand.",
        "-- Arm joints for the Energy Pistol's third-person poses: the pistol out in front, rolled flat and level as",
        "-- first person holds it, and the left arm hanging at the side. The standing poses also carry the hips, waist",
        "-- and neck, stood up straight. Values are { x, y, z, qx, qy, qz, qw }.",
        "return {",
    ]
    for name, (joints, gun) in poses.items():
        if name in SKIP:
            continue
        solved, wrist_turn, gun_at = solve(rig, joints, gun, name in UPRIGHT)
        print(f"{name:16} wrist turn {wrist_turn:5.1f} deg, gun from head {np.round(gun_at, 2)}")
        lines.append(f"\t{name} = {{")
        for joint_name, value in solved.items():
            if isinstance(value, list):  # a whole joint, place and turn
                whole = ", ".join(f"{round(v, 4):g}" for v in value)
                lines.append(f"\t\t{joint_name} = {{ {whole} }},")
                continue
            quat = ", ".join(f"{round(v, 4):g}" for v in mat_to_quat(value))
            lines.append(f"\t\t{joint_name} = {{ 0, 0, 0, {quat} }},")
        lines.append("\t},")
    lines.append("}")
    open(OUT, "w", encoding="utf-8", newline="").write("\n".join(lines) + "\n")


main()
