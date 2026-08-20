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

# 무기 및 전투
const BulletScene = preload("res://scenes/entities/projectiles/bullet.gd")
var equipped_weapon: String = "권총"
var attack_cooldown_timer: float = 0.0
var weapon_fire_rate: float = 0.35 # 발사 간격 (초)

signal stats_changed
signal interact_prompt(show: bool, text: String)
signal object_interacted(world_pos: Vector2, tile_pos: Vector2i, type: Vector2i)

# 손전등 및 조명
var flashlight: PointLight2D
var ambient_light: PointLight2D
var muzzle_light: PointLight2D
var flashlight_enabled: bool = true
var muzzle_flash_timer: float = 0.0

func _ready() -> void:
	add_to_group("player")
	EventBus.player_damaged.connect(_on_player_damaged)
	_setup_lighting()

func _setup_lighting() -> void:
	# 1. 발밑 주변 360도 은은한 조명 (반경 70px)
	ambient_light = PointLight2D.new()
	ambient_light.name = "AmbientLight"
	ambient_light.texture = _create_radial_gradient(140, 0.45)
	ambient_light.color = Color(1.0, 0.95, 0.8)
	ambient_light.energy = 0.9
	add_child(ambient_light)
	
	# 2. 전방 집중 부채꼴 손전등 빔 (Real Flashlight Cone)
	flashlight = PointLight2D.new()
	flashlight.name = "Flashlight"
	flashlight.texture = _create_flashlight_cone_texture(320, 240, 65.0)
	flashlight.offset = Vector2(160, 0) # 광원 중심을 전방으로 이동
	flashlight.color = Color(1.0, 0.98, 0.9)
	flashlight.energy = 1.4
	add_child(flashlight)
	
	# 3. 총구 전방 집중 화염 조명 (Directional Muzzle Flash Cone)
	muzzle_light = PointLight2D.new()
	muzzle_light.name = "MuzzleLight"
	muzzle_light.texture = _create_flashlight_cone_texture(240, 180, 100.0)
	muzzle_light.offset = Vector2(120, 0) # 전방 120px 중심의 100도 부채꼴 화염
	muzzle_light.color = Color(1.0, 0.85, 0.4)
	muzzle_light.energy = 0.0
	muzzle_light.enabled = false
	add_child(muzzle_light)
	
	set_flashlight(flashlight_enabled)

func set_flashlight(enabled: bool) -> void:
	flashlight_enabled = enabled
	if flashlight:
		flashlight.enabled = flashlight_enabled
	if ambient_light:
		ambient_light.enabled = flashlight_enabled

func _create_radial_gradient(size: int, intensity: float) -> GradientTexture2D:
	var grad = Gradient.new()
	grad.colors = PackedColorArray([Color(1, 1, 1, intensity), Color(1, 1, 1, 0)])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = size
	tex.height = size
	return tex

