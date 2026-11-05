import bpy, math
from mathutils import Vector, Matrix, Quaternion

# Pass GUN="Energy Pistol" with that gun's blend open. M57 is the default.
GUN = globals().get("GUN", "M57")
OUT = "H:/rblxgame/src/shared/Guns/ArmClips/%s.luau" % GUN.replace(" ", "")
arm = bpy.data.objects["Armature"]; pb = arm.pose.bones; vl = bpy.context.view_layer
g = bpy.data.objects[GUN]
MW = arm.matrix_world.copy(); inv = MW.inverted(); R3 = MW.to_3x3().normalized().inverted()
DIG = ("Indice", "DedoMedio", "Anular", "Menique", "Pulgar")
NAMES = [b.name for b in arm.data.bones]

# Blender armature space to the mesh space of the Arms model in Studio.
M = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))
T = Vector((0, -1.5707, 0.1058))
FLIP = Matrix(((-1, 0, 0), (0, 1, 0), (0, 0, -1)))  # bone rolls differ by a half turn
# Blender world to Roblox camera space.
K = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))

g0 = g.matrix_world.copy()
base = {n: pb[n].matrix.copy() for n in NAMES}
POLE = {"R": Vector((.6, -.3, -1)), "L": Vector((-.6, -.2, -1))}
PIVOT = Vector((.7, 1.2, -.9))  # about where the right hand holds the gun
FREE_HAND = "R"  # the hand that leaves the gun in the reload
ONE_HANDED = GUN == "Energy Pistol"  # the left hand stays off the gun, ready to snap
if ONE_HANDED:
    PIVOT = Vector((.5, 1.3, -.7))
    FREE_HAND = "L"
LEFT_GRIP = Vector((.257, 1.335, -.716))  # where the left wrist reaches to, under the pistol, for the reload
GRIP_TILT = -90  # the pistol is posed on its side, top to the left; the blend holds it, LEFT_GRIP is from before it
GRIP_SHIFT = Vector((.2, 0, 0))  # and slid right, out of the middle of the screen
if ONE_HANDED:
    LEFT_GRIP = Matrix.Translation(PIVOT + GRIP_SHIFT) @ Matrix.Rotation(math.radians(GRIP_TILT), 4, 'Y') @ Matrix.Translation(-PIVOT) @ LEFT_GRIP
    PIVOT = PIVOT + GRIP_SHIFT
    POLE["R"] = Vector((.758, -.114, .642))  # the elbow flares out to the side of the sideways hold
SLAP_WRIST = Vector((.46, 1.42, -.5))  # the left wrist with the palm flat on the pistol, before any gun movement
SLAP_FINGERS = Vector((.38, .92, -.1))  # where the slapping fingers point: forward, angled in across the gun
SLAP_PALM = Vector((.03, 0, -1))  # and which way the palm faces
FOLLOW = .25  # share of the gun's movement the free hand picks up from the body


def restore():
    g.matrix_world = g0
    for n in NAMES:
        pb[n].matrix = base[n]
        vl.update()


def twist(k):
    f = pb[k + ".Antebrazo"]; p = pb[k + ".Palma"]
    rest = f.bone.matrix_local.to_quaternion().inverted() @ p.bone.matrix_local.to_quaternion()
    now = f.matrix.to_quaternion().inverted() @ p.matrix.to_quaternion()
    return (rest.inverted() @ now).to_swing_twist('Y')[1]


def open_fingers(k, amount):
    """Eases one hand's fingers toward flat, with amount 0 to 1."""
    palm = pb[k + ".Palma"]
    carry = palm.matrix @ palm.bone.matrix_local.inverted()
    for d in DIG:
        root = pb[k + "." + d]
        flat = carry @ root.bone.matrix_local
        now = root.matrix
        q = now.to_quaternion().slerp(flat.to_quaternion(), amount)
        root.matrix = Matrix.Translation(now.translation) @ q.to_matrix().to_4x4()
        vl.update()
        for suf in ("2", "3"):
            b = pb[k + "." + d + suf]
            loc, rot, _ = b.matrix_basis.decompose()
            b.matrix_basis = Matrix.Translation(loc) @ rot.slerp(Quaternion(), amount).to_matrix().to_4x4()
            vl.update()


