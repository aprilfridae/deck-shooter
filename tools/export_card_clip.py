import bpy, json, math, os
from mathutils import Vector, Matrix

# Run with Card Arms Posed.blend open. Poses the arms and the bending card, then writes ArmClips/Card.luau.
# Pass RENDER_FRAMES=[("draw", 3), ...] to also render those frames from the first-person camera.
OUT = "H:/rblxgame/src/shared/Guns/ArmClips/Card.luau"
arm = bpy.data.objects["Armature"]; pb = arm.pose.bones; vl = bpy.context.view_layer
rig = bpy.data.objects["CardRig"]
deck = bpy.data.objects["Deck"]
MW = arm.matrix_world.copy(); inv = MW.inverted(); R3 = MW.to_3x3().normalized().inverted()
DIG = ("Indice", "DedoMedio", "Anular", "Menique")
NAMES = [b.name for b in arm.data.bones]
CARD_BONES = [b.name for b in rig.data.bones]
CARD_LENGTH = .32
CARD_SCALE = CARD_LENGTH / .44  # the rig was built .44 long
DECK_OUT, DECK_SIDE, DECK_LIFT = .36, .01, .095  # where the deck sits on the left hand
DECK_TURN = -58  # its long edge runs across the palm, from the thumb to the little finger

# Blender armature space to the mesh space of the Arms model in Studio, and world to Roblox camera space.
M = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))
T = Vector((0, -1.5707, 0.1058))
FLIP = Matrix(((-1, 0, 0), (0, 1, 0), (0, 0, -1)))
K = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))

SHOULDER = {"R": Vector((1, -.42, -1.2)), "L": Vector((-1, -.42, -1.2))}
LENGTHS = {k: ((MW @ arm.data.bones[k + ".Antebrazo"].head_local - MW @ arm.data.bones[k + ".Brazo"].head_local).length,
               (MW @ arm.data.bones[k + ".Palma"].head_local - MW @ arm.data.bones[k + ".Antebrazo"].head_local).length) for k in "RL"}
POLE = {"R": Vector((.2, -.2, -1)), "L": Vector((-.2, -.2, -1))}
SIDE = {"R": -1, "L": 1}  # which way round the fingers-cross-thumb gives the palm
FAN = {"Indice": 1, "DedoMedio": .33, "Anular": -.33, "Menique": -1}


# River's own posing of the left fingers and thumb in Blender, relative to the hand. See hand_matrix.
SHAPE_FILE = "H:/rblxgame/tools/card_left_hand.json"
LEFT_SHAPE = {}
if os.path.exists(SHAPE_FILE):
    with open(SHAPE_FILE, encoding="utf8") as fh:
        LEFT_SHAPE = {n: Matrix(m) for n, m in json.load(fh).items()}


def rest_at(n):
    return MW @ arm.data.bones[n].head_local


def rest_frame(k):
    """The hand's rest directions: fingers, thumb side, palm."""
    f = (rest_at(k + ".DedoMedio") - rest_at(k + ".Palma")).normalized()
    s = rest_at(k + ".Indice") - rest_at(k + ".Menique")
    s = (s - f * s.dot(f)).normalized()
    return f, s, f.cross(s) * SIDE[k]


def twist(k):
    """How far the hand is turned on the forearm from where it rests."""
    f = pb[k + ".Antebrazo"]; p = pb[k + ".Palma"]
    rest = f.bone.matrix_local.to_quaternion().inverted() @ p.bone.matrix_local.to_quaternion()
    now = f.matrix.to_quaternion().inverted() @ p.matrix.to_quaternion()
    return (rest.inverted() @ now).to_swing_twist('Y')[1]


def four_fingers(curl):
    return tuple(curl) * 4 if len(curl) == 3 else tuple(curl)


def world_aim(n, head, tail):
    m = pb[n].matrix.copy()
    d0 = m.to_3x3().normalized().col[1]
    dn = (R3 @ (tail - head)).normalized()
    R = d0.rotation_difference(dn).to_matrix() @ m.to_3x3().normalized()
    pb[n].matrix = Matrix.Translation(inv @ head) @ R.to_4x4()
    vl.update()


