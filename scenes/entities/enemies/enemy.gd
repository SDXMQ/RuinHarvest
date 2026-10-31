# res://scenes/entities/enemies/enemy.gd
extends CharacterBody2D

enum EnemyType { ZOMBIE, RUNNER, TANK, SCAV, RAIDER, BOSS }
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
var armor_tier: int = 0
var has_used_medkit: bool = false

var current_state: State = State.IDLE
var target_player: CharacterBody2D = null
var target_entity: Node2D = null
var faction_scan_timer: float = 0.0
var detection_radius: float = 240.0
var attack_radius: float = 28.0

var is_ranged_human: bool = false
var mag_ammo: int = 8
var max_mag_ammo: int = 8
var reload_timer: float = 0.0
var strafe_sign: float = 1.0
var strafe_change_timer: float = 0.0
var boss_burst_remaining: int = 0
var boss_burst_timer: float = 0.0
var boss_grenade_cooldown: float = 4.0
var active_boss_grenades: Array = []

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
	armor_tier = 0
	has_used_medkit = false
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
			armor_tier = 1
			detection_radius = 220.0
			attack_radius = 34.0
		EnemyType.SCAV:
			is_ranged_human = true
			armor_tier = 1
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
			armor_tier = 2
			max_hp = 95.0
			speed = 94.0
			damage = 14.0
			attack_cooldown = 0.42
			detection_radius = 360.0
			attack_radius = 290.0
			max_mag_ammo = 15
			mag_ammo = 15
		EnemyType.BOSS:
			is_ranged_human = true
			armor_tier = 3
			max_hp = 260.0
			speed = 90.0
			damage = 18.0
			attack_cooldown = 0.28
			detection_radius = 420.0
			attack_radius = 330.0
			max_mag_ammo = 30
			mag_ammo = 30
	hp = max_hp
	strafe_sign = 1.0 if randf() > 0.5 else -1.0
	faction_scan_timer = randf_range(0.1, 0.5)

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
	var excl: Array = [self]
	if is_instance_valid(target_player):
		excl.append(target_player)
	if is_instance_valid(target_entity):
		excl.append(target_entity)
	ray_query.exclude = excl
	ray_query.collision_mask = 1
	var res = space_state.intersect_ray(ray_query)
	return res.is_empty()

