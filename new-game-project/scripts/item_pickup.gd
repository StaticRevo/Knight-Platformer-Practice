extends Area2D

const ChestReward = preload("res://scripts/chest_reward.gd")

@export var rewards: Array[ChestReward] = []

@export var prompt_font: Font
@export_range(8, 64) var prompt_font_size: int = 16
@export var open_prompt: String = "Press E to open"
@export var pickup_prompt: String = "Press E to pick up"

@export var world_icon: Texture2D
@export var reward_icon: Texture2D
@export_range(0, 20) var weapon_damage: int = 0

@export var bob_height := 2.0
@export var bob_period := 1.8
@export var interaction_distance := 38.0

@export var opened_icon: Texture2D

@onready var sprite: Sprite2D = $Sprite2D
var prompt: Label
var opened := false

func _ready() -> void:
	if world_icon != null:
		sprite.texture = world_icon
		sprite.region_enabled = false
		
	# The chest stays still and only opens when E is pressed nearby.
	prompt = Label.new()
	prompt.text = open_prompt
	if prompt_font != null:
		prompt.add_theme_font_override("font", prompt_font)
	prompt.add_theme_font_size_override("font_size", prompt_font_size)
	prompt.position = Vector2(-65, -48)
	prompt.add_theme_constant_override("outline_size", 6)
	prompt.scale = Vector2(0.8, 0.8)
	prompt.visible = false
	add_child(prompt)

func _process(_delta: float) -> void:
	prompt.visible = not opened and _nearby_player() != null

func _unhandled_key_input(event: InputEvent) -> void:
	if opened or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey and event.physical_keycode == KEY_E:
		var player := _nearby_player()
		if player == null:
			return
		get_viewport().set_input_as_handled()
		_open_chest(player)

func _open_chest(player: Node2D) -> void:
	if opened:
		return
	opened = true
	prompt.hide()
	if opened_icon != null:
		sprite.texture = opened_icon
		sprite.region_enabled = false
	else:
		sprite.modulate = Color(0.65, 0.65, 0.65)
	# Spawn a separate reward so opening never immediately adds it to inventory.
	
	var drop = load("res://scripts/dropped_item.gd").new()
	# Skip incomplete list entries. An empty list uses the original reward.
	var valid_rewards: Array[ChestReward] = []
	for reward in rewards:
		if reward != null and reward.icon != null:
			valid_rewards.append(reward)
			
	var chosen: ChestReward = null
	if not valid_rewards.is_empty():
		chosen = valid_rewards.pick_random()
		
	drop.icon = chosen.icon if chosen != null else reward_icon
	drop.prompt_font = prompt_font
	drop.prompt_font_size = prompt_font_size
	drop.pickup_prompt = pickup_prompt
	if drop.icon == null:
		drop.icon = sprite.texture
		if sprite.region_enabled:
			var region_icon := AtlasTexture.new()
			region_icon.atlas = sprite.texture
			region_icon.region = sprite.region_rect
			drop.icon = region_icon
	drop.weapon_damage = chosen.weapon_damage if chosen != null else weapon_damage
	drop.attack_sound = chosen.attack_sound if chosen != null else null
	drop.weapon_data = chosen
	drop.launch_direction = -1.0 if player.global_position.x < global_position.x else 1.0
	get_parent().add_child(drop)
	drop.global_position = global_position + Vector2(0, -10)

func _nearby_player() -> Node2D:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and global_position.distance_to(player.global_position) <= interaction_distance:
		return player
	return null
