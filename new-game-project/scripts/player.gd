extends CharacterBody2D

const SPEED = 130.0
const SPRINT_SPEED = 200.0
const MAX_LIVES = 5
const MAX_STAMINA = 2.5
const STAMINA_RECOVERY = 0.625
const HIT_COOLDOWN = 1.0

var lives: int = MAX_LIVES
var stamina: float = MAX_STAMINA
var hit_cooldown := 0.0
var sprint_exhausted := false
const JUMP_VELOCITY = -300.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var sword_slash_sound: AudioStreamPlayer2D = $SwordSlashSound
@onready var punch_sound: AudioStreamPlayer2D = $PunchSound
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	hit_cooldown = maxf(0.0, hit_cooldown - delta)
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Get the input direction: -1, 0, 1
	var direction := Input.get_axis("move_left", "move_right")
	
	# Flip the sprite
	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true
	
	# Play animations
	if is_on_floor():
		if direction == 0:
			animated_sprite.play("idle")
		else:
			animated_sprite.play("run")
	else: 
		animated_sprite.play("jump")
	
	if Input.is_key_pressed(KEY_A):
		direction = -1
	elif Input.is_key_pressed(KEY_D):
		direction = 1
	
	var sprinting := direction != 0.0 and Input.is_physical_key_pressed(KEY_SHIFT) and not sprint_exhausted
	if sprinting:
		stamina = maxf(0.0, stamina - delta)
		sprint_exhausted = stamina <= 0.0
	else:
		stamina = minf(MAX_STAMINA, stamina + STAMINA_RECOVERY * delta)
		if stamina >= MAX_STAMINA:
			sprint_exhausted = false

	# Apply movement
	if direction:
		velocity.x = direction * (SPRINT_SPEED if sprinting else SPEED)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func take_damage(amount: int) -> void:
	if amount <= 0 or hit_cooldown > 0.0 or lives <= 0:
		return

	lives = maxi(0, lives - amount)
	hit_cooldown = HIT_COOLDOWN

	if lives == 0:
		_play_death_sequence()


func _play_death_sequence() -> void:
	Engine.time_scale = 0.5
	$CollisionShape2D.set_deferred("disabled", true)

	# 0.6 seconds of game time is about 1.2 seconds in slow motion.
	await get_tree().create_timer(0.6, false).timeout

	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

# Inventory code
signal item_added(slot_index: int, icon: Texture2D)

const INVENTORY_SIZE := 5
var inventory: Array[Texture2D] = []
var inventory_damage: Array[int] = []
var selected_slot := 0
var attack_cooldown := 0.0

func add_item(icon: Texture2D, damage: int = 0) -> bool:
	if inventory.size() >= INVENTORY_SIZE:
		return false

	var slot_index := inventory.size()
	inventory.append(icon)
	inventory_damage.append(damage)
	item_added.emit(slot_index, icon)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if lives <= 0:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_5:
			selected_slot = event.keycode - KEY_1
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_attack()

func _attack() -> void:
	if attack_cooldown > 0.0:
		return
	var facing := -1.0 if animated_sprite.flip_h else 1.0
	var armed := selected_slot < inventory.size() and inventory_damage[selected_slot] > 0
	var damage := inventory_damage[selected_slot] if armed else 1
	var reach := 33.0 if armed else 28.0
	
	attack_cooldown = 0.5 if armed else 0.35
	
	# Check enemy positions in a short band in front of the player.
	for enemy in get_tree().get_nodes_in_group("damageable_enemies"):
		var distance: Vector2 = enemy.global_position - global_position
		var forward := distance.x * facing
		if forward >= (-5.0 if not armed else 0.0) and forward <= reach and absf(distance.y) <= 16.0:
			enemy.take_damage(damage)
	if armed:
		sword_slash_sound.play()
		_animate_swing(inventory[selected_slot], facing)
	else:
		punch_sound.play()
		_animate_punch(facing)

func _animate_swing(icon: Texture2D, facing: float) -> void:
	# Scale only the in-world sword. The hotbar uses the original icon.
	var swing := Sprite2D.new()
	swing.scale = Vector2(0.5, 0.5)
	swing.texture = icon
	swing.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	swing.position = Vector2(facing * 7.0, -8.0)
	swing.offset = Vector2(8.0, 0.0)
	swing.rotation = (-1.1 if facing > 0.0 else PI + 1.1)
	add_child(swing)
	var tween := swing.create_tween()
	tween.tween_property(swing, "rotation", swing.rotation + 2.2 * facing, 0.18)
	tween.tween_callback(swing.queue_free)


func _animate_punch(facing: float) -> void:
	# A small swipe shows the click even when the attack misses.
	var swipe := Polygon2D.new()
	swipe.color = Color(1.0, 0.88, 0.67)
	swipe.polygon = PackedVector2Array([Vector2(0, -2), Vector2(9, -3), Vector2(4, 2)])
	swipe.position = Vector2(7.0 * facing, -8.0)
	swipe.scale.x = facing
	add_child(swipe)
	var tween := swipe.create_tween().set_parallel()
	tween.tween_property(swipe, "position:x", 13.0 * facing, 0.13)
	tween.tween_property(swipe, "modulate:a", 0.0, 0.13)
	tween.chain().tween_callback(swipe.queue_free)
