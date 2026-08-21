# Changelog

All notable changes to GoPlacer are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows [Semantic Versioning](https://semver.org).

---

## [Unreleased]

---

## [0.1.1] — 2026-06-04

### Added
- Square tile layout for palette entry grid (`fixed_column_width`, `fixed_icon_size`)
- Mesh Picking toggle in Settings — skip expensive mesh-face raycast pass when disabled (default: on)
- Ghost material caching — single `StandardMaterial3D` shared across all ghost surfaces
- GdUnit4 test suites for `SnapHelper`, `InstanceFactory`, and `GhostManager`
- Palette discovery now scans `res://` and `res://palettes/` recursively
- `ResourceLoader.exists()` type-hint filtering — skips non-palette `.tres` files without loading them
- Debounced `filesystem_changed` callback (1s cooldown) — avoids re-scanning on every file save

### Fixed
- Ghost preview now visible without a Node3D selected in the viewport (`_handles()` always returns `true`)
- Placed instances now use correct world-space coordinates when the target parent has a non-identity transform (`global_transform` set after `add_child`)
- Ghost basis resets to identity when normal returns to `Vector3.UP` after wall/ceiling placement
- `apply_placement_transform` uses dot-product threshold (0.999) for near-UP normal detection
- Hit normal explicitly reset to `Vector3.UP` on floor plane fallback (no stale surface normals)
- `EditorResourcePreview` thumbnails now use `preview` arg as primary icon, `thumbnail` as fallback
- `queue_edited_resource_preview` used for assets without a `resource_path`
- Restored accidentally deleted `_on_normal_align_toggled`, `setup()`, `set_plugin()`, and member variable declarations

### Removed
- Floor Snap and Surface Snap checkboxes — dead settings never consumed by the raycast pipeline

---

## [0.1.0] — 2026-06-03

### Added
- Bottom dock panel with Palettes and Settings drawers
- Palette auto-discovery from `res://palettes/`, auto-refresh on filesystem changes
- Palette CRUD: create, delete, add/remove entries via drag-and-drop from FileSystem dock
- `EditorResourcePreview`-based thumbnail generation for palette entries
- Entry selection → placement FSM: IDLE → PREVIEWING → DRAG_ROTATE → back to PREVIEWING
- Ghost preview: semi-transparent blue material, collision disabled, raycast exclusion
- 3-layer raycast cascade: physics (with Area3D) → mesh-face Moller–Trumbore → floor plane (Y=0) fallback
- Face normal direction guarantee: mesh normals always face toward camera
- Surface snapping with normal alignment: Y-up aligns to outward surface normal
- Azimuth gizmo: yellow arc + forward direction line during drag-rotate
- Ctrl-held position snapping (configurable grid) and azimuth snapping (rotation snap dropdown)
- AABB flush offset: objects sit flush on surfaces using support-function projection (toggle in Settings)
- Target parent auto-detection (`GoPlacerParent` node) and manual override in Settings
- Undo/Redo integration for every placement via `EditorUndoRedoManager`
- `InstanceFactory` — shared utility for creating instances from palette entries
- `GhostManager` — extracted ghost lifecycle (spawn, clear, RID collection, collision disable, material overlay)
- `PlacementGizmo` — extracted gizmo rendering (arc mesh, line mesh, positioning)
- `PlacementController` — cleaned up, dead code removed, public getters for settings
- Social content template and queue system (`docs/internal/social/`)
- Copilot instructions (`docs/internal/copilot-instructions.md` + `AGENTS.md`)
- CI pipeline: `gdparse` + `gdlint` on every push/PR via GitHub Actions
- Release scripts: `scripts/release.sh`, `scripts/release-dev.sh`, `scripts/release/prepare_release_notes.sh`

### Changed
- Normal alignment now correctly orients Y-up to surface normal (was pointing -Z along normal)
- AABB flush offset computes using inward-facing support function (adapted from GoBuild)
- Committed instances now copy ghost transform directly (prevents double AABB offset)
- `plugin.gd` reduced from 454 lines to ~200 lines by extracting `GhostManager`, `PlacementGizmo`, `InstanceFactory`
- Private field access replaced with public getters on `PlacementController`