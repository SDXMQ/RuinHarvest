# res://scenes/main_menu/new_game_custom_window.gd
extends Control

## 새 게임 시작 시 게임 규칙/난이도 모딩 윈도우

@onready var title_label: Label = $Center/Panel/Title
@onready var preset_opt: OptionButton = $Center/Panel/VBox/PresetRow/PresetOpt
@onready var zombie_opt: OptionButton = $Center/Panel/VBox/ZombieRow/ZombieOpt
@onready var raid_time_opt: OptionButton = $Center/Panel/VBox/RaidTimeRow/RaidTimeOpt
@onready var loot_opt: OptionButton = $Center/Panel/VBox/LootRow/LootOpt
@onready var day_night_opt: OptionButton = $Center/Panel/VBox/DayNightRow/DayNightOpt
@onready var money_opt: OptionButton = $Center/Panel/VBox/MoneyRow/MoneyOpt
@onready var permadeath_check: CheckBox = $Center/Panel/VBox/PermadeathRow/PermadeathCheck

@onready var start_btn: Button = $Center/Panel/Buttons/StartBtn
@onready var cancel_btn: Button = $Center/Panel/Buttons/CancelBtn

var is_updating_preset: bool = false

func _ready() -> void:
	if UiIconManager:
		UiIconManager.set_label_icon(title_label, "settings", "", 18, 6)
		UiIconManager.apply_button_icon(start_btn, "rocket", "", 16)
	_setup_options()
	preset_opt.item_selected.connect(_on_preset_selected)
	
	zombie_opt.item_selected.connect(_on_custom_option_changed)
	raid_time_opt.item_selected.connect(_on_custom_option_changed)
	loot_opt.item_selected.connect(_on_custom_option_changed)
	day_night_opt.item_selected.connect(_on_custom_option_changed)
	money_opt.item_selected.connect(_on_custom_option_changed)
	permadeath_check.toggled.connect(func(_val): _on_custom_option_changed(0))
	
	start_btn.pressed.connect(_on_start_pressed)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	
	# 기본 프리셋(스탠다드) 적용
	preset_opt.selected = 1
	_apply_preset(1)

func _setup_options() -> void:
	# 프리셋
	preset_opt.clear()
	var preset_defs := [
		["diff_casual", "캐주얼 (Casual)", 0],
		["diff_standard", "스탠다드 (Standard)", 1],
		["diff_hardcore", "하드코어 (Hardcore)", 2],
		["diff_custom", "커스텀 모딩 (Custom)", 3],
	]
	for pdef in preset_defs:
		var p_icon: Texture2D = UiIconManager.get_icon(pdef[0]) if UiIconManager else null
		if p_icon != null:
			preset_opt.add_icon_item(p_icon, pdef[1], pdef[2])
		else:
			preset_opt.add_item(pdef[1], pdef[2])
	preset_opt.add_theme_constant_override("icon_max_width", 14)
	
	# 좀비 밀도
	zombie_opt.clear()
	zombie_opt.add_item("매우 적음 (50%)", 0)
	zombie_opt.add_item("보통 (100%)", 1)
	zombie_opt.add_item("위험 (150%)", 2)
	zombie_opt.add_item("지옥 (250%)", 3)
	
	# 레이드 시간
	raid_time_opt.clear()
	raid_time_opt.add_item("10분 (스피드)", 0)
	raid_time_opt.add_item("20분 (스탠다드)", 1)
	raid_time_opt.add_item("30분 (여유)", 2)
	raid_time_opt.add_item("60분 (장기전)", 3)
	raid_time_opt.add_item("무제한 (Infinite)", 4)
	
	# 루팅 드롭률
	loot_opt.clear()
	loot_opt.add_item("희박함 (50%)", 0)
	loot_opt.add_item("보통 (100%)", 1)
	loot_opt.add_item("풍족함 (200%)", 2)
	loot_opt.add_item("대박 (400%)", 3)
	
	# 낮/밤 속도
	day_night_opt.clear()
	day_night_opt.add_item("빠름 (2분 주기)", 0)
	day_night_opt.add_item("보통 (5분 주기)", 1)
	day_night_opt.add_item("느림 (10분 주기)", 2)
	day_night_opt.add_item("영구 주간 (항상 낮)", 3)
	
	# 시작 소지금
	money_opt.clear()
	money_opt.add_item("1,000 루블 (극빈)", 0)
	money_opt.add_item("5,000 루블 (기본)", 1)
	money_opt.add_item("15,000 루블 (여유)", 2)
	money_opt.add_item("50,000 루블 (부유)", 3)

func _apply_preset(idx: int) -> void:
	is_updating_preset = true
	match idx:
		0: # 캐주얼
			zombie_opt.selected = 0
			raid_time_opt.selected = 2
			loot_opt.selected = 2
			day_night_opt.selected = 1
			money_opt.selected = 2
			permadeath_check.button_pressed = false
		1: # 스탠다드
			zombie_opt.selected = 1
			raid_time_opt.selected = 1
			loot_opt.selected = 1
			day_night_opt.selected = 1
			money_opt.selected = 1
			permadeath_check.button_pressed = false
		2: # 하드코어
			zombie_opt.selected = 2
			raid_time_opt.selected = 0
			loot_opt.selected = 0
			day_night_opt.selected = 0
			money_opt.selected = 0
			permadeath_check.button_pressed = true
	is_updating_preset = false

func _on_preset_selected(index: int) -> void:
	if index != 3:
		_apply_preset(index)

func _on_custom_option_changed(_val: Variant) -> void:
	if not is_updating_preset:
		preset_opt.selected = 3 # 커스텀으로 변경

func _on_start_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	
	var zombie_vals = [0.5, 1.0, 1.5, 2.5]
	var raid_vals = [10.0, 20.0, 30.0, 60.0, 99999.0]
	var loot_vals = [0.5, 1.0, 2.0, 4.0]
	var day_vals = [120.0, 300.0, 600.0, -1.0]
	var money_vals = [1000, 5000, 15000, 50000]
	
	var custom_settings = {
		"world_name": "Custom Game",
		"difficulty": ["casual", "normal", "hardcore", "custom"][preset_opt.selected],
		"zombie_multiplier": zombie_vals[zombie_opt.selected],
		"raid_duration_minutes": raid_vals[raid_time_opt.selected],
		"loot_multiplier": loot_vals[loot_opt.selected],
		"day_night_cycle_duration": day_vals[day_night_opt.selected],
		"starting_money": money_vals[money_opt.selected],
		"permadeath": permadeath_check.button_pressed
	}
	
	if GameManager:
		GameManager.start_new_game(custom_settings)

func _on_cancel_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	queue_free()
