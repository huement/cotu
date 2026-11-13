# Sky & Daylight

Every outdoor map draws its sky with one shader, `Shaders/pixel_sky.gdshader`, and runs the same `DayNightCycle` script off one shared clock (`GameState.world_time`). By day the sky is a banded gradient with drifting pixel clouds and a pixel sun. As night falls the clouds fade out and the main-menu space scene (nebula, parallax pixel stars, glowing giant stars) fades in.

| File | Role |
|---|---|
| `Shaders/pixel_sky.gdshader` | The sky: gradient, sun, clouds, night space scene |
| `resources/Environment/pixel_sky.tres` | Default material (clear day) |
| `resources/Environment/pixel_sky_overcast.tres` | Greyer, heavier-cloud material for gloomy maps |
| `resources/Environment/pixel_sky_feroshaw.tres` | FeroShaw only: dark teal-to-jaundice day sky under heavy slate cloud |
| `Scripts/Environment/day_night_cycle.gd` | Orbits sun/moon lights, lerps ambient, drives the sky shader |
| `Shaders/space_pixel.gdshader` | The 2D menu background the night scene was ported from (menus only) |

| Map | Material |
|---|---|
| VeroWood, StoneTrail | `pixel_sky.tres` |
| FeroShaw | `pixel_sky_feroshaw.tres` (sick overcast day; night unchanged) |
| GreenGrove, BrokenBoneMarsh, GloomReach, CastleHollow | `pixel_sky_overcast.tres` |
| Dungeons / caves | No sky: flat dark `Environment` + depth fog, no `DayNightCycle` |

---

## How the sky shader works

`DayNightCycle` sets two uniforms on the sky material every frame:

- `day_amount` — 0 at night, 1 in full day
- `sun_direction` — direction toward the sun

Everything else is drawn from those, in this order:

1. **Gradient.** Night colours (`night_top` / `night_horizon`) blend to day colours (`day_top` / `day_horizon`) by `day_amount`, quantised into `color_steps` bands.
2. **Sunset glow.** `sunset_color` is added near the horizon on the sun's side while the sun is low.
3. **Sun disc.** A pixel disc of radius `sun_size`.
4. **Clouds.** fbm noise projected on a flat ceiling, banded into 3 shades, drifting with `wind`. Lit/shadow colours blend between the day and night cloud colours.
5. **Night space scene.** Nebula plus three parallax star layers and giant glowing stars, drawn over the night gradient.

### The day/night cross-fade

One value controls the hand-over:

```
space_fade = space_amount * smoothstep(0.1, 0.9, 1.0 - day_amount)
```

- Cloud opacity is multiplied by `1 - space_fade * (1 - night_cloud_amount)`, so clouds fade **out** as night comes on.
- The space scene is mixed in by `space_fade`, so it fades **in** over the same span. It is also faded out toward the horizon and hidden behind any cloud that remains.

`day_amount` goes from 1 to 0 over a short window around sunset (and back at sunrise), so the cross-fade happens at dusk and dawn rather than across the whole day.

### Pixel grids

- The gradient, sun and clouds are snapped to a 3D "art pixel" grid on the dome (`pixel_density` pixels per radian).
- The space scene uses its own 2D grid (a stereographic projection of the upper dome), because the plus-shaped and glowing stars need flat 2D pixel coordinates. Its pixel size also follows `pixel_density`.

### Ambient pass

The environment's ambient light comes from the sky. For that cubemap pass the shader renders the gradient only, so clouds, stars and nebula don't flicker the scene lighting.

### Renderer note

On the Compatibility renderer, `TIME` only exists inside `sky()`. Helper functions that animate (stars, nebula) take the time as a `tm` parameter. Keep that pattern when adding new helpers.

---

## Tuning the sky (material > Shader Parameters)

