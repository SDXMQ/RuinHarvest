# res://scenes/entities/enemies/enemy.gd
extends CharacterBody2D

enum EnemyType { ZOMBIE, RUNNER, TANK, SCAV, RAIDER, BOSS, NIGHT_STALKER }
enum State { IDLE, WANDER, CHASE, ATTACK, INVESTIGATE, HURT, DEAD }

const BulletScene = preload("res://scenes/entities/projectiles/bullet.tscn")
const GroundItemScene = preload("res://scenes/entities/items/ground_item.tscn")
const CorpseBoxScript = preload("res://scenes/world/objects/corpse_box.gd")
const EnemyData = preload("res://scenes/entities/enemies/enemy_data.gd")
const EnemyVisualHelper = preload("res://scenes/entities/enemies/enemy_visual_helper.gd")

@export var enemy_type: EnemyType = EnemyType.ZOMBIE

var max_hp: float = 40.0
var hp: float = 40.0
var speed: float = 75.0
var damage: float = 12.0
var attack_cooldown: float = 1.0
var attack_timer: float = 0.0
var armor_tier: int = 0
var armor_value: float = 0.0
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
const BOSS_TELEGRAPH_DURATION: float = 0.60
var boss_telegraph_timer: float = 0.0
var boss_telegraph_ready: bool = false

func is_boss_telegraphing() -> bool:
	return enemy_type == EnemyType.BOSS and boss_telegraph_timer > 0.0

var wander_dir: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO
var hit_flash_tween: Tween
var last_hit_floating_text: String = ""
var last_hit_floating_color: Color = Color.WHITE
var _hit_feedback_already_shown: bool = false
var _was_flashlight_exposed: bool = false
var stalker_smoke_burst_count: int = 0

var _enemy_sprites_ready: bool = false
var _last_synced_type: int = -1
var _walk_phase: float = 0.0
var _enemies_tex: CanvasTexture = null
var _shadow_spr: Sprite2D = null
var _boot_left_spr: Sprite2D = null
var _boot_right_spr: Sprite2D = null
var _body_spr: Sprite2D = null
var _blood_spr: Sprite2D = null
var _glow_overlay: Node2D = null
var _hud_overlay: Node2D = null

func get_night_stalker_body_alpha() -> float:
	if enemy_type != EnemyType.NIGHT_STALKER:
		return 1.0
	if is_exposed_to_player_flashlight():
		return 0.92
	return 0.30

func trigger_night_stalker_smoke_evade() -> void:
	stalker_smoke_burst_count += 1
	if is_inside_tree() and get_tree() and get_tree().current_scene:
		var ps_ev = get_tree().current_scene.get_node_or_null("ParticleSystem")
		if ps_ev:
			ps_ev.emit("smoke", global_position.x, global_position.y, 6)

static func format_hit_feedback(dmg: float, armor_mult: float = 1.0) -> Dictionary:
	return EnemyVisualHelper.format_hit_feedback(dmg, armor_mult)

func show_hit_feedback(dmg: float, armor_mult: float = 1.0) -> Dictionary:
	var fb: Dictionary = EnemyVisualHelper.format_hit_feedback(dmg, armor_mult)
	last_hit_floating_text = String(fb["text"])
	last_hit_floating_color = fb["color"]
	_hit_feedback_already_shown = true
	EnemyVisualHelper.spawn_hit_feedback_label(self, fb)
	return fb

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
	has_used_medkit = false
	attack_cooldown = 1.0
	var preset: Dictionary = EnemyData.get_stats_preset(int(enemy_type))
	max_hp = float(preset.get("max_hp", 32.0))
	speed = float(preset.get("speed", 62.0))
	damage = float(preset.get("damage", 8.0))
	armor_tier = int(preset.get("armor_tier", 0))
	armor_value = float(preset.get("armor_value", 0.0))
	attack_cooldown = float(preset.get("attack_cooldown", 1.0))
	detection_radius = float(preset.get("detection_radius", 200.0))
	attack_radius = float(preset.get("attack_radius", 28.0))
	is_ranged_human = bool(preset.get("is_ranged_human", false))
	max_mag_ammo = int(preset.get("max_mag_ammo", 8))
	mag_ammo = max_mag_ammo
	hp = max_hp
	strafe_sign = 1.0 if randf() > 0.5 else -1.0
	faction_scan_timer = randf_range(0.1, 0.5)

