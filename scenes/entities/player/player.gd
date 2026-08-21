# res://scenes/entities/player/player.gd
extends CharacterBody2D

@export var walk_speed: float = 125.0
@export var sprint_speed: float = 185.0
@export var crouch_speed: float = 75.0

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
var is_exhausted: bool = false
var is_running: bool = false

# 상호작용 관련
var interactable_tile_pos: Vector2i = Vector2i(-1, -1)
var interactable_type: Vector2i = Vector2i(-1, -1)
var interact_cooldown: float = 0.0
var vault_timer: float = 0.0
const VAULT_DURATION: float = 1.0

# 무기, 모딩 및 전투
const BulletScene = preload("res://scenes/entities/projectiles/bullet.tscn")
var equipped_weapon: String = "권총"
var equipped_weapon_data: Dictionary = {}
var attack_cooldown_timer: float = 0.0
var weapon_fire_rate: float = 0.35
var recoil_offset: float = 0.0
var is_aiming_ads: bool = false
var is_reloading: bool = false
var reload_timer: float = 0.0

var footstep_noise_timer: float = 0.0

signal stats_changed
signal interact_prompt(show: bool, text: String)
signal object_interacted(world_pos: Vector2, tile_pos: Vector2i, type: Vector2i)

# 조명 관련
var flashlight: PointLight2D
var ambient_light: PointLight2D
var muzzle_light: PointLight2D
var flashlight_enabled: bool = true
var muzzle_flash_timer: float = 0.0

# 카메라 및 피격 셰이크
var base_camera_pos: Vector2 = Vector2.ZERO
var target_cam_offset: Vector2 = Vector2.ZERO
var shake_intensity: float = 0.0
var shake_timer: float = 0.0
var hit_flash_tween: Tween
var walk_bob: float = 0.0

var inventory: Inventory = null

func _ready() -> void:
	add_to_group("player")
	_setup_lighting()
	
	# 기본 조립 무기 초기화
	if equipped_weapon_data.is_empty():
		equipped_weapon_data = WeaponPartsDatabase.create_default_weapon("M9_리시버")
	
	if has_node("Camera2D"):
		base_camera_pos = get_node("Camera2D").position
		
	if EventBus.has_signal("player_damaged"):
		EventBus.player_damaged.connect(_on_player_damaged)
	if EventBus.has_signal("camera_shake_requested"):
		EventBus.camera_shake_requested.connect(_on_camera_shake_requested)
		
	if has_node("Visuals"):
		get_node("Visuals").draw.connect(_on_visuals_draw)

func _process(delta: float) -> void:
	# 걷기 흔들림 (Walk Bobbing)
	if velocity.length() > 10.0:
		walk_bob += delta * 12.0
	else:
		walk_bob = lerp(walk_bob, 0.0, delta * 10.0)
		
	# 총구 화염 발광 감쇠
	if muzzle_flash_timer > 0.0:
		muzzle_flash_timer -= delta
		if muzzle_flash_timer <= 0.0 and muzzle_light:
			muzzle_light.enabled = false
			muzzle_light.energy = 0.0
			
	if has_node("Visuals"):
		get_node("Visuals").queue_redraw()

func _physics_process(delta: float) -> void:
	# 이동 및 컨트롤
	_handle_movement(delta)
	
	# 발소리 소음 (달리기 중 주기적 발생)
	if is_running and velocity.length() > 20.0:
		footstep_noise_timer -= delta
		if footstep_noise_timer <= 0:
			footstep_noise_timer = 0.35
			EventBus.noise_created.emit(global_position, 150.0, "footstep")
	
	# 공격 및 줌 제어
	_handle_combat(delta)
	
	# 반동 회복
	recoil_offset = lerp(recoil_offset, 0.0, delta * 15.0)
	
	# 상호작용 검출
	_update_interaction()
	
	# 생존 스탯 업데이트
	_handle_survival_stats(delta)
	
	# 카메라 셰이크
	if shake_timer > 0:
		shake_timer -= delta
		if has_node("Camera2D"):
			var cam = get_node("Camera2D")
			cam.position = base_camera_pos + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_intensity * (shake_timer / 0.5)
	else:
		if has_node("Camera2D") and not is_aiming_ads:
			get_node("Camera2D").position = base_camera_pos