| Group | Uniform | What it does |
|---|---|---|
| pixel_look | `pixel_density` | Lower = chunkier pixels |
| pixel_look | `color_steps` | Gradient bands (fewer = more retro) |
| day_sky / night_sky | `day_top`, `day_horizon`, `night_top`, `night_horizon` | Gradient colours |
| sun_and_sunset | `sun_size`, `sun_color`, `sunset_color`, `sunset_strength` | Sun disc and dusk/dawn glow |
| clouds | `cloud_coverage` | 0 clear … 1 overcast |
| clouds | `cloud_softness`, `cloud_scale`, `cloud_height`, `cloud_bands`, `wind` | Cloud shape and drift |
| clouds | `cloud_day_*`, `cloud_night_*` | Cloud colours |
| night_space | `space_amount` | How much of the space scene shows at full night (0 = plain dark sky, no stars) |
| night_space | `night_cloud_amount` | Clouds left at full night (0 = fade out fully, 1 = never fade) |
| night_space | `space_drift`, `space_seed` | Slow drift of the star field; layout seed |
| night_space | `nebula_dark`, `nebula_mid`, `nebula_bright` | Nebula palette (defaults match the menu's warm red/orange) |
| night_space | `nebula_intensity`, `nebula_scale`, `nebula_coverage`, `nebula_grain`, `nebula_warp`, `dust_lanes`, `nebula_evolve` | Nebula shape |
| stars | `far_star_density`, `mid_star_density`, `near_star_density`, `giant_star_density` | Stars per layer |
| stars | `giant_glow`, `star_brightness`, `star_twinkle`, `twinkle_speed` | Glow size, brightness, twinkle |
| stars | `star_cool`, `star_warm`, `star_hot` | Star colours (defaults match the menu) |

Changes to `pixel_sky.tres` affect VeroWood and StoneTrail; `pixel_sky_feroshaw.tres` affects FeroShaw only; changes to `pixel_sky_overcast.tres` affect GreenGrove, BrokenBoneMarsh, GloomReach and CastleHollow.

---

## Day / night (`DayNightCycle`)

Every outdoor map has a `DayLightCycle` node with `day_night_cycle.gd`. It does **not** own the clock — `GameState.world_time` does, so travelling between maps keeps the same time of day.

| `world_time` | Meaning |
|---|---|
| `0.0` | Midnight |
| `0.25` | Sunrise |
| `0.5` | Noon |
| `0.75` | Sunset |

Period names (written to `GameState.current_time_period`): `MORNING` 0.20–0.35, `DAY` 0.35–0.65, `EVENING` 0.65–0.80, `NIGHT` otherwise.

`SignalBus.day_night_changed(is_night)` fires when the sun crosses the horizon (used by night-only enemies).

Each frame the script:

1. Moves the sun and moon lights (and the moon mesh) around their orbit and fades their `light_energy`.
2. Sets `day_amount` and `sun_direction` on the pixel sky material.
3. Holds `background_energy_multiplier` at `day_background_energy`. The sky darkens itself through its night colours; it is not dimmed by the environment. (A non-pixel sky material would instead be dimmed to 2% at night.)
4. Lerps ambient colour and energy between night and day values.
5. If volumetric fog is on, tints and thickens it at night.

### Inspector knobs

| Export | What it does |
|---|---|
| `day_duration` | Real seconds for one full 24h loop (default `120`) |
| `time_of_day` | Editor preview; overwritten at runtime from `GameState.world_time` |
| `sun_light` / `moon_light` / `moon_mesh_node` | Lights and moon mesh the script orbits |
| `world_environment` | Environment whose sky and ambient get driven |
| `orbit_distance` | Sun/moon distance from the origin (default `200`) |
| `day_ambient` / `night_ambient` | Ambient colours at noon and midnight |
| `day_ambient_energy` | Peak daytime ambient energy (lower = gloomier) |
| `day_background_energy` | Sky brightness (applies day and night with the pixel sky) |
| `moon_emission_energy` / `moon_rotation_degrees` | Moon glow and facing |
| `day_fog_density` / `day_fog_color` | Daytime depth fog (0 = off). Thins to nothing at night. Used by FeroShaw |

### Other things that change time

- **Rest / camp** — anything that writes `GameState.world_time`.
- **Save / load** — `world_time` and `time_period` are stored on `SaveGame`.
- **New game** — starts at `world_time = 0.25`.

### Map swaps

`MapManager` copies the active map's `Environment` onto the root `World/WorldEnvironment` and re-points that map's `DayNightCycle` at it, so outdoor skies and dungeon fog don't fight each other.

---

## Quick recipes

**Force night for testing** — set `GameState.world_time = 0.0`.

**Slow the day** — raise `day_duration` on the map's `DayLightCycle` (`300` = 5 real minutes per day).

**Keep some cloud at night on gloomy maps** — raise `night_cloud_amount` in `pixel_sky_overcast.tres`.

**Cooler night sky** — retint `nebula_*` and `star_*` in the material; lower `nebula_intensity` for a subtler nebula.

**Stars only, no nebula** — `nebula_intensity = 0`.

**More overcast day** — raise `cloud_coverage`.

**Trigger a thunderstorm** — see [`WEATHER.md`](WEATHER.md). Outdoors: `SignalBus.storm_requested.emit(1.0, 5.0)`.

---

## Retired

The earlier approaches — `stylized_sky.gdshader` with its `stylized_sky_*.tres` presets, `ProceduralSkyMaterial` skies, and the `CloudLayer` mesh clouds (`cloud_layer.gd`) — are no longer used by any outdoor map.
