extends Control

@onready var raid_button: Button = $RaidButton
@onready var menu_button: Button = $MenuButton

func _ready() -> void:
	raid_button.pressed.connect(_on_raid_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	
	if I18nManager:
		$Title.text = I18nManager.t("hideout_title")
		raid_button.text = I18nManager.t("start_raid_btn")

func _on_raid_pressed() -> void:
	if SoundManager:
		SoundManager.play("menu_select")
		
	if GameManager:
		GameManager.start_raid()

func _on_menu_pressed() -> void:
	if SoundManager:
		SoundManager.play("menu_select")
		
	if GameManager:
		# 현재 진행 데이터 저장 후 메인 메뉴
		if GameManager.current_save_slot != "":
			SaveManager.save_game(GameManager.current_world_data, GameManager.current_save_slot)
		GameManager.change_state(GameManager.GameState.MAIN_MENU)
