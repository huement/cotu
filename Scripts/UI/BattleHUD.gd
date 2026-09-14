# res://Scripts/UI/BattleHUD.gd
class_name BattleHUD
extends Control

enum CombatState {
	IDLE,
	AWAITING_ACTION,
	SELECTING_TARGET,
}

const ACTION_ATTACK: StringName = &"ATTACK"

@onready var enemy_name_label: Label = %EnemyNameLabel as Label
@onready var enemy_hp_label: Label = %EnemyHPLabel as Label
@onready var turn_character_label: Label = %TurnCharacter as Label
@onready var turn_info_label: Label = %TurnInfo as Label

@onready var left_chevrons: TextureRect = %LeftChevrons as TextureRect
@onready var right_chevrons: TextureRect = %RightChevrons as TextureRect
@onready var auto_button: TextureButton = %AutoButton as TextureButton

@onready var party_left: VBoxContainer = %PartyLeft as VBoxContainer
@onready var party_right: VBoxContainer = %PartyRight as VBoxContainer
@onready var action_bar: Control = %ActionBar as Control
@onready var elemental_vfx: AnimatedSprite2D = %ElementalVFX as AnimatedSprite2D
@onready var edge_flash: Control = %EdgeFlash as Control
@onready var slice_overlay: ColorRect = %SliceOverlay as ColorRect

var portrait_slots: Array[Node] = []
var _state: CombatState = CombatState.IDLE
var _active_slot_index: int = -1
var _selected_action: StringName = &""
var _is_auto_battle_on: bool = false
var _buttons_bound: bool = false
var current_turn_slot_index: int = -1
var _enemy_max_hps: Dictionary = {}
var _enemy_current_hps: Dictionary = {}

func _ready() -> void:
	hide()
	_initialize_portrait_slots()
	_connect_to_signal_bus()
	_bind_action_buttons()

	if is_instance_valid(auto_button):
		auto_button.toggled.connect(_on_auto_button_toggled)
	if is_instance_valid(elemental_vfx):
		elemental_vfx.hide()
		if not elemental_vfx.animation_finished.is_connected(_on_vfx_animation_finished):
			elemental_vfx.animation_finished.connect(_on_vfx_animation_finished)
	if is_instance_valid(SignalBus) and SignalBus.has_signal(&"screen_slice_requested"):
		if not SignalBus.screen_slice_requested.is_connected(play_screen_slice):
			SignalBus.screen_slice_requested.connect(play_screen_slice)

func _bind_action_buttons() -> void:
	if _buttons_bound or not is_instance_valid(action_bar):
		return

	_buttons_bound = true
	var buttons: Array[Node] = action_bar.find_children("*", "BaseButton", true, false)

	for node: Node in buttons:
		var btn: BaseButton = node as BaseButton
		if is_instance_valid(auto_button) and btn == auto_button:
			continue

		var action_type: StringName = &"ATTACK"

		if "action_type" in btn:
			action_type = btn.get("action_type") as StringName
		else:
			var b_name: String = btn.name.to_upper()
			if "DEFEND" in b_name:
				action_type = &"DEFEND"
			elif "MAGIC" in b_name or "SPELL" in b_name or "SKILL" in b_name:
				action_type = &"SPELL"
			elif "ITEM" in b_name:
				action_type = &"ITEM"
			elif "RUN" in b_name or "FLEE" in b_name:
				action_type = &"RUN"

		btn.pressed.connect(_on_action_button_pressed.bind(action_type, btn.name))


