extends PanelContainer

const PIXEL_FONT = preload("res://assets/fonts/PixelOperator8.ttf")
const PIXEL_BOLD = preload("res://assets/fonts/PixelOperator8-Bold.ttf")
const ITEM_SHEET = preload("res://assets/sprites/32x32.png")
# Matching blue armor tiles, ordered helmet, chestplate, pants, boots.
const ARMOR_REGIONS = {
	"Helmet": Rect2(0, 3712, 32, 32),
	"Chestplate": Rect2(0, 3744, 32, 32),
	"Pants": Rect2(0, 3776, 32, 32),
	"Boots": Rect2(0, 3808, 32, 32)
}

var player
var bag: GridContainer
var gear: HBoxContainer
var acquired: VBoxContainer
var description: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# A local theme makes every inventory control use the requested pixel font.
	theme = Theme.new()
	theme.default_font = PIXEL_FONT
	theme.default_font_size = 16
	theme.set_font("font", "TooltipLabel", PIXEL_FONT)
	theme.set_color("font_color", "Label", Color("#e9dccb"))
	theme.set_color("font_color", "Button", Color("#e9dccb"))
	theme.set_stylebox("normal", "Button", _slot_style(Color("#211c35"), Color("#514259")))
	theme.set_stylebox("hover", "Button", _slot_style(Color("#393047"), Color("#e4ad72")))
	theme.set_stylebox("pressed", "Button", _slot_style(Color("#4a3450"), Color("#f4cb91")))
	theme.set_stylebox("focus", "Button", _slot_style(Color.TRANSPARENT, Color("#f4cb91")))
	theme.set_stylebox("disabled", "Button", _slot_style(Color("#1a1727"), Color("#352c42")))
	var background := _slot_style(Color("#161322"), Color("#9a715b"))
	background.content_margin_left = 6
	background.content_margin_right = 6
	add_theme_stylebox_override("panel", background)
	player = get_parent().get_parent().get_node("Player")
	# Use regular Control nodes so all buttons support mouse and keyboard navigation.
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -300
	offset_right = 300
	offset_top = -240
	offset_bottom = 240
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 18)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "Inventory"
	title.add_theme_font_override("font", PIXEL_BOLD)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#f4cb91"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var back := Button.new()
	back.text = "Close (I)"
	back.pressed.connect(close)
	header.add_child(back)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var sections := VBoxContainer.new()
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections.add_theme_constant_override("separation", 12)
	scroll.add_child(sections)
	_add_heading(sections, "Equipment")
	gear = HBoxContainer.new()
	gear.add_theme_constant_override("separation", 12)
	sections.add_child(gear)
	_add_heading(sections, "Bag")
	bag = GridContainer.new()
	bag.columns = 5
	bag.add_theme_constant_override("h_separation", 8)
	bag.add_theme_constant_override("v_separation", 8)
	sections.add_child(bag)
	_add_heading(sections, "Abilities")
	acquired = VBoxContainer.new()
	sections.add_child(acquired)
	description = Label.new()
	description.text = "Click to select or equip. Hover for item details."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)
	hide()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_I:
		if visible:
			close()
		elif not get_tree().paused and player.lives > 0:
			show()
			get_tree().paused = true
			_refresh()
		get_viewport().set_input_as_handled()

func close() -> void:
	hide()
	get_tree().paused = false

func _refresh() -> void:
	_clear(bag)
	_clear(gear)
	_clear(acquired)
	for category in player.equipment:
		var index: int = player.equipment[category]
		var button := Button.new()
		button.custom_minimum_size = Vector2(76, 68)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 40)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if index >= 0:
			button.icon = player.inventory[index]
			button.tooltip_text = category + ": " + _item_name(index) + "\nClick to unequip"
			button.add_theme_stylebox_override("normal", _slot_style(Color("#30263b"), Color("#c79a69")))
		else:
			# Empty slots show category artwork. Equipped slots show the actual item.
			var placeholder := AtlasTexture.new()
			placeholder.atlas = ITEM_SHEET
			placeholder.region = ARMOR_REGIONS[category]
			button.icon = placeholder
			button.self_modulate = Color(0.65, 0.65, 0.75)
			button.tooltip_text = category + " slot — empty"
		button.pressed.connect(_unequip.bind(category))
		gear.add_child(button)
	for index in range(player.INVENTORY_SIZE):
		var button := Button.new()
		button.custom_minimum_size = Vector2(95, 54)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 32)
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.text = str(index + 1) if index < 5 else ""
		button.disabled = index >= player.inventory.size()
		if not button.disabled:
			button.icon = player.inventory[index]
			button.tooltip_text = _item_name(index)
			button.pressed.connect(_choose.bind(index))
			if index == player.selected_slot:
				button.add_theme_stylebox_override("normal", _slot_style(Color("#382b42"), Color("#f4cb91")))
			if index in player.equipment.values():
				button.add_theme_stylebox_override("normal", _slot_style(Color("#233b39"), Color("#6cac96")))
		bag.add_child(button)
	if player.abilities.is_empty():
		_add_label(acquired, "No abilities acquired yet.")
	for ability in player.abilities:
		var entry := HBoxContainer.new()
		var icon := TextureRect.new()
		icon.texture = ability.icon
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		entry.add_child(icon)
		_add_label(entry, ability.item_name)
		acquired.add_child(entry)

func _choose(index: int) -> void:
	var data: Resource = player.inventory_weapon_data[index]
	if data != null and player.equipment.has(data.item_type):
		player.equipment[data.item_type] = index
		description.text = "Equipped " + _item_name(index)
	else:
		player.selected_slot = index
		description.text = "Selected " + _item_name(index)
	_refresh()

func _unequip(category: String) -> void:
	player.equipment[category] = -1
	description.text = "Unequipped " + category
	_refresh()

func _item_name(index: int) -> String:
	var data: Resource = player.inventory_weapon_data[index]
	return data.item_name if data != null else "Item"

func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _add_label(parent: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	parent.add_child(label)


func _add_heading(parent: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", PIXEL_BOLD)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("#f4cb91"))
	parent.add_child(label)

func _slot_style(fill: Color, border: Color) -> StyleBoxFlat:
	# Square borders and nearest filtering match the game's pixel artwork.
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style