def hand_matrix(k, wrist, fingers, palm):
    """Carries the resting hand to a wrist spot, facing the given ways."""
    f = Vector(fingers).normalized()
    p = Vector(palm); p = (p - f * p.dot(f)).normalized()
    s = p.cross(f) * SIDE[k]
    f0, s0, p0 = rest_frame(k)
    def columns(a, b, c):
        return Matrix((a, b, c)).transposed()
    turn = columns(f, s, p) @ columns(f0, s0, p0).inverted()
    return Matrix.Translation(Vector(wrist)) @ turn.to_4x4() @ Matrix.Translation(-rest_at(k + ".Palma"))


def pose_hand(k, wrist, fingers, palm, curl, thumb, spread=0, reach=(1, 1), shape=0):
    """Puts the wrist at a point with the fingers and palm facing given ways. curl is each finger's three joint bends
    (three for all the fingers, or twelve, index first) in degrees toward the palm, spread fans the fingers apart in degrees.
    thumb is nine numbers: for each of its three bones, how far it runs along the fingers, the thumb side and the palm.
    reach stretches its first two bones, because the model's thumb is too short to lie across a card.
    shape is how far the left fingers go to River's posed shape. The left thumb always takes River's."""
    wrist = Vector(wrist)
    f = Vector(fingers).normalized()
    p = Vector(palm); p = (p - f * p.dot(f)).normalized()
    s = p.cross(f) * SIDE[k]
    H = hand_matrix(k, wrist, fingers, palm)

    # The arm reaches the wrist with its elbow out toward the pole.
    sh = SHOULDER[k]
    a, b = LENGTHS[k]
    v = wrist - sh; L = min(v.length, (a + b) * .99); d = v.normalized()
    al = (a * a - b * b + L * L) / (2 * L); h = math.sqrt(max(a * a - al * al, 0))
    q = POLE[k] - d * POLE[k].dot(d)
    el = sh + d * al + q.normalized() * h
    world_aim(k + ".Brazo", sh, el)
    world_aim(k + ".Antebrazo", el, wrist)

    # The forearm takes most of the hand's turn, as on the guns, so the wrist doesn't pinch.
    palm_at = inv @ H @ (MW @ arm.data.bones[k + ".Palma"].matrix_local)
    pb[k + ".Palma"].matrix = palm_at; vl.update()
    fore = pb[k + ".Antebrazo"]; whole = twist(k); fore_at = fore.matrix.copy()

    def turn_forearm(angle):
        fore.matrix = fore_at @ Matrix.Rotation(angle, 4, 'Y'); vl.update()
        pb[k + ".Palma"].matrix = palm_at; vl.update()
    turn_forearm(whole * .7)
    if abs(twist(k)) > abs(whole):
        turn_forearm(-whole * .7)
    axis = f.cross(p)
    bends = four_fingers(curl)
    for d_name in DIG + ("Pulgar",):
        names = [k + "." + d_name + x for x in ("", "2", "3")]
        for n in names:
            pb[n].matrix = inv @ H @ (MW @ arm.data.bones[n].matrix_local); vl.update()
        at = H @ rest_at(names[0]); total = 0
        for i, n in enumerate(names):
            bn = arm.data.bones[n]
            dr = (H.to_3x3() @ ((MW @ bn.tail_local) - (MW @ bn.head_local)))
            if d_name == "Pulgar":
                a, b, c = thumb[i * 3:i * 3 + 3]
                tail = at + (f * a + s * b + p * c).normalized() * dr.length * (tuple(reach) + (1,))[i]
            else:
                total += bends[DIG.index(d_name) * 3 + i]
                fan = math.radians(spread * FAN[d_name] * SIDE[k])
                tail = at + Matrix.Rotation(fan, 3, p) @ Matrix.Rotation(math.radians(total), 3, axis) @ dr
            world_aim(n, at, tail)
            at = tail
    if k == "L":
        for n, shaped in LEFT_SHAPE.items():
            share = 1 if "Pulgar" in n else shape
            if share > 0:
                now = pb[n].matrix.copy()
                goal = inv @ H @ shaped
                turned = now.to_quaternion().slerp(goal.to_quaternion(), share).to_matrix().to_4x4()
                pb[n].matrix = Matrix.Translation(now.translation.lerp(goal.translation, share)) @ turned
                vl.update()