func _connect_to_signal_bus() -> void:
	var sb: Node = SignalBus
	if not is_instance_valid(sb):
		return

	if not sb.combat_started.is_connected(_on_combat_started):
		sb.combat_started.connect(_on_combat_started)
	if not sb.combat_ended.is_connected(_on_combat_ended):
		sb.combat_ended.connect(_on_combat_ended)
	if not sb.combatant_turn_ready.is_connected(_on_combatant_turn_ready):
		sb.combatant_turn_ready.connect(_on_combatant_turn_ready)
	if not sb.enemy_health_changed.is_connected(_on_enemy_health_changed):
		sb.enemy_health_changed.connect(_on_enemy_health_changed)
	if not sb.chevron_flash_requested.is_connected(_on_chevron_flash):
		sb.chevron_flash_requested.connect(_on_chevron_flash)
	if not sb.player_action_selected.is_connected(_on_player_action_selected):
		sb.player_action_selected.connect(_on_player_action_selected)
	if not sb.spell_vfx_requested.is_connected(_on_spell_vfx_requested):
		sb.spell_vfx_requested.connect(_on_spell_vfx_requested)


func _on_player_action_selected(_slot_index: int, _action: StringName, _target_index: int) -> void:
	_reset_state()


func _on_combatant_turn_ready(combatant_id: String, slot_index: int) -> void:
	current_turn_slot_index = slot_index

	if not combatant_id.begins_with("party_slot_"):
		return

	if _is_auto_battle_on:
		SignalBus.player_action_selected.emit(slot_index, ACTION_ATTACK, 0)
		return

	_state = CombatState.AWAITING_ACTION
	_active_slot_index = slot_index

	for i: int in range(portrait_slots.size()):
		if is_instance_valid(portrait_slots[i]) and portrait_slots[i].has_method("set_active"):
			portrait_slots[i].set_active(i == slot_index)

	var cat_name: String = "COMMANDER WHISKERS"
	var gs: Node = get_tree().root.get_node_or_null("GameState")

	if is_instance_valid(gs) and "current_party" in gs and gs.current_party:
		var slots: Array = gs.current_party.get("slots") as Array
		if slot_index >= 0 and slot_index < slots.size() and is_instance_valid(slots[slot_index]):
			var cat_res: Resource = slots[slot_index] as Resource
			if "name" in cat_res and cat_res.get("name") != null:
				cat_name = str(cat_res.get("name")).to_upper()
			elif "character_name" in cat_res and cat_res.get("character_name") != null:
				cat_name = str(cat_res.get("character_name")).to_upper()

	if is_instance_valid(turn_character_label):
		turn_character_label.text = cat_name
	if is_instance_valid(turn_info_label):
		turn_info_label.text = "ACTIVE"
	if is_instance_valid(action_bar):
		action_bar.show()


func _on_action_button_pressed(action_type: StringName, _button_name: String) -> void:
	if _state != CombatState.AWAITING_ACTION:
		return

	match action_type:
		&"SPELL", &"SKILL":
			var gs: Node = get_tree().root.get_node_or_null("GameState")
			var cm: Node = get_tree().root.get_node_or_null("CombatManager")

			var active_cat: CatCharacter = null
			if is_instance_valid(gs) and "current_party" in gs and gs.current_party:
				var slots: Array = gs.current_party.get("slots") as Array
				if _active_slot_index >= 0 and _active_slot_index < slots.size():
					active_cat = slots[_active_slot_index] as CatCharacter

			var combatants_list: Array = []
			if is_instance_valid(cm) and "combatants" in cm:
				combatants_list = cm.get("combatants") as Array

			SignalBus.popup_requested.emit(&"BATTLE_ABILITIES", { "character": active_cat, "slot_index": _active_slot_index, "combatants": combatants_list })

		&"ITEM":
			var gs: Node = get_tree().root.get_node_or_null("GameState")
			var inv: Inventory = gs.get("inventory") as Inventory if is_instance_valid(gs) and "inventory" in gs else null
			var cm: Node = get_tree().root.get_node_or_null("CombatManager")
			var combatants_list: Array = []
			if is_instance_valid(cm) and "combatants" in cm:
				combatants_list = cm.get("combatants") as Array

			GameLogger.combat("BATTLE ITEM ACTION triggered for slot %d" % [_active_slot_index])

			SignalBus.popup_requested.emit(&"BATTLE_ITEMS", { "slot_index": _active_slot_index, "inventory": inv, "combatants": combatants_list })

		_:
			var current_slot: int = _active_slot_index
			SignalBus.player_action_selected.emit(current_slot, action_type, 0)


