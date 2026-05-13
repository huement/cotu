## Day 12 Presets and Tuning Workflow

Date: 2026-03-13

### Presets
- Snap preset: `res://resources/presets/movement_config_snap.tres`
- Smooth preset: `res://resources/presets/movement_config_smooth.tres`

### Quick Swap Workflow (Inspector)
1. Open `ManualTestWorld` scene.
2. Select the root node with script `main.gd`.
3. In Inspector, set `active_movement_preset` to `Snap` or `Smooth`.
4. Run project (`F5`) to apply chosen preset at startup.

### Notes
- Preset application is centralized in `apply_movement_preset` on world script.
- Preset values are copied into the player runtime config, so tuning can be done by editing preset resources only.
- This keeps preset swapping code-free during manual tuning sessions.

### Verification
- Preset resources and swap behavior are covered by:
- `tests/test_day12_presets.gd`
- Existing movement regressions in `tests/test_player_day3_movement.gd`