def hand_frame():
    """The left hand's directions in the world: fingers, thumb side, and the way the palm faces."""
    head = lambda n: MW @ pb["L." + n].head
    F = (MW @ pb["L.Palma"].tail - head("Palma")).normalized()
    S = head("Indice") - head("Menique")
    S = (S - F * S.dot(F)).normalized()
    N = F.cross(S)
    if N.dot(MW @ pb["L.Anular3"].tail - head("Anular")) < 0:
        N = -N
    return F, S, N


def seg(n):
    return (MW @ pb[n].tail - MW @ pb[n].head).length


def aim_bone(n, a, b):
    m = pb[n].matrix.copy()
    d0 = m.to_3x3().normalized().col[1]
    dn = (R3 @ (b - a)).normalized()
    R = d0.rotation_difference(dn).to_matrix() @ m.to_3x3().normalized()
    pb[n].matrix = Matrix.Translation(inv @ a) @ R.to_4x4()
    vl.update()


def bend_middle(angles, F, N):
    chain = ["L.DedoMedio", "L.DedoMedio2", "L.DedoMedio3"]
    pts = [MW @ pb[chain[0]].head]
    for n, th in zip(chain, angles):
        a = math.radians(th)
        pts.append(pts[-1] + (F * math.cos(a) + N * math.sin(a)) * seg(n))
    for n, a, b in zip(chain, pts, pts[1:]):
        aim_bone(n, a, b)
    return pts[-1]


def reach_thumb(target, pole):
    chain = ["L.Pulgar", "L.Pulgar2", "L.Pulgar3"]
    start = MW @ pb[chain[0]].head
    L = [seg(n) for n in chain]
    c = target - start
    bend = 0
    if c.length < sum(L):
        lo, hi = 0.0, math.radians(80)
        for _ in range(30):
            bend = (lo + hi) / 2
            if L[0] * math.cos(bend) + L[1] + L[2] * math.cos(bend) > c.length:
                lo = bend
            else:
                hi = bend
    u = c.normalized()
    v = (pole - u * pole.dot(u)).normalized()
    dirs = [u * math.cos(bend) + v * math.sin(bend), u, u * math.cos(bend) - v * math.sin(bend)]
    pts = [start]
    for l, dv in zip(L, dirs):
        pts.append(pts[-1] + dv * l)
    fix = (pts[-1] - start).rotation_difference(c)
    pts = [start + fix @ (p - start) for p in pts]
    for n, a, b in zip(chain, pts, pts[1:]):
        aim_bone(n, a, b)


def snap_fingers(mid=(75, 125, 165), thumb=0):
    """thumb 0 presses on the middle fingertip, 1 has slid off it to the base of the index finger."""
    F, S, N = hand_frame()
    tip = bend_middle(mid, F, N)
    pinch = tip + N * .02 + S * .01
    knuckle = MW @ pb["L.Indice"].head + N * .04
    reach_thumb(pinch.lerp(knuckle, thumb), S - N * .5)


