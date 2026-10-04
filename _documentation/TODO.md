# Shards of the Arcanum — Feature & Architecture Roadmap (TODO)

## 1. Combat System & Tactical Depth

- [ ] **Default / Auto Actions** | needs to be some way of having the player do actions like move, attack, or use items without having to explicitly say so.

---

## 2. Dungeon Traversal & Skill Interactions

- [ ] **Skill-Based World Interaction Engine**
  - **Lockpicking**: Interactive door/chest lockpicking minigame or stat check using `DEX` and `Lockpicking.tres`.
  - **Stealth / Search**: Toggle active search mode to reveal hidden wall buttons, phantom data sectors, and secret passages using `PER`.
  - **Hazard Mitigation**: Environmental hazard tiles (Arcane Pollution, Electrified Server Racks, Poison Gas) dealing field damage or applying debuffs.
- [x] **Interactive Dungeon Objects**
  - Interactive Keycard Terminals, Hackable Nodes, Loot Containers, and Elevators connected to `MapManager.gd`.

---

## 3. Party Roster & Character Creation

- [ ] **Character Creation Flow Scene**
  - Point-buy / attribute rolling system for base stats (`STR`, `INT`, `PIE`, `VIT`, `DEX`, `SPD`, `PER`).
  - Breed (`CatBreed`) and Profession (`ProfessionData`) selection UI with real-time requirement validation.
  - Portrait assignment and character naming.

- [ ] **Roster Management UI**
  - Tavern/Hub interface to recruit, bench, or swap members between active party slots (1–6) and stored roster via `RosterSaveSystem.gd`.
- [] **Party Management & Placement** Adjust Battle HUD pictures to put front row on left and backrow on the right. Or some way of delimitating who is front / back from the HUD view.

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

- [ ] **CRT / DOS Terminal SubViewport Pipeline** (IDK about this)
  - Render the 3D dungeon view inside a windowed `SubViewportContainer` with a retro DOS/CRT shader overlay (scanlines, chromatic aberration, curvature).
- [ ] **Terminal Dialogue & Interrogation System**
  - ANSI/ASCII-inspired dialogue interface for Guild-Corp contacts and competitive street faction NPCs.
- [ ] **Expansive Elements** | The inventory grid needs to be able to go "full screen". So it pushes everything else out of its way. It CANT just be modal because they need to be able to drag items onto their character.

---

## 6. Fixes / Updates

- [ ] **LEVEL SWAP** : moving from the forest to the dungeon, the fog doesnt show back up in the dungeon.
- [ ] **Forest Level**: needs to add in some kinda grass shader, mushroom models, and some other small details. Need to add in the "crash site" location.
- [ ] **Forest Level**: Decide where the level exits actually go to.
- [ ] **WINDMILL**: the windmill isnt animating and doesnt do anything / go anywhere.
- [ ] **Walking upstairs** | like when you go on a bridge should make your camera go up just slightly until you get off the bridge.

---

## 7. LORE

- [ ] **INTRO** : the intro movie that explains how you end up on the planet.
