# Shards of the Arcanum — Feature & Architecture Roadmap (TODO)

## 1. Combat System & Tactical Depth

- [ ] **Front Row / Back Row Combat Mechanics**
  - Restrict short-range melee weapons (`BLADE`, `BASH`) to hitting/being hit from Front Row (Slots 1–3).
  - Allow Reach/Ranged weapons (`RANGED`, `MAGITEK_RAILGUN`, `PLASMA_DART`) to target Back Row (Slots 4–6).
- [ ] **Phased Command Combat Execution**
  - Implement a full Command Phase where all 6 party members select their actions upfront before turn execution begins.
  - Execute turn queue resolution sequentially based on calculated initiative/speed rolls.
- [ ] **Auto-Combat Automation System (RAID-Style)**
  - Add an Auto-Combat toggle in `BattleHUD.gd` for trash mob encounters.
  - Implement basic AI action priority rules (e.g., Use basic attacks, conserve MP, do not use consumables).
  - Automatically disable Auto-Combat when encountering Boss or Named Hostiles.
- [ ] **Visual Status Effect Overlay**
  - Add status effect icons and turn duration counters to `PartySlotPortrait.tscn` and `EnemyVisualManager.gd` (Poison, Stun, Shield, Haste, Debuff).

---

## 2. Dungeon Traversal & Skill Interactions

- [ ] **Skill-Based World Interaction Engine**
  - **Lockpicking**: Interactive door/chest lockpicking minigame or stat check using `DEX` and `Lockpicking.tres`.
  - **Stealth / Search**: Toggleable active search mode to reveal hidden wall buttons, phantom data sectors, and secret passages using `PER`.
  - **Hazard Mitigation**: Environmental hazard tiles (Arcane Pollution, Electrified Server Racks, Poison Gas) dealing field damage or applying debuffs.
- [ ] **Interactive Dungeon Objects**
  - Interactive Keycard Terminals, Hackable Nodes, Loot Containers, and Elevators connected to `MapManager.gd`.

---

## 3. Party Roster & Character Creation

- [ ] **Character Creation Flow Scene**
  - Point-buy / attribute rolling system for base stats (`STR`, `INT`, `PIE`, `VIT`, `DEX`, `SPD`, `PER`).
  - Breed (`CatBreed`) and Profession (`ProfessionData`) selection UI with real-time requirement validation.
  - Portrait assignment and character naming.
- [ ] **Party Formation & Roster Management UI**
  - Tavern/Hub interface to recruit, bench, or swap members between active party slots (1–6) and stored roster via `RosterSaveSystem.gd`.

---

## 4. Cyberware Implants & Guild-Corp Economy

- [ ] **Cybernetic Implant System**
  - Equipment slots specifically for illegal cyberware upgrades providing major stat buffs.
  - Ostracization / Overt Tracking Mechanic: High cyberware usage reduces diplomacy / Guild-Corp reputation or triggers scanner encounters.
- [ ] **Quartermaster Shop & Contract Board UI**
  - Buy/Sell/Upgrade gear interface using party credits.
  - Contract selection terminal in the Guild-Corp basement hub for "Monster of the Week" mitigation gigs.

---

## 5. Retro Cyberpunk UI/UX & Game Juice

- [ ] **CRT / DOS Terminal SubViewport Pipeline**
  - Render the 3D dungeon view inside a windowed `SubViewportContainer` with a retro DOS/CRT shader overlay (scanlines, chromatic aberration, curvature).
- [ ] **Terminal Dialogue & Interrogation System**
  - ANSI/ASCII-inspired dialogue interface for Guild-Corp contacts and competitive street faction NPCs.
- [ ] **Sound Effects & Audio Signal System**
  - Connect audio triggers to `SignalBus.gd` for footsteps, melee swings, spell impacts, button clicks, and camera shake bursts.
