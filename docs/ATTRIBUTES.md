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

Pounce-only stamina (StaminaServer 1.4 / StaminaBar 1.1; TRexModelData 1.22 / RaptorModelData 1.12): `StaminaPounceOnly` = true →
no run drain, never `Exhausted`; costs `StaminaBiteCost` 0, `JumpStaminaCost` 0, `RamStaminaCost` 0; `PounceStaminaCost` 15 and
`PounceLatchDrain` 15/s unchanged (a latch / pin starts at 85 and releases at 0 after about 5.7 s); refill hidden at the normal rate.
The bar shows only while `PounceLatched` (latch or pin); client `StaminaBarState` adds "ground" (hidden on the ground) and
"disabled" (StaminaEnabled false). Verified in Play: pin → bar 85 → 0 in 5.69 s, release "stamina", bar hidden after; three T-Rex
bites left stamina at 100.

## Kill regen (KillRegenServer 1.0 / BiteServer 1.6 / PounceServer 1.3)
| Attribute (character) | Value | Meaning |
|---|---|---|
| KillRegenEnabled | true | Heal after a kill |
| KillRegenFraction | 0.25 | Share of MaxHealth given back per kill (T-Rex 50, raptor 15) |
| KillRegenTime | 5 | Seconds the heal is spread over (evenly, capped at MaxHealth; each kill stacks its own stream) |

Kill = the killing blow on a bot (`IsBot`): the bite or pounce hit that takes `DummyHealth` from above 0 to 0 stamps the bot with
`KilledBy` (player name), `KilledByUserId`, `KilledWith` ("bite" / "pounce") and, last, `KilledAt`; the bot gets
`KillRegenCredited` (player name / "noPlayer" / "dead" / "disabled").
Diagnostics: character `KillCount`, `LastKillTarget`, `LastKillWith`, `KillRegenActive`, `KillRegenRemaining`, `KillRegenLastAmount`,
`KillRegenLastAt`, `KillRegenHealed` (+ `KillRegenHealedExact`); player `DinoKills`; script `KillRegenServerVersion`, `KillRegenKills`.
Verified in Play: T-Rex bite kill 100 → 150; raptor pin kill 30 → 45 in a straight line over 5.00 s.

## Hunger and thirst (SurvivalServer 1.0 / SurvivalBars 1.0)
Modelled on The Isle (Evrima): two meters that drain over time; an empty meter damages health until the dino eats /
drinks or dies. No link to stamina; no passive regen (KillRegenServer 1.0 unchanged).

| Attribute (character) | Value | Meaning |
|---|---|---|
| SurvivalEnabled | true | Meters run; false = frozen, HUD hidden, E not taken |
| HungerMax / ThirstMax | 100 / 100 | Meter size (both species) |
| HungerDrainTime / ThirstDrainTime | 480 / 360 | Seconds from full to empty at drain mul 1 (Arcade pace) |
| SurvivalDrainMul | by Species | TRex 1, Raptor 1.25 (raptor: 384 s / 288 s); set to override |
| StarveDamageRate / DehydrateDamageRate | 0.01 / 0.01 | Share of MaxHealth lost per second while that meter is 0 (both empty = both) |
| EatRate / DrinkRate | 10 / 15 | Meter points per second while holding E |
| EatRange | 8 | Flat (X/Z) studs from the head to the carcass box |
| EatHeight | 20 | Head at most this far above the carcass box top / below its bottom |
| SurvivalWarnFraction | 0.2 | Below this share of max: warning (red pulsing bar) |

| Attribute (SurvivalServer script) | Value | Meaning |
|---|---|---|
| SurvivalCarcassEnabled | true | KO'd / killed bots leave a carcass |
| SurvivalCarcassTime | 90 | Seconds a carcass stays (or until eaten) |

State (character, server): `Hunger`, `Thirst` (exact), `HungerState` / `ThirstState` (ok / warning / empty), `SurvivalState`
(ok / warning / starving / dehydrating / starvingAndDehydrating / dead / disabled), `SurvivalCanEat`, `SurvivalNearCarcass`,
`SurvivalCanDrink`, `SurvivalWaterSource` (lake / sea / none), `SurvivalAction` (none / eating / drinking).
Diagnostics (character, server): `SurvivalVersion`, `SurvivalLastChange` + `SurvivalLastChangeAt` (meter state from → to and the
value that triggered it), `SurvivalActionResult` (started / released / full / outOfRange / notInLake / dead / disabled / switched /
badArg), `SurvivalActionStartedAt` / `SurvivalActionStoppedAt`, `LastAteAt`, `LastDrankAt`, `SurvivalFoodEaten`, `SurvivalWaterDrunk`,
`StarveDamageTaken` / `DehydrateDamageTaken` (exact), `SurvivalDamageTaken` (whole), `SurvivalDiedOf`.
Diagnostics (character, client): `SurvivalBarsVersion`, `SurvivalBarsState` (normal / warning / empty / disabled), `SurvivalHint`,
`SurvivalInputBound`, `SurvivalHolding`.
Carcass (Workspace.DinoCarcasses.Carcass_<Species>_<n>): `Carcass`, `CarcassSpecies`, `CarcassFood`, `CarcassFoodMax`, `CarcassFrom`,
`CarcassKilledBy`, `CarcassCreatedAt`, `CarcassExpiresAt`. Script: `SurvivalServerVersion`, `SurvivalCarcasses`, `SurvivalCarcassesMade`,
`SurvivalCarcassesEaten`, `SurvivalCarcassesExpired`, `SurvivalCarcassLastRemoved`, `SurvivalCarcassLastSkipped`.
Verified in Play (T-Rex): drain 0.208 / 0.278 per s; lake drink 40 → full ("full"); sea shallows = "sea", no drink, E not bound;
raptor carcass 60 food eaten at 10/s, carcass removed ("eaten"), action stopped "outOfRange"; Hunger 0 → 2 HP/s (1% of 200);
Ram not triggered while E ate / drank.

