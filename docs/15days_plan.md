## Plan: Godot 4 Grid Crawler Prep

Build a jam-safe, reusable first-person grid crawler foundation in 15 days with focus on movement + view correctness first, then robustness and handoff readiness. This plan intentionally avoids game-specific content so it remains compliant prep work before theme reveal.

**Steps**
1. Day 1: Project bootstrap and control contract.
Deliverables: new Godot 4 project, input map for keyboard/gamepad/UI buttons, written command contract for `step_forward`, `step_back`, `strafe_left`, `strafe_right`, `turn_left`, `turn_right`.
Exit criteria: all command inputs trigger logging hooks in a test scene and no command is ambiguous.
2. Day 2: Canonical grid and facing state.
Deliverables: integer grid position model, cardinal facing enum, conversion helpers between grid and world transform.
Exit criteria: 50 random transform round-trips return exact grid cell and one of four valid headings.
3. Day 3: Snap movement and turning core.
Deliverables: movement controller executes one-cell steps and 90-degree turns only, with action gating.
Exit criteria: scripted command sequence yields exact expected final grid/facing state with zero drift.
4. Day 4: Smooth mode and reconciliation.
Deliverables: configurable snap/smooth toggles with step and turn durations; end-of-action hard snap to canonical state.
Exit criteria: switching snap/smooth at runtime preserves identical logical outcomes for the same command script.
5. Day 5: First-person camera sync.
Deliverables: camera follows authoritative movement/facing signals, strict cardinal orientation, no free-look.
Exit criteria: 100 move/turn loop keeps camera centered and angles locked to 0/90/180/270.
6. Day 6: GridMap occupancy extraction.
Deliverables: passability layer from GridMap (walls and closed doors blocked, floor passable).
Exit criteria: blocked moves return deterministic no-op and valid moves always commit exactly once.
7. Day 7: Unified input normalization.
Deliverables: keyboard, gamepad, and clickable UI direction buttons feed one command pipeline.
Exit criteria: same scripted scenario driven by each input method yields identical state history.
8. Day 8: Input queue and anti-overlap hardening.
Deliverables: one-command queue, overlapping tween protection, single completion signal per action.
Exit criteria: held-input stress test shows ordered commands only, no skips, no double-executes.
9. Day 9: Collision edge cases and deterministic feedback.
Deliverables: collision result events for UI/SFX hooks (`moved`, `blocked`, `turned`) with stable payload shape.
Exit criteria: event logs are consistent across 200 mixed actions and all blocked steps preserve state.
10. Day 10: Automated test harness baseline.
Deliverables: unit tests for passability/state transitions and integration tests for command sequencing + camera sync.
Exit criteria: headless test run passes reliably on repeat and reports no resource leak warnings.
11. Day 11: Scene transition input isolation shell.
Deliverables: placeholder inventory/combat/town scenes that pause exploration command processing.
Exit criteria: entering any placeholder scene guarantees zero movement until return to exploration.
12. Day 12: Config presets and tuning workflow.
Deliverables: snap and smooth config presets exposed for quick swap in inspector/testing scene.
Exit criteria: presets can be switched without code edits and pass full movement regression script.
Status: completed on 2026-03-13. Presets and workflow documented in `docs/day12_presets.md`.
13. Day 13: Build-readiness checks.
Deliverables: clean startup flow, stable scene ownership, reproducible run instructions.
Exit criteria: fresh open-and-run works without manual fixes and reaches exploration scene first try.

Day 13 execution checklist:
1. Startup flow hardening.
- Set and verify the primary run scene is the intended exploration entry.
- Remove or gate any temporary bootstrap/debug-only startup behavior that can hijack first-run flow.
- Confirm one-click run lands in exploration without manual editor steps.
2. Scene ownership and lifecycle sanity.
- Verify dynamic nodes created at runtime (overlays, temporary visuals, tween-driven helpers) are parented and freed deterministically.
- Ensure world scene contains authoritative ownership boundaries (player, grid/passability wiring, overlay shell).
- Confirm close/open overlay cycles do not leak nodes or duplicate handlers.
3. Input + command readiness pass.
- Validate input actions required for exploration and overlay transitions are present and documented.
- Confirm command gating behavior remains deterministic across scene transitions and first-run state.
- Re-run key Day 8-Day 11 behavior checks (queue, blocked feedback, overlay isolation).
4. Reproducible run instructions.
- Write a concise runbook in docs with exact "open project -> run -> expected first frame" behavior.
- Include required plugin assumptions (GUT enabled) and expected test entry command/path.
- Add troubleshooting notes for the 2-3 most likely first-run issues.
5. Validation and sign-off.
- Execute full automated test suite and record pass status.
- Perform a fresh-open manual smoke check and capture result.
- Mark Day 13 complete only when both automated and manual checks pass.
14. Day 14: Compliance rehearsal and checklist lock.
Deliverables: explicit jam-rule compliance checklist for first-person exploration, square-grid full steps, and cardinal turns.
Exit criteria: each checklist item is demonstrated in-engine and signed off in notes.
Status: completed on 2026-03-13. Checklist locked in `docs/day14_compliance_checklist.md`.
15. Day 15: Freeze template and handoff package.
Deliverables: stable prep template snapshot, concise technical README, prioritized post-jam-start backlog.
Exit criteria: template is ready to branch at jam start with no blocker defects in movement/view core.
Status: in progress on 2026-03-13. Baseline window/viewport and stretch policy locked in `project.godot`; theme-driven visual tuning remains deferred until reveal.

**Relevant files**
- New Godot project assets for scenes, scripts, and tests to be created during execution (exact paths chosen at implementation time).
- /memories/session/plan.md for iterative plan revisions.

**Verification**
1. Action correctness: every movement command results in exactly one-tile delta or no-op on block; every turn is exactly +/-90 degrees.
2. Compliance: exploration remains first-person and movement respects square-grid full-step constraints only.
3. Input parity: keyboard, gamepad, and clickable controls produce identical command outcomes.
4. Stability: no tween overlap glitches, no input-order corruption, no cumulative transform drift after long loops.
5. Regression safety: repeatable headless test run validates core movement/view behavior and collision invariants.

**Decisions**
- Included: single-character baseline, GridMap-first world representation, configurable snap/smooth movement and turning, keyboard+gamepad+clickable controls, wall/closed-door blocking, true lateral strafing.
- Deferred: enemy grid movement logic (tracked for post-foundation), mouse-look fallback, game-specific content, narrative/theme-specific mechanics.
- Scope boundary: this prep builds engine-like reusable systems only, not a specific jam game implementation.
- Verticality decision: single-floor grid for prep template; multi-level support is explicitly out of scope for this 15-day phase.