# Dino Arcade — Prey v1.0 (compies, chickens, crabs)

**Goal:** hatchlings and small dinos always have something they can catch: small prey that spawn near players and in fixed zones, flee in readable ways, and leave meat (and XP once growth lands).
**Chosen direction:** a new PreyServer (BotServer untouched); compies sprint-then-tire; chickens on grass, crabs on beaches. Looks approved from a Studio mockup on 2026-10-27 (`docs/mockups/prey_looks.jpg`).
**Architecture:** prey models carry the same flags as bots (`IsBot`, `Bitable`, `Species`, `HumanoidRootPart`, `DummyMaxHealth`), so the existing systems already handle them: DinoHitboxes, BiteTargetHealth (KO), BiteServer / PounceServer (bites, raptor pins), SurvivalServer (carcass on removal, food = DummyMaxHealth) and KillRegenServer. PreyServer only spawns, moves and removes them.
**Research (The Isle Evrima):** AI animals with one clear behaviour each (deer and goat flee, boar fight back, rabbit bolts, chicken = first meal for tiny carnivores, crabs and frogs = shore snacks); AI spawns in groups around players (`AIDensity` 0.25–2, `AISpawnInterval` 40 s); carnivore patrol zones switch off with no food nearby.

## Global Constraints
- Versions: PreyModels 1.0, PreyHop 1.0, IslandWater 1.0, PreyServer 1.0, BiteTest 1.6, BiteTargetHealth 1.2.
- Build order (user): growth first (DINO-5 → DINO-9), then prey. Each: header vX.Y, changelog line, version attribute, `docs/VERSIONS.md` row, `docs/ATTRIBUTES.md` section.
- Additive; toggle: PreyServer script attribute `PreyEnabled` (default true; false = no prey anywhere).
- Every state change is an attribute.
- Install per Working Agreements rule 9; stop Play before installing.

