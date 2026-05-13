## Day 14 Compliance Rehearsal Checklist (Locked)

Date: 2026-03-13
Scope: Jam-rule compliance rehearsal for first-person exploration, square-grid full steps, and cardinal turns.

### Checklist
- [x] Exploration is first-person and camera remains player-centered.
- [x] Traversal moves are full-cell steps only (no partial drift, no fractional grid commits).
- [x] Rotation is cardinal-only quarter turns (90-degree increments).
- [x] Blocked movement is deterministic no-op (state preserved).
- [x] Input paths still route through one command pipeline and respect Day 11 overlay isolation.

### Evidence
- First-person camera + cardinal lock:
- [tests/test_player_day5_camera_sync.gd](tests/test_player_day5_camera_sync.gd)
- [tests/test_player_day10_camera_blocked.gd](tests/test_player_day10_camera_blocked.gd)
- [tests/test_day14_compliance_rehearsal.gd](tests/test_day14_compliance_rehearsal.gd)
- Full-step traversal + deterministic no-op on block:
- [tests/test_player_day3_movement.gd](tests/test_player_day3_movement.gd)
- [tests/test_passability_scenarios.gd](tests/test_passability_scenarios.gd)
- [tests/test_day14_compliance_rehearsal.gd](tests/test_day14_compliance_rehearsal.gd)
- Cardinal quarter turns only:
- [tests/test_facing_transitions.gd](tests/test_facing_transitions.gd)
- [tests/test_player_day3_movement.gd](tests/test_player_day3_movement.gd)
- [tests/test_day14_compliance_rehearsal.gd](tests/test_day14_compliance_rehearsal.gd)
- Day 11 input isolation remains intact:
- [tests/test_player_day11_scene_transitions.gd](tests/test_player_day11_scene_transitions.gd)

### Rehearsal Sign-Off
- [x] Automated checks executed (full GUT suite).
- [x] Compliance checklist reviewed and locked.
- [x] Day 14 exit criteria satisfied.
