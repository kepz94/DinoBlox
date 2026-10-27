#!/usr/bin/env python3
"""Raptor generator v1.4 (Dino Arcade) -> src/shared/Models/RaptorModelData.luau

Movie-style raptor (Deinonychus size) in the T-Rex block style (docs/STYLE_TRex.md), scaled to the
T-Rex: T-Rex 40.1 studs long ~ 12.3 m (3.26 studs/m); raptor ~3.9 m -> 12.85 studs long, hip 3.3.
Palette from the user's reference picture: green body with dark bands, cream belly/throat, teal face
stripe, yellow slit eye, olive lower legs, dark claws including the raised sickle claw.

Same 17-segment rig and joint names as the T-Rex (rig 1.3), so IdleAnimation / WalkPose / TurnPose /
HeadLeadPose / DinoHitboxes / StaminaServer work unchanged:
  RootJoint (HRP->Torso), Neck, Head, Jaw, ArmL/R, Tail1-5, LegL/R (hip), KneeL/R, AnkleL/R.
All joints are world-aligned (identity rotation in C0); tilts are baked into the parts.

Coordinates: "dino space" D = (x forward, y up, z side; z > 0 is the L side, as on the T-Rex), origin at
the hip centre (= HumanoidRootPart centre). HRP space = (z, y, -x) (HRP LookVector = dino forward).
Run: python3 tools/raptor_generator.py   (writes the data file; prints the bounds)
v1.1: leap (JumpTest 1.0 / JumpServer 1.0 / JumpPose 1.0): JumpEnabled true, JumpWindup 0.12, JumpLaunchPower 59
      (measured 11.0 studs, 0.67 s in the air), JumpBoost 10 (when moving faster than JumpBoostMinSpeed 2), JumpAirHold true, JumpStaminaCost 15,
      JumpCooldown 0.5. Geometry unchanged.
v1.2: pounce (PounceTest 1.0 / PounceServer 1.0 / PouncePose 1.0): PounceEnabled true, 20-stud lunge (PounceDistance 20,
      PounceUpSpeed 28), PounceCooldown 3, PounceStaminaCost 15, PounceLatchDrain 15/s, PounceLandDamage 8 + PounceTickDamage 4
      every PounceTickInterval 0.5 s, latches onto dinos at least PounceSizeRatio 1.5x its size. Geometry unchanged.
v1.3: version attributes only (inherited from TRexModelData 1.15: ShoulderCam 1.0, TurnLimit 1.1, PounceFX 1.0,
      PounceTest 1.2, PounceServer 1.1).
v1.4: crouch walk (user: "the raptor needs to actually look like a crouch"; shown while exhausted, CreepServer 1.1).
      The inherited T-Rex creep values scaled to the raptor's legs gave a 0.7-stud dip and ~8 tiny steps/s at
      MoveCreepSpeed 10. Raptor creep: CreepCrouch 4.3 (1.3 studs = ~40% of the 3.3 hip), CreepStepLength 12 +
      CreepDuty 0.65 + CreepStrideStretch 1.15 (~3 steps/s, feet glide ~1.3 studs/s), CreepLift 2, CreepFootForward 1,
      CreepLean 6, CreepNeckDrop 20, CreepTailDrop 10 (tail level instead of raised), CreepTailWhip 0.15,
      CreepArmTuck 35. WalkSideStepReach 1.6 (WalkPose 3.4 strafe: the narrow hips (0.55 from the centre) give a
      1-reach side step of only 0.55 studs, so the planted foot slid at ~24 of 30 studs/s; 1.6 = feet cross the centre
      line by ~0.3). Version attributes: IdleAnimation 1.17, WalkPose 3.4.
"""
import math, re, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "src", "shared", "Models", "RaptorModelData.luau")
TREX = os.path.join(ROOT, "src", "shared", "Models", "TRexModelData.luau")

VERSION = "1.4"
HIP = 3.3            # hip (HRP centre) height above the ground
HRP_SIZE_D = (3.6, 2.4, 1.4)   # D x (length), y, z (width)

C = {
    "body":   "5E943E",  # green
    "dark":   "283A1E",  # dark bands
    "belly":  "C9C98F",  # cream
    "teal":   "2E8C82",  # face stripe
    "lower":  "8FA046",  # olive lower legs / feet
    "mouth":  "963C3C",
    "tooth":  "E8E2D2",
    "claw":   "302824",
    "eye":    "F0C81E",
    "pupil":  "111111",
}
SMOOTH = {"eye", "pupil", "tooth", "claw", "mouth"}

