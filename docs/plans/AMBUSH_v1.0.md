# Dino Arcade Ambush v1.0: grass heights, creeping cover, more grass

**Goal:** let a grown T-Rex ambush raptors from grass by creeping, the way the user intends ("This is the reason for grass and creep walk. Allow a way for that mechanic to be used for ambushing that's why I want more tall grass"). This also makes the T-Rex raptor goals (Goals v1.0) achievable.
**Chosen direction:** option A, "Height rule, two grass kinds". Prototype: `docs/mockups/ambush_options.html` (artifact https://claude.ai/artifact/SmKB3NMVaqjnqDU4vewsR9).
**User answers (2026-10-27):**
- Creep: "Hidden near grass".
- Grass: "Make some grass be tall enough that a t-Rex is only hidden if it's creeping through it as well but do both options" (more grass everywhere, plus clusters near raptor pack homes and lake shores).
- Picked option A, which changes today's rule: a standing adult T-Rex is no longer hidden in tall grass.
- Cover hint: show it.

**Dev Hub:** DINO-22 (planning), ADR-004, build tickets DINO-24 … 27.

**Red-team synthesis (user answers, 2026-10-27):**
- **Part budget.** The new grass may add at most 8,000 Workspace parts. The plan is 36 tall + 90 short patches, with lighter short-grass blades (step 3.5) and CastShadow off.
- **After an ambush bite.** Kept as it is: the opening bite comes from hiding, then the existing pack grudge turns the pack on you. No bonus damage and no hidden grace.
- **Accepted risks:**
  - The server uses the measured head heights (creep pose not visible to the server), so they need re-measuring if the creep animation changes.
  - The new grass lives in the place file (the tool refuses a second batch and has a remove mode).

**Architecture:**
- **GrassCover** (new pure module) decides cover from four inputs: the patch boxes with a height each, the dino's head height (species × growth scale, lowered while creeping), whether the dino is creeping, and a 4-stud creeping edge.
- **BotServer 1.7** (the only writer of `Hidden`) uses GrassCover instead of the old "root inside a box" test. It sits behind a toggle that brings the old test back. BotServer also publishes `CoverHint` and diagnostics.
- **Grass install tool** (new, run once in Edit) adds the new patches to `DinoIsland.TallGrass` as additions:
  - tall-grass clusters near the raptor pack homes and lake shores;
  - short grass spread over open land.
- **CoverHint** (new HUD script) shows "Too tall to hide here · hold C to creep".

## Measured facts (Play, 2026-10-27)
- **Head height ("top", studs above ground):**
  - adult T-Rex: 20.0 standing, 14.0 creeping (crouch plus neck drop);
  - adult raptor: 5.5 standing, 3.3 creeping.
  - Server rest pose is the same as standing.
- **Growth sizes:** 0.4 / 0.6 / 0.8 / 1.0 (GrowthCurve 1.1, `Model:ScaleTo`); `char:GetScale()` gives the current one.
- **Today's tall grass:**
  - 52 patches in `DinoIsland.TallGrass` (attributes DinoBush, DinoTallGrass, TallGrassField; no height attribute);
  - radius 15, blades 17–23 tall, colours 93BE4E / 82C455 / 6FB84A / 5EA63E, Plastic;
  - streamed whole (ModelStreamingMode Atomic). There is no `DinoIsland.Bushes` folder.
- **Today's hiding rule:**
  - BotServer 1.1+ sets `Hidden` = HumanoidRootPart inside any patch box (+0.5) in its main loop (TICK 0.1 s);
  - the bush list is read once at server start.
  - Read by: BotServer (sight, chase, T-Rex avoid), HealthBar (HIDDEN badge), GoalServer (hide goal).
  - BushView (client) makes the patch you are inside see-through, using the same box test.
- **Other island facts:**
  - lakes = `DinoIsland.Ground` parts named "LakeWater" (their X/Z rectangles);
  - raptor pack markers at (−153, 477), (−90, −462), and an unused one at (239, 446);
  - spawn at (88, 904);
  - land about −940…1000 on both axes;
  - 18,621 parts in Workspace today.

## Global Constraints
- **Versions:** GrassCover 1.0, BotServer 1.7, grass_ambush_install 1.0 (island attribute `IslandAmbushGrassVersion` "1.0") and CoverHint 1.0. Each gets a header vX.Y, a changelog line, a version attribute, a VERSIONS.md row and an ATTRIBUTES.md section.
- **Toggles:**
  - BotServer script attribute `AmbushRulesEnabled` (default true; false = the v1.6 box test exactly);
  - character attribute `CoverHintEnabled` (default true).
- **Constants (GrassCover):**
  - TOP = {TRex = {20.0, 14.0}, Raptor = {5.5, 3.3}}; an unknown species uses TRex;
  - DEFAULT_HEIGHT 17 (a patch without `GrassHeight`);
  - EDGE 4 studs; MARGIN 0.5 (as today).
- **Grass kinds:**
  - tall: `GrassHeight` 17, radius 15, blades 17–23, today's colours;
  - short: `GrassHeight` 10, radius 10, blades 9.5–11.5, colours A6D35F / 9CCF5C / 8CC152;
  - every new patch has DinoBush = true, DinoTallGrass = true, `GrassKind`, `GrassHeight`, `GrassBatch` "ambush1", ModelStreamingMode Atomic.
- **Install check:** hash h = 7, h = (h × 31 + byte) % 2147483647, plus a loadstring compile.
- **Hint layout:** FredokaOne 15, panel rgb(20,20,26) at 0.2, UICorner 10, "C" in rgb(255,210,60).

## Do-not-touch
- **Island:** today's 52 patches and their models; the generator / island installers.
- **Hidden readers:** every BotServer behaviour except the hidden computation (sight, chase, avoid and grudge read `Hidden` as before); HealthBar; BushView; GoalServer.
- **Creep:** CreepServer / CreepTest (read only: `Creeping`).
- **Other scripts:** PreyServer and every fight / survival script.

## File structure
| File | New / Modify | Responsibility |
|---|---|---|
| `src/shared/GrassCover.luau` | New | Pure: patch records, head top, cover check, hint check |
| `tools/tests/GrassCover.spec.luau` | New | Logic test run in Studio Edit |
| `tools/grass_ambush_install.luau` | New | One-time Edit tool: places / removes the "ambush1" patches, deterministic (seeded) |
| `src/server/BotServer.server.luau` | Modify → 1.7 | Hidden via GrassCover (toggle), patch heights, CoverHint, diagnostics |
| `src/character/CoverHint.client.luau` | New | The hint line |
| `docs/VERSIONS.md`, `docs/ATTRIBUTES.md` | Modify | Rows / sections |

## Deterministic map (BotServer 1.7, every TICK, each alive player character)
| Branch | Condition | Hidden | HiddenReason | CoverHint |
|---|---|---|---|---|
| toggle off | AmbushRulesEnabled false | v1.6 box test | "legacy" | false |
| inside, fits | root inside a patch box (+0.5) and top ≤ its height (highest of the boxes it is inside) | true | "inside" | false |
| edge, creeping, fits | not inside a box that fits; Creeping; root within EDGE of a patch footprint (flat distance to the box +0.5, vertical inside the box), top ≤ its height | true | "edge" | false |
| too tall, creeping would fit | inside, or within EDGE of, a patch; top > height; creeping top ≤ height; not creeping | false | "tooTall" | true |
| too tall, even creeping | inside / within EDGE of a patch; creeping top > every such height | false | "tooTall" | false |
| next to grass, not creeping | not inside; within EDGE; not creeping; fits when creeping | false | "open" | true |
| open | no patch inside or within EDGE | false | "open" | false |

`top` = TOP[species][creeping and 2 or 1] × `char:GetScale()`.

**Character diagnostics:** `HiddenReason`, `HiddenTop` (0.1), `HiddenGrassHeight` (the height used, 0 when none). **Script:** `AmbushPatches` (patch count), `AmbushPatchesTall`, `AmbushPatchesShort`.

---

### Task 1: GrassCover 1.0 · Mode: Logic

**Files:** Create `src/shared/GrassCover.luau` and `tools/tests/GrassCover.spec.luau`.

**Interfaces:**
- `GrassCover.Version` = "1.0"; `TOP`, `DEFAULT_HEIGHT` = 17, `EDGE` = 4, `MARGIN` = 0.5.
- `GrassCover.patch(cf: CFrame, size: Vector3, height: number?) -> {cf, half, height}`: half = size / 2 + MARGIN; height defaults to DEFAULT_HEIGHT.
- `GrassCover.top(species: string?, scale: number?, creeping: boolean) -> number`.
- `GrassCover.check(patches, pos: Vector3, species, scale, creeping) -> hidden: boolean, reason: string, height: number, hint: boolean` (the deterministic map above).

**Steps:**
- [ ] Write the spec. Each check uses a patch at the origin, box 30 × 25 × 30 (top 12.5 above its centre), height 17, plus a short patch at (100, 0, 0), size 20 × 12 × 20, height 10.
  - **top:** TRex scale 1 → 20 standing and 14 creeping; scale 0.6 → 12 / 8.4; Raptor scale 1 → 5.5 / 3.3; an unknown species → TRex values.
  - **adult T-Rex at (0, 0, 0):** standing → false, "tooTall", 17, hint true; creeping → true, "inside", 17.
  - **adult T-Rex creeping at (18, 0, 0):** 18 − 15.5 = 2.5 ≤ 4, so true, "edge". Standing at the same spot → false, "open", hint true.
  - **adult T-Rex at (22, 0, 0):** 6.5 > 4, so false, "open", hint false.
  - **juvenile T-Rex** (scale 0.6) standing at (100, 0, 0) → false, "tooTall", 10, hint true; creeping (8.4) → true.
  - **sub-adult** (0.8) creeping (11.2) at (100, 0, 0) → false, "tooTall", hint false.
  - **adult raptor** standing at (100, 0, 0) → true, "inside".
  - **overlap:** both patches overlapping at one point → the higher height is used.
  - **height:** a point 20 studs above the box → "open".
- [ ] Run the spec in Edit and watch it fail (module missing).
- [ ] Write the module, run the spec until it passes, install, hash, update docs, commit.

**Acceptance:** spec PASS; pure (no instances, no services).

### Task 2: grass_ambush_install 1.0 · Mode: Wired

**Files:** Create `tools/grass_ambush_install.luau`. It is pasted into execute_luau in Edit and parameterised with `MODE` = "plan" | "place" | "remove".

**Interfaces:**
- Produces patches in `DinoIsland.TallGrass` named `AmbushGrass_<kind>_<n>`, with the attributes listed under Global Constraints.
- Island attributes: `IslandAmbushGrassVersion` "1.0", `IslandAmbushGrassTall`, `IslandAmbushGrassShort`, `IslandAmbushGrassBlades`.

**Placement** (Random seed 20261027; every spot checked by rays onto `DinoIsland.Ground`):
- **A spot is valid when:**
  - the 5 rays (centre plus 4 at the patch radius) all hit Ground parts that are not LakeWater, Shallows or Seabed;
  - every hit top is between −0.8 and 20, and the 5 tops are within 3 studs of each other (flat, not rock or mountain);
  - it is ≥ radius + 12 from every Trees model's bounding-box centre;
  - it is ≥ 90 studs from the SpawnLocation;
  - it is ≥ (its radius + the other's radius + 6) from every existing or already placed patch.
- **Tall clusters:**
  - for each BotSpawns marker with Species "Raptor" (3 markers, including the unused one), 6 patches at a random angle and a distance of 45–80 studs (≤ 400 tries per marker);
  - 18 lake-shore patches: random points 8–40 studs outside a LakeWater rectangle's edge, ≤ 3000 tries.
- **Short grass:** 90 patches at random points on land within ±940, each ≥ 95 studs from other short patches (≤ 20000 tries).
- **Blades:**
  - tall: as the island installer (step 3, jitter ±1.2, edge −0..3);
  - short: step 3.5 (fewer blades), height 9.5–11.5, width 0.8–1.2, tilt ±9°, Anchored, CanCollide false, CanQuery false, CanTouch false, CastShadow false.

**Modes:**
- "plan" returns the counts and spots without building anything.
- "remove" deletes every model with `GrassBatch` "ambush1" and clears the island attributes.

**Steps:**
- [ ] Write the tool.
- [ ] Run "plan" and read back the counts (tall clusters by marker / lake, short).
- [ ] Run "place", then hash-check that the tool file matches the run source.
- [ ] Screenshots: a pack home ring, a lake shore, open ground with short grass.
- [ ] Count parts before and after.
- [ ] Play: BushView makes a new patch see-through when you're inside it; nothing blocks walking.
- [ ] Update docs, commit.

**Acceptance:**
- Counts as planned (tall ≥ 30, short ≥ 80), with no patch in water, on rock, on a tree or within 90 of the spawn.
- Running "place" twice refuses: it reports the batch already exists and does nothing.
- "remove" restores the 52 patches only.
- Workspace parts go up by ≤ 8,000.

**Out of scope:** the island generator and its 52 patches.

### Task 3: BotServer 1.7 · Mode: Wired

**Files:** Modify `src/server/BotServer.server.luau`:
- the bush list build (add the height field: `GrassHeight` or nil);
- the "who is hidden" block in the main loop;
- the header, VERSION and DEFAULTS.

**Interfaces:**
- Consumes GrassCover 1.0, and the character's `Creeping`, `Species` and `GetScale()`.
- Produces `Hidden` (same attribute, new rule), `HiddenReason`, `HiddenTop`, `HiddenGrassHeight`, `CoverHint`; script `AmbushPatches`, `AmbushPatchesTall`, `AmbushPatchesShort`.
- Toggle `AmbushRulesEnabled`.

**Steps:**
- [ ] Add the hunks: require GrassCover; build `coverPatches` alongside `bushes`; in the loop, if `AmbushRulesEnabled` is not false use GrassCover.check, else `inBush` (v1.6).
- [ ] Install, hash, compile.
- [ ] Play: adult T-Rex (growth off) in tall grass:
  - standing → Hidden false, "tooTall", CoverHint true;
  - creeping → Hidden true;
  - creeping 3 studs outside → true, "edge";
  - standing in short grass → false.
- [ ] Hatchling T-Rex standing in short grass → true. Raptor in short grass → true.
- [ ] Toggle off → standing adult in tall grass → true ("legacy").
- [ ] Raptor bot behaviour (real): a creeping adult T-Rex in a cluster near a pack home is not avoided. A raptor wandering within bite reach can be bitten. Standing up (leaving creep) inside 40 studs → the raptors avoid it.
- [ ] Update docs, commit.

**Acceptance:**
- Every row of the deterministic map is observed in Play.
- Toggle off = v1.6 behaviour.
- The hide goal (GoalServer) still counts when Hidden is true.
- No BotServer warnings.

**Out of scope:** sight, chase, avoid and grudge logic.

### Task 4: CoverHint 1.0 · Mode: Wired

**Files:** Create `src/character/CoverHint.client.luau` (LocalScript in StarterCharacterScripts).

**Interfaces:**
- Consumes the character attributes `CoverHint`, `Hidden` and `CoverHintEnabled`.
- Produces the diagnostics `CoverHintVersion` and `CoverHintShown`.

**Layout:**
- ScreenGui "CoverHint", ResetOnSpawn true, DisplayOrder 5.
- Label AnchorPoint (0.5, 1), Position UDim2.new(0.5, 0, 1, −250): above GrowthBar (holder −198, 44 tall, so its top is at −242). Height 26, automatic width with 12 px padding.
- Text "Too tall to hide here · hold " + "C" (yellow, RichText) + " to creep", FredokaOne 15.
- Fades in and out over 0.15 s. Shown while `CoverHint` is true and `CoverHintEnabled` is not false.

**Steps:**
- [ ] Write, install, hash.
- [ ] Play screenshots: shown standing in tall grass as an adult; gone when creeping; gone in the open.
- [ ] Update docs, commit.

**Acceptance:**
- Shows and hides as described.
- No overlap with GrowthBar, the SurvivalBars hint row or GoalTracker.
- `CoverHintEnabled` false = never shown.

**Out of scope:** HealthBar, the HIDDEN badge.