def pose_card(centre, along, facing, bend):
    """Puts the card's middle at a point, its long edge along one way and its face another, bowed by bend degrees."""
    y = Vector(along).normalized()
    z = Vector(facing); z = (z - y * z.dot(y)).normalized()
    x = y.cross(z)
    joints = len(CARD_BONES) - 1
    step = math.radians(bend) / joints if joints else 0
    seg = CARD_LENGTH / len(CARD_BONES)
    # Walks the bent chain to find its middle and its chord, so the card stays centred and aimed.
    pts = [Vector((0, 0)), Vector((seg, 0))]
    ang = 0
    for _ in range(joints):
        ang += step
        pts.append(pts[-1] + Vector((math.cos(ang), math.sin(ang))) * seg)
    mid = sum((p for p in pts), Vector((0, 0))) / len(pts)
    chord = pts[-1] - pts[0]; lean = math.atan2(chord.y, chord.x)
    frame_m = Matrix((x, y, z)).transposed().to_4x4()
    local = (Matrix.Rotation(-lean, 4, 'X')
             @ Matrix.Translation(Vector((0, -mid.x + CARD_LENGTH / 2, -mid.y)))
             @ Matrix.Scale(CARD_SCALE, 4))
    rig.matrix_world = Matrix.Translation(Vector(centre)) @ frame_m @ local
    for i, n in enumerate(CARD_BONES):
        p = rig.pose.bones[n]
        p.rotation_mode = 'XYZ'
        p.rotation_euler = (step if i else 0, 0, 0)
    vl.update()


def nums(xs):
    return ", ".join(("%.4f" % x).rstrip("0").rstrip(".") if x else "0" for x in xs)


def mesh_matrix(n):
    m = pb[n].matrix
    return Matrix.Translation(M @ m.translation + T) @ (M @ m.to_3x3().normalized() @ FLIP).to_4x4()


def frame(bend):
    m = rig.matrix_world
    q = (K @ m.to_3x3().normalized() @ M.inverted()).to_quaternion()
    d = deck.matrix_world
    dq = (K @ d.to_3x3().normalized() @ M.inverted()).to_quaternion()
    lines = ["\t\t\t{", "\t\t\t\tcard = CFrame.new(%s, %s)," % (nums(K @ m.translation), nums((q.x, q.y, q.z, q.w))),
             "\t\t\t\tdeck = CFrame.new(%s, %s)," % (nums(K @ d.translation), nums((dq.x, dq.y, dq.z, dq.w))),
             "\t\t\t\tbend = %s," % nums((math.radians(bend) / (len(CARD_BONES) - 1),)), "\t\t\t\tbones = {"]
    for n in NAMES:
        c = mesh_matrix(n)
        b = arm.data.bones[n]
        rel = c if not b.parent else mesh_matrix(b.parent.name).inverted() @ c
        p = rel.translation; r = rel.to_quaternion()
        lines.append('\t\t\t\t\t["%s"] = { %s },' % (n, nums((p.x, p.y, p.z, r.x, r.y, r.z, r.w))))
    lines += ["\t\t\t\t},", "\t\t\t},"]
    return lines


