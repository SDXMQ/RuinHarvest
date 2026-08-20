# res://scenes/ui/save_slots_window.gd
extends Control

@onready var close_btn: Button = $Panel/VBox/Header/CloseBtn
@onready var slots_container: VBoxContainer = $Panel/VBox/ScrollContainer/SlotsVBox

signal window_closed

func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	_refresh_slots()

func _refresh_slots() -> void:
	for child in slots_container.get_children():
		child.queue_free()
		
	# 가상의 세이브 데이터 3개 표시
	for i in range(1, 4):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 50)
		btn.text = "세이브 슬롯 %d - (Day 1)" % i
		btn.pressed.connect(func(): _load_save(i))
		slots_container.add_child(btn)

func _load_save(slot_idx: int) -> void:
	if SoundManager: SoundManager.play("menu_select")
	# 현재는 구현용 껍데기이므로 강제로 hideout 진입
	if GameManager:
		GameManager.current_state = GameManager.GameState.HIDEOUT
	get_tree().change_scene_to_file("res://scenes/hideout/hideout.tscn")
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func _on_close_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	queue_free()
	window_closed.emit()
