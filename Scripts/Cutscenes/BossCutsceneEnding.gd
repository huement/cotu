# res://Scripts/Cutscenes/BossCutsceneEnding.gd
class_name BossCutsceneEnding
extends Resource
## What happens at the end of a boss villain cutscene (BossVillainCutscene).
##
## Order: the boss's DIALOG first, then the screen fades to black and:
##   - DRAIN (optional, works with anything): the party is left with a sliver of HP and Mana.
##   - then ONE of:  nothing (they just wake up)  /  a forced FIGHT  /  TRAVEL to another level.
##
## Bosses build one of these from their own inspector settings (see MalviathanController) and send
## it along with SignalBus.boss_cutscene_requested.

enum After {
	NOTHING, ## The party wakes up where it stood.
	FIGHT,   ## Forced battle against `fight_enemies`, right where the party stands.
	TRAVEL,  ## The party wakes up in `travel_scene`.
}

const MAX_FIGHT_ENEMIES: int = 4

@export_group("Dialog")
## Shown above the text. Empty = no name line.
@export var speaker_name: String = ""
## What the boss says. Empty = no dialog box at all.
@export_multiline var dialog_text: String = ""
## Picture in the corner of the dialog box.
@export var avatar: Texture2D

@export_group("After The Dialog")
@export var after: After = After.NOTHING
## FIGHT: the enemy pack (first 4 are used).
@export var fight_enemies: Array[EnemyData] = []
## TRAVEL: the level to wake up in.
@export_file("*.tscn") var travel_scene: String = ""
## TRAVEL: marker in that level the party arrives on.
@export var travel_arrival_point: String = "SpawnPoint"

@export_group("Drain")
## Leave the party wrecked but alive. Combines with any `after` choice.
@export var drain_party: bool = false
## How much HP and Mana each living member is LEFT with, as a percent of their maximum.
@export_range(1.0, 100.0, 1.0) var vitals_left_percent: float = 1.0


func has_dialog() -> bool:
	return not dialog_text.strip_edges().is_empty()


## The enemies for the forced fight: valid entries only, at most MAX_FIGHT_ENEMIES, each its own
## copy so the battle never edits the shared .tres data.
func build_fight_group() -> Array[Resource]:
	var group: Array[Resource] = []
	for enemy: EnemyData in fight_enemies:
		if enemy == null:
			continue
		if group.size() >= MAX_FIGHT_ENEMIES:
			break # extra entries are ignored
		var copy: EnemyData = enemy.duplicate(false) as EnemyData # shallow: keeps model / material refs
		copy.current_health = copy.max_health
		group.append(copy)
	return group


## What a vital drops to when drained. Never raises it, never kills: a living member keeps at
## least 1 HP; Mana may reach 0 only if it already was.
static func drained_value(current: int, maximum: int, left_percent: float) -> int:
	if current <= 0:
		return current
	var floor_value: int = maxi(1, ceili(float(maximum) * clampf(left_percent, 0.0, 100.0) / 100.0))
	return mini(current, floor_value)


## Drains every living party member and returns the slots that changed (for HUD updates).
func apply_drain(party_slots: Array) -> Array[int]:
	var changed: Array[int] = []
	if not drain_party:
		return changed
	for i: int in range(party_slots.size()):
		var member: CatCharacter = party_slots[i] as CatCharacter
		if member == null or member.current_hp <= 0:
			continue
		member.current_hp = drained_value(member.current_hp, member.max_hp, vitals_left_percent)
		member.current_mana = drained_value(member.current_mana, member.max_mana, vitals_left_percent)
		changed.append(i)
	return changed
