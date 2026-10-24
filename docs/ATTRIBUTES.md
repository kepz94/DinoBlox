# Character attributes

All tuning lives in attributes on the character model (`StarterPlayer.StarterCharacter`), so values can be
changed in Studio's Properties panel without touching code. Defaults below are the current values.

## Movement (test values — SRD speeds not decided yet)
| Attribute | Value | Meaning |
|---|---|---|
| MoveWalkSpeed | 16 | Walk speed (studs/s) |
| MoveRunSpeed | 28 | Run speed while Shift is held |
| MoveRoarSpeed | 4 | Speed while roaring |
| MoveCreepSpeed | 10 | Speed while C is held (creep) |

Speed priority (SprintTest 1.2): roar > run > creep > walk.

## Idle (IdlePose)
| Attribute | Value | Meaning |
|---|---|---|
| IdleEnabled | true | Animation on/off |
| IdlePeriod | 1.0 | Seconds per breathing loop |
| IdleBob | 0.3 | Body dip (studs) |
| IdleHead | 1.0 | Head/jaw motion multiplier |
| IdleTailSway | 1.0 | Tail sway multiplier |
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

## Diagnostics (set at runtime, client-side)
`IdleState`, `IdleJointCount`, `IdleLookState`, `MoveState` (idle/walking/running/creeping/crouched), `MoveSpeed`, `WalkBlend`,
`GaitBlend`, `WalkState`, `RigLegLength`, `RigHeelX`, `RigToeX`, `RigFootToe`, `RigAnkleHeight`, `RoarState`,
`Roaring`, `Sprinting`, `MoveSpeedSource` (roar/run/creep/walk), `CreepBlend`, `CreepInput`, `CreepRequested`,
`RoarFXCount`, `RoarRingsShot`, `RoarSoundLoaded`. Server: `RoarStartedAt`, `RoarCount`,
`RoarLastResult`, `Creeping`, `CreepLastResult` (on/off/disabled/dead/badArg).
