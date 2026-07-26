# res://Scripts/UI/BattleHUD.gd
class_name BattleHUD
extends Control

# SceneUniqueNodes
@onready var enemy_name_label: Label = %EnemyNameLabel as Label
@onready var enemy_hp_label: Label = %EnemyHPLabel as Label
@onready var left_chevrons: TextureRect = %LeftChevrons as TextureRect
@onready var right_chevrons: TextureRect = %RightChevrons as TextureRect
@onready var auto_button: TextureButton = %AutoButton as TextureButton

@onready var party_left: VBoxContainer = %PartyLeft as VBoxContainer
@onready var party_right: VBoxContainer = %PartyRight as VBoxContainer

const COLOR_NORMAL: Color = Color("23f0c7")
const COLOR_PLAYER_HIT: Color = Color("ff2a6d")
const COLOR_ENEMY_HIT: Color = Color("ffae00")

var portrait_slots: Array[Node] = []

func _ready() -> void:
	hide()
	_initialize_portrait_slots()
	
	var sb: Node = get_tree().root.get_node_or_null("SignalBus")
	if sb:
		if sb.has_signal("chevron_flash_requested"):
			sb.chevron_flash_requested.connect(_on_chevron_flash)
		if sb.has_signal("enemy_health_changed"):
			sb.enemy_health_changed.connect(_on_enemy_health_changed)
		if sb.has_signal("combat_started"):
			sb.combat_started.connect(_on_combat_started)
		if sb.has_signal("combat_ended"):
			sb.combat_ended.connect(_on_combat_ended)

func _initialize_portrait_slots() -> void:
	portrait_slots.clear()
	portrait_slots.resize(6)
	
	# Register Front Row (Slots 0, 1, 2)
	if party_left:
		for child: Node in party_left.get_children():
			if "slot_index" in child:
				var idx: int = child.get("slot_index")
				if idx >= 0 and idx < 6:
					portrait_slots[idx] = child

	# Register Back Row (Slots 3, 4, 5)
	if party_right:
		for child: Node in party_right.get_children():
			if "slot_index" in child:
				var idx: int = child.get("slot_index")
				if idx >= 0 and idx < 6:
					portrait_slots[idx] = child

func setup_party_display(party_members: Array) -> void:
	if portrait_slots.is_empty():
		_initialize_portrait_slots()

	for i: int in range(6):
		var slot_node: Node = portrait_slots[i]
		if slot_node == null or not slot_node.has_method("setup_slot"):
			continue
			
		if i < party_members.size() and party_members[i] != null:
			slot_node.call("setup_slot", party_members[i])
		else:
			slot_node.call("setup_slot", null)

func _on_combat_started(enemy_data: EnemyData = null, player_party: Array = []) -> void:
	show()
	
	var active_party: Array = player_party
	if active_party.is_empty() and (Engine.has_singleton("GameState") or get_tree().root.has_node("GameState")):
		if GameState.current_party:
			active_party = GameState.current_party.slots
			
	setup_party_display(active_party)
	
	if enemy_data:
		if enemy_name_label: enemy_name_label.text = enemy_data.enemy_name.to_upper()
		if enemy_hp_label: enemy_hp_label.text = "%d / %d" % [enemy_data.max_health, enemy_data.max_health]

func _on_combat_ended(_victory: bool) -> void:
	hide()

func _on_chevron_flash(is_player_hit: bool) -> void:
	var flash_color: Color = COLOR_PLAYER_HIT if is_player_hit else COLOR_ENEMY_HIT
	
	var tween: Tween = create_tween().set_parallel(true)
	if left_chevrons: left_chevrons.modulate = flash_color
	if right_chevrons: right_chevrons.modulate = flash_color
	
	if left_chevrons: tween.tween_property(left_chevrons, "modulate", COLOR_NORMAL, 0.4)
	if right_chevrons: tween.tween_property(right_chevrons, "modulate", COLOR_NORMAL, 0.4)

func _on_enemy_health_changed(current_hp: int, max_hp: int) -> void:
	if enemy_hp_label:
		enemy_hp_label.text = "%d / %d" % [current_hp, max_hp]
