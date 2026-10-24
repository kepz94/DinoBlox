# Version log

| Component | Version | What |
|---|---|---|
| T-Rex style | 1.1 (StripeEye) | Preset B cartoon proportions + cream throat→belly stripe + square eye with highlight |
| Rig | 1.3 | 17 joints; knee + ankle joints (legs split thigh / shin / foot); 1.3: thigh + shin 30% longer (hip 9.68 studs up) |
| StarterCharacter | 1.2 | Player copy of the T-Rex; HRP re-aimed to the dino's forward; scripts in StarterCharacterScripts; 1.2: rig 1.3 legs, HipHeight 4.96 |
| IdleAnimation | 1.10 | Client animator: idle + walk/run/creep blend + crouched stance + roar layer; joints picked up as they stream in |
| IdlePose | 1.3 | Breathing loop + occasional head turn |
| WalkPose | 3.1 | Distance-driven walk/run/creep, 2-joint knee IK, planted feet, run gait blend, creep blend + crouched stance |
| RoarPose | 1.0 | Wind-up → roar (jaw 40°, head shake) → recover, upper body only |
| RoarFX | 1.1 | Sound + forward-shooting sound-wave rings from the mouth + camera shake |
| RoarServer | 1.0 | Validates roar requests, cooldown, server-time stamp (no gameplay effect yet) |
| RoarTest | 1.0 | TEST input: R / gamepad Y / touch button |
| SprintTest | 1.2 | TEST input: hold Shift / L3 / touch button; speed priority roar > run > creep > walk |
| CreepTest | 1.0 | TEST input: hold C / gamepad B / touch button; run breaks creep |
| CreepServer | 1.0 | Validates creep requests, sets replicated Creeping (no stealth effect yet) |
| CameraZoom | 1.0 | Camera starts 35 studs out (3rd person) on every spawn; scroll still zooms |
| WalkTest | 1.1 | TEST mover for the display dino (walk 40, turn, back) |
| Roar sound | 1.0 | TRex_Roar_v1.0.mp3 (0.40–1.52 s of the supplied clip), asset 105842146042073 |
| TRexModelData | 1.2 | Snapshot of the player T-Rex, rebuilt exactly by DinoModelBuilder 1.0 (1.1 creep attributes, 1.2 rig 1.3 legs + camera) |

The Workspace display dino (TRex_v1.1_StripeEye) is rig 1.3 too: legs copied from the StarterCharacter
(relative to the Torso Root, max error 0.000008) and the model raised 2.0265 studs so the feet stay on the ground.

## Open decisions
- Skill points per level-up.
- Per-class walk/run speeds (current 16 / 28 are test values).
- Roar of Terror effect area: forward cone (matches the waves) or circle.
- Stamina for sprinting.
- Creep gameplay effect (stealth / detection radius).