func _scan_hostile_target() -> Node2D:
	var best_target: Node2D = null
	var best_dist: float = detection_radius
	if is_instance_valid(target_player):
		var p_dist = global_position.distance_to(target_player.global_position)
		if p_dist <= detection_radius:
			best_target = target_player
			best_dist = p_dist
	# AI vs AI 팩션 교전: 인간형 무장 세력(Scav/Raider/Boss) vs 감염체(Zombie/Runner/Tank)
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or not is_instance_valid(node) or node.get("hp") == null or node.hp <= 0:
			continue
		var other_human = bool(node.get("is_ranged_human"))
		if other_human != is_ranged_human:
			var d = global_position.distance_to(node.global_position)
			if d < best_dist:
				best_dist = d
				best_target = node
	return best_target

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
	boss_grenade_cooldown -= delta
	strafe_change_timer -= delta
	if strafe_change_timer <= 0:
		strafe_change_timer = randf_range(1.2, 2.6)
		strafe_sign = -strafe_sign
		
	if active_boss_grenades.size() > 0:
		for gi in range(active_boss_grenades.size() - 1, -1, -1):
			active_boss_grenades[gi]["timer"] -= delta
			if active_boss_grenades[gi]["timer"] <= 0.0:
				var g_info = active_boss_grenades[gi]
				active_boss_grenades.remove_at(gi)
				_detonate_boss_grenade(g_info)
		if has_node("Visuals"):
			get_node("Visuals").queue_redraw()
			
	if enemy_type == EnemyType.BOSS and boss_burst_remaining > 0 and reload_timer <= 0.0:
		boss_burst_timer -= delta
		if boss_burst_timer <= 0.0:
			boss_burst_timer = 0.09
			boss_burst_remaining -= 1
			var burst_t: Node2D = target_entity if is_instance_valid(target_entity) else target_player
			if is_instance_valid(burst_t):
				_fire_ranged_shot(burst_t)
	
	# 인간형 무장 적 응급 치료 (체력 35% 이하 시 1회 자가 회복)
	if is_ranged_human and not has_used_medkit and (hp / max_hp) <= 0.35:
		has_used_medkit = true
		hp = min(max_hp, hp + 35.0)
		alert_timer = 1.5
		alert_icon_type = "?"
		if has_node("Visuals"):
			get_node("Visuals").queue_redraw()
	
	# 넉백 감쇠
	if knockback_velocity.length() > 5.0:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 500.0 * delta)
		velocity = knockback_velocity
		move_and_slide()
		return
		
	var player_dist: float = 9999.0
	if is_instance_valid(target_player):
		player_dist = global_position.distance_to(target_player.global_position)
		
	# AI LOD: 화면 밖 원거리(850px 초과) 엔티티는 무거운 레이캐스트 및 물리 연산 생략
	if player_dist > 850.0:
		if has_node("Visuals"):
			get_node("Visuals").modulate.a = 0.0
		return
		
	faction_scan_timer -= delta
	if faction_scan_timer <= 0.0 or not is_instance_valid(target_entity):
		faction_scan_timer = 0.35
		target_entity = _scan_hostile_target()
		
	var active_target: Node2D = target_entity if is_instance_valid(target_entity) else target_player
	if is_instance_valid(active_target):
		var dist = global_position.distance_to(active_target.global_position)
		
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
				if is_ranged_human and dist <= attack_radius and _has_line_of_sight(active_target.global_position):
					var dir_to_t = global_position.direction_to(active_target.global_position)
					rotation = lerp_angle(rotation, dir_to_t.angle(), delta * 12.0)
					# 전술 무빙: 너무 가까우면 뒷걸음질, 적정 거리면 좌우 스트레이핑
					if dist < 95.0:
						velocity = (-dir_to_t + dir_to_t.orthogonal() * strafe_sign * 0.5).normalized() * (speed * 0.75)
					else:
						velocity = (dir_to_t.orthogonal() * strafe_sign) * (speed * 0.55)
					_try_attack(active_target)
					if has_node("Visuals"):
						get_node("Visuals").queue_redraw()
				elif not is_ranged_human and dist <= attack_radius:
					velocity = Vector2.ZERO
					var dir_to_t = global_position.direction_to(active_target.global_position)
					rotation = dir_to_t.angle()
					_try_attack(active_target)
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
					
					var steer_dir = _get_steered_direction(active_target.global_position)
					rotation = lerp_angle(rotation, steer_dir.angle(), delta * 10.0)
					velocity = steer_dir * speed
					
		move_and_slide()
		
		# 걷기 애니메이션 (몸 흔들림) 및 전술 시야(LoS/FoV) 가시성 마스킹
		if has_node("Visuals"):
			var visuals = get_node("Visuals")
			if velocity.length() > 5.0:
				var bob = sin(Time.get_ticks_msec() * 0.01 * (speed / 70.0)) * 2.0
				visuals.position.y = bob
			_update_tactical_visibility(delta, player_dist, visuals)

func _update_tactical_visibility(delta: float, dist: float, visuals: Node2D) -> void:
	if not is_instance_valid(target_player):
		return
	var has_los = _has_line_of_sight(target_player.global_position)
	if not has_los:
		visuals.modulate.a = lerp(visuals.modulate.a, 0.0, clamp(delta * 14.0, 0.0, 1.0))
		return

	var p_forward = Vector2.RIGHT.rotated(target_player.rotation)
	var dir_from_p = target_player.global_position.direction_to(global_position)
	var dot_p = p_forward.dot(dir_from_p)

	# 어둠/야간 여부 판단
	var is_darkness = false
	var current_scene = get_tree().current_scene
	var day_night = current_scene.get_node_or_null("DayNightModulate") if current_scene else null
	if day_night and day_night is CanvasModulate:
		if day_night.color.v < 0.45:
			is_darkness = true
	elif current_scene and "Interior" in current_scene.name:
		is_darkness = true

	var target_alpha = 0.0

	if is_darkness:
		var flashlight_on = false
		var nvg_on = false
		if target_player.get("player_lighting") != null:
			var pl = target_player.player_lighting
			flashlight_on = bool(pl.flashlight_enabled)
			nvg_on = bool(pl.nvg_enabled)
		elif target_player.get("flashlight_enabled") != null:
			flashlight_on = bool(target_player.flashlight_enabled)
			if target_player.get("nvg_enabled") != null:
				nvg_on = bool(target_player.nvg_enabled)

		# 야간 및 암흑: 손전등 콘(전방 62도 각도 및 340px 거리 이내) 또는 NVG 활성화 또는 근접 35px 이외에는 어둠 속에 완전히 은폐
		var in_nvg = nvg_on and (dot_p >= 0.34 or dist <= 85.0)
		var in_flashlight_cone = flashlight_on and (dist <= 340.0) and (dot_p >= 0.85)
		var in_close_touch = dist <= 35.0

		if in_nvg or in_flashlight_cone or in_close_touch:
			target_alpha = 1.0
		else:
			target_alpha = 0.0
	else:
		# 주간: 140도 전방 시야 (dot >= 0.34) 또는 근접 85px 내 감지 시
		var in_fov = dot_p >= 0.34
		var in_close = dist <= 85.0
		if in_fov or in_close:
			target_alpha = 1.0
		else:
			target_alpha = 0.0

	var prev_a = visuals.modulate.a
	visuals.modulate.a = lerp(visuals.modulate.a, target_alpha, clamp(delta * 14.0, 0.0, 1.0))
	if abs(visuals.modulate.a - prev_a) > 0.01:
		visuals.queue_redraw()

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
		
		# 목표 방향과의 일치도 (Dot product)
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

