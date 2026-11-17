extends CanvasLayer

@onready var player = $"../Player"
@onready var health: ProgressBar = $Vitals/Health
@onready var health_label: Label = $Vitals/HealthLabel
@onready var hotbar: HBoxContainer = $Hotbar
@onready var stamina: ProgressBar = $Vitals/Stamina

func _ready() -> void:
	health.max_value = player.MAX_LIVES
	stamina.max_value = player.MAX_STAMINA
	player.item_added.connect(_on_item_added)
	_update_vitals()

func _process(_delta: float) -> void:
	_update_vitals()

func _update_vitals() -> void:
	health.value = player.lives
	health_label.text = "Health  %d / %d" % [player.lives, player.MAX_LIVES]
	stamina.value = player.stamina
	for slot in hotbar.get_children():
		slot.self_modulate = Color(1.7, 1.5, 1.8) if slot.get_index() == player.selected_slot else Color.WHITE

func _on_item_added(slot_index: int, texture: Texture2D) -> void:
	var slot := $Hotbar.get_child(slot_index) as Panel
	var icon := TextureRect.new()
	icon.texture = texture
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	slot.add_child(icon)
	slot.move_child(icon, 0) # Keep the slot number above the icon.
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 8
	icon.offset_top = 8
	icon.offset_right = -8
	icon.offset_bottom = -8
