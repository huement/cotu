# Throwing

Status as of 2026-11-10.

## How throwing works in battle

- **Item throw (Items menu).** Any item with `is_throwable = TRUE` can be used against enemies. Battle-only; uses one from the stack.
  - **Hit / crit:** thrower's DEX vs target speed (`CombatMath.throw_hit_chance` / `throw_crit_chance`).
  - **Damage:** STR-scaled (`CombatMath.throw_damage`), ignores half armour. Weaker than skill throws.
  - **Targets:** one enemy, unless `target_type = ALL_ENEMIES`.
- **Deadly Throw skill.** Ghostblade / Voidhand / Ronin / Shade / Warden. Consumes one knife or star from hands or pack, plays ThrowAnimator (`knife_throw` / `star_throw`), deals heavy skill damage.
- **Dual Flask (Maester).** Needs ≥2 equipped flasks; spends 2; hits the same target twice; plays `big_potion_throw`.
- **Crush Gems (Maester).** Field inventory skill: spend 1 `gem_*` → brew N Alchemy Flasks (`effect_amount`).
- **Ranged basics.** Bows spend arrow ammo (`bow_shot`). Maester basic flask attacks stay on WeaponAnimator `potion_throw`.

## Throwables

| Item | Anim | Notes |
|---|---|---|
| Steel / Holo-Shuriken | `star_throw` | Ghostblade kit → pack |
| Throwing Knife | `knife_throw` | Seeded for Deadly Throw classes |
| Kunai (`weap_kunai`) | `knife_throw` | Renamed from Radium Dart |

## ThrowAnimator

| File | Role |
|---|---|
| `Scenes/3D/throw_animator.tscn` | Pivot + models + AnimationPlayer |
| `Scripts/3D/ThrowAnimator.gd` | Plays clip, impact, hide |
| `Scenes/Player.tscn` | Instanced under Camera3D |
| `Core/SignalBus.gd` | `throw_requested` / `throw_animation_finished` |

Clips: `big_potion_throw`, `knife_throw`, `star_throw`. Item routing: `ItemData.get_throw_anim()` → `CombatManager._emit_throw_anim()`.

## Maester backup

`weap_maester_regular_backup` Wooden Staff (BASH) goes to the pack when Alchemy Flasks occupy the hand.

## Still open (art)

- Replace grey knife / star placeholder meshes.
- Re-key the three throw clips (impact frame + explosion only on potions).