func _unhandled_input(event: InputEvent) -> void:
	# F 키 손전등 ON/OFF 토글
	if event.is_action_pressed("flashlight") or (event is InputEventKey and event.physical_keycode == KEY_F and event.pressed and not event.echo):
		set_flashlight(not flashlight_enabled)
		if SoundManager: SoundManager.play("menu_select")
		get_viewport().set_input_as_handled()
		
	# R 키 재장전
	if event is InputEventKey and event.physical_keycode == KEY_R and event.pressed and not event.echo:
		if not is_reloading:
			_start_reload()
		get_viewport().set_input_as_handled()

func _handle_movement(delta: float) -> void:
	var mouse_pos = get_global_mouse_position()
	rotation = global_position.direction_to(mouse_pos).angle()
	
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
	
	if stamina <= 0.0:
		is_exhausted = true
	elif is_exhausted and stamina >= 25.0:
		is_exhausted = false
		
	var current_speed = walk_speed
	is_running = false
	
	if wants_sprint and input_dir != Vector2.ZERO and not is_exhausted and stamina > 5.0 and not is_fractured:
		current_speed = sprint_speed
		is_running = true
		stamina -= 25.0 * delta
	elif is_crouching:
		current_speed = crouch_speed
		_regen_stamina(delta, 1.5)
	else:
		_regen_stamina(delta, 1.0)
	
	if is_fractured:
		current_speed *= 0.5
		
	stamina = clamp(stamina, 0.0, max_stamina)
	velocity = input_dir * current_speed
	move_and_slide()

func _regen_stamina(delta: float, multiplier: float) -> void:
	if hunger > 20.0 and thirst > 20.0:
		stamina += 10.0 * multiplier * delta

func _handle_survival_stats(delta: float) -> void:
	hunger -= 0.15 * delta
	thirst -= 0.25 * delta
	
	if is_bleeding:
		hp -= 1.0 * delta
	if is_infected:
		hp -= 0.5 * delta
	if hunger <= 0: hp -= 0.5 * delta
	if thirst <= 0: hp -= 1.0 * delta
	
	hunger = clamp(hunger, 0.0, max_hunger)
	thirst = clamp(thirst, 0.0, max_thirst)
	hp = clamp(hp, 0.0, max_hp)
	
	if hp <= 0:
		_die()
		
	stats_changed.emit()

func _handle_combat(delta: float) -> void:
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0:
			_finish_reload()
			
	var right_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	is_aiming_ads = right_pressed and not get_tree().paused
	
	_update_camera_zoom(delta)
	
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
		
	if Input.is_action_just_pressed("attack") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if get_tree().paused: return
		_try_attack()

func _update_camera_zoom(delta: float) -> void:
	var cam = get_node_or_null("Camera2D")
	if not cam: return
	
	var zoom_factor = 1.0
	var has_telescope = false
	var telescope_mult = 1.0
	
	if inventory:
		for it in inventory.items:
			if it and it["id"] == "고배율_망원경":
				has_telescope = true
				telescope_mult = 10.0
				break
			elif it and it["id"] == "망원경":
				has_telescope = true
				telescope_mult = 5.0
				
	var scope_zoom = 1.0
	if not equipped_weapon_data.is_empty():
		var stats = equipped_weapon_data.get("computed_stats", {})
		scope_zoom = stats.get("zoom", 1.0)
		
	if is_aiming_ads:
		zoom_factor = max(scope_zoom, telescope_mult if has_telescope else 1.0)
		
	var target_zoom_val = 1.0 / sqrt(zoom_factor)
	var target_zoom = Vector2(target_zoom_val, target_zoom_val)
	
	if is_aiming_ads and zoom_factor > 1.0:
		var mouse_offset = get_global_mouse_position() - global_position
		target_cam_offset = mouse_offset.limit_length(180.0 * (zoom_factor / 2.0))
	else:
		target_cam_offset = Vector2.ZERO
		
	cam.zoom = cam.zoom.lerp(target_zoom, delta * 6.0)
	cam.position = cam.position.lerp(base_camera_pos + target_cam_offset, delta * 6.0)

