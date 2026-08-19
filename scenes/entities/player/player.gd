# res://scenes/entities/player/player.gd
extends CharacterBody2D

var base_speed: float = 160.0
var current_speed: float = 160.0

@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	if GameSettings:
		base_speed = GameSettings.PLAYER_SPEED * float(GameSettings.TILE_SIZE)
	current_speed = base_speed

func _physics_process(_delta: float) -> void:
	if GameManager and GameManager.is_paused:
		velocity = Vector2.ZERO
		return
		
	# 1. 이동 벡터 계산 (InputMap 액션 또는 물리 키 직접 폴백)
	var input_vec = Vector2.ZERO
	
	# InputMap 체크
	if InputMap.has_action("move_left"):
		input_vec = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		
	# 폴백 키 검사 (InputMap이 비정상일 경우 대비)
	if input_vec == Vector2.ZERO:
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			input_vec.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			input_vec.y += 1.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			input_vec.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			input_vec.x += 1.0
		input_vec = input_vec.normalized()
		
	# 2. 달리기 / 웅크리기 배율 적용
	var speed_mult: float = 1.0
	if Input.is_action_pressed("sprint") or Input.is_key_pressed(KEY_SHIFT):
		speed_mult = 1.6
	elif Input.is_action_pressed("crouch") or Input.is_key_pressed(KEY_CTRL):
		speed_mult = 0.5
		
	current_speed = base_speed * speed_mult
	velocity = input_vec * current_speed
	
	# 3. 마우스 커서 방향 회전
	var mouse_pos = get_global_mouse_position()
	rotation = (mouse_pos - global_position).angle()
	
	move_and_slide()
	queue_redraw()

func _draw() -> void:
	# 플레이어 본체 (원형 바디)
	draw_circle(Vector2.ZERO, 14.0, Color(0.25, 0.4, 0.25)) # 녹색 옷
	draw_circle(Vector2.ZERO, 10.0, Color(0.85, 0.7, 0.55)) # 피부
	
	# 앞 방향 표시 (총구/시선)
	draw_line(Vector2(6, 0), Vector2(18, 0), Color(0.2, 0.2, 0.2), 4.0)
	draw_circle(Vector2(18, 0), 2.5, Color(0.8, 0.3, 0.2))
