# res://scenes/ui/radio_window.gd
extends Control

@onready var close_btn: Button = $Panel/VBox/Header/CloseBtn
@onready var scan_container: VBoxContainer = $Panel/VBox/ScanContainer

signal window_closed

func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	
	var targets = [
		{"name": "인근 생존자 스캔", "type": "survivor", "cost": 50},
		{"name": "물자 투하 위치 스캔", "type": "supply", "cost": 100},
		{"name": "군사 기지 신호 스캔", "type": "military", "cost": 200}
	]
	
	for t in targets:
		var btn = Button.new()
		btn.text = "%s (전력/배터리 %d 소모)" % [t["name"], t["cost"]]
		btn.pressed.connect(func(): _scan_target(t["type"]))
		scan_container.add_child(btn)

func _scan_target(type: String) -> void:
	if SoundManager: SoundManager.play("menu_select")
	if EventBus.has_signal("radio_scan_requested"):
		EventBus.radio_scan_requested.emit(type)
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("📻 무전기 스캔 시작: " + type)
	_on_close_pressed()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func _on_close_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	queue_free()
	window_closed.emit()
