extends Area2D

@export_range(0, 20) var weapon_damage: int = 0

@export var bob_height := 2.0
@export var bob_period := 1.8

@onready var sprite: Sprite2D = $Sprite2D
@onready var start_y := sprite.position.y

var elapsed := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

# Item move up & Down
func _process(delta: float) -> void:
	elapsed += delta
	sprite.position.y = start_y + sin(elapsed * TAU / bob_period) * bob_height

func _on_body_entered(body: Node2D) -> void:
	if is_queued_for_deletion() or not body.is_in_group("player"):
		return

	var icon := AtlasTexture.new()
	icon.atlas = sprite.texture
	icon.region = sprite.region_rect

	if body.add_item(icon, weapon_damage):
		print("Picked up ", name)
		queue_free()
