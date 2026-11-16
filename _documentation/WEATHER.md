## Thunderstorm & Rain (`WeatherController` + `PixelRainOverlay`)

Dynamic weather layers on top of `Shaders/pixel_sky.gdshader` and `DayNightCycle` without mutating per-map baseline sky materials. Everything is driven by a single normalized **`storm_amount`** (`0.0` clear → `1.0` full thunderstorm).

| File | Role |
|---|---|
| `Scripts/Environment/WeatherController.gd` | Persistent `World` node (`%WeatherController`, `process_priority = 10`). Tweens `storm_amount`, dims sun/ambient energy, thickens depth fog, drives rain loop volume, and fires double-flash lightning + camera shake + delayed thunder |
| `Scripts/Environment/PixelRainOverlay.gd` | Persistent `CanvasLayer` (`%PixelRainOverlay`, layer `85`). Drives `pixel_rain.gdshader` from `SignalBus.weather_changed` and updates `wind_slant` as the camera makes 90° turns |
| `Shaders/pixel_rain.gdshader` | Fullscreen `canvas_item` shader rendering aspect-corrected pixel rain columns (far + near parallax layers) and lower-screen splash ticks |
| `Shaders/pixel_sky.gdshader` | Extended with the `storm` uniform group for horizon-to-zenith cloud rollout, slate storm palette blending, wind boost, night star occlusion, and sheet lightning |
| `Core/AudioManager.gd` | `start_rain_loop` / `stop_rain_loop` (Ambient bus, layers over BGM) and `play_thunder` (random `thunder-1..4` on the SFX pool) |
| `Core/SignalBus.gd` | Decoupled weather request and state signals (`storm_requested`, `weather_clear_requested`, `lightning_flash_requested`, `weather_changed`) |

Wired in `Scenes/world.tscn` as `%WeatherController` + `%PixelRainOverlay`. `MapManager._rebind_weather()` retargets the controller after every map swap.

---

### Storm progression (`storm_amount`)

| Range | Visual & Audio Behaviour |
|---|---|
| `0.00 – 0.25` | Cloud front sweeps from `storm_front` horizon; **coverage thickens** (gaps kept so banded clouds stay readable); sky only gets a mild cool tint (not a solid repaint); wind speeds up; sun disc fades under the front |
| `0.25 – 0.35` | `PixelRainOverlay` fades in (lagging the cloud deck by `storm_rain_threshold`); looping `rain-loop.mp3` starts on the Ambient bus over BGM; directional sunlight and ambient energy dim; storm depth fog thickens |
| `0.35 – 1.00` | Heavy downpour; random double-flash lightning bolts orient `DirectionalLight3D` from the sky vector, flash cloud undersides, emit `camera_shake_requested` on close strikes, and play a random distance-delayed thunder clip on the SFX bus |

---

### Audio

Rain and thunder are **additive** — they never stop Music, level ambient, footsteps, or other SFX.

| Sound | Source | Bus | Behaviour |
|---|---|---|---|
| Rain bed | `Audio/Environment/rain-loop.mp3` | `Ambient` | Dedicated `RainPlayer` in `AudioManager`. Stream is duplicated with `loop = true`. Starts when rain amount &gt; 0; volume tracks rain intensity; stops when weather clears or the party goes indoors |
| Thunder | `Audio/Environment/thunder-1.mp3` … `thunder-4.mp3` | `SFX` | After each lightning flash, a distance delay (`0.2 – 1.5 s`) then `AudioManager.play_thunder()` picks one clip at random (inspector `thunder_streams` override, else auto-load). Plays on the SFX pool so strikes can overlap the rain loop |

---

### Execution order & lighting rules

- **Priority (`process_priority = 10`):** `WeatherController` runs after `DayNightCycle` (`0`) so storm gloom, fog density, and 1–3 frame lightning spikes layer on top of time-of-day lighting without being overwritten on the same frame.
- **Cubemap safety:** `lightning_flash` in `pixel_sky.gdshader` is strictly excluded from `AT_CUBEMAP_PASS` so environment reflection/ambient probes do not strobe. Ground illumination during flashes comes from `WeatherController` temporarily aiming `sun_light` from the sky flash vector toward `Vector3.ZERO` (including during night storms when the orbital sun is underground).
- **Night storms:** Effective `night_cloud_amount` lerps toward `1.0` under the storm front so clouds stay visible at night and occlude the space/nebula layer behind them.

---

### Shader uniforms

#### `Shaders/pixel_sky.gdshader` (`group_uniforms storm`)

| Uniform | Type | Default | What it does |
|---|---|---|---|
| `storm_amount` | `float` | `0.0` | `0.0` clear … `1.0` full thunderstorm |
| `storm_front` | `vec2` | `(1.0, 0.0)` | Unit XZ direction the storm front approaches from |
| `lightning_flash` | `float` | `0.0` | Brief `0.0 – 1.0` sheet-lightning spike on cloud undersides |
| `storm_top` | `vec3` | `(0.18, 0.22, 0.25)` | Overcast zenith sky colour |
| `storm_horizon` | `vec3` | `(0.25, 0.30, 0.35)` | Overcast horizon sky colour |
| `storm_cloud_lit` | `vec3` | `(0.35, 0.40, 0.45)` | Lit band colour of storm clouds |
| `storm_cloud_shadow` | `vec3` | `(0.15, 0.18, 0.22)` | Shadow band colour of storm clouds |

