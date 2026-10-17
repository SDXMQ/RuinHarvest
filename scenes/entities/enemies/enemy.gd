# res://scenes/entities/enemies/enemy.gd
extends CharacterBody2D

enum EnemyType { ZOMBIE, RUNNER, TANK, SCAV, RAIDER }
enum State { IDLE, WANDER, CHASE, ATTACK, INVESTIGATE, HURT, DEAD }

const BulletScene = preload("res://scenes/entities/projectiles/bullet.tscn")
const GroundItemScene = preload("res://scenes/entities/items/ground_item.tscn")

@export var enemy_type: EnemyType = EnemyType.ZOMBIE

var max_hp: float = 40.0
var hp: float = 40.0
var speed: float = 75.0
var damage: float = 12.0
var attack_cooldown: float = 1.0
var attack_timer: float = 0.0

var current_state: State = State.IDLE
var target_player: CharacterBody2D = null
var detection_radius: float = 240.0
var attack_radius: float = 28.0

var is_ranged_human: bool = false
var mag_ammo: int = 8
var max_mag_ammo: int = 8
var reload_timer: float = 0.0
var strafe_sign: float = 1.0
var strafe_change_timer: float = 0.0

var wander_dir: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO
var hit_flash_tween: Tween

# 소음 및 느낌표 시스템
var target_noise_pos: Vector2 = Vector2.ZERO
var investigate_timer: float = 0.0
var alert_timer: float = 0.0
var alert_icon_type: String = "!" # "!" or "?"

func _ready() -> void:
	add_to_group("enemies")
	_setup_stats_by_type()
	if has_node("Visuals"):
		get_node("Visuals").draw.connect(_on_visuals_draw)
	
	if EventBus.has_signal("noise_created"):
		EventBus.noise_created.connect(_on_noise_created)

func _exit_tree() -> void:
	if EventBus and EventBus.noise_created.is_connected(_on_noise_created):
		EventBus.noise_created.disconnect(_on_noise_created)

func _setup_stats_by_type() -> void:
	is_ranged_human = false
	match enemy_type:
		EnemyType.ZOMBIE:
			max_hp = 40.0
			speed = 70.0
			damage = 12.0
			detection_radius = 240.0
			attack_radius = 28.0
		EnemyType.RUNNER:
			max_hp = 25.0
			speed = 135.0
			damage = 8.0
			detection_radius = 260.0
			attack_radius = 26.0
		EnemyType.TANK:
			max_hp = 120.0
			speed = 45.0
			damage = 25.0
			detection_radius = 220.0
			attack_radius = 34.0
		EnemyType.SCAV:
			is_ranged_human = true
			max_hp = 55.0
			speed = 82.0
			damage = 10.0
			attack_cooldown = 0.85
			detection_radius = 310.0
			attack_radius = 230.0
			max_mag_ammo = 8
			mag_ammo = 8
		EnemyType.RAIDER:
			is_ranged_human = true
			max_hp = 95.0
			speed = 94.0
			damage = 14.0
			attack_cooldown = 0.42
			detection_radius = 360.0
			attack_radius = 290.0
			max_mag_ammo = 15
			mag_ammo = 15
	hp = max_hp
	strafe_sign = 1.0 if randf() > 0.5 else -1.0

func _on_noise_created(pos: Vector2, radius: float, source_type: String) -> void:
	if hp <= 0:
		return
	var dist = global_position.distance_to(pos)
	if dist <= radius:
		alert_to_position(pos, source_type)

func alert_to_position(pos: Vector2, source_type: String = "") -> void:
	if hp <= 0 or current_state == State.CHASE:
		return
	target_noise_pos = pos
	current_state = State.INVESTIGATE
	investigate_timer = randf_range(4.0, 7.0)
	alert_timer = 2.0
	alert_icon_type = "!" if (source_type == "gunshot" or source_type == "break" or source_type == "explosion") else "?"
	if has_node("Visuals"):
		get_node("Visuals").queue_redraw()

