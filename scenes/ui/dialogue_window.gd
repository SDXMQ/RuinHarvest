# res://scenes/ui/dialogue_window.gd
extends Control

@onready var name_label: Label = $Panel/VBox/NameLabel
@onready var text_label: Label = $Panel/VBox/TextLabel
@onready var next_indicator: Label = $Panel/NextIndicator

var current_dialogue: Array = []
var current_line_idx: int = 0
var is_typing: bool = false
var tween: Tween

signal window_closed

func _ready() -> void:
	if EventBus.has_signal("dialogue_started"):
		EventBus.dialogue_started.connect(start_dialogue)
	visible = false

func start_dialogue(npc_data: Dictionary) -> void:
	# npc_data = {"name": "프라포", "lines": ["안녕하세요.", "반갑습니다."]}
	name_label.text = npc_data.get("name", "NPC")
	current_dialogue = npc_data.get("lines", ["..."])
	current_line_idx = 0
	visible = true
	_show_line()

func _show_line() -> void:
	if current_line_idx >= current_dialogue.size():
		_end_dialogue()
		return
		
	next_indicator.visible = false
	text_label.text = current_dialogue[current_line_idx]
	text_label.visible_characters = 0
	is_typing = true
	
	if tween:
		tween.kill()
	tween = create_tween()
	var duration = text_label.text.length() * 0.05
	tween.tween_property(text_label, "visible_characters", text_label.text.length(), duration)
	tween.tween_callback(func(): 
		is_typing = false
		next_indicator.visible = true
	)

func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	
	if event.is_action_pressed("attack") or event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		
		if is_typing:
			# 즉시 표시
			if tween: tween.kill()
			text_label.visible_characters = -1
			is_typing = false
			next_indicator.visible = true
		else:
			current_line_idx += 1
			_show_line()

func _end_dialogue() -> void:
	visible = false
	if EventBus.has_signal("dialogue_ended"):
		EventBus.dialogue_ended.emit()
	window_closed.emit()
