# Gives a model real textures without changing its shape. Every mesh object gets UVs packed into one shared atlas,
# a procedural material picked from its name (brushed steel, gunmetal, polymer grain, knurled grip, rubber, painted
# accents, armour plates), and the materials are baked into one set of 1024 maps: colour, normal, roughness and
# metalness. The meshes are written back out with the same names and the same vertices, so they drop into Studio in
# place of the old ones with the maps on a SurfaceAppearance.
#
# Run inside Blender (Ropilot's, or `blender -b --python tools/texture_model.py -- <args>`):
#   exec(open("tools/texture_model.py").read()); texture(source, out, kind="gun")
# source is a .glb or .fbx; out is a folder for the maps and <name>_textured.glb / .fbx.
# kind picks the look: "gun" (River's guns) or "soldier" (the soldier's body and arms).
# thin: optional { object name: (centre, axis, factor) } to slim a part toward a line before UVs (the soldier's arms).
import math
import os

import bpy
import bmesh
from mathutils import Vector

SIZE = 1024
DETAIL = 1.0  # pattern frequency multiplier: 1 for the guns (metres), lower for bigger models
EDGE_SCALE = 0.0018  # metres: how wide worn edges are (the guns are in metres)
DECALS = None  # set by texture(): { "right": image, "left": image, "lo": (y, z), "hi": (y, z) }


def srgb(c):
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)


# Looks, by the word in a part's name. color is Studio's Color3 (sRGB). pattern picks the surface detail.
GUN = {
    "Steel": dict(color=(0.76, 0.77, 0.78), metal=0.9, rough=0.32, pattern="brushed", wear=0.5, grime=0.6),
    "Gunmetal": dict(color=(0.29, 0.30, 0.32), metal=0.85, rough=0.38, pattern="brushed", wear=0.8, grime=0.6),
    "DarkSteel": dict(color=(0.19, 0.195, 0.21), metal=0.8, rough=0.42, pattern="parkerized", wear=0.9, grime=0.5),
    "BarrelDark": dict(color=(0.43, 0.415, 0.4), metal=0.85, rough=0.4, pattern="heat", wear=0.6, grime=0.7),
    "Polymer": dict(color=(0.17, 0.175, 0.19), metal=0.0, rough=0.62, pattern="polymer", wear=0.35, grime=0.5),
    "Rubber": dict(color=(0.11, 0.11, 0.115), metal=0.0, rough=0.85, pattern="ribs", wear=0.1, grime=0.4),
    "GripTexture": dict(color=(0.18, 0.185, 0.2), metal=0.0, rough=0.7, pattern="knurl", wear=0.3, grime=0.5),
    "AccentRed": dict(color=(0.76, 0.2, 0.25), metal=0.15, rough=0.45, pattern="paint", wear=1.0, grime=0.4),
    "Copper": dict(color=(0.8, 0.58, 0.44), metal=1.0, rough=0.3, pattern="brushed", wear=0.4, grime=0.6),
}
SOLDIER = {
    "armorDark": dict(color=(0.078, 0.129, 0.239), metal=0.15, rough=0.5, pattern="armour", wear=0.7, grime=0.5),
    "armor": dict(color=(0.135, 0.215, 0.37), metal=0.15, rough=0.45, pattern="armour", wear=0.8, grime=0.5),
    "metalLight": dict(color=(0.64, 0.675, 0.725), metal=0.85, rough=0.35, pattern="brushed", wear=0.4, grime=0.5),
    "metal": dict(color=(0.42, 0.455, 0.51), metal=0.8, rough=0.4, pattern="parkerized", wear=0.6, grime=0.5),
    "steel": dict(color=(0.231, 0.263, 0.314), metal=0.85, rough=0.38, pattern="brushed", wear=0.6, grime=0.5),
    "joint": dict(color=(0.137, 0.153, 0.18), metal=0.0, rough=0.75, pattern="weave", wear=0.15, grime=0.4),
    "visor": dict(color=(0.039, 0.051, 0.078), metal=0.4, rough=0.12, pattern="paint", wear=0.2, grime=0.2),
}
SKIP = ("Lens", "CellCore", "Neon", "eye", "sight_glass", "glass")


