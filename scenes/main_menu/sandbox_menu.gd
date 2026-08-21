# res://scenes/main_menu/sandbox_menu.gd
extends Control

## 샌드박스 커스텀 게임 설정 스크립트

@onready var zombie_opt: OptionButton = $Center/Panel/VBox/ZombieRow/ZombieOpt
@onready var raid_time_opt: OptionButton = $Center/Panel/VBox/RaidTimeRow/RaidTimeOpt
@onready var day_night_opt: OptionButton = $Center/Panel/VBox/DayNightRow/DayNightOpt
@onready var loot_opt: OptionButton = $Center/Panel/VBox/LootRow/LootOpt
@onready var money_opt: OptionButton = $Center/Panel/VBox/MoneyRow/MoneyOpt

@onready var start_btn: Button = $Center/Panel/Buttons/StartBtn
@onready var back_btn: Button = $Center/Panel/Buttons/BackBtn

func _ready() -> void:
	# 좀비 스폰 밀도
	zombie_opt.clear()
	zombie_opt.add_item("평화로움 (50%)", 0)
	zombie_opt.add_item("보통 (100%)", 1)
	zombie_opt.add_item("위험 (200%)", 2)
	zombie_opt.add_item("아포칼립스 지옥 (400%)", 3)
	zombie_opt.selected = 1
	
	# 레이드 제한 시간
	raid_time_opt.clear()
	raid_time_opt.add_item("10분 (빠른 탈출)", 0)
	raid_time_opt.add_item("20분 (스탠다드)", 1)
	raid_time_opt.add_item("30분 (여유로움)", 2)
	raid_time_opt.add_item("무제한 (Infinite)", 3)
	raid_time_opt.selected = 2
	
	# 낮/밤 주기
	day_night_opt.clear()
	day_night_opt.add_item("빠름 (2분 주기)", 0)
	day_night_opt.add_item("보통 (5분 주기)", 1)
	day_night_opt.add_item("느림 (10분 주기)", 2)
	day_night_opt.add_item("영구 주간 (항상 낮)", 3)
	day_night_opt.selected = 1
	
	# 루팅 드롭률
	loot_opt.clear()
	loot_opt.add_item("희박함 (50%)", 0)
	loot_opt.add_item("보통 (100%)", 1)
	loot_opt.add_item("풍족함 (200%)", 2)
	loot_opt.add_item("파밍 대박 (400%)", 3)
	loot_opt.selected = 1
	
	# 시작 소지금
	money_opt.clear()
	money_opt.add_item("1,000 루블", 0)
	money_opt.add_item("5,000 루블", 1)
	money_opt.add_item("25,000 루블", 2)
	money_opt.add_item("100,000 루블", 3)
	money_opt.selected = 1
	
	start_btn.pressed.connect(_on_start_pressed)
	back_btn.pressed.connect(_on_back_pressed)

func _on_start_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	
	var zombie_multipliers = [0.5, 1.0, 2.0, 4.0]
	var raid_durations = [10.0, 20.0, 30.0, 99999.0]
	var day_speeds = [120.0, 300.0, 600.0, -1.0]
	var loot_multipliers = [0.5, 1.0, 2.0, 4.0]
	var start_moneys = [1000, 5000, 25000, 100000]
	
	var custom_settings = {
		"world_name": "Sandbox World",
		"mode": "sandbox",
		"zombie_multiplier": zombie_multipliers[zombie_opt.selected],
		"raid_duration_minutes": raid_durations[raid_time_opt.selected],
		"day_night_cycle_duration": day_speeds[day_night_opt.selected],
		"loot_multiplier": loot_multipliers[loot_opt.selected],
		"starting_money": start_moneys[money_opt.selected]
	}
	
	if GameManager:
		GameManager.start_new_game(custom_settings)

func _on_back_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	queue_free()
