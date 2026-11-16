# Mobile UI — every touch-screen tweak in one place

The game was built for desktop (1152 x 648, stretch `canvas_items` / aspect `expand`). On phones the
screen is wider and physically much smaller, so some screens get a separate **touch layout**.
This page lists all of them. **When you add or change a mobile tweak, add it here.**

Mockups and play-test notes: `Mobile_FIX/` (`mobile_1..3`, `screen_1..3.txt`, `snotes.md`).

---

## 1. The switch: `MobileUI` (`Scripts/UI/MobileUI.gd`)

One static class decides whether touch layouts are used. Every mobile layout asks
`MobileUI.is_wanted()` — never `OS.has_feature()` directly.

| Turned on by | Notes |
|---|---|
| Phones / tablets (`OS.has_feature("mobile")`) | automatic |
| Touch browsers (`web` + touchscreen) | automatic |
| **world.tscn > MapManager > Mobile Preview** | editor runs only, also reshapes the window (see §2) |
| Debug menu (`` ` ``) > DISPLAY > Mobile UI | toggles while playing; the character sheet follows the next time it opens |
| Project Settings > `shards/hud/force_mobile_hud` | forces the layouts, window keeps its shape |

Shared helpers in the same file:

- `MobileUI.scale_fonts(node, factor)` / `restore_fonts(node)` — enlarge every Label / Button under a node and put it back.
- `MobileUI.safe_insets(control)` — notch / rounded-corner padding in canvas units (zero on desktop). **Not yet checked on a real device.**

---

## 2. Testing on desktop ("view it as a phone")

1. Open `Scenes/world.tscn`, select **MapManager**.
2. Tick **Mobile Preview** (right under **Dev Start Override**).
3. Run the project.

The window takes a phone shape and every touch layout is on; the mouse acts as a finger (D-pad included).
Untick to get the desktop game back. Exported builds ignore the flag.

- **Mobile Preview Size** sets the shape. Only the proportions matter (the window keeps its height):
  `1404 x 648` = 19.5:9 modern phone (default), `1296 x 648` = 18:9, `1152 x 648` = 16:9, `864 x 648` = 4:3 tablet.
- It works with Dev Start Override on or off (off: the flag applies once you reach the world from the menu).
- Run as a separate window, the window itself takes the phone shape. Embedded in the editor's Game tab (floating or docked),
  the editor owns the window size, so the preview letterboxes instead: a phone-shaped canvas with black bars above and
  below (`MobileUI.letterbox`). Resizing an embedded window used to leave a big red strip at the top.
- The preview shows layout, not physical size. A phone screen is roughly a third the height of a monitor window,
  so text that looks comfortable here is small on the device.

---

## 3. Exploration HUD — `MobileHUD` (`Scripts/UI/MobileHUD.gd`)

Created by `DungeonHUD` (`Scripts/hud.gd`). The battle HUD is unchanged.

| Desktop | Mobile |
|---|---|
| Party portraits in the right sidebar | Bottom-left panel, 2 rows of 3 (front row at the bottom; back row only when used) |
| Toolbar (SEARCH / REST / ITEMS) bottom-left | Bottom-centre, same spacing |
| Keyboard movement | D-pad bottom-right (`TouchScreenButton`s pressing the same input actions as the keys; multi-touch) |
| Sidebar frame (`CockpitBackground`) | Faded out |

Everything hides in battle with the rest of the exploration HUD. Art: `ui/MOBILE/*.svg`.

### Anchoring fixes (apply to every screen width, not just phones)

Anything placed with "x pixels from the left" drifts on wide screens. Fixed so far:

| Node | Fix |
|---|---|
| `%GoldControl` (HUD.tscn) | anchored top-right (was `offset_left = 1113`) |
| `%EnemyInRange` (HUD.tscn + `hud.gd`) | anchored top-right; the tween measures from the right edge (`ENEMY_IN_RANGE_CENTER_FROM_RIGHT`) instead of fixed x = 865 / 845 / 820 |

---

## 4. Character sheet — `CharacterSheetMobile` (`Scripts/UI/CharacterSheetMobile.gd`)

Created by `CharacterSheetMenu`; checked each time the sheet opens. The desktop sheet shows seven
blocks at once; on mobile the **same panels** are moved into three tabs (nothing is duplicated, so
`CharacterSheetMenu` fills them exactly as on desktop) and moved back when the layout is switched off.

| Tab | Left | Right |
|---|---|---|
| **MAIN** | Player info, load out, status effects | Stats / fight, `+ ALLOCATE POINTS` when there are unspent points |
| **INVENTORY** | Player info (HP / MP only), load out | Filter `ALL / GEAR / CONSUMABLES`, inventory 5 big slots wide (scrolls) |
| **SKILLS/SPELLS** | Skill / spell list | Caster vitals, ability details, target picker, cast button |

Bottom bar on every tab: `[ CLOSE ]`, character picker (`1. NYX — LVL 1 SPARTAN`, replaces the small
`< 1 | 6 >` arrows), the three tab buttons. It sits 14 px above the screen edge so swipe-home gestures don't eat taps.

What is different from desktop, and where it lives:

| Tweak | Where |
|---|---|
| Bigger text per panel (info x1.2, load out x1.3, stats x1.7) | constants at the top of `CharacterSheetMobile.gd` |
| Load out slots 52 px tall | `LOADOUT_SLOT_HEIGHT` |
| Status effects: one row; **tap a badge** to read its description (no tooltips on touch) | `CharacterSheetMobile._on_badge_input` |
| Inventory: 5 columns, 100 px slots, `x5` counters, filter | `character_inventory_grid.gd` — `set_touch_layout()`, `set_filter()`, `Filter` |
| Ability rows x1.5; tapping a row **selects** it instead of opening the detail popup | `SkillsSpellsPanel.gd` — `set_touch_layout()`, `ability_selected`; `AbilityRow.set_ui_scale()` |
| `SHOW: ALL / FIELD ONLY` filter next to `[ ALL SKILLS ]` | `SkillsSpellsPanel.field_only` |
| Inline casting: pick a party member, `[ CAST ON <NAME> ]`. Button shows the reason when it can't be used (`COMBAT ONLY`, `NOT ENOUGH MANA`, restricted, incapacitated) | `CharacterSheetMobile._refresh_cast_panel`; the cast itself is still done by `SkillSpellDetailPopup.cast_now()` (sent as `ABILITY_INFO` with `cast_now`) |
| "Downed" banner hidden (placed for the desktop layout; the red INCAPACITATED line + downed portrait remain) | `CharacterSheetMobile.refresh` |

Item taps (inventory or load out) still open the normal item action popup; the load out updates when it closes.

---

## 5. Adding another mobile layout

1. Write a small controller node (like `MobileHUD` / `CharacterSheetMobile`) owned by the screen it changes.
2. Ask `MobileUI.is_wanted()`; re-parent existing nodes instead of building a second copy of the screen.
3. Record every property you change so the desktop layout can be restored (the debug toggle switches live).
4. Anchor to the screen edge the element belongs to — never "x pixels from the left".
5. Add a section here.

---

## 6. Known gaps (from `Mobile_FIX/snotes.md`, not done yet)

- HUD: toolbar buttons and portraits too small; D-pad buttons want a little more spacing.
- HUD: Nine voice panel position on wide screens (re-anchored by hand, needs a check).
- Battle HUD: attack / defend / spell buttons off-centre on wide screens (same "pixels from the left" cause).
- Character sheet on a phone: "CLOSE and the character arrows don't respond" was reported against the old desktop
  layout. The tabbed layout replaces both controls with large ones away from the screen edge; re-test on a device.
- `MobileUI.safe_insets()` needs a check on a phone with a notch.

## Battle HUD, toasts, Nine, shard menu (2026-11-14)
- **BattleHUD** (`Scripts/UI/BattleHUD.gd` > RESPONSIVE LAYOUT): ActionBar and ActionBarBackground are anchored bottom-centre and re-laid out on resize / show / button changes. On touch layouts the one-piece `HUDBackground` is hidden and replaced by `ui/MOBILE/battlehud_left.svg` + `battlehud_right.svg` pinned to the screen edges (full height, safe-area aware); the action bar background uses `battlehud_bottom.svg`.
- **Toasts** (`toast_notification_manager.gd`): on touch layouts they are 560 px wide, 28 px text with an outline, drawn with a StyleBox only (no PNG bar), placed right of the battle frame and below the enemy header.
- **Nine** (`NineHUD.gd`): snaps itself centred under `MinimapAnchor/MinimapBackground` every time it speaks and on resize (top-left anchors, no bottom-right offsets).
- **Shard menu** (`hud_shard_menu.gd`): the text box (`ScrollInset`) is fitted to the green frame's drawn rect, since the frame keeps its aspect and gets narrower than its box on wide phones.