func _on_spell_vfx_requested(anim_name: String, element: ItemData.ElementalBase) -> void:
	GameLogger.combat("_on_spell_vfx_requested %s" % [anim_name])
	# 1. Play specific SpriteFrames animation by string key
	if is_instance_valid(elemental_vfx) and elemental_vfx.sprite_frames.has_animation(anim_name):
		GameLogger.combat("FIREING ANIMATION FOR %s" % [anim_name])
		elemental_vfx.show()
		elemental_vfx.play(anim_name)

	# 2. Flash screen edge overlay using elemental tint
	if is_instance_valid(edge_flash) and element != ItemData.ElementalBase.NONE:
		var flash_color: Color = _get_element_color(element)
		edge_flash.modulate = flash_color
		edge_flash.modulate.a = 0.8
		edge_flash.show()
		GameLogger.combat("EDGE FLASH COLOR %s" % [flash_color])
		
		var tween: Tween = create_tween()
		tween.tween_property(edge_flash, "modulate:a", 0.0, 0.5)
		tween.tween_callback(edge_flash.hide)

func _get_element_color(element: ItemData.ElementalBase) -> Color:
	match element:
		ItemData.ElementalBase.FIRE:
			return Color(1.0, 0.2, 0.1) # Flame Red
		ItemData.ElementalBase.WATER:
			return Color(0.1, 0.5, 1.0) # Aqua Blue
		ItemData.ElementalBase.EARTH:
			return Color(0.4, 0.7, 0.2) # Nature Green
		ItemData.ElementalBase.AIR:
			return Color(0.6, 0.9, 1.0) # Gust Cyan
		ItemData.ElementalBase.BOLT:
			return Color(1.0, 0.9, 0.1) # Electric Yellow
		ItemData.ElementalBase.DARK:
			return Color(0.6, 0.1, 0.8) # Void Purple
		ItemData.ElementalBase.LIFE:
			return Color(0.2, 0.9, 0.4) # Holy Green
		_:
			return Color.WHITE
					
func _on_elemental_vfx_requested(element: ItemData.ElementalBase) -> void:
	if not is_instance_valid(elemental_vfx):
		return

	var anim_name: String = ItemData.ElementalBase.keys()[element] # Returns "FIRE"
	if elemental_vfx.sprite_frames.has_animation(anim_name):
		elemental_vfx.show()
		elemental_vfx.play(anim_name)


func _on_vfx_animation_finished() -> void:
	if is_instance_valid(elemental_vfx):
		elemental_vfx.hide()


func _reset_state() -> void:
	for slot in portrait_slots:
		if is_instance_valid(slot) and slot.has_method("set_active"):
			slot.set_active(false)

	_state = CombatState.IDLE
	_active_slot_index = -1
	_selected_action = &""

	if is_instance_valid(action_bar):
		action_bar.hide()
	if is_instance_valid(turn_info_label):
		turn_info_label.text = "WAITING"


func _on_auto_button_toggled(is_on: bool) -> void:
	_is_auto_battle_on = is_on
	if is_instance_valid(auto_button):
		auto_button.modulate = Color.GREEN if is_on else Color.WHITE



func _on_chevron_flash(is_player_hit: bool) -> void:
	var flash_color: Color = Color.RED if is_player_hit else Color.ORANGE
	var tween: Tween = create_tween().set_parallel(true)
	if is_instance_valid(left_chevrons):
		left_chevrons.modulate = flash_color
		tween.tween_property(left_chevrons, "modulate", Color.WHITE, 0.4)
	if is_instance_valid(right_chevrons):
		right_chevrons.modulate = flash_color
		tween.tween_property(right_chevrons, "modulate", Color.WHITE, 0.4)


func _initialize_portrait_slots() -> void:
	portrait_slots.clear()
	portrait_slots.resize(6)

	var all_portraits: Array[Node] = []
	if is_instance_valid(party_left):
		all_portraits.append_array(party_left.get_children())
	if is_instance_valid(party_right):
		all_portraits.append_array(party_right.get_children())

	for portrait: Node in all_portraits:
		if "slot_index" in portrait:
			var idx: int = portrait.get("slot_index")
			if idx >= 0 and idx < 6:
				portrait_slots[idx] = portrait


## Resolves any enemy payload variant into typed Array[Resource] for HUD initialization
func _resolve_enemy_resources(payload: Variant) -> Array[Resource]:
	var result: Array[Resource] = []

	if payload is Array:
		for item in (payload as Array):
			if item is Resource:
				result.append(item as Resource)
			elif is_instance_valid(item) and "enemy_group" in item:
				var group_array: Variant = item.get("enemy_group")
				if group_array is Array:
					for sub_item in (group_array as Array):
						if sub_item is Resource:
							result.append(sub_item as Resource)

	elif is_instance_valid(payload):
		if "enemy_group" in payload:
			var group_val: Variant = payload.get("enemy_group")
			if group_val is Array and not (group_val as Array).is_empty():
				for item in (group_val as Array):
					if item is Resource:
						result.append(item as Resource)

		if result.is_empty() and "members" in payload:
			var members_val: Variant = payload.get("members")
			if members_val is Array and not (members_val as Array).is_empty():
				for item in (members_val as Array):
					if item is Resource:
						result.append(item as Resource)

		if result.is_empty() and payload is Resource:
			var target_res: Resource = payload as Resource
			var overworld_enemies: Array[Node] = get_tree().get_nodes_in_group(&"world_enemies")
			if overworld_enemies.is_empty():
				overworld_enemies = get_tree().root.find_children("*", "WorldEnemy", true, false)

			for node in overworld_enemies:
				if is_instance_valid(node) and ("enemy_group" in node):
					var grp: Variant = node.get("enemy_group")
					var n_data: Variant = node.get("data") if "data" in node else null
					var n_edata: Variant = node.get("enemy_data") if "enemy_data" in node else null

					if (grp is Array and (grp as Array).has(target_res)) or n_data == target_res or n_edata == target_res:
						if grp is Array and not (grp as Array).is_empty():
							for item in (grp as Array):
								if item is Resource:
									result.append(item as Resource)
							break

			if result.is_empty():
				var count: int = 1
				if "pack_size" in payload:
					count = max(1, int(payload.get("pack_size")))
				for i in range(count):
					result.append(target_res.duplicate() if count > 1 else target_res)

	return result


func _on_combat_started(enemy_payload: Variant, player_party: Array) -> void:
	show()
	_reset_state()
	_bind_action_buttons()
	setup_party_display(player_party)

	var enemy_resources: Array[Resource] = _resolve_enemy_resources(enemy_payload)
	_enemy_max_hps.clear()
	_enemy_current_hps.clear()

	var total_max_hp: int = 0
	var base_name: String = "CYBER-ZOMBIE CAT"

	for i in range(enemy_resources.size()):
		var res: Resource = enemy_resources[i]
		var e_id: String = "enemy_%d" % i
		var hp: int = 30

		if is_instance_valid(res):
			if "enemy_name" in res and res.get("enemy_name") != null:
				base_name = str(res.get("enemy_name"))
			if "max_health" in res and res.get("max_health") != null:
				hp = int(res.get("max_health"))

		_enemy_max_hps[e_id] = hp
		_enemy_current_hps[e_id] = hp
		total_max_hp += hp

	if is_instance_valid(enemy_name_label):
		if enemy_resources.size() > 1:
			enemy_name_label.text = "%s (x%d)" % [base_name.to_upper(), enemy_resources.size()]
		else:
			enemy_name_label.text = base_name.to_upper()

	if is_instance_valid(enemy_hp_label):
		enemy_hp_label.text = "%d / %d" % [total_max_hp, total_max_hp]


