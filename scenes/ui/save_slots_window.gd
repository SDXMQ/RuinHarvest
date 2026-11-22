# res://scenes/ui/save_slots_window.gd
extends Control

## 세이브 파일 목록 표시, 로드 및 삭제를 담당하는 윈도우

@onready var title_label: Label = $Center/Panel/VBox/Header/Title
@onready var close_btn: Button = $Center/Panel/VBox/Header/CloseBtn
@onready var slots_container: VBoxContainer = $Center/Panel/VBox/ScrollContainer/SlotsVBox
@onready var no_saves_label: Label = $Center/Panel/VBox/ScrollContainer/SlotsVBox/NoSavesLabel
@onready var open_folder_btn: Button = $Center/Panel/VBox/Footer/OpenFolderBtn
@onready var refresh_btn: Button = $Center/Panel/VBox/Footer/RefreshBtn

signal window_closed

func _ready() -> void:
	if UiIconManager:
		UiIconManager.set_label_icon(title_label, "save", "", 18, 6)
		UiIconManager.apply_button_icon(open_folder_btn, "folder", "", 16)
		UiIconManager.apply_button_icon(refresh_btn, "refresh", "", 16)
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
	
	if PixelAssetManager:
		var style: StyleBox = PixelAssetManager.get_pixel_stylebox("save_slot_card", 12.0, 8.0, 12.0, 8.0, 4)
		if style != null:
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
	title_lbl.text = "%s (Day %d) [%s]" % [w_name, day, diff.to_upper()]
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	vbox.add_child(title_lbl)
	if UiIconManager:
		UiIconManager.set_label_icon(title_lbl, "globe", "", 14, 5)
	
	# 하단 정보 행 (소지금, 저장 일시)
	var funds = info.get("funds", 0)
	var save_time = info.get("save_time", "")
	var info_row = HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 5)
	if UiIconManager:
		info_row.add_child(UiIconManager.create_icon_rect("money", 13))
	var funds_lbl = Label.new()
	funds_lbl.text = "소지금: %d 루블  |" % funds
	funds_lbl.add_theme_font_size_override("font_size", 12)
	funds_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	info_row.add_child(funds_lbl)
	if UiIconManager:
		info_row.add_child(UiIconManager.create_icon_rect("clock", 13))
	var time_lbl = Label.new()
	time_lbl.text = str(save_time)
	time_lbl.add_theme_font_size_override("font_size", 12)
	time_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	info_row.add_child(time_lbl)
	vbox.add_child(info_row)
	
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

func _on_open_folder_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	SaveManager.ensure_save_dir()
	var global_path = ProjectSettings.globalize_path(SaveManager.SAVE_DIR)
	OS.shell_open(global_path)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func _on_close_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	queue_free()
	window_closed.emit()
