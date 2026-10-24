# Character attributes

**Where to change them:** in Studio, select `StarterPlayer > StarterCharacter` and scroll the Properties panel
to **Attributes** (values there apply to every new spawn). While playing, select your character model under
`Workspace` (your player name) to change them live for that session only.

All tuning lives in attributes on the character model (`StarterPlayer.StarterCharacter`), so values can be
changed in Studio's Properties panel without touching code. Defaults below are the current values.

## Movement (test values — SRD speeds not decided yet)
| Attribute | Value | Meaning |
|---|---|---|
| MoveWalkSpeed | 20 | Walk speed (studs/s) (was 16) |
| MoveRunSpeed | 44 | Run speed while Shift is held (was 34, before that 28) |
| MoveRoarSpeed | 4 | Speed while roaring |
| MoveCreepSpeed | 10 | Speed while C is held (creep) |

Speed priority (SprintTest 1.2): roar > run > creep > walk. SprintTest 1.4: roar > exhausted (creep speed) > run > creep > walk.

## Stamina (StaminaServer 1.1 / StaminaBar 1.0)
| Attribute | Value | Meaning |
|---|---|---|
| StaminaEnabled | true | false = always full, never exhausted |
| StaminaMax | 100 | Full bar |
| StaminaRunTime | 15 | Seconds of running from full to empty |
| StaminaRefillTime | 5 | Seconds to refill from empty |
| StaminaBiteCost | 10 | Stamina per accepted bite (bites are never blocked; clamped at 0) |
| StaminaRegenDelay | 0.75 | Seconds after the last run, bite or leap before refilling starts |
| StaminaRecoverFraction | 0.25 | Exhausted until the bar refills to this share (25%) |
| StaminaTiredBiteMul | 0.6 | Damage × for a bite started while exhausted (BiteServer 1.4, every target incl. the dummy): torso 15, head 23, tail 8 |

Drains only while the dino really runs (run key held, not exhausted, horizontal speed above halfway between walk and run speed).
At 0: `Exhausted` = true → creep crouch (CreepServer 1.1) at MoveCreepSpeed, no running (SprintTest 1.4), red pulsing bar.
Curve (replicated): `StaminaValue`, `StaminaRate` (per s), `StaminaAt` (server time); stamina = clamp(Value + Rate × (now − At), 0, Max).
Diagnostics: server `StaminaState` (full/running/delay/refilling/exhausted/disabled), `StaminaLastEvent`, `StaminaRunWanted`,
`StaminaBiteCount`, `StaminaJumpCount` (1.1), `StaminaExhaustCount`, `Exhausted`, `CreepWanted`; client `StaminaBarState` (waiting/normal/low/exhausted), `StaminaShown`.

## Camera (CameraZoom)
| Attribute | Value | Meaning |
|---|---|---|
| CameraStartZoom | 35 | Camera distance (studs) set on every spawn; scroll / pinch still zooms |

## Idle (IdlePose)
| Attribute | Value | Meaning |
|---|---|---|
| IdleEnabled | true | Animation on/off |
| IdlePeriod | 1.0 | Seconds per breathing loop |
| IdleBob | 0.3 | Body dip (studs) |
| IdleHead | 1.0 | Head/jaw motion multiplier |
| IdleTailSway | 1.0 | Tail sway multiplier |
| IdleTailPeriod | 2.0 | Seconds per idle tail sway loop (was tied to the 1 s breath) |
| IdleLookEnabled | true | Occasional head turn |
| IdleLookAngle | 30 | Head turn (degrees) |
| IdleLookMinGap / MaxGap | 3 / 7 | Random wait between turns (s) |
| IdleLookHold | 1.2 | Time held to the side (s) |