M = ((0, 0, 1), (0, 1, 0), (-1, 0, 0))  # D -> HRP space


def matmul(a, b):
    return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)) for i in range(3))


def mv(a, v):
    return tuple(sum(a[i][k] * v[k] for k in range(3)) for i in range(3))


def rot(pitch=0.0, yaw=0.0, roll=0.0):
    """Rotation in D: roll about x, then yaw about y, then pitch about z (degrees), R = Rz*Ry*Rx."""
    p, y, r = math.radians(pitch), math.radians(yaw), math.radians(roll)
    Rz = ((math.cos(p), -math.sin(p), 0), (math.sin(p), math.cos(p), 0), (0, 0, 1))
    Ry = ((math.cos(y), 0, math.sin(y)), (0, 1, 0), (-math.sin(y), 0, math.cos(y)))
    Rx = ((1, 0, 0), (0, math.cos(r), -math.sin(r)), (0, math.sin(r), math.cos(r)))
    return matmul(Rz, matmul(Ry, Rx))


def cf(pos_d, R_d=None):
    R = matmul(M, R_d if R_d else rot())
    p = mv(M, pos_d)
    vals = list(p) + [R[0][0], R[0][1], R[0][2], R[1][0], R[1][1], R[1][2], R[2][0], R[2][1], R[2][2]]
    return [round(v, 6) + 0.0 for v in vals]


segments = {}   # name -> {"root": D pos, "parts": []}
order = []


def seg(name, root):
    segments[name] = {"root": root, "parts": []}
    order.append(name)


def part(segname, key, size, center, pitch=0.0, yaw=0.0, roll=0.0, name=None):
    segments[segname]["parts"].append({
        "name": name or f"{segname}_{key}",
        "size": size, "center": center, "R": rot(pitch, yaw, roll), "key": key})


def about(root, point, pitch):
    """point rotated about root by pitch (degrees, about D z)."""
    a = math.radians(pitch)
    dx, dy = point[0] - root[0], point[1] - root[1]
    return (root[0] + dx * math.cos(a) - dy * math.sin(a), root[1] + dx * math.sin(a) + dy * math.cos(a), point[2])


def tilt_down(dx, dy):
    """pitch (deg) that turns a box's +Y axis to point along (dx, dy) downward direction (bottom end toward +x)."""
    return math.degrees(math.atan2(dx, -dy))


# ---------------------------------------------------------------- torso
seg("Torso", (0.0, 0.0, 0.0))
part("Torso", "body", (2.6, 1.3, 1.15), (0.5, 0.15, 0.0))
part("Torso", "body", (1.1, 1.25, 1.0), (1.75, 0.05, 0.0), pitch=-8, name="Torso_chest")
part("Torso", "body", (1.2, 1.15, 1.05), (-0.6, 0.25, 0.0), pitch=6, name="Torso_hips")
part("Torso", "belly", (2.4, 0.3, 0.92), (0.7, -0.45, 0.0))
part("Torso", "belly", (0.5, 0.8, 0.8), (2.2, 0.0, 0.0), name="Torso_throat")
for i, (x, top, w) in enumerate([(-0.9, 0.86, 1.09), (-0.35, 0.86, 1.19), (0.2, 0.83, 1.19), (0.75, 0.83, 1.19),
                                 (1.3, 0.83, 1.19), (1.85, 0.71, 1.04)]):
    part("Torso", "dark", (0.2, 0.95, w), (x, top - 0.475, 0.0), name=f"Torso_band{i + 1}")

# ---------------------------------------------------------------- neck
seg("Neck", (2.05, 0.45, 0.0))
part("Neck", "body", (0.95, 0.8, 0.72), (2.4, 0.85, 0.0), pitch=50)
part("Neck", "body", (0.85, 0.65, 0.62), (2.85, 1.4, 0.0), pitch=25, name="Neck_upper")
part("Neck", "belly", (0.75, 0.25, 0.56), (2.62, 0.56, 0.0), pitch=50, name="Neck_throat")
part("Neck", "dark", (0.16, 0.5, 0.75), (2.42, 1.12, 0.0), pitch=50, name="Neck_band1")
part("Neck", "dark", (0.16, 0.4, 0.65), (2.86, 1.62, 0.0), pitch=25, name="Neck_band2")

