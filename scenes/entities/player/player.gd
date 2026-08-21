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
const BulletScene = preload("res://scenes/entities/projectiles/bullet.tscn")
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

# 시각 효과 (Visuals) 관련 변수
var walk_bob: float = 0.0
var recoil_offset: float = 0.0
var hit_flash_tween: Tween

func _ready() -> void:
	add_to_group("player")
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.camera_shake_requested.connect(_on_camera_shake_requested)
	_setup_lighting()
	
	if has_node("Camera2D"):
		base_camera_pos = get_node("Camera2D").position
	
	if has_node("Visuals"):
		get_node("Visuals").draw.connect(_on_visuals_draw)

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
	
	# 실시간 2D 그림자 차폐 (Occlusion) 적용
	flashlight.shadow_enabled = true
	flashlight.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5 # 부드러운 그림자
	
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

var shake_intensity: float = 0.0
var shake_timer: float = 0.0
var base_camera_pos: Vector2 = Vector2.ZERO

func _on_camera_shake_requested(intensity: float, duration: float) -> void:
	shake_intensity = intensity
	shake_timer = duration

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
	
	# 카메라 셰이크 처리
	if shake_timer > 0:
		shake_timer -= delta
		if has_node("Camera2D"):
			var cam = get_node("Camera2D")
			# 부드러운 셰이크를 위해 노이즈 사용 (여기서는 랜덤)
			cam.position = base_camera_pos + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_intensity * (shake_timer / 0.5)
	else:
		if has_node("Camera2D"):
			get_node("Camera2D").position = base_camera_pos

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

var inventory: Inventory = null

func _has_ammo() -> bool:
	if not inventory: return true
	for item in inventory.items:
		if item and item["id"] == "탄약" and item["amount"] > 0:
			return true
	return false

func _consume_ammo() -> bool:
	if not inventory: return true
	for i in range(inventory.max_slots):
		var item = inventory.items[i]
		if item and item["id"] == "탄약" and item["amount"] > 0:
			inventory.remove_item_at(i, 1)
			return true
	return false

func _degrade_weapon(amount: float = 1.0) -> void:
	if not inventory: return
	for item in inventory.items:
		if item and (item["id"] == equipped_weapon or (equipped_weapon == "권총" and item["id"] == "권총")):
			if item.has("durability"):
				item["durability"] = max(0, item["durability"] - amount)
				inventory.inventory_changed.emit()
				break

