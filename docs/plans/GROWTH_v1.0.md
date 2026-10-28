# Dino Arcade — Growth v1.0 (levels + stages)

**Goal:** a dino visibly grows and gets stronger by playing, from hatchling to adult, and banks skill points for the coming skill tree.
**Chosen direction:** C · Levels + growth stages. Prototype: https://claude.ai/artifact/UyfqPuduULJ3cUhxBtMRv7
**Architecture:** a new server script (GrowthServer) keeps each player's level / XP per species for the session (saving is a follow-up ticket), earns XP from attributes the existing scripts already publish (food eaten, water drunk, bite / pounce hits, killing blows), and applies the stage to the character: `Model:ScaleTo(stage size)` plus scaled values written to the character attributes the existing scripts already read. Three client scripts get re-fit-on-scale extensions (animator, shoulder camera, start zoom). A new HUD bar shows level, stage, XP and banked points.

## Global Constraints
- Version tags: GrowthCurve 1.0, GrowthServer 1.0, GrowthBar 1.0, IdleAnimation 1.24, ShoulderCam 1.1, CameraZoom 1.1, BotServer 1.6. Each: header `vX.Y` + changelog line + version attribute + `docs/VERSIONS.md` row + `docs/ATTRIBUTES.md` section.
- Additive only. Existing defaults stay. Every new behaviour has a toggle: script attribute `GrowthEnabled` (default true; false = no scaling, no stat changes, no XP: the game plays exactly as today).
- Every state change is an attribute (diagnostics listed per task).
- Install per Working Agreements rule 9 (multi_edit / execute_luau, hash-verify against GitHub); stop Play before installing (rule 8).
- Rojo layout: `src/shared` → ServerStorage.DinoArcade, `src/server` → ServerScriptService, `src/character` → StarterCharacterScripts.