func _has_line_of_sight(target_pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var ray_query = PhysicsRayQueryParameters2D.new()
	ray_query.from = global_position
	ray_query.to = target_pos
	ray_query.exclude = [self]
	if is_instance_valid(target_player):
		ray_query.exclude.append(target_player)
	ray_query.collision_mask = 1
	var res = space_state.intersect_ray(ray_query)
	return res.is_empty()

func _physics_process(delta: float) -> void:
	if hp <= 0:
		return
		
	if reload_timer > 0:
		reload_timer -= delta
		if reload_timer <= 0:
			mag_ammo = max_mag_ammo
		if has_node("Visuals"):
			get_node("Visuals").queue_redraw()
		
	# 느낌표 타이머 감소
	if alert_timer > 0:
		alert_timer -= delta
		if alert_timer <= 0 and has_node("Visuals"):
			get_node("Visuals").queue_redraw()
		
	# 플레이어 탐색
	if not is_instance_valid(target_player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target_player = players[0]
			
	attack_timer -= delta
	strafe_change_timer -= delta
	if strafe_change_timer <= 0:
		strafe_change_timer = randf_range(1.2, 2.6)
		strafe_sign = -strafe_sign
	
	# 넉백 감쇠
	if knockback_velocity.length() > 5.0:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 500.0 * delta)
		velocity = knockback_velocity
		move_and_slide()
		return
		
	if is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		
		# 감지 범위 내 진입 시 추적
		if dist <= detection_radius:
			if current_state != State.CHASE:
				alert_timer = 2.0
				alert_icon_type = "!"
				if has_node("Visuals"):
					get_node("Visuals").queue_redraw()
			current_state = State.CHASE
		elif current_state == State.CHASE and dist > detection_radius * 1.5:
			current_state = State.IDLE
			
		match current_state:
			State.IDLE:
				velocity = Vector2.ZERO
				wander_timer -= delta
				if wander_timer <= 0:
					wander_timer = randf_range(2.0, 5.0)
					if randf() > 0.5:
						current_state = State.WANDER
						wander_dir = Vector2.RIGHT.rotated(randf() * TAU)
			State.WANDER:
				wander_timer -= delta
				velocity = wander_dir * (speed * 0.4)
				rotation = wander_dir.angle()
				if wander_timer <= 0:
					current_state = State.IDLE
					wander_timer = randf_range(1.0, 3.0)
			State.INVESTIGATE:
				investigate_timer -= delta
				var steer_dir = _get_steered_direction(target_noise_pos)
				rotation = lerp_angle(rotation, steer_dir.angle(), delta * 8.0)
				velocity = steer_dir * (speed * 0.7)
				if global_position.distance_to(target_noise_pos) < 24.0 or investigate_timer <= 0:
					current_state = State.IDLE
					wander_timer = 2.0
			State.CHASE:
				if is_ranged_human and dist <= attack_radius and _has_line_of_sight(target_player.global_position):
					var dir_to_p = global_position.direction_to(target_player.global_position)
					rotation = lerp_angle(rotation, dir_to_p.angle(), delta * 12.0)
					# 전술 무빙: 너무 가까우면 뒷걸음질, 적정 거리면 좌우 스트레이핑
					if dist < 95.0:
						velocity = (-dir_to_p + dir_to_p.orthogonal() * strafe_sign * 0.5).normalized() * (speed * 0.75)
					else:
						velocity = (dir_to_p.orthogonal() * strafe_sign) * (speed * 0.55)
					_try_attack()
					if has_node("Visuals"):
						get_node("Visuals").queue_redraw()
				elif not is_ranged_human and dist <= attack_radius:
					velocity = Vector2.ZERO
					var dir_to_p = global_position.direction_to(target_player.global_position)
					rotation = dir_to_p.angle()
					_try_attack()
				else:
					# 앞쪽 창문 타일 감지 및 파괴 침입
					var forward_pos = global_position + Vector2.RIGHT.rotated(rotation) * 20.0
					var chunk_mgr = get_node_or_null("/root/MainWorld/ChunkManager")
					if chunk_mgr and chunk_mgr.object_layer:
						var t_pos = chunk_mgr.object_layer.local_to_map(forward_pos)
						if chunk_mgr.object_layer.get_cell_atlas_coords(t_pos) == TileManager.OBJ_WINDOW:
							if attack_timer <= 0:
								chunk_mgr.object_layer.set_cell(t_pos, 0, TileManager.OBJ_WINDOW_BROKEN)
								EventBus.noise_created.emit(forward_pos, 400.0, "break")
								EventBus.window_broken.emit(t_pos)
								EventBus.event_logged.emit("💥 적이 창문을 깨부수고 침입합니다!")
								if SoundManager: SoundManager.play("hit_melee")
								attack_timer = 1.0
					
					var steer_dir = _get_steered_direction(target_player.global_position)
					rotation = lerp_angle(rotation, steer_dir.angle(), delta * 10.0)
					velocity = steer_dir * speed
					
		move_and_slide()
		
		# 걷기 애니메이션 (몸 흔들림) 및 전술 시야(LoS/FoV) 가시성 페이드
		if has_node("Visuals"):
			var visuals = get_node("Visuals")
			if velocity.length() > 5.0:
				var bob = sin(Time.get_ticks_msec() * 0.01 * (speed / 70.0)) * 2.0
				visuals.position.y = bob
			_update_tactical_visibility(delta, dist, visuals)

func _update_tactical_visibility(delta: float, dist: float, visuals: Node2D) -> void:
	if not is_instance_valid(target_player):
		return
	var has_los = _has_line_of_sight(target_player.global_position)
	var p_forward = Vector2.RIGHT.rotated(target_player.rotation)
	var dir_from_p = target_player.global_position.direction_to(global_position)
	var in_fov = p_forward.dot(dir_from_p) >= -0.15 # 약 195도 전방 시야
	
	var target_alpha = 1.0
	if dist <= 90.0:
		target_alpha = 1.0 if has_los else 0.35
	elif not has_los:
		target_alpha = 0.25 if velocity.length() > 15.0 else 0.12
	elif not in_fov and dist > 160.0:
		target_alpha = 0.45
		
	visuals.modulate.a = lerp(visuals.modulate.a, target_alpha, clamp(delta * 10.0, 0.0, 1.0))
	if hp_bar:
		hp_bar.modulate.a = visuals.modulate.a

func _get_steered_direction(target_pos: Vector2) -> Vector2:
	var desired_dir = global_position.direction_to(target_pos)
	var space_state = get_world_2d().direct_space_state
	
	# 8방향 가중치 계산 (Context Steering)
	var num_rays = 8
	var best_dir = desired_dir
	var best_score = -999.0
	
	for i in range(num_rays):
		var angle = (float(i) / float(num_rays)) * TAU
		var dir = Vector2.RIGHT.rotated(angle)
		
		# 플레이어 방향과의 일치도 (Dot product)
		var interest = dir.dot(desired_dir)
		
		# 전방 장애물 레이캐스트
		var ray_query = PhysicsRayQueryParameters2D.new()
		ray_query.from = global_position
		ray_query.to = global_position + dir * 32.0 # 1타일 거리
		ray_query.exclude = [self]
		ray_query.collision_mask = 1 # 벽/오브젝트 레이어
		
		var result = space_state.intersect_ray(ray_query)
		var danger = 0.0
		if not result.is_empty():
			danger = 2.0 # 장애물이 있으면 큰 페널티
			
		var score = interest - danger
		if score > best_score:
			best_score = score
			best_dir = dir
			
	return best_dir

func _try_attack() -> void:
	if attack_timer > 0 or reload_timer > 0:
		return
	if not is_instance_valid(target_player):
		return
		
	if is_ranged_human:
		if mag_ammo <= 0:
			reload_timer = 1.9 if enemy_type == EnemyType.SCAV else 1.5
			return
		mag_ammo -= 1
		attack_timer = attack_cooldown * randf_range(0.85, 1.2)
		
		var aim_dir = global_position.direction_to(target_player.global_position)
		var spread_deg = 7.5 if enemy_type == EnemyType.SCAV else 4.0
		var shot_dir = aim_dir.rotated(deg_to_rad(randf_range(-spread_deg, spread_deg)))
		var muzzle_pos = global_position + aim_dir * 18.0
		
		var bullet = BulletScene.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.setup(muzzle_pos, shot_dir, damage, attack_radius * 1.35, 1, "enemies", 540.0 if enemy_type == EnemyType.SCAV else 640.0)
		
		var ps = get_tree().current_scene.get_node_or_null("ParticleSystem")
		if ps:
			ps.emit("muzzle", muzzle_pos.x, muzzle_pos.y, 3, shot_dir.angle())
		if SoundManager:
			SoundManager.play("hit_ranged")
		EventBus.noise_created.emit(global_position, 450.0, "gunshot")
	else:
		attack_timer = attack_cooldown
		EventBus.player_damaged.emit(damage, "zombie")
		if SoundManager:
			SoundManager.play("hit_melee")

func take_damage(amount: float, hit_dir: Vector2) -> void:
	hp -= amount
	current_state = State.CHASE # 피격 시 즉시 추적 모드
	knockback_velocity = hit_dir.normalized() * (110.0 if is_ranged_human else 180.0)
	
	if has_node("Visuals"):
		get_node("Visuals").queue_redraw()
		_play_hit_flash()
	else:
		queue_redraw()
	
	# 피격 파티클 (피 + 타격 이펙트)
	var ps = get_tree().current_scene.get_node_or_null("ParticleSystem")
	if ps:
		ps.emit("blood", global_position.x, global_position.y, 6)
		ps.emit("hit", global_position.x, global_position.y, 3)
	
	if SoundManager:
		SoundManager.play("hit_melee")
		
	if hp <= 0:
		_die()

func _play_hit_flash() -> void:
	var visuals = get_node_or_null("Visuals")
	if visuals and visuals.material:
		if hit_flash_tween:
			hit_flash_tween.kill()
		hit_flash_tween = create_tween()
		visuals.material.set_shader_parameter("flash_color", Color(1, 1, 1, 1)) # 흰색 플래시
		visuals.material.set_shader_parameter("flash_modifier", 1.0)
		hit_flash_tween.tween_property(visuals.material, "shader_parameter/flash_modifier", 0.0, 0.15)

func _die() -> void:
	if current_state == State.DEAD:
		return
	current_state = State.DEAD
	var type_str = "zombie"
	var faction_str = "infected"
	match enemy_type:
		EnemyType.RUNNER: type_str = "runner"
		EnemyType.TANK: type_str = "tank"
		EnemyType.SCAV:
			type_str = "scav"
			faction_str = "scav"
		EnemyType.RAIDER:
			type_str = "raider"
			faction_str = "raider"
	EventBus.enemy_killed.emit(type_str, faction_str, global_position)
	_spawn_loot_drop()
	queue_free()

func _spawn_loot_drop() -> void:
	if not GroundItemScene or not get_parent():
		return
	var drops: Array = []
	match enemy_type:
		EnemyType.ZOMBIE, EnemyType.RUNNER:
			if randf() < 0.55:
				var pool = [
					{"id": "천", "amount": randi_range(1, 2)},
					{"id": "붕대", "amount": 1},
					{"id": "고철", "amount": 1},
					{"id": "마른 빵", "amount": 1},
					{"id": "9mm", "amount": randi_range(5, 12)}
				]
				drops.append(pool.pick_random())
		EnemyType.TANK:
			var pool = [
				{"id": "구급상자", "amount": 1},
				{"id": "진통제", "amount": 1},
				{"id": "화약", "amount": randi_range(1, 2)},
				{"id": "12게이지_벅샷", "amount": randi_range(4, 8)}
			]
			drops.append(pool.pick_random())
		EnemyType.SCAV:
			var ammo_pool = [
				{"id": "9mm", "amount": randi_range(10, 20)},
				{"id": ".45ACP", "amount": randi_range(8, 16)},
				{"id": "12게이지_벅샷", "amount": randi_range(5, 10)}
			]
			drops.append(ammo_pool.pick_random())
			if randf() < 0.65:
				var gear_pool = [
					{"id": "붕대", "amount": 1},
					{"id": "진통제", "amount": 1},
					{"id": "생수", "amount": 1},
					{"id": "M9_리시버", "amount": 1},
					{"id": "레밍턴_리시버", "amount": 1}
				]
				drops.append(gear_pool.pick_random())
		EnemyType.RAIDER:
			var ammo_pool = [
				{"id": "5.56mm", "amount": randi_range(15, 30)},
				{"id": "7.62mm", "amount": randi_range(15, 30)}
			]
			drops.append(ammo_pool.pick_random())
			var high_pool = [
				{"id": "구급상자", "amount": 1},
				{"id": "고급 치료킷", "amount": 1},
				{"id": "수류탄", "amount": 1},
				{"id": "AK_리시버", "amount": 1},
				{"id": "M4_리시버", "amount": 1},
				{"id": "2레벨_방탄복", "amount": 1},
				{"id": "2레벨_헬멧", "amount": 1}
			]
			drops.append(high_pool.pick_random())
			
	for i in range(drops.size()):
		var d = drops[i]
		var g_item = GroundItemScene.instantiate()
		var offset = Vector2(randf_range(-14, 14), randf_range(-14, 14))
		g_item.global_position = global_position + offset
		get_parent().call_deferred("add_child", g_item)
		g_item.call_deferred("setup", d["id"], d["amount"])

func _on_visuals_draw() -> void:
	var visuals = get_node("Visuals")
	
	# 기본 크기 비례
	var scale_f = 1.0
	if enemy_type == EnemyType.TANK: scale_f = 1.4
	elif enemy_type == EnemyType.RUNNER: scale_f = 0.85
	elif enemy_type == EnemyType.RAIDER: scale_f = 1.08
	
	# 색상 정의
	var body_color = Color(0.3, 0.45, 0.3)
	var cloth_color = Color(0.35, 0.35, 0.4)
	if enemy_type == EnemyType.RUNNER: 
		body_color = Color(0.4, 0.3, 0.3)
		cloth_color = Color(0.4, 0.2, 0.2)
	elif enemy_type == EnemyType.TANK: 
		body_color = Color(0.2, 0.35, 0.25)
		cloth_color = Color(0.2, 0.3, 0.4)
	elif enemy_type == EnemyType.SCAV:
		body_color = Color(0.82, 0.68, 0.55)
		cloth_color = Color(0.45, 0.36, 0.26)
	elif enemy_type == EnemyType.RAIDER:
		body_color = Color(0.78, 0.65, 0.52)
		cloth_color = Color(0.22, 0.28, 0.22)
		
	# --- 1. 좀비 몸통 (구부정한 어깨와 불규칙한 체형을 다각형으로 표현) ---
	var shoulder_width = 14.0 * scale_f
	var body_length = 10.0 * scale_f
	var chest_width = 12.0 * scale_f
	
	# 불규칙한 옷/몸통 다각형 (외곽선용)
	var body_points = PackedVector2Array([
		Vector2(-body_length, -chest_width),  # 등 좌측
		Vector2(-body_length, chest_width),   # 등 우측
		Vector2(0, shoulder_width),           # 우측 어깨
		Vector2(body_length, chest_width*0.8),# 앞가슴 우측
		Vector2(body_length, -chest_width*0.8),# 앞가슴 좌측
		Vector2(0, -shoulder_width)           # 좌측 어깨
	])
	
	var colors_outline = PackedColorArray()
	var colors_cloth = PackedColorArray()
	for i in range(body_points.size()):
		colors_outline.append(Color(0.1, 0.1, 0.1))
		colors_cloth.append(cloth_color)
		
	# 약간 더 크게 외곽선 폴리곤 그리기
	var outline_points = PackedVector2Array()
	for p in body_points:
		outline_points.append(p * 1.15)
	
	visuals.draw_polygon(outline_points, colors_outline)
	visuals.draw_polygon(body_points, colors_cloth)
	
	# --- 2. 찢어진 옷 (다각형 틈새로 피부가 드러남) ---
	var torn_points1 = PackedVector2Array([
		Vector2(body_length*0.5, -shoulder_width*0.6),
		Vector2(0, -shoulder_width*0.8),
		Vector2(body_length*0.2, -shoulder_width*0.4)
	])
	visuals.draw_polygon(torn_points1, PackedColorArray([body_color, body_color, body_color]))
	
	if enemy_type == EnemyType.TANK:
		var torn_points2 = PackedVector2Array([
			Vector2(-body_length*0.5, chest_width*0.5),
			Vector2(-body_length*0.8, chest_width*0.8),
			Vector2(-body_length*0.2, chest_width*0.9)
		])
		visuals.draw_polygon(torn_points2, PackedColorArray([body_color, body_color, body_color]))
		
	# --- 3. 혈흔 (불규칙 다각형 점) ---
	var hp_ratio = hp / max_hp
	if hp_ratio < 0.7:
		var blood1 = PackedVector2Array([Vector2(-4, -4), Vector2(-8, -2), Vector2(-5, 3), Vector2(-2, 0)])
		visuals.draw_polygon(blood1, PackedColorArray([Color(0.5, 0, 0, 0.8), Color(0.5, 0, 0, 0.8), Color(0.5, 0, 0, 0.8), Color(0.5, 0, 0, 0.8)]))
	if hp_ratio < 0.4:
		visuals.draw_polygon(PackedVector2Array([Vector2(4, 5), Vector2(8, 7), Vector2(6, 10), Vector2(2, 8)]), 
			PackedColorArray([Color(0.4, 0, 0, 0.9), Color(0.4, 0, 0, 0.9), Color(0.4, 0, 0, 0.9), Color(0.4, 0, 0, 0.9)]))

	# --- 4. 머리 (약간 타원형 혹은 다각형) ---
	var head_radius_x = 7.0 * scale_f
	var head_radius_y = 8.0 * scale_f
	var head_offset = Vector2(body_length * 0.4, 0)
	
	var head_points = PackedVector2Array()
	var head_colors = PackedColorArray()
	var head_outlines = PackedColorArray()
	var sides = 12
	for i in range(sides):
		var angle = (i / float(sides)) * TAU
		# 앞쪽 주둥이를 살짝 뾰족하게
		var rx = head_radius_x
		if cos(angle) > 0: rx += 2.0 * scale_f * cos(angle)
		var p = head_offset + Vector2(cos(angle) * rx, sin(angle) * head_radius_y)
		head_points.append(p)
		head_colors.append(body_color)
		head_outlines.append(Color(0.1, 0.1, 0.1))
		
	var head_outline_points = PackedVector2Array()
	for p in head_points:
		head_outline_points.append(head_offset + (p - head_offset) * 1.2)
		
	visuals.draw_polygon(head_outline_points, head_outlines)
	visuals.draw_polygon(head_points, head_colors)
	
	var eye_offset = head_offset + Vector2(head_radius_x * 0.5, 0)
	if is_ranged_human:
		# 인간형 적 모자/전술 헬멧 및 방탄 조끼
		if enemy_type == EnemyType.RAIDER:
			visuals.draw_rect(Rect2(Vector2(-6, -10), Vector2(12, 20)), Color(0.15, 0.2, 0.15))
			visuals.draw_circle(head_offset, 7.8 * scale_f, Color(0.22, 0.26, 0.22))
			visuals.draw_rect(Rect2(head_offset + Vector2(2, -5.5), Vector2(4.5, 11.0)), Color(0.1, 0.75, 0.35, 0.9)) # 야간투시경/바이저
		else:
			visuals.draw_arc(head_offset, 6.5 * scale_f, PI * 0.4, PI * 1.6, 10, Color(0.55, 0.18, 0.15), 3.0) # 스캐브 두건/비니
			visuals.draw_circle(eye_offset + Vector2(0, -3.0*scale_f), 1.3*scale_f, Color(0.15, 0.15, 0.15))
			visuals.draw_circle(eye_offset + Vector2(0, 3.0*scale_f), 1.3*scale_f, Color(0.15, 0.15, 0.15))
			
		# 총기 파지 자세 및 총기 렌더링
		var gun_len = 22.0 if enemy_type == EnemyType.RAIDER else 15.0
		visuals.draw_line(Vector2(2, 8), Vector2(12, 4), cloth_color, 4.0)
		visuals.draw_line(Vector2(2, -8), Vector2(14, 1), cloth_color, 4.0)
		visuals.draw_circle(Vector2(12, 4), 2.5, body_color)
		visuals.draw_circle(Vector2(14, 1), 2.5, body_color)
		visuals.draw_line(Vector2(6, 2), Vector2(6 + gun_len, 2), Color(0.14, 0.15, 0.18), 3.2)
		if enemy_type == EnemyType.RAIDER and current_state == State.CHASE and reload_timer <= 0:
			# 정예 레이더 전술 레이저 포인터
			visuals.draw_line(Vector2(6 + gun_len, 2), Vector2(115, 2), Color(1.0, 0.15, 0.15, 0.42), 1.2)
	else:
		# 붉은 눈 (좀비 시선 방향)
		visuals.draw_circle(eye_offset + Vector2(0, -3.5*scale_f), 1.5*scale_f, Color.RED)
		visuals.draw_circle(eye_offset + Vector2(0, 3.5*scale_f), 1.5*scale_f, Color.RED)
		
		# --- 5. 양 팔 (추적 시 손을 뻗음) ---
		var reach = 0.0
		if current_state == State.CHASE: reach = 6.0 * scale_f
		
		var arm_y = shoulder_width * 0.8
		var arm_len = 16.0 * scale_f + reach
		
		var arm_l = PackedVector2Array([
			Vector2(0, arm_y), Vector2(0, arm_y + 4*scale_f), 
			Vector2(arm_len, arm_y + 2*scale_f), Vector2(arm_len, arm_y - 2*scale_f)
		])
		var arm_r = PackedVector2Array([
			Vector2(0, -arm_y), Vector2(0, -arm_y - 4*scale_f), 
			Vector2(arm_len, -arm_y - 2*scale_f), Vector2(arm_len, -arm_y + 2*scale_f)
		])
		
		var arm_colors = PackedColorArray([body_color, body_color, body_color, body_color])
		var arm_outlines = PackedColorArray([Color(0.1, 0.1, 0.1), Color(0.1, 0.1, 0.1), Color(0.1, 0.1, 0.1), Color(0.1, 0.1, 0.1)])
		
		var arm_l_outline = PackedVector2Array()
		for p in arm_l: arm_l_outline.append(p + (p - Vector2(arm_len/2, arm_y))*0.2)
		visuals.draw_polygon(arm_l_outline, arm_outlines)
		visuals.draw_polygon(arm_l, arm_colors)
		
		var arm_r_outline = PackedVector2Array()
		for p in arm_r: arm_r_outline.append(p + (p - Vector2(arm_len/2, -arm_y))*0.2)
		visuals.draw_polygon(arm_r_outline, arm_outlines)
		visuals.draw_polygon(arm_r, arm_colors)
		
		if enemy_type == EnemyType.RUNNER or current_state == State.CHASE:
			visuals.draw_circle(Vector2(arm_len, arm_y), 3.0*scale_f, Color(0.6, 0, 0))
			visuals.draw_circle(Vector2(arm_len, -arm_y), 3.0*scale_f, Color(0.6, 0, 0))
		else:
			visuals.draw_circle(Vector2(arm_len, arm_y), 2.5*scale_f, body_color)
			visuals.draw_circle(Vector2(arm_len, -arm_y), 2.5*scale_f, body_color)
	
	# 재장전 게이지 표시 (인간형 무장 적)
	if is_ranged_human and reload_timer > 0:
		var r_w = 24.0
		var r_pos = Vector2(-r_w / 2.0, -18.0 * scale_f - 16.0)
		visuals.draw_rect(Rect2(r_pos, Vector2(r_w, 3.0)), Color(0.15, 0.15, 0.2, 0.85))
		var r_ratio = clamp(1.0 - (reload_timer / 1.9), 0.0, 1.0)
		visuals.draw_rect(Rect2(r_pos, Vector2(r_w * r_ratio, 3.0)), Color(1.0, 0.85, 0.25))
	
	# HP 바 (피격 시 표시)
	if hp < max_hp and hp > 0:
		var bar_w = 26.0
		var bar_h = 4.0
		var bar_pos = Vector2(-bar_w/2.0, -18.0 * scale_f - 10.0)
		visuals.draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.2, 0.2, 0.2))
		var fill_w = (hp / max_hp) * bar_w
		visuals.draw_rect(Rect2(bar_pos, Vector2(fill_w, bar_h)), Color(0.9, 0.2, 0.2))

	# 느낌표/물음표 경고 아이콘 (소음 감지 또는 플레이어 발견 시)
	if alert_timer > 0:
		var icon_pos = Vector2(0, -22.0 * scale_f - 12.0)
		var icon_col = Color(1.0, 0.2, 0.2) if alert_icon_type == "!" else Color(1.0, 0.8, 0.2)
		# 배경 원 (깜빡임 효과)
		var bg_alpha = clamp(alert_timer, 0.0, 1.0)
		visuals.draw_circle(icon_pos, 8.0, Color(0.1, 0.1, 0.1, 0.8 * bg_alpha))
		visuals.draw_arc(icon_pos, 8.0, 0, TAU, 16, icon_col * Color(1, 1, 1, bg_alpha), 1.5)
		
		if alert_icon_type == "!":
			# 느낌표 막대
			visuals.draw_line(icon_pos + Vector2(0, -4), icon_pos + Vector2(0, 1), icon_col * Color(1, 1, 1, bg_alpha), 2.5)
			# 느낌표 점
			visuals.draw_circle(icon_pos + Vector2(0, 4), 1.2, icon_col * Color(1, 1, 1, bg_alpha))
		else:
			# 물음표 점
			visuals.draw_circle(icon_pos + Vector2(0, 4), 1.2, icon_col * Color(1, 1, 1, bg_alpha))
			# 물음표 곡선
			visuals.draw_arc(icon_pos + Vector2(0, -2), 3.0, -PI, 0, 8, icon_col * Color(1, 1, 1, bg_alpha), 2.0)
			visuals.draw_line(icon_pos + Vector2(3, -2), icon_pos + Vector2(0, 1), icon_col * Color(1, 1, 1, bg_alpha), 2.0)
