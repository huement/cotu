# Combat System: How It Works

Scripts involved:

| Script | Job |
|---|---|
| `Scripts/Managers/CombatManager.gd` (autoload) | The brain. Builds combatants, fills turn meters, runs every action, does all damage math, ends the battle. **Only it emits `combat_ended`.** |
| `Scripts/UI/BattleHUD.gd` | Action bar, target buttons, enemy HP header, chevron flash, spell VFX, **screen slice shader**. Sends `player_action_selected`. |
| `Scripts/UI/battle_ability_popup.gd` | Spell/skill picker. Stores the chosen ability in `TargetSelectionManager`, then sends `player_action_selected(SPELL/SKILL)`. |
| `Scripts/Managers/TargetSelectionManager.gd` (autoload) | Holds the pending item / ability between the popup and CombatManager. |
| `Scripts/3D/EnemyVisualManager.gd` | Spawns/positions enemy models, plays attack / hit / death animations from SignalBus events. |
| `Scripts/3D/weapon_animatior.gd` | First-person weapon swing (`weapon_swing_requested`). |
| `Scripts/3D/CameraShake.gd` | `camera_shake_requested` (trauma) + earthquakes. |
| `Scripts/Resources/EnemyData.gd`, `resources/CatCharacter.gd`, `ItemData`, `SpellData`, `SkillData`, `StatusEffectData` | The numbers. |

All communication goes through **SignalBus**.

---

## 1. Battle start

Something in the world (WorldEnemy, BlobBossController, TentacleBoss…) emits:

```
SignalBus.combat_started(enemy_group, party_slots, facing)
```

`CombatManager._on_combat_started`:
1. Bumps `_battle_serial` (any leftover coroutine from a previous battle sees the change and quits).
2. Builds one **Combatant** per party member and per enemy. All stats are **snapshotted here** (see §5).
3. Sets every turn meter to `speed × 5` (capped at 100), so fast characters start partly charged.

At the same time the HUD shows itself and builds the enemy header, and EnemyVisualManager spawns the models.

---

## 2. Turn meters (the "gauges")

Every frame (`_process`) while the battle can advance:

```
meter += effective_speed × base_tick_rate × delta      (base_tick_rate = 25)
```

- At **100** the combatant joins `turn_queue`.
- Meters are **frozen** while: a player is choosing an action, an action is playing out (`_is_resolving_action`), or the battle is ending.
- `turn_meter_updated(id, 0..1)` is emitted every frame for the portrait/enemy gauges.

Speed 10 → full meter in 0.4 s of *unfrozen* time. Raise/lower `base_tick_rate` in the CombatManager autoload inspector to change overall battle tempo.

---

## 3. A turn, start to finish

### 3a. Start of turn: `_process_turn_queue()`
For the next combatant in the queue:
1. **Party member:** their **Guard ends** (guard lasts until your own next turn).
2. **Tick effects** (`_tick_effects_at_turn_start`): DoT deals damage, HoT heals, every effect's duration −1, expired effects are removed.
3. If that killed them → meter reset, skip. If it ended the battle → stop.
4. **Stunned / frozen** (`SKIP_TURN`) → "unable to act", meter reset, skip.
5. Otherwise:
   - **Party member:** `is_paused_for_input = true`, emit `combatant_turn_ready(id, slot)`. HUD shows the action bar (or AUTO picks ATTACK).
   - **Enemy:** `_run_enemy_turn()` starts immediately.

### 3b. The action
Player picks an action → HUD/popup emits `player_action_selected(slot, action, target)`. Meters stay frozen from here until the end of the turn.

| Action | What happens |
|---|---|
| **ATTACK** | Weapon swing animation → wait `player_attack_windup` (0.25 s) → damage lands (slice/shake/sound/VFX at impact) → weapon on-hit effects roll (Burn/Freeze/Stun). Ranged weapons use 1 ammo; no ammo = unarmed punch. |
| **SPELL / SKILL** | Cost check & mana spent (CombatManager only) → skill accuracy roll → spell VFX + shake → wait `spell_windup` (0.35 s) → effect applied to each target (see §4). Silenced characters can't cast. |
| **ITEM** | Inventory `use_item` on the chosen party member, HP/MP synced back. |
| **DEFEND** | Added to `guarding_characters` → takes 50% physical damage until their next turn. |
| **RUN** | Flee chance = 60% + 5% per point of (your speed − average enemy speed), clamped 15–95%. Success ends the battle (no rewards). |

**Enemy turn:** if `can_cast_spells` and it rolls under `enemy_spell_chance` (50%) it casts a random spell from `spell_ids`; otherwise it attacks physically. Either way `enemy_attack_started` fires first (model plays its attack / blob lunge), then after `enemy_attack_windup` (0.45 s) the hit lands. Targets are random living party members (heals go to the most-hurt ally).