## Walk / Run (WalkPose) — every Walk* has a Run* twin; speed blends between them
| Walk | Run | Meaning |
|---|---|---|
| WalkStepLength 6 | RunStepLength 6.5 (default) | Distance a planted foot travels per step |
| WalkDuty 0.6 | **RunDuty 0.48** | Share of the cycle each foot is planted (higher = heavier) |
| WalkLift 1.6 | RunLift 2.4 | Foot lift (studs) |
| WalkCrouch 0.5 | RunCrouch 1.0 | Knee bend / body lowered |
| WalkFootForward 1.2 | RunFootForward 1.6 | Foot path shifted forward |
| WalkToeDrop 25 | RunToeDrop 35 | Toes pointing down mid-swing (°) |
| WalkSway 1.0 | RunSway 0.6 | Body side roll/yaw |
| WalkBounce 0.35 | **RunBounce 0.3** | Body spring |
| WalkBodyRock 4 | RunBodyRock 6 | Forward/back pitch per step (°) |
| WalkHeadBob 6 | RunHeadBob 8 | Neck/head nod (°) |
| WalkTailWhip 1.0 | RunTailWhip 0.7 | Tail swing + whip |
| WalkArmSwing 25 | RunArmSwing 10 | Arm swing (°) |
| — | **RunLean 11** | Forward lean while running (°) |
| — | RunArmTuck 35 | Arms folded while running (°) |
| WalkTailRate 0.5 | — | Tail swing speed while moving, as a share of the step rate (all gaits) |

Bold = "heavier, more powerful T-Rex" preset (set on the character). `WalkLegSwing` is unused since WalkPose v2.0.

## Creep (WalkPose 3.1 / CreepTest / CreepServer) — every gait value above also has a Creep* twin
| Attribute | Value | Meaning |
|---|---|---|
| CreepEnabled | true | Creep allowed (server-checked) |
| CreepStepLength | 5.5 | Step length while creeping |
| CreepDuty | 0.7 | Feet planted most of the cycle (careful steps) |
| CreepLift | 1.3 | Foot lift |
| CreepCrouch | 2.2 | Body lowered (studs) |
| CreepFootForward | 1.4 | Foot path shifted forward |
| CreepToeDrop | 15 | Toes down mid-swing (°) |
| CreepSway | 0.3 | Body side roll/yaw |
| CreepBounce | 0.05 | Body spring |
| CreepBodyRock | 1.5 | Forward/back pitch per step (°) |
| CreepHeadBob | 1.5 | Neck/head nod (°) |
| CreepTailWhip | 0.35 | Tail swing + whip |
| CreepArmSwing | 5 | Arm swing (°) |
| CreepLean | 5 | Body pitched nose-down (°) |
| CreepArmTuck | 20 | Arms folded (°) |
| CreepNeckDrop | 28 | Neck lowered (°); head tilts back 60% of it so the snout points ahead |
| CreepTailDrop | 6 | Tail held lower (°) |

## Roar (RoarPose / RoarFX / RoarServer)
| Attribute | Value | Meaning |
|---|---|---|
| RoarEnabled | true | Roar allowed |
| RoarDuration | 1.4 | Whole roar (s) |
| RoarCooldown | 3 | Seconds between roars (server-checked) |
| RoarRadius | 30 | How far the sound waves travel (studs) |
| RoarWaveSize | 18 | Wave diameter at full reach (studs) |
| RoarJawOpen | 40 | Jaw opening (°) |
| RoarShake | 2.5 | Head shake (°) |
| RoarShakeCamera | 0.35 | Camera shake for players inside the radius |
| RoarSoundId | rbxassetid://105842146042073 | Roar audio (TRex_Roar_v1.0.mp3) |
| RoarDebuffEnabled | true | Roar debuff on (RoarServer 1.1) |
| RoarConeAngle | 90 | Roar hit cone in front of the mouth (°; 45 each side); range = RoarRadius |
| RoarDebuffDuration | 8 | Seconds the debuff lasts; a new roar hit refreshes it (no stacking) |
| RoarDebuffDamageTaken | 1.25 | Damage taken while debuffed (×; +25%) |
| RoarDebuffSpeed | 1.1 | Move speed while debuffed (×; +10%; players via SprintTest, the display T-Rex via WalkTest 1.3) |

Roar debuff: a dino (Species attribute; not the roarer, not the dummy) is hit when it is within RoarRadius of the mouth front,
inside the cone, and a ring is passing it (rings stream out from 20% to 80% of the roar and fly 30 studs in 0.75 s).
Target state (replicated): `DebuffUntil` (server time), `DebuffDamageTakenMul`, `DebuffSpeedMul`, `DebuffBy`, `DebuffSource` (roar),
`DebuffCount`, `DebuffState` (roared/none). Roarer diagnostics: `RoarEffectState` (sweeping/done/disabled), `RoarHits`, `RoarHitNames`.
Speed: SprintTest 1.3 multiplies the chosen speed by `DebuffSpeedMul` while debuffed (`MoveSpeedMul` diagnostic). The display T-Rex
(WalkTest 1.3) runs its walk clock at `DebuffSpeedMul` (`WalkTestClockRate` diagnostic), so its walk, turns and pauses run 10% faster.
Badges (StatusBadges 1.0, every client): above the dino while `DebuffUntil` is in the future — blue `▼ DEF` when `DebuffDamageTakenMul` > 1,
red `▲ SPD` when `DebuffSpeedMul` > 1 (players and NPCs, StatusBadges 1.1); a timer bar empties over the effect and the badge pops on apply/refresh.
Diagnostics (client): `StatusBadgesState` (none/def/spd/def,spd), `StatusBadgesVersion`.