# ---------------------------------------------------------------- head
seg("Head", (3.15, 1.6, 0.0))
part("Head", "body", (1.05, 0.8, 0.78), (3.55, 1.65, 0.0), name="Head_skull")
part("Head", "body", (1.25, 0.52, 0.6), (4.55, 1.55, 0.0), pitch=-4, name="Head_snout")
part("Head", "body", (0.35, 0.42, 0.5), (5.2, 1.5, 0.0), name="Head_tip")
part("Head", "mouth", (1.9, 0.12, 0.5), (4.25, 1.2, 0.0), name="Head_mouth")
for i, x in enumerate([3.8, 4.05, 4.3, 4.55, 4.8, 5.05]):
    part("Head", "tooth", (0.12, 0.14, 0.58), (x, 1.24, 0.0), name=f"Head_tooth{i + 1}")
part("Head", "dark", (0.5, 0.12, 0.82), (3.8, 2.07, 0.0), name="Head_brow")
part("Head", "dark", (0.15, 0.06, 0.8), (3.3, 2.06, 0.0), name="Head_band1")
part("Head", "dark", (0.12, 0.05, 0.62), (4.3, 1.82, 0.0), name="Head_band2")
part("Head", "dark", (0.12, 0.05, 0.62), (4.75, 1.8, 0.0), name="Head_band3")
for side in (1, -1):
    sname = "L" if side > 0 else "R"
    part("Head", "teal", (0.8, 0.12, 0.03), (3.25, 1.76, side * 0.395), name=f"Head_stripe{sname}")
    part("Head", "eye", (0.26, 0.24, 0.05), (3.75, 1.82, side * 0.395), name=f"Head_eye{sname}")
    part("Head", "pupil", (0.07, 0.2, 0.03), (3.77, 1.82, side * 0.42), name=f"Head_pupil{sname}")
    part("Head", "dark", (0.08, 0.06, 0.04), (5.3, 1.62, side * 0.22), name=f"Head_nostril{sname}")

# ---------------------------------------------------------------- jaw (rest open 14 deg)
JAW_ROOT = (3.35, 1.25, 0.0)
JAW_OPEN = -14
seg("Jaw", JAW_ROOT)
for key, size, c, nm in [
    ("body", (1.9, 0.3, 0.55), (4.35, 1.0, 0.0), "Jaw_lower"),
    ("body", (0.4, 0.25, 0.45), (5.1, 1.02, 0.0), "Jaw_chin"),
    ("belly", (1.6, 0.1, 0.45), (4.3, 0.84, 0.0), "Jaw_under"),
] + [("tooth", (0.12, 0.12, 0.5), (x, 1.2, 0.0), f"Jaw_tooth{i + 1}") for i, x in enumerate([4.0, 4.25, 4.5, 4.75, 5.0])]:
    part("Jaw", key, size, about(JAW_ROOT, c, JAW_OPEN), pitch=JAW_OPEN, name=nm)

# ---------------------------------------------------------------- arms (hang down and forward, three claws)
for side in (1, -1):
    s = "L" if side > 0 else "R"
    z = side * 0.62
    sh, el, ha = (1.85, -0.25), (2.05, -0.85), (2.35, -1.45)
    seg(f"Arm{s}", (sh[0], sh[1], side * 0.52))
    part(f"Arm{s}", "body", (0.28, 0.72, 0.24), ((sh[0] + el[0]) / 2, (sh[1] + el[1]) / 2, z),
         pitch=tilt_down(el[0] - sh[0], el[1] - sh[1]), name=f"Arm{s}_upper")
    part(f"Arm{s}", "body", (0.24, 0.72, 0.22), ((el[0] + ha[0]) / 2, (el[1] + ha[1]) / 2, z),
         pitch=tilt_down(ha[0] - el[0], ha[1] - el[1]), name=f"Arm{s}_fore")
    part(f"Arm{s}", "dark", (0.25, 0.1, 0.25), (2.08, -0.8, z), name=f"Arm{s}_band")
    part(f"Arm{s}", "lower", (0.3, 0.22, 0.24), (2.4, -1.5, z), name=f"Arm{s}_hand")
    for i, dz in enumerate((-0.07, 0.0, 0.07)):
        part(f"Arm{s}", "claw", (0.06, 0.28, 0.05), (2.5, -1.68, z + dz), pitch=20, name=f"Arm{s}_claw{i + 1}")

