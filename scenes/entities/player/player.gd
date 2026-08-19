# res://scenes/entities/player/player.gd
extends CharacterBody2D

# 기본 이동 설정
var walk_speed: float = 120.0
var sprint_speed: float = 200.0
var crouch_speed: float = 60.0

# 생존 스탯
var max_hp: float = 100.0
var hp: float = 100.0
var max_stamina: float = 100.0
var stamina: float = 100.0
var max_hunger: float = 100.0
var hunger: float = 100.0
var max_thirst: float = 100.0
var thirst: float = 100.0

# 상태이상
var is_bleeding: bool = false
var is_infected: bool = false
var is_fractured: bool = false

# 상호작용 관련
var interactable_tile_pos: Vector2i = Vector2i(-1, -1)
var interactable_type: Vector2i = Vector2i(-1, -1)

signal stats_changed
signal interact_prompt(show: bool, text: String)
signal object_interacted(world_pos: Vector2, tile_pos: Vector2i, type: Vector2i)

func _ready() -> void:
	# 초기화
	EventBus.player_damaged.connect(_on_player_damaged)

func _process(delta: float) -> void:
	_handle_survival_stats(delta)
	_update_interaction()

func _physics_process(delta: float) -> void:
	_handle_movement(delta)

func _handle_movement(delta: float) -> void:
	# 마우스 방향으로 회전
	var mouse_pos = get_global_mouse_position()
	rotation = global_position.direction_to(mouse_pos).angle()
	
	# WASD 입력 (InputMap 설정이 안 되어있을 경우 하드코딩 대체)
	var input_dir = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): input_dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S): input_dir.y += 1
	if Input.is_physical_key_pressed(KEY_A): input_dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D): input_dir.x += 1
	
	if Input.is_action_pressed("move_up"): input_dir.y -= 1
	if Input.is_action_pressed("move_down"): input_dir.y += 1
	if Input.is_action_pressed("move_left"): input_dir.x -= 1
	if Input.is_action_pressed("move_right"): input_dir.x += 1
	
	input_dir = input_dir.normalized()
	
	var is_sprinting = Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_action_pressed("sprint")
	var is_crouching = Input.is_physical_key_pressed(KEY_CTRL) or Input.is_action_pressed("crouch")
	
	var current_speed = walk_speed
	
	# 달리기 스태미너 소모 및 제어
	if is_sprinting and input_dir != Vector2.ZERO and stamina > 0 and not is_fractured:
		current_speed = sprint_speed
		stamina -= 15.0 * delta # 초당 15 소모
	elif is_crouching:
		current_speed = crouch_speed
		_regen_stamina(delta, 1.5)
	else:
		_regen_stamina(delta, 1.0)
	
	if is_fractured:
		current_speed *= 0.5 # 골절 시 이속 반토막
		
	# 스태미너 고갈 억제
	stamina = clamp(stamina, 0.0, max_stamina)
	
	velocity = input_dir * current_speed
	move_and_slide()

func _regen_stamina(delta: float, multiplier: float) -> void:
	if hunger > 20.0 and thirst > 20.0:
		stamina += 10.0 * multiplier * delta

func _handle_survival_stats(delta: float) -> void:
	# 허기/갈증 초당 소모
	hunger -= 0.2 * delta
	thirst -= 0.3 * delta
	
	# 출혈 데미지
	if is_bleeding:
		hp -= 1.0 * delta
		
	# 갈증/기아 데미지
	if hunger <= 0: hp -= 0.5 * delta
	if thirst <= 0: hp -= 1.0 * delta
	
	hunger = clamp(hunger, 0.0, max_hunger)
	thirst = clamp(thirst, 0.0, max_thirst)
	hp = clamp(hp, 0.0, max_hp)
	
	if hp <= 0:
		_die()
		
	stats_changed.emit()

var interact_cooldown: float = 0.0

func _update_interaction() -> void:
	# 쿨다운 감소
	if interact_cooldown > 0:
		interact_cooldown -= get_process_delta_time()
		
	# 타일맵 상호작용 (전방 1타일 거리)
	# 마우스 방향이나 캐릭터가 바라보는 방향 기준
	var interact_dist = 32.0 # 1타일 거리
	var check_pos = global_position + Vector2.RIGHT.rotated(rotation) * interact_dist
	var chunk_manager = get_node_or_null("/root/MainWorld/ChunkManager")
	
	interactable_type = Vector2i(-1, -1)
	interactable_tile_pos = Vector2i(-1, -1)
	var can_interact = false
	var prompt_text = ""
	
	if chunk_manager and chunk_manager.object_layer:
		var t_pos = chunk_manager.object_layer.local_to_map(check_pos)
		var tile_coords = chunk_manager.object_layer.get_cell_atlas_coords(t_pos)
		
		# 상호작용 가능한 타일인지 확인 (TileManager 상수 사용)
		if tile_coords == Vector2i(3, 1): # OBJ_CRATE
			can_interact = true
			prompt_text = "[E] 파밍 상자 열기"
		elif tile_coords == Vector2i(4, 1): # OBJ_BARREL
			can_interact = true
			prompt_text = "[E] 드럼통 뒤지기"
		elif tile_coords == Vector2i(5, 1): # OBJ_CAR
			can_interact = true
			prompt_text = "[E] 폐차 수색하기"
		elif tile_coords == Vector2i(6, 1): # OBJ_DOOR
			can_interact = true
			prompt_text = "[E] 문 열기/닫기"
			
		if can_interact:
			interactable_tile_pos = t_pos
			interactable_type = tile_coords
	
	interact_prompt.emit(can_interact, prompt_text)
	
	# 상호작용 실행 (꾹 누르기 방지 쿨다운 적용)
	if can_interact and interact_cooldown <= 0.0:
		if Input.is_action_just_pressed("interact") or (Input.is_physical_key_pressed(KEY_E) and Input.is_action_just_pressed("move_right") == false):
			# 임시로 is_physical_key_pressed 대신 action 위주로 처리하거나 짧은 쿨다운으로 연타 방지
			pass
		
		# Input 맵 이슈를 우회하면서도 연타를 막기 위해 E키 상태를 프레임 단위가 아닌 쿨다운으로 제어
		if Input.is_physical_key_pressed(KEY_E) or Input.is_action_just_pressed("interact"):
			interact_cooldown = 0.5 # 0.5초 쿨다운
			object_interacted.emit(check_pos, interactable_tile_pos, interactable_type)

func _on_player_damaged(amount: float, source: String) -> void:
	hp -= amount
	# 공격 소스에 따라 확률적 상태이상
	if source == "zombie" and randf() < 0.3:
		is_infected = true
	elif source == "gunfire" and randf() < 0.5:
		is_bleeding = true

func _die() -> void:
	EventBus.player_died.emit()
	# Game Over 로직

func _draw() -> void:
	# 캐릭터 그리기 (플레이어 반경 14)
	var radius = 14.0
	
	# 외곽선
	draw_circle(Vector2.ZERO, radius + 2, Color.BLACK)
	# 셔츠 (초록색)
	draw_circle(Vector2.ZERO, radius, Color(0.3, 0.5, 0.3))
	# 머리/피부 (가운데 살구색)
	draw_circle(Vector2.ZERO, radius * 0.6, Color(0.9, 0.8, 0.7))
	# 앞을 가리키는 총구 / 시선
	var aim_dir = Vector2(radius * 1.2, 0)
	draw_line(Vector2.ZERO, aim_dir, Color.BLACK, 4.0)
	draw_circle(aim_dir, 3.0, Color.RED)