func _get_compatible_ammo_type() -> String:
	if not equipped_weapon_data.is_empty():
		return equipped_weapon_data.get("loaded_ammo", "9mm")
	return "탄약"

func _get_available_ammo_count() -> int:
	if not inventory: return 0
	var ammo_id = _get_compatible_ammo_type()
	var count = 0
	for it in inventory.items:
		if it and (it["id"] == ammo_id or (ammo_id == "9mm" and it["id"] == "탄약")):
			count += it["amount"]
	return count

func _start_reload() -> void:
	if equipped_weapon_data.is_empty(): return
	var stats = equipped_weapon_data.get("computed_stats", {})
	var mag_size = stats.get("magazine_size", 15)
	var cur_mag = equipped_weapon_data.get("current_magazine_ammo", 0)
	
	if cur_mag >= mag_size: return
	var avail = _get_available_ammo_count()
	if avail <= 0:
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("⚠️ [%s] 호환 탄약이 없습니다!" % _get_compatible_ammo_type())
		return
		
	is_reloading = true
	reload_timer = stats.get("reload_speed", 1.8)
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("🔄 재장전 중... (%.1f초)" % reload_timer)
	if SoundManager: SoundManager.play("menu_select")

func _finish_reload() -> void:
	is_reloading = false
	if equipped_weapon_data.is_empty() or not inventory: return
	
	var stats = equipped_weapon_data.get("computed_stats", {})
	var mag_size = stats.get("magazine_size", 15)
	var cur_mag = equipped_weapon_data.get("current_magazine_ammo", 0)
	var needed = mag_size - cur_mag
	var ammo_id = _get_compatible_ammo_type()
	
	var loaded = 0
	for i in range(inventory.max_slots):
		var it = inventory.items[i]
		if it and (it["id"] == ammo_id or (ammo_id == "9mm" and it["id"] == "탄약")):
			var take = min(needed - loaded, it["amount"])
			it["amount"] -= take
			loaded += take
			if it["amount"] <= 0:
				inventory.items[i] = null
			if loaded >= needed:
				break
				
	equipped_weapon_data["current_magazine_ammo"] = cur_mag + loaded
	inventory.inventory_changed.emit()
	stats_changed.emit()
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("✅ 재장전 완료! (%d/%d)" % [equipped_weapon_data["current_magazine_ammo"], mag_size])

func _try_attack() -> void:
	if attack_cooldown_timer > 0 or is_reloading: return
	
	if equipped_weapon_data.is_empty():
		equipped_weapon_data = WeaponPartsDatabase.create_default_weapon("M9_리시버")
		
	var stats = equipped_weapon_data.get("computed_stats", {})
	var rpm = stats.get("rpm", 150)
	attack_cooldown_timer = 60.0 / float(rpm)
	
	var cur_mag = equipped_weapon_data.get("current_magazine_ammo", 0)
	if cur_mag <= 0:
		_start_reload()
		return
		
	equipped_weapon_data["current_magazine_ammo"] = cur_mag - 1
	stats_changed.emit()
	
	var aim_dir = Vector2.RIGHT.rotated(rotation)
	var spawn_pos = global_position + aim_dir * 20.0
	
	var recoil_val = stats.get("recoil", 20.0)
	recoil_offset = recoil_val * 0.2
	
	if stats.get("muzzle_flash", true):
		muzzle_flash_timer = 0.06
		if muzzle_light:
			muzzle_light.enabled = true
			muzzle_light.energy = 1.4
			
	var ps = get_tree().current_scene.get_node_or_null("ParticleSystem")
	if ps:
		ps.emit("muzzle", spawn_pos.x, spawn_pos.y, 4, rotation)
		ps.emit("bullet_shell", spawn_pos.x, spawn_pos.y, 1, rotation)
		
	var noise_rad = stats.get("noise_radius", 600.0)
	EventBus.noise_created.emit(global_position, noise_rad, "gunshot")
	
	var pellets = stats.get("pellets", 1)
	var dmg_per_pellet = stats.get("damage", 20.0)
	var accuracy = stats.get("accuracy", 75.0)
	var spread_max = deg_to_rad(max(1.0, (100.0 - accuracy) * 0.35))
	
	for p in range(pellets):
		var spread = randf_range(-spread_max, spread_max)
		var pellet_dir = aim_dir.rotated(spread)
		var bullet = BulletScene.instantiate()
		get_parent().add_child(bullet)
		bullet.setup(spawn_pos, pellet_dir, dmg_per_pellet)
		
	if SoundManager: SoundManager.play("hit_ranged")

