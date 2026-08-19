# res://scenes/world/main_world.gd
extends Node2D

@onready var chunk_manager: Node = $ChunkManager
@onready var world_renderer: Node2D = $WorldRenderer
@onready var entities_layer: Node2D = $Entities
@onready var pause_menu: Control = $UI/PauseMenu
@onready var resume_btn: Button = $UI/PauseMenu/CenterPanel/VBoxContainer/ResumeBtn
@onready var exit_btn: Button = $UI/PauseMenu/CenterPanel/VBoxContainer/ExitBtn
@onready var debug_label: Label = $UI/HUD/Panel/DebugLabel

const PlayerScene = preload("res://scenes/entities/player/player.tscn")
var player: CharacterBody2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # 일시정지 중에도 메인 월드 스크립트 실행 유지
	
	# 플레이어 인스턴스화
	player = PlayerScene.instantiate()
	player.position = Vector2.ZERO
	entities_layer.add_child(player)
	
	# 일시정지 메뉴 버튼 시그널 연결
	resume_btn.pressed.connect(_on_resume_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)
	pause_menu.visible = false

	# 청크 매니저 시그널 연결
	chunk_manager.chunk_loaded.connect(_on_chunk_loaded)
	chunk_manager.chunk_unloaded.connect(_on_chunk_unloaded)
	
	# 초기 청크 로드
	chunk_manager.update_chunks(player.global_position)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			_toggle_pause()
			get_viewport().set_input_as_handled()
			return
			
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if player:
		# 플레이어 이동 시 청크 업데이트 (render_distance 기준)
		chunk_manager.update_chunks(player.global_position)
		
		if debug_label:
			var cx = floor(player.global_position.x / (16 * 32))
			var cy = floor(player.global_position.y / (16 * 32))
			var pos_text = "위치: (%.1f, %.1f) | 청크: (%d, %d)" % [player.global_position.x, player.global_position.y, cx, cy]
			var speed_text = "이동 속도: %.1f px/s" % [player.velocity.length()]
			var hint_text = "조작: WASD 이동 | Shift 달리기 | ESC 일시정지"
			debug_label.text = "%s\n%s\n%s" % [pos_text, speed_text, hint_text]

func _on_chunk_loaded(chunk_pos: Vector2i, data: Dictionary) -> void:
	world_renderer.add_chunk(chunk_pos, data)

func _on_chunk_unloaded(chunk_pos: Vector2i) -> void:
	world_renderer.remove_chunk(chunk_pos)

func _toggle_pause() -> void:
	var next_pause_state = not get_tree().paused
	get_tree().paused = next_pause_state
	pause_menu.visible = next_pause_state
	if GameManager:
		GameManager.is_paused = next_pause_state

func _on_resume_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	_toggle_pause()

func _on_exit_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	get_tree().paused = false
	if GameManager:
		GameManager.is_paused = false
		GameManager.end_raid("survived")
