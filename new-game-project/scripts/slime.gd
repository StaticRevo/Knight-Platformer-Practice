extends Node2D

const SPEED = 30
@export_range(1, 5) var contact_damage: int = 1
var direction = 1

@onready var ray_cast_right: RayCast2D = $RayCastRight
@onready var ray_cast_left: RayCast2D = $RayCastLeft
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var die_sound: AudioStreamPlayer2D = $DieSound
@onready var hit_sound: AudioStreamPlayer2D = $HitSound

func _process(delta: float) -> void:
	if ray_cast_right.is_colliding():
		direction = -1
		animated_sprite.flip_h = true
		
	if ray_cast_left.is_colliding():
		direction = 1
		animated_sprite.flip_h = false
		
	position.x += direction * SPEED * delta


func _physics_process(_delta: float) -> void:
	if health <= 0:
		return
	for body in $ContactArea.get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(contact_damage)


@export var max_health := 3
@onready var health := max_health

func _ready() -> void:
	# Player attacks look for targets in this group.
	add_to_group("damageable_enemies")
	animated_sprite.animation_finished.connect(_on_animation_finished)

# Take damage function
func take_damage(amount: int) -> void:
	if health <= 0 or amount <= 0:
		return

	health -= amount

	if health <= 0:
		# Stop movement and contact damage while the death sound plays.
		set_process(false)
		set_physics_process(false)
		animated_sprite.hide()
		hit_sound.stop()

		# Keep the slime node alive until its audio finishes.
		if die_sound.stream != null:
			die_sound.play()
			await die_sound.finished

		queue_free()
		return

	# Surviving hits play their sound and restart the hit animation.
	hit_sound.play()
	animated_sprite.stop()
	animated_sprite.play("take_damage")

func _on_animation_finished() -> void:
	if animated_sprite.animation == &"take_damage":
		animated_sprite.play("idle")