def look_for(name, kind):
    table = GUN if kind == "gun" else SOLDIER
    words = name.replace(".", "_").split("_")
    for word in sorted(table, key=len, reverse=True):  # longest first, so armorDark wins over armor
        if word in words:
            return table[word]
    for word in sorted(table, key=len, reverse=True):
        if word.lower() in name.lower():
            return table[word]
    return None


def node(tree, kind, x, y, **values):
    made = tree.nodes.new(kind)
    made.location = (x, y)
    for key, value in values.items():
        if key in made.inputs:
            made.inputs[key].default_value = value
        else:
            setattr(made, key, value)
    return made


def link(tree, a, b):
    tree.links.new(a, b)


def build_material(name, look, seed):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    t = m.node_tree
    t.nodes.clear()
    out = node(t, "ShaderNodeOutputMaterial", 1400, 0)
    bsdf = node(t, "ShaderNodeBsdfPrincipled", 1100, 0)
    link(t, bsdf.outputs["BSDF"], out.inputs["Surface"])
    coord = node(t, "ShaderNodeTexCoord", -1400, 0)
    obj = coord.outputs["Object"]
    pattern = look["pattern"]

    # Detail height (0..1) from the pattern, all in object space (metres) so it's the same size on every part.
    def noise(scale, detail=4.0, rough=0.55, vector=None, mapping=None):
        n = node(t, "ShaderNodeTexNoise", -900, 0)
        n.noise_dimensions = "4D"  # the 4th dimension is the seed, so parts don't share one pattern
        n.inputs["W"].default_value = seed
        n.inputs["Scale"].default_value = scale * DETAIL
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = rough
        link(t, mapping if mapping is not None else obj, n.inputs["Vector"])
        return n.outputs["Fac"]

    def stretched(sx, sy, sz):
        mp = node(t, "ShaderNodeMapping", -1150, 0)
        mp.inputs["Scale"].default_value = (sx, sy, sz)
        link(t, obj, mp.inputs["Vector"])
        return mp.outputs["Vector"]

    def math_node(op, a, b=None, clamp=False):
        n = node(t, "ShaderNodeMath", -500, 0, operation=op, use_clamp=clamp)
        if isinstance(a, (int, float)):
            n.inputs[0].default_value = a
        else:
            link(t, a, n.inputs[0])
        if b is not None:
            if isinstance(b, (int, float)):
                n.inputs[1].default_value = b
            else:
                link(t, b, n.inputs[1])
        return n.outputs[0]

    bump_strength = 0.3
    if pattern == "brushed":  # long fine streaks along the gun (Blender Y)
        height = noise(900, 2.0, 0.5, mapping=stretched(1.0, 0.02, 1.0))
        bump_strength = 0.12
    elif pattern == "parkerized":  # a fine matte grain
        height = noise(1400, 3.0, 0.7)
        bump_strength = 0.18
    elif pattern == "heat":  # grain and a little scorch
        height = noise(900, 3.0, 0.6)
        bump_strength = 0.15
    elif pattern == "polymer":  # moulded stipple
        v = node(t, "ShaderNodeTexVoronoi", -900, 0, Scale=420.0 * DETAIL)
        link(t, obj, v.inputs["Vector"])
        height = math_node("POWER", v.outputs["Distance"], 0.6)
        bump_strength = 0.22
    elif pattern == "knurl":  # crossed diamond grooves
        a = node(t, "ShaderNodeTexWave", -900, 120, wave_type="BANDS", bands_direction="DIAGONAL", Scale=140.0 * DETAIL, Distortion=0.0)
        b = node(t, "ShaderNodeTexWave", -900, -120, wave_type="BANDS", bands_direction="DIAGONAL", Scale=140.0 * DETAIL, Distortion=0.0)
        rot = node(t, "ShaderNodeMapping", -1150, -120)
        rot.inputs["Rotation"].default_value = (0, 0, math.radians(90))
        link(t, obj, a.inputs["Vector"])
        link(t, obj, rot.inputs["Vector"])
        link(t, rot.outputs["Vector"], b.inputs["Vector"])
        height = math_node("MINIMUM", a.outputs["Fac"], b.outputs["Fac"])
        bump_strength = 0.6
    elif pattern == "ribs":  # rubber ribs across the pad
        w = node(t, "ShaderNodeTexWave", -900, 0, wave_type="BANDS", bands_direction="Z", Scale=90.0 * DETAIL, Distortion=0.0)
        link(t, obj, w.inputs["Vector"])
        height = w.outputs["Fac"]
        bump_strength = 0.5
    elif pattern == "paint":  # smooth paint with a faint orange peel
        height = noise(700, 2.0, 0.4)
        bump_strength = 0.06
    elif pattern == "armour":  # plates: a soft grain with shallow hex panel lines
        v = node(t, "ShaderNodeTexVoronoi", -900, 0, Scale=9.0 * DETAIL, feature="DISTANCE_TO_EDGE")
        link(t, obj, v.inputs["Vector"])
        lines = math_node("LESS_THAN", v.outputs["Distance"], 0.03)
        grain = noise(260, 3.0, 0.6)
        height = math_node("SUBTRACT", grain, math_node("MULTIPLY", lines, 0.8))
        bump_strength = 0.25
    else:  # weave: crossed fabric bands
        a = node(t, "ShaderNodeTexWave", -900, 120, wave_type="BANDS", bands_direction="X", Scale=160.0 * DETAIL)
        b = node(t, "ShaderNodeTexWave", -900, -120, wave_type="BANDS", bands_direction="Y", Scale=160.0 * DETAIL)
        link(t, obj, a.inputs["Vector"])
        link(t, obj, b.inputs["Vector"])
        height = math_node("MAXIMUM", a.outputs["Fac"], b.outputs["Fac"])
        bump_strength = 0.35

    bump = node(t, "ShaderNodeBump", 800, -300, Strength=bump_strength, Distance=0.002 / DETAIL)
    link(t, height, bump.inputs["Height"])
    link(t, bump.outputs["Normal"], bsdf.inputs["Normal"])

    # Worn edges: where the bevelled normal turns away from the face normal, the paint or bluing is rubbed off.
    bevel = node(t, "ShaderNodeBevel", -900, -500, Radius=EDGE_SCALE, samples=8)
    geo = node(t, "ShaderNodeNewGeometry", -900, -700)
    dot = node(t, "ShaderNodeVectorMath", -650, -550, operation="DOT_PRODUCT")
    link(t, bevel.outputs["Normal"], dot.inputs[0])
    link(t, geo.outputs["Normal"], dot.inputs[1])
    edge = math_node("SUBTRACT", 1.0, dot.outputs["Value"])
    edge = math_node("MULTIPLY", edge, 22.0)
    chips = noise(160, 5.0, 0.7)
    edge = math_node("MULTIPLY", edge, math_node("ADD", chips, 0.25), clamp=True)
    edge = math_node("MULTIPLY", edge, look["wear"], clamp=True)

    # Grime in the gaps and corners, from ambient occlusion, broken up with a big soft noise.
    ao = node(t, "ShaderNodeAmbientOcclusion", -900, -900, samples=16, Distance=EDGE_SCALE * 4)
    dirt = math_node("SUBTRACT", 1.0, ao.outputs["AO"])
    blotch = noise(25, 3.0, 0.6)
    dirt = math_node("MULTIPLY", dirt, math_node("ADD", blotch, 0.4), clamp=True)
    dirt = math_node("MULTIPLY", dirt, look["grime"] * 0.7, clamp=True)

    base = srgb(look["color"])
    # Colour: the base, slightly mottled, lightened toward bare metal on worn edges, darkened by grime.
    mottle = noise(60, 4.0, 0.6)
    tint = node(t, "ShaderNodeMix", 100, 200, data_type="RGBA", blend_type="MIX")
    tint.inputs["A"].default_value = (*[v * 0.86 for v in base], 1)
    tint.inputs["B"].default_value = (*[min(v * 1.12, 1) for v in base], 1)
    link(t, mottle, tint.inputs["Factor"])
    bare = node(t, "ShaderNodeMix", 350, 200, data_type="RGBA", blend_type="MIX")
    link(t, tint.outputs["Result"], bare.inputs["A"])
    bare.inputs["B"].default_value = (*srgb((0.78, 0.79, 0.8)), 1)
    link(t, edge, bare.inputs["Factor"])
    grimy = node(t, "ShaderNodeMix", 600, 200, data_type="RGBA", blend_type="MULTIPLY")
    link(t, bare.outputs["Result"], grimy.inputs["A"])
    grimy.inputs["B"].default_value = (*srgb((0.5, 0.47, 0.44)), 1)
    link(t, dirt, grimy.inputs["Factor"])
    colour_out = grimy.outputs["Result"]
    decal_alpha = None
    if DECALS:
        colour_out, decal_alpha = add_decals(t, colour_out, chips)
    link(t, colour_out, bsdf.inputs["Base Color"])

    # Roughness: rougher in grime, smoother on rubbed edges, with streaks.
    streak = noise(300, 2.0, 0.5, mapping=stretched(1.0, 0.05, 1.0))
    rough = math_node("ADD", look["rough"], math_node("MULTIPLY", math_node("SUBTRACT", streak, 0.5), 0.18))
    rough = math_node("ADD", rough, math_node("MULTIPLY", dirt, 0.25))
    rough = math_node("SUBTRACT", rough, math_node("MULTIPLY", edge, 0.15), clamp=True)
    if decal_alpha is not None:  # paint is satin
        mixr = node(t, "ShaderNodeMix", 900, -100, data_type="FLOAT")
        link(t, decal_alpha, mixr.inputs["Factor"])
        link(t, rough, mixr.inputs["A"])
        mixr.inputs["B"].default_value = 0.45
        rough = mixr.outputs["Result"]
    link(t, rough, bsdf.inputs["Roughness"])

    # Metalness: bare edges of painted parts show metal.
    metal = math_node("ADD", look["metal"], math_node("MULTIPLY", edge, max(0.0, 0.7 - look["metal"])), clamp=True)
    if decal_alpha is not None:  # paint isn't metal
        metal = math_node("MULTIPLY", metal, math_node("SUBTRACT", 1.0, decal_alpha))
    link(t, metal, bsdf.inputs["Metallic"])
    m["metal_socket"] = True
    return m, metal


