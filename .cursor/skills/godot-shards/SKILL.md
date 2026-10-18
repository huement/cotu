---
name: godot-shards
description: Run Shards in Godot 4.5, capture logs/screenshots, query Godot docs, and use the Godot MCP. Use when launching the game, debugging GDScript, inspecting scenes, running GUT, or looking up Godot 4.x APIs.
---

# Shards / Godot 4.5 workflow

## Binaries

- Godot: `/Applications/Godot.app/Contents/MacOS/Godot` (symlink: `godot`)
- Project root: directory containing `project.godot`

## Look at the game (preferred)

From the repo root, using the game-development skill:

```bash
node /Users/eris/.claude/skills/game-development/game.mjs run
node /Users/eris/.claude/skills/game-development/game.mjs logs --errors
node /Users/eris/.claude/skills/game-development/game.mjs shot
node /Users/eris/.claude/skills/game-development/game.mjs stop
```

`SCRIPT ERROR:` lines with `res://` paths map to workspace files.

## Direct Godot commands

```bash
godot --path . --editor
godot --path .
godot --path . --headless --quit-after 2
godot --path . --headless -s addons/gut/gut_cmdln.gd
```

## Docs

Use Context7, not training-data guesses for Godot 4.5 APIs:

1. `resolve-library-id` only if needed
2. `query-docs` with `libraryId` `/godotengine/godot-docs` (or `/godotengine/godot-docs/__branch__4.5`) and `language` `gdscript`

## Godot MCP

When the `godot` MCP namespace is connected, prefer it for:

- `get_godot_version`, `get_project_info`, `list_projects`
- `launch_editor`, `run_project`, `get_debug_output`, `stop_project`
- Scene/node edits: `create_scene`, `add_node`, `save_scene`, `load_sprite`, `export_mesh_library`
- Godot 4.4+ UIDs: `get_uid`, `update_project_uids`

Pass this project's path (`/Users/eris/Developer/_Godot/shards`) to project-scoped tools.

If the MCP namespace is missing, fall back to the CLI commands above and tell the user to enable **godot** under Cursor Settings → MCP.
