# Version log

| Component | Version | What |
|---|---|---|
| T-Rex style | 1.1 (StripeEye) | Preset B cartoon proportions + cream throat→belly stripe + square eye with highlight |
| Rig | 1.3 | 17 joints; knee + ankle joints (legs split thigh / shin / foot); 1.3: thigh + shin 30% longer (hip 9.68 studs up) |
| StarterCharacter | 1.2 | Player copy of the T-Rex; HRP re-aimed to the dino's forward; scripts in StarterCharacterScripts; 1.2: rig 1.3 legs, HipHeight 4.96 |
| IdleAnimation | 1.12 | Client animator: idle + walk/run/creep blend + crouched stance + head turn into turns + roar layer + bite layer (local prediction, hit-stop); running turns no longer speed the legs up |
| IdlePose | 1.3 | Breathing loop + occasional head turn |
| WalkPose | 3.1 | Distance-driven walk/run/creep, 2-joint knee IK, planted feet, run gait blend, creep blend + crouched stance |
| BitePose | 1.0 | Quick bite: wind-up 0.15 s (rear + gape) → strike 0.10 s (lunge down, jaws shut) → recover 0.30 s; head thrash on hit |
| TurnPose | 1.0 | Neck + head yaw and tilt into turns while moving (TurnHead* attributes) |
| RoarPose | 1.0 | Wind-up → roar (jaw 40°, head shake) → recover, upper body only |
| RoarFX | 1.1 | Sound + forward-shooting sound-wave rings from the mouth + camera shake |
| RoarServer | 1.0 | Validates roar requests, cooldown, server-time stamp (no gameplay effect yet) |
| RoarTest | 1.0 | TEST input: R / gamepad Y / touch button |
| SprintTest | 1.2 | TEST input: hold Shift / L3 / touch button; speed priority roar > run > creep > walk |
| BiteTest | 1.1 | TEST input: left click / R2 / touch button; 3-stud forward lunge in the strike; local cooldown + prediction; 1.1: hit claim from the animated snout (capsule) |
| BiteServer | 1.1 | Validates bites (alive, enabled, not roaring, cooldown); 1.1: capsule hit volume along the snout + validated client claims, each bite resolved once; damages dummies only |
| BiteFX | 1.1 | Chomp sound, flash, brick chunks, popping damage number, target wobble (1.1: yields to server moves), attacker camera punch |
| BiteDummy | 1.0 | TEST training dummy at (0, 0, -45): 200 HP bar, tips over at 0 and resets after 2 s |
| CreepTest | 1.0 | TEST input: hold C / gamepad B / touch button; run breaks creep |
| CreepServer | 1.0 | Validates creep requests, sets replicated Creeping (no stealth effect yet) |
| CameraZoom | 1.0 | Camera starts 35 studs out (3rd person) on every spawn; scroll still zooms |
| WalkTest | 1.1 | TEST mover for the display dino (walk 40, turn, back) |
| Roar sound | 1.0 | TRex_Roar_v1.0.mp3 (0.40–1.52 s of the supplied clip), asset 105842146042073 |
| TRexModelData | 1.4 | Snapshot of the player T-Rex, rebuilt exactly by DinoModelBuilder 1.0 (1.1 creep, 1.2 rig 1.3 legs + camera, 1.3 bite, 1.4 run 34 + turn head + bite reach-back) |

The Workspace display dino (TRex_v1.1_StripeEye) is rig 1.3 too: legs copied from the StarterCharacter
(relative to the Torso Root, max error 0.000008) and the model raised 2.0265 studs so the feet stay on the ground.

## Open decisions
- Skill points per level-up.
- Per-class walk/run speeds (current 16 / 28 are test values).
- Roar of Terror effect area: forward cone (matches the waves) or circle.
- Stamina for sprinting.
- Creep gameplay effect (stealth / detection radius).
- Bite: damage to players / health system, stamina cost, final chomp sound (current BiteSoundId 108790087307118 is a Creator Store placeholder).
