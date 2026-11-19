extends CanvasLayer

@onready var overlay: ColorRect = $Overlay
@onready var resume: Button = $Overlay/Center/Panel/Margin/Menu/Resume
@onready var main_menu: Button = $Overlay/Center/Panel/Margin/Menu/MainMenu

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		# Escape closes the inventory first instead of opening two menus.
		var inventory := get_parent().get_node_or_null("PlayerHUD/InventoryPanel")
		if inventory != null and inventory.visible:
			inventory.close()
			return
		_set_pause_menu(not overlay.visible)

func _set_pause_menu(open: bool) -> void:
	overlay.visible = open
	get_tree().paused = open
	if open:
		resume.grab_focus()

func _on_resume_pressed() -> void:
	_set_pause_menu(false)

func _on_main_menu_pressed() -> void:
	var tree := get_tree()
	var result := tree.change_scene_to_file("res://scenes/title_screen.tscn")
	if result == OK:
		tree.paused = false
	else:
		push_error("Could not return to the main menu: %s" % error_string(result))
		main_menu.grab_focus()

func _on_quit_pressed() -> void:
	get_tree().quit()
