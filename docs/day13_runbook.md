## Day 13 Runbook

### Startup Expectation
- Primary run scene: `res://scenes/title/title_screen.tscn`
- Expected first frame after Run:
- Title screen is visible with Start Game and Quit options.
- After selecting Start Game, gameplay loads `ManualTestWorld`.
- Player spawns in exploration world at origin-facing north baseline.
- GridMap is visible and passability wiring completes (occupancy log prints once).
- Overlay shell is loaded, but debug panel is hidden by default unless `show_debug_panel` is enabled on `ManualTestWorld`.

### Manual Run (Godot Editor)
1. Open the project in Godot 4.
2. Press Run Project (or `F5`).
3. Verify startup lands on the title screen with no scene picker or manual scene open step.
4. Select Start Game and verify transition into ManualTestWorld.
4. Optional smoke checks:
- Movement actions (`move_forward`, `move_back`, `move_left`, `move_right`, `turn_left`, `turn_right`) respond.
- Overlay actions (`open_inventory`, `open_combat`, `open_town`, `close_overlay`) work and movement is isolated while overlays are active.

### Automated Tests (VS Code)
1. Open Command Palette.
2. Run command: `GUT: Run All Tests`.
3. Wait for completion and confirm no failures.

### Troubleshooting
1. Runs into an unexpected scene or blank startup.
- Verify `project.godot` has `run/main_scene="res://scenes/title/title_screen.tscn"`.
- Reopen project so editor cache picks up updated startup settings.

2. Movement seems blocked at startup.
- Confirm no overlay is open.
- If testing from editor with modified scene state, restart scene (`F6`) or rerun project (`F5`) to reset runtime state.

3. GUT command not available in VS Code.
- Ensure the GUT VS Code extension is installed and enabled.
- Confirm Godot project opened at workspace root and plugin is enabled in `project.godot` under `[editor_plugins]`.