### 3c. End of turn: `_end_action()`
1. Actor's meter → 0.
2. **Victory/defeat check.** If one side is wiped → §6.
3. Wait `action_recovery` (0.55 s) so hit/death animations finish.
4. Unfreeze meters, start the next queued turn (or keep ticking).

Because meters are frozen from the windup until the recovery ends, **every action's animation plays fully before the next action starts**: no more hits landing before swings, or several enemies acting in the same frame.

---

## 4. Spells & skills

The category comes from the resource's `effect_type` enum:

| SpellData.effect_type | SkillData.effect_type | Does |
|---|---|---|
| DAMAGE | DAMAGE | Damage (§5), then applies `status_effect` if the target survives |
| HEAL | HEAL | Heals `power` HP (Revive spells can target the dead). Multi-turn spells add a HoT. |
| BUFF | — | Applies `status_effect` (e.g. `eff_shield_2`), or +`power` flat defense if none |
| DEBUFF | — | Applies `status_effect`, or −`power` flat defense if none |
| UTILITY | other skill types | Applies `status_effect` if any |

Targets come from `target_type`: SINGLE_ENEMY, ALL_ENEMY, SINGLE_ALLY, ALL_ALLY, SELF (NONE = self).

**Power**
- Spells: `SpellData.calculate_potency(caster_stat)` = `base_amount + random(0, base_amount × var_multiplier) + caster_stat / 2`.
  - Player `caster_stat` = the stat in `stat_scaling` (`INT` / `PIE` / `PER` …) **including equipment bonuses**.
  - Enemy `caster_stat` = `EnemyData.magic_power`.
  - Then × "Magic Up/Down" status × equipment **Amplify**.
- Skills: `effect_amount`.

**Status effects** come from `Data/StatusEffects/*.tres` (built from `Data/status_effects.csv`) by `effect_id`:

| modifier_type | In combat |
|---|---|
| MULTIPLIER | ±% to DEF / ATK / SPD / MAG / ACC / DEX |
| PERCENT_MAX_HP_TICK | DoT: % of target max HP each of its turns (poison, burn) |
| PERCENT_MAX_HP_HEAL | HoT |
| PERCENT_SHIELD | Absorbs any damage up to % max HP |
| PERCENT_MAGIC_SHIELD | Absorbs spell damage up to % max HP |
| CC_SKIP_TURN | Stun/freeze: meter reset + skips its next turn(s) |
| CC_LOCK_MAGIC | Silence: can't cast spells |

Duration = the larger of the status's `duration` and the ability's duration.

---

## 5. Damage math

### Stats (snapshotted at battle start)

**Party member**
- **Attack** = STR *(with "+STR" gear, same as the character sheet)* + **every** equipped item's `attack_bonus` (weapon counted **once**).
- **Defense** = `player_base_defense` (2) + every equipped item's `defense_bonus` (HEAD, BODY, **ARMS**, LEGS, **FEET**, hands, accessories).
- **Speed** = SPD *(with "+SPD" gear)* + every item's `speed_bonus`.
- **Equipment specials** (`ItemData.effects`):

  | effects | effect_amount | Combat effect |
  |---|---|---|
  | Resist | fraction (0.5 = 50%) | Ignore that much damage of `effect_element` (MAGIC = **magic defense**) |
  | Amplify | multiplier (1.2) | Spell damage × amount |
  | Pierce | fraction (0.3) | Weapon attacks ignore 30% of the target's defense |
  | Burn / Freeze / Stun | chance (≤1 = fraction, >1 = percent) | Rolled on each weapon hit → `eff_hp_burn_1` / `eff_freeze_1` / `eff_stun_1` |

**Enemy** (`EnemyData`)
- **Attack** = `attack_damage` · **Defense** = `defense` · **Speed** = `speed`
- `weakness_element`: hits of that type do ×1.5 (MAGIC = every spell)
- `magic_resist`: fraction of spell damage ignored (magic defense)
- `attack_element`: its physical attack type (BLADE/BASH/RANGED)

Buffs/debuffs apply on top: flat first, then percent.

### Physical attack
```
damage = max(1, ATK − DEF × (1 − pierce))
       × 0.5 if melee attacker is in the back row
       × 0.5 if the defender is in the back row
       × 0.5 if the defender is Guarding
       × 1.5 if the attack type matches the defender's weakness
       × (1 − defender's resist to that type)
→ shields absorb → HP
```
Unarmed attacks (no weapon / out of ammo) drop the weapon's attack bonus.

### Spell
```
damage = power × 1.5 if weak to MAGIC × (1 − magic resist)  → magic shield / shield absorb → HP
```
Spells ignore physical defense, rows and guard.

### Physical skill
```
damage = effect_amount × row × guard × weakness × (1 − resist)
```
(Skills don't use ATK/DEF; their damage is the skill's own number.)

---

## 6. Battle end

