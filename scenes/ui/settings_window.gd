# res://scenes/ui/settings_window.gd
extends Control

@onready var fullscreen_btn: CheckButton = $Panel/VBox/TabContainer/비디오/VBox/FullscreenBtn
@onready var resolution_opt: OptionButton = $Panel/VBox/TabContainer/비디오/VBox/ResolutionOpt
@onready var master_lbl: Label = $Panel/VBox/TabContainer/오디오/VBox/MasterLbl
@onready var master_vol: HSlider = $Panel/VBox/TabContainer/오디오/VBox/MasterVol
@onready var bgm_lbl: Label = $Panel/VBox/TabContainer/오디오/VBox/BGMLbl
@onready var bgm_vol: HSlider = $Panel/VBox/TabContainer/오디오/VBox/BGMVol
@onready var sfx_lbl: Label = $Panel/VBox/TabContainer/오디오/VBox/SFXLbl
@onready var sfx_vol: HSlider = $Panel/VBox/TabContainer/오디오/VBox/SFXVol

@onready var log_label: Label = $Panel/VBox/TabContainer/게임플레이/VBox/LogLabel
@onready var log_count_slider: HSlider = $Panel/VBox/TabContainer/게임플레이/VBox/LogCountSlider
@onready var movement_mode_opt: OptionButton = $Panel/VBox/TabContainer/게임플레이/VBox/MovementModeOpt

signal window_closed

var resolutions: Array[Vector2i] = [
	Vector2i(640, 360),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]

var integer_scale_btn: CheckButton = null

func _ready() -> void:
	# 초기화
	var win_mode := DisplayServer.window_get_mode()
	var is_fs := (win_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or win_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	if GameSettings and GameSettings.fullscreen:
		is_fs = true
	fullscreen_btn.button_pressed = is_fs
	
	resolution_opt.clear()
	for i in range(resolutions.size()):
		var res: Vector2i = resolutions[i]
		var suffix := ""
		if res == Vector2i(640, 360):
			suffix = " (0.5x 픽셀)"
		elif res == Vector2i(1280, 720):
			suffix = " (1x 정수 기준)"
		elif res == Vector2i(2560, 1440):
			suffix = " (2x 정수 배율)"
		resolution_opt.add_item("%d x %d%s" % [res.x, res.y, suffix])
		if (GameSettings and GameSettings.resolution_index == i) or DisplayServer.window_get_size() == res:
			resolution_opt.selected = i

	var video_vbox: VBoxContainer = get_node_or_null("Panel/VBox/TabContainer/비디오/VBox") as VBoxContainer
	if video_vbox:
		integer_scale_btn = CheckButton.new()
		integer_scale_btn.name = "IntegerScaleBtn"
		integer_scale_btn.text = "정수 배율 픽셀 스케일링 (Integer Scale)"
		integer_scale_btn.tooltip_text = "활성화 시 1px 픽셀 아트 테두리가 비정수 배율에서 뭉개지지 않도록 정수 배율로 고정합니다."
		var is_int_scale: bool = (GameSettings.integer_scaling if GameSettings else false) or (get_tree() != null and get_tree().root != null and get_tree().root.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_INTEGER)
		integer_scale_btn.button_pressed = is_int_scale
		integer_scale_btn.toggled.connect(_on_integer_scale_toggled)
		video_vbox.add_child(integer_scale_btn)
			
	# 로그 개수 슬라이더 초기화
	if GameSettings:
		log_count_slider.value = GameSettings.max_event_logs
		log_label.text = "이벤트 로그 최대 개수: %d개" % GameSettings.max_event_logs
		GameSettings.ensure_audio_buses()
		master_vol.value = GameSettings.master_volume
		bgm_vol.value = GameSettings.bgm_volume
		sfx_vol.value = GameSettings.sfx_volume
	_update_audio_labels()
	if movement_mode_opt:
		movement_mode_opt.clear()
		movement_mode_opt.add_item("기본 이동 (화면 상하좌우 WASD)")
		movement_mode_opt.add_item("시선 기준 이동 (W: 마우스 방향으로 전진)")
		movement_mode_opt.selected = clampi(GameSettings.movement_mode, 0, 1) if GameSettings else 0
			
	# 시그널 연결
	fullscreen_btn.toggled.connect(_on_fullscreen_toggled)
	resolution_opt.item_selected.connect(_on_resolution_selected)
	
	master_vol.value_changed.connect(func(v: float): _on_volume_changed("Master", v))
	bgm_vol.value_changed.connect(func(v: float): _on_volume_changed("BGM", v))
	sfx_vol.value_changed.connect(func(v: float): _on_volume_changed("SFX", v))
	
	log_count_slider.value_changed.connect(_on_log_count_changed)
	if movement_mode_opt:
		movement_mode_opt.item_selected.connect(_on_movement_mode_selected)
	
	var close_btn = $Panel/VBox/Header/CloseBtn
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)

func _on_movement_mode_selected(index: int) -> void:
	if GameSettings:
		GameSettings.movement_mode = clampi(index, 0, 1)
		GameSettings.save_settings()

func _on_log_count_changed(value: float) -> void:
	var count = int(value)
	log_label.text = "이벤트 로그 최대 개수: %d개" % count
	if GameSettings:
		GameSettings.max_event_logs = count
		GameSettings.save_settings()

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if GameSettings:
		GameSettings.fullscreen = toggled_on
		GameSettings.apply_display_settings()
		GameSettings.save_settings()
	elif DisplayServer.get_name() != "headless":
		if toggled_on:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_integer_scale_toggled(toggled_on: bool) -> void:
	if get_tree() and get_tree().root:
		get_tree().root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if toggled_on else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	if GameSettings:
		GameSettings.integer_scaling = toggled_on
		GameSettings.save_settings()

func _on_resolution_selected(index: int) -> void:
	var res: Vector2i = resolutions[index]
	if GameSettings:
		GameSettings.resolution_index = index
		GameSettings.apply_display_settings()
		GameSettings.save_settings()
	elif DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(res)

func _update_audio_labels() -> void:
	if master_lbl and master_vol:
		master_lbl.text = "마스터 볼륨 (Master Volume): %d%%" % int(round(master_vol.value * 100.0))
	if bgm_lbl and bgm_vol:
		bgm_lbl.text = "배경음악 (BGM Volume): %d%%" % int(round(bgm_vol.value * 100.0))
	if sfx_lbl and sfx_vol:
		sfx_lbl.text = "효과음 (SFX Volume): %d%%" % int(round(sfx_vol.value * 100.0))

func _on_volume_changed(bus_name: String, value: float) -> void:
	var clamped: float = clampf(value, 0.0, 1.0)
	if GameSettings:
		if bus_name == "Master":
			GameSettings.master_volume = clamped
		elif bus_name == "BGM":
			GameSettings.bgm_volume = clamped
		elif bus_name == "SFX":
			GameSettings.sfx_volume = clamped
		GameSettings.apply_audio_settings()
		GameSettings.save_settings()
	else:
		var idx: int = AudioServer.get_bus_index(bus_name)
		if idx != -1:
			AudioServer.set_bus_mute(idx, clamped <= 0.001)
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(clamped, 0.0001)))
	_update_audio_labels()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE or event.is_action_pressed("pause"):
			_on_close_pressed()
			if get_viewport():
				get_viewport().set_input_as_handled()

func _on_close_pressed() -> void:
	queue_free()
	window_closed.emit()