## Bite (BitePose / BiteTest / BiteServer / BiteFX)
| Attribute | Value | Meaning |
|---|---|---|
| BiteEnabled | true | Bite allowed (client + server checked) |
| BiteWindup | 0.15 | Seconds: neck rears up, jaw gapes |
| BiteStrike | 0.10 | Seconds: neck drives forward/down, jaws shut (contact at the end) |
| BiteRecover | 0.30 | Seconds back to the base pose (head thrash on a hit) |
| BiteJawOpen | 45 | Jaw gape (°) |
| BiteRear | 14 | Neck rear-up in the wind-up (°) |
| BiteLunge | 20 | Neck drive-down at the strike (°) |
| BiteReach | 1.2 | Neck slides forward at the strike (studs) |
| BiteShake | 14 | Head thrash after a hit (°) |
| BiteShakeTime | 0.30 | Thrash length (s) |
| BiteHitStop | 0.06 | Pose freeze on a hit (s) |
| BiteCooldown | 0.8 | Seconds between bites (server-checked) |
| BiteDamage | 25 | Damage per bite (dummies only for now) |
| BiteRange | 5 | Hit capsule radius (studs); the capsule line runs from BiteReachBack behind the mouth front to BiteRange/2 ahead |
| BiteReachBack | 8 | Studs the hit capsule reaches back along the snout (targets the head has pushed into still count) |
| BiteLungeDist | 3 | Forward push during the strike (studs) |
| BiteSoundId | rbxassetid://108790087307118 | Chomp sound (Creator Store placeholder) |

## Hit zones (BiteServer 1.3) — read from the bitten dino
| Attribute | Value | Zone (hitbox segments) |
|---|---|---|
| HitZoneHeadMul | 1.5 | head: Head, Jaw, Neck (25 → 38) |
| HitZoneTorsoMul | 1 | torso: Torso, legs, shins, feet, arms (25) |
| HitZoneTailMul | 0.5 | tail: Tail1–5 (25 → 13) |

Damage = round(BiteDamage × zone × debuff). Zone = the target hitbox nearest the bite tip (server check) or nearest the claimed point
(client claim). The training dummy has no zones and no debuff (always BiteDamage). Debuffed: torso 31, head 47, tail 16.
Diagnostics (attacker): `BiteHitZone` (head/torso/tail/dummy), `BiteHitSegment`, `BiteHitZoneMul`, `BiteHitDebuffMul`, `BiteHitBaseDamage`;
`BiteHitDamage` = final damage. BiteServer 1.4 adds `BiteHitTiredMul` (1, or 0.6 for an exhausted bite).

Bite diagnostics: client `BiteState` (none/windup/strike/recover, `-hit`), `BiteSource` (server/predicted),
`BiteInputResult`, `BiteLungeMoved`, `BiteClaim` (sent/none), `BiteFXHits`, `BiteSoundLoaded`, `BitePredictedAt`; server `BiteStartedAt`,
`BiteCount`, `BiteLastResult` (ok/cooldown/roaring/disabled/dead/badArg), `BiteLastContact` (hit/miss), `BiteStartLag`,
`BiteHitSource` (client/server), `BiteClaimResult` (ok/noBite/stale/resolved/late/badTarget/offTarget/far/badArg), `BiteClaimDist`,
`BiteHitAt`, `BiteHitPos`, `BiteHitDamage`, `BiteHitTarget`, `BiteHitCount`. Dummy: `DummyHealth`, `DummyMaxHealth`,
`DummyState` (ready/ko), `DummyKOs`.

