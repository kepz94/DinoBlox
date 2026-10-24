# Tools

- `trex_generator_v3.luau` — the original generator that built the T-Rex (preset B, v1.0 and v1.1 StripeEye)
  with the 13-joint rig. Kept for history and as the starting point for new species. It does **not** include the
  rig v1.2 knee/ankle split or the player-character changes; the exact current T-Rex is
  `src/shared/Models/TRexModelData.luau` (rebuild with `DinoModelBuilder`).
- `ik_check_run.py` — offline check of the walk/run knee IK (reach, planted feet, toe clearance, flight %)
  using the T-Rex leg measurements. Run with `python3 tools/ik_check_run.py`.
- `ik_check_creep.py` — offline check of the creep gait and crouched stance (WalkPose 3.1): reach, planted feet,
  toe clearance, knee range, stance foot error. Run with `python3 tools/ik_check_creep.py`.
