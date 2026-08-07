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
