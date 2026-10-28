# Dino Arcade Bot hunting and fights v1.0

**Goal:** bots behave like animals. They hunt prey that comes into range and fight other bot dinos (user, 2026-10-27: "the bots need to hunt too tho when theyre in range of prey or fight if they get in range of other bot animals").
**User answers (2026-10-27):**
- **Fights:** predator rules. T-Rex bots attack raptor bots. The bitten raptor's pack gangs up on the T-Rex, as it does against a T-Rex player. Rival raptor packs fight each other, and T-Rex bots fight each other.
- **Fight end:** the loser flees at low health (below 30%).
- **After a kill:** the killer eats for a while (~8 s, eat animation); players can steal the carcass.
- **Priority:** the nearest target.

**Dev Hub:** DINO-30 (BotHunt 1.0), DINO-31 (BotServer 1.9); ADR-006.

## Facts read in the code (2026-10-27)
- **Bot bites hit players only.** `bite(b, player, …)` → `hum:TakeDamage` on a player's Humanoid.
- **Animal health:** prey and bots use `DummyHealth` / `DummyMaxHealth` (BiteTargetHealth: 0 → `DummyState` "ko"). Today only BiteServer (player bites) lowers it.
- **Kill stamp:** BiteServer stamps `KilledBy` / `KilledWith` / `KilledAt` (last) on a killed IsBot model. GrowthServer, GoalServer and KillRegenServer only credit `KilledBy` = a player's name.
- **Carcass:** SurvivalServer makes `Workspace.DinoCarcasses.Carcass_*` (attribute `CarcassFrom` = model name) when a downed IsBot model is destroyed (prey 2.5 s after KO via PreyServer, bots `BotKORemoveTime` 2.5 s).
- **Eat pose:** IdleAnimation 1.21 plays the eat pose on any model from `SurvivalPhase` / `SurvivalKind` / `SurvivalPhaseAt` / `SurvivalEnterTime` / `SurvivalRiseTime`, and reaches toward the carcass named by `SurvivalNearCarcass`.
- **Prey flee from bots:** PreyServer's `predatorsList` includes bots.
- **Packs:** they avoid any T-Rex, player or bot, within 40 (`nearestRex`). Their grudge works against T-Rex players only.
- **Hitboxes:** `distanceTo` / `dipFor` work on any model with `Hitboxes`.

## Architecture
- **BotHunt 1.0 (new pure module).** Decides who may attack whom, which target is nearest, flee and health regen. It works on plain descriptors, so it can be tested.
- **BotServer 1.9 (additive).** Adds an animal target path next to the player target path:
  - Search: when a bot has no player target, it picks the nearest allowed target among players (existing rules), prey and bots.
  - Fight: an animal target is chased and bitten (bite only, no pounce / latch on animals). The bite lowers the target's `DummyHealth` and stamps the kill with `KilledBy` = the bot's name.
  - Grudge: a bot bite on a pack member gives that pack a grudge against the biter, so the pack fights back and doesn't avoid it.
  - Flee: a bot below 30% health drops bot targets and runs.
  - Regen: bots heal 1% per second after 10 s without a hit.
  - Eat: after a kill, the killer eats at the carcass (eat pose) for 8 s.
- **Toggles:** BotHuntEnabled (prey) and BotFightEnabled (bots).

## Rules (BotHunt.hostile(self, other))
| self \ other | prey | raptor bot, same pack | raptor bot, other pack / no pack | T-Rex bot |
|---|---|---|---|---|
| raptor bot | yes | no | yes | only its pack's grudge target |
| T-Rex bot | yes | yes | yes | yes |

Further rules:
- `self.hpFrac < 0.3` → no bot targets (prey still allowed).
- A bot never targets itself, a KO'd animal, or a model being removed.
- Players stay on today's rules: packs leave grown T-Rex players alone; bots don't chase hidden players.

