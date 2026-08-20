# res://scenes/ui/settings_window.gd
extends Control

@onready var fullscreen_btn: CheckButton = $Panel/VBox/TabContainer/비디오/VBox/FullscreenBtn
@onready var resolution_opt: OptionButton = $Panel/VBox/TabContainer/비디오/VBox/ResolutionOpt
@onready var master_vol: HSlider = $Panel/VBox/TabContainer/오디오/VBox/MasterVol
@onready var sfx_vol: HSlider = $Panel/VBox/TabContainer/오디오/VBox/SFXVol
@onready var bgm_vol: HSlider = $Panel/VBox/TabContainer/오디오/VBox/BGMVol

signal window_closed

var resolutions = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]

func _ready() -> void:
	# 초기화
	fullscreen_btn.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	for i in range(resolutions.size()):
		var res = resolutions[i]
		resolution_opt.add_item("%d x %d" % [res.x, res.y])
		if DisplayServer.window_get_size() == res:
			resolution_opt.selected = i
			
	# 시그널 연결
	fullscreen_btn.toggled.connect(_on_fullscreen_toggled)
	resolution_opt.item_selected.connect(_on_resolution_selected)
	
	master_vol.value_changed.connect(func(v): _on_volume_changed(0, v))
	bgm_vol.value_changed.connect(func(v): _on_volume_changed(1, v))
	sfx_vol.value_changed.connect(func(v): _on_volume_changed(2, v))
	
	var close_btn = $Panel/VBox/Header/CloseBtn
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_resolution_selected(index: int) -> void:
	var res = resolutions[index]
	DisplayServer.window_set_size(res)

func _on_volume_changed(bus_idx: int, value: float) -> void:
	var db = linear_to_db(max(value, 0.001))
	AudioServer.set_bus_volume_db(bus_idx, db)
	AudioServer.set_bus_mute(bus_idx, value <= 0.0)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func _on_close_pressed() -> void:
	queue_free()
	window_closed.emit()