## Species (SpeciesServer 1.0 / SpeciesPicker 1.0) and the Raptor
The raptor's own values live in `RaptorModelData` (see `docs/STYLE_Raptor.md`): walk 30, run 52, TurnLimitRate 540,
CameraStartZoom 16, roar / bite / creep off, its gait values and RunNeckDrop 20.
WalkPose 3.3 settings (defaults keep the T-Rex unchanged):

| Attribute | Default | Meaning |
|---|---|---|
| WalkStrideStretch / RunStrideStretch / CreepStrideStretch | 1 | × ground covered per gait cycle: > 1 = fewer steps, planted feet glide by (1 − 1/stretch) of the speed |
| RunNeckDrop | 0 | Degrees the neck lowers at full run (head dips when sprinting) |

Diagnostics: player `DinoSpecies`, `SpeciesLastResult` (ok/same/badArg/cooldown/noTemplate); SpeciesServer script attribute
`SpeciesTemplate` (ready/missing); client `SpeciesPickerState`, `SpeciesPickerLast`.

## Leap (JumpTest 1.0 / JumpServer 1.0 / JumpPose 1.0 / StaminaServer 1.1)
Only dinos with `JumpEnabled = true` (the Raptor) use it; the T-Rex keeps the default Roblox jump.
Press jump → 0.12 s crouch → launch 11 studs high (JumpPower 59, measured 11.0 studs and 0.67 s in the air; the Humanoid's
floor push adds speed during liftoff, so the height is above JumpPower² / 2g).
If moving faster than 2 studs/s at takeoff, +10 studs/s along the body's forward. While move input is held in the
air, the boosted speed is kept (a client-side LinearVelocity constraint in Plane mode holds the horizontal velocity;
Humanoid.WalkSpeed is not touched) and the leap steers at the body's turn rate; no input = Roblox air control.
Measured (raptor, open ground): standing leap 11.0 studs / 0.67 s; running leap takeoff 52 → 62 held to landing,
41.1 studs long; W+A mid-air turns the path 45°; releasing input slows 62 → 3 in 0.35 s; held key = 7 leaps from full
stamina, then "stamina".
Holding the key re-leaps on landing. Each accepted leap costs 15 stamina; no leap while exhausted or below 15.

| Attribute | Raptor value (default) | Meaning |
|---|---|---|
| JumpEnabled | true (false) | Leap instead of the default jump |
| JumpWindup | 0.12 | Crouch seconds before the launch |
| JumpLaunchPower | 59 | Humanoid.JumpPower at the launch (59 → 11.0 studs measured) |
| JumpBoost | 10 | Forward studs/s added at takeoff |
| JumpBoostMinSpeed | 2 | Horizontal studs/s needed at takeoff for the boost |
| JumpAirHold | true | Keep the leap speed in the air while input is held (steerable) |
| JumpStaminaCost | 15 | Stamina per accepted leap; also the minimum needed to leap |
| JumpCooldown | 0.5 | Seconds between accepted leaps (server and client) |

JumpPose 1.0 shape values (defaults; studs × geo.scale, foot targets as shares of leg reach): `JumpPoseEnabled` true;
crouch `JumpCrouch` 3, `JumpCrouchLean` 12, `JumpCrouchNeck` 18, `JumpCrouchTail` 10, `JumpCrouchArms` 25; push
`JumpPushBack` 22, `JumpPushExtend` 0.97, `JumpPushToe` 45, `JumpLaunchPitch` 14, `JumpPushTime` 0.15; tuck
`JumpTuckFwd` 0.14, `JumpTuckDown` 0.5, `JumpTuckToe` 30, `JumpAirTail` 10, `JumpAirArms` 35, `JumpAirPitch` 10,
`JumpAirNeck` 10; reach `JumpReachFwd` 0.24, `JumpReachDown` 0.84, `JumpReachToe` −10; land `JumpLandTime` 0.22,
`JumpLandCrouch` 2.5, `JumpLandLean` 8, `JumpLandNeck` 12, `JumpLandTail` 8.

Diagnostics: owner client `JumpTestState` (disabled/ready/crouch/air/dead), `JumpInputResult`
(sent/air/exhausted/stamina/cooldown/dead/denied/noLiftoff), `JumpInputSource` (inputAction/humanoid), `JumpPredictedAt`,
`JumpLaunchCount`, `JumpTakeoffSpeed`, `JumpBoostApplied`, `JumpLeapSpeed`, `JumpAirSpeed`, `JumpPeakHeight`, `JumpAirTime`,
`JumpAirHoldState` (off/holding/released), `JumpAirDistance`.
Server (replicated): `JumpStartedAt`, `JumpServerResult` (ok/badArg/dead/disabled/exhausted/stamina/cooldown), `JumpCount`,
`JumpDenyCount`, `JumpDeniedAt`, `JumpDenyReason`. Every client (jump-enabled dinos): `JumpState`
(none/crouch/push/rise/fall/land), `JumpBlend`, `JumpSource` (server/predicted), `JumpGroundDist`.