## Camera (CameraZoom)
| Attribute | Value | Meaning |
|---|---|---|
| CameraStartZoom | 35 | Camera distance (studs) set on every spawn; scroll / pinch still zooms |

## Shoulder camera (ShoulderCam 1.0 / TurnLimit 1.1 aim mode)
Fixed over-the-shoulder camera on the owner's client (Scriptable camera, cursor locked to the centre, small white
centre dot). Mouse / right stick / touch drag (right 60% of the screen) aims; the body turns toward the camera yaw at
`TurnLimitRate` (TurnLimit 1.1 `TurnLimitMode` = "aim", set by ShoulderCam): W/S move along the aim, A/D strafe.
Q / gamepad R3 / touch **Shoulder** swaps shoulders (starts right = dino on the left of the screen). Hold Left Alt (or
open the Roblox menu) for a free cursor. Scroll / pinch zooms 0.6–1.5× of the distance. The camera is pulled in to just
before world geometry (dinos, hitboxes and this dino ignored); Humanoid.CameraOffset (bite punch, roar shake) still applies.
Framing defaults are measured from the model at spawn; any attribute below overrides.

| Attribute | Default | Meaning |
|---|---|---|
| ShoulderCamEnabled | true | false = Roblox's camera (Custom), mouse free, TurnLimitMode "move" |
| ShoulderCamDistance | CameraStartZoom (T-Rex 35, raptor 16) | Camera distance behind the focus (studs, × zoom) |
| ShoulderCamFocusHeight | 0.75 × model top above the HRP (T-Rex 8.1, raptor 1.7) | Focus point above the HumanoidRootPart |
| ShoulderCamSide | max(0.6 × width, 0.9 × top + 1) (T-Rex 10.7, raptor 3) | Sideways offset toward the shoulder |
| ShoulderCamHeight | 0.35 × top (T-Rex 3.8) | Extra camera height |
| ShoulderCamSensitivity | 0.25 | Degrees per mouse pixel |
| ShoulderCamPadSpeed | 240 | Right-stick turn speed (°/s at full tilt; 0.15 deadzone) |
| ShoulderCamTouchSensitivity | 0.35 | Degrees per touch-drag pixel |
| ShoulderCamPitchMin / Max / Start | −55 / 65 / −12 | Pitch limits and start (°) |
| ShoulderCamZoomMin / Max | 0.6 / 1.5 | Zoom range (wheel step 0.1) |
| ShoulderCamSwapTime | 0.2 | Seconds the shoulder swap slides |
| TurnLimitMode | "move" (ShoulderCam sets "aim") | TurnLimit 1.1: "aim" = body turns to the camera yaw, camera-relative movement |

Test hook: `ShoulderCamLookAt` (Vector3) turns the camera to look at that point once, then is cleared.
Diagnostics, owner client: `ShoulderCamState` (aim/free/off), `ShoulderSide` (right/left), `ShoulderCamYaw`,
`ShoulderCamPitch`, `ShoulderCamZoom`, `ShoulderCamBlocked`, `ShoulderCamNowDistance`, `ShoulderCamNowFocusHeight`,
`ShoulderCamNowSide`, `ShoulderCamNowHeight`; TurnLimit 1.1 `TurnLimitState` adds aiming/aimAligned.

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

### Raptor bite (RaptorModelData 1.11 / raptor_generator 1.11)
The player raptor's bite = the raptor bot's bite (BotServer SPECIES Raptor: 8 dmg / 1 s / reach 3). Same BiteTest 1.4 /
BiteServer 1.5 path as the T-Rex; only these values differ (everything else inherited from TRexModelData).

| Attribute | Raptor value | Meaning |
|---|---|---|
| BiteEnabled | true | Bite on (was false since RaptorModelData 1.0) |
| BiteDamage | 8 | Base damage (× hit zone: head 12, torso 8, tail 4) |
| BiteCooldown | 1 | Seconds between bites |
| BiteRange | 3 | Capsule radius = the bot's reach |
| BiteReachBack | 0 | Capsule runs from the mouth front to 1.5 studs ahead: a 3-stud ball around the snout |

