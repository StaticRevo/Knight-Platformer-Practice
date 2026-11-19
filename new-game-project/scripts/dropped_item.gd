extends CharacterBody2D

var prompt_font: Font
var prompt_font_size := 16
var pickup_prompt := "Press E to pick up"
var icon: Texture2D
var weapon_damage := 0
var attack_sound: AudioStream
var weapon_data: Resource
var launch_direction := 1.0
var sprite: Sprite2D
var prompt: Label
var landed := false
var elapsed := 0.0

func _ready() -> void:
	# Collide with the map, while allowing the player to walk through the item.
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(10, 10)
	shape.shape = box
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.texture = icon
	sprite.scale = Vector2(0.5, 0.5)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	prompt = Label.new()
	prompt.text = pickup_prompt
	if prompt_font != null:
		prompt.add_theme_font_override("font", prompt_font)
	prompt.add_theme_font_size_override("font_size", prompt_font_size)
	prompt.position = Vector2(-65, -35)
	prompt.scale = Vector2(0.65, 0.65)
	prompt.add_theme_constant_override("outline_size", 6)
	add_child(prompt)
	velocity = Vector2(launch_direction * 65.0, -170.0)

func _physics_process(delta: float) -> void:
	# The reward follows a real arc and settles on level collision.
	velocity += get_gravity() * delta
	move_and_slide()
	if is_on_floor():
		landed = true
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	var player := _nearby_player()
	prompt.visible = landed and player != null
	if landed:
		elapsed += delta
		sprite.position.y = -3.0 + sin(elapsed * TAU / 1.8) * 2.0

func _unhandled_key_input(event: InputEvent) -> void:
	if not landed or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey and event.physical_keycode == KEY_E:
		var player := _nearby_player()
		if player == null:
			return
		get_viewport().set_input_as_handled()
		# Leave the reward on the ground when all inventory slots are occupied.
		if player.add_item(icon, weapon_damage, attack_sound, weapon_data):
			queue_free()
		else:
			prompt.text = "Inventory full"

func _nearby_player() -> Node2D:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and global_position.distance_to(player.global_position) <= 38.0:
		return player
	return null
