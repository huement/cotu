# Revised Overworld Topology (MVP Alignment)

Source diagram: `assets/MAP_DIAGRAM-*.png` (chat / Cursor assets). This markdown is the agent-facing reference — prefer it over the image.

## Legend

| Tag | Meaning |
|---|---|
| **Starter** | Tutorial / beginning map |
| **Built** | Existing Godot zone |
| **Town (MVP)** | Greco-Roman forest hub town goal |
| **Ruins (MVP)** | Above-ground dungeon goal |
| **Interstitial** | New forest buffer between built zones |
| **Water barrier** | Hard natural block (not a travel route) |
| **Future** | Planned / not required for current MVP |

## Hub model

**Feroshaw** is the main crossroads. Almost every other outdoor zone hangs off one of its gates. The starter grove is a one-way tutorial feed into Feroshaw from the north.

```
                         GREEN GROVE
                       (Starter / Tutorial)
                              |
                         Tutorial Exit
                              v
  Forgotten Ruins <-- Witch's Hollow <-- VEROWOOD <-- West Gate(2) --+
  (Ruins MVP)         (Interstitial)      (Built)                    |
                                                                     |
  RED CRAG <-- Trail Exit(8) -- STONE TRAIL <-- SW Pass(4) -- FEROSHAW
  (Future)                      (Built)                      (Built hub)
                                                                     |
                              +-- Well(1) --> LESSER WILDS --(LH)--> SUNKEN MERE
                              |                 (Built)              (Water barrier)
                              |
                              +-- East Gate(3) --> EAST MARSH ----> SYLVANIA
                                                   (Buffer)          (Town MVP)
```

## Zones

### Green Grove — Starter / Beginning Map
- **Scene:** `Scenes/GreenGrove.tscn`
- **Role:** Safe first walk. No enemies on first visit; weak Slime Drones on return visits.
- **Exits:** Tutorial Exit → **Feroshaw** only.
- **Does not connect to:** Stone Trail, VeroWood, or anything else.

### Feroshaw — Main Crossroads Hub (Built)
- **Scene:** `Scenes/FeroShaw.tscn`
- **Role:** Central outdoor hub after the tutorial.
- **Gates (diagram IDs):**
  | ID | Gate | Destination |
  |---|---|---|
  | — | North / Tutorial entry | From **Green Grove** |
  | 2 | West Gate | **VeroWood** |
  | 3 | East Gate | **East Marsh** |
  | 4 | SW Pass | **Stone Trail** |
  | 1 | Well | **Lesser Wilds** |

### VeroWood — Dense Forest (Built)
- **Scene:** `Scenes/VeroWood.tscn`
- **Connections:** East Gate(6) ↔ Feroshaw · West Path(7) → Witch's Hollow

### Witch's Hollow — Deep Cursed Woods (Interstitial / planned)
- **Role:** Buffer forest between VeroWood and Forgotten Ruins.
- **Connections:** VeroWood ↔ Forgotten Ruins

### Forgotten Ruins — Above-Ground Dungeon (MVP goal)
- **Connections:** East ← Witch's Hollow · South Exit (future)

### Stone Trail — Canyon Switchback (Built)
- **Scene:** `Scenes/StoneTrail.tscn`
- **Connections:** Trail Entry(5) ↔ Feroshaw (SW Pass) · Trail Exit(8) → Red Crag
- **Not connected to Green Grove.**

### Red Crag — Desert Mesa (Future)
- **Connections:** ← Stone Trail (Trail Exit)

### East Marsh — Buffer Zone (planned / partial)
- **Connections:** ← Feroshaw (East Gate) · → Sylvania

### Sylvania — Town, Greco-Roman Forest Hub (MVP goal)
- **Connections:** ← East Marsh

### Lesser Wilds — Coastal Untamed Woods (Built / partial)
- **Connections:** ← Feroshaw (Well) · Gate Barrier/Edge (LH) → Sunken Mere (blocked)

### The Sunken Mere — Great Lake (Water barrier)
- **Role:** Impossible natural barrier. Not a traversable MVP route.

## Implementation notes (current wiring)

- New game default map: **Green Grove** (`world.tscn` → `MapManager.default_map_scene`).
- Green Grove stone gate → **FeroShaw** (`Scenes/FeroShaw.tscn`), arrival `SpawnPoint`.
- Feroshaw has a north-side return gate → **Green Grove** so return-visit slime drones can be tested. Diagram treats starter as inbound tutorial; the return gate is a thin convenience edge, not a second overworld artery.
- Stone Trail never links to Green Grove (only Feroshaw ↔ Stone Trail ↔ Red Crag).
