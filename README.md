```text
																				.
                                        / \
                                       |   |
                                    _  |   |  _
                    ____           | | |   | | |           ____
        _____      / ___| __ _ _   | | |   | | |   _ _ _  / ___|      _____
       / ___ \    | |    / _` | |  | | |   | | |  | | | | | |         / ___ \
      / /   \ \   | |   | (_| | |__| | |   | | |__| | | | | |___     / /   \ \
      | |   | |   | |___ \__,_|\____/   \_/   \____/|_| |  \____|    | |   | |
      \ \___/ /    \____|           THE CLAWS           |_|          \ \___/ /
       \_____/                O F  T H E  U N D Y I N G               \_____/
                                  (GODOT 4 BLOBBER)
                                         |
                                         |
                                       _/ \_
                                       \   /
                                        \_/
```

# THE CLAWS OF THE UNDYING

A first-person, grid-based "blobber" RPG built in **Godot 4**.

> "The stone does not bleed, yet the walls of the labyrinth weep for those who entered and never returned. Descend, Torchbearer. The Undying awaits."

---

## 🌑 Overview

**The Claws of the Undying** is a dungeon crawler inspired by classics like *Wizardry* and *Shin Megami Tensei*. It focuses on atmospheric exploration, tactical turn-based combat, and the claustrophobic tension of navigating a lethal, tile-based underworld.

## ⚔️ Core Features

* **Grid-Based Movement:** Authentic 90-degree turning and step-by-step navigation.
* **Godot 4 Rendering:** Utilizing Forward+ rendering, volumetric fog, and SDFGI for a modern-yet-gritty aesthetic.
* **Blobber Mechanics:** Control a full party of adventurers acting as a single unit ("the blob").
* **Turn-Based Combat:** Tactical RPG encounters where resource management is critical.
* **Dark Fantasy Setting:** A hand-crafted descent into the lair of a forgotten deity.

## 🕯️ Getting Started

### Prerequisites
* **Godot Engine 4.x** (Standard or .NET)

### Installation
1. Clone the repository:
   ```bash
   git clone [https://github.com/huement/cotu.git](https://github.com/huement/cotu.git)
	 ```
	 
2. Open Godot 4 and select Import.

3. Locate the project.godot file in the cloned directory.

4. Press F5 to run the project.

## 🕹️ Controls
W / Arrow Up: Move Forward

S / Arrow Down: Move Backward

A / D: Turn Left / Right

Q / E: Strafe Left / Right

Space / Enter: Interact

Tab: Menu / Inventory

Esc: Pause

## 🗺️ Development Roadmap
[ ] Implement Party Creation System

[ ] Enemy AI and Pathfinding

[ ] Dynamic Lighting & Torch Mechanics

[ ] Automap System with Fog of War

[ ] Loot and Equipment Tables

## Directory Structure

```shell
res://
├── .godot/           <-- (AUTO-GENERATED: Never touch/commit this)
├── Assets/           <-- Raw 3D models (.glb), Textures, and Audio
├── Core/             <-- Autoloads (SignalBus.gd, GameState.gd)
├── Data/             <-- Your .tres Resource files (Cat stats, Spells)
│   ├── Breeds/
│   ├── Classes/
│   └── Items/
├── Scenes/           <-- Combined scenes and their logic scripts
│   ├── Combat/       <-- Phased combat UI and controllers
│   ├── UI/           <-- CRT overlay, party windows
│   └── World/        <-- Dungeon levels and environment
└── Scripts/          <-- Standalone components (Movement, Stats)
```

## 📜 License
Distributed under the MIT License. See LICENSE for more information.

## Extra
Developed by [https://huement.com](https://huement.com). Built with Godot 4.