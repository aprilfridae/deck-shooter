"""Exports every pose in a SplitDeck_Poses_<Gun>.blend file to JSON, for tools/build_body_poses.py.

Run inside Blender with the pose file open:
    blender.exe -b SplitDeck_Poses_M57_v4.blend --python tools/export_body_poses.py -- M57 out/M57.json
Each pose is an Action with one key on frame 1. For every pose the JSON holds each bone's frame in the
rig's Roblox root space (12 numbers: x, y, z, then the rotation matrix by rows). Body bones are given as
the Roblox part's frame (the bone's frame times C1 inverse), as the game sees the part. The rig's C0 and C1
for each joint and the gun's parts (handle-space boxes) come along, so the build step needs nothing else.
"""
import json
import sys

import bpy
from mathutils import Matrix

ROOT_Z = 5.009  # Blender height of the rig's HumanoidRootPart centre
R2B = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, ROOT_Z), (0, 0, 0, 1)))  # Roblox root space -> Blender
B2R = R2B.inverted()
PROPS = ("GunMount", "MagProp", "ActionProp", "ShellProp", "FPCamera", "HumanoidRootPart")


def flat(m):
    return [round(v, 5) for v in (m[0][3], m[1][3], m[2][3], m[0][0], m[0][1], m[0][2], m[1][0], m[1][1], m[1][2], m[2][0], m[2][1], m[2][2])]


def motors():
    """C0 and C1 for each body joint, from the pose file's own core module."""
    core = {}
    exec(bpy.data.texts["posekit_core.py"].as_string(), core)
    return {child: {"part0": parent, "c0": flat(c0), "c1": flat(c1)} for child, (parent, c0, c1) in core["MOT"].items()}, core["MOT"]


def gun_parts(rig, gun):
    """Each mesh of the gun as a box in GunMount (handle) space, with the bone it rides on."""
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    out = []
    for prop in ("GunMount", "MagProp", "ActionProp"):
        inv = (rig.matrix_world @ rig.pose.bones[prop].matrix).inverted()
        for o in bpy.data.objects:
            if o.type != "MESH":
                continue
            on_gun = o.parent and o.parent.name == "GUN_" + gun
            on_prop = o.parent == rig and o.parent_bone == prop and (o.get("gun") == gun or o.name in ("ShellStandIn", "PistolMagStandIn"))
            if (prop == "GunMount" and on_gun and o.parent_type != "BONE") or on_prop:
                pts = [inv @ o.matrix_world @ v.co for v in o.data.vertices]
                if pts:
                    lo = [round(min(p[i] for p in pts), 4) for i in range(3)]
                    hi = [round(max(p[i] for p in pts), 4) for i in range(3)]
                    out.append({"name": o.name, "bone": prop, "min": lo, "max": hi})
    return out


def export(gun, path):
    rig = bpy.data.objects["SoldierRig"]
    joints, mot = motors()
    poses = {}
    for act in sorted(bpy.data.actions, key=lambda a: a.name):
        rig.animation_data.action = act
        if act.slots:
            rig.animation_data.action_slot = act.slots[0]
        bpy.context.scene.frame_set(2)  # step off and back so the new action is evaluated
        bpy.context.scene.frame_set(1)
        bpy.context.view_layer.update()
        frames = {}
        for pb in rig.pose.bones:
            f = B2R @ pb.matrix
            if pb.name in mot:
                f = f @ mot[pb.name][2].inverted()  # bone frame -> Roblox part frame
            frames[pb.name] = flat(f)
        cam = bpy.data.objects.get("FP_GameCamera")
        if cam:  # the first-person camera at the centre of the red eye bar, looking down its -Z like a Roblox camera
            m = cam.matrix_world.normalized()
            frames["FPView"] = flat(B2R @ m)
        poses[act.name] = frames
    gun_name = "GUN_" + gun
    data = {
        "gun": gun,
        "rootZ": ROOT_Z,
        "joints": joints,
        "parts": gun_parts(rig, gun) if bpy.data.objects.get(gun_name) else [],
        "gunScale": round(bpy.data.objects[gun_name].scale[0], 4) if bpy.data.objects.get(gun_name) else None,
        "poses": poses,
    }
    with open(path, "w", encoding="utf8") as fh:
        json.dump(data, fh, separators=(",", ":"))
    return len(poses)


if __name__ == "__main__" and "--" in sys.argv:
    gun_arg, out_arg = sys.argv[sys.argv.index("--") + 1:][:2]
    print("EXPORTED", gun_arg, export(gun_arg, out_arg))
