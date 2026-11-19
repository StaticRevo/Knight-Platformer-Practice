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
	_update_held_weapon(delta)

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

const INVENTORY_SIZE := 20
# Equipment points to owned inventory entries, so equipping cannot duplicate items.
var equipment: Dictionary = {"Helmet": -1, "Chestplate": -1, "Pants": -1, "Boots": -1}
var abilities: Array[Resource] = []
var inventory: Array[Texture2D] = []
var inventory_damage: Array[int] = []
# Match each inventory slot to its weapon sound.
var inventory_sounds: Array[AudioStream] = []
var weapon_sound_player: AudioStreamPlayer2D
var inventory_weapon_data: Array[Resource] = []
var selected_slot := 0
var equipped_slot := -1
var weapon_tween: Tween
var weapon_swinging := false
var hand_phase := 0.0

@onready var hand: Node2D = $HandPivot
@onready var held_weapon: Sprite2D = $HandPivot/WeaponSprite
var attack_cooldown := 0.0

func add_item(icon: Texture2D, damage: int = 0, attack_sound: AudioStream = null, weapon_data: Resource = null) -> bool:
	# Acquired abilities have their own section and do not consume bag space.
	if weapon_data != null and weapon_data.item_type == "Ability":
		for ability in abilities:
			if ability == weapon_data:
				return true
		abilities.append(weapon_data)
		return true
	if inventory.size() >= INVENTORY_SIZE:
		return false

	var slot_index := inventory.size()
	inventory.append(icon)
	inventory_damage.append(damage if weapon_data == null or weapon_data.item_type == "Weapon" else 0)
	inventory_sounds.append(attack_sound)
	inventory_weapon_data.append(weapon_data)
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
		# Use the equipped reward's sound, or the original sword sound.
		var sound: AudioStream = inventory_sounds[selected_slot]
		if sound != null:
			if not is_instance_valid(weapon_sound_player):
				weapon_sound_player = AudioStreamPlayer2D.new()
				add_child(weapon_sound_player)
			weapon_sound_player.stream = sound
			weapon_sound_player.play()
		else:
			sword_slash_sound.play()
		_animate_swing(inventory[selected_slot], facing)
	else:
		punch_sound.play()
		_animate_punch(facing)

func _update_held_weapon(delta: float) -> void:
	# Refresh after collecting or selecting a slot. Empty slots hide the weapon.
	var armed := selected_slot < inventory.size() and inventory_damage[selected_slot] > 0
	held_weapon.visible = armed and lives > 0
	if not held_weapon.visible:
		_cancel_weapon_swing()
		equipped_slot = -1
		return
	var data: Resource = inventory_weapon_data[selected_slot]
	var rest := deg_to_rad(data.resting_angle if data != null else -35.0)
	if equipped_slot != selected_slot:
		_cancel_weapon_swing()
		equipped_slot = selected_slot
		held_weapon.texture = inventory[selected_slot]
		var size_scale: float = data.held_scale if data != null else 0.5
		held_weapon.scale = Vector2.ONE * size_scale
		# Put the handle at the pivot instead of rotating around the icon's center.
		held_weapon.position = -(data.grip_position if data != null else Vector2(8, 24)) * size_scale
		hand.rotation = rest
	if not weapon_swinging:
		hand.scale.x = -1.0 if animated_sprite.flip_h else 1.0
		hand.position.x = 5.0 * hand.scale.x
		hand_phase += delta * (14.0 if absf(velocity.x) > 1.0 else 3.0)
		hand.position.y = -8.0 + sin(hand_phase) * (0.7 if is_on_floor() else 0.0)
		hand.rotation = rest + sin(hand_phase) * 0.04

func _cancel_weapon_swing() -> void:
	# Slot changes interrupt the old animation safely.
	if weapon_tween != null and weapon_tween.is_valid():
		weapon_tween.kill()
	weapon_swinging = false

func _animate_swing(_icon: Texture2D, facing: float) -> void:
	_update_held_weapon(0.0)
	_cancel_weapon_swing()
	weapon_swinging = true
	hand.scale.x = facing
	hand.position = Vector2(5.0 * facing, -8.0)
	var rest := hand.rotation
	# Wind up, slash quickly, then recover with the handle fixed at the hand.
	weapon_tween = create_tween()
	weapon_tween.tween_property(hand, "rotation", rest - 0.7, 0.07)
	weapon_tween.tween_property(hand, "rotation", rest + 1.6, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	weapon_tween.tween_property(hand, "rotation", rest, 0.18).set_trans(Tween.TRANS_SINE)
	weapon_tween.tween_callback(func(): weapon_swinging = false)

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