func _create_flashlight_cone_texture(width: int, height: int, cone_angle_deg: float) -> ImageTexture:
	var img = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	var start_x = 0.0
	var start_y = height / 2.0
	var half_angle_rad = deg_to_rad(cone_angle_deg / 2.0)
	var max_dist = float(width)
	
	for y in range(height):
		for x in range(width):
			var dx = x - start_x
			var dy = y - start_y
			var dist = sqrt(dx * dx + dy * dy)
			
			if dist <= 0.0 or dist > max_dist:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
				
			var angle = abs(atan2(dy, dx))
			if angle > half_angle_rad:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
				
			# 1. 거리에 따른 부드러운 감쇠 (Falloff)
			var dist_factor = pow(1.0 - (dist / max_dist), 1.6)
			# 2. 부채꼴 가장자리 부드러운 페이드 (Edge feathering)
			var angle_factor = cos((angle / half_angle_rad) * (PI / 2.0))
			
			var alpha = clamp(dist_factor * angle_factor, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
			
	return ImageTexture.create_from_image(img)

func _process(delta: float) -> void:
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
		
	# 총구 화염 조명 감쇠
	if muzzle_flash_timer > 0.0:
		muzzle_flash_timer -= delta
		if muzzle_flash_timer <= 0.0:
			if muzzle_light:
				muzzle_light.enabled = false
				muzzle_light.energy = 0.0
		else:
			if muzzle_light:
				muzzle_light.energy = (muzzle_flash_timer / 0.05) * 1.5
		queue_redraw()
		
	_handle_survival_stats(delta)
	_update_interaction()
	_handle_combat(delta)

func _unhandled_input(event: InputEvent) -> void:
	# F 키 손전등 ON/OFF 토글
	if event.is_action_pressed("flashlight") or (event is InputEventKey and event.physical_keycode == KEY_F and event.pressed and not event.echo):
		set_flashlight(not flashlight_enabled)
		if SoundManager:
			SoundManager.play("menu_select")
		get_viewport().set_input_as_handled()

func _handle_combat(_delta: float) -> void:
	if Input.is_action_just_pressed("attack") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# UI가 떠있거나 일시정지면 무시
		if get_tree().paused: return
		_try_attack()

func _try_attack() -> void:
	if attack_cooldown_timer > 0: return
	attack_cooldown_timer = weapon_fire_rate
	
	var aim_dir = Vector2.RIGHT.rotated(rotation)
	var spawn_pos = global_position + aim_dir * 18.0
	
	if equipped_weapon == "권총" or equipped_weapon == "레버액션 소총":
		# 국소 총구 화염 발광 (0.05초)
		muzzle_flash_timer = 0.05
		if muzzle_light:
			muzzle_light.enabled = true
			muzzle_light.energy = 1.5
		queue_redraw()
		
		# 총구 스파크 + 탄피 파티클
		var ps = get_tree().current_scene.get_node_or_null("ParticleSystem")
		if ps:
			ps.emit("muzzle", spawn_pos.x, spawn_pos.y, 4, rotation)
			ps.emit("bullet_shell", spawn_pos.x, spawn_pos.y, 1, rotation)
		
		# 총알 발사
		var bullet_scene = load("res://scenes/entities/projectiles/bullet.tscn")
		if bullet_scene:
			var bullet = bullet_scene.instantiate()
			get_parent().add_child(bullet)
			bullet.setup(spawn_pos, aim_dir, 25.0)
			
		if SoundManager:
			SoundManager.play("hit_ranged")
	else:
		# 근접 공격 (전방 40px 부채꼴 범위 공격)
		# 슬래시 파티클
		var ps = get_tree().current_scene.get_node_or_null("ParticleSystem")
		if ps:
			ps.emit("slash", spawn_pos.x, spawn_pos.y, 6, rotation)
		
		if SoundManager:
			SoundManager.play("hit_melee")
			
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsShapeQueryParameters2D.new()
		var circle = CircleShape2D.new()
		circle.radius = 35.0
		query.shape = circle
		query.transform = Transform2D(0, spawn_pos)
		var results = space_state.intersect_shape(query)
		for res in results:
			var collider = res.get("collider")
			if collider and collider.has_method("take_damage") and collider != self:
				collider.take_damage(15.0, aim_dir)

func _physics_process(delta: float) -> void:
	_handle_movement(delta)

var is_exhausted: bool = false

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
	
	var wants_sprint = Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_action_pressed("sprint")
	var is_crouching = Input.is_physical_key_pressed(KEY_CTRL) or Input.is_action_pressed("crouch")
	
	# 탈진 상태 관리 (0 이하로 떨어지면 탈진, 25 이상 회복되어야 달리기 가능)
	if stamina <= 0.0:
		is_exhausted = true
	elif is_exhausted and stamina >= 25.0:
		is_exhausted = false
		
	var current_speed = walk_speed
	
	# 달리기 스태미너 소모 및 제어
	if wants_sprint and input_dir != Vector2.ZERO and not is_exhausted and stamina > 5.0 and not is_fractured:
		current_speed = sprint_speed
		stamina -= 25.0 * delta # 달리기 시 초당 25 소모
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
	
	var object_layer: TileMapLayer = null
	var chunk_manager = get_node_or_null("/root/MainWorld/ChunkManager")
	if chunk_manager and chunk_manager.object_layer:
		object_layer = chunk_manager.object_layer
	else:
		# 실내 씬 등 부모 노드 계층에서 ObjectsLayer 탐색
		var cur_scene = get_tree().current_scene
		if cur_scene and cur_scene.has_node("ObjectsLayer"):
			object_layer = cur_scene.get_node("ObjectsLayer")
		elif get_parent() and get_parent().get_parent() and get_parent().get_parent().has_node("ObjectsLayer"):
			object_layer = get_parent().get_parent().get_node("ObjectsLayer")
	
	interactable_type = Vector2i(-1, -1)
	interactable_tile_pos = Vector2i(-1, -1)
	var can_interact = false
	var prompt_text = ""
	
	if object_layer:
		var t_pos = object_layer.local_to_map(check_pos)
		var tile_coords = object_layer.get_cell_atlas_coords(t_pos)
		
		# 상호작용 가능한 타일인지 확인 (TileManager 상수 사용)
		if tile_coords == Vector2i(3, 1): # OBJ_CRATE
			can_interact = true
			prompt_text = "[E] 수색하기"
		elif tile_coords == Vector2i(4, 1): # OBJ_BARREL
			can_interact = true
			prompt_text = "[E] 가구 수색하기"
		elif tile_coords == Vector2i(5, 1): # OBJ_CAR
			can_interact = true
			prompt_text = "[E] 폐차 수색하기"
		elif tile_coords == Vector2i(6, 1): # OBJ_DOOR
			can_interact = true
			prompt_text = "[E] 문 열기/나가기"
			
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
	
	# 총구 화염 스파크 (총구 앞에서만 작게 1~2프레임 렌더)
	if muzzle_flash_timer > 0.0:
		var flash_tip = aim_dir + Vector2(6, 0)
		draw_circle(flash_tip, 5.0, Color(1.0, 0.9, 0.3, 0.9)) # 밝은 코어
		draw_circle(flash_tip + Vector2(3, 0), 3.0, Color(1.0, 0.5, 0.1, 0.8)) # 외곽 스파크