## Rules (from the user's answers)
- 20 levels in 4 stages of 5: Hatchling 1–5, Juvenile 6–10, Sub-adult 11–15, Adult 16–20.
- Size (body scale) changes only at stage-ups: 0.4 / 0.6 / 0.8 / 1.0.
- Strength (max health, bite damage, pounce damage) rises every level: multiplier 0.4 + 0.6 × (level − 1) / 19 (level 20 = today's adult values).
- Speed per stage (red-team answer): MoveWalkSpeed / MoveRunSpeed / MoveCreepSpeed × 0.80 / 0.87 / 0.93 / 1.00 (Hatchling → Adult).
- Distances in studs that belong to the body (bite reach, lunge, pounce distance / reach / stand-off, eat reach, camera distance) × stage size.
- XP to go from level L to L + 1: 40 + 15 × (L − 1) (3325 XP from 1 to 20).
- XP sources: 1 per meat point eaten, 0.5 per water point drunk, 1 per damage dealt (bites and pounce hits), kill bonus = half the target's max health.
- Bigger target bonus: damage XP and kill XP × clamp(target body length ÷ attacker body length, 1, 10). Smaller targets are never reduced.
- 1 skill point per level, banked (GrowthSkillPoints = level − 1). Spending comes with the skill tree plan.
- Death: drop one stage = 5 levels (minimum level 1); XP progress into the level is kept but stays below that level's requirement.
- Progress per player per species, kept for the session (red-team answer: session-only first; DataStore saving is the follow-up ticket). Species switch keeps each species' own progress.
- Bots stay adults, but react to the player's size (red-team answer, BotServer 1.6): raptor packs avoid a T-Rex player only from Juvenile up and may hunt a Hatchling T-Rex; a bot's bite or pounce damage on a player is capped at 40 % of that player's max health per hit.

Worked example (adult raptor, length 12.85, kills the adult T-Rex bot, length 40.1, ratio 3.12): damage 200 × 3.12 = 624 XP + kill 100 × 3.12 = 312 XP + eating its 200-food carcass 200 XP = 1136 XP. A T-Rex killing a raptor bot: 60 + 30 (+60 eating) = 150 XP.

## Do-not-touch
- BotServer 1.5 movement, packs, flanking, water: unchanged except the three size rules in Task 5; bots are not scaled and earn no XP.
- BiteServer 1.7 / BiteTest 1.5 hit logic and auto-aim (only their attribute inputs change values).
- PounceServer 1.3 / PounceTest 1.3 latch and pin rules, ShakeOffServer 1.1, RamServer 1.1, RoarServer 1.1.
- SurvivalServer 1.4 meters, eat / drink phases and healing.
- KillRegenServer 1.0, StaminaServer 1.4, DinoHealthServer 1.0, SpeciesServer 1.0 (read only: GrowthServer reacts to their attributes / events).
- Jump power, pounce up-speed, roar radius, ram range: unchanged at every stage.
- Model data files (TRexModelData, RaptorModelData): unchanged; adult values are read from the character at spawn.

## File structure
| File | New / extend | Responsibility |
|---|---|---|
| `src/shared/GrowthCurve.luau` | New ModuleScript (ServerStorage.DinoArcade.GrowthCurve) | Pure math: level from XP, stage, size, strength multiplier, XP needed, death drop, size-ratio multiplier, stage-scaled attribute table. No Roblox state. |
| `tools/tests/GrowthCurve.spec.luau` | New | Test script run in Studio Edit via execute_luau (no test runner exists in the repo). |
| `src/server/GrowthServer.server.luau` | New Script | XP ledger, level state (session), apply stage to the character, death drop, replicated attributes for the HUD. |
| `src/character/IdleAnimation/init.server.luau` | Extend (v1.24) | Re-fit joint rest frames and leg geometry when the model's scale changes. |
| `src/character/ShoulderCam.client.luau` | Extend (v1.1) | Re-measure framing when the model's scale changes. |
| `src/character/CameraZoom.client.luau` | Extend (v1.1) | Re-apply the start zoom when CameraStartZoom changes. |
| `src/character/GrowthBar.client.luau` | New LocalScript | HUD bar + level-up / stage-up / death-drop messages. |
| `docs/VERSIONS.md`, `docs/ATTRIBUTES.md` | Extend | Rows and sections per task. |

## Deterministic map (every new state)
| State | Trigger | End state |
|---|---|---|
| Growth off | script attribute GrowthEnabled = false | no ScaleTo, no attribute writes, no XP; GrowthState "disabled"; HUD hidden |
| Loading | PlayerAdded | GrowthSaveState "loading"; character waits at its current size (scale 1) until loaded or LOAD_TIMEOUT 8 s | *(follow-up saving ticket)*
| Loaded | DataStore GetAsync ok | record per species; GrowthSaveState "loaded" | *(follow-up saving ticket)*
| No save yet | GetAsync ok, nil | level 1, XP 0 for every species; GrowthSaveState "new" | *(follow-up saving ticket)*
| Save unavailable | GetAsync errors (Studio without API access, outage) after 3 tries | session-only progress from level 1; GrowthSaveState "unavailable"; never overwrites the store this session | *(follow-up saving ticket)*
| Character applied | CharacterAdded + record ready + DinoMaxHealthSet present (DinoHealthServer done) | ScaleTo(stage size), scaled attributes written, MaxHealth set, Health = MaxHealth; GrowthApplied = level; GrowthState "ready" |
| XP gain | any source delta > 0 | GrowthXP += gain; GrowthLastXp "<source> +n"; level-up loop |
| Level up | XP ≥ need and level < 20 | level += 1, XP −= need; strength attributes rewritten; MaxHealth rises, health fraction kept; GrowthLevelUpAt |
| Stage up | new level crosses 5 / 10 / 15 | also ScaleTo(new size) and distance attributes; GrowthStageUpAt |
| Max level | level 20 | XP stops at 0 into 20; GrowthXP frozen; HUD "MAX" |
| Death | Humanoid.Died | level = max(1, level − 5); XP kept, clamped to need − 1; GrowthDeathDropAt / GrowthDeathDrop "Lv a → Lv b"; the respawned character gets the new stage |
| Species switch | CharacterAdded with a different Species | that species' record applies |
| Save | dirty and 30 s since last save, PlayerRemoving, BindToClose | UpdateAsync; GrowthSaveState "saved" / "saveFailed" (retried at the next save point) | *(follow-up saving ticket)*

## Tasks

### Task 1 — GrowthCurve module · Mode: Logic
**Files:** Create `src/shared/GrowthCurve.luau`; Create `tools/tests/GrowthCurve.spec.luau`.
**Interfaces (Produces):**
- `GrowthCurve.Version = "1.0"`, `GrowthCurve.MAX_LEVEL = 20`, `GrowthCurve.STAGES = {"Hatchling","Juvenile","Sub-adult","Adult"}`, `GrowthCurve.STAGE_SIZE = {0.4,0.6,0.8,1.0}`
- `xpToNext(level: number) -> number` = 40 + 15 × (level − 1); 0 at level 20
- `stageOf(level) -> number` (1..4) = floor((level − 1) / 5) + 1
- `sizeOf(level) -> number` = STAGE_SIZE[stageOf(level)]
- `strengthOf(level) -> number` = 0.4 + 0.6 × (level − 1) / 19
- `addXp(level, xp, gain) -> (level, xp, levelsGained)` (loops level-ups, stops at 20 with xp 0)
- `deathDrop(level, xp) -> (level, xp)` = max(1, level − 5), min(xp, xpToNext(newLevel) − 1) (xp 0 at 20)
- `sizeRatioMul(targetLen, myLen) -> number` = clamp(targetLen / myLen, 1, 10); 1 if either is ≤ 0
- `SPEED_MUL = {0.80, 0.87, 0.93, 1.00}`; `speedOf(level) -> number` = SPEED_MUL[stageOf(level)]
- `scaledAttributes(base: {[string]: number}, level) -> {[string]: number}`: SPEED_KEYS {MoveWalkSpeed, MoveRunSpeed, MoveCreepSpeed} × speedOf (0.1 steps), STRENGTH_KEYS {BiteDamage, PounceLandDamage, PounceTickDamage} × strengthOf (rounded to whole), DISTANCE_KEYS {BiteRange, BiteReachBack, BiteLungeDist, PounceDistance, PounceReach, PounceLatchStandoff, EatRange, EatHeight, CameraStartZoom, ShoulderCamDistance} × sizeOf (0.01 steps); keys missing from base are skipped
- `maxHealthOf(baseMax, level) -> number` = round(baseMax × strengthOf(level))
- [ ] Step 1: write `tools/tests/GrowthCurve.spec.luau` with these asserts: xpToNext(1)=40, xpToNext(19)=310, xpToNext(20)=0; sum of xpToNext(1..19)=3325; stageOf(5)=1, stageOf(6)=2, stageOf(20)=4; sizeOf(1)=0.4, sizeOf(16)=1; strengthOf(1)=0.4, strengthOf(20)=1; addXp(1,0,40)=(2,0,1); addXp(1,30,500) = (7,65,6) [530 − 40 − 55 − 70 − 85 − 100 − 115 = 65 < 130]; addXp(20,0,999)=(20,0,0); deathDrop(13,50)=(8,50); deathDrop(3,10)=(1,10); deathDrop(8,200)=(3,69); sizeRatioMul(40.1,12.85)≈3.12, sizeRatioMul(12.85,40.1)=1, sizeRatioMul(500,1)=10; maxHealthOf(200,1)=80, maxHealthOf(200,20)=200; scaledAttributes({BiteDamage=25,BiteRange=5,MoveRunSpeed=52},1) = {BiteDamage=10, BiteRange=2, MoveRunSpeed=41.6}; speedOf(6)=0.87.
- [ ] Step 2: run the spec in Studio Edit (execute_luau `require` of the module source + the spec); watch it fail (module missing).
- [ ] Step 3: write the module; run the spec; all pass.
- [ ] Step 4: install the module at ServerStorage.DinoArcade.GrowthCurve, hash-verify; docs rows; commit.
**Acceptance:** all spec asserts pass in Studio; module has no Instance access; version row in VERSIONS.md.
**Out of scope:** applying anything to characters (Task 2).

### Task 2 — Re-fit on scale (IdleAnimation 1.24, ShoulderCam 1.1, CameraZoom 1.1) · Mode: Wired
**Files:** Modify `src/character/IdleAnimation/init.server.luau` (motor loop at the top of PreSimulation), `src/character/ShoulderCam.client.luau:63-75` (framing measure), `src/character/CameraZoom.client.luau` (start zoom).
**Behaviour:**
- IdleAnimation: keep `capturedScale` per motor entry (model:GetScale() at capture). Each frame, when model:GetScale() ≠ an entry's capturedScale: restC0 = CFrame.new(restC0.Position × new / captured) × restC0.Rotation, capturedScale = new; then rig = nil, geo = nil so the leg chain and knee IK re-measure. Diagnostic `IdleRefitCount`, `IdleRefitScale`.
- ShoulderCam: when model:GetScale() changes, re-measure top / width (same code as at spawn). Diagnostic `ShoulderCamScale`.
- CameraZoom: on CameraStartZoom change, re-apply the zoom the same way as at spawn. Diagnostic `CameraZoomApplied`.
- [ ] Step 1: write; install; hash-verify.
- [ ] Step 2: Play, server ScaleTo(0.5) (a test call; GrowthServer does not exist yet) on the T-Rex: the client Neck C0 matches the server (3.15, was 6.3), extents ≈ 20 (was 32), walk / run / bite / eat poses look right at 0.4, 0.6, 0.8, 1.0 (screen captures from the player camera).
- [ ] Step 3: docs; commit.
**Acceptance:** body stays together at every stage on the owner's and another client; feet stay planted when walking; camera frames the dino at every stage.
**Out of scope:** pose tuning per stage.

### Task 3 — GrowthServer · Mode: Wired
**Files:** Create `src/server/GrowthServer.server.luau`; Modify `docs/VERSIONS.md`, `docs/ATTRIBUTES.md`.
**Interfaces:** Consumes GrowthCurve (Task 1) and the re-fit of Task 2 (without it the scaled body comes apart on clients). Produces replicated character attributes `GrowthLevel`, `GrowthStage` (1..4), `GrowthStageName`, `GrowthXP`, `GrowthXPNext`, `GrowthSkillPoints`, `GrowthScale`, `GrowthLevelUpAt`, `GrowthStageUpAt`, `GrowthDeathDrop`, `GrowthDeathDropAt`, `GrowthBodyLength`; player attributes `GrowthSaveState`; script attributes `GrowthServerVersion`, `GrowthEnabled`.
**Behaviour:**
- Adult base per character at spawn (before any write): copy each key of GrowthCurve's SPEED_KEYS + STRENGTH_KEYS + DISTANCE_KEYS present on the character to `GrowthBase_<key>`; `GrowthBaseMaxHealth` = Humanoid.MaxHealth after DinoHealthServer set it (wait for attribute DinoMaxHealthSet, 5 s timeout); `GrowthBaseLength` = largest component of GetExtentsSize() / GetScale() (rest pose on the server).
- Apply: `char:ScaleTo(sizeOf(level))` only when it differs from GetScale() by > 0.001; write scaledAttributes; MaxHealth = maxHealthOf; Health = MaxHealth on spawn, health fraction kept on level-up; GrowthBodyLength = GrowthBaseLength × size.
- Body length of any model (targets): character / bot GrowthBodyLength attribute if set, else largest GetExtentsSize() component (bots are adults).
- XP sources (each tick 0.2 s, deltas of cumulative attributes kept per character): `SurvivalFoodEaten` × XpPerFood (1); `SurvivalWaterDrunk` × XpPerWater (0.5); attacker `BiteHitAt` change → `BiteHitDamage` × XpPerDamage (1) × sizeRatioMul(target named by `BiteHitTarget`); attacker `PounceBiteAt` change → `PounceHitDamage` × XpPerDamage × sizeRatioMul(target named by `PounceLatchTarget`); kills: Workspace.DescendantAdded is not used — a `KilledAt` change on any model in DinoIsland.Bots or a player character whose `KilledBy` = a player's character name → (DummyMaxHealth or Humanoid.MaxHealth) × KillXpFraction (0.5) × sizeRatioMul. Tunables are script attributes (XpPerFood, XpPerWater, XpPerDamage, KillXpFraction).
- Death: Humanoid.Died → deathDrop.
- Records live in a server table `records[player][species] = {level, xp}` (session only; PlayerRemoving drops it). The load / save rows of the deterministic map belong to the follow-up saving ticket; this task sets player attribute `GrowthSaveState` = "session".
- Diagnostics: `GrowthState` ("ready"/"disabled"), `GrowthLastXp`, `GrowthXpTotal`, `GrowthApplied`, `GrowthSaveState`.
- [ ] Step 1: write the script; install in Edit; hash-verify.
- [ ] Step 2: Play: new player spawns Lv 1 Hatchling, scale 0.4, T-Rex 80 HP, BiteDamage 10, BiteRange 2.
- [ ] Step 3: eat a raptor carcass (60 food) → +60 XP; drink to full → +50 XP; bite a raptor bot → +damage XP; kill it → +30 XP; as a raptor, latch the T-Rex bot → XP × 3.12 per hit.
- [ ] Step 4: reach level 6 (feed XP by raising SurvivalFoodEaten on the server in a test call) → Juvenile, scale 0.6; die → Lv 1; switch species → separate record.
- [ ] Step 4b: terrain check at Hatchling (0.4) for both species: walk and run across grass / meadow / rock tiles and up the beach; record any step the body cannot climb (a 0.4 raptor has HipHeight 0.84). If any are found, stop and report before Task 4.
- [ ] Step 5: docs; commit.
**Acceptance:** every session row of the deterministic map observed via its attribute; GrowthEnabled = false restores today's game exactly (scale 1, original attribute values); speeds at Hatchling = 80 % of the species' values; terrain check at Hatchling reported.
**Out of scope:** BotServer, hit logic, skill tree spending.

### Task 4 — GrowthBar HUD · Mode: Wired
**Files:** Create `src/character/GrowthBar.client.luau`.
**Layout:** bottom centre, `Position = UDim2.new(0.5, 0, 1, -176)` (50 px above SurvivalBars at −126), same holder size (0.42 width, 260–560 px), FredokaOne 16, dark back rgb(20,20,26) 0.2 transparent, 11 px corners, white 2 px stroke at 0.55, like HealthBar / SurvivalBars. Left: "LV {GrowthLevel} · {STAGE NAME}" uppercase. Right: "{GrowthXP} / {GrowthXPNext} XP" (or "MAX") plus a chip "{n} skill pts". Fill: purple gradient rgb(196,140,255) → rgb(140,90,230). Messages centred at 14% from the top, FredokaOne: level-up "Level n" + "+1 skill point" (1.8 s); stage-up "You grew into a juvenile!" + "Bigger body · {max} max health · bite {BiteDamage}" in yellow rgb(255,210,60) (2.5 s); after a death drop, on the new spawn "Dropped to Lv n · {stage}" in red (2.5 s). Hidden while GrowthState ≠ "ready".
- [ ] Step 1: write; install; hash-verify.
- [ ] Step 2: Play through Task 3's steps, compare with the prototype.
- [ ] Step 3: docs; commit.
**Acceptance:** matches the prototype layout; no overlap with SurvivalBars at 260 px and 560 px widths; hidden when growth is off.
**Out of scope:** skill tree screen.

### Task 5 — Size-aware bots (BotServer 1.6) · Mode: Wired
**Files:** Modify `src/server/BotServer.server.luau` (nearestRex, rexNear, pack target filters, bite(), latchOn / latch ticks).
**Interfaces:** Consumes the character attribute `GrowthStage` (Task 3). A character without it (growth off) is treated as Adult, so today's behaviour is unchanged.
**Behaviour:** (1) nearestRex / rexNear count a T-Rex player only when GrowthStage ≥ 2 (BOT_AVOID_MIN_STAGE). (2) Pack members may pick and keep a T-Rex player with GrowthStage 1 as a chase target (normal chase / bite, head allowed). (3) Damage a bot deals to a player per bite / latch land / latch tick = min(normal, BOT_PLAYER_HIT_CAP 0.4 × the player's MaxHealth), only when the player has GrowthStage. Diagnostics: bot `BotLastHitCapped` (true / false), `BotAvoidSkipSmall` (count).
- [ ] Step 1: write; install; hash-verify.
- [ ] Step 2: Play as a Hatchling T-Rex near Pack2: the pack hunts it; as a Juvenile it flees. Hatchling raptor bitten by the T-Rex bot loses 0.4 × 24 = 9.6, not 25.
- [ ] Step 3: docs; commit.
**Acceptance:** with growth off the bot behaviour and damage match 1.5 exactly; the three rules observed via attributes.
**Out of scope:** bot movement, flanking, water.

### Follow-up (backlog, P2) — Growth saving (DataStore)
DataStore `DinoGrowth_v1`, key `u<UserId>`, value `{v = 1, TRex = {level, xp}, Raptor = {level, xp}}`; GetAsync 3 tries, UpdateAsync on save (dirty + 30 s, PlayerRemoving, BindToClose); load failure = session-only and never overwrites; GrowthSaveState loading / loaded / new / unavailable / saved / saveFailed. Needs the user to turn on Studio API access to test.

### Note for the skill-tree plan
Dying drops 5 levels = 5 skill points. Once points can be spent, the tree plan must decide what happens to spent points on a drop (locked until re-earned, or refunded from the newest node).

## Self-review
- Coverage: maths → Task 1; animation + camera re-fit → Task 2; XP sources (4), size / stats / speed / death / species → Task 3; HUD → Task 4; bots vs size → Task 5; saving → follow-up.
- Placeholder scan: none.
- Fence check: no task edits a do-not-touch script; IdleAnimation / ShoulderCam / CameraZoom / BotServer extensions keep today's path when the scale is 1 or GrowthStage is absent.
- Order: the re-fit (Task 2) lands before anything scales a player (Task 3).

## Red-team (summary)
1. Speeds: unscaled speeds on 40 %-length legs = ~2.5x step rate (the raptor's 14 steps/s problem again). Resolved: speed × 0.80 / 0.87 / 0.93 / 1.00 by stage.
2. Bots vs small players: packs fled from any T-Rex player by species, and the T-Rex bot's 25 bite one-shot a 24-HP raptor hatchling. Resolved: Task 5 (size-aware bots).
3. Testing / saving: 3325 XP to level 20, DataStore needs Studio API access. Resolved: session-only first, saving as a follow-up; tests feed XP through the source attributes.
4. Small bodies on terrain: a 0.4 raptor (HipHeight 0.84) may not climb ground-tile steps an adult takes. Accepted as a verification gate: Task 3 Step 4b, stop and report if found.
5. Death drop vs spent points: dropping 5 levels removes 5 points; recorded for the skill-tree plan.
