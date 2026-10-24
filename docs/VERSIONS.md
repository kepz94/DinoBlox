# Version log

| Component | Version | What |
|---|---|---|
| T-Rex style | 1.1 (StripeEye) | Preset B cartoon proportions + cream throat→belly stripe + square eye with highlight |
| Rig | 1.2 | 17 joints; knee + ankle joints added (legs split thigh / shin / foot) |
| StarterCharacter | 1.1 | Player copy of the T-Rex; HRP re-aimed to the dino's forward; scripts in StarterCharacterScripts |
| IdleAnimation | 1.9 | Client animator: idle + walk/run blend + roar layer; joints picked up as they stream in |
| IdlePose | 1.3 | Breathing loop + occasional head turn |
| WalkPose | 3.0 | Distance-driven walk/run, 2-joint knee IK, planted feet, run gait blend |
| RoarPose | 1.0 | Wind-up → roar (jaw 40°, head shake) → recover, upper body only |
| RoarFX | 1.1 | Sound + forward-shooting sound-wave rings from the mouth + camera shake |
| RoarServer | 1.0 | Validates roar requests, cooldown, server-time stamp (no gameplay effect yet) |
| RoarTest | 1.0 | TEST input: R / gamepad Y / touch button |
| SprintTest | 1.1 | TEST input: hold Shift / L3 / touch button; roar slow |
| WalkTest | 1.1 | TEST mover for the display dino (walk 40, turn, back) |
| Roar sound | 1.0 | TRex_Roar_v1.0.mp3 (0.40–1.52 s of the supplied clip), asset 105842146042073 |
| TRexModelData | 1.0 | Snapshot of the player T-Rex, rebuilt exactly by DinoModelBuilder 1.0 |

## Open decisions
- Skill points per level-up.
- Per-class walk/run speeds (current 16 / 28 are test values).
- Roar of Terror effect area: forward cone (matches the waves) or circle.
- Stamina for sprinting.
