# Dino Arcade Roaming bots v1.0: bot groups that travel the whole island

**Goal:** dinos come to you anywhere on the island. Today every bot wanders within 60 studs of a marker near the middle, so most of the island is empty (user: "feels like im just freely running around unless i walk into range of a bot dinosaur").
**User answers (2026-10-27):**
- "lets just forget the scale with your growth thingy and just have roaming bots on the map".
- Picked option B of `docs/mockups/roaming_options.html` (artifact https://claude.ai/artifact/9AxgWNWqsfAHvSDY91m2hy): today's 7 bots stay home and 9 new bots roam (2 raptor packs of 3, 2 lone raptors, 1 T-Rex).
- Travel: random spots.
- Mix: as shown.

**Dev Hub:** DINO-23 (planning), ADR-005, build tickets DINO-28 … 29.

**Red-team answers (2026-10-27):**
- **Lone raptors:** "Act like pack raptors". Each lone raptor is a pack of 1 (pack records Roam3 and Roam4), so it gets the pack rules: avoid a grown T-Rex, grudge, flank. Players it hunts: raptors and hatchling T-Rexes.
- **Spawn area:** "No roaming within 250 of spawn". Roam spots and roam respawn spots are never within 250 studs of the SpawnLocation.
- **Accepted:** 16 bots instead of 7 (server work per tick about doubles, 9 more bots each stepping every 0.1 s).

**Architecture:**
- **New bots, same engine.** The new bots are ordinary BotServer bots (same spawn, behaviour, hitboxes, health, carcass, kill XP). They are spawned from runtime marker parts in `DinoIsland.RoamMarkers`, which BotServer creates and which are not in BotSpawns.
- **Roaming = moving home.** Each roam group has a moving home: travel to a spot, stay 20–40 s (normal wander within 60 studs of it), pick the next spot. Bots wander around `b.home`, so setting `b.home` to the group's spot is enough. The pack leader and lone bots walk there through the existing wander (goal within BotWanderRadius of home, MoveTo, re-picked every 12 s), and pack followers follow the leader as today.
- **Spot picking** lives in a new pure module, BotRoam, which is given a ground-sample function so it can be tested without the island. A spot is:
  - dry, on low ground, 250–650 studs away, inside IslandWanderLimit;
  - reachable in a straight line with no water and no rise over 3 studs per 4-stud step (StepAssist lifts 2.6), so groups don't head into lakes or cliffs.

## Measured / read facts (2026-10-27)
- **Today's bots** (BotServer 1.7): 2 packs of 3 raptors at BotSpawn_1 / BotSpawn_2, the T-Rex at BotSpawn_4, BotSpawn_3 unused. 7 bots.
- **Wander:**
  - `randomDryGoal` = a point within BotWanderRadius 60 of `b.home` whose straight way is dry (8 tries, else the dry cut toward home); re-picked on arrival (< 5 studs) or after 12 s; 1–3 s idle.
  - Pack followers keep formation behind the leader (MoveRunSpeed when farther than CATCH_UP).
  - Packs avoid an unhidden T-Rex (player or bot) within 40.
- **Respawn:** `despawn(b)` → `spawnBot(b.marker, b.pack, b.slot)` after BotRespawnTime 10 s, at the marker (a pack member on a 6-stud ring).
- **Bot speeds:** raptor walk 30 / run 52; T-Rex walk 20 / run 44.
- **Island:**
  - IslandWanderLimit 920; land about ±940; mountain / rock ground tops above 20;
  - the water test is `isWater` (Shallows / Seabed / below −0.8 / no hit);
  - StepAssistServer lifts bots over steps up to 2.6.
- **Simulation (prototype):** share of standing spots a bot reaches within 2 minutes: today 5%, option B 29%.

## Global Constraints
- **Versions:** BotRoam 1.0 and BotServer 1.8, each with a header, changelog, version attribute, VERSIONS.md row and ATTRIBUTES.md section.
- **Toggle:** BotServer script attribute `BotRoamEnabled`, default true.
  - false → the roam bots are removed (no respawn), BotRoamState "off";
  - true → the groups spawn again.
  - Today's 7 bots are never affected.
- **Groups** (`ROAM_GROUPS`, in order): `Roam1` raptor pack (3), `Roam2` raptor pack (3), `Roam3` lone raptor (pack of 1), `Roam4` lone raptor (pack of 1), `Roam5` T-Rex (no pack, like today's T-Rex bot).
- **Constants:**
  - spot distance 250–650 studs; stay 20–40 s; arrive radius 40;
  - stuck: the group's lead bot moves < 20 studs in 25 s while travelling → new spot;
  - spawn / respawn ≥ 150 studs from every player;
  - spots and respawns ≥ 250 studs from the SpawnLocation;
  - path check: 4-stud steps, max rise 3, ground top −0.8 … 20, inside ±IslandWanderLimit;
  - 40 tries per pick.
- **Install check:** hash plus compile, as before.

## Do-not-touch
- Today's 7 bots and their markers, and every v1.0–1.7 behaviour: chase, bite, pounce, latch, ram, packs (formation / avoid / grudge / flank), water, size-aware, Hidden / ambush.
- PreyServer, GrowthServer, GoalServer, SurvivalServer, and the fight scripts.

## File structure
| File | New / Modify | Responsibility |
|---|---|---|
| `src/shared/BotRoam.luau` | New | Pure: path check, spot pick, respawn spot (ground sampled through a passed-in function) |
| `tools/tests/BotRoam.spec.luau` | New | Logic test with a fake height map |
| `src/server/BotServer.server.luau` | Modify → 1.8 | Roam groups: markers, spawn, travel / stay state, respawn, toggle, diagnostics |
| `docs/VERSIONS.md`, `docs/ATTRIBUTES.md` | Modify | Rows / sections |

## Deterministic map (BotServer 1.8, every TICK, per roam group)
| State | Condition | Action / end state |
|---|---|---|
| off | BotRoamEnabled false | Every roam bot destroyed (no respawn); group state "off" |
| spawn | enabled, the group has no live or pending bot | spot = BotRoam.respawnSpot (≥ 150 from players); marker moved there; spawnBot (packs: 3 slots); state "stay" with stayUntil = now + 20–40 s |
| stay | now < stayUntil | Every member's `b.home` = spot (normal wander around it) |
| pick | stay over | spot = BotRoam.pickSpot from the lead bot's position; on failure keep the spot and stay 10 s more (BotRoamPickFails + 1); members' home = new spot; state "travel" |
| travel | lead bot farther than 40 from the spot | Wander goals fall near the spot, so the lead bot walks there; followers follow |
| arrive | lead bot within 40 | state "stay", stayUntil = now + 20–40 s, BotRoamTrips + 1 |
| stuck | travel, lead moved < 20 studs in the last 25 s | Pick a new spot (BotRoamStuck + 1) |
| fight | a member chases / flanks / avoids | Unchanged (those branches run before wander); the group state timers keep running |
| member removed | KO → despawn | Respawn after BotRespawnTime: pack member at the group's current spot if no player is within 150, else at a respawnSpot (it runs to the leader); lone bot at a respawnSpot |
| lead bot | pack: packLeader (lowest up slot); lone: the bot | None up (all down or removed): the timers pause |

**Diagnostics:**
- Bot: `BotRoamGroup`, `BotRoamState`, `BotRoamSpot` ("x, z").
- Script: `BotRoamGroups`, `BotRoamBots`, `BotRoamTrips`, `BotRoamPicks`, `BotRoamPickFails`, `BotRoamStuck`, `BotRoamState` ("on" / "off").

---

### Task 1: BotRoam 1.0 · Mode: Logic

**Files:** Create `src/shared/BotRoam.luau` and `tools/tests/BotRoam.spec.luau`.

**Interfaces:**
- `BotRoam.Version` = "1.0"
- `BotRoam.pathOk(from: Vector3, to: Vector3, sample: (x, z) -> number?, opts?) -> boolean, reason`. sample returns the ground top, or nil for water. A step fails on: nil (water), top < −0.8, top > 20, a rise over 3 from the previous sample, or a point outside ±limit. Reasons: "ok" / "water" / "high" / "rise" / "limit".
- `BotRoam.pickSpot(rng: Random, from: Vector3, sample, opts?) -> Vector3?, tries`. opts: minDist 250, maxDist 650, limit 920, tries 40, avoid = list of positions with avoidDist. Returns the first candidate (random angle, random distance) that is inside the limit, ≥ avoidDist from every avoid point, and passes pathOk.
- `BotRoam.respawnSpot(rng, sample, players: {Vector3}, opts?) -> Vector3?`: a random dry low point inside the limit, ≥ 150 from every player, 200 tries.

**Steps:**
- [ ] Write the spec with a fake height map:
  - flat land (top 2) for |x| ≤ 900, |z| ≤ 900;
  - a "lake" (nil) for 100 ≤ x ≤ 200;
  - a "cliff" (top 30) for z ≥ 500;
  - a 2.5-stud step at x = −300.
- [ ] Spec asserts:
  - pathOk across the lake = false, "water"; into the cliff = false ("high"); over the 2.5 step = true; a 3.5-stud step = false ("rise"); a point at x = 950 = false ("limit").
  - pickSpot from (−500, 0, 0), seed 1: distance 250–650, not across the lake, z < 500.
  - pickSpot with every way blocked (from inside a ring of water) → nil after 40 tries.
  - respawnSpot with a player at the origin → ≥ 150 from it.
  - The same seed gives the same spot.
- [ ] Run the spec and watch it fail; write the module; PASS; install, hash; docs; commit.

**Acceptance:** spec PASS; pure (the module only calls `sample` and `rng`).

### Task 2: BotServer 1.8 (roam groups) · Mode: Wired

**Files:** Modify `src/server/BotServer.server.luau`, all additive hunks:
- header / VERSION / DEFAULTS (BotRoamEnabled);
- require BotRoam;
- a roam section after the startup spawn: groups, markers, spawn;
- a roam tick in the main loop, before the bot steps;
- one branch at the top of `despawn` for roam bots (respawn spot);
- `b.roamGroup` set on spawn.

**Interfaces:**
- Consumes BotRoam 1.0 and the existing `spawnBot`, `packs`, `bots`, `isWater`, `groundHit`, `wanderLimit`, `get`.
- Produces the roam bots, named `Bot_<Species>_<n>` like the others, with BotPack "Roam1" / "Roam2" for the packs, plus the diagnostics above.

**Steps:**
- [ ] Write the hunks.
- [ ] Install, hash, compile.
- [ ] Play, adult T-Rex with growth off and BotSightRange 0, so the bots roam undisturbed:
  - 16 bots: 7 at home and 9 roaming in 5 groups (BotRoamGroups 5, BotRoamBots 9).
  - Over 5 minutes (sampled every 30 s by attributes): every group makes at least 2 trips, BotRoamStuck stays low, and no roam bot ends in water.
  - Positions are logged; the spread is checked against today's homes.
- [ ] KO a roam pack member: it respawns at the group spot or ≥ 150 from the player.
- [ ] BotRoamEnabled false → 9 removed, today's 7 untouched; true → 9 back.
- [ ] With BotSightRange back to 60, a roaming pack meets the player: normal chase / avoid (screenshot).
- [ ] Docs, commit.

**Acceptance:**
- 16 bots, of which 9 roam.
- ≥ 2 trips per group in 5 minutes, and no roam bot stuck in water or on a cliff for more than 25 s.
- Respawns follow the map rows.
- The toggle works both ways, and today's 7 are unchanged.
- No new warnings; hash matches.

**Out of scope:** behaviour changes, bot counts for today's markers, growth scaling (dropped by the user).
