# Dino Arcade Goals v1.0 — stage and species goals with XP rewards

**Goal:** give the player something to do that pays off from the moment they spawn, so the opening is no longer aimless roaming.
**Chosen direction:** option A "Goal list". Three goals are always shown on the right side (top at 30% of the screen height, below Roblox's player list) and can be done in any order; a finished goal glows gold, "GOAL DONE!" pops, and a new goal slides in 2.5 s later. Prototype: `docs/mockups/goals_options.html` (artifact https://claude.ai/artifact/MKZBjBF97LPhDUrJuyeKHJ).
**User answers (2026-10-27):**
- Fix "Goals / quests" first; "More dinos, closer" is plan B (roaming bots scaled by growth, grown T-Rex faces bigger raptor packs).
- Start feel: scales with growth.
- Direction A.
- Goal pool as shown.
- On death: keep the goals that still fit.

**Red-team synthesis (user answers, 2026-10-27):**
- **Player list.** Roblox's player list (CoreGui PlayerList, confirmed on in Play) covers the top-right corner. The tracker moves down the right side, with its top at 30% of the screen height; the player list is left alone.
- **T-Rex raptor goals.** "Down a raptor" and "Down 3 raptors" stay as they are. A grown T-Rex is meant to finish them by ambush ("This is the reason for grass and creep walk"). Accepted risk: until the Ambush plan ships, a T-Rex can only finish them from inside today's 52 tall-grass patches, where a hidden T-Rex is not avoided (BotServer 1.6).
- **Ambush is the next plan.** Requirements so far:
  - creeping within a few studs of tall grass counts as hidden;
  - a taller grass kind hides a T-Rex only while it creeps through it;
  - more grass everywhere, plus clusters near pack homes and lake shores.
- **Endgame.** Repeating sub-adult and adult pools (3 goals each) are accepted for v1.0; more late goals come with plan B.

**Dev Hub:** ADR-003, tickets DINO-18 … 21; follow-on plans DINO-22 (Ambush) and DINO-23 (Roaming bots).
**Architecture:**
- A pure module (GoalDefs) holds the goal pool, the reward maths and the pick / carry rules.
- A new server script (GoalServer) keeps each player's 3 goals per species for the session. It counts progress from attributes the existing scripts already publish and pays XP by raising a character counter (`GoalXpEarned`).
- GrowthServer 1.2 turns that counter into XP the same way it already turns `SurvivalFoodEaten` into XP.
- A new HUD script (GoalTracker) draws the list from player attributes.
- No fight, survival, bot or prey script changes.

## Global Constraints
- Version tags:
  - GoalDefs 1.0, GoalServer 1.0, GoalTracker 1.0 and GrowthServer 1.2.
  - Each script carries a header vX.Y, a changelog line, a `<Name>Version` attribute, a docs/VERSIONS.md row and a docs/ATTRIBUTES.md section.
- Session-only, like growth (DataStore saving is DINO-10).
- Every state change is exposed as an attribute (the lists below).
- Toggles:
  - GoalServer script attribute `GoalsEnabled` (default true).
  - GrowthServer script attribute `XpPerGoal` (default 1; 0 = goals pay nothing).
  - GoalTracker character attribute `GoalPopEnabled` (default true; false = no centre pop).
- Install check: hash h = 7, h = (h × 31 + byte) % 2147483647 over the Studio Source, compared with tools hash.py over the file, plus a loadstring compile.
- Rojo mapping:
  - src/shared → ServerStorage.DinoArcade
  - src/server → ServerScriptService
  - src/character → StarterPlayer.StarterCharacterScripts
- HUD font FredokaOne; panel colour rgb(20,20,26) at transparency 0.2; outline white 2 px; XP purple rgb(196,140,255); gold rgb(255,226,122); stage yellow rgb(255,210,60); stroke purple rgb(74,42,138).

## Do-not-touch
- **Fight scripts:** BiteServer, PounceServer, KillRegenServer, BiteTargetHealth, DinoHitboxes. GoalServer only reads `KilledBy`, `KilledWith`, `KilledAt`, `BiteHitAt`, `BiteHitDamage`, `PounceBiteAt` and `PounceHitDamage`.
- **Survival:** SurvivalServer and SurvivalBars. Read only: `SurvivalFoodEaten`, `SurvivalWaterDrunk`.
- **Bots:** BotServer and PreyServer. Read only: `Hidden`, `IsPrey`, `PreyKind`, `BotSpecies`.
- **Roar:** RoarServer. Read only: `RoarCount`.
- **Growth:** GrowthCurve (required, not changed). GrowthServer 1.1 logic stays as it is; 1.2 only adds the goal counter beside food and water.
- **HUD:** Roblox's player list (top-right, left on), the bottom stack (GrowthBar −198, SurvivalBars −126, HealthBar −76, StaminaBar −26), the GrowthBar level-up banner (34% from the top), and SpeciesPicker (top-left, 16, 64).

## File structure
| File | New / Modify | Responsibility |
|---|---|---|
| `src/shared/GoalDefs.luau` | New | Goal pool, reward maths, next-goal pick, carry on stage change, kill matching. Pure, no instances. |
| `tools/tests/GoalDefs.spec.luau` | New | Logic test, run in Studio Edit through execute_luau (as GrowthCurve.spec). |
| `src/server/GrowthServer.server.luau` | Modify → 1.2 | Add `GoalXpEarned` → XP (source "goal"), as food / water. |
| `src/server/GoalServer.server.luau` | New | Records, progress counting, completion, payout, replacement, attributes. |
| `src/character/GoalTracker.client.luau` | New | Top-right list, done glow, centre pop, slide-in. |
| `docs/VERSIONS.md`, `docs/ATTRIBUTES.md` | Modify | Rows / sections per script. |

## Goal pool (GoalDefs.POOL, in pick order)
Size: s = 0.35, m = 0.6, b = 1.0 of `GrowthCurve.xpToNext(min(level, 19))`, rounded to the nearest whole number.

| Stage | id | Text | Kind | Need | Size | Who |
|---|---|---|---|---|---|---|
| 1 Hatchling | h_snack | Catch 2 chickens or crabs | kill {prey Chicken, Crab} | 2 | m | both |
| 1 | h_eat | Eat 25 food | eat | 25 | s | both |
| 1 | h_drink | Drink 25 water | drink | 25 | s | both |
| 1 | h_hide | Hide in a bush or tall grass for 10 s | hide | 10 | s | both |
| 1 | h_pounce | Pounce-kill a chicken or crab | kill {prey Chicken, Crab; with pounce} | 1 | m | Raptor |
| 2 Juvenile | j_compy | Catch 3 compies | kill {prey Compy} | 3 | m | both |
| 2 | j_bites | Land 5 bites | bites | 5 | s | both |
| 2 | j_eat | Eat 50 food | eat | 50 | s | both |
| 2 | j_drink | Drink 50 water | drink | 50 | s | both |
| 2 | j_roar | Roar 3 times | roar | 3 | s | TRex |
| 3 Sub-adult | s_raptor | Down a raptor | kill {bot Raptor} | 1 | b | both |
| 3 | s_damage | Deal 150 bite damage | damage | 150 | m | both |
| 3 | s_prey | Catch 5 prey | kill {prey any} | 5 | m | both |
| 4 Adult | a_raptors | Down 3 raptors | kill {bot Raptor} | 3 | b | TRex |
| 4 | a_trex | Down the T-Rex | kill {bot TRex} | 1 | b | Raptor |
| 4 | a_damage | Deal 300 bite damage | damage | 300 | m | both |
| 4 | a_eat | Eat 100 food | eat | 100 | s | both |

Pool sizes per species: T-Rex 4 / 5 / 3 / 3; Raptor 5 / 4 / 3 / 3. Every pool has at least 3 goals, so all 3 slots fill.

## Deterministic map (GoalServer)
| State / branch | Trigger | End state |
|---|---|---|
| waiting | character spawned, `GrowthState` not "ready" yet | `GoalState` "waiting"; no counting; baselines follow the counters |
| first fill | `GrowthState` "ready" and the species record is empty | 3 slots from `nextGoal` in pool order; `GoalState` "running" |
| respawn, same stage | new character, record exists, `GrowthStage` = record.stage | slots unchanged (progress kept) |
| stage change (up, or down by death) | `GrowthStage` ≠ record.stage | `carry`: slots still in the new pool keep progress; the rest are refilled by `nextGoal`; record.stage updated; `GoalLastEvent` "stage a->b kept n" |
| species switch | new character with a different `Species` | that species' own record (filled first if empty) |
| progress | counter increases (eat / drink / bites / damage / roar / kill match) | slot `have` = min(need, have + amount); `Goal<i>Have` |
| hide streak | `Hidden` true every tick | have = floor(seconds hidden in a row); `Hidden` false → have 0 (unless done) |
| done | have ≥ need | `Goal<i>Done` true, `Goal<i>DoneAt` = server time; character `GoalXpEarned` += reward(size, `GrowthLevel`); `GoalsCompleted` +1; `GoalLastDone` "<text> +n" |
| replace | GoalReplaceDelay 2.5 s after done | slot = `nextGoal` (not on screen, not used; pool used up → used cleared); `Goal<i>Done` false |
| died before the replace | character removed during the 2.5 s | replace still runs on the record; XP was already paid to the old character, and GrowthServer counted it while that character was alive (it reads every 0.2 s) |
| level change | `GrowthLevel` changes | `Goal<i>Xp` recomputed for open goals |
| growth off | `GrowthState` "disabled" | `GoalState` "paused"; no counting; baselines follow, so nothing done while off is credited |
| goals off | `GoalsEnabled` false | every `Goal*` player attribute removed; `GoalState` "disabled"; baselines follow; records kept |
| goals on again | `GoalsEnabled` true | attributes rewritten from the records; "running" |
| level 20 | `GrowthLevel` 20 | reward uses xpToNext(19) (310 × share); GrowthCurve.addXp at max level adds nothing |
| player leaves | PlayerRemoving | records[player] = nil |
| kill seen late | `KilledAt` older than 2 s when first seen | ignored (same rule as GrowthServer) |

Kill info for matching: `isPrey` = IsPrey == true; `preyKind` = PreyKind; `botSpecies` = BotSpecies; `with` = KilledWith. Only models in DinoIsland.Bots and DinoIsland.Prey are scanned, and only kills with `KilledBy` = the player's name count.

---

### Task 1 — GoalDefs 1.0 · Mode: Logic · DINO-18

**Files:**
- Create: `src/shared/GoalDefs.luau`
- Test: `tools/tests/GoalDefs.spec.luau`

**Interfaces:**
- Consumes: `GrowthCurve.xpToNext(level)` (ServerStorage.DinoArcade.GrowthCurve 1.1).
- Produces:
  - `GoalDefs.Version = "1.0"`
  - `GoalDefs.SLOTS = 3`
  - `GoalDefs.SHARES = {s = 0.35, m = 0.6, b = 1}`
  - `GoalDefs.POOL[stage] = {{id, text, kind, need, size, who, filter}}`, where `filter` = `{prey = {"Chicken","Crab"} | "any", bot = "Raptor" | "TRex", with = "pounce"}`
  - `GoalDefs.byId(id) -> def | nil`
  - `GoalDefs.poolFor(stage, species) -> {def}`
  - `GoalDefs.reward(size, level) -> integer`
  - `GoalDefs.nextGoal(stage, species, onScreenIds: {[id]=true}, used: {[id]=true}) -> def | nil, used`
  - `GoalDefs.carry(slots: {{id, have}}, stage, species) -> keptSlots, keptCount`
  - `GoalDefs.matchKill(def, info: {isPrey, preyKind, botSpecies, with}) -> boolean`

- [ ] Step 1: write the spec with these asserts:
  - Version "1.0".
  - Pool sizes: poolFor(1,"TRex") 4, (1,"Raptor") 5, (2,"TRex") 5, (2,"Raptor") 4, (3,*) 3, (4,"TRex") 3, (4,"Raptor") 3.
  - Rewards: reward("s",1) 5, ("m",2) 12, ("b",17) 280, ("b",20) 310, ("m",6) 69.
  - nextGoal(1,"TRex",{},{}) → h_snack.
  - nextGoal with on-screen {h_snack,h_eat,h_drink} and used {h_snack,h_eat,h_drink} → h_hide.
  - Then with on-screen {h_eat,h_drink,h_hide} and used all 4 → used cleared and h_snack returned.
  - carry({{id="h_eat",have=10},{id="h_snack",have=1},{id="h_hide",have=0}}, 2, "TRex") → kept {} 0.
  - carry({{id="s_damage",have=40}}, 4, "TRex") → kept 0.
  - carry({{id="a_damage",have=40}}, 4, "Raptor") → kept 1, have 40.
  - matchKill(h_snack, {isPrey=true, preyKind="Crab"}) true; (h_snack, Compy) false.
  - matchKill(h_pounce, Chicken with "bite") false; with "pounce" true.
  - matchKill(s_raptor, {isPrey=false, botSpecies="Raptor"}) true; (s_raptor, {isPrey=true, botSpecies="Compy"}) false.
  - matchKill(s_prey, any prey) true; (a_trex, {botSpecies="TRex"}) true.
- [ ] Step 2: run the spec in Studio Edit and watch it fail (module missing).
- [ ] Step 3: write the module. Run the spec until every assert passes.
- [ ] Step 4: install, hash-verify, update docs, commit.

**Acceptance:**
- All spec asserts pass ("PASS n").
- No instance access in the module apart from requiring GrowthCurve.

**Out of scope:** GrowthCurve maths.

### Task 2 — GrowthServer 1.2 (goal XP) · Mode: Wired · DINO-19

**Files:**
- Modify: `src/server/GrowthServer.server.luau`, in three places:
  - SCRIPT_DEFAULTS: add `XpPerGoal = 1`.
  - The `st` record in `onCharacter`: add `lastGoal`.
  - The Heartbeat food / water block and the growth-off baseline block.

**Interfaces:**
- Consumes: character attribute `GoalXpEarned` (number, cumulative, written by GoalServer).
- Produces: `giveXp(char, st, (goal - st.lastGoal) × XpPerGoal, "goal")`, so `GrowthLastXp` reads "goal +n".

- [ ] Step 1: add the hunks: `lastGoal = char:GetAttribute("GoalXpEarned") or 0` on spawn; the delta check next to food / water; the baseline advance in the off branch.
- [ ] Step 2: add the header v1.2 changelog line and set VERSION to "1.2".
- [ ] Step 3: check the hunks apply (hunks.py), multi_edit, hash, compile.
- [ ] Step 4: in Play, set the character's `GoalXpEarned` to 12 from the server. `GrowthLastXp` should read "goal +12" and XP should rise by 12. With growth off, +12 should give nothing, and turning growth back on should not credit it.
- [ ] Step 5: update docs, commit.

**Acceptance:**
- "goal +n" credited once per increase.
- No credit while off, and none afterwards.
- `XpPerGoal` 0 → no XP.
- Food / water / bite / kill XP unchanged (one sample each).

**Out of scope:** every other GrowthServer rule.

### Task 3 — GoalServer 1.0 · Mode: Wired · DINO-20

**Files:** Create `src/server/GoalServer.server.luau`.

**Interfaces:**
- Consumes:
  - GoalDefs (Task 1).
  - Character: `GrowthState`, `GrowthStage`, `GrowthLevel`, `Species`, `Hidden`, `SurvivalFoodEaten`, `SurvivalWaterDrunk`, `BiteHitAt`, `BiteHitDamage`, `PounceBiteAt`, `PounceHitDamage`, `RoarCount`.
  - Models: `KilledAt`, `KilledBy`, `KilledWith`, `IsPrey`, `PreyKind`, `BotSpecies`.
- Produces:
  - Character: `GoalXpEarned`.
  - Player:
    - `GoalState` ("waiting" / "running" / "paused" / "disabled"), `GoalStageName`.
    - Per slot i = 1..3: `Goal<i>Id`, `Goal<i>Text`, `Goal<i>Have`, `Goal<i>Need`, `Goal<i>Xp`, `Goal<i>Size`, `Goal<i>Done`, `Goal<i>DoneAt`.
    - `GoalsCompleted`, `GoalLastDone`, `GoalLastDoneAt`, `GoalLastEvent`.
  - Script: `GoalServerVersion`, `GoalsEnabled`, `GoalReplaceDelay` (2.5), `GoalCompletedTotal`.

- [ ] Step 1: write the script per the deterministic map. TICK 0.2. Per character: baselines; per player per species: a record `{stage, slots = {{id, have, doneAt}}, used}`.
- [ ] Step 2: install, hash, compile.
- [ ] Step 3: in Play as a hatchling T-Rex:
  - Spawn: 3 goals (h_snack, h_eat, h_drink).
  - Eat a carcass: Have rises; at 25 the goal is done, XP is paid, and it is replaced by h_hide after 2.5 s.
  - Kill 2 chickens: h_snack done.
  - Stand in tall grass for 10 s: h_hide done.
- [ ] Step 4: force a stage-up (set the record level to 6 through GrowthServer's record path: give 125 XP via `GoalXpEarned`) → the slots carry (0 kept) and refill with j_*. Die → stage 1 → the slots refill with h_*.
- [ ] Step 5: `GoalsEnabled` false → attributes gone, "disabled"; true → back with the same progress.
- [ ] Step 6: update docs, commit.

**Acceptance:**
- Every row of the deterministic map is observed, or forced and read back as attributes.
- A kill by another player (`KilledBy` ≠ name) doesn't count.
- A compy kill doesn't advance h_snack.
- The Raptor sees h_pounce and never j_roar.

**Out of scope:** bot / prey spawning (plan B), saving (DINO-10).

### Task 4 — GoalTracker 1.0 · Mode: Wired · DINO-21

**Files:** Create `src/character/GoalTracker.client.luau` (LocalScript in StarterCharacterScripts).

**Interfaces:** Consumes the player attributes from Task 3. Produces client diagnostics on the character: `GoalTrackerVersion`, `GoalTrackerState` ("shown" / "hidden"), `GoalPopShownAt`.

**Layout:**
- ScreenGui "GoalTracker", ResetOnSpawn true, DisplayOrder 5.
- Holder: AnchorPoint (1, 0), Position UDim2.new(1, −16, 0.30, 0) (right side, below Roblox's player list; red-team answer), width 260 (200 when the viewport is narrower than 900), vertical list with 6 px padding.
- Header row: "GOALS" left (FredokaOne 15, white) and the stage name right (13, rgb(159,176,166)).
- Goal rows, each 46 high:
  - Panel rgb(20,20,26) at transparency 0.2, UICorner 10, UIStroke white 2 px at transparency 0.55.
  - Line 1: text left (FredokaOne 13), "+n XP" right, in rgb(196,140,255), or rgb(255,210,60) when the size is b.
  - Line 2: "have / need" (12), or "have / need s" for the hide goal.
  - Progress strip: 5 px high, rgb(255,255,255) at 0.85 transparency, fill rgb(255,226,122).
- Done row: stroke rgb(255,226,122) 3 px; text prefixed "✓ " in gold.
- New row: slides in from +20 px X with transparency 1 → 0 over 0.3 s.
- Centre pop:
  - "GOAL DONE!" at Position (0.5, 0, 0.20, 0), FredokaOne 40, gold, UIStroke rgb(74,42,138) 2.
  - Subtitle "<text> · +n XP" (18, white).
  - Scale 0.3 → 1.1 → 1 over 0.3 s, hold, fade over the last 20% of 1.8 s.
  - It sits above the level-up banner at 34%, so a goal that also levels you up shows both without overlap.
- Hidden when `GoalState` is "disabled" or missing.

- [ ] Step 1: write the script.
- [ ] Step 2: install, hash.
- [ ] Step 3: in Play:
  - Screenshot at spawn (3 rows).
  - Finish h_eat: screenshot the done glow and the pop, then the slide-in.
  - Finish a goal that levels you up: the pop and the level-up banner don't overlap.
  - Two-player Studio test: check the tracker against the Roblox player list (see the red-team item).
- [ ] Step 4: update docs, commit.

**Acceptance:**
- The layout matches the prototype.
- No overlap with SpeciesPicker, the bottom HUD, the level-up banner or the player list.
- `GoalPopEnabled` false → no pop.
- Survives respawn.

**Out of scope:** GrowthBar, SurvivalBars, SpeciesPicker.