## Fixed parameter signature to accept enemy_id emitted from SignalBus
func _on_enemy_health_changed(enemy_id: String, current_hp: int, max_hp: int) -> void:
	_enemy_current_hps[enemy_id] = current_hp
	_enemy_max_hps[enemy_id] = max_hp

	var total_current: int = 0
	var total_max: int = 0

	for id in _enemy_max_hps:
		total_current += _enemy_current_hps.get(id, 0)
		total_max += _enemy_max_hps.get(id, 0)

	if is_instance_valid(enemy_hp_label):
		enemy_hp_label.text = "%d / %d" % [total_current, total_max]


func _on_combat_ended(_victory: bool) -> void:
	hide()
	_reset_state()


func setup_party_display(party_members: Array) -> void:
	if portrait_slots.is_empty():
		_initialize_portrait_slots()

	for i: int in range(portrait_slots.size()):
		var slot_node: Node = portrait_slots[i]
		if not is_instance_valid(slot_node):
			continue

		if i < party_members.size() and is_instance_valid(party_members[i]):
			if slot_node.has_method("setup_slot"):
				slot_node.call("setup_slot", party_members[i])
		else:
			if slot_node.has_method("setup_slot"):
				slot_node.call("setup_slot", null)


## Formats enemy names for single-type vs mixed encounters
func update_enemy_header_display(enemy_pack: Array[EnemyData]) -> void:
	var name_label := %EnemyNameLabel as Label if has_node("%EnemyNameLabel") else null
	if name_label == null or enemy_pack.is_empty():
		return

	# Collect unique enemy names and counts
	var name_counts: Dictionary = { }
	for res in enemy_pack:
		if res is EnemyData:
			var e_name: String = (res as EnemyData).enemy_name.to_upper()
			name_counts[e_name] = name_counts.get(e_name, 0) + 1

	# Format display string based on pack composition
	var display_text: String = ""
	if name_counts.size() == 1:
		# Single enemy type encounter (e.g. "SCAVENGER DRONE (X2)" or "ZOMBIE CAT")
		var sole_name: String = name_counts.keys()[0] as String
		var count: int = name_counts[sole_name] as int
		if count > 1:
			display_text = "%s  (X%d)" % [sole_name, count]
		else:
			display_text = sole_name
	else:
		# Mixed encounter (e.g. "SCAVENGER DRONE & ZOMBIE CAT")
		var formatted_names: Array[String] = []
		for e_name in name_counts.keys():
			var count: int = name_counts[e_name] as int
			if count > 1:
				formatted_names.append("%s (X%d)" % [e_name, count])
			else:
				formatted_names.append(e_name as String)
		display_text = " & ".join(formatted_names)

	name_label.text = display_text


func _on_defend_button_pressed() -> void:
	if current_turn_slot_index < 0:
		return

	# Emit DEFEND action to CombatManager
	SignalBus.player_action_selected.emit(current_turn_slot_index, &"DEFEND", -1)


func _on_run_button_pressed() -> void:
	if current_turn_slot_index < 0:
		return

	# Emit RUN action to CombatManager
	SignalBus.player_action_selected.emit(current_turn_slot_index, &"RUN", -1)

## Plays the diagonal full-screen slice animation for blade impacts
func play_screen_slice() -> void:
	if not is_instance_valid(slice_overlay) or slice_overlay.material == null:
		return

	var mat := slice_overlay.material as ShaderMaterial
	if mat == null:
		return

	var tween: Tween = create_tween()
	tween.tween_property(mat, "shader_parameter/progress", 1.0, 0.22) \
		.from(0.0) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)

	tween.finished.connect(func() -> void:
		mat.set_shader_parameter("progress", 0.0)
	, CONNECT_ONE_SHOT)
