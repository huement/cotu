# UI DOCS

## BATTLE SYSTEM

### Screen Shake & Game Juice Architecture

#### 1. Concept Definition

- **Screen Shake / Camera Shake**: Perceptual feedback technique where the camera or UI viewport rapidly offsets and rotates to simulate physical impact.
- **Game Juice**: The collection of feedback effects (camera shake, flash chevrons, hit stop) that maximize player responsiveness.

#### 2. Trauma Model Formula

$$ \text{Shake Amount} = \text{Trauma}^2 $$

- `trauma` ranges from `0.0` to `1.0`.
- Linear decay ensures hits feel instantaneous and settle cleanly back to rest.

#### 3. Signal API (`SignalBus.gd`)

- `SignalBus.camera_shake_requested.emit(trauma_amount: float)`
  - `0.2 - 0.3`: Light physical hits or basic attacks.
  - `0.4 - 0.6`: Heavy spells, elemental bursts, critical hits.
  - `0.7 - 1.0`: Boss attacks or party wipe events.

---

## Keyboard play

| Key | Does |
|---|---|
| W/S, arrows | Move / turn (Q/E strafe) - only while no panel is open |
| `/` `.` `,` | Search / Rest / Items (HUD toolbar, input actions `interact`, `party_rest`, `item_menu`) |
| 1-6 | Open that party member's character sheet; switches character while it is open; picks that ally as a target in battle (input actions `party_slot_1`..`party_slot_6`, same as clicking the portrait) |
| Tab / Shift+Tab, arrows | Move between buttons in any open panel |
| Enter / Space | Press the focused button (Enter on the Rest slider = REST) |
| Esc | Cancel / close the panel (target page in battle = back) |

**How it works:** `Scripts/UI/KeyboardModal.gd`. One line per panel: `KeyboardModal.attach(panel, on_cancel)`.
While that panel is visible and topmost it makes every enabled button / slider inside it focusable (cyan
outline; TextureButtons show their hover texture), puts focus on the control marked
`KeyboardModal.set_default()` or the first one, re-scans for rebuilt content, maps Esc to `on_cancel`, and
`KeyboardModal.is_any_open()` stops the party from walking. Panels that should still take the 1-6 keys set
meta `allow_party_hotkeys` (character sheet, battle action bar / target buttons).

Attached: UniversalPopup (search, rest, items, item actions, loot, lore, confirmations, victory),
character sheet, battle action bar + enemy target buttons, battle skills/spells popup, skill/spell detail
popup, level-up menu, shop. The main menu, in-game menu, save slots, roster and shard menu already had
their own keyboard focus.
