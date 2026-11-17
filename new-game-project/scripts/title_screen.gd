extends Control

const SETTINGS_PATH := "user://settings.cfg"

@onready var menu: VBoxContainer = $Center/Menu
@onready var settings: VBoxContainer = $Center/SettingsPage
@onready var volume: HSlider = $Center/SettingsPage/Volume
@onready var fullscreen: CheckButton = $Center/SettingsPage/Fullscreen

func _ready() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	volume.set_value_no_signal(float(config.get_value("audio", "volume", 100.0)))
	fullscreen.set_pressed_no_signal(bool(config.get_value("display", "fullscreen", false)))
	_apply_volume(volume.value)
	_apply_fullscreen(fullscreen.button_pressed)
	menu.get_node("Play").grab_focus()

func _on_play_pressed() -> void:
	var result := get_tree().change_scene_to_file("res://scenes/game.tscn")
	if result != OK:
		push_error(error_string(result))

func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_settings_pressed() -> void:
	menu.hide()
	settings.show()
	volume.grab_focus()

func _on_back_pressed() -> void:
	settings.hide()
	menu.show()
	menu.get_node("Settings").grab_focus()

func _on_volume_changed(value: float) -> void:
	_apply_volume(value)
	_save_settings()

func _on_fullscreen_toggled(enabled: bool) -> void:
	_apply_fullscreen(enabled)
	_save_settings()

func _apply_volume(value: float) -> void:
	AudioServer.set_bus_mute(0, value <= 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value / 100.0, 0.001)))

func _apply_fullscreen(enabled: bool) -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "volume", volume.value)
	config.set_value("display", "fullscreen", fullscreen.button_pressed)
	var result := config.save(SETTINGS_PATH)
	if result != OK:
		push_warning("Could not save settings: %s" % error_string(result))
