# res://scenes/ui/main_menu.gd
extends Control

@onready var btn_new_game: Button = $VBox/BtnNewGame
@onready var btn_continue: Button = $VBox/BtnContinue
@onready var btn_settings: Button = $VBox/BtnSettings
@onready var btn_exit: Button = $VBox/BtnExit

const SettingsWindowScene = preload("res://scenes/ui/settings_window.tscn")
const SaveSlotsWindowScene = preload("res://scenes/ui/save_slots_window.tscn")

func _ready() -> void:
	btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_continue.pressed.connect(_on_continue_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_exit.pressed.connect(_on_exit_pressed)
	
	if SoundManager:
		# SoundManager.play_bgm("main_theme")
		pass

func _on_new_game_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	if GameManager:
		GameManager.start_new_game()
	else:
		TransitionManager.change_scene("res://scenes/hideout/hideout.tscn", "fade", 0.8)

func _on_continue_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	# 오픈 세이브 슬롯 UI
	var save_ui = SaveSlotsWindowScene.instantiate()
	add_child(save_ui)

func _on_settings_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	var settings = SettingsWindowScene.instantiate()
	add_child(settings)

func _on_exit_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	get_tree().quit()