def hold(move=(0, 0, 0), pitch=0, roll=0, yaw=0, hand=(0, 0, 0), hand_turn=0, spread=0, reach=1, snap=None, slap=None):
    """Pose the gun and hands together. hand shifts the free hand off the grip, along the gun's own
    axes, hand_turn rolls it about the gun's length, spread opens its fingers. On a one-handed gun,
    reach is how far the left hand goes to its spot, and snap poses it for a finger snap. slap swings the
    left hand on its own: at is its wrist's shift, flat how far it has turned palm-down, or on_gun rides the pistol."""
    restore()
    X = (Matrix.Translation(PIVOT + Vector(move))
         @ Matrix.Rotation(math.radians(yaw), 4, 'Z')
         @ Matrix.Rotation(math.radians(pitch), 4, 'X')
         @ Matrix.Rotation(math.radians(roll), 4, 'Y')
         @ Matrix.Translation(-PIVOT))
    g.matrix_world = X @ g0
    vl.update()
    for k in "RL":
        old = {n: MW @ base[k + "." + n] for n in ("Brazo", "Antebrazo", "Palma") + DIG}
        sh = old["Brazo"].translation; el0 = old["Antebrazo"].translation; wr0 = old["Palma"].translation
        H = X
        if k == FREE_HAND:
            shift = X.to_3x3() @ Vector(hand)
            H = Matrix.Translation(shift) @ X @ Matrix.Translation(wr0) @ Matrix.Rotation(math.radians(hand_turn), 4, 'Y') @ Matrix.Translation(-wr0)
        if k == "L" and ONE_HANDED:
            if slap:
                f = SLAP_FINGERS.normalized()
                n = (SLAP_PALM - f * SLAP_PALM.dot(f)).normalized()
                start = old["Palma"].to_3x3().normalized()
                flat = Matrix((n, f, n.cross(f))).transposed() @ start.inverted()
                if slap.get("on_gun"):
                    H = Matrix.Translation(X @ SLAP_WRIST) @ X.to_3x3().to_4x4() @ flat.to_4x4() @ Matrix.Translation(-wr0)
                else:
                    axis, angle = flat.to_quaternion().to_axis_angle()
                    H = (Matrix.Translation(wr0 + Vector(slap["at"])) @ Matrix.Rotation(angle * slap["flat"], 4, axis)
                         @ Matrix.Translation(-wr0))
            elif snap:
                _, thumb_side, _ = BASE_HAND
                H = (Matrix.Translation(wr0 + Vector(snap.get("shift", (0, 0, 0))))
                     @ Matrix.Rotation(math.radians(snap.get("turn", 0)), 4, thumb_side)
                     @ Matrix.Translation(-wr0))
            elif any(hand):
                H = Matrix.Translation(((X @ LEFT_GRIP + X.to_3x3() @ Vector(hand)) - wr0) * reach)
            else:
                H = Matrix.Translation(Vector(move) * FOLLOW)
        wr = H @ wr0
        a = (el0 - sh).length; b = (wr0 - el0).length
        v = wr - sh; L = min(v.length, (a + b) * .99); d = v.normalized()
        al = (a * a - b * b + L * L) / (2 * L); h = math.sqrt(max(a * a - al * al, 0))
        p = POLE[k] - d * POLE[k].dot(d)
        el = sh + d * al + p.normalized() * h

        def aim(n, head, tail):
            m = inv @ old[n]
            d0 = m.to_3x3().normalized().col[1]
            dn = (R3 @ (tail - head)).normalized()
            R = d0.rotation_difference(dn).to_matrix() @ m.to_3x3().normalized()
            pb[k + "." + n].matrix = Matrix.Translation(inv @ head) @ R.to_4x4()
            vl.update()
        aim("Brazo", sh, el); aim("Antebrazo", el, wr)
        kids = {n: inv @ H @ old[n] for n in ("Palma",) + DIG}
        for n, m in kids.items():
            pb[k + "." + n].matrix = m; vl.update()
        f = pb[k + ".Antebrazo"]; t0 = twist(k); m0 = f.matrix.copy()

        def turn(an):
            f.matrix = m0 @ Matrix.Rotation(an, 4, 'Y'); vl.update()
            for n, m in kids.items():
                pb[k + "." + n].matrix = m; vl.update()
        turn(t0 * .7)
        if abs(twist(k)) > abs(t0):
            turn(-t0 * .7)
    if spread:
        open_fingers(FREE_HAND, spread)
    if snap:
        snap_fingers(snap.get("mid", READY_MID), snap.get("thumb", 0))


def nums(xs):
    return ", ".join(("%.4f" % x).rstrip("0").rstrip(".") if x else "0" for x in xs)


def mesh_matrix(n):
    m = pb[n].matrix
    R = (M @ m.to_3x3().normalized() @ FLIP)
    return Matrix.Translation(M @ m.translation + T) @ R.to_4x4()