`_check_battle_state()` runs after every action and every DoT tick.

1. All enemies dead → **victory**. All party dead → **defeat**. Successful RUN → **fled** (counts as `victory = false`).
2. `_finish_battle()` sets `is_transitioning_out` (meters, queue and in-flight actions stop immediately).
3. Victory only: rewards are collected (XP/gold per dead enemy, loot rolled into the inventory, gold added), then it waits `victory_linger` (1 s) for death animations.
4. State is reset, **`combat_ended(victory)` is emitted once**, the game saves, and on victory the `BATTLE_VICTORY` popup opens.

Listeners: the HUD hides, EnemyVisualManager clears models, world enemies/bosses despawn on victory or reset on false, player movement unlocks.

⚠️ **Defeat and fleeing are the same signal (`victory = false`)**: there's no game-over screen yet; a wiped party just leaves battle.

---

## 7. Visual feedback: what fires when

| Moment | Signal | Who reacts |
|---|---|---|
| Player attack starts | `weapon_swing_requested` (sword_swing / staff_bash / bow_shot) | WeaponAnimator |
| Enemy attack/spell starts | `enemy_attack_started` | EnemyVisualManager (attack anim, blob lunge) |
| Spell cast starts | `spell_vfx_requested` + shake 0.6 | BattleHUD elemental VFX + edge flash |
| Party member takes a physical hit | `screen_slice_requested` + shake 0.85 + chevrons red | BattleHUD slice shader |
| Party member takes a spell hit | shake 0.65 + chevrons red | |
| Enemy takes a BLADE hit (any hit vs water enemies) | `screen_slice_requested` | BattleHUD slice shader |
| Enemy takes a weapon hit | attack sound, shake by type, weapon/skill `attack_vfx`, `enemy_damaged_visual` | EnemyVisualManager hit shake |
| Enemy HP 0 | `enemy_health_changed(…, 0)` | EnemyVisualManager death sink / death anim |

The slice only plays for physical hits on the party, and BLADE hits on enemies (plus every hit in water fights). Each new slice restarts the shader cleanly.

---

## 8. Tuning knobs (CombatManager autoload inspector)

| Setting | Default | Effect |
|---|---|---|
| `base_tick_rate` | 25 | Overall battle tempo |
| `player_attack_windup` | 0.25 s | Swing → hit delay |
| `enemy_attack_windup` | 0.45 s | Enemy anim → hit delay (blob lunge peaks ~0.54 s) |
| `spell_windup` | 0.35 s | Spell VFX → effect delay |
| `action_recovery` | 0.55 s | Pause after each action |
| `victory_linger` | 1.0 s | Hold after the last kill |
| `player_base_defense` | 2 | Defense before armor |
| `weakness_multiplier` | 1.5 | Weakness bonus |
| `enemy_spell_chance` | 0.5 | How often casters cast |

The battle log (`GameLogger.combat`) prints every combatant's final ATK / DEF / SPD / HP / magic resist when the battle starts, so you can verify gear is being counted.

---

## 9. Known gaps (not implemented yet)

- No game-over on party wipe (see §6).
- Items with **ALL_PARTY** / **ALL_ENEMIES** targets only affect the user (TargetSelectionManager sends target −1).
- DEX and accuracy don't affect normal attacks (no hit/miss or crits for ATTACK); only skills roll accuracy.
- Every party member defaults to `is_front_row = true`, so back-row rules only matter if you set rows.
- Skills don't scale with STR / weapons, and spells ignore physical DEF (by design above; change in `_calculate_ability_damage` if you want otherwise).

## Pure helpers (`Scripts/Combat/`)

CombatManager keeps battle state, timing, signals and logging. Everything that is just math lives in small
static, typed classes that need no scene tree, so they can be read and unit-tested on their own:

| File | What |
|---|---|
| `Combatant.gd` / `ActiveEffect.gd` | Battle snapshot of a fighter + buffs; effective stats (flat then %), shields |
| `CombatMath.gd` | `physical_damage`, `ability_power`, `ability_damage`, `ability_duration`, `flee_chance`, `next_meter`, `average_speed`, element/attack-type maps, `as_fraction`, `cat_attribute`, `modifier_stat_name` |
| `CombatTargeting.gd` | `resolve_ability_targets`, `pick_opponent`, `find_by_id` / `find_by_slot`, `living` |
| `AbilityInfo.gd` | `category`, `display_name`, `id`, `status_id`, `hit_verb` |

State the helpers need (guard state, `weakness_multiplier`, `base_tick_rate`, the combatant list) is passed in
by CombatManager's thin wrappers (`_calculate_physical_damage`, `_calculate_ability_damage`, `_is_guarding`,
`_resolve_ability_targets`, `_pick_opponent`, …).

Tests: `tests/combat/` (GUT, fixtures in `combat_fixtures.gd`):
`godot --path . --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