def add_decals(t, colour, chips):
    """Projects the side decal images onto faces that look along X: the right image on +X faces and the mirrored left
    image on -X faces, so text reads the right way round from both sides. Paint chips off with the edge-wear noise."""
    geo = t.nodes.new("ShaderNodeNewGeometry")
    pos = t.nodes.new("ShaderNodeSeparateXYZ")
    t.links.new(geo.outputs["Position"], pos.inputs[0])
    nrm = t.nodes.new("ShaderNodeSeparateXYZ")
    t.links.new(geo.outputs["Normal"], nrm.inputs[0])
    lo, hi = DECALS["lo"], DECALS["hi"]

    def remap(value, a, b):
        n = t.nodes.new("ShaderNodeMapRange")
        n.inputs["From Min"].default_value = a
        n.inputs["From Max"].default_value = b
        n.clamp = False
        t.links.new(value, n.inputs["Value"])
        return n.outputs["Result"]

    u = remap(pos.outputs["Y"], lo[0], hi[0])
    v = remap(pos.outputs["Z"], lo[1], hi[1])
    uv = t.nodes.new("ShaderNodeCombineXYZ")
    t.links.new(u, uv.inputs["X"])
    t.links.new(v, uv.inputs["Y"])
    results = []
    for side, sign in (("right", 1.0), ("left", -1.0)):
        img = t.nodes.new("ShaderNodeTexImage")
        img.image = DECALS[side]
        img.extension = "CLIP"
        img.interpolation = "Cubic"
        t.links.new(uv.outputs["Vector"], img.inputs["Vector"])
        facing = t.nodes.new("ShaderNodeMath")
        facing.operation = "MULTIPLY"
        facing.inputs[1].default_value = sign
        t.links.new(nrm.outputs["X"], facing.inputs[0])
        mask = t.nodes.new("ShaderNodeMapRange")
        mask.inputs["From Min"].default_value = 0.55
        mask.inputs["From Max"].default_value = 0.8
        mask.clamp = True
        t.links.new(facing.outputs[0], mask.inputs["Value"])
        a = t.nodes.new("ShaderNodeMath")
        a.operation = "MULTIPLY"
        t.links.new(img.outputs["Alpha"], a.inputs[0])
        t.links.new(mask.outputs["Result"], a.inputs[1])
        results.append((img.outputs["Color"], a.outputs[0]))
    # Worn paint: chips where the noise is low.
    worn = t.nodes.new("ShaderNodeMapRange")
    worn.inputs["From Min"].default_value = 0.28
    worn.inputs["From Max"].default_value = 0.36
    worn.clamp = True
    t.links.new(chips, worn.inputs["Value"])
    total = None
    for colour_in, alpha in results:
        a = t.nodes.new("ShaderNodeMath")
        a.operation = "MULTIPLY"
        t.links.new(alpha, a.inputs[0])
        t.links.new(worn.outputs["Result"], a.inputs[1])
        mix = t.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        t.links.new(a.outputs[0], mix.inputs["Factor"])
        t.links.new(colour, mix.inputs["A"])
        t.links.new(colour_in, mix.inputs["B"])
        colour = mix.outputs["Result"]
        if total is None:
            total = a.outputs[0]
        else:
            add = t.nodes.new("ShaderNodeMath")
            add.operation = "ADD"
            add.use_clamp = True
            t.links.new(total, add.inputs[0])
            t.links.new(a.outputs[0], add.inputs[1])
            total = add.outputs[0]
    return colour, total


