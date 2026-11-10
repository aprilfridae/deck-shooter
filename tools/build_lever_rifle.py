# Cuts River's lever rifle (LeverRifle_v5.glb, about 1.3 million triangles) down to a game-size model for Roblox.
#
#   blender -b --python tools/build_lever_rifle.py -- <LeverRifle_v5.glb> <out folder>
#
# Roblox gives a MeshPart one colour, so the rifle is joined into one mesh per moving group and material:
# Static_Steel, Lever_Polymer, Bolt_Steel and so on. The moving groups are Lever (with its red grip), Bolt (with its
# cyan dot) and Trigger; everything else is Static. The scope's two lenses stay apart as sight_glass_low (the eyepiece,
# which the scope code looks for) and Lens_Front.
#
# Writes LeverRifle_low.glb and parts.json (each part's triangles, material colour and box, in the handoff's metres:
# +X muzzle, +Z up, origin at the trigger) to the out folder. Roblox moves each mesh's origin to the middle of its box,
# so the boxes are what place the lever's pivot afterwards.
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

source, out = sys.argv[sys.argv.index("--") + 1:][:2]
os.makedirs(out, exist_ok=True)

MOVING = {"Lever": "Lever", "LeverGrip": "Lever", "Bolt": "Bolt", "BoltIndicator": "Bolt", "Trigger": "Trigger"}
BUDGET = 40  # a mesh of n triangles keeps about BUDGET * n ^ (1/3)
SMALLEST = 120
SOLID_FROM = 30000  # triangles: bigger meshes are the solid moulded ones (stock, fore-end, lever, receiver)
HEAVY = 1500  # triangles a small part may keep before it is collapsed as well
THIN = ("ScopeBody", "Ring", "Lens")  # thin-walled parts that are never collapsed
FLAT = 6  # degrees between faces that count as one flat face on a small part

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=source)
bpy.context.scene.frame_set(1)  # lever closed

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]


def only(objects, active=None):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objects[0]


def triangles(o):
    o.data.calc_loop_triangles()
    return len(o.data.loop_triangles)


# Which group each source object moves with, before any are renamed or split.
groups = {}
for o in meshes:
    base = o.name.split(".")[0]
    groups[o.name] = MOVING.get(o.name, MOVING.get(base, "Static"))
    if o.parent and o.parent.name in MOVING:
        groups[o.name] = MOVING[o.parent.name]

# Drop the animation and the parenting, keeping every mesh where it is.
for o in list(bpy.context.scene.objects):
    o.animation_data_clear()
only(meshes)
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for o in list(bpy.context.scene.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o)

# The scope's two glowing "rings" are solid discs in the file, which cover its lenses. Taking out the middle of each
# end leaves the glowing rim, with the lens showing through.
for o in meshes:
    if o.name in ("ScopeEyeRing", "ScopeObjectiveRing"):
        mesh = bmesh.new()
        mesh.from_mesh(o.data)
        turn = o.matrix_world.to_3x3()
        middle = [f for f in mesh.faces if abs((turn @ f.normal).normalized().x) > 0.7]  # the faces across each end
        bmesh.ops.delete(mesh, geom=middle, context="FACES")
        mesh.to_mesh(o.data)
        mesh.free()
        print("RING", o.name, "took out", len(middle))

# Thin each mesh.
before = 0
for o in meshes:
    count = triangles(o)
    before += count
    keep = max(SMALLEST, int(BUDGET * count ** (1 / 3)))
    if count < SOLID_FROM:
        # A small part is thin-walled metal: collapsing it tears tubes open and fills rings in (it did the scope),
        # so only its flat faces are merged, which leaves its shape exactly as it was.
        modifier = o.modifiers.new("Thin", "DECIMATE")
        modifier.decimate_type = "DISSOLVE"
        modifier.angle_limit = math.radians(FLAT)
    elif keep < count:
        modifier = o.modifiers.new("Thin", "DECIMATE")
        modifier.ratio = keep / count
    else:
        continue
    only([o])
    bpy.ops.object.modifier_apply(modifier="Thin")
    # A small part that's still heavy is a solid knob or block, which does collapse cleanly.
    left = triangles(o)
    if count < SOLID_FROM and left > HEAVY and not any(word in o.name for word in THIN):
        modifier = o.modifiers.new("Thin", "DECIMATE")
        modifier.ratio = HEAVY / left
        bpy.ops.object.modifier_apply(modifier="Thin")