def frame(prefix=""):
    gm = g.matrix_world
    pos = K @ gm.translation
    q = (K @ gm.to_3x3().normalized() @ K.inverted()).to_quaternion()
    lines = ["\t\t\t{", "\t\t\t\tgun = CFrame.new(%s, %s)," % (nums(pos), nums((q.x, q.y, q.z, q.w))), "\t\t\t\tbones = {"]
    for n in NAMES:
        if not n.startswith(prefix):
            continue
        c = mesh_matrix(n)
        b = arm.data.bones[n]
        rel = c if not b.parent else mesh_matrix(b.parent.name).inverted() @ c
        p = rel.translation; r = rel.to_quaternion()
        lines.append('\t\t\t\t\t["%s"] = { %s },' % (n, nums((p.x, p.y, p.z, r.x, r.y, r.z, r.w))))
    lines += ["\t\t\t\t},", "\t\t\t},"]
    return lines


# The assault reload sound is 0.964s: a rattle until 0.3s, then the smack lands at 0.44s and rings to 0.64s.
# 11 frames at 11.4 per second fills it, and frame 5 lands on the smack.
UP = dict(move=(-.08, -.15, .16), pitch=52)


def raised(share, **extra):
    return dict(move=tuple(v * share for v in UP["move"]), pitch=UP["pitch"] * share, **extra)


RUN = dict(move=(-.3, -.12, -.02), pitch=20, roll=-32, yaw=38)


def carried(side, bounce, roll, yaw):
    x, y, z = RUN["move"]
    return dict(move=(x + side, y, z + bounce), pitch=RUN["pitch"], roll=RUN["roll"] + roll, yaw=RUN["yaw"] + yaw)


DOWN = dict(move=(.1, -.2, -.9), pitch=-32, roll=14)


def lowered(share):
    return dict(move=tuple(v * share for v in DOWN["move"]), pitch=DOWN["pitch"] * share, roll=DOWN["roll"] * share)


if GUN == "Energy Pistol":
    UP = dict(move=(-.1, -.1, .12), pitch=36)
    RUN = dict(move=(-.1, -.25, -.1), pitch=30, roll=-25, yaw=25)

# Each pose: (move forward/up in Blender world, pitch up, roll).
CLIPS = {
    # A slow breath: the gun sags, the muzzle droops, then it's lifted back up.
    "idle": dict(fps=3, loop=True, poses=[
        dict(),
        dict(move=(.004, 0, -.014), pitch=-.2),
        dict(move=(.01, .004, -.032), pitch=-.6),
        dict(move=(.012, .006, -.042), pitch=-.9),
        dict(move=(.008, .004, -.03), pitch=-.6),
        dict(move=(.003, 0, -.012), pitch=-.2),
    ]),
    # Kicks back past the first frame, drags home, then dips forward before settling.
    # At full auto the next shot restarts it, so the last frames only show after a burst.
    "fire": dict(fps=30, loop=False, poses=[
        dict(move=(.012, -.2, .045), pitch=3.5, roll=-1.5),
        dict(move=(.014, -.24, .05), pitch=4.5, roll=-1.5),
        dict(move=(.01, -.16, .04), pitch=3.2, roll=-.5),
        dict(move=(.005, -.09, .02), pitch=1.8),
        dict(move=(0, -.03, .005), pitch=.6),
        dict(move=(0, .012, -.008), pitch=-.3),
        dict(move=(0, .005, -.003), pitch=-.1),
    ]),
    # The gun swung across the chest, muzzle up and left, bouncing with each stride.
    "run": dict(fps=10, loop=True, poses=[
        carried(0, 0, 0, 0),
        carried(.02, -.05, 2, 1),
        carried(.03, -.07, 3, 1.5),
        carried(0, -.02, 1, .5),
        carried(-.03, -.07, -3, -1.5),
        carried(-.02, -.05, -2, -1),
    ]),
    # Drops out of view on a swap, and the next gun swings up, overshoots and settles.
    "holster": dict(fps=20, loop=False, poses=[lowered(.3), lowered(.65), lowered(1)]),
    "equip": dict(fps=20, loop=False, poses=[
        lowered(1), lowered(.72), lowered(.42), lowered(.16),
        dict(move=(0, .03, .03), pitch=3),
        dict(move=(0, .015, .012), pitch=1.2),
        dict(move=(0, -.01, -.008), pitch=-.5),
    ]),
    # Sinks before heaving up, overshoots the top, gets knocked down hard by the smack,
    # then drops back under its own weight and sags a little past the firing position.
    "reload": dict(fps=11.4, loop=False, poses=[
        raised(-.08, roll=1.5),
        raised(.45),
        raised(1),
        raised(1.12, hand=(.14, -.04, .02), hand_turn=-10, spread=.5),
        raised(1.14, roll=3, hand=(.44, -.16, .18), hand_turn=-30, spread=1),
        raised(.6, roll=-16, hand=(.07, .06, .22), hand_turn=-15, spread=1),  # the smack
        raised(.8, roll=-8, hand=(.1, .04, .18), hand_turn=-15, spread=.9),
        raised(.94, roll=-2, hand=(.12, -.02, .06), hand_turn=-8, spread=.5),
        raised(.55),
        raised(.12),
        raised(-.06),
    ]),
}