func is_exposed_to_player_flashlight() -> bool:
	if not is_instance_valid(target_player):
		return false
	var flashlight_on := false
	if target_player.get("player_lighting") != null and target_player.player_lighting != null:
		flashlight_on = bool(target_player.player_lighting.flashlight_enabled)
	elif target_player.get("flashlight_enabled") != null:
		flashlight_on = bool(target_player.flashlight_enabled)
	if not flashlight_on:
		return false
	var dist = global_position.distance_to(target_player.global_position)
	if dist > 320.0 or dist < 1.0:
		return false
	var p_forward = Vector2.RIGHT.rotated(target_player.rotation)
	var dir_from_p = target_player.global_position.direction_to(global_position)
	if p_forward.dot(dir_from_p) < 0.82:
		return false
	if is_inside_tree() and get_world_2d() != null:
		return _has_line_of_sight(target_player.global_position)
	return true

func compute_night_stalker_evade_velocity(target_pos: Vector2) -> Vector2:
	var dir_to_t = global_position.direction_to(target_pos)
	var evade_dir = (-dir_to_t * 0.38 + dir_to_t.orthogonal() * strafe_sign).normalized()
	return evade_dir * (speed * 1.18)

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
	if is_instance_valid(target_player) and (target_player.get("hp") == null or float(target_player.get("hp")) > 0.0) and not bool(target_player.get("_is_dying")):
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
	if active_target == target_player and is_instance_valid(target_player):
		if (target_player.get("hp") != null and float(target_player.get("hp")) <= 0.0) or bool(target_player.get("_is_dying")):
			active_target = null
	if not is_instance_valid(active_target) and enemy_type == EnemyType.BOSS:
		boss_telegraph_timer = 0.0
		boss_telegraph_ready = false
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

		if enemy_type == EnemyType.BOSS and (current_state != State.CHASE or dist > attack_radius or not _has_line_of_sight(active_target.global_position)):
			boss_telegraph_timer = 0.0
			boss_telegraph_ready = false
			
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
					var can_fire := true
					if enemy_type == EnemyType.BOSS and attack_timer <= 0.0 and reload_timer <= 0.0 and boss_burst_remaining <= 0:
						if not boss_telegraph_ready:
							if boss_telegraph_timer <= 0.0:
								boss_telegraph_timer = BOSS_TELEGRAPH_DURATION
							boss_telegraph_timer = maxf(0.0, boss_telegraph_timer - delta)
							if _glow_overlay:
								_glow_overlay.queue_redraw()
							if boss_telegraph_timer > 0.0:
								can_fire = false
							else:
								boss_telegraph_ready = true
					if can_fire:
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
					if chunk_mgr and chunk_mgr.object_layer and attack_timer <= 0:
						var t_pos = chunk_mgr.object_layer.local_to_map(forward_pos)
						if TileManager.break_window_at(chunk_mgr.object_layer, t_pos, forward_pos, "[icon:explosion] 적이 창문을 깨부수고 침입합니다!", 400.0, 6, false):
							attack_timer = 1.0
					
					var exposed_now := (enemy_type == EnemyType.NIGHT_STALKER and active_target == target_player and is_exposed_to_player_flashlight())
					if enemy_type == EnemyType.NIGHT_STALKER:
						if exposed_now and not _was_flashlight_exposed:
							trigger_night_stalker_smoke_evade()
						_was_flashlight_exposed = exposed_now
					if exposed_now and dist > 48.0:
						var evade_vel = compute_night_stalker_evade_velocity(active_target.global_position)
						rotation = lerp_angle(rotation, evade_vel.angle(), delta * 14.0)
						velocity = evade_vel
						if randf() < 0.25 and get_tree() and get_tree().current_scene:
							var ps_ev = get_tree().current_scene.get_node_or_null("ParticleSystem")
							if ps_ev:
								ps_ev.emit("smoke", global_position.x, global_position.y, 2)
					else:
						var steer_dir = _get_steered_direction(active_target.global_position)
						rotation = lerp_angle(rotation, steer_dir.angle(), delta * 10.0)
						var spd_mult = 1.12 if (enemy_type == EnemyType.NIGHT_STALKER and dist <= 110.0) else 1.0
						velocity = steer_dir * (speed * spd_mult)
					
		move_and_slide()
		
		# 걷기 애니메이션 (몸 흔들림 + 부츠 교차 보행) 및 전술 시야(LoS/FoV) 가시성 마스킹
		if has_node("Visuals"):
			var visuals = get_node("Visuals")
			_sync_enemy_pixel_layers(visuals)
			var scale_f := _get_type_scale()
			if velocity.length() > 5.0:
				_walk_phase += delta * (speed / 70.0) * 11.0
				var bob := sin(_walk_phase * 2.0) * 1.4
				visuals.position.y = bob
				var stride := sin(_walk_phase) * 4.5 * scale_f
				if _boot_left_spr and _boot_right_spr:
					_boot_left_spr.position = Vector2(stride, -5.0 * scale_f)
					_boot_right_spr.position = Vector2(-stride, 5.0 * scale_f)
			else:
				visuals.position.y = lerp(visuals.position.y, 0.0, clampf(delta * 10.0, 0.0, 1.0))
				if _boot_left_spr and _boot_right_spr:
					_boot_left_spr.position = _boot_left_spr.position.lerp(Vector2(0.0, -5.0 * scale_f), clampf(delta * 10.0, 0.0, 1.0))
					_boot_right_spr.position = _boot_right_spr.position.lerp(Vector2(0.0, 5.0 * scale_f), clampf(delta * 10.0, 0.0, 1.0))
			if _shadow_spr:
				_shadow_spr.position = Vector2(1.0, 2.0 - visuals.position.y)
			_update_tactical_visibility(delta, player_dist, visuals)
			if _glow_overlay:
				_glow_overlay.visible = visuals.modulate.a >= 0.05
				if _glow_overlay.visible:
					_glow_overlay.queue_redraw()

