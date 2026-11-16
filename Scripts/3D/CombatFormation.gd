# res://Scripts/3D/CombatFormation.gd
class_name CombatFormation
extends RefCounted
## 5-slot front/back battle formation for combat models.
##
## Camera view (farther = front row):
##         [2]     [1]     [3]
##             [4]     [5]
##
## Slot 1 is always reserved for a solo enemy or a marked boss (`combat_is_boss` meta).

const BOSS_META: StringName = &"combat_is_boss"

## Default lateral gap between front-row centers (metres).
const DEFAULT_SPACING: float = 1.8
## How much closer to the camera the back row sits (metres).
const DEFAULT_BACK_PULL: float = 0.75


## True when this EnemyData was marked as the fight's boss.
static func is_boss(data: Resource) -> bool:
	return is_instance_valid(data) and data.has_meta(BOSS_META) and bool(data.get_meta(BOSS_META))


## Marks a duplicated EnemyData as the fight boss (formation slot 1).
static func mark_boss(data: Resource) -> void:
	if is_instance_valid(data):
		data.set_meta(BOSS_META, true)


## Returns one formation slot (1–5) per enemy index in `group`.
static func get_best_slots(group: Array[Resource]) -> PackedInt32Array:
	var n: int = group.size()
	var slots := PackedInt32Array()
	if n <= 0:
		return slots

	var boss_idx: int = _find_boss_index(group)

	match n:
		1:
			slots.append(1)
		2:
			if boss_idx >= 0:
				slots.resize(2)
				slots[boss_idx] = 1
				slots[1 - boss_idx] = 2
			else:
				slots.append(2)
				slots.append(3)
		3:
			if boss_idx >= 0:
				slots = _assign_with_boss_center(n, boss_idx, [2, 3])
			else:
				# Pack order → left / center / right
				slots.append(2)
				slots.append(1)
				slots.append(3)
		4:
			if boss_idx >= 0:
				slots = _assign_with_boss_center(n, boss_idx, [2, 3, 4])
			else:
				slots.append(2)
				slots.append(1)
				slots.append(3)
				slots.append(4)
		_:
			# 5+ — fill all slots; extras keep stacking on 5
			if boss_idx >= 0:
				var extras: Array[int] = [2, 3, 4, 5]
				while extras.size() < n - 1:
					extras.append(5)
				slots = _assign_with_boss_center(n, boss_idx, extras)
			else:
				var fill: Array[int] = [2, 1, 3, 4, 5]
				for i: int in n:
					slots.append(fill[mini(i, fill.size() - 1)])
	return slots


## Camera-relative offset for a slot: x = lateral (camera right), y = depth_delta
## (added to base forward distance; positive = farther / front row).
static func slot_offset(slot: int, spacing: float = DEFAULT_SPACING, back_pull: float = DEFAULT_BACK_PULL) -> Vector2:
	var s: float = maxf(0.1, spacing)
	var pull: float = maxf(0.0, back_pull)
	match clampi(slot, 1, 5):
		1:
			return Vector2(0.0, 0.0)
		2:
			return Vector2(-s, 0.0)
		3:
			return Vector2(s, 0.0)
		4:
			return Vector2(-s * 0.5, -pull)
		5:
			return Vector2(s * 0.5, -pull)
		_:
			return Vector2.ZERO


static func _find_boss_index(group: Array[Resource]) -> int:
	for i: int in group.size():
		if is_boss(group[i]):
			return i
	return -1


## Boss always in slot 1; remaining enemies fill `other_slots` in left-to-right index order.
static func _assign_with_boss_center(n: int, boss_idx: int, other_slots: Array) -> PackedInt32Array:
	var slots := PackedInt32Array()
	slots.resize(n)
	slots[boss_idx] = 1
	var next: int = 0
	for i: int in n:
		if i == boss_idx:
			continue
		var slot_num: int = int(other_slots[mini(next, other_slots.size() - 1)])
		slots[i] = slot_num
		next += 1
	return slots