# ---------------------------------------------------------------- tail (long, stiff and raised: straight line rising TAIL_RISE)
TAIL_RISE = 12.0  # degrees above horizontal, from the hips back (user: raised higher and stiff)
tail = [  # segment length (root to next root), block size, band offsets from the root [(distance, key)]
    (1.45, (1.55, 0.8, 0.78), [(1.05, "dark")]),
    (1.35, (1.45, 0.62, 0.6), [(0.4, "dark"), (1.0, "dark")]),
    (1.25, (1.35, 0.48, 0.46), [(0.4, "dark"), (0.9, "belly")]),
    (1.15, (1.25, 0.36, 0.34), [(0.35, "dark"), (0.75, "belly")]),
    (1.15, (1.15, 0.26, 0.24), [(0.3, "dark"), (0.65, "belly"), (1.0, "dark")]),
]
_a = math.radians(TAIL_RISE)
_dir = (-math.cos(_a), math.sin(_a))  # backward and up
_root = (-1.15, 0.35)
for i, (seglen, size, bands) in enumerate(tail):
    name = f"Tail{i + 1}"
    seg(name, (_root[0], _root[1], 0.0))
    centre = (_root[0] + _dir[0] * (size[0] / 2 - 0.05), _root[1] + _dir[1] * (size[0] / 2 - 0.05), 0.0)
    part(name, "body", size, centre, pitch=-TAIL_RISE)
    for j, (d, key) in enumerate(bands):
        part(name, key, (0.18, size[1] + 0.04, size[2] + 0.04), (_root[0] + _dir[0] * d, _root[1] + _dir[1] * d, 0.0),
             pitch=-TAIL_RISE, name=f"{name}_band{j + 1}")
    _root = (_root[0] + _dir[0] * seglen, _root[1] + _dir[1] * seglen)

# ---------------------------------------------------------------- legs (thigh, shin, metatarsus + toes, sickle claw)
for side in (1, -1):
    s = "L" if side > 0 else "R"
    z = side * 0.55
    hip, knee, ankle, ball = (-0.15, 0.0), (0.3, -1.15), (-0.45, -2.25), (-0.15, -3.1)
    seg(f"Leg{s}", (hip[0], hip[1], z))
    part(f"Leg{s}", "body", (0.62, 1.45, 0.55), ((hip[0] + knee[0]) / 2, (hip[1] + knee[1]) / 2, z),
         pitch=tilt_down(knee[0] - hip[0], knee[1] - hip[1]), name=f"Leg{s}_thigh")
    part(f"Leg{s}", "body", (1.1, 0.85, 0.6), (-0.1, -0.25, z), pitch=10, name=f"Leg{s}_muscle")
    part(f"Leg{s}", "dark", (0.16, 0.85, 0.63), (-0.25, -0.22, z), pitch=10, name=f"Leg{s}_band")
    seg(f"Shin{s}", (knee[0], knee[1], z))
    part(f"Shin{s}", "lower", (0.36, 1.38, 0.38), ((knee[0] + ankle[0]) / 2, (knee[1] + ankle[1]) / 2, z),
         pitch=tilt_down(ankle[0] - knee[0], ankle[1] - knee[1]), name=f"Shin{s}_shin")
    seg(f"Foot{s}", (ankle[0], ankle[1], z))
    part(f"Foot{s}", "lower", (0.3, 0.95, 0.32), ((ankle[0] + ball[0]) / 2, (ankle[1] + ball[1]) / 2, z),
         pitch=tilt_down(ball[0] - ankle[0], ball[1] - ankle[1]), name=f"Foot{s}_meta")
    part(f"Foot{s}", "lower", (0.8, 0.22, 0.42), (0.15, -3.19, z), name=f"Foot{s}_toes")
    for i, dz in enumerate((-0.13, 0.0, 0.13)):
        part(f"Foot{s}", "claw", (0.16, 0.12, 0.08), (0.6, -3.22, z + dz), name=f"Foot{s}_claw{i + 1}")
    part(f"Foot{s}", "claw", (0.09, 0.34, 0.07), (0.07, -2.93, z - side * 0.15), pitch=-35, name=f"Foot{s}_sickle")

