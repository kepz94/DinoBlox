# Tools

- `trex_generator_v3.luau` — the original generator that built the T-Rex (preset B, v1.0 and v1.1 StripeEye)
  with the 13-joint rig. Kept for history and as the starting point for new species. It does **not** include the
  rig v1.2 knee/ankle split or the player-character changes; the exact current T-Rex is
  `src/shared/Models/TRexModelData.luau` (rebuild with `DinoModelBuilder`).
- `ik_check_run.py` — offline check of the walk/run knee IK (reach, planted feet, toe clearance, flight %)
  using the T-Rex leg measurements. Run with `python3 tools/ik_check_run.py`.
- `ik_check_creep.py` — offline check of the creep gait and crouched stance (WalkPose 3.1): reach, planted feet,
  toe clearance, knee range, stance foot error (rig 1.3 legs). Run with `python3 tools/ik_check_creep.py`.
- `leg_stretch.py` — rig 1.3 leg lengthening (thigh + shin x factor, feet unchanged) applied to
  `TRexModelData.luau`; the same math was run in Studio on the StarterCharacter. Only for rig 1.2 data.
- `raptor_generator.py` (v1.0) — builds the raptor geometry, rig and attributes and writes
  `src/shared/Models/RaptorModelData.luau` (the T-Rex attributes are copied in, raptor overrides on top). Run with
  `python3 tools/raptor_generator.py`. Style rules: `docs/STYLE_Raptor.md`.
- `island_v2/island_v2_generator.py` (v1.0) — DinoIsland 2.0 layout from `island_v2/reference_photo.webp` (the user's aerial
  photo): writes `island_v2/payloads/NN_<stage>.luau`, `island_v2/manifest.json` (expected counts + payload checksums) and
  `island_v2/preview.png`. Run with `python3 tools/island_v2/island_v2_generator.py` (numpy, scipy, Pillow).
- `island_v2_install.luau` (v1.0) — the staged Studio builder the payloads are cut from (`--@section` markers). Install: Studio
  in Edit, paste the payloads in order with execute_luau (00_begin … 99_finish); finish refuses unless every count matches.
- `island_v3/island_v3_generator.py` (v1.3) — DinoIsland 3.2 (2048 × 2048, hills, a 200-stud mountain with a trail, 45-stud murky lakes, coconut palms) from the
  same photo (`island_v3/reference_photo.webp`): writes `island_v3/payloads/NN_<stage>.luau`, `island_v3/manifest.json`
  (expected counts, payload checksums, data hashes) and `island_v3/preview.png`. Run with
  `python3 tools/island_v3/island_v3_generator.py` (`NO_PAYLOADS=1` = preview only).
- `island_v3_install.luau` (v1.3) — the staged builder the v3 payloads are cut from. Install as island 2.0; each stage returns
  `hash N`, which must equal `manifest.json` `hashes` for that payload.