func _try_attack() -> void:
	if attack_cooldown_timer > 0: return
	attack_cooldown_timer = weapon_fire_rate
	
	var aim_dir = Vector2.RIGHT.rotated(rotation)
	var spawn_pos = global_position + aim_dir * 18.0
	
	if equipped_weapon == "권총" or equipped_weapon == "레버액션 소총":
		# 탄약 확인 및 소모
		if not _has_ammo():
			if SoundManager:
				SoundManager.play("menu_select")
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("⚠️ [탄약 부족] 발사할 탄약(9mm)이 없습니다!")
			return
			
		_consume_ammo()
		_degrade_weapon(1.0) # 사격 시 무기 내구도 1 감소
		recoil_offset = 6.0 # 총기 반동
		
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
	
	# 1. 물리 엔티티 기반 상호작용 (우선)
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = check_pos
	query.collision_mask = 1 | 2 # 엔티티/환경
	query.collide_with_bodies = true
	query.collide_with_areas = true
	
	var results = space_state.intersect_point(query)
	var found_entity = false
	
	for res in results:
		var collider = res["collider"]
		if collider and collider.get("interactable_type") != null:
			var i_type = collider.get("interactable_type")
			if typeof(i_type) == TYPE_VECTOR2I and i_type == Vector2i(5, 1):
				can_interact = true
				prompt_text = "[E] 폐차 트렁크 열기"
				interactable_type = i_type
				
				# 엔티티 상호작용 시, tile_pos 대신 엔티티의 고유 좌표(타일맵 좌표로 변환된 값) 사용
				if object_layer:
					interactable_tile_pos = object_layer.local_to_map(collider.global_position)
				else:
					interactable_tile_pos = Vector2i(int(collider.global_position.x / 32), int(collider.global_position.y / 32))
					
				found_entity = true
				break
				
	# 2. 타일맵 기반 상호작용 (엔티티가 없으면 실행)
	if not found_entity and object_layer:
		var t_pos = object_layer.local_to_map(check_pos)
		var tile_coords = object_layer.get_cell_atlas_coords(t_pos)
		
		# 상호작용 가능한 타일인지 확인
		if tile_coords == Vector2i(3, 1): # OBJ_CRATE
			can_interact = true
			prompt_text = "[E] 수색하기"
		elif tile_coords == Vector2i(4, 1): # OBJ_BARREL
			can_interact = true
			prompt_text = "[E] 가구 수색하기"
		elif tile_coords == Vector2i(5, 1): # OBJ_DEBRIS/CAR (잔해)
			can_interact = true
			prompt_text = "[E] 잔해물 뒤지기"
		elif tile_coords == Vector2i(6, 1): # OBJ_DOOR
			can_interact = true
			prompt_text = "[E] 문 열기/나가기"
			
		if can_interact:
			interactable_tile_pos = t_pos
			interactable_type = tile_coords
	
	interact_prompt.emit(can_interact, prompt_text)
	
	# 상호작용 실행 (꾹 누르기 방지 쿨다운 적용)
	if can_interact and interact_cooldown <= 0.0:
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
		
	# 피격 플래시 효과 및 카메라 셰이크
	_play_hit_flash()
	EventBus.camera_shake_requested.emit(8.0, 0.3)

func _play_hit_flash() -> void:
	var visuals = get_node_or_null("Visuals")
	if visuals and visuals.material:
		if hit_flash_tween:
			hit_flash_tween.kill()
		hit_flash_tween = create_tween()
		visuals.material.set_shader_parameter("flash_color", Color(1, 0, 0, 1)) # 붉은 플래시
		visuals.material.set_shader_parameter("flash_modifier", 1.0)
		hit_flash_tween.tween_property(visuals.material, "shader_parameter/flash_modifier", 0.0, 0.2)

func _die() -> void:
	EventBus.player_died.emit()
	# Game Over 로직

func _fire_weapon() -> void:
	attack_cooldown_timer = weapon_fire_rate
	recoil_offset = 6.0 # 반동
	
	# 투사체 발사
	var bullet = BulletScene.instantiate()
	bullet.global_position = global_position + Vector2(20, 0).rotated(rotation)
	bullet.rotation = rotation
	get_tree().current_scene.add_child(bullet)
	
	# 총구 화염 및 조명 켬
	muzzle_flash_timer = 0.08
	if muzzle_light:
		muzzle_light.enabled = true
		
	if has_node("Visuals"):
		get_node("Visuals").queue_redraw()
	
	# 소음
	if SoundManager:
		SoundManager.play("gun_fire")
		# 좀비 어그로를 끄는 이벤트 방출 가능
		EventBus.noise_created.emit(global_position, 600.0)