JOINTS = [("RootJoint", "HRP", "Torso"), ("Neck", "Torso", "Neck"), ("Head", "Neck", "Head"), ("Jaw", "Head", "Jaw"),
          ("ArmL", "Torso", "ArmL"), ("ArmR", "Torso", "ArmR"), ("Tail1", "Torso", "Tail1"), ("Tail2", "Tail1", "Tail2"),
          ("Tail3", "Tail2", "Tail3"), ("Tail4", "Tail3", "Tail4"), ("Tail5", "Tail4", "Tail5"),
          ("LegL", "Torso", "LegL"), ("LegR", "Torso", "LegR"), ("KneeL", "LegL", "ShinL"), ("KneeR", "LegR", "ShinR"),
          ("AnkleL", "ShinL", "FootL"), ("AnkleR", "ShinR", "FootR")]

# ---------------------------------------------------------------- attributes: the T-Rex's, with raptor overrides
trex = open(TREX).read()
block = trex[trex.index("attributes = {"):]
block = block[:block.index("\n\t},")]
attrs = {}
for m in re.finditer(r'^\t\t(\w+) = (.+?),$', block, re.M):
    attrs[m.group(1)] = m.group(2)
OVERRIDES = {
    "Species": '"Raptor"', "StyleVersion": '"1.0"', "RaptorModelVersion": f'"{VERSION}"',
    "DisplayName": '"Raptor"',
    "MoveWalkSpeed": "30", "MoveRunSpeed": "52", "TurnLimitRate": "540",
    "RoarEnabled": "false", "BiteEnabled": "false", "CreepEnabled": "false",
    "CameraStartZoom": "16", "RigHipHeight": f"{HIP}", "IdleBob": "0.1",
    # gait: short legs at walk 30 / run 52 -> longest clean stride + arcade stride stretch (WalkPose 3.3).
    # Walk is a jog gait (duty 0.38): ~6 steps/s, feet glide ~8.6 studs/s; run ~8 steps/s, glide ~9.4 studs/s.
    "WalkStepLength": "8.5", "WalkDuty": "0.38", "WalkCrouch": "0.8", "WalkLift": "2.2", "WalkStrideStretch": "1.4",
    "RunStepLength": "10.4", "RunDuty": "0.3", "RunCrouch": "1.6", "RunLift": "3", "RunFootForward": "1.6",
    "RunStrideStretch": "1.22", "WalkPoseVersion": '"3.4"',
    # raptor run (user): head dips when sprinting, stiff tail (little swing)
    "RunNeckDrop": "20", "WalkTailWhip": "0.25", "RunTailWhip": "0.15", "IdleTailSway": "0.35",
    # v1.1 leap (user): ~11 studs, 0.12 s crouch, +10 forward when moving, steerable boosted air speed, 15 stamina
    "JumpEnabled": "true", "JumpWindup": "0.12", "JumpLaunchPower": "59", "JumpBoost": "10",
    "JumpBoostMinSpeed": "2", "JumpAirHold": "true", "JumpStaminaCost": "15", "JumpCooldown": "0.5",
    # v1.2 pounce (user): F / X / touch, ~20 studs, 3 s cooldown, 15 stamina + 15/s latched, 8 + 4 every 0.5 s
    "PounceEnabled": "true", "PounceWindup": "0.1", "PounceDistance": "20", "PounceUpSpeed": "28",
    "PounceCooldown": "3", "PounceStaminaCost": "15", "PounceLatchDrain": "15", "PounceLandDamage": "8",
    "PounceTickDamage": "4", "PounceTickInterval": "0.5", "PounceSizeRatio": "1.5", "PounceReach": "1.6",
    "PounceLatchStandoff": "2.4", "PounceLeapOffSpeed": "30", "PounceLeapOffUp": "35", "PounceClaimWindow": "0.9",
    # v1.4 crouch walk (user: must look like a crouch): ~40% lower, ~3 slow deliberate steps/s, level stiff tail
    "CreepCrouch": "4.3", "CreepStepLength": "12", "CreepDuty": "0.65", "CreepStrideStretch": "1.15",
    "CreepLift": "2", "CreepFootForward": "1", "CreepLean": "6", "CreepNeckDrop": "20", "CreepTailDrop": "10",
    "CreepTailWhip": "0.15", "CreepArmTuck": "35",
    # v1.4 strafe side-step reach (WalkPose 3.4): narrow hips need a longer side step than the default 1
    "WalkSideStepReach": "1.6",
}
attrs.update(OVERRIDES)
for k in ("StarterCharacterVersion",):
    attrs.pop(k, None)