#### `Shaders/pixel_rain.gdshader` (`group_uniforms rain_look`)

| Uniform | Type | Default | What it does |
|---|---|---|---|
| `rain_amount` | `float` | `0.0` | `0.0` dry … `1.0` torrential downpour |
| `pixel_rows` | `float` | `135.0` | Vertical art-pixel grid resolution (columns auto-scale from `SCREEN_PIXEL_SIZE` to keep pixels square) |
| `wind_slant` | `float` | `0.15` | Horizontal pixel offset per vertical row; updated each frame from `camera.global_basis.x` vs. `storm_front` |
| `fall_speed` | `float` | `3.2` | Base fall speed in screen-heights per second |
| `rain_color` | `vec4` | `(0.66, 0.78, 0.90, 0.45)` | Tint and peak alpha (quantised into 4 retro alpha steps) |
| `splash_amount` | `float` | `0.55` | Intensity of lower-viewport pixel splash flickers (`UV.y > 0.84`) |

---

### Inspector knobs (`WeatherController`)

| Export | Default | What it does |
|---|---|---|
| `world_environment` / `day_night_cycle` | Rebound by `MapManager` | Target environment and active map clock |
| `rain_overlay` | `%PixelRainOverlay` | Fullscreen rain `CanvasLayer` receiving `storm_front` |
| `storm_amount` / `storm_front` | `0.0` / `(1, 0)` | Current storm intensity and approach direction |
| `storm_rain_threshold` | `0.25` | Storm intensity where rain overlay + rain loop begin |
| `min_sun_energy_mult` | `0.25` | Sunlight multiplier at full storm (`0.25` = 75% dimmer) |
| `min_ambient_energy_mult` | `0.45` | Ambient light multiplier at full storm |
| `storm_ambient_tint` | `(0.24, 0.30, 0.36)` | Cool slate ambient tint blended in during storms |
| `max_storm_fog_density` / `storm_fog_color` | `0.018` / `(0.20, 0.25, 0.30)` | Depth fog layered on top of map baseline fog |
| `lightning_enabled` / `lightning_threshold` | `true` / `0.35` | Enables automatic strikes once `storm_amount >= 0.35` |
| `max_lightning_light_energy` | `4.5` | Peak `DirectionalLight3D` energy on a close strike |
| `min_strike_interval` / `max_strike_interval` | `4.5` / `16.0` | Seconds between strikes (interpolated by storm intensity) |
| `thunder_streams` | auto `thunder-1..4` | Pool of thunder `AudioStream` assets; empty at edit time → loaded from disk in `_ready` |

---

### Triggering weather (`SignalBus`)

Gameplay scripts, bosses, and map triggers control weather through `SignalBus` without referencing scene nodes:

```gdscript
# Roll a storm in to 100% over 30 seconds
SignalBus.storm_requested.emit(1.0, 30.0)

# Fast test roll-in (5 seconds)
SignalBus.storm_requested.emit(1.0, 5.0)

# Gradually clear active weather back to 0.0 over 45 seconds
SignalBus.weather_clear_requested.emit(45.0)

# Force an immediate scripted lightning strike (0.0 .. 1.0 intensity)
SignalBus.lightning_flash_requested.emit(1.0)
```

`WeatherController` emits `SignalBus.weather_changed(storm_amount)` whenever intensity updates.

**Debug menu** (backtick `` ` `` while playing a debug build): **WEATHER** → `STORM IN` (5s roll-in), `CLEAR` (8s), `LIGHTNING`. The menu closes so the storm tween can run.

### First visit: Fero Shaw

On the **first arrival** at map id `FeroShaw` (persisted like Nine's intro via `GameState.environment_states` / object `feroshaw_arrival_storm`):

1. Wait a random **10–20 s** after `MapManager` rebinds weather.
2. Roll a full storm in (~28 s), hold ~90 s, then clear.

Revisits skip the scripted beat; ambient random storms still apply.

### Ambient random storms

While outdoors and weather is clear, `WeatherController` counts down a random interval (**3–8 min** by default). When it fires: roll in → hold → clear → roll a new interval. Paused indoors / while a storm (or the Fero Shaw first-visit delay) is already in progress. Tunable under the **Ambient Random Storms** inspector group.

### Map swaps & indoor isolation

During map transitions, `MapManager._rebind_weather()` calls `weather_controller.bind_map_context(root_we, active_cycle)`:

- **Outdoor maps** (containing a `DayNightCycle` and `pixel_sky.gdshader` environment) inherit the active `storm_amount` across borders; rain overlay and rain loop stay in sync.
- **Dungeons & caves** (no `DayNightCycle`) force effective storm to `0.0`: rain overlay hides, rain loop stops, lightning/thunder cancel via `_storm_serial`. Sky storm uniforms are not applied until the next outdoor map.

Also see [`SKY_AND_DAYLIGHT.md`](SKY_AND_DAYLIGHT.md) for the base sky / day-night stack this layers on.
