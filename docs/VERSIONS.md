# Version log

| Component | Version | What |
|---|---|---|
| T-Rex style | 1.1 (StripeEye) | Preset B cartoon proportions + cream throat→belly stripe + square eye with highlight |
| Rig | 1.3 | 17 joints; knee + ankle joints (legs split thigh / shin / foot); 1.3: thigh + shin 30% longer (hip 9.68 studs up) |
| StarterCharacter | 1.2 | Player copy of the T-Rex; HRP re-aimed to the dino's forward; scripts in StarterCharacterScripts; 1.2: rig 1.3 legs, HipHeight 4.96 |
| IdleAnimation | 1.13 | Client animator: idle + walk/run/creep blend + crouched stance + head turn into turns + roar layer + bite layer (local prediction, hit-stop); running turns no longer speed the legs up; 1.13: tail on its own (half-speed) phase; 1.14: head lead layer (HeadLeadPose) |
| IdlePose | 1.4 | Breathing loop + occasional head turn; 1.4: tail sway on its own 2 s loop (IdleTailPeriod) |
| WalkPose | 3.2 | Distance-driven walk/run/creep, 2-joint knee IK, planted feet, run gait blend, creep blend + crouched stance; 3.2: separate tail phase (WalkTailRate 0.5) |
| BitePose | 1.0 | Quick bite: wind-up 0.15 s (rear + gape) → strike 0.10 s (lunge down, jaws shut) → recover 0.30 s; head thrash on hit |
| TurnPose | 1.0 | Neck + head yaw and tilt into turns while moving (TurnHead* attributes) |
| HeadLeadPose | 1.0 | Neck + head turn toward the input direction before the body (up to 45°, moving and standing; off during roar / bite) |
| TurnLimit | 1.0 | Owner client: body turn capped at TurnLimitRate 180 °/s (AutoRotate off), movement follows the body (wide arcs); input from the Input Action System MoveAction; sends the turn still to go |
| StatusBadges | 1.1 | Every client: badges above a dino while roar-debuffed — blue ▼ DEF (damage taken up), red ▲ SPD (speed up); timer bar + pop on apply/refresh; 1.1: SPD on NPCs too |
| TurnServer | 1.0 | Validates the turn still to go (number, ≤30/s), sets replicated TurnError for other clients' head lead |
| RoarPose | 1.0 | Wind-up → roar (jaw 40°, head shake) → recover, upper body only |
| RoarFX | 1.1 | Sound + forward-shooting sound-wave rings from the mouth + camera shake |
| RoarServer | 1.1 | Validates roar requests, cooldown, server-time stamp; 1.1: roar debuff — 90° cone, RoarRadius 30, timed with the rings: +25% damage taken, +10% speed, 8 s, refresh (no stacking) |
| RoarTest | 1.0 | TEST input: R / gamepad Y / touch button |
| SprintTest | 1.3 | TEST input: hold Shift / L3 / touch button; speed priority roar > run > creep > walk; 1.3: × DebuffSpeedMul while roar-debuffed |
| BiteTest | 1.2 | TEST input: left click / R2 / touch button; 3-stud forward lunge in the strike; local cooldown + prediction; 1.1: hit claim from the animated snout (capsule); 1.2: Bitable dinos via their hitboxes |
| BiteServer | 1.2 | Validates bites (alive, enabled, not roaring, cooldown); 1.1: capsule hit volume along the snout + validated client claims, each bite resolved once; 1.2: Bitable dinos (hitboxes only, 4-stud claim tolerance); 1.3: hit zones (head 1.5×, torso 1×, tail 0.5×) × roar debuff damage taken |
| BiteFX | 1.1 | Chomp sound, flash, brick chunks, popping damage number, target wobble (1.1: yields to server moves), attacker camera punch |
| BiteDummy | 1.0 | TEST training dummy at (0, 0, -45): 200 HP bar, tips over at 0 and resets after 2 s |
| DinoHitboxes | 1.0 | Hitbox per body part on every dino (red = blocks: torso, neck, head, tail; blue = bite-only: jaw, legs, feet, arms); head/jaw end at mid-mouth |
| HitboxView | 1.0 | TEST: H shows/hides hitboxes (+ HumanoidRootPart in yellow) |
| BiteTargetHealth | 1.0 | TEST: health bar + KO/reset for Bitable dinos (display T-Rex: 200 HP, KO 3 s) |
| CreepTest | 1.0 | TEST input: hold C / gamepad B / touch button; run breaks creep |
| CreepServer | 1.0 | Validates creep requests, sets replicated Creeping (no stealth effect yet) |
| CameraZoom | 1.0 | Camera starts 35 studs out (3rd person) on every spawn; scroll still zooms |
| WalkTest | 1.3 | TEST mover for the display dino (walk 40, turn, back); 1.2: shared server clock (instances WalkTest = Client, WalkTestServer = Server), stops + rolls onto its side when knocked out; 1.3: clock runs at DebuffSpeedMul while roar-debuffed (re-anchored, no jump) |
| Roar sound | 1.0 | TRex_Roar_v1.0.mp3 (0.40–1.52 s of the supplied clip), asset 105842146042073 |
| TRexModelData | 1.9 | Snapshot of the player T-Rex, rebuilt exactly by DinoModelBuilder 1.0 (1.1 creep, 1.2 rig 1.3 legs + camera, 1.3 bite, 1.4 run 34 + turn head + bite reach-back, 1.5 half-speed tail + versions, 1.6 walk 20 / run 44 + TurnLimit* / HeadLead* + versions, 1.7 HitZone* + RoarConeAngle / RoarDebuff* + versions, 1.8 StatusBadgesVersion, 1.9 StatusBadges 1.1) |

The Workspace display dino (TRex_v1.1_StripeEye) is rig 1.3 too: legs copied from the StarterCharacter
(relative to the Torso Root, max error 0.000008) and the model raised 2.0265 studs so the feet stay on the ground.

## Open decisions
- Skill points per level-up.
- Per-class walk/run speeds (current 16 / 28 are test values).
- Roar of Terror effect area: forward cone (matches the waves) or circle.
- Stamina for sprinting.
- Creep gameplay effect (stealth / detection radius).
- Bite: damage to players / health system, stamina cost, final chomp sound (current BiteSoundId 108790087307118 is a Creator Store placeholder).