def muzzle():
    """The middle of the gun's front end, in Roblox gun space."""
    points = [g.matrix_world @ v.co for v in g.data.vertices]
    front = max(p.y for p in points)
    tip = [p for p in points if p.y > front - .03]
    centre = sum(tip, Vector()) / len(tip)
    return K @ (centre - g.matrix_world.translation)


if GUN == "Energy Pistol":
    # Snaps up with each shot, then settles. At full speed the next shot lands around the fifth frame.
    CLIPS["fire"]["poses"] = [
        dict(move=(0, -.1, .03), pitch=7, roll=-1),
        dict(move=(0, -.12, .04), pitch=9, roll=-1),
        dict(move=(0, -.07, .02), pitch=5),
        dict(move=(0, -.03, .01), pitch=2),
        dict(move=(0, .01, -.005), pitch=-.6),
        dict(move=(0, 0, 0), pitch=-.2),
    ]
    # Pumps like a runner's arm, the gun rolled back upright: out and down to the right, then back in across the chest.
    def pumped(i, frames=8):
        turn = 2 * math.pi * i / frames
        out = (1 - math.cos(turn)) / 2
        x, y, z = -.15, .1, -.22
        return dict(move=(x + .42 * out, y - .05 * out + .05 * math.sin(turn), z - .22 * out - .03 * abs(math.sin(turn))),
                    pitch=18 - 14 * out, roll=78 + 8 * out, yaw=18 - 20 * out)

    CLIPS["run"] = dict(fps=12, loop=True, poses=[pumped(i) for i in range(8)])

    # The gun cocks up to meet it, the left hand winds up and hangs, then whips across in two frames. The hit
    # drives the gun down and right, it bounces past centre and settles while the hand drops back to snapping.
    def blow(x, z, pitch, roll, yaw, **left):
        return dict(move=(x, x * -.11, z), pitch=pitch, roll=roll, yaw=yaw, **left)

    def swing(x, y, z, flat, spread):
        return dict(slap=dict(at=(x, y, z), flat=flat), spread=spread)

    ON_GUN = dict(slap=dict(on_gun=True), spread=1)
    CLIPS["reload"] = dict(fps=15, loop=False, poses=[
        blow(-.03, .03, 3, 2, 0, **swing(-.03, 0, .06, -.02, .1)),
        blow(-.08, .08, 7, 5, 0, **swing(-.07, -.03, .15, -.05, .3)),
        blow(-.13, .12, 11, 8, 0, **swing(-.12, -.06, .25, -.09, .6)),
        blow(-.15, .14, 13, 10, 0, **swing(-.15, -.08, .3, -.12, .8)),
        blow(-.16, .145, 13.5, 10.5, 0, **swing(-.17, -.09, .33, -.14, .9)),
        blow(-.16, .15, 14, 11, 0, **swing(-.18, -.1, .35, -.15, 1)),
        blow(-.16, .15, 14, 11, 0, **swing(.45, .2, .42, .65, 1)),
        blow(.06, -.05, -5, -14, -3, **ON_GUN),  # the hit
        blow(.12, -.09, -8, -22, -5, **ON_GUN),
        blow(.14, -.1, -9, -26, -6, **ON_GUN),
        blow(.12, -.08, -7, -22, -5, **swing(.85, .3, .3, .9, 1)),
        blow(.08, -.05, -4.5, -14, -3, **swing(.62, .26, .33, .7, 1)),
        blow(.03, -.02, -2, -6, -1.5, **swing(.38, .16, .25, .5, .9)),
        blow(-.01, .02, 1, 2, .5, **swing(.2, .09, .15, .3, .8)),
        blow(-.03, .04, 2, 5, 1, **swing(.09, .04, .08, .15, .6)),
        blow(-.02, .03, 1.5, 4, .8, **swing(.04, .02, .03, .07, .4)),
        blow(-.01, .01, .5, 1.5, 0, **swing(.01, 0, .015, .03, .25)),
        blow(.005, 0, 0, -.6, 0, **swing(0, 0, 0, 0, .15)),
        blow(.002, 0, 0, -.2, 0, **swing(0, 0, 0, 0, .05)),
        dict(),
        dict(),
    ])

    # Presses the thumb into the middle finger, then lets go: the finger slams the palm and the hand whips.
    # Left hand only, played on top of whatever the gun is doing.
    SLAM = (88, 175, 240)
    CLIPS["snap"] = dict(fps=24, loop=False, left_only=True, poses=[
        dict(snap=dict(turn=-5, shift=(0, 0, .015), mid=(72, 122, 160))),
        dict(snap=dict(turn=-10, shift=(0, 0, .03), mid=(70, 120, 158))),
        dict(snap=dict(turn=9, shift=(0, .02, -.02), mid=SLAM, thumb=1)),
        dict(snap=dict(turn=14, shift=(0, .03, -.03), mid=SLAM, thumb=1)),
        dict(snap=dict(turn=12, shift=(0, .03, -.03), mid=SLAM, thumb=1)),
        dict(snap=dict(turn=9, shift=(0, .02, -.02), mid=SLAM, thumb=1)),
        dict(snap=dict(turn=9, shift=(0, .02, -.02), mid=SLAM, thumb=1)),
        dict(snap=dict(turn=6, shift=(0, .01, -.015), mid=(85, 165, 225), thumb=.9)),
        dict(snap=dict(turn=3, shift=(0, .005, -.008), mid=(80, 145, 195), thumb=.5)),
        dict(snap=dict(turn=1, mid=(77, 132, 175), thumb=.15)),
    ])