var _layer_refs: Dictionary = {}
var _cached_laser_end: Vector2 = Vector2(145.0, 1.0)

func _get_type_scale() -> float:
	return EnemyData.get_type_scale(int(enemy_type))

func _setup_enemy_pixel_layers(visuals: Node2D) -> void:
	if _enemy_sprites_ready or not visuals:
		return
	_enemy_sprites_ready = true
	_layer_refs = EnemyVisualHelper.setup_pixel_layers(visuals, _on_glow_overlay_draw, _on_hud_overlay_draw)
	_enemies_tex = _layer_refs.get("enemies_tex") as CanvasTexture
	_shadow_spr = _layer_refs.get("shadow_spr") as Sprite2D
	_boot_left_spr = _layer_refs.get("boot_left_spr") as Sprite2D
	_boot_right_spr = _layer_refs.get("boot_right_spr") as Sprite2D
	_body_spr = _layer_refs.get("body_spr") as Sprite2D
	_blood_spr = _layer_refs.get("blood_spr") as Sprite2D
	_glow_overlay = _layer_refs.get("glow_overlay") as Node2D
	_hud_overlay = _layer_refs.get("hud_overlay") as Node2D
	_sync_enemy_pixel_layers(visuals)

func _sync_enemy_pixel_layers(visuals: Node2D) -> void:
	if not _enemy_sprites_ready:
		_setup_enemy_pixel_layers(visuals)
	_last_synced_type = EnemyVisualHelper.sync_pixel_layers(self, visuals, _layer_refs, _last_synced_type)
	_cached_laser_end = EnemyVisualHelper.update_cached_laser_end(self)

func _on_glow_overlay_draw() -> void:
	EnemyVisualHelper.draw_glow_overlay(self, _glow_overlay, _enemies_tex)