func _on_visuals_draw() -> void:
	var visuals = get_node("Visuals")
	
	# 걷기 밥에 따른 Y 오프셋 및 회전
	var bob_y = sin(walk_bob * 2.0) * 2.0
	var bob_rot = sin(walk_bob) * 0.1
	visuals.position = Vector2(0, bob_y)
	visuals.rotation = bob_rot
	
	var skin_color = Color(0.9, 0.8, 0.7)
	
	# --- 1. 방탄 조끼 (Tactical Vest) / 상체 ---
	# 다각형으로 어깨 및 몸통 각지게 표현
	var vest_points = PackedVector2Array([
		Vector2(-10, -12), # 등 좌측
		Vector2(-10, 12),  # 등 우측
		Vector2(2, 14),    # 우측 어깨 앞
		Vector2(12, 8),    # 앞가슴 우측
		Vector2(12, -8),   # 앞가슴 좌측
		Vector2(2, -14)    # 좌측 어깨 앞
	])
	
	var vest_colors = PackedColorArray()
	var vest_outline = PackedColorArray()
	for p in vest_points:
		vest_colors.append(Color(0.2, 0.3, 0.2)) # 진녹색 조끼
		vest_outline.append(Color(0.1, 0.1, 0.1))
		
	var vest_outline_pts = PackedVector2Array()
	for p in vest_points:
		vest_outline_pts.append(p * 1.15)
		
	visuals.draw_polygon(vest_outline_pts, vest_outline)
	visuals.draw_polygon(vest_points, vest_colors)
	
	# 조끼 주머니 디테일 (작은 사각형들)
	visuals.draw_rect(Rect2(Vector2(2, 3), Vector2(6, 4)), Color(0.15, 0.25, 0.15))
	visuals.draw_rect(Rect2(Vector2(2, -7), Vector2(6, 4)), Color(0.15, 0.25, 0.15))
	
	# --- 2. 머리 (헬멧 또는 각진 실루엣) ---
	var head_radius = 8.0
	visuals.draw_circle(Vector2(2, 0), head_radius + 1.5, Color.BLACK)
	visuals.draw_circle(Vector2(2, 0), head_radius, skin_color)
	
	# 모자(야구모자 챙) 또는 헬멧 앞부분
	var hat_pts = PackedVector2Array([
		Vector2(2, -7), Vector2(2, 7), Vector2(12, 5), Vector2(12, -5)
	])
	visuals.draw_polygon(hat_pts, PackedColorArray([Color(0.15, 0.15, 0.15), Color(0.15, 0.15, 0.15), Color(0.15, 0.15, 0.15), Color(0.15, 0.15, 0.15)]))

	# --- 3. 팔과 무기 ---
	var weapon_recoil_pos = Vector2(-recoil_offset, 0)
	
	# 오른팔 (무기 방아쇠 쪽)
	var right_shoulder = Vector2(0, 10)
	var right_hand = Vector2(12, 6) + weapon_recoil_pos
	visuals.draw_line(right_shoulder, right_hand, Color(0.25, 0.35, 0.25), 5.0)
	visuals.draw_circle(right_hand, 3.5, skin_color) # 오른손
	
	# 왼팔 (총열 쪽)
	var left_shoulder = Vector2(2, -10)
	var left_hand = Vector2(18, 0) + weapon_recoil_pos
	visuals.draw_line(left_shoulder, left_hand, Color(0.25, 0.35, 0.25), 5.0)
	visuals.draw_circle(left_hand, 3.5, skin_color) # 왼손
	
	# 무기 (소총/권총 형태를 다각형으로 조합)
	# 권총 손잡이
	visuals.draw_rect(Rect2(right_hand + Vector2(-2, -2), Vector2(4, 6)), Color(0.1, 0.1, 0.1))
	# 총열 (앞으로 길게)
	var barrel_rect = Rect2(right_hand + Vector2(2, -3), Vector2(14, 4))
	visuals.draw_rect(barrel_rect, Color(0.15, 0.15, 0.15))
	
	# --- 4. 총구 화염 스파크 ---
	if muzzle_flash_timer > 0.0:
		var flash_tip = right_hand + Vector2(16, -1)
		var flash_poly = PackedVector2Array([
			flash_tip + Vector2(0, -3),
			flash_tip + Vector2(8, 0),
			flash_tip + Vector2(0, 3),
			flash_tip + Vector2(12, 0) # 더 길게 뻗는 섬광
		])
		visuals.draw_polygon(flash_poly, PackedColorArray([
			Color(1.0, 0.9, 0.3, 0.9), Color(1.0, 0.7, 0.1, 0.8), 
			Color(1.0, 0.9, 0.3, 0.9), Color(1.0, 0.5, 0.1, 0.8)
		]))