func _try_attack(victim: Node2D = null) -> void:
	if attack_timer > 0 or reload_timer > 0:
		return
	var target_node: Node2D = victim if is_instance_valid(victim) else target_player
	if not is_instance_valid(target_node):
		return
		
	if is_ranged_human:
		if mag_ammo <= 0:
			boss_burst_remaining = 0
			reload_timer = 1.9 if enemy_type == EnemyType.SCAV else 1.4
			return
		if enemy_type == EnemyType.BOSS:
			var dist_to_v = global_position.distance_to(target_node.global_position)
			if boss_grenade_cooldown <= 0.0 and dist_to_v >= 110.0 and dist_to_v <= 600.0:
				_throw_boss_grenade(target_node.global_position)
				boss_grenade_cooldown = 9.5
				attack_timer = 0.75
				return
			# 보스 특수 패턴 1: 6연발 제압 사격 (Suppressive Burst Fire)
			boss_burst_remaining = 5
			boss_burst_timer = 0.09
			attack_timer = 1.35
			_fire_ranged_shot(target_node)
		else:
			attack_timer = attack_cooldown * randf_range(0.85, 1.2)
			_fire_ranged_shot(target_node)
	else:
		attack_timer = attack_cooldown
		if target_node == target_player:
			EventBus.player_damaged.emit(damage, "zombie")
			if EventBus.has_signal("player_hit_direction"):
				EventBus.player_hit_direction.emit(global_position)
		elif target_node.has_method("take_damage"):
			target_node.take_damage(damage, global_position.direction_to(target_node.global_position))
		if SoundManager:
			SoundManager.play("hit_melee")

func _fire_ranged_shot(target_node: Node2D) -> void:
	if mag_ammo <= 0 or not is_instance_valid(target_node):
		return
	mag_ammo -= 1
	var aim_dir = global_position.direction_to(target_node.global_position)
	var spread_deg = 7.5 if enemy_type == EnemyType.SCAV else (2.8 if enemy_type == EnemyType.BOSS else 4.0)
	var shot_dir = aim_dir.rotated(deg_to_rad(randf_range(-spread_deg, spread_deg)))
	var muzzle_pos = global_position + aim_dir * 18.0
	
	var bullet = BulletScene.instantiate()
	get_tree().current_scene.add_child(bullet)
	var pen = 3 if enemy_type == EnemyType.BOSS else (2 if enemy_type == EnemyType.RAIDER else 1)
	var b_speed = 700.0 if enemy_type == EnemyType.BOSS else (540.0 if enemy_type == EnemyType.SCAV else 640.0)
	bullet.setup(muzzle_pos, shot_dir, damage, attack_radius * 1.35, pen, "enemies", b_speed)
	
	var ps = get_tree().current_scene.get_node_or_null("ParticleSystem")
	if ps:
		ps.emit("muzzle", muzzle_pos.x, muzzle_pos.y, 3, shot_dir.angle())
		ps.emit("bullet_shell", global_position.x, global_position.y, 1, rotation - PI * 0.5)
	if SoundManager:
		SoundManager.play("hit_ranged")
	EventBus.noise_created.emit(global_position, 450.0, "gunshot")