## Turning (TurnPose)
| Attribute | Value | Meaning |
|---|---|---|
| TurnHeadEnabled | true | Head leans into turns while moving |
| TurnHeadMax | 20 | Most head yaw into a turn (°) |
| TurnHeadGain | 0.06 | Head yaw (°) per °/s of turning |
| TurnHeadRoll | 0.4 | Head tilt into the turn, as a share of the yaw |
| TurnHeadSmooth | 8 | How fast the turn rate is followed (per second) |

Diagnostics: `TurnRate` (°/s, positive = left), `TurnHead` (°).

## Heavy turning (TurnLimit 1.0) and head lead (HeadLeadPose 1.0)
The body turns toward the move input at most `TurnLimitRate` °/s (Humanoid.AutoRotate is off while this runs) and
moves where the body faces, so sharp turns swing wide (radius = speed / turn rate: walk 20 ≈ 6.4 studs, run 44 ≈ 14 studs).
The neck and head turn toward the input direction first (the turn still to go, clamped), moving or standing;
the lead fades out during the roar and the bite.

| Attribute | Value | Meaning |
|---|---|---|
| TurnLimitEnabled | true | false = Roblox's own turning (AutoRotate) again |
| TurnLimitRate | 180 | Most body turn (°/s); 180 = a 90° turn in 0.5 s |
| HeadLeadEnabled | true | Head turns into the turn before the body |
| HeadLeadMax | 45 | Most neck + head lead (°) |
| HeadLeadSmooth | 10 | How fast the head follows (per second) |
| HeadLeadNeckShare | 0.45 | Share of the lead on the neck (rest on the head) |

Diagnostics, owner client: `TurnLimitState` (disabled/noControls/dead/holding/turning/aligned), `TurnInputSource`
(inputAction/controlModule/none), `TurnBodyYaw`, `TurnTargetYaw`, `TurnErrorLocal` (° still to turn, positive = left),
`TurnErrorSent`, `TurnRemote` (ok/missing). Server (replicated): `TurnError`, `TurnErrorLastResult`
(ok/badArg/rateLimited/dead). Every client: `HeadLead` (°), `HeadLeadSource` (local/server/none),
`HeadLeadState` (off/none/leading/suppressed).

## Hitboxes (DinoHitboxes) and bitable dinos
Every dino gets a `Hitboxes` folder: one box per body part, welded to the part so it follows the animation.
Red (blocks, CanCollide): Torso, Neck, Head, Tail1-5. Blue (bite-only): Jaw, legs, feet, arms. Head and Jaw
boxes end at the middle of the mouth, so only the front half of the jaws can sink into things.
Press **H** in Play to show/hide them (HumanoidRootPart shown in yellow).

| Attribute (on a display dino) | Value | Meaning |
|---|---|---|
| Bitable | true | Can be bitten (only its hitboxes count) |
| DummyMaxHealth | 200 | Health; DummyHealth / DummyState (ready/ko) / DummyKOs are runtime |
| DisplayName | Display T-Rex | Name over its health bar |

## Diagnostics (set at runtime, client-side)
`IdleState`, `IdleJointCount`, `IdleLookState`, `MoveState` (idle/walking/running/creeping/crouched), `MoveSpeed`, `WalkBlend`,
`GaitBlend`, `WalkState`, `RigLegLength`, `RigHeelX`, `RigToeX`, `RigFootToe`, `RigAnkleHeight`, `RoarState`,
`Roaring`, `Sprinting`, `MoveSpeedSource` (roar/run/creep/walk), `CreepBlend`, `CreepInput`, `CreepRequested`,
`RoarFXCount`, `RoarRingsShot`, `RoarSoundLoaded`, `CameraZoomState` (zooming/set/timeout). Server: `RoarStartedAt`, `RoarCount`,
`RoarLastResult`, `Creeping`, `CreepLastResult` (on/off/disabled/dead/badArg).