# Decals: markings painted on the gun's sides, laid out on an exact side render (+Y to the right, +Z up), in that
# render's pixels. kind: text (font title or mono), rect, frame, stripes, barcode, chevrons, dots.
FONTS = {
    "title": r"H:/SplitDeck/assets/fonts/KHInterferencePRO-Bold.otf",
    "mono": r"C:/Windows/Fonts/consolab.ttf",
}
BONE = (232, 230, 223, 255)
ACID = (194, 254, 11, 255)
CYAN = (1, 255, 255, 255)
RED = (205, 52, 62, 255)


def draw_decal(decal):
    """One decal as an RGBA PIL image the size of its rect."""
    from PIL import Image, ImageDraw, ImageFont
    import random
    x0, y0, x1, y1 = decal["rect"]
    w, h = max(1, int(x1 - x0)), max(1, int(y1 - y0))
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    colour = decal.get("color", BONE)
    kind = decal["kind"]
    if kind == "text":
        name = FONTS[decal.get("font", "mono")]
        size = int(h * 1.15)
        font = ImageFont.truetype(name, size=size)
        box = d.textbbox((0, 0), decal["text"], font=font)
        if box[2] - box[0] > w:
            size = max(6, int(size * w / (box[2] - box[0])))
            font = ImageFont.truetype(name, size=size)
            box = d.textbbox((0, 0), decal["text"], font=font)
        th = box[3] - box[1]
        d.text((-box[0], (h - th) / 2 - box[1]), decal["text"], font=font, fill=colour)
    elif kind == "rect":
        d.rectangle((0, 0, w - 1, h - 1), fill=colour)
    elif kind == "frame":
        lw = max(2, min(w, h) // 8)
        d.rectangle((0, 0, w - 1, h - 1), outline=colour, width=lw)
    elif kind == "stripes":
        step = decal.get("step", max(2, h // 2))
        for k in range(-h, w + h, step * 2):
            d.polygon([(k, h), (k + step, h), (k + step + h, 0), (k + h, 0)], fill=colour)
    elif kind == "barcode":
        rng = random.Random(decal.get("seed", 1))
        unit = max(1, h // 14)
        x = 0
        while x < w:
            bw = rng.choice((1, 1, 2, 3)) * unit
            d.rectangle((x, 0, min(w - 1, x + bw - 1), h - 1), fill=colour)
            x += bw + unit * rng.choice((1, 1, 2))
    elif kind == "chevrons":
        n = decal.get("count", 3)
        cw = w / n
        for i in range(n):
            a = i * cw
            d.polygon([(a, 0), (a + cw * 0.45, 0), (a + cw * 0.95, h / 2), (a + cw * 0.45, h), (a, h), (a + cw * 0.5, h / 2)], fill=colour)
    elif kind == "dots":
        r = max(2, h // 2)
        for i in range(int(w // (r * 3))):
            cx = i * r * 3 + r
            d.ellipse((cx - r, h / 2 - r, cx + r, h / 2 + r), fill=colour)
    return img


def make_decals(spec, out, prefix):
    """Paints the decals into a right-side and a left-side image (each decal mirrored in place on the left) and
    returns the Blender images and the projection bounds."""
    from PIL import Image
    W, H = spec["size"]
    right = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    left = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for decal in spec["decals"]:
        img = draw_decal(decal)
        x0, y0 = int(decal["rect"][0]), int(decal["rect"][1])
        right.alpha_composite(img, (x0, y0))
        left.alpha_composite(img.transpose(Image.FLIP_LEFT_RIGHT), (x0, y0))
    # A loaded PNG's top row is V = 1, the top of the gun, so the images go in as drawn.
    images = {}
    for side, img in (("right", right), ("left", left)):
        path = os.path.join(out, f"{prefix}_Decal_{side}.png")
        img.save(path)
        images[side] = bpy.data.images.load(path, check_existing=False)
        images[side].colorspace_settings.name = "sRGB"
    images["lo"] = spec["lo"]
    images["hi"] = spec["hi"]
    return images


def unwrap(objects):
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        while len(o.data.uv_layers):
            o.data.uv_layers.remove(o.data.uv_layers[0])
        o.data.uv_layers.new(name="UVMap")
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(55), island_margin=0.002, area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(margin=0.004, rotate=True)
    bpy.ops.object.mode_set(mode="OBJECT")


def bake(objects, out, prefix, materials):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.render.bake.margin = 6
    images = {}
    for kind in ("Color", "Normal", "Roughness", "Metalness"):
        image = bpy.data.images.new(f"{prefix}_{kind}", SIZE, SIZE, alpha=False)
        image.colorspace_settings.name = "sRGB" if kind == "Color" else "Non-Color"
        images[kind] = image
    for o in objects:
        for slot in o.material_slots:
            t = slot.material.node_tree
            tex = t.nodes.get("BakeTarget") or t.nodes.new("ShaderNodeTexImage")
            tex.name = "BakeTarget"
            tex.location = (1400, -400)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]

    def target(kind):
        for o in objects:
            for slot in o.material_slots:
                t = slot.material.node_tree
                tex = t.nodes["BakeTarget"]
                tex.image = images[kind]
                t.nodes.active = tex

    # Colour: diffuse colour only, no lighting.
    target("Color")
    scene.render.bake.use_pass_direct = False
    scene.render.bake.use_pass_indirect = False
    scene.render.bake.use_pass_color = True
    bpy.ops.object.bake(type="DIFFUSE")
    target("Normal")
    bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT")
    target("Roughness")
    bpy.ops.object.bake(type="ROUGHNESS")
    # Metalness: send the metal value out as emission for a moment and bake that.
    target("Metalness")
    swaps = []
    for o in objects:
        for slot in o.material_slots:
            m = slot.material
            t = m.node_tree
            bsdf = t.nodes.get("Principled BSDF")
            out_node = next(n for n in t.nodes if n.bl_idname == "ShaderNodeOutputMaterial")
            src = bsdf.inputs["Metallic"].links[0].from_socket if bsdf.inputs["Metallic"].links else None
            emit = t.nodes.new("ShaderNodeEmission")
            if src:
                t.links.new(src, emit.inputs["Color"])
            else:
                v = bsdf.inputs["Metallic"].default_value
                emit.inputs["Color"].default_value = (v, v, v, 1)
            old = out_node.inputs["Surface"].links[0].from_socket
            t.links.new(emit.outputs["Emission"], out_node.inputs["Surface"])
            swaps.append((t, old, out_node, emit))
    bpy.ops.object.bake(type="EMIT")
    for t, old, out_node, emit in swaps:
        t.links.new(old, out_node.inputs["Surface"])
        t.nodes.remove(emit)
    paths = {}
    for kind, image in images.items():
        path = os.path.join(out, f"{prefix}_{kind}.png")
        image.filepath_raw = path
        image.file_format = "PNG"
        image.save()
        paths[kind] = path
    return paths


def thin_object(o, centre, axis, factor):
    """Pulls every vertex toward the line through centre along axis (world space), by factor."""
    axis = Vector(axis).normalized()
    centre = Vector(centre)
    mw = o.matrix_world
    inv = mw.inverted()
    for v in o.data.vertices:
        p = mw @ v.co
        along = (p - centre).dot(axis)
        on_line = centre + axis * along
        p = on_line + (p - on_line) * factor
        v.co = inv @ p
    o.data.update()


def texture(source, out, kind="gun", prefix=None, thin=None, decals=None, edge=None):
    os.makedirs(out, exist_ok=True)
    prefix = prefix or os.path.splitext(os.path.basename(source))[0]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if source.lower().endswith(".fbx"):
        bpy.ops.import_scene.fbx(filepath=source)
    else:
        bpy.ops.import_scene.gltf(filepath=source)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    global DECALS, EDGE_SCALE
    DECALS = make_decals(decals, out, prefix) if decals else None
    if edge:
        EDGE_SCALE = edge
    before = {o.name: [list(o.matrix_world @ Vector(c)) for c in (o.bound_box[0], o.bound_box[6])] for o in meshes}
    if thin:
        for name, (centre, axis, factor) in thin.items():
            if name in bpy.data.objects:
                thin_object(bpy.data.objects[name], centre, axis, factor)
    after = {o.name: [list(o.matrix_world @ Vector(c)) for c in (o.bound_box[0], o.bound_box[6])] for o in meshes}
    textured, skipped, unknown = [], [], []
    for index, o in enumerate(meshes):
        if any(word.lower() in o.name.lower() for word in SKIP):
            skipped.append(o.name)
            continue
        look = look_for(o.name, kind)
        if not look:
            unknown.append(o.name)
            continue
        material, _ = build_material("Tex_" + o.name, look, seed=index * 1.7)
        o.data.materials.clear()
        o.data.materials.append(material)
        textured.append(o)
    unwrap(textured)
    paths = bake(textured, out, prefix, None)
    # Write the meshes back out: the textured ones with their new UVs, the skipped ones as they were. No materials:
    # the look goes on as a SurfaceAppearance in Studio.
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    if source.lower().endswith(".fbx"):
        mesh_path = os.path.join(out, f"{prefix}_textured.fbx")
        bpy.ops.export_scene.fbx(filepath=mesh_path, use_selection=True, object_types={"MESH"}, path_mode="STRIP", embed_textures=False, bake_anim=False)
    else:
        mesh_path = os.path.join(out, f"{prefix}_textured.glb")
        bpy.ops.export_scene.gltf(filepath=mesh_path, use_selection=True, export_materials="NONE", export_format="GLB")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, f"{prefix}_textured.blend"))
    return {
        "maps": paths,
        "mesh": mesh_path,
        "textured": [o.name for o in textured],
        "skipped": skipped,
        "unknown": unknown,
        "before": before,
        "after": after,
    }


def rebake(blend, out, prefix, kind="gun", decals=None, edge=None):
    """Bakes new maps onto a model texture() already unwrapped (its saved .blend), keeping its UVs, so the mesh
    already uploaded stays good and only the maps change."""
    bpy.ops.wm.open_mainfile(filepath=blend)
    global DECALS, EDGE_SCALE
    DECALS = make_decals(decals, out, prefix) if decals else None
    if edge:
        EDGE_SCALE = edge
    textured = []
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for index, o in enumerate(meshes):
        if any(word.lower() in o.name.lower() for word in SKIP):
            continue
        look = look_for(o.name, kind)
        if not look or not o.data.uv_layers:
            continue
        material, _ = build_material("Tex_" + o.name, look, seed=index * 1.7)
        o.data.materials.clear()
        o.data.materials.append(material)
        textured.append(o)
    paths = bake(textured, out, prefix, None)
    bpy.ops.wm.save_as_mainfile(filepath=blend)
    return {"maps": paths, "textured": [o.name for o in textured]}



def texture_soldier(fbx, manifest_path, out, prefix, thin_parts=(), factor=0.82, detail=0.06, edge=0.03):
    """The soldier's body or first-person arms (River's FBX, one Blender unit = one stud). Thins the meshes of
    thin_parts (R15 part names) toward their bone axes by factor, then textures everything like texture().
    Returns each thinned mesh's old and new centre and size in the rig's root space, for placing it in Studio."""
    import json
    import numpy
    from mathutils import Matrix, Quaternion
    global DECALS, EDGE_SCALE, DETAIL
    DECALS, EDGE_SCALE, DETAIL = None, edge, detail
    os.makedirs(out, exist_ok=True)
    manifest = json.load(open(manifest_path))
    entries = manifest[os.path.basename(fbx)]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=fbx)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]

    def box(o):
        pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        return (lo + hi) / 2, hi - lo

    # Blender world -> root space: fit root = A @ blender + t over every mesh's box centre.
    names = [o.name for o in meshes if o.name in entries]
    B = numpy.array([list(box(bpy.data.objects[n])[0]) + [1.0] for n in names])
    R = numpy.array([entries[n]["centre"] for n in names])
    sol, residual, _, _ = numpy.linalg.lstsq(B, R, rcond=None)
    A, t = Matrix(sol[:3].T.tolist()), Vector(sol[3].tolist())
    err = float(numpy.abs(B @ sol - R).max())
    A_inv = A.inverted()

    moved = {}
    for o in meshes:
        part = entries.get(o.name, {}).get("part")
        if part not in thin_parts:
            continue
        frame = manifest["partFrames"][part]
        q = Quaternion((frame[6], frame[3], frame[4], frame[5]))
        axis_root = q @ Vector((0, 1, 0))
        point_b = A_inv @ (Vector(frame[:3]) - t)
        axis_b = (A_inv @ axis_root).normalized()
        before = box(o)
        thin_object(o, point_b, axis_b, factor)
        after = box(o)
        moved[o.name] = {
            "old_centre": list(A @ before[0] + t),
            "new_centre": list(A @ after[0] + t),
        }

    textured, skipped = [], []
    for index, o in enumerate(meshes):
        if any(word.lower() in o.name.lower() for word in SKIP):
            skipped.append(o.name)
            continue
        look = look_for(o.name, "soldier")
        if not look:
            skipped.append(o.name)
            continue
        material, _ = build_material("Tex_" + o.name, look, seed=index * 1.7)
        o.data.materials.clear()
        o.data.materials.append(material)
        textured.append(o)
    unwrap(textured)
    paths = bake(textured, out, prefix, None)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    mesh_path = os.path.join(out, f"{prefix}_textured.fbx")
    bpy.ops.export_scene.fbx(filepath=mesh_path, use_selection=True, object_types={"MESH"}, path_mode="STRIP",
                             embed_textures=False, bake_anim=False)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, f"{prefix}_textured.blend"))
    with open(os.path.join(out, f"{prefix}_moved.json"), "w") as f:
        json.dump(moved, f, indent=1)
    return {"maps": paths, "mesh": mesh_path, "fit_error": err, "textured": len(textured), "skipped": skipped,
            "moved": len(moved)}