func _throw_boss_grenade(target_pos: Vector2) -> void:
	if global_position.distance_to(target_pos) > 600.0:
		return
	active_boss_grenades.append({
		"pos": target_pos,
		"timer": 1.8,
		"max_time": 1.8,
		"radius": 120.0,
		"damage": 45.0
	})
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("⚠️ 💣 [경고] 보스가 세열 수류탄을 투척했습니다! (1.8초 후 폭발, 반경 120px 이탈 요망)")
	if has_node("Visuals"):
		get_node("Visuals").queue_redraw()

func _detonate_boss_grenade(g_info: Dictionary) -> void:
	var g_pos: Vector2 = g_info.get("pos", global_position)
	var g_rad: float = float(g_info.get("radius", 120.0))
	var g_dmg: float = float(g_info.get("damage", 45.0))
	var ps = get_tree().current_scene.get_node_or_null("ParticleSystem") if get_tree() and get_tree().current_scene else null
	if ps:
		ps.emit("explosion", g_pos.x, g_pos.y, 24)
		ps.emit("spark", g_pos.x, g_pos.y, 16)
	if SoundManager:
		SoundManager.play("explosion")
	EventBus.noise_created.emit(g_pos, 550.0, "explosion")
	if EventBus.has_signal("camera_shake_requested"):
		EventBus.camera_shake_requested.emit(8.0, 0.35)
	if is_instance_valid(target_player) and target_player.global_position.distance_to(g_pos) <= g_rad:
		EventBus.player_damaged.emit(g_dmg, "explosion")
		if EventBus.has_signal("player_hit_direction"):
			EventBus.player_hit_direction.emit(g_pos)

func take_damage(amount: float, hit_dir: Vector2) -> void:
	hp -= amount
	current_state = State.CHASE # 피격 시 즉시 추적 모드
	knockback_velocity = hit_dir.normalized() * (65.0 if enemy_type == EnemyType.BOSS else (110.0 if is_ranged_human else 180.0))
	
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
		EnemyType.BOSS:
			type_str = "boss"
			faction_str = "raider"
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("★ 💀 [보스 처치] 구역 지휘관 '강철의 보스'를 사살했습니다! 최고급 전리품을 확인하십시오!")
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
		EnemyType.BOSS:
			var boss_parts = {
				"barrel": "정밀_롱헤비_총열",
				"muzzle": "소음기",
				"optic": "4배율_ACOG",
				"stock": "PRS_정밀_저격_스톡",
				"grip": "RK-1_인체공학_그립",
				"magazine": "50발_드럼_탄창",
				"rail": ["적색_레이저_표적지시기"]
			}
			var boss_stats = WeaponPartsDatabase.compute_weapon_stats("M4_리시버", boss_parts, "5.56mm")
			var boss_wep_custom = {
				"id": "M4_리시버",
				"receiver": "M4_리시버",
				"name": "보스 특제 M4A1 전술소총",
				"parts": boss_parts,
				"attachments": boss_parts,
				"computed_stats": boss_stats,
				"current_magazine_ammo": int(boss_stats.get("magazine_size", 50)),
				"loaded_ammo": "5.56mm",
				"durability": 100.0
			}
			drops.append({"id": "M4_리시버", "amount": 1, "custom_data": boss_wep_custom})
			drops.append({"id": "3레벨_방탄복", "amount": 1})
			drops.append({"id": "3레벨_헬멧", "amount": 1})
			drops.append({"id": "고급 치료킷", "amount": 1})
			drops.append({"id": "암호화된_SSD", "amount": 1})
			
	for i in range(drops.size()):
		var d = drops[i]
		var g_item = GroundItemScene.instantiate()
		var offset = Vector2(randf_range(-14, 14), randf_range(-14, 14))
		g_item.global_position = global_position + offset
		get_parent().call_deferred("add_child", g_item)
		g_item.call_deferred("setup", d["id"], d["amount"], d.get("custom_data", {}))