## Rules (from the user's answers)
| Prey | Where | Group | Health = meat | Walk / flee speed | Behaviour |
|---|---|---|---|---|---|
| Compy | grass near the tall-grass fields | 3–5 | 15 | 14 / 30 | Graze. A predator within 30 studs alarms the whole group: sprint 30 for 4 s, then tired (walk 14) for 3 s, repeat while a predator is within 30. |
| Chicken | grass / meadow | 2–4 | 8 | 6 / 10 | Graze and peck. A predator within 15: hop away at 10 for 3 s. |
| Crab | beach sand | 2–4 | 8 | 6 / 10 | Same as the chicken; scuttles sideways (its body faces across its path). |
- Predator = any living player character, or a BotServer bot (bots never hunt prey; prey still runs from them).
- Spawning, both ways (user's answer):
  - Zones: at start, zone centres are picked from the island ground once: compy zones next to the TallGrass fields, chicken zones on Meadow / Grass tiles, crab zones on Sand tiles; at most ZONE_MAX 6 per kind, at least ZONE_SPACING 150 studs apart (greedy farthest-point from a fixed order, so the same island gives the same zones). A zone holds 1 group while a player is within ZONE_ACTIVE 300 studs.
  - Near players: each player keeps PLAYER_GROUPS 2 groups 60–150 studs away on dry land, never within 40 studs of any player (no pop-in). Kind chosen by the ground under the spot (sand → crab, else compy or chicken alternately).
  - Top-up every TOPUP 20 s; total cap MAX_GROUPS 24, MAX_COMPIES 15 (animator cost, see red-team).
  - A group with no player within DESPAWN_RADIUS 250 studs for DESPAWN_TIME 30 s is removed (not while a member is knocked out).
- Water: prey never pick a goal in water (same rule as BotServer 1.5: ground ray hits Shallows / Seabed, below −0.8, or nothing).
- Death: DummyState "ko" or PinnedAt → lies on its side (anchored roll); removed PREY_KO_REMOVE 2.5 s after the KO → SurvivalServer makes the carcass (food = 15 / 8). A pin release without a KO lets it stand and flee.
- Everyone can hunt prey. Size-ratio XP (growth plan) gives adults only base XP from prey.

## Do-not-touch
- BotServer 1.5 (and the planned 1.6): unchanged. Prey are in a separate folder; BotServer's `bots` table never sees them.
- BiteServer / PounceServer / ShakeOffServer / RamServer / RoarServer hit and latch rules; SurvivalServer carcass code; KillRegenServer; DinoHitboxes; BiteTargetHealth health / KO logic (only its bar is skipped for prey, Task 4).
- Player characters and the growth plan rules (one amendment: GrowthServer's kill watch includes `DinoIsland.Prey`, noted on DINO-7).

## File structure
| File | New / extend | Responsibility |
|---|---|---|
| `src/shared/PreyModels.luau` | New ModuleScript | `build(kind) -> Model` for "Compy" / "Chicken" / "Crab" (compy = RaptorModelData build, recoloured, ScaleTo 0.3; snacks = part lists in one "Torso" segment with a Root, HumanoidRootPart, Humanoid, RootJoint Motor6D). Sets Species, attributes and stats. |
| `src/shared/IslandWater.luau` | New ModuleScript | `isWater(p)`, `dryLine(from, to)`, `nearestDry(p)`: the BotServer 1.5 rules, for PreyServer (BotServer keeps its own copy). |
| `src/character/PreyHop.client.luau` | New Script, RunContext Client, cloned into snack models only | Hop while moving, peck while standing, on every client (RootJoint C0). Not in StarterCharacterScripts: lives in `src/shared/PreyScripts/` and is cloned by PreyServer. |
| `src/server/PreyServer.server.luau` | New Script | Zones, spawning, behaviour, KO / pin / removal, despawn, diagnostics. |
| `src/character/BiteTest.client.luau` | Extend (1.6) | Auto-aim also scans `DinoIsland.Prey`. |

## Deterministic map
| State | Trigger | End state |
|---|---|---|
| Off | PreyEnabled = false | no zones, no spawns, existing prey removed; PreyServerState "disabled" |
| Graze | spawned, no predator in range | walk to a dry point within 15 studs of the group centre, pause 1–3 s; PreyState "graze" |
| Alarm (compy) | predator within 30 of any member | whole group PreyState "flee": run 30 away from the nearest predator (dry goal, 7 directions like BotServer avoid) for 4 s |
| Tired (compy) | 4 s of fleeing | PreyState "tired": walk 14 for 3 s, still away; then back to flee if a predator is within 30, else graze |
| Hop away (snack) | predator within 15 | PreyState "hop": 10 studs/s away for 3 s, then graze |
| Water ahead | flee / graze goal cut by water | goal = last dry point; PreyState keeps its name, diagnostic PreyWaterCuts + 1 |
| Knocked out | DummyState "ko" | lie down, PreyState "ko", removed after 2.5 s → carcass |
| Pinned | PinnedAt set (raptor pin) | lie down, PreyState "pinned"; KO → as above; release without KO → stand up, flee |
| Despawn | no player within 250 for 30 s, no member knocked out | group removed (no carcass: removed while alive, so SurvivalServer's KO check skips it); PreyDespawned + 1 |
| Zone idle | no player within 300 | zone spawns nothing; existing group despawns by the rule above |

## Tasks

### Task 1 — PreyModels 1.0 · Mode: Wired
**Files:** Create `src/shared/PreyModels.luau`.
**Interfaces (produces):** `PreyModels.Version = "1.0"`; `PreyModels.KINDS = {"Compy", "Chicken", "Crab"}`; `PreyModels.STATS[kind] = {health, walk, run, group = {min, max}, alarm, fleeTime, tiredTime}` with the table values above; `PreyModels.build(kind) -> Model` returns an unparented model with: Species = kind, BotSpecies = kind, IsBot = true, IsPrey = true, Bitable = true, DummyMaxHealth = health, DisplayName = kind, MoveWalkSpeed, MoveRunSpeed, PreyKind = kind; a Humanoid (BreakJointsOnDeath false, JumpPower 0, DisplayDistanceType None); unanchored HumanoidRootPart.
- Compy: DinoModelBuilder.build(RaptorModelData), colours 5E943E → rgb(196,150,72), 283A1E → rgb(110,62,30), C9C98F → rgb(236,222,180), then ScaleTo(0.3) before returning.
- Chicken and Crab: the part lists of the approved mockup (chicken: white body 1.6×1.3×1.1, red comb and wattle, orange beak and legs; crab: red shell 1.6×0.6×2.2, claws, eye stalks, 6 legs), all welded to the Torso segment's Root; a "Torso" segment Model so DinoHitboxes builds one Torso hitbox; crab's forward (+X of the HumanoidRootPart) is across its body so it walks sideways.
- [ ] Step 1: write; install at ServerStorage.DinoArcade.PreyModels; hash-verify.
- [ ] Step 2: in Edit, build one of each next to each other at (54, 0, 621), screen-capture, compare with the approved mockup; check HitboxCount after parenting in Play (compy ≥ 10, snacks 1); remove the test models.
- [ ] Step 3: docs; commit.
**Acceptance:** looks match the mockup; every model has a working Humanoid and hitboxes in Play; build() never parents the model.

### Task 2 — PreyHop 1.0 · Mode: Wired
**Files:** Create `src/shared/PreyScripts/PreyHop.client.luau` (Script, RunContext Client; cloned into snacks by PreyServer).
**Behaviour:** every RenderStepped on every client: speed = flat HumanoidRootPart velocity; moving (> 1 stud/s): RootJoint C0 = rest × up |sin(t × 2π × HOP_RATE 3)| × HOP_HEIGHT (0.35 × model height) and a small forward tilt; standing: a peck every 2–4 s (tilt 25° for 0.25 s); knocked out / pinned (DummyState "ko" or PinnedAt): no motion. Diagnostic PreyHopState.
- [ ] Step 1: write; install into ServerStorage.DinoArcade.PreyScripts; hash-verify.
- [ ] Step 2: verified with Task 3 (hop while fleeing, peck while grazing, still when KO).
- [ ] Step 3: docs; commit.

### Task 3 — IslandWater 1.0 + PreyServer 1.0 · Mode: Wired
**Files:** Create `src/shared/IslandWater.luau`, `src/server/PreyServer.server.luau`.
**Interfaces:** Consumes PreyModels (Task 1), PreyHop (Task 2). Produces Workspace.DinoIsland.Prey (Folder); per model: PreyState, PreyGroup (group id), PreyWaterCuts; script: PreyServerVersion, PreyServerState, PreyCount, PreyGroups, PreyZones (count per kind, e.g. "Compy 6 · Chicken 6 · Crab 5"), PreyZonesActive, PreyDespawned, PreySpawned.
**Behaviour:** as the Rules and Deterministic map above. Clones StarterCharacterScripts.IdleAnimation / StatusBadges / PounceFX / StunFX into compies (as BotServer does), PreyHop into snacks. Server-owned physics (SetNetworkOwner nil), velocity cap like BotServer's fling guard (horizontal 1.5 × run, up 30). KO roll and stand-up as BotServer 1.5 (copied, BotServer unchanged).
- [ ] Step 1: write both; install; hash-verify.
- [ ] Step 2: Play: zones listed in PreyZones; groups appear 60–150 studs from the player within 20 s; walking 260 studs away removes them after 30 s.
- [ ] Step 3: compies: approach to 25 studs → whole group sprints 4 s, tires 3 s; a Hatchling-speed chaser (35 run) catches one in the tired window (bite from the real client).
- [ ] Step 4: chickens / crabs hop away; crabs scuttle sideways; nobody enters water (sample positions for 60 s: 0 wet).
- [ ] Step 5: kill a compy: carcass appears with 15 food; eat it (hold E) → Hunger + 15; raptor pin on a chicken works.
- [ ] Step 6: client frame time with 15 compies in view (Stats / RenderStepped dt) recorded; docs; commit.
**Acceptance:** every row of the deterministic map seen through its attribute; caps respected (PreyCount, MAX_COMPIES); PreyEnabled = false removes all prey; BotServer behaviour unchanged.

### Task 4 — BiteTest 1.6 + BiteTargetHealth 1.2 + growth hook · Mode: Wired
**Files:** Modify `src/character/BiteTest.client.luau` (aimCandidates: also scan `DinoIsland.Prey`); modify `src/server/BiteTargetHealth.server.luau` (addBar skips models with IsPrey = true; health, KO and reset unchanged; diagnostic TargetBarSkipped); note on DINO-7 (GrowthServer kill watch includes `DinoIsland.Prey`).
- [ ] Step 1: write; install; hash-verify.
- [ ] Step 2: Play: bite a grazing chicken 30° off-centre → BiteAimTarget = the chicken, hit; compies show no floating bar, damage numbers still pop; bots and the display dinos keep their bars.
- [ ] Step 3: docs; commit.
**Acceptance:** prey are auto-aim targets; nothing else in the aim changes; no health bar over prey, unchanged for everything else.

### Later (backlog)
- Prey v1.1: fight-back critter (boar-like: charges dinos smaller than it, 25 health / 25 meat, new simple model).
- Prey v1.2: fish in lakes (catch from the shallows; a fishing interaction next to drinking).

## Red-team (resolved with the user)
1. Client cost: every compy runs the full IdleAnimation on every client. Accepted (user): MAX_COMPIES 15, frame time measured in Task 3 Step 6; a lighter animator only if the test shows a problem.
2. Prey before growth: resolved (user): growth first, then prey.
3. Health bars: resolved (user): hide bars on prey (BiteTargetHealth 1.2 skips IsPrey models, Task 4); damage numbers still pop.
4. Hatchling bite on a 3.9-stud compy at ground level: a Hatchling T-Rex mouth is about 5.8 studs up; the bite dip (up to 60°) and auto-aim should reach it. Verified in Task 3 Step 3, not assumed.