## Deterministic map (BotServer 1.9, each bot step)
| State | Condition | Action |
|---|---|---|
| flee | `DummyHealth / Max < 0.3` and a hostile bot within 40 | Run (MoveRunSpeed) 35 studs straight away from it (dry cut), drop the animal target; BotState "flee" |
| keep animal target | target alive, ≤ BotLoseRange, still hostile | Chase (dryGoal); bite when `dipFor` reaches it; BotState "hunt" (prey) / "fight" (bot) |
| lose animal target | KO'd, removed, > BotLoseRange, not hostile | Target cleared |
| pick | no player and no animal target | Nearest of: allowed players (today's checks) and hostile animals within BotSightRange. Player → today's path; animal → this path |
| bite lands | snout within reach + 1 after BITE_HIT_DELAY | `DummyHealth -= cfg.biteDamage`. Target gets `LastHitBy`, `LastHitAt`, `LastHitDamage`. Attacker gets `BiteHitAt`, `BotAnimalBites + 1`. A pack-member target's pack gets a grudge on the attacker for 20 s |
| kill | the bite takes DummyHealth from > 0 to 0 | Target gets `KilledBy` = bot name, `KilledByUserId` 0, `KilledWith` "bite", `KilledAt`. Attacker: `BotAnimalKills + 1`, eat plan |
| eat | eat plan, no player / animal target in sight | Walk to the kill spot. Once within 8 studs: SurvivalPhase "lowering" (1.5 s), "eating" (8 s), "rising" (0.5 s), then "none". SurvivalNearCarcass = the carcass with CarcassFrom = the kill's name. BotState "eat". Any new target or a hit → phase "none", eat plan dropped |
| regen | no hit for 10 s, DummyHealth < Max | +1% of Max per second |
| give up (added in the Play test) | chasing one animal: moved < 3 studs in 3 s with no bite started, or 20 s with no bite landing | Drop it, skip it for 15 s; `BotAnimalGiveUps + 1`, script `BotHuntGiveUps + 1`. Found when a chicken on a 4-stud ledge held a raptor in place forever |

Pack followers keep following unless they have their own target (today's rule).

**Diagnostics:**
- Bot: `BotAnimalTarget`, `BotAnimalBites`, `BotAnimalKills`, `BotFleeing`, `BotEatState`.
- Script: `BotHuntKills`, `BotFightKills`, `BotFightBites`, `BotFlees`, `BotEats`.

## Do-not-touch
- Player chase / bite / pounce / latch / grudge-flank.
- Water handling, roaming, size-aware rules, ambush Hidden.
- PreyServer, SurvivalServer, BiteTargetHealth, GrowthServer, GoalServer.

### Task 1: BotHunt 1.0 · Logic
**Files:** `src/shared/BotHunt.luau`, `tools/tests/BotHunt.spec.luau`.

**API:**
- `hostile(self, other) -> bool`. Descriptors are `{kind = "bot" | "prey", species, pack, id, hpFrac, grudge}`.
- `nearest(self, candidates {desc, dist, allowed?}, sight) -> index?`. A player candidate has kind "player" and comes with `allowed` already set.
- `shouldFlee(hpFrac) -> bool` (threshold 0.3).
- `regen(hp, max, sinceHit, dt) -> hp` (10 s wait, 1% / s).

**Spec:** the rule table above row by row; nearest picks the closer allowed candidate; low health drops bot targets but keeps prey; regen before / after 10 s, capped at max.

### Task 2: BotServer 1.9 · Wired
**Files:** `src/server/BotServer.server.luau` (additive: header, DEFAULTS, require, helpers, the step branch, pack grudge, `nearestRex` skip for the grudge target, regen in the main loop).

**Play checks:**
- A raptor bot hunts a chicken, kills it, eats.
- The T-Rex bot attacks a raptor pack; the pack gangs up.
- Rival packs fight.
- A bot below 30% flees, then regens.
- Toggles.
- A player still gets chased when nearer.
- No warnings.
