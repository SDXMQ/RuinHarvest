# res://scenes/ui/save_slots_window.gd
extends Control

## 세이브 파일 목록 표시, 로드 및 삭제를 담당하는 윈도우

@onready var close_btn: Button = $Center/Panel/VBox/Header/CloseBtn
@onready var slots_container: VBoxContainer = $Center/Panel/VBox/ScrollContainer/SlotsVBox
@onready var no_saves_label: Label = $Center/Panel/VBox/ScrollContainer/SlotsVBox/NoSavesLabel

signal window_closed

func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	_refresh_slots()

func _refresh_slots() -> void:
	for child in slots_container.get_children():
		if child != no_saves_label:
			child.queue_free()
		
	var saves = SaveManager.get_save_files()
	
	if saves.is_empty():
		no_saves_label.visible = true
		return
	else:
		no_saves_label.visible = false
		
	for save_info in saves:
		var slot_card = _create_save_slot_card(save_info)
		slots_container.add_child(slot_card)

func _create_save_slot_card(info: Dictionary) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 64)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16, 0.9)
	style.border_width_left = 3
	style.border_color = Color(0.3, 0.6, 0.9)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	
	# 상단 타이틀 라벨 (월드명, 일차, 난이도)
	var title_lbl = Label.new()
	var w_name = info.get("world_name", "새 월드")
	var day = info.get("day", 1)
	var diff = info.get("difficulty", "normal")
	title_lbl.text = "🌍 %s (Day %d) [%s]" % [w_name, day, diff.to_upper()]
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	vbox.add_child(title_lbl)
	
	# 하단 정보 라벨 (소지금, 저장 일시)
	var info_lbl = Label.new()
	var funds = info.get("funds", 0)
	var save_time = info.get("save_time", "")
	info_lbl.text = "💰 소지금: %d 루블 | 🕒 %s" % [funds, save_time]
	info_lbl.add_theme_font_size_override("font_size", 12)
	info_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	vbox.add_child(info_lbl)
	
	# 우측 버튼들
	var load_btn = Button.new()
	load_btn.text = "불러오기"
	load_btn.custom_minimum_size = Vector2(84, 36)
	load_btn.pressed.connect(func(): _load_save(info.get("filename", "")))
	hbox.add_child(load_btn)
	
	var del_btn = Button.new()
	del_btn.text = "삭제"
	del_btn.custom_minimum_size = Vector2(50, 36)
	del_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	del_btn.pressed.connect(func(): _delete_save(info.get("filename", "")))
	hbox.add_child(del_btn)
	
	return panel

func _load_save(filename: String) -> void:
	if filename == "": return
	if SoundManager: SoundManager.play("menu_select")
	
	if GameManager:
		GameManager.load_game(filename)
	queue_free()

func _delete_save(filename: String) -> void:
	if filename == "": return
	if SoundManager: SoundManager.play("menu_select")
	
	SaveManager.delete_save(filename)
	_refresh_slots()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func _on_close_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	queue_free()
	window_closed.emit()