def fmt_list(v):
    return "{" + ",".join(f"{x:g}" if isinstance(x, float) else str(x) for x in v) + "}"


lines = []
lines.append(f"-- RaptorModelData v{VERSION} (Dino Arcade) — movie-style raptor (Deinonychus size), T-Rex block style, rig 1.3 joint names.")
lines.append("-- Generated by tools/raptor_generator.py (do not edit by hand; change the generator and re-run).")
lines.append(f"-- Scale: T-Rex 40.1 studs ~ 12.3 m; raptor ~3.9 m -> about 12.85 studs long, hip {HIP} studs.")
lines.append("-- All CFrames are relative to the HumanoidRootPart; sizes in studs; colors hex RGB.")
lines.append("-- Rebuild with DinoModelBuilder.build(require(RaptorModelData)).")
lines.append("return {")
lines.append(f'\tversion = "{VERSION}", species = "Raptor", style = "1.0", rig = "1.3",')
hx, hy, hz = HRP_SIZE_D
lines.append(f'\thrp = {{size = {{{hz},{hy},{hx}}}, color = "A3A2A5", surface = {{"Studs","Inlet","Smooth","Smooth","Smooth","Smooth"}}}},')
lines.append(f'\thumanoid = {{RigType = "R15", HipHeight = {HIP - hy / 2:g}, DisplayDistanceType = "None"}},')
lines.append('\tmodelStreamingMode = "Atomic",')
lines.append("\tsegments = {")
lo = [1e9] * 3
hi = [-1e9] * 3
count = 0
for name in order:
    s = segments[name]
    lines.append(f'\t\t{{name = "{name}", root = {fmt_list(cf(s["root"]))}, parts = {{')
    for p in s["parts"]:
        surface = '"Smooth"' if p["key"] in SMOOTH else '"Studs"'
        lines.append(f'\t\t\t{{name = "{p["name"]}", size = {fmt_list([round(v, 4) for v in p["size"]])}, '
                     f'cf = {fmt_list(cf(p["center"], p["R"]))}, color = "{C[p["key"]]}", surface = {surface}}},')
        count += 1
        # bounds in D space
        hx2, hy2, hz2 = (v / 2 for v in p["size"])
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    w = mv(p["R"], (sx * hx2, sy * hy2, sz * hz2))
                    for i in range(3):
                        lo[i] = min(lo[i], p["center"][i] + w[i])
                        hi[i] = max(hi[i], p["center"][i] + w[i])
    lines.append("\t\t}},")
lines.append("\t},")
lines.append("\tjoints = {")
for jn, p0, p1 in JOINTS:
    if p0 == "HRP":
        c0 = cf((0.0, 0.0, 0.0))
    else:
        a, b = segments[p0]["root"], segments[p1]["root"]
        c0 = [round(b[i] - a[i], 6) + 0.0 for i in range(3)] + [1, 0, 0, 0, 1, 0, 0, 0, 1]
    lines.append(f'\t\t{{name = "{jn}", part0 = "{p0}", part1 = "{p1}", c0 = {fmt_list(c0)}, c1 = {{0,0,0,1,0,0,0,1,0,0,0,1}}}},')
lines.append("\t},")
lines.append("\tattributes = {")
for k in sorted(attrs):
    lines.append(f"\t\t{k} = {attrs[k]},")
lines.append("\t},")
lines.append("}")
open(OUT, "w").write("\n".join(lines) + "\n")
print(f"{count} parts, {len(order)} segments -> {OUT}")
print("D bounds: x %.2f..%.2f (length %.2f)  y %.2f..%.2f (ground at %.2f, height %.2f)  z %.2f..%.2f (width %.2f)" % (
    lo[0], hi[0], hi[0] - lo[0], lo[1], hi[1], -HIP, hi[1] + HIP, lo[2], hi[2], hi[2] - lo[2]))
