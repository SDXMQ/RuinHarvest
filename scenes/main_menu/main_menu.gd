extends Control

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var load_button: Button = $VBoxContainer/LoadButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	load_button.pressed.connect(_on_load_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# 타이틀 다국어 적용 시뮬레이션
	if I18nManager:
		$Title.text = I18nManager.t("game_title")
		$Subtitle.text = I18nManager.t("game_subtitle")
		start_button.text = I18nManager.t("new_game")
		load_button.text = I18nManager.t("load_game")
		quit_button.text = I18nManager.t("quit")
		
	# BGM 시작 (나중에 추가)

func _on_start_pressed() -> void:
	if SoundManager:
		SoundManager.play("menu_select")
		
	if GameManager:
		# 임시로 바로 월드 생성/시작
		GameManager.start_new_game(GameSettings.DEFAULT_WORLD_SETTINGS)

func _on_load_pressed() -> void:
	if SoundManager:
		SoundManager.play("menu_select")
		
	var saves = SaveManager.get_save_files()
	if saves.size() > 0:
		GameManager.load_game(saves[0].filename)
	else:
		print("No saves found.")

func _on_quit_pressed() -> void:
	get_tree().quit()