func _update_interaction() -> void:
	if interact_cooldown > 0:
		interact_cooldown -= get_process_delta_time()
		
	var interact_dist = 32.0
	var check_pos = global_position + Vector2.RIGHT.rotated(rotation) * interact_dist
	
	var object_layer: TileMapLayer = null
	var chunk_manager = get_node_or_null("/root/MainWorld/ChunkManager")
	if chunk_manager and chunk_manager.object_layer:
		object_layer = chunk_manager.object_layer
	else:
		var cur_scene = get_tree().current_scene
		if cur_scene and cur_scene.has_node("ObjectsLayer"):
			object_layer = cur_scene.get_node("ObjectsLayer")
		elif get_parent() and get_parent().get_parent() and get_parent().get_parent().has_node("ObjectsLayer"):
			object_layer = get_parent().get_parent().get_node("ObjectsLayer")
	
	interactable_type = Vector2i(-1, -1)
	interactable_tile_pos = Vector2i(-1, -1)
	var can_interact = false
	var prompt_text = ""
	
	# 엔티티 상호작용
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = check_pos
	query.collision_mask = 1 | 2
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
				if object_layer:
					interactable_tile_pos = object_layer.local_to_map(collider.global_position)
				else:
					interactable_tile_pos = Vector2i(int(collider.global_position.x / 32), int(collider.global_position.y / 32))
				found_entity = true
				break
				
	# 타일맵 상호작용
	if not found_entity and object_layer:
		var t_pos = object_layer.local_to_map(check_pos)
		var tile_coords = object_layer.get_cell_atlas_coords(t_pos)
		
		if tile_coords == Vector2i(3, 1):
			can_interact = true
			prompt_text = "[E] 수색하기"
		elif tile_coords == Vector2i(4, 1):
			can_interact = true
			prompt_text = "[E] 가구 수색하기"
		elif tile_coords == Vector2i(5, 1):
			can_interact = true
			prompt_text = "[E] 잔해물 뒤지기"
		elif tile_coords == Vector2i(6, 1):
			can_interact = true
			prompt_text = "[E] 문 열기"
		elif tile_coords == Vector2i(7, 1):
			can_interact = true
			prompt_text = "[E] 문 닫기"
		elif tile_coords == Vector2i(1, 2):
			can_interact = true
			prompt_text = "[E] 창문 깨기"
		elif tile_coords == Vector2i(2, 2):
			can_interact = true
			prompt_text = "[E 꾹 누르기] 창문 넘어가기"
		elif tile_coords == Vector2i(5, 2):
			can_interact = true
			prompt_text = "[E] 조명 스위치 작동"
			
		if can_interact:
			interactable_tile_pos = t_pos
			interactable_type = tile_coords
	
	# 창문 넘어가기(Vaulting) 홀드 처리
	if can_interact and interactable_type == Vector2i(2, 2):
		if Input.is_physical_key_pressed(KEY_E) or Input.is_action_pressed("interact"):
			vault_timer += get_process_delta_time()
			queue_redraw()
			if vault_timer >= VAULT_DURATION:
				# 창문 타일 너머 반대편으로 플레이어 도약 이동
				var fwd = Vector2.RIGHT.rotated(rotation)
				global_position += fwd * 44.0
				vault_timer = 0.0
				interact_cooldown = 0.4
				queue_redraw()
				EventBus.noise_created.emit(global_position, 120.0, "vault")
				EventBus.event_logged.emit("🏃 창문을 뛰어넘었습니다.")
				if SoundManager: SoundManager.play("footstep")
				return
		else:
			if vault_timer > 0:
				vault_timer = 0.0
				queue_redraw()
	else:
		if vault_timer > 0:
			vault_timer = 0.0
			queue_redraw()
	
	interact_prompt.emit(can_interact, prompt_text)
	
	if can_interact and interact_cooldown <= 0.0 and interactable_type != Vector2i(2, 2):
		if Input.is_physical_key_pressed(KEY_E) or Input.is_action_just_pressed("interact"):
			interact_cooldown = 0.35
			object_interacted.emit(check_pos, interactable_tile_pos, interactable_type)