BASE_HAND = hand_frame() if ONE_HANDED else None
READY_MID = (75, 125, 165)

a0 = M.inverted() @ (-T)
off_p = K @ (MW @ a0)
off_q = (K @ MW.to_3x3().normalized() @ M.inverted()).to_quaternion()
out = ["-- Made by the Blender export script from M57 Arms Posed.blend. Don't edit by hand.", "return {",
       "\tmeshOffset = CFrame.new(%s, %s)," % (nums(off_p), nums((off_q.x, off_q.y, off_q.z, off_q.w))),
       "\tmuzzle = Vector3.new(%s)," % nums(muzzle())]
for name, c in CLIPS.items():
    out += ["\t%s = {" % name, "\t\tfps = %s," % c["fps"], "\t\tloop = %s," % ("true" if c["loop"] else "false"), "\t\tframes = {"]
    for p in c["poses"]:
        hold(**p)
        out += frame("L." if c.get("left_only") else "")
    out += ["\t\t},", "\t},"]
out.append("}")
RENDER = globals().get("RENDER_FRAMES")
if RENDER:
    scn = bpy.context.scene
    for clip, i in RENDER:
        hold(**CLIPS[clip]["poses"][i])
        scn.render.filepath = "H:/rblxgame/.superpowers/%s%d.png" % (clip, i)
        bpy.ops.render.render(write_still=True)
restore()
with open(OUT, "w", encoding="utf8", newline="\n") as fh:
    fh.write("\n".join(out) + "\n")
result = {"lines": len(out), "bones": len(NAMES), "gun": [round(x, 3) for x in K @ g0.translation]}
