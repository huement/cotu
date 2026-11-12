# Leveling system

How XP, level-ups, and point grants work in Shards. Source of truth for the curve and per-class numbers: **`Data/Class_Progression.csv`** (read at runtime by `Scripts/Progression/ClassProgression.gd` — edit the sheet and run; no compile step). Character application lives on `CatCharacter` (`resources/CatCharacter.gd`).

---

## Pipeline (exploration → level)

1. Combat victory → `CombatManager._collect_victory_rewards()` sums each dead enemy's `xp_value` (from enemy data / `Data/Enemies.csv`) into `total_xp`.
2. `GameState._award_victory_xp` splits that pool evenly across **living** party members: `xp_per_member = total_xp / living_count`.
3. Each living cat calls `CatCharacter.add_xp(xp_per_member)`.
4. While `current_xp >= max_xp` and under `Max Level`, the character levels: leftover XP carries over, then `_on_level_up()` runs.

Exploration pickups (skulls, masks, etc.) can also call `GameState.add_xp` / character XP helpers; battle XP is the main path.

---

## XP needed per level

For a class row at current level `L` (the level you are leaving):

```
XP to reach L+1 = floor( Base XP × L ^ XP Growth )
```

- `L` is clamped to at least `1`.
- `Base XP` and `XP Growth` come from that class's row in `Class_Progression.csv`.
- Harder classes use a higher **Base XP** and a steeper **XP Growth**, so they stay behind easy classes for the same fight XP.

Implemented as `ClassProgression.xp_to_next_level(row, level)`. `CatCharacter.get_required_xp_for_level(level)` wraps that with the character's profession row.

### Examples (after the ~+50% Base XP bump)

| Class | Diff | Base XP | Growth | L1→2 | L2→3 | L5→6 |
|---|---|---:|---:|---:|---:|---:|
| Spartan / Shade | Easy | 360 | 1.40 | 360 | 950 | 3426 |
| Soulwright / Archanist | Normal | 405 | 1.45 | 405 | 1106 | 4177 |
| Warden / Echo | Tricky | 480 | 1.50 | 480 | 1357 | 5366 |
| Maester / Psynic | Tricky | 495 | 1.50 | 495 | 1400 | 5534 |
| Amazon | Hard | 560 | 1.55 | 560 | 1639 | 6785 |
| Wizard / Crusader | Hard | 585 | 1.55 | 585 | 1712 | 7088 |
| Ronin / Voidhand | Expert | 650 | 1.60 | 650 | 1970 | 8536 |
| Ghostblade | Expert | 675 | 1.60 | 675 | 2046 | 8864 |

Unknown / missing class names fall back to `ClassProgression.DEFAULTS` (Base XP **450**, Growth **1.5**).

### Tuning

- Want slower early levels → raise **Base XP** (affects every step).
- Want slower late levels relative to early → raise **XP Growth**.
- Early trash packs (e.g. groups of 60–150 XP enemies) split six ways; with Base XP in the 360+ range, easy classes typically need more than two or three wins for L1→2.

---

## What happens on level-up

`CatCharacter._on_level_up()` (in order):

1. **Auto stat gains** from the sheet (`Auto Stat Gains`, e.g. `STR+1,VIT+1`) — permanent, no spend UI.
2. **`grant_level_points()`** — banks unspent stat / skill / spell points (see below).
3. **`pending_level_rolls += 1`** — one level-up die to roll later on the Level Up screen (`LevelUpDice` / `apply_level_roll`).
4. **Spellbook opening** — if this level unlocks the class's secondary book (`Spells Unlock At Level`), starter spells are granted + toast.
5. Vitals recalculated; HP and energy restored to full.

XP stops advancing once `level` hits **Max Level** (50 for every current class).

---

## Point grants (sheet values)

`ClassProgression.points_for_level(row, new_level)` returns `Vector3i(stat, skill, spell)`:

| Pool | Sheet columns | Notes |
|---|---|---|
| Stat points | `Stat Points Per Level` + milestone | Milestone: every `Milestone Every` levels, add `Milestone Stat Points` |
| Skill points | `Skill Points Per Level` | Then **ability cap** (below) |
| Spell points | `Spell Points Per Level` | **0** until `new_level >= Spells Unlock At Level`; unlock `0` means never |

These sheet numbers are the *requested* grant. Stat points are applied in full. Skill and spell points are clamped before they hit the character.

---

## Skill / spell point cap (half of known abilities)

**Skill and spell points — not stat points** — are capped so you never bank more ability ranks than you can usefully spend.

On every grant (`grant_level_points` and the ability portion of `apply_level_roll`):

```
granted = min( sheet_or_dice_amount, floor( known_count / 2 ) )
```

- Skill pool uses `known_skills.size()`.
- Spell pool uses `known_spells.size()`.
- Examples: 2 skills → at most **1** skill point that grant; 1 spell → **0** spell points; 4 spells → at most **2**.
- Sheet values (e.g. Spartan 6 skill/level) are unchanged; the cap only trims what actually banks into `unspent_skill_points` / `unspent_spell_points`.

Helper: `CatCharacter._capped_ability_grant(raw, known_count)`.

Stat points (`unspent_stat_points`) are **not** limited by known skills/spells.

---

## Level-up dice

Each level queues one pending roll. When the Level Up UI resolves it, `apply_level_roll(1..6)` applies `LevelUpDice` bonuses (extra stats, ability bank split across skills/spells, optional permanent max-HP %). Ability dice points go through the same half-known cap.

---

## HP / MP from the sheet

```
max HP = VIT × HP Per VIT + (level − 1) × HP Per Level
         (+ permanent % from lucky level-up dice)
max MP = INT + PIE + (level − 1) × MP Per Level
```

(`ClassProgression.max_hp` / `max_mp`; warriors vs casters differ via `HP Per VIT` / `HP Per Level` / `MP Per Level`.)

---

## Related files

| Piece | Path |
|---|---|
| Curve + point sheet | `Data/Class_Progression.csv` |
| Reader / formulas | `Scripts/Progression/ClassProgression.gd` |
| Apply XP / grants / cap | `resources/CatCharacter.gd` |
| Victory XP split | `Core/GameState.gd` (`_award_victory_xp`) |
| Enemy XP sources | `Data/Enemies.csv` → `xp_value`; summed in `CombatManager._collect_victory_rewards` |
| Level-up UI / dice | `Scripts/UI/LevelUpMenu.gd`, `Scripts/Progression/LevelUpDice.gd` |
| Learning skills/spells | `_documentation/SKILLS_AND_SPELLS.md` |
| Tests | `tests/progression/test_class_progression.gd`, `test_level_up_dice.gd` |
