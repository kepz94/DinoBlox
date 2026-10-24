# Raptor style spec — Version 1.0, rig 1.3 joint names

Movie-style raptor (*Deinonychus* size) in the T-Rex block style (see `STYLE_TRex.md`). Source of truth is
`tools/raptor_generator.py`, which writes `src/shared/Models/RaptorModelData.luau` (do not edit the data by hand).

## Scale (proportional to the T-Rex)
- T-Rex: 40.1 studs long, hip 9.68, about 12.3 m → about 3.26 studs per metre.
- Raptor: about 3.9 m → **12.7 studs long**, **hip 3.3**, head top 5.4, width 1.7. Its head reaches about the T-Rex's knee.

## Look (from the user's reference picture)
- Green body with dark bands across the back, cream belly and throat, teal stripe behind the yellow eye
  (black slit pupil), long low snout with teeth top and bottom (jaw open 14° at rest).
- Long arms hanging forward with three dark claws; olive digitigrade legs (thigh, shin, metatarsus + toes),
  three toe claws and the raised **sickle claw** on the inner toe.
- **Tail:** long, straight and stiff, rising 12° from the hips (`TAIL_RISE`), banded dark/cream towards the tip.
- Plain Roblox Parts, studs on body faces; eyes, teeth, claws and mouth smooth.

## Palette
| Use | Hex |
|---|---|
| Body | `5E943E` |
| Dark bands | `283A1E` |
| Belly / throat / tail bands | `C9C98F` |
| Face stripe | `2E8C82` |
| Lower legs, feet, hands | `8FA046` |
| Mouth | `963C3C` |
| Teeth | `E8E2D2` |
| Claws | `302824` |
| Eye / pupil | `F0C81E` / `111111` |

## Rig
Same 17 Motor6D names as the T-Rex (`RootJoint`, `Neck`, `Head`, `Jaw`, `ArmL/R`, `Tail1–5`, `LegL/R`,
`KneeL/R`, `AnkleL/R`), all C0 rotations identity (world-aligned frames, tilts baked into the parts), so
IdleAnimation / WalkPose / TurnPose / HeadLeadPose / DinoHitboxes / StaminaServer work unchanged.
HRP 1.4 × 2.4 × 3.6, Humanoid HipHeight 2.1, `Head_mouth` present (bite / roar code finds it).

## Raptor settings (model attributes)
- Speeds: walk 30, run 52; TurnLimitRate 540 (90° in 0.17 s); CameraStartZoom 16; IdleBob 0.1.
- Roar, bite and creep are **off** (RoarEnabled / BiteEnabled / CreepEnabled = false) until its own moves are designed.
- Gait (WalkPose 3.3): walk is a jog gait — WalkStepLength 8.5, WalkDuty 0.38, WalkCrouch 0.8, WalkLift 2.2,
  WalkStrideStretch 1.4; run — RunStepLength 10.4, RunDuty 0.3, RunCrouch 1.6, RunLift 3, RunFootForward 1.6,
  RunStrideStretch 1.22. About 6.7 steps/s at walk 30 and 8.1 at run 52 (feet glide a little: arcade stride stretch).
- Run look: RunNeckDrop 20 (head dips when sprinting); stiff tail: WalkTailWhip 0.25, RunTailWhip 0.15, IdleTailSway 0.35.
- All other values are the T-Rex's (copied by the generator).
