# NineHUD — Voice Assistant Overlay

Nine is the party's HUD voice assistant: a bottom-right CRT panel that appears when dialogue plays, spins concentric rings to the voice bus spectrum, and fades out when the clip ends.

---

## Files

| Path | Role |
|---|---|
| `Scenes/UI/NineHUD.tscn` | Standalone Control scene (frame, waveform, three ring textures). |
| `Scripts/UI/NineHUD.gd` | Show/hide, voice playback trigger, spectrum → animation. |
| `Shaders/hud_waveform.gdshader` | Animated sine-line driven by an `energy` uniform (0–1). |
| `ui/HUD/nine_frame.png` | Outer CRT bezel. |
| `ui/HUD/nine_white.png` | Static white ring (background). |
| `ui/HUD/nine_cyan.png` | Rotating cyan ring. |
| `ui/HUD/nine_blue.png` | Rotating blue ring (opposite direction). |
| `Audio/Voice/*.mp3` | Dialogue clips resolved by basename. |
| `default_bus_layout.tres` | `Voice` bus + `AudioEffectSpectrumAnalyzer`. |
| `Core/AudioManager.gd` | `play_voice()`, `get_voice_player()`, `is_voice_playing()`. |

Embedded into the main dungeon HUD as a scene-unique instance:

- `Scenes/UI/HUD.tscn` → child `NineHud` (`unique_name_in_owner = true`)
- `Scripts/hud.gd` → `@onready var nine_hud: Control = %NineHud as Control`

---

## Scene layout

Root `Control` is bottom-right anchored (`anchors_preset = 3`, ~228×171 px). Children under `BackgroundBox`:

1. **Waveform** (`%Waveform` ColorRect) — shader material, cyan line.
2. **RingWhite** (`%RingWhite`) — static.
3. **RingCyan** (`%RingCyan`) — spins positive (`cyan_rotation_speed`, default `0.8`).
4. **RingBlue** (`%RingBlue`) — spins negative (`blue_rotation_speed`, default `-1.4`).

The panel starts **hidden** in `_ready()`.

---

## How it works

### Lifecycle

1. Something calls `make_nine_talk(sound_file_name)`.
2. NineHUD `show()`s, sets `_is_speaking = true`.
3. `AudioManager.play_voice(sound_file_name)` loads `res://Audio/Voice/<name>.mp3` onto the Voice bus player.
4. While speaking, `_process`:
   - Samples spectrum on the `Voice` bus (200–4000 Hz).
   - Boosts ring spin by `1 + energy * 3`.
   - Lerps the waveform shader `energy` toward that magnitude.
5. On `AudioStreamPlayer.finished` (one-shot): fades `modulate.a` to 0 over 0.4 s, then `hide()` and resets alpha.

### Audio path

```
make_nine_talk("cant-sleep-here")
  → AudioManager.play_voice("cant-sleep-here")
  → res://Audio/Voice/cant-sleep-here.mp3
  → AudioStreamPlayer on bus "Voice"
  → SpectrumAnalyzer effect feeds NineHUD rings / waveform
```

`play_voice` strips any extension via `get_basename()`, then looks under `Audio/Voice/`. If missing, it falls back to `Audio/<name>.mp3` and warns if still not found.

### Exports / tuning

| Export | Default | Meaning |
|---|---|---|
| `cyan_rotation_speed` | `0.8` | Base rad/s for cyan ring. |
| `blue_rotation_speed` | `-1.4` | Base rad/s for blue ring. |
| `voice_bus_name` | `&"Voice"` | Bus that must carry a SpectrumAnalyzer. |

---

## How to call it

### Preferred (from code that already holds the HUD)

```gdscript
if is_instance_valid(nine_hud) and nine_hud.has_method("make_nine_talk"):
	nine_hud.make_nine_talk("cant-sleep-here")
```

Pass the **file basename only** (no path, extension optional). Examples that exist on disk:

| Clip basename | File |
|---|---|
| `cant-sleep-here` | `Audio/Voice/cant-sleep-here.mp3` |
| `hostiles-ahead` | `Audio/Voice/hostiles-ahead.mp3` |
| `mask-collected` | `Audio/Voice/mask-collected.mp3` |
| `env-warning-exit-now` | `Audio/Voice/env-warning-exit-now.mp3` |

### From anywhere in the tree (debug / one-off)

```gdscript
var nine_hud: Node = get_tree().root.find_child("NineHud", true, false)
if is_instance_valid(nine_hud) and nine_hud.has_method("make_nine_talk"):
	nine_hud.call("make_nine_talk", "hostiles-ahead")
```

### Adding a new line

1. Drop `Audio/Voice/<kebab-name>.mp3`.
2. Call `make_nine_talk("<kebab-name>")` from the relevant gameplay hook.
3. Ensure the `Voice` bus still has SpectrumAnalyzer enabled, or rings/waveform stay flat.

There is **no SignalBus signal** dedicated to Nine yet — callers talk to the node (or find it) directly. Gameplay logic that only knows SignalBus should either reach `%NineHud` via `DungeonHUD`, or a future `nine_speak_requested` signal could be added.

---

## Where it is used right now

### Production

| Location | Trigger | Clip |
|---|---|---|
| `Scripts/hud.gd` → `_on_popup_requested` | Player presses **REST** (`SignalBus.popup_requested` with `"REST"`) while monsters are nearby (`_are_monsters_nearby()`) | `"cant-sleep-here"` |

Flow:

```
rest_button.gd → SignalBus.popup_requested.emit("REST")
  → DungeonHUD._on_popup_requested
  → if monsters nearby → nine_hud.make_nine_talk("cant-sleep-here")
  → early return (rest popup does not open)
```

Proximity uses `_current_enemy_tier` from `enemy_proximity_changed`, with a fallback 8-unit 3D distance check against the `"enemies"` group.

### Debug / test

| Location | Trigger | Clip |
|---|---|---|
| `Scripts/Testing/BattleTest.gd` → `_test_nine_hud` | Debug build, **V** key | `"cant-sleep-here"` |

Finds `NineHud` via `find_child` and calls `make_nine_talk`.

### Unused clips (on disk, no callers yet)

- `hostiles-ahead`
- `mask-collected`
- `env-warning-exit-now`

---

## Integration checklist for new call sites

1. Prefer going through `DungeonHUD.nine_hud` when you already sit on the HUD layer.
2. Guard with `is_instance_valid` + `has_method("make_nine_talk")`.
3. Use kebab-case basenames matching files under `Audio/Voice/`.
4. Do not assume the panel stays visible — it auto-hides when the voice player finishes.
5. Overlapping calls reuse the same Voice player; a new `play_voice` replaces the stream. Reconnect finished via `CONNECT_ONE_SHOT` each talk.

## CREATING NEW AUDIO FILES

To create a new audio file, you need to use the Text To Speech Generator. `robot_tts`. This allows you to turn any text into a audio file. 