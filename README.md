# DinoBlox

Dino Arcade — a fast, arcade-style open-world dinosaur survival / PvP game for Roblox. Blocky studded dinos,
instant drop-in play, quick growth and skill trees (design: Dev Hub project `dino-arcade`, SRD Version 1.0).

## What's here (T-Rex v1.1, rig v1.2)
- A playable T-Rex: players spawn as it (`StarterPlayer.StarterCharacter`).
- Code-driven animation: idle breathing + head turns, walk and run with planted feet (knee IK), roar.
- Roar: press **R** — upper-body roar, sound-wave rings shoot from the mouth, roar sound, camera shake, slowed movement.
- Test controls: **Shift** = run, **R** = roar (gamepad L3 / Y, on-screen buttons on mobile).

## Layout (Rojo)
| Path | Synced to | Contents |
|---|---|---|
| `src/character/` | `StarterPlayer.StarterCharacterScripts` | `IdleAnimation` (Script, RunContext Client) + `IdlePose` / `WalkPose` / `RoarPose` modules; `RoarFX` (Script, RunContext Client); `RoarTest`, `SprintTest` (LocalScripts, test input); `Animate` (disabled placeholder that blocks Roblox's default human animations) |
| `src/server/` | `ServerScriptService` | `RoarServer` (roar validation + cooldown) |
| `src/shared/` | `ServerStorage.DinoArcade` | `DinoModelBuilder` + `Models/TRexModelData` (exact snapshot of the player T-Rex) |
| `src/display/` | not synced | `WalkTest` — test mover used inside the display T-Rex in Workspace |
| `assets/audio/` | — | `TRex_Roar_v1.0.mp3` (uploaded as asset 105842146042073) |
| `docs/` | — | Style spec, attribute reference, version log |
| `tools/` | — | Original generator, offline IK check |

## The T-Rex model
Rojo syncs scripts, not hand-built parts, so the character model is stored as data. To rebuild it in Studio
(command bar), after syncing:

```lua
local Builder = require(game.ServerStorage.DinoArcade.DinoModelBuilder)
local data = require(game.ServerStorage.DinoArcade.Models.TRexModelData)
local m = Builder.build(data, {name = "StarterCharacter"})
m.Parent = game.StarterPlayer
```

Display copy (pinned in place, walks with `src/display/WalkTest`):
`Builder.build(data, {name = "TRex_Display", pivot = CFrame.new(0, 7.65, 40), anchored = true})`.

The snapshot was verified by rebuilding in Studio: 88 parts, 17 joints, 70 welds, all attributes identical
(max position difference 0.000008 studs).

## Docs
- [`docs/STYLE_TRex.md`](docs/STYLE_TRex.md) — look, palette, proportions, rig
- [`docs/ATTRIBUTES.md`](docs/ATTRIBUTES.md) — every tunable setting and diagnostic
- [`docs/VERSIONS.md`](docs/VERSIONS.md) — component versions + open decisions