func _update_tactical_visibility(delta: float, dist: float, visuals: Node2D) -> void:
	var has_los := _has_line_of_sight(target_player.global_position) if is_instance_valid(target_player) else false
	EnemyVisualHelper.update_tactical_visibility(self, target_player, delta, dist, visuals, has_los)

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
	if target_node == target_player and ((target_player.get("hp") != null and float(target_player.get("hp")) <= 0.0) or bool(target_player.get("_is_dying"))):
		return
		
	if is_ranged_human:
		if mag_ammo <= 0:
			boss_burst_remaining = 0
			reload_timer = 1.9 if enemy_type == EnemyType.SCAV else 1.4
			return
		if enemy_type == EnemyType.BOSS:
			var dist_to_v = global_position.distance_to(target_node.global_position)
			boss_telegraph_ready = false
			if boss_grenade_cooldown <= 0.0 and dist_to_v >= 110.0 and dist_to_v <= 260.0:
				_throw_boss_grenade(target_node.global_position)
				boss_grenade_cooldown = 9.5
				attack_timer = 0.75
				return
			# 보스 특수 패턴 1: 4연발 제압 사격 (Suppressive Burst Fire)
			boss_burst_remaining = 3
			boss_burst_timer = 0.11
			attack_timer = 1.55
			_fire_ranged_shot(target_node)
		else:
			attack_timer = attack_cooldown * randf_range(0.95, 1.3)
			_fire_ranged_shot(target_node)
	else:
		attack_timer = attack_cooldown
		if target_node == target_player:
			var dmg_source := "night_stalker" if enemy_type == EnemyType.NIGHT_STALKER else "zombie"
			EventBus.player_damaged.emit(damage, dmg_source)
			if not target_player.is_node_ready() and target_player.has_method("take_damage"):
				target_player.take_damage(damage, dmg_source)
			elif enemy_type == EnemyType.NIGHT_STALKER and "is_infected" in target_player and not bool(target_player.is_infected):
				target_player.is_infected = true
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
	var spread_deg = 11.0 if enemy_type == EnemyType.SCAV else (4.5 if enemy_type == EnemyType.BOSS else 6.5)
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
	if get_tree() and get_tree().current_scene and get_tree().current_scene.has_method("spawn_transient_point_light"):
		get_tree().current_scene.spawn_transient_point_light(muzzle_pos, Color(1.0, 0.78, 0.28), 1.85, 1.75, 0.06, 48.0)
	if SoundManager:
		SoundManager.play("hit_ranged")
	EventBus.noise_created.emit(global_position, 450.0, "gunshot")

func _throw_boss_grenade(target_pos: Vector2) -> void:
	if global_position.distance_to(target_pos) > 260.0:
		return
	active_boss_grenades.append({
		"pos": target_pos,
		"timer": 1.8,
		"max_time": 1.8,
		"radius": 120.0,
		"damage": 45.0
	})
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("[icon:warn] [icon:grenade] [경고] 보스가 세열 수류탄을 투척했습니다! (1.8초 후 폭발, 반경 120px 이탈 요망)")
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
	if not _hit_feedback_already_shown:
		show_hit_feedback(amount, 1.0)
	_hit_feedback_already_shown = false
	hp -= amount
	current_state = State.CHASE # 피격 시 즉시 추적 모드
	knockback_velocity = hit_dir.normalized() * (65.0 if enemy_type == EnemyType.BOSS else (110.0 if is_ranged_human else 180.0))
	
	if has_node("Visuals"):
		var visuals = get_node("Visuals")
		_sync_enemy_pixel_layers(visuals)
		visuals.queue_redraw()
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
	var meta: Dictionary = EnemyData.get_death_meta(int(enemy_type))
	var log_msg: String = String(meta.get("log_msg", ""))
	if log_msg != "" and EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit(log_msg)
	EventBus.enemy_killed.emit(String(meta.get("type_str", "zombie")), String(meta.get("faction_str", "infected")), global_position)
	_spawn_loot_drop()
	queue_free()

func _spawn_loot_drop() -> void:
	if not GroundItemScene or not get_parent():
		return
	var drops: Array = EnemyData.roll_loot_drops(int(enemy_type))
	if is_ranged_human or enemy_type in [EnemyType.SCAV, EnemyType.RAIDER, EnemyType.BOSS]:
		_spawn_corpse_loot_box(drops)
		return

	for d in drops:
		var g_item = GroundItemScene.instantiate()
		var offset := Vector2(randf_range(-14, 14), randf_range(-14, 14))
		g_item.global_position = global_position + offset
		get_parent().call_deferred("add_child", g_item)
		g_item.call_deferred("setup", d["id"], d["amount"], d.get("custom_data", {}))

func _spawn_corpse_loot_box(drops: Array) -> void:
	EnemyData.spawn_corpse_loot_box(self, int(enemy_type), drops, CorpseBoxScript)

func _on_visuals_draw() -> void:
	var visuals = get_node("Visuals")
	_sync_enemy_pixel_layers(visuals)
	if _hud_overlay:
		_hud_overlay.queue_redraw()

func _on_hud_overlay_draw() -> void:
	EnemyVisualHelper.draw_hud_overlay(self, _hud_overlay)