def lerp(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


# Matches River's reference: the left hand holds a deck palm up, curled fingers spring the top card off its far end,
# it spins flat across, lands on the open right palm and the fingers shut over it.
def vec(*a):
    return Vector(a)


LEFT_WRIST = vec(-.62, .98, -.62)
LEFT_FINGERS = vec(.72, .25, .6).normalized()
LEFT_PALM = vec(.12, -.8, .58)
LEFT_PALM = (LEFT_PALM - LEFT_FINGERS * LEFT_PALM.dot(LEFT_FINGERS)).normalized()
LEFT_SIDE = LEFT_PALM.cross(LEFT_FINGERS)
DECK_ALONG = Matrix.Rotation(math.radians(DECK_TURN), 3, LEFT_PALM) @ LEFT_FINGERS
DECK_AT = LEFT_WRIST + LEFT_FINGERS * DECK_OUT + LEFT_SIDE * DECK_SIDE + LEFT_PALM * DECK_LIFT
DECK_TOP = DECK_AT + LEFT_PALM * .055
DECK_UP = dict(fingers=tuple(LEFT_FINGERS), palm=tuple(LEFT_PALM))
LEFT_THUMB = (.1, .75, .65, .15, .8, .6, .2, .85, .45)  # stands up beside the deck
LEFT_SET = dict(wrist=tuple(LEFT_WRIST), curl=(2, 10, 50), thumb=LEFT_THUMB, shape=1, **DECK_UP)
LEFT_COIL = dict(wrist=tuple(LEFT_WRIST + vec(.02, 0, .03)), curl=(6, 18, 70), thumb=LEFT_THUMB, **DECK_UP)
LEFT_SNAP = dict(wrist=tuple(LEFT_WRIST + vec(-.02, 0, -.04)), curl=(-8, 8, 5), thumb=LEFT_THUMB, spread=14, **DECK_UP)
LEFT_OPEN = dict(wrist=tuple(LEFT_WRIST), curl=(4, 12, 8), thumb=LEFT_THUMB, spread=12, **DECK_UP)
LEFT_LOW = dict(LEFT_SET, wrist=tuple(LEFT_WRIST + vec(-.1, -.1, -.6)))

THUMB_ON_CARD = (.4, 0, .9, .9, -.2, .38, .95, -.3, .05)  # comes over the card's edge and lies across it
THUMB_LIFTED = (.3, .6, .75, .3, .75, .6, .3, .85, .4)  # held up out of the card's way
# The right hand holds one pose the whole way through, at the pistol's wrist spot with the hand in line with the forearm.
# The palm faces the camera, the card lies across the fingers and sticks out past the index side, under the thumb.
SHUT_WRIST, SHUT_FINGERS, SHUT_PALM = (.69, .98, -.62), (-.66, .42, .62), (-.33, -.9, .26)
RIGHT_SHUT = dict(wrist=SHUT_WRIST, fingers=SHUT_FINGERS, palm=SHUT_PALM, thumb=THUMB_ON_CARD, reach=(1.3, 2.2),
                  curl=(4, 10, 15, 4, 10, 15, 10, 20, 18, 12, 22, 18))
RIGHT_EASY = RIGHT_SHUT
RIGHT_WIDE = dict(RIGHT_SHUT, thumb=THUMB_LIFTED, reach=(1.3, 1.6))
RIGHT_LOW = dict(RIGHT_SHUT, wrist=tuple(Vector(SHUT_WRIST) + vec(.05, -.05, -.6)))
RIGHT_DIP = dict(RIGHT_SHUT, wrist=tuple(Vector(SHUT_WRIST) + vec(.02, -.01, -.08)))


CARD_LIFT = .08  # just clear of the palm's skin
RIGHT_DIP_BY = vec(.02, -.01, -.08)


def on_right():
    f = Vector(SHUT_FINGERS).normalized()
    p = Vector(SHUT_PALM); p = (p - f * p.dot(f)).normalized()
    side = p.cross(f) * -1
    return Vector(SHUT_WRIST) + f * .42 + side * .16 + p * CARD_LIFT, p, side


HELD_AT, RIGHT_NORMAL, HELD_ALONG = on_right()
SPIN_AXIS = RIGHT_NORMAL.lerp(LEFT_PALM, .5).normalized()
LAND = math.degrees(math.atan2(DECK_ALONG.cross(HELD_ALONG).dot(SPIN_AXIS), DECK_ALONG.dot(HELD_ALONG))) % 360


def turned(share):
    """The card's long edge, this share of the way through its one spin from the deck to the hand."""
    return tuple(Matrix.Rotation(math.radians(share * (LAND + 360)), 3, SPIN_AXIS) @ DECK_ALONG)


def on_deck(slide, bend):
    return dict(centre=tuple(DECK_TOP + DECK_ALONG * slide), along=tuple(DECK_ALONG), facing=tuple(LEFT_PALM), bend=bend)


def flying(t, spin, bend):
    at = (DECK_TOP + DECK_ALONG * .16).lerp(HELD_AT, t) + vec(0, .03, .2) * math.sin(t * math.pi)
    return dict(centre=tuple(at), along=turned(spin), facing=tuple(LEFT_PALM.lerp(RIGHT_NORMAL, t).normalized()), bend=bend)


def seated(wobble, dip=0, raised=0):
    """dip is how far through the catch's dip the hand is, so the card goes with it."""
    along = Matrix.Rotation(math.radians(wobble), 3, RIGHT_NORMAL) @ HELD_ALONG
    return dict(centre=tuple(HELD_AT + RIGHT_DIP_BY * dip + vec(0, 0, raised)), along=tuple(along), facing=tuple(RIGHT_NORMAL), bend=0)


def mix(a, b, t):
    out = dict(a)
    for key in ("wrist", "fingers", "palm", "thumb"):
        out[key] = lerp(a[key], b[key], t)
    out["curl"] = lerp(four_fingers(a["curl"]), four_fingers(b["curl"]), t)
    out["reach"] = lerp(a.get("reach", (1, 1)), b.get("reach", (1, 1)), t)
    out["shape"] = a.get("shape", 0) + (b.get("shape", 0) - a.get("shape", 0)) * t
    out["spread"] = a.get("spread", 0) + (b.get("spread", 0) - a.get("spread", 0)) * t
    return out


def still(hand_l, hand_r, card):
    return dict(L=hand_l, R=hand_r, card=card, deck=hand_l["wrist"])


DRAW = [
    still(mix(LEFT_LOW, LEFT_SET, .45), mix(RIGHT_LOW, RIGHT_EASY, .45), on_deck(0, 0)),
    still(mix(LEFT_LOW, LEFT_SET, .85), mix(RIGHT_LOW, RIGHT_EASY, .85), on_deck(0, 0)),
    still(LEFT_SET, RIGHT_EASY, on_deck(0, -6)),
    still(mix(LEFT_SET, LEFT_COIL, .6), mix(RIGHT_EASY, RIGHT_WIDE, .2), on_deck(.02, -35)),
    still(LEFT_COIL, mix(RIGHT_EASY, RIGHT_WIDE, .5), on_deck(.07, -75)),  # sprung, about to go
    still(LEFT_SNAP, mix(RIGHT_EASY, RIGHT_WIDE, .85), flying(.1, .1, 55)),
    still(LEFT_SNAP, RIGHT_WIDE, flying(.4, .38, -30)),
    still(mix(LEFT_SNAP, LEFT_OPEN, .5), RIGHT_WIDE, flying(.72, .7, 16)),
    still(LEFT_OPEN, RIGHT_WIDE, flying(.96, .96, -8)),  # lands on the palm
    still(LEFT_OPEN, RIGHT_DIP, seated(8, 1)),  # the hand snaps shut, thumb over the card
    still(mix(LEFT_OPEN, LEFT_SET, .5), RIGHT_DIP, seated(-4, 1)),
    still(LEFT_SET, mix(RIGHT_DIP, RIGHT_SHUT, .6), seated(2, .4)),
    still(LEFT_SET, RIGHT_SHUT, seated(0)),
]
HOLD = [still(LEFT_SET, dict(RIGHT_SHUT, wrist=tuple(vec(*RIGHT_SHUT["wrist"]) + vec(0, 0, d))), seated(0, 0, d)) for d in (0, .006, .014, .006)]
CLIPS = {"draw": dict(fps=24, loop=False, poses=DRAW), "hold": dict(fps=3, loop=True, poses=HOLD)}


def apply(pose):
    pose_hand("L", **pose["L"])
    pose_hand("R", **pose["R"])
    pose_card(**pose["card"])
    f = Vector(pose["L"]["fingers"]).normalized()
    p = Vector(pose["L"]["palm"]); p = (p - f * p.dot(f)).normalized()
    along = Matrix.Rotation(math.radians(DECK_TURN), 3, p) @ f
    at = Vector(pose["L"]["wrist"]) + f * DECK_OUT + p.cross(f) * DECK_SIDE + p * DECK_LIFT
    deck.matrix_world = Matrix.Translation(at) @ Matrix((along.cross(p), along, p)).transposed().to_4x4()
    vl.update()


a0 = M.inverted() @ (-T)
off_q = (K @ MW.to_3x3().normalized() @ M.inverted()).to_quaternion()
out = ["-- Made by tools/export_card_clip.py from Card Arms Posed.blend. Don't edit by hand.", "return {",
       "\tmeshOffset = CFrame.new(%s, %s)," % (nums(K @ (MW @ a0)), nums((off_q.x, off_q.y, off_q.z, off_q.w)))]
for name, c in CLIPS.items():
    out += ["\t%s = {" % name, "\t\tfps = %s," % c["fps"], "\t\tloop = %s," % ("true" if c["loop"] else "false"), "\t\tframes = {"]
    for p in c["poses"]:
        apply(p)
        out += frame(p["card"]["bend"])
    out += ["\t\t},", "\t},"]
out.append("}")
for clip, i in globals().get("RENDER_FRAMES") or []:
    apply(CLIPS[clip]["poses"][i])
    scn = bpy.context.scene
    scn.render.filepath = "H:/rblxgame/.superpowers/card_%s%d.png" % (clip, i)
    bpy.ops.render.render(write_still=True)
with open(OUT, "w", encoding="utf8", newline="\n") as fh:
    fh.write("\n".join(out) + "\n")
result = {"lines": len(out), "lengths": {k: [round(x, 3) for x in v] for k, v in LENGTHS.items()},
          "shoulders": {k: [round(x, 3) for x in v] for k, v in SHOULDER.items()}}
