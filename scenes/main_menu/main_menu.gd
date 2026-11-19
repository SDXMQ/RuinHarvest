extends Control

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var sandbox_button: Button = $VBoxContainer/SandboxButton
@onready var load_button: Button = $VBoxContainer/LoadButton
@onready var settings_button: Button = get_node_or_null("VBoxContainer/SettingsButton")
@onready var quit_button: Button = $VBoxContainer/QuitButton

const SandboxMenuScene = preload("res://scenes/main_menu/sandbox_menu.tscn")
const NewGameCustomScene = preload("res://scenes/main_menu/new_game_custom_window.tscn")
const SaveSlotsWindowScene = preload("res://scenes/ui/save_slots_window.tscn")
const SettingsWindowScene = preload("res://scenes/ui/settings_window.tscn")

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	if sandbox_button:
		sandbox_button.pressed.connect(_on_sandbox_pressed)
	load_button.pressed.connect(_on_load_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# 타이틀 다국어 적용 시뮬레이션
	if I18nManager:
		$Title.text = I18nManager.t("game_title")
		$Subtitle.text = I18nManager.t("game_subtitle")
		start_button.text = I18nManager.t("new_game")
		load_button.text = I18nManager.t("load_game")
		quit_button.text = I18nManager.t("quit")

func _on_start_pressed() -> void:
	if SoundManager:
		SoundManager.play("menu_select")
	var custom_win = NewGameCustomScene.instantiate()
	add_child(custom_win)

func _on_sandbox_pressed() -> void:
	if SoundManager:
		SoundManager.play("menu_select")
	var sand_menu = SandboxMenuScene.instantiate()
	add_child(sand_menu)

func _on_load_pressed() -> void:
	if SoundManager:
		SoundManager.play("menu_select")
	var load_win = SaveSlotsWindowScene.instantiate()
	add_child(load_win)

func _on_settings_pressed() -> void:
	if SoundManager:
		SoundManager.play("menu_select")
	var settings_win = SettingsWindowScene.instantiate()
	add_child(settings_win)

func _on_quit_pressed() -> void:
	get_tree().quit()