func _on_visuals_draw() -> void:
	var visuals = get_node("Visuals")
	for g_info in active_boss_grenades:
		var local_g = visuals.to_local(g_info["pos"])
		var g_rad = float(g_info.get("radius", 120.0))
		var g_ratio = 1.0 - clamp(float(g_info.get("timer", 0.0)) / float(g_info.get("max_time", 1.8)), 0.0, 1.0)
		visuals.draw_circle(local_g, g_rad, Color(0.95, 0.15, 0.15, 0.14 + 0.18 * g_ratio))
		visuals.draw_arc(local_g, g_rad, 0, TAU, 32, Color(1.0, 0.25, 0.15, 0.85), 2.0)
		visuals.draw_circle(local_g, 5.0, Color(0.2, 0.25, 0.2, 0.95))
	# 은폐 상태(modulate.a < 0.05)일 때 머리 위 느낌표, HP 바, 레이저 포인터까지 일괄 숨김 처리
	if visuals.modulate.a < 0.05:
		return
	
	# 기본 크기 비례
	var scale_f = 1.0
	if enemy_type == EnemyType.TANK: scale_f = 1.4
	elif enemy_type == EnemyType.RUNNER: scale_f = 0.85
	elif enemy_type == EnemyType.RAIDER: scale_f = 1.08
	elif enemy_type == EnemyType.BOSS: scale_f = 1.28
	
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
	elif enemy_type == EnemyType.BOSS:
		body_color = Color(0.78, 0.65, 0.52)
		cloth_color = Color(0.16, 0.14, 0.18)
		
	# --- 1. 몸통 다각형 ---
	var shoulder_width = 14.0 * scale_f
	var body_length = 10.0 * scale_f
	var chest_width = 12.0 * scale_f
	
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
		colors_outline.append(Color(0.95, 0.75, 0.15) if enemy_type == EnemyType.BOSS else Color(0.1, 0.1, 0.1))
		colors_cloth.append(cloth_color)
		
	var outline_points = PackedVector2Array()
	for p in body_points:
		outline_points.append(p * 1.15)
	
	visuals.draw_polygon(outline_points, colors_outline)
	visuals.draw_polygon(body_points, colors_cloth)
	
	# --- 2. 찢어진 옷 또는 중장갑 패드 ---
	if enemy_type == EnemyType.BOSS:
		visuals.draw_rect(Rect2(Vector2(-8, -14), Vector2(16, 28)), Color(0.55, 0.12, 0.12))
	else:
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
		
	# --- 3. 혈흔 ---
	var hp_ratio = hp / max_hp
	if hp_ratio < 0.7:
		var blood1 = PackedVector2Array([Vector2(-4, -4), Vector2(-8, -2), Vector2(-5, 3), Vector2(-2, 0)])
		visuals.draw_polygon(blood1, PackedColorArray([Color(0.5, 0, 0, 0.8), Color(0.5, 0, 0, 0.8), Color(0.5, 0, 0, 0.8), Color(0.5, 0, 0, 0.8)]))
	if hp_ratio < 0.4:
		visuals.draw_polygon(PackedVector2Array([Vector2(4, 5), Vector2(8, 7), Vector2(6, 10), Vector2(2, 8)]), 
			PackedColorArray([Color(0.4, 0, 0, 0.9), Color(0.4, 0, 0, 0.9), Color(0.4, 0, 0, 0.9), Color(0.4, 0, 0, 0.9)]))

	# --- 4. 머리 ---
	var head_radius_x = 7.0 * scale_f
	var head_radius_y = 8.0 * scale_f
	var head_offset = Vector2(body_length * 0.4, 0)
	
	var head_points = PackedVector2Array()
	var head_colors = PackedColorArray()
	var head_outlines = PackedColorArray()
	var sides = 12
	for i in range(sides):
		var angle = (i / float(sides)) * TAU
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
		if enemy_type == EnemyType.BOSS:
			visuals.draw_circle(head_offset, 8.6 * scale_f, Color(0.18, 0.18, 0.22))
			visuals.draw_arc(head_offset, 8.6 * scale_f, 0, TAU, 16, Color(0.95, 0.78, 0.2), 1.8)
			visuals.draw_rect(Rect2(head_offset + Vector2(2, -6.5), Vector2(5.0, 13.0)), Color(0.95, 0.2, 0.15, 0.95))
		elif enemy_type == EnemyType.RAIDER:
			visuals.draw_rect(Rect2(Vector2(-6, -10), Vector2(12, 20)), Color(0.15, 0.2, 0.15))
			visuals.draw_circle(head_offset, 7.8 * scale_f, Color(0.22, 0.26, 0.22))
			visuals.draw_rect(Rect2(head_offset + Vector2(2, -5.5), Vector2(4.5, 11.0)), Color(0.1, 0.75, 0.35, 0.9))
		else:
			visuals.draw_arc(head_offset, 6.5 * scale_f, PI * 0.4, PI * 1.6, 10, Color(0.55, 0.18, 0.15), 3.0)
			visuals.draw_circle(eye_offset + Vector2(0, -3.0*scale_f), 1.3*scale_f, Color(0.15, 0.15, 0.15))
			visuals.draw_circle(eye_offset + Vector2(0, 3.0*scale_f), 1.3*scale_f, Color(0.15, 0.15, 0.15))
			
		# 총기 파지 자세 및 총기 렌더링
		var gun_len = 26.0 if enemy_type == EnemyType.BOSS else (22.0 if enemy_type == EnemyType.RAIDER else 15.0)
		visuals.draw_line(Vector2(2, 8), Vector2(12, 4), cloth_color, 4.0)
		visuals.draw_line(Vector2(2, -8), Vector2(14, 1), cloth_color, 4.0)
		visuals.draw_circle(Vector2(12, 4), 2.5, body_color)
		visuals.draw_circle(Vector2(14, 1), 2.5, body_color)
		visuals.draw_line(Vector2(6, 2), Vector2(6 + gun_len, 2), Color(0.14, 0.15, 0.18), 3.6 if enemy_type == EnemyType.BOSS else 3.2)
		if (enemy_type == EnemyType.RAIDER or enemy_type == EnemyType.BOSS) and current_state == State.CHASE and reload_timer <= 0:
			var laser_col = Color(1.0, 0.8, 0.15, 0.55) if enemy_type == EnemyType.BOSS else Color(1.0, 0.15, 0.15, 0.42)
			visuals.draw_line(Vector2(6 + gun_len, 2), Vector2(135, 2), laser_col, 1.4)
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
	
	# HP 바 (보스는 상시 표시, 일반 적은 피격 시 표시)
	if (hp < max_hp or enemy_type == EnemyType.BOSS) and hp > 0:
		var bar_w = 38.0 if enemy_type == EnemyType.BOSS else 26.0
		var bar_h = 5.0 if enemy_type == EnemyType.BOSS else 4.0
		var bar_pos = Vector2(-bar_w/2.0, -18.0 * scale_f - 10.0)
		visuals.draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.15, 0.15, 0.18))
		var fill_w = (hp / max_hp) * bar_w
		var bar_col = Color(1.0, 0.75, 0.15) if enemy_type == EnemyType.BOSS else Color(0.9, 0.2, 0.2)
		visuals.draw_rect(Rect2(bar_pos, Vector2(fill_w, bar_h)), bar_col)

	# 느낌표/물음표 경고 아이콘 (소음 감지 또는 플레이어 발견 시)
	if alert_timer > 0:
		var icon_pos = Vector2(0, -22.0 * scale_f - 12.0)
		var icon_col = Color(1.0, 0.2, 0.2) if alert_icon_type == "!" else Color(1.0, 0.8, 0.2)
		var bg_alpha = clamp(alert_timer, 0.0, 1.0)
		visuals.draw_circle(icon_pos, 8.0, Color(0.1, 0.1, 0.1, 0.8 * bg_alpha))
		visuals.draw_arc(icon_pos, 8.0, 0, TAU, 16, icon_col * Color(1, 1, 1, bg_alpha), 1.5)
		
		if alert_icon_type == "!":
			visuals.draw_line(icon_pos + Vector2(0, -4), icon_pos + Vector2(0, 1), icon_col * Color(1, 1, 1, bg_alpha), 2.5)
			visuals.draw_circle(icon_pos + Vector2(0, 4), 1.2, icon_col * Color(1, 1, 1, bg_alpha))
		else:
			visuals.draw_circle(icon_pos + Vector2(0, 4), 1.2, icon_col * Color(1, 1, 1, bg_alpha))
			visuals.draw_arc(icon_pos + Vector2(0, -2), 3.0, -PI, 0, 8, icon_col * Color(1, 1, 1, bg_alpha), 2.0)
			visuals.draw_line(icon_pos + Vector2(3, -2), icon_pos + Vector2(0, 1), icon_col * Color(1, 1, 1, bg_alpha), 2.0)