func _setup_lighting() -> void:
	ambient_light = PointLight2D.new()
	ambient_light.name = "AmbientLight"
	ambient_light.texture = _create_directional_ambient_texture(160, 0.6, 0.05)
	ambient_light.color = Color(1.0, 0.95, 0.8)
	ambient_light.energy = 0.85
	add_child(ambient_light)
	
	flashlight = PointLight2D.new()
	flashlight.name = "Flashlight"
	flashlight.texture = _create_flashlight_cone_texture(360, 260, 60.0)
	flashlight.offset = Vector2(180, 0)
	flashlight.color = Color(1.0, 0.98, 0.9)
	flashlight.energy = 1.6
	flashlight.shadow_enabled = true
	flashlight.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	add_child(flashlight)
	
	muzzle_light = PointLight2D.new()
	muzzle_light.name = "MuzzleLight"
	muzzle_light.texture = _create_flashlight_cone_texture(240, 180, 100.0)
	muzzle_light.offset = Vector2(120, 0)
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
		ambient_light.energy = 0.85 if flashlight_enabled else 0.15

func _create_directional_ambient_texture(size: int, front_alpha: float, back_alpha: float) -> ImageTexture:
	var img = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center = size / 2.0
	
	for y in range(size):
		for x in range(size):
			var dx = x - center
			var dy = y - center
			var dist = sqrt(dx * dx + dy * dy)
			
			if dist > center:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
				
			var dist_factor = pow(1.0 - (dist / center), 1.4)
			var angle = atan2(dy, dx)
			var forward_bias = (cos(angle) + 1.0) / 2.0
			var alpha_target = lerp(back_alpha, front_alpha, forward_bias)
			var alpha = clamp(dist_factor * alpha_target, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
			
	return ImageTexture.create_from_image(img)

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
				
			var dist_factor = pow(1.0 - (dist / max_dist), 1.5)
			var angle_factor = cos((angle / half_angle_rad) * (PI / 2.0))
			var alpha = clamp(dist_factor * angle_factor, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
			
	return ImageTexture.create_from_image(img)

func _on_camera_shake_requested(intensity: float, duration: float) -> void:
	shake_intensity = intensity
	shake_timer = duration

func _on_player_damaged(amount: float, source: String) -> void:
	hp -= amount
	if source == "zombie" and randf() < 0.3:
		is_infected = true
	elif source == "gunfire" and randf() < 0.5:
		is_bleeding = true
		
	_play_hit_flash()
	_on_camera_shake_requested(8.0, 0.3)

func _play_hit_flash() -> void:
	var visuals = get_node_or_null("Visuals")
	if visuals and visuals.material:
		if hit_flash_tween:
			hit_flash_tween.kill()
		hit_flash_tween = create_tween()
		visuals.material.set_shader_parameter("flash_color", Color(1, 0, 0, 1))
		visuals.material.set_shader_parameter("flash_modifier", 1.0)
		hit_flash_tween.tween_property(visuals.material, "shader_parameter/flash_modifier", 0.0, 0.2)

func _die() -> void:
	EventBus.player_died.emit()

func _on_visuals_draw() -> void:
	var visuals = get_node("Visuals")
	
	var bob_y = sin(walk_bob * 2.0) * 2.0
	var bob_rot = sin(walk_bob) * 0.1
	visuals.position = Vector2(0, bob_y)
	visuals.rotation = bob_rot
	
	var skin_color = Color(0.9, 0.8, 0.7)
	
	# 1. 방탄 조끼 / 상체
	var vest_points = PackedVector2Array([
		Vector2(-10, -12), Vector2(-10, 12),
		Vector2(2, 14), Vector2(12, 8),
		Vector2(12, -8), Vector2(2, -14)
	])
	
	var vest_colors = PackedColorArray()
	var vest_outline = PackedColorArray()
	for p in vest_points:
		vest_colors.append(Color(0.2, 0.3, 0.2))
		vest_outline.append(Color(0.1, 0.1, 0.1))
		
	var vest_outline_pts = PackedVector2Array()
	for p in vest_points:
		vest_outline_pts.append(p * 1.15)
		
	visuals.draw_polygon(vest_outline_pts, vest_outline)
	visuals.draw_polygon(vest_points, vest_colors)
	
	visuals.draw_rect(Rect2(Vector2(2, 3), Vector2(6, 4)), Color(0.15, 0.25, 0.15))
	visuals.draw_rect(Rect2(Vector2(2, -7), Vector2(6, 4)), Color(0.15, 0.25, 0.15))
	
	# 2. 머리
	var head_radius = 8.0
	visuals.draw_circle(Vector2(2, 0), head_radius + 1.5, Color.BLACK)
	visuals.draw_circle(Vector2(2, 0), head_radius, skin_color)
	
	var hat_pts = PackedVector2Array([
		Vector2(2, -7), Vector2(2, 7), Vector2(12, 5), Vector2(12, -5)
	])
	visuals.draw_polygon(hat_pts, PackedColorArray([Color(0.15, 0.15, 0.15), Color(0.15, 0.15, 0.15), Color(0.15, 0.15, 0.15), Color(0.15, 0.15, 0.15)]))

	# 3. 팔과 무기
	var weapon_recoil_pos = Vector2(-recoil_offset, 0)
	var right_shoulder = Vector2(0, 10)
	var right_hand = Vector2(12, 6) + weapon_recoil_pos
	visuals.draw_line(right_shoulder, right_hand, Color(0.25, 0.35, 0.25), 5.0)
	visuals.draw_circle(right_hand, 3.5, skin_color)
	
	var left_shoulder = Vector2(2, -10)
	var left_hand = Vector2(18, 0) + weapon_recoil_pos
	visuals.draw_line(left_shoulder, left_hand, Color(0.25, 0.35, 0.25), 5.0)
	visuals.draw_circle(left_hand, 3.5, skin_color)
	
	visuals.draw_rect(Rect2(right_hand + Vector2(-2, -2), Vector2(4, 6)), Color(0.1, 0.1, 0.1))
	var barrel_rect = Rect2(right_hand + Vector2(2, -3), Vector2(14, 4))
	visuals.draw_rect(barrel_rect, Color(0.15, 0.15, 0.15))
	
	# 4. 총구 화염
	if muzzle_flash_timer > 0.0:
		var flash_tip = right_hand + Vector2(16, -1)
		var flash_poly = PackedVector2Array([
			flash_tip + Vector2(0, -3), flash_tip + Vector2(8, 0),
			flash_tip + Vector2(0, 3), flash_tip + Vector2(12, 0)
		])
		visuals.draw_polygon(flash_poly, PackedColorArray([
			Color(1.0, 0.9, 0.3, 0.9), Color(1.0, 0.7, 0.1, 0.8), 
			Color(1.0, 0.9, 0.3, 0.9), Color(1.0, 0.5, 0.1, 0.8)
		]))

	# 5. 레이저 사이트 빔
	if not equipped_weapon_data.is_empty():
		var stats = equipped_weapon_data.get("computed_stats", {})
		if stats.get("laser_sight", false):
			var laser_start = right_hand + Vector2(16, -1)
			var laser_end = laser_start + Vector2(350, 0)
			visuals.draw_line(laser_start, laser_end, Color(1.0, 0.15, 0.15, 0.65), 1.2)
			visuals.draw_circle(laser_end, 2.5, Color(1.0, 0.25, 0.25, 0.9))

	# 6. 창문 넘어가기(Vaulting) 프로그레스 바
	if vault_timer > 0.0:
		var ratio = clamp(vault_timer / VAULT_DURATION, 0.0, 1.0)
		var bar_w = 36.0
		var bar_h = 5.0
		var bar_pos = Vector2(-bar_w / 2.0, -26.0)
		
		# 배경
		visuals.draw_rect(Rect2(bar_pos + Vector2(-1, -1), Vector2(bar_w + 2, bar_h + 2)), Color(0, 0, 0, 0.8))
		# 채우기 게이지 (노란색 -> 녹색)
		var fill_color = Color(1.0, 0.8, 0.2).lerp(Color(0.2, 0.9, 0.3), ratio)
		visuals.draw_rect(Rect2(bar_pos, Vector2(bar_w * ratio, bar_h)), fill_color)
