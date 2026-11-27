extends Node2D

@export var camera_speed: float = 70.0
@onready var camera: Camera2D = $Camera2D

func _process(delta: float) -> void:
	# Preview scrolling with a camera independent of the game's player.
	var direction := Input.get_axis("ui_left", "ui_right")
	if Input.is_physical_key_pressed(KEY_A):
		direction = -1.0
	elif Input.is_physical_key_pressed(KEY_D):
		direction = 1.0
	camera.position.x += direction * camera_speed * delta

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_HOME:
			camera.position = Vector2(98.5, 112)