Reach (rest pose, HRP space): mouth front 5.2 ahead → capsule tip 6.7 → hit surface up to ~9.7 ahead, plus the 3-stud
BiteLungeDist. Verified in Play (RaptorModelData 1.11): raptor bot torso 60 → 52, tail 52 → 48 (×0.5), arm 48 → 40;
cooldown blocks a second click 0.4 s later; bot 19 studs ahead (nearest hitbox ≥ 16) = miss; T-Rex bot leg (LegL) 200 → 192.

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
Since RaptorModelData 1.11 the bite is on (see "Raptor bite" under Bite).
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

## Pounce (PounceTest 1.0 / PounceServer 1.0 / PouncePose 1.0 / StaminaServer 1.2)
Only dinos with `PounceEnabled = true` (the Raptor). F / gamepad X / touch Pounce button → 0.1 s crouch → flat lunge
(20 studs, 70 studs/s, ~0.3 s, 2.7 studs high). Touching a hitbox of a larger dino (Bitable + Species, extents ≥ 1.5× the
raptor's: the display T-Rex now; player T-Rex once PvP damage exists) latches on: the raptor clings to that body part,
riding its animation, and bites. Damage 8 on landing + 4 every 0.5 s (× roar debuff, no hit zones). Stamina −15 for the
pounce, −15/s while latched. Lets go on jump (leaps off), stamina 0, target KO. Miss = lands ~22 studs ahead.

| Attribute | Raptor value (default) | Meaning |
|---|---|---|
| PounceEnabled | true (false) | Has the pounce (and the Pounce button) |
| PounceWindup | 0.1 | Crouch seconds before the lunge |
| PounceDistance | 20 | Studs the lunge covers on flat ground |
| PounceUpSpeed | 28 | Upward studs/s at the launch (sets the arc; JumpPower is set to this for the launch) |
| PounceReach | 1.6 | Radius of the contact sweep at the snout |
| PounceCooldown | 3 | Seconds between pounces (client + server) |
| PounceStaminaCost | 15 | Stamina per pounce; also the minimum needed |
| PounceLatchDrain | 15 | Stamina per second while latched |
| PounceLandDamage | 8 | Damage when it latches |
| PounceTickDamage / PounceTickInterval | 4 / 0.5 | Damage per bite / seconds between bites while latched |
| PounceSizeRatio | 1.5 | Target must be at least this many times the raptor's size |
| PounceClaimWindow | 0.9 | Seconds after the start a latch claim is accepted |
| PounceLatchStandoff | 2.4 | Studs the body sits off the gripped surface |
| PounceLeapOffSpeed / PounceLeapOffUp | 30 / 35 | Studs/s away from the surface / up when jumping off |

PouncePose 1.0 shape values (defaults): `PouncePoseEnabled` true; lunge `PounceLungePitch` 18, `PounceLungeLegFwd` 0.55,
`PounceLungeLegDown` 0.45, `PounceLungeToe` −20, `PounceLungeArms` 45, `PounceLungeJaw` 28; latched `PounceLatchCrouch` 2.6,
`PounceLatchLean` 22, `PounceLatchNeck` 60, `PounceLatchHead` −20 (snout into the body), `PounceLatchArms` 55,
`PounceLatchJawOpen` 22, `PounceChompTime` 0.22, `PounceThrash` 10.

Diagnostics: owner client `PounceTestState` / `PounceLocalState` (off/ready/windup/lunge/latched/dead), `PounceInputResult`
(sent/air/exhausted/stamina/cooldown/latched/dead/denied), `PounceContact` (hit/miss/noTargets), `PounceContactSegment`,
`PounceLungeSpeed`, `PounceLatchSource` (predicted/server), `PounceLetGo` (jump/rejected/server:<reason>/gone/dead/orphan),
`PounceTargets`, `PouncePredictedAt`. Server (replicated): `PounceStartedAt`, `PounceServerResult`, `PounceDeniedAt`,
`PounceDenyReason`, `PounceClaimResult` (ok/badArg/noPounce/late/badTarget/small/far/badOffset/dead), `PounceClaimDist`,
`PounceLatched`, `PounceLatchedAt`, `PounceLatchOffset`, ObjectValue `PounceLatchPart`, `PounceLatchTarget`,
`PounceLatchSegment`, `PounceBiteAt`, `PounceHitDamage`, `PounceDamageTotal`, `PounceReleasedAt`, `PounceReleaseReason`
(jump/stamina/ko/gone/dead/disabled/timeout), `PounceCount`, `PounceLatchCount`, `StaminaPounceCount`, StaminaState
`latched`. Every client: `PounceState` (none/windup/lunge/latched/release), `PounceBlend`, `PounceSource`.

### Pin (PounceTest 1.1–1.2 / PounceServer 1.1 / WalkTest 1.5)
A pounce on a Bitable + Species dino smaller than `PounceSizeRatio` × the raptor's size (same size or smaller: the
display raptor now; player dinos once PvP damage exists) pins it: the target is knocked onto its side (WalkTest 1.5
"pinned"), the raptor stands on top of it (upright, facing the lunge direction, at the target's HumanoidRootPart X/Z and
`PouncePinRideHeight` above the ground under it — default own hip height + 0.9 × the target's thickness) and bites with
the latch pose. Damage and stamina are the same as a latch (8 on landing + 4 every 0.5 s, −15/s). The pin ends only when
the raptor jumps off or its stamina runs out (also gone / dead / disabled / timeout) — not on the target's KO. The target
then rolls back up over 0.5 s ("getup") and walks on. Contact (PounceTest 1.2): when the front sweep misses, a
`PounceReach` sphere is swept straight down from the front point to feet level against pin targets only (a same-size
target sits under the lunge arc).

Attributes: `PouncePinRideHeight` (optional override). Diagnostics: owner client `PounceKind` (latch/pin),
`PounceContactProbe` (front/column); server `PounceMode` (latch/pin), `PounceClaimResult` adds busy (target already
pinned; "small" no longer used), `PounceReleaseReason` ko applies to latches only; on the target `PinnedAt` (server time),
`PinnedBy` (raptor name), `PinReleasedAt`; WalkTest `WalkTestState` adds pinned/getup.

### Pounce effects (PounceFX 1.0)
Every client, on each `PounceBiteAt`: the bite chomp (`BiteSoundId`) on the head at a higher pitch, a small flash at the
jaws and a damage number — landing hit (`PounceBiteAt` == `PounceLatchedAt`) big yellow (0.8 s, as a bite's), each 0.5 s
bite smaller orange (0.55 s, 0.65×). No chunks, wobble or camera punch.

| Attribute | Default | Meaning |
|---|---|---|
| PounceSoundPitch | 1.35 | Chomp PlaybackSpeed (higher = smaller, sharper chomp) |
| PounceSoundVolume | 0.7 | Chomp volume |

Diagnostics (client): `PounceFXHits`, `PounceFXLast` (land/bite), `PounceSoundLoaded`.

## Display raptor (tools/display_raptor_install.luau 1.0, WalkTest 1.4–1.5)
`Workspace.DinoArcade_Raptor.Raptor_v1.0_Display`, built from RaptorModelData with DinoModelBuilder (anchored, PivotOffset
90° so WalkTest's path follows the raptor's forward). Bitable, `DummyMaxHealth` 60, `DisplayName` "Display Raptor",
`WalkTestSpeed` 30 (walk out), `WalkTestReturnSpeed` 52 (run back), `WalkTestDistance` 100, `WalkTestTurnTime` 0.5,
`WalkTestKOHalfWidth` 0.9; route (−60, 0, 120) → (40, 0, 120). WalkTest 1.4 settings default to the 1.3 behaviour.

## Move direction (IdleAnimation 1.17 / WalkPose 3.4)
Steps follow the direction the body actually moves (body frame): backing up runs the step cycle in reverse, strafing
side-steps (hip roll, foot kept flat), diagonals mix both. Below 2 studs/s the step direction eases back to forward.

| Attribute | Default (Raptor) | Meaning |
|---|---|---|
| WalkDirectional | true | false = forward-only stepping (IdleAnimation 1.16 behaviour) |
| WalkSideStepReach | 1 (1.6) | Most side step × the hip's distance from the centre line (1 = feet meet it; > 1 = feet cross) |

Diagnostic (every client): `MoveDir` (degrees, 0 forward, 90 right, -90 left, ±180 back).
Raptor crouch walk (RaptorModelData 1.4; 1.5: CreepEnabled true, so C / B / touch crouches it too, besides exhaustion): CreepCrouch 4.3, CreepStepLength 12, CreepDuty 0.65,
CreepStrideStretch 1.15, CreepLift 2, CreepFootForward 1, CreepLean 6, CreepNeckDrop 20, CreepTailDrop 10,
CreepTailWhip 0.15, CreepArmTuck 35. T-Rex creep values unchanged.

## Island, bots and health (Island 1.0 / BotServer 1.0 / DinoHealthServer 1.0 / HealthBar 1.0 / BushView 1.0)
Island: `Workspace.DinoIsland` (tools/island_install.luau) — attributes `IslandVersion`, `IslandHalfSize` 185,
`IslandWanderLimit` 165; bushes = models with `DinoBush` = true; bot spawn markers carry `Species`.
Island 1.1: hiding spots are `DinoIsland.TallGrass` patches (`DinoBush` = true, `DinoTallGrass` = true, ModelStreamingMode Atomic),
blades 17–23 studs tall, so the T-Rex can hide too; trees in `DinoIsland.Trees` (JungleTree_n, Palm_n).
Bots (`DinoIsland.Bots`, "Bot_<Species>_<n>"): `IsBot`, `BotSpecies`, `Bitable`, `DummyMaxHealth` (Raptor 60, T-Rex 200),
`DisplayName`, `BiteEnabled` true. BotServer script attributes override: `BotSightRange` 60, `BotLoseRange` 90,
`BotHiddenLoseTime` 2, `BotWanderRadius` 60, `BotChaseSpeedMul` 0.9, `BotRespawnTime` 10, `BotKORemoveTime` 2.5.
Bite per species (BotServer SPECIES): Raptor 8 dmg / 1 s / reach 3; T-Rex 25 dmg / 1.6 s / reach 6.
Player health: Humanoid.MaxHealth = `DinoMaxHealth` or T-Rex 200 / Raptor 60; no regen; respawn 3 s.
Diagnostics: bot `BotState` (wander/idle/chase/search/bite/pinned/ko/getup), `BotTarget`, `BotBites`, `BotSpawnedAt`;
player character `Hidden`, `LastHitBy`, `LastHitDamage`, `LastHitAt`, `DiedAt`, `RespawnTime`, `DinoHealthVersion`,
`DinoMaxHealthSet`; client `HealthBarState` (normal/low/dead), `HealthShown`, `BushInside`; player `DinoDeaths`;
BotServer `BotServerVersion`, `BotServerState`, `BotCount`; BiteDummy `BiteDummyState` "island".

## Island 2.0 (island_v2_generator 1.0 / island_v2_install 1.0)
`Workspace.DinoIsland` 2.0 keeps the 1.x contract (folders Ground / Rocks / Trees / TallGrass / BotSpawns / Bots / EdgeWalls,
`Ground.Water` = the sea, top −0.8; `Trees` models with `Trunk*` / `Root` parts; `TallGrass` models with `DinoBush` +
`DinoTallGrass`; markers with `Species`), so BotServer / BushView / ShakeOffServer / RamServer / RamTest / StunClient are unchanged.

| Attribute (DinoIsland) | Value | Meaning |
|---|---|---|
| IslandVersion | "2.0" | Map version |
| IslandHalfSize | 470 | Land reaches about ±470 studs (edge walls at ±561) |
| IslandWanderLimit | 460 | BotServer keeps wander targets inside abs(x), abs(z) ≤ this |
| IslandGeneratorVersion / IslandInstallVersion | "1.0" / "1.0" | Tools that built it |
| IslandBuildStage | "done" | Last install stage (begin / ground / water / rocks / trees / grass / done) |
| IslandGroundBlocks / IslandLakeBlocks / IslandBoulders | 2283 / 45 / 102 | Built counts (checked against tools/island_v2/manifest.json) |
| IslandTrees / IslandJungleTrees / IslandPines / IslandPalms | 405 / 126 / 255 / 24 | Trees |
| IslandTallGrassPatches / IslandTallGrassFields | 38 / 6 | Hunting fields; each patch also has `TallGrassField` (1–6) |
| IslandParts | 11012 | BaseParts in the island |
| IslandSpawnPos | (44, −0.4, 452) | Player spawn (south beach) |

Ground part names: `Grass` (forest floor), `Meadow`, `RockGround`, `Sand`, `Shallows` (sea shelf and every lake bed — the name
ShakeOffServer's water test reads), `LakeWater` (lake surfaces: no collision / queries), `Water`, `Seabed`. Verified in Play: bots
spawn and wander; `Hidden` true inside a patch, false 60 studs out; ShakeOffServer's ray reads all three lakes and the sea as water,
meadow and beach as dry; `ShakeOffTrunks` 1710.

## Island 3.0 (island_v3_generator 1.1 / island_v3_install 1.1)
Same contract as 2.0 (folders, part names, `Ground.Water` top −0.8, tree `Trunk*` / `Root` parts, `DinoBush` + `DinoTallGrass`
patches, `Species` markers), so no game script changed. New tree model `CoconutPalm_n` (ringed `Trunk` parts collide, `Crown`,
`Frond`, `Tuft`, `Coconut`). Lake beds are still named `Shallows`; the sea floor is several `Seabed` blocks around the lakes.

| Attribute (DinoIsland) | Value | Meaning |
|---|---|---|
| IslandVersion | "3.0" | Map version |
| IslandHalfSize | 940 | Land reaches about ±940 studs (edge walls at ±1085) |
| IslandWanderLimit | 920 | BotServer keeps wander targets inside abs(x), abs(z) ≤ this |
| IslandGeneratorVersion / IslandInstallVersion | "1.1" / "1.1" | Tools that built it (installed with 1.0 payloads + the 1.1 seabed, identical result) |
| IslandBuildStage | "done" | Last install stage |
| IslandGroundBlocks / IslandLakeBlocks / IslandBoulders | 4725 / 49 / 109 | Built counts (checked against tools/island_v3/manifest.json) |
| IslandSeabedBlocks | 88 | Sea floor blocks (top −8) that leave the lakes open (1.1) |
| IslandTrees / IslandJungleTrees / IslandPines / IslandPalms | 405 / 114 / 21 / 270 | Trees (IslandPalms = coconut palms) |
| IslandTallGrassPatches / IslandTallGrassFields | 54 / 9 | Hunting fields; each patch also has `TallGrassField` (1–9) |
| IslandParts | 19849 | BaseParts in the island |
| IslandSpawnPos | (88, −0.4, 904) | Player spawn (south beach) |

Verified in Play: 4 bots spawn and wander; `Hidden` true inside a field patch; a dino in the middle lake stands on the bed at
−30.8 (no Seabed above it); ridge top 54 walkable; `ShakeOffTrunks` 3247; every column of ±1700 hits ground (no holes).

## Island 3.1 (island_v3_generator 1.2 / island_v3_install 1.2)
Same contract as 3.0. New ground part name `Trail` (the mountain trail; collides, studded top, no script reads it). The
middle and south lakes are one lake; the mountain's cliffs are `RockGround` in 14-stud bands up to the 200-stud summit.

| Attribute (DinoIsland) | Value | Meaning |
|---|---|---|
| IslandVersion | "3.1" | Map version |
| IslandHalfSize / IslandWanderLimit | 940 / 920 | Unchanged |
| IslandGeneratorVersion / IslandInstallVersion | "1.2" / "1.2" | Tools that built it |
| IslandGroundBlocks / IslandLakeBlocks / IslandBoulders / IslandSeabedBlocks | 4578 / 48 / 120 / 89 | Built counts (tools/island_v3/manifest.json) |
| IslandTrees / IslandJungleTrees / IslandPines / IslandPalms | 357 / 100 / 6 / 251 | Trees |
| IslandTallGrassPatches / IslandTallGrassFields | 52 / 9 | Hunting fields |
| IslandParts | 18534 | BaseParts in the island |
| IslandSpawnPos | (88, −0.4, 904) | Player spawn (south beach) |

Verified in Play: a T-Rex player (40 studs long) walked the trail from the foot (8) to the summit (200) in 52 s; off the
trail a raptor's 11-stud leap reaches only the lowest bands (48); the joined lake reads as water all the way across (beds
−19 … −31); `Hidden` true in three fields; 4 bots; `ShakeOffTrunks` 2940.

## Island 3.2 (island_v3_generator 1.3 / island_v3_install 1.3)
Same contract and attributes as 3.1, with `IslandVersion` "3.2", `IslandGeneratorVersion` / `IslandInstallVersion` "1.3",
`IslandGroundBlocks` 4578, `IslandLakeBlocks` 48, `IslandParts` 18619. Lakes: beds (`Shallows`) −2.8 rim, then down to a
45-stud pit at −45.8; `LakeWater` parts are murky (52693B, transparency 0.1) from −0.8 to −46.2. Sea `Water` parts now
follow the 89 seabed rectangles (top −0.8 unchanged; ShakeOffServer still reads the first one's top).
Verified: pit beds −45.8 (joined lake 30 cells, north-east 15); a T-Rex in the pit stands at HRP −36 (fully under);
a 12 × 10 × 40 block 8 studs under the surface is invisible from the shore; `Hidden` in fields; 4 bots; trunks 2940.

## Bite dip, bot pounce and shake-off (BiteTest 1.3 / BiteServer 1.5 / BitePose 1.1 / BotServer 1.2 / ShakeOffServer 1.0 / StunClient 1.0)
Bite dip: at the press the bite looks for the smallest downward swing of the mouth about the neck (0–`BiteDipMax` 60°,
5° steps) that reaches a hitbox of another bitable dino; sent with the request, replicated as `BiteDip` (own client
`BiteDipPredicted`, `BiteDipChosen`); BitePose lowers the neck by `BiteDip − BiteLunge`; the server capsule is rotated
down by it. BiteTest 1.4 scores each dip by the whole rotated capsule (own client `BiteDipProbe` "capsule"). Bots do the same (T-Rex bot vs raptors).
Raptor bots pounce onto dinos ≥ 1.5× their size, 8–22 studs away, every 6 s (BotServer `BotPounceCooldown`); latched
8 + 4 / 0.5 s to the target's Humanoid for up to `BotLatchTime` 6.7 s. Bot attributes: `PounceStartedAt`, `PounceLatched`,
`PounceLatchedAt`, `PounceMode`, `PounceLatchTarget`, ObjectValue `PounceLatchPart`, `PounceBiteAt`, `PounceHitDamage`,
`PounceReleaseReason` (tired/gone/ko/water/rammed), `BotFlingClamps`, `BotShakeGoal` (tree/water); BotState adds
pounce/latched/leapoff/stunned/shake.
Shake-off (ShakeOffServer): on the raptor `ShakeOffReason` (water/rammed), `ShakeOffAt`, `StunnedUntil` (ram, 3 s); on
the shaking dino `ShakeOffCount`, `ShakeOffLast`, `ShakeOffLastAt`, `RamSpeed`, `InWater`. Ram = ≥ 0.75 × MoveRunSpeed
within the last 0.5 s and a blocking hitbox / HRP within 1.5 studs of a tree Trunk*/Root. Stun (StunClient): own client
`StunState` (none/stunned/getup), `StunLeft`; PounceInputResult / PounceServerResult "stunned".

## Tree ram and toss stun (RamTest 1.0 / RamServer 1.0 / RamPose 1.0 / IdleAnimation 1.19 / ShakeOffServer 1.1 / StunClient 1.1 / StunFX 1.0 / BotServer 1.3)
Settings (character): `RamEnabled` (T-Rex true, raptor false), `RamWindup` 0.4, `RamRange` 60, `RamStaminaCost` 20,
`RamCooldown` 6, `RamSpeedMul` 1.15, `RamMaxCharge` 3.5. Keys: E / gamepad DPadUp / touch "Ram".
Replicated (server): `RamStartedAt`, `RamTargetTree`, `RamCount`, `RamServerResult`, `RamDeniedAt` + `RamDenyReason`,
`RamImpactResult` (hit/waiting/farImpact/miss/noRam/late), `RamImpactDist`, `RamImpactPoint`, `RamImpactAt`,
`RamImpactCount`, `RamEndedAt`, `RamResult` (hit/miss/timeout; bots also cancel); StaminaServer `StaminaRamCount`,
`StaminaLastEvent` "ram".
Owner client: `RamTestState` / `RamLocalState` (off/ready/windup/charge/recoil/dead), `RamInputResult`
(sent/noTree/dead/stunned/latched/busy/air/exhausted/stamina/cooldown/denied), `RamTargetDist`, `RamContact`
(trunk/blocked/miss), `RamChargeSpeed`, `RamWalkSpeed` (charge/restored), `RamPredictedAt`, `RamLocalImpactAt`,
`RamLocalEndAt`. Every client (IdleAnimation): `RamState` (none/windup/charge/impact/fade), `RamSource`, `StunPose`
(none/kicking), `StunBlend`; StunFX `StunFXState` (none/stars/fading), `StunFXShown`.
Shake-off by ram (ShakeOffServer 1.1): on the raptor `StunTossFrom` (Vector3), `StunTossDistance` 15, `StunTossAt`, then
`StunnedUntil` (+3 s), `ShakeOffReason` "rammed", `ShakeOffAt`; on the rammer `ShakeOffRamImpacts`, `ShakeOffLastTossed`.
Script attribute `ShakeOffPassiveRam` (default false: running into a tree no longer shakes) + `ShakeOffPassiveRamOn`.
Toss: own client `StunState` adds "tossed", `StunTossDist`; bots `BotState` "tossed", `BotTossDist`. T-Rex bot:
`BotState` "ram", `BotRamPhase` (windup/charge/recoil/none). Latched raptor bots: `BotLatchNoCollide` (parts switched off).

## Ram only while latched on (RamServer 1.1 / RamTest 1.1)
User: "ram should only be able to happen when latched by a dino".
| Attribute (character) | Value | Meaning |
|---|---|---|
| RamRequiresLatchOn | true | Ram only while a raptor is latched on this dino; false = RamTest / RamServer 1.0 behaviour |

Server: `LatchedOnCount` (every player character, every 0.1 s) = raptors (players + DinoIsland.Bots) with `PounceLatched`, not a pin,
`PounceLatchPart` inside this character. Request result / `RamDenyReason` adds "notLatchedOn". Owner client: `RamInputResult` adds
"notLatchedOn", `RamLatchGate` (open / closed / off). The Ram key (E / DPadUp) and touch button are bound only while the gate is open,
so E does nothing (or eats / drinks, SurvivalBars) when no raptor is on. Bot rams unchanged (BotServer 1.3 already needs a latched raptor).
Verified in Play: not latched → not bound, direct request denied "notLatchedOn"; latched (test latcher) → bound, ram "ok" → "hit".

## Eat / drink animation (EatPose 1.0 / IdleAnimation 1.20)
User: "currently there is no drinking or eating animation". Driven by `SurvivalAction` (SurvivalServer 1.0) on every client.
| Attribute (model) | Value | Meaning |
|---|---|---|
| EatPoseEnabled | true | Layer on / off |
| EatBlendRate | 6 | Blend in / out per second |
| EatCrouch / EatLean | 0.8 / 8 | Body lowers (studs × scale) and pitches nose-down (°), feet planted |
| EatNeckDip / EatHeadDip | 20 / 20 | Eating neck / head dip (°) before the reach |
| EatTugRate / EatTug / EatShake / EatJawOpen | 1.2 / 14 / 10 / 35 | Tears per s, neck tug up (°), head shake (°), jaw open (°) |
| DrinkNeckDip / DrinkHeadDip | 18 / 14 | Drinking neck / head dip (°) before the reach |
| DrinkLapRate / DrinkLap / DrinkJawOpen | 2.4 / 5 / 14 | Laps per s, head bob (°), jaw open (°) |
| EatTailLift | 10 | Tail lift (°) |

Reach (IdleAnimation 1.20): extra neck dip that brings the lowest Head + Jaw point to the lake surface − 0.3 (drink) or the carcass
top (eat): 6° per stud off, at 3/s, −35..40°. Diagnostics (client): `EatPoseState` (none/eating/drinking/fade), `EatPoseBlend`,
`EatReach`, `EatMouthGap`. Verified in Play: T-Rex drinking at the lake rim settles at reach −2..−4° (mouth ±1 stud of −1.1);
raptor drinking settles at reach 0 (mouth −1.03); T-Rex eating a raptor carcass: head down, jaw opening / tug cycle.

## Eat / drink phases, vulnerability and dead look (SurvivalServer 1.1 / SurvivalBars 1.1 / EatPose 1.1 / DeadPose 1.0 / IdleAnimation 1.21)
User: drinking should take longer to get the head in; no refill until the mouth is in; eating "takes time to get into rendering the
player vulnerable"; dead dinos clearly dead; an eat prompt. Answers: move + turn locked (bite / roar / pounce cancel); drink 1 s, eat
1.5 s, up 0.5 s; dead pose; carcasses + KO'd bots + dead players.
| Attribute (character) | Value | Meaning |
|---|---|---|
| DrinkEnterTime / EatEnterTime | 1.0 / 1.5 | Seconds from the press until the mouth is in (no refill before) |
| SurvivalRiseTime | 0.5 | Seconds getting back up after letting go (still locked) |
| DeadPoseEnabled / DeadBlendRate | true / 4 | Dead look on / blend speed (model attribute) |
| DeadLegSwing / DeadKnee / DeadAnkle / DeadArm | 38 / −18 / 25 / 45 | Dead pose limbs (°) |
| DeadNeck / DeadHead / DeadHeadRoll / DeadJaw / DeadTail | −18 / −12 / 10 / −32 / 6 | Dead pose neck, head, jaw, tail (°) |

Server (character): `SurvivalPhase` (none / lowering / eating / drinking / rising), `SurvivalPhaseAt`, `SurvivalKind` (eat / drink),
`SurvivalEnterTime`, `SurvivalRiseTime`, `SurvivalLocked`, `SurvivalLockAt`, `SurvivalInterruptedBy`; `SurvivalActionResult` adds
"interrupted". Carcass: `CarcassDeadPose`. Owner client: `SurvivalLockState` (none / predicted / locked / released),
`SurvivalEatPrompt`. Every client: `EatPoseState` adds lowering / rising, `EatReachIn`, `EatReachHover`, `EatAim`, `DeadPoseState`,
`DeadPoseBlend`.
Verified in Play: drink lowering 1.0 s with no refill → drinking refills → rising 0.5 s → none; W held during the lock = 0 studs moved,
21 studs in 0.8 s after it; T-Rex facing into the lake: snout under the surface; eat lowering 1.5 s no refill → eating refills, neck turned
35° into a carcass placed to the side; a roar during eating → "interrupted", lock off at once; KO'd raptor bot, carcass and a dead
T-Rex player all show the dead pose; eat prompt "[E] EAT / food 60 / 60" over the carcass.

## Eating visible + clearly dead (SurvivalBars 1.2 / SurvivalServer 1.2–1.3 / DeadPose 1.1 / IdleAnimation 1.22 / CarcassFlies 1.0)
User: "the eating animation hasnt shown up once"; dead dinos "lay on their side eyes open not even obvious that theyre dead".
Cause found: the eat animation played (SurvivalPhase eating, EatPoseBlend 1, hunger refilling) but the shoulder camera sits
behind and above the dino, so the lowered head and the carcass were hidden behind its own body. Answers: side view while eating;
X eyes + stronger pose + flies.
| Attribute | Value | Meaning |
|---|---|---|
| SurvivalSideCam (character) | true | Camera swings to a 3/4 side view while locked (lowering / eating / drinking / getting up) |
| DeadEyesEnabled (model) | true | X eyes while dead |
| CarcassFliesEnabled (player) | true | Flies over carcasses |

Diagnostics: `SurvivalCamBlend` (owner client), `SurvivalHeadPos` (server), `DeadEyes` (every client: none / x / noHead), carcass
`CarcassDeadEyes`, `CarcassFliesVersion` / `CarcassFliesSwarms` (owner client).
Verified in Play (no teleport of the player, real bites): raptor bot killed by 3 bites → carcass → "[E] Hold to eat" → hold E → the
camera swings to the side, the T-Rex's head goes down into the carcass, hunger 27 → 56 → 83, the camera returns after getting up;
KO'd bot and carcass show X eyes (4 bars) and the jaw wide open; 6 flies over the carcass.

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
