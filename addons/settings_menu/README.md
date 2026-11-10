# Settings Menu Lite for Godot 4 (free edition)

A ready-to-use settings menu. 100% typed GDScript, no external assets.

- **Audio**: one volume slider per audio bus (Master, Music, SFX), applied live.
- **Graphics**: resolution, fullscreen / windowed, VSync.
- **Auto save & load**: settings are stored in `user://settings.cfg` and re-applied every time the game starts.
- Responsive layout (native Control nodes, `SIZE_EXPAND_FILL`), navigable with mouse, keyboard and gamepad.
- English interface with a **built-in French translation** (used automatically for French-speaking players).

Compatibility: Godot **4.2 and later**.

*Version française : voir `README.fr.md`.*

## Settings Menu PRO

The paid edition, **Settings Menu PRO**, adds the **Controls** tab:

- keyboard, mouse and gamepad rebinding (2 keyboard/mouse slots + 1 gamepad slot per action);
- conflict detection with **Swap** or **Replace**;
- saved custom bindings, and an API to add actions from code.

👉 https://exiforever.itch.io/settings-menu-pro

Upgrading is instant: replace the `addons/settings_menu/` folder with the one from
Settings Menu PRO. Your players' saved settings are kept.

---

## Installation (2 minutes)

1. Copy the `addons/settings_menu/` folder into your project's `addons/` folder.
2. Open **Project > Project Settings > Plugins** and enable **Settings Menu Lite**.
   The `SettingsManager` autoload is added for you.
3. (Recommended) In the **Audio** panel at the bottom of the editor, create the `Music` and `SFX`
   buses and assign them to your `AudioStreamPlayer` nodes. If they don't exist, the addon creates them at startup.

**Try it now**: open `addons/settings_menu/demo/Demo.tscn` and run it with **F6**.

## Opening the menu

```gdscript
const SETTINGS_MENU: PackedScene = preload("res://addons/settings_menu/SettingsMenu.tscn")

func _on_settings_button_pressed() -> void:
	var menu: Control = SETTINGS_MENU.instantiate()
	menu.free_on_close = true
	add_child(menu)
	menu.closed.connect(_on_settings_closed)
```

You can also drop `SettingsMenu.tscn` into your scene, hide it, then call `open()`.

### Scene options (Inspector)

| Option | Default | Effect |
| --- | --- | --- |
| `pause_game_while_open` | `false` | Pauses the game while the menu is open. |
| `free_on_close` | `false` | Frees the menu when it closes (otherwise it is hidden). |
| `revert_unsaved_on_close` | `true` | "Close" reverts unsaved changes. |
| `close_on_cancel` | `true` | Esc / B button closes the menu. |

## Appearance

The menu is styled entirely by a theme generated in code (no image or font files).
In the `SettingsMenu` Inspector, **Appearance** group:

| Option | Purpose |
| --- | --- |
| `color_preset` | Ready-made palette: Night, Light, Ocean, **Candy** (default), Dusk, or "Custom" to use the colours below |
| `accent_color` | Main colour (active tab, Save button, sliders, switches) |
| `panel_color` / `surface_color` | Window background / card background |
| `text_color` / `muted_text_color` | Main text / secondary text |
| `on_accent_color` | Text drawn on the main colour |
| `corner_radius` | Corner rounding |
| `max_panel_size` | Maximum panel size (below it, the panel uses 92% of the screen) |
| `animate` | Open and close animations |
| `custom_theme` | Your own `Theme`: fully replaces the generated one |

From code: change `color_preset` or the colours, then call `menu.apply_theme()`.

## Buttons

- Settings apply **immediately** so the player sees the result.
- **Save** writes everything to `user://settings.cfg`.
- **Defaults** restores your project's values (save afterwards to keep them).
- **Close** closes the menu; unsaved changes are reverted (configurable).

## Configuration

`Project > Project Settings > Settings Menu`:

- `audio/buses`: buses shown in the Audio tab (default `Master, Music, SFX`). Default values come from your project.
- `localization/builtin_french` (on by default): built-in French translation; turn it off for an
  English-only game. To force a language: `TranslationServer.set_locale("fr")`.

## `SettingsManager` API

```gdscript
SettingsManager.set_volume("Music", 0.5)       # 0.0 to 1.0
SettingsManager.set_resolution(Vector2i(1920, 1080))
SettingsManager.set_fullscreen(true)
SettingsManager.set_vsync(false)
SettingsManager.save_settings()
SettingsManager.reset_to_defaults()
```

Signals: `settings_loaded`, `settings_saved`, `settings_reset`, `setting_changed(section, key, value)`.

## License

MIT (see `LICENSE.txt`): free to use, including in commercial games.