# Split by material, then join each group's pieces of one material.
piles = {}
for o in meshes:
    group = groups[o.name]
    only([o])
    if len([s for s in o.material_slots if s.material]) > 1:
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.separate(type="MATERIAL")
        bpy.ops.object.mode_set(mode="OBJECT")
    for piece in bpy.context.selected_objects:
        used = {piece.data.materials[p.material_index] for p in piece.data.polygons if piece.data.materials}
        material = next(iter(used), None)
        name = material.name.replace("LR_", "") if material else "Plain"
        if name.startswith("Neon"):
            # River doesn't want the glowing cyan and magenta strips, dots and rims: they're left off.
            bpy.data.objects.remove(piece)
            continue
        key = f"{group}_{name}"
        if name == "Lens":
            middle = sum((piece.matrix_world @ Vector(c) for c in piece.bound_box), Vector()) / 8
            key = "sight_glass_low" if middle.x < 0.05 else "Lens_Front"
        piles.setdefault(key, []).append(piece)

parts = {}
for key, pieces in piles.items():
    only(pieces)
    if len(pieces) > 1:
        bpy.ops.object.join()
    part = bpy.context.view_layer.objects.active
    part.name = key
    part.data.name = key
    only([part])
    bpy.ops.object.shade_smooth()
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    corners = [part.matrix_world @ Vector(c) for c in part.bound_box]
    low = [min(c[i] for c in corners) for i in range(3)]
    high = [max(c[i] for c in corners) for i in range(3)]
    material = part.data.materials[0] if part.data.materials else None
    colour, glow = [0.8, 0.8, 0.8], False
    if material and material.node_tree:
        for node in material.node_tree.nodes:
            if node.type == "BSDF_PRINCIPLED":
                colour = list(node.inputs["Base Color"].default_value)[:3]
                glow = node.inputs["Emission Strength"].default_value > 0
                if glow:
                    colour = list(node.inputs["Emission Color"].default_value)[:3]
                metal = node.inputs["Metallic"].default_value
                rough = node.inputs["Roughness"].default_value
    parts[key] = {
        "triangles": triangles(part),
        "low": low,
        "high": high,
        "colour": colour,
        "glow": glow,
        "metal": metal if material else 0,
        "rough": rough if material else 0.5,
    }

# Roblox brings +X in as -X, and the game's guns point down -Z with unturned parts, so turn the muzzle to -Y here.
only([o for o in bpy.context.scene.objects if o.type == "MESH"])
bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
for o in bpy.context.selected_objects:
    o.matrix_world = Matrix.Rotation(-math.pi / 2, 4, "Z") @ o.matrix_world
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
low = [min((o.matrix_world @ Vector(c))[i] for o in bpy.context.selected_objects for c in o.bound_box) for i in range(3)]
high = [max((o.matrix_world @ Vector(c))[i] for o in bpy.context.selected_objects for c in o.bound_box) for i in range(3)]
print("TURNED", [round(v, 3) for v in low], [round(v, 3) for v in high])

bpy.ops.export_scene.gltf(
    filepath=os.path.join(out, "LeverRifle_low.glb"),
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    export_animations=False,
)
with open(os.path.join(out, "parts.json"), "w") as file:
    json.dump(parts, file, indent=1)
after = sum(p["triangles"] for p in parts.values())
print(f"RESULT {before} -> {after} triangles in {len(parts)} parts")
for key, part in sorted(parts.items()):
    print("PART", key, part["triangles"], [round(c, 2) for c in part["colour"]], "glow" if part["glow"] else "")
