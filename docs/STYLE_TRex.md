# T-Rex style spec — Version 1.1 (StripeEye), rig Version 1.2

The standard look for every Dino Arcade species. Source of truth for the T-Rex geometry is
`src/shared/Models/TRexModelData.luau`; this page records the rules behind it so other species match.

## Construction
- Built from plain Roblox `Part`s (Plastic), studs on every face (eyes/eye-shine smooth).
- Many overlapping rectangular blocks; curves made by rotating blocks a few degrees (stepped silhouette).
- Spikes/ridges = small dark blocks; no wedges or meshes.
- Cartoon proportions (preset **B**): big head, wide jaw, chunky short legs, short thick tail, tiny arms.
- Continuous cream **stripe** from throat → neck front → chest → belly.
- **Eyes**: flat square black eye on the side of the skull + small off-white highlight in the upper-front corner.
- Open jaw at rest (10°) with teeth top and bottom; dark red mouth interior.

## Palette (earthy)
| Use | RGB | Hex |
|---|---|---|
| Body | 102, 106, 74 | `666A4A` |
| Dark (ridges, jaw, feet) | 80, 82, 58 | `50523A` |
| Belly / stripe | 178, 162, 120 | `B2A278` |
| Mouth | 110, 52, 46 | `6E342E` |
| Teeth / claws | 232, 226, 210 | `E8E2D2` |
| Eye | 17, 17, 17 | `111111` |
| Eye shine | 245, 245, 240 | `F5F5F0` |

## Preset B proportions (generator parameters)
`bs = (1, 1.18, 1.2)` body scale · `hs = 1.45` head · `lt = 1.35` leg thickness · `ll = 0.85` leg length ·
`ts = 1.2` tail thickness · `tl = 0.8` tail length · `es = 1.7` eye size · `as = 0.75` arm size ·
`headTilt = -2°` · `jawOpen = 10°`

## Rig (Version 1.2) — 17 Motor6D joints
`RootJoint (HRP→Torso)`, `Neck`, `Head`, `Jaw`, `ArmL/R`, `Tail1–5`, `LegL/R` (hip),
`KneeL/R` (thigh→shin), `AnkleL/R` (shin→foot).
- Every segment is a `Model` with an invisible `Root` part at its joint pivot; visual parts are welded to it.
- Joint frames are world-aligned at build time: dino forward = segment +X, up = +Y.
- `HumanoidRootPart` is the invisible hitbox; on the player character its LookVector points along the dino's forward.
- Model streams atomically (`ModelStreamingMode = Atomic`).
