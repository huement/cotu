# STATUS

# SHARDS OF THE ARCANUM / VENEFEX - System Documentation

This document provides a comprehensive overview of the core features and architectural components built for the Godot 4 first-person dungeon crawler project (**Shards of the Arcanum / VENEFEX**).

---

## 1. CHARACTERS

### Party System & Row Positioning
* **6-Slot Party Roster:** The party consists of up to six characters divided into two rows:
  * **Front Row:** Takes the brunt of physical melee attacks and acts as a defensive line.
  * **Back Row:** Moore Protected, receive 50% of the enemies attack but player physical attacks deal 50% of damage; ideal for ranged damage dealers, casters, and support.
  * The player controls what party members are in what row, at least **one** party member must be in the **FRONT**
* **Data-Driven Races & Classes:**
  * **Races (`Data/Races/`):** Space Cat species (e.g., Abyssinian, Bengal, Bobcat, Bobtail, Liger, Ocelot, Persian, Savannah, Siamese, Sphynx, Tabby) compiled from CSV data (`Character_Races.csv`) into native Godot `Resource` files.
  * **Classes (`Data/Classes/`):** Character archetypes (e.g., Ghostblade, Ronin, Voidhand, Warden, Wizard, Amazon, Archanist, Crusader, etc.) configured via `.tres` Resource files.

### Primary Attributes (`character_stats.gd`)
* **Static Attributes:** All stats use GDScript 2.0 static typing (`var stat: int = 10`):
  * **STR (Strength):** Determines melee damage output and physical force.
  * **INT (Intelligence):** Influences arcane magic effectiveness and spell points.
  * **PIE (Piety):** Affects divine/holy spell power and status resistance.
  * **VIT (Vitality):** Controls max hit points and damage mitigation.
  * **DEX (Dexterity):** Dictates hit accuracy, critical chance, and skill checks (e.g., Lockpicking).
  * **SPD (Speed):** Sets initiative turn ordering during combat.
  * **PER (Perception):** Helps detect secrets, traps, and hidden paths.

### Skills & Spells
* **Modular Abilities:** Abilities are created as standalone `Resource` objects (`SkillData.gd`, `SpellData.gd`).
* **UI Integration:** Displayed and managed via dedicated UI panels (`SkillsSpellsPanel.gd` and `SkillSpellEntry.tscn`).

---

## 2. BATTLE

### Phased Turn-Based Combat (`CombatManager.gd`)
* **Two-Phase Action Loop:**
  1. **Planning Phase:** Players assign commands (Attack, Cast, Skill, Item, Guard, Run) for each party member.
  2. **Execution Phase:** Commands from both the party and enemy groups (`EncounterGroup.gd`) execute sequentially based on Speed/Initiative.
* **Position & Targeting Logic:**
  * Melee attacks respect row positions (Front Row targeting preferred).
  * Spells (`PlasmaDart.tres`, `PurrHealing.tres`) and ranged skills ignore front-row restrictions unless specified.
* **Enemy Encounters:**
  * Enemy formations are defined using `EnemyGroupData.gd` and individual `EnemyData.gd` resources.
  * Visual representations are managed dynamically in 3D using `EnemyVisualManager.gd`.

### Decoupled Combat UI (`SignalBus.gd`, `BattleHUD.gd`)
* **Signal-Driven Architecture:** `CombatManager.gd` never directly manipulates UI elements. Instead, events emit signals through `SignalBus.gd` (e.g., `character_damaged`, `turn_started`, `battle_ended`).
* **UI Responsiveness:** `BattleHUD.gd` listens to the global signal bus and updates health bars, action buttons, and battle logs independently.

---

## 3. GAME LOGIC (SAVING, UI ETC)

### Grid-Based Movement & Navigation (`player.gd`, `GridCommand.gd`)
* **Tile-by-Tile Navigation:**
  * Movement is locked to a 3D grid, using `Vector3` directions mapped to cardinal headings (North, South, East, West).
  * Smooth step translation and 90-degree camera rotations are driven by Godot's `Tween` node.
  * Collision detection is handled via `RayCast3D` nodes checking tile boundaries prior to movement, avoiding physics heavy `CharacterBody3D` jitter.
* **Minimap Camera:**
  * A dedicated `minimap_camera.gd` tracks the player from an overhead perspective to render the dungeon layout.

### Game State & Logging
* **State Management (`GameState.gd`):** Tracks global flags, current location, active quests, and environment interactions.
* **System Logging (`GameLogger.gd`):** Records game events and feeds them to the DOS/UNIX terminal-styled log UI.

### Save & Progression System (`RosterSaveSystem.gd`)
* Serializes character stats, party configuration, and inventory states into standard disk data for loading/saving roster progress.
* LEVEL UP | Killing Enemies drops [GOLD, EXP, LOOT] 

### Utility & Compilers (`DataCompiler.gd`, `RaceCompiler.gd`)
* Pipeline tools that parse master spreadsheet data (`Character_Classes.csv`, `Character_Races.csv`) and automatically update Godot `.tres` Resource files in `Data/Classes/` and `Data/Races/`.

