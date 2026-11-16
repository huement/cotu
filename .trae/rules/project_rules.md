# Project Rules & Context: Shards of the Arcanum / VENEFEX

## Project Overview

- **Engine:** Godot 4.x (Latest Stable)
- **Language:** GDScript 2.0 with mandatory static typing (`var hp: int = 10`, `func cast() -> void:`)
- **Genre:** 1st-person grid-based dungeon crawler (Blobber RPG) with 6-character turn-based combat.
- **Architecture Philosophy:** "Composition over Inheritance" — use lightweight Node/Node3D components attached to entities instead of deep inheritance trees.

## Directory & File Structure

- `res://Core/`: Core global singletons (`GameState.gd`, `SignalBus.gd`, `GameLogger.gd`).
- `res://Scripts/3D/`: 3D visual rendering managers (`EnemyVisualManager.gd`).
- `res://Scripts/Enemies/`: Enemy logic, AI, and encounter definitions.
- `res://Scripts/Grid/`: Grid movement commands and definitions (`GridCommand.gd`).
- `res://Scripts/Managers/`: Game systems (`CombatManager.gd`, `MapManager.gd`).
- `res://Scripts/Resources/`: Custom resource data schemas (`item_data.gd`, `inventory.gd`, `EnemyData.gd`, `SkillData.gd`, `SpellData.gd`).
- `res://Scripts/UI/`: Decoupled battle HUDs, loadout panels, and inventory grids.
- `res://Scripts/Utilities/`: Editor CSV compilers (`DataCompiler.gd`, `RaceCompiler.gd`).

## Coding & Architectural Conventions

### 1. Nodes & UI Access

- Always use Scene Unique Nodes (`%` prefix, e.g., `%HealthBar`) for UI elements and key component references.
- Keep UI strictly decoupled from combat logic. `CombatManager.gd` must NEVER modify UI directly; communicate strictly via `SignalBus.gd` events (e.g., `SignalBus.character_damaged.emit()`).

### 2. Data & Content Pipeline

- Stats, Items, Spells, Classes, and Races are stored as Godot `.tres` Resource files.
- Master data originates from CSV files in `res://Data/` and is compiled into `.tres` files via utility compilers.
- When creating new data schemas, extend `Resource` and export typed properties (`@export var energy_cost: int`).

### 3. Grid Traversal & Physics

- Movement must remain strictly tile-by-tile on a 3D grid using `Vector3` cardinal directions.
- Use `Tween` for camera smooth-stepping and 90-degree rotations.
- Use `RayCast3D` for wall collision checks rather than physics-driven `CharacterBody3D` nodes to avoid physics jitter.

### 4. Turn-Based Combat Rules

- Party consists of 6 slots split into Front Row (Slots 1–3) and Back Row (Slots 4–6).
- Melee weapons (`BLADE`, `BASH`) are subject to row positioning constraints.
- Spells and ranged skills scale dynamically (`Total Duration = Base Duration * Spell Level`).
- Target types follow enum standard: `SINGLE_ENEMY` (0), `ALL_ENEMY` (1), `SINGLE_ALLY` (2), `ALL_ALLY` (3), `SELF` (4), `NONE` (5).