### UI FEATURES
+ BATTLE HUD | entering battle triggers a unique Heads Up Display allowing quick fights and easy access to combat commands
+ TOAST Notifications | Popups that show temporary messages such as battle damage or the results from skills and spells
+ Character Stat Screen
  + Equipment Management | Swap in and out equipment. See the results update the stat display instantly. 
  + 6 Slots + 2 Accessories Including 2 HANDED Combat Items

---

## 4. ITEMS AND EQUIPMENT

### Resource-Driven Item Architecture (`item_data.gd`, `inventory.gd`)
* **Resource Items:** Every item is defined as an individual `.tres` asset extending `item_data.gd`.
* **Inventory Management (`inventory.gd`):** Manages item storage, stacks, and categorization without hardcoding item logic into UI or Player scenes.

### Item Categories & Equipment Slots
* **Weapons:** `LaserClaw.tres`, `katana.png` (referenced texture), `bolt.png` (referenced texture).
* **Armor:** `PowerSuit.tres`, `helmet.png`, `gauntlet.png`, `pants.png` (referenced textures).
* **Accessories & Artifacts:** `Charm.tres`, `ring.png`, `orb.png`, `cadecus.png` (referenced textures).
* **Consumables:** `CatnipPotion.tres`, health items.

### Inventory & Loadout UI
* **Inventory Grid (`character_inventory_grid.gd` & `ItemSlot.tscn`):** Renders item slots dynamically in a scannable grid.
* **Loadout Panel (`character_loadout_panel.gd`):** Handles equipping items onto specific body slots per party member.
* **Node Referencing:** Uses Godot 4 SceneUniqueNodes (`%`) for fast, robust node access in UI scenes.


----

## TODO LIST

### LEVELING
1. SKILLS AND SPELLS CUSTOMIZATION + LEVEL UP SCREEN
2. CHARACTER LEVEL UP SCREEN

Right now characters can collect EXP Points to increase their level, but when they reach the requirements, there is no logic to advance them to the next level. Upon Leveling they should receive stat bonuses, and advance their skill and spell levels / abilities. For instance every 3 levels they can learn a new skill or spell. Every other level they can increase the level of a single skill or spell by 1. 

### SPELL BOOKS
1. Requirements | what spells will be available and at what level needs to be coded. 
2. What spells are available in the game. Enemies and players alike will draw from the same spell books. 

### RANGED WEAPONS
1. Nothing is strong or weak to ranged weapons, instead they work on a critical damage dice roll to be strong or weak versions of the attack. 
2. Advanced Skills and Loot drop will yield special ammo that has ELEMENT type damage (fire arrows etc)

### PHYSICAL ATTACKS
1. Advanced Fighting skills allow multi strike attacks. Essentially granting two - three rounds per each turn. 
2. Combos ? | Potentially each attack uses the previous attack as a ‘multiplier’ so if the first hit was hard the second is harder etc. 

### ENEMIES
1. Unique Creature Types | Some enemies will be ‘creature’ type, and will only have a single skill or spell that levels with them. Optionally they can a strong and weak element, for instance a ‘fire’ type enemy will always deal fire damage + physical damage and cast a leveled offensive fireball spell, and will be weak to water attacks. Creatures are also all weak to BLADE. 
2. Cat Types | Random ‘characters’ will be generated that share the same classes and races the player can choose from. They use whatever skills and spells their class has and carry armor typical to that class. Optionally they can also have the “INFECTED” attribute where they are then weak to Physical attacks [BLADE, BASH]

Right now there is only 1 ‘INFECTED’ Creature prototype that needs to be expanded. Just like the other systems there will be a spreadsheet that can be updated to control what enemies are generated. 

+ Nice to have | Enemies have a ‘random’ element, such as having a white model that gets a color applied to it, allowing for random colored enemies, or a pool of ‘parts’ that the game pulls from allowing for a fixed but LARGE amount of options if given enough potential combinations. Using scripts to generate textures, or using Shaders as texture to make them shimmery / animated look and feel. 

### GAMEPLAY

There are a number of smaller features that are present in the UI but not yet wired in. 

1. SEARCH BUTTON | In the world view, players can ‘search’ an area an find environmental items. The item list needs to be created and the % change setup. 
2. Environmental Skills / Spells | There are skills like, make arrows, and potentially a REVIVE that works outside battle. Right now casting spells or doing skills outside of battle does not work. Spells to Enchant Armor? Forever or Temporary? 
3. Equipment Damage & Repair | equipment has a ‘durability’ value but its not being subtracted from after battle or over time, and then when it is, there is no way to repair yet either. 
4. CHARACTER SCREEN SKILLS & SPELLS PANEL | This is pretty rough looking…
   1. when a spell/skill is selected a popup should appear with details and description. if its an environmental spell, also has button to cast it / perform it. 
   2. View Spellbook and Master Scrolls for given class. Showing all possible spells and skills a class can learn. 

#### BATTLE MOODE
1. DEFEND BUTTON | There is a defend button that does nothing. Should allow blocking / reduce damage
2. RUN BUTTON | This button needs to allow to escape a battle
3. ANIMATIONS | We at least need basic animations for spells, skills, and attacks. 
4. ENEMY AI | smarter enemies that get better as the game progresses (using magic more and more etc)

#SpaceCats