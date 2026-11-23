# res://scenes/entities/enemies/enemy.gd
extends CharacterBody2D

enum EnemyType { ZOMBIE, RUNNER, TANK, SCAV, RAIDER, BOSS, NIGHT_STALKER }
enum State { IDLE, WANDER, CHASE, ATTACK, INVESTIGATE, HURT, DEAD }

const BulletScene = preload("res://scenes/entities/projectiles/bullet.tscn")
const GroundItemScene = preload("res://scenes/entities/items/ground_item.tscn")
const CorpseBoxScript = preload("res://scenes/world/objects/corpse_box.gd")

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
	var dmg_int: int = max(1, int(round(dmg)))
	if armor_mult < 0.85:
		var absorb_pct: int = int(round((1.0 - armor_mult) * 100.0))
		return {
			"text": "-%d [방탄 흡수 -%d%%]" % [dmg_int, absorb_pct],
			"color": Color(0.55, 0.78, 0.98),
			"absorbed": true
		}
	elif armor_mult < 0.999:
		var absorb_pct2: int = int(round((1.0 - armor_mult) * 100.0))
		return {
			"text": "-%d [방탄 -%d%%]" % [dmg_int, absorb_pct2],
			"color": Color(0.75, 0.82, 0.92),
			"absorbed": true
		}
	else:
		return {
			"text": "-%d" % dmg_int,
			"color": Color(1.0, 0.92, 0.32) if dmg >= 30.0 else Color(1.0, 0.98, 0.92),
			"absorbed": false
		}

func show_hit_feedback(dmg: float, armor_mult: float = 1.0) -> Dictionary:
	var fb := format_hit_feedback(dmg, armor_mult)
	last_hit_floating_text = String(fb["text"])
	last_hit_floating_color = fb["color"]
	_hit_feedback_already_shown = true
	if is_inside_tree() and get_parent() != null:
		var lbl := Label.new()
		lbl.text = last_hit_floating_text
		lbl.add_theme_font_size_override("font_size", 11 if bool(fb["absorbed"]) else 13)
		lbl.add_theme_color_override("font_color", last_hit_floating_color)
		lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 0.95))
		lbl.add_theme_constant_override("outline_size", 3)
		lbl.z_index = 45
		lbl.global_position = global_position + Vector2(randf_range(-14.0, 14.0), -28.0)
		get_parent().add_child(lbl)
		var tw := lbl.create_tween()
		tw.set_parallel(true)
		tw.tween_property(lbl, "global_position:y", lbl.global_position.y - 26.0, 0.65)
		tw.tween_property(lbl, "modulate:a", 0.0, 0.65)
		tw.chain().tween_callback(lbl.queue_free)
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
	is_ranged_human = false
	armor_tier = 0
	armor_value = 0.0
	has_used_medkit = false
	match enemy_type:
		EnemyType.ZOMBIE:
			max_hp = 32.0
			speed = 62.0
			damage = 8.0
			detection_radius = 200.0
			attack_radius = 28.0
		EnemyType.RUNNER:
			max_hp = 20.0
			speed = 115.0
			damage = 6.0
			detection_radius = 220.0
			attack_radius = 26.0
		EnemyType.TANK:
			max_hp = 90.0
			speed = 40.0
			damage = 16.0
			armor_tier = 1
			armor_value = 10.0
			detection_radius = 190.0
			attack_radius = 34.0
		EnemyType.SCAV:
			is_ranged_human = true
			armor_tier = 1
			armor_value = 10.0
			max_hp = 42.0
			speed = 72.0
			damage = 7.0
			attack_cooldown = 1.25
			detection_radius = 250.0
			attack_radius = 200.0
			max_mag_ammo = 8
			mag_ammo = 8
		EnemyType.RAIDER:
			is_ranged_human = true
			armor_tier = 2
			armor_value = 20.0
			max_hp = 72.0
			speed = 82.0
			damage = 10.0
			attack_cooldown = 0.72
			detection_radius = 290.0
			attack_radius = 240.0
			max_mag_ammo = 15
			mag_ammo = 15
		EnemyType.BOSS:
			is_ranged_human = true
			armor_tier = 3
			armor_value = 32.0
			max_hp = 190.0
			speed = 80.0
			damage = 12.0
			attack_cooldown = 0.45
			detection_radius = 290.0
			attack_radius = 225.0
			max_mag_ammo = 30
			mag_ammo = 30
		EnemyType.NIGHT_STALKER:
			max_hp = 65.0
			speed = 130.0
			damage = 13.0
			armor_tier = 1
			armor_value = 14.0
			attack_cooldown = 0.85
			detection_radius = 300.0
			attack_radius = 30.0
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
					if chunk_mgr and chunk_mgr.object_layer:
						var t_pos = chunk_mgr.object_layer.local_to_map(forward_pos)
						var win_coords: Vector2i = chunk_mgr.object_layer.get_cell_atlas_coords(t_pos)
						if TileManager.is_window(win_coords):
							if attack_timer <= 0:
								chunk_mgr.object_layer.set_cell(t_pos, 0, TileManager.get_window_broken_tile(win_coords))
								EventBus.noise_created.emit(forward_pos, 400.0, "break")
								EventBus.window_broken.emit(t_pos)
								EventBus.event_logged.emit("[icon:explosion] 적이 창문을 깨부수고 침입합니다!")
								if SoundManager: SoundManager.play("hit_melee")
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

func _get_type_scale() -> float:
	match enemy_type:
		EnemyType.TANK:
			return 1.25
		EnemyType.RUNNER:
			return 0.88
		EnemyType.RAIDER:
			return 1.06
		EnemyType.BOSS:
			return 1.24
		EnemyType.NIGHT_STALKER:
			return 1.06
		_:
			return 1.0

func _setup_enemy_pixel_layers(visuals: Node2D) -> void:
	if _enemy_sprites_ready or not visuals:
		return
	_enemy_sprites_ready = true
	if PixelAssetManager:
		_enemies_tex = PixelAssetManager.get_canvas_texture("entities/enemies")
	var parts_tex: CanvasTexture = PixelAssetManager.get_canvas_texture("entities/player_parts") if PixelAssetManager else null

	_shadow_spr = Sprite2D.new()
	_shadow_spr.name = "ContactShadow"
	_shadow_spr.centered = true
	_shadow_spr.region_enabled = true
	_shadow_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shadow_spr.use_parent_material = false
	_shadow_spr.z_index = -2
	if parts_tex:
		_shadow_spr.texture = parts_tex
	_shadow_spr.region_rect = Rect2(0, 0, 32, 32)
	_shadow_spr.modulate = Color(1.0, 1.0, 1.0, 0.72)
	visuals.add_child(_shadow_spr)

	_boot_left_spr = Sprite2D.new()
	_boot_left_spr.name = "BootLeft"
	_boot_left_spr.centered = true
	_boot_left_spr.region_enabled = true
	_boot_left_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_boot_left_spr.use_parent_material = true
	_boot_left_spr.z_index = -1
	if _enemies_tex:
		_boot_left_spr.texture = _enemies_tex
	_boot_left_spr.region_rect = Rect2(0, 48, 48, 48)
	visuals.add_child(_boot_left_spr)

	_boot_right_spr = Sprite2D.new()
	_boot_right_spr.name = "BootRight"
	_boot_right_spr.centered = true
	_boot_right_spr.region_enabled = true
	_boot_right_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_boot_right_spr.use_parent_material = true
	_boot_right_spr.z_index = -1
	if _enemies_tex:
		_boot_right_spr.texture = _enemies_tex
	_boot_right_spr.region_rect = Rect2(0, 48, 48, 48)
	visuals.add_child(_boot_right_spr)

	_body_spr = Sprite2D.new()
	_body_spr.name = "BodySprite"
	_body_spr.centered = true
	_body_spr.region_enabled = true
	_body_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_body_spr.use_parent_material = true
	_body_spr.z_index = 0
	if _enemies_tex:
		_body_spr.texture = _enemies_tex
	visuals.add_child(_body_spr)

	_blood_spr = Sprite2D.new()
	_blood_spr.name = "BloodOverlay"
	_blood_spr.centered = true
	_blood_spr.region_enabled = true
	_blood_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_blood_spr.use_parent_material = true
	_blood_spr.z_index = 1
	if _enemies_tex:
		_blood_spr.texture = _enemies_tex
	_blood_spr.region_rect = Rect2(7 * 48, 0, 48, 48)
	_blood_spr.visible = false
	visuals.add_child(_blood_spr)

	_glow_overlay = Node2D.new()
	_glow_overlay.name = "GlowOverlay"
	_glow_overlay.z_index = 2
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_glow_overlay.material = unshaded
	_glow_overlay.draw.connect(_on_glow_overlay_draw)
	visuals.add_child(_glow_overlay)

	_hud_overlay = Node2D.new()
	_hud_overlay.name = "HudOverlay"
	_hud_overlay.z_index = 5
	_hud_overlay.use_parent_material = false
	_hud_overlay.draw.connect(_on_hud_overlay_draw)
	visuals.add_child(_hud_overlay)

	_sync_enemy_pixel_layers(visuals)

func _sync_enemy_pixel_layers(visuals: Node2D) -> void:
	if not _enemy_sprites_ready:
		_setup_enemy_pixel_layers(visuals)
	var scale_f := _get_type_scale()
	if _last_synced_type != int(enemy_type):
		_last_synced_type = int(enemy_type)
		var col_idx := clampi(int(enemy_type), 0, 6)
		if _body_spr:
			_body_spr.region_rect = Rect2(col_idx * 48, 0, 48, 48)
		if _shadow_spr:
			_shadow_spr.scale = Vector2(scale_f * 1.05, scale_f * 1.15)
		if _boot_left_spr and _boot_right_spr:
			var bscale := Vector2(scale_f * 0.9, scale_f * 0.9)
			_boot_left_spr.scale = bscale
			_boot_right_spr.scale = bscale
			_boot_left_spr.position = Vector2(0.0, -5.0 * scale_f)
			_boot_right_spr.position = Vector2(0.0, 5.0 * scale_f)
		if visuals and visuals.material:
			var oc := Color(0.05, 0.06, 0.08, 0.95)
			if enemy_type == EnemyType.BOSS:
				oc = Color(0.95, 0.75, 0.15, 0.98)
			elif enemy_type == EnemyType.NIGHT_STALKER:
				oc = Color(0.45, 0.22, 0.75, 0.92)
			visuals.material.set_shader_parameter("outline_color", oc)

	if _blood_spr:
		var hp_ratio: float = hp / maxf(max_hp, 1.0)
		_blood_spr.visible = hp_ratio < 0.7
		if _blood_spr.visible:
			_blood_spr.modulate.a = 0.95 if hp_ratio < 0.4 else 0.72
			_blood_spr.scale = Vector2(scale_f, scale_f)

	if visuals and visuals.material:
		if enemy_type == EnemyType.NIGHT_STALKER:
			var ns_alpha := get_night_stalker_body_alpha()
			visuals.material.set_shader_parameter("stealth_dissolve", clampf(1.0 - ns_alpha, 0.0, 0.72))
		else:
			visuals.material.set_shader_parameter("stealth_dissolve", 0.0)

	_update_cached_laser_end()

var _cached_laser_end: Vector2 = Vector2(145.0, 1.0)

func _update_cached_laser_end() -> void:
	if not is_ranged_human or not (enemy_type == EnemyType.RAIDER or enemy_type == EnemyType.BOSS) or current_state != State.CHASE or reload_timer > 0:
		return
	var is_boss_lockon := (enemy_type == EnemyType.BOSS and boss_telegraph_timer > 0.0)
	var muzzle_start := Vector2(28.0, 1.0)
	var laser_end := Vector2(attack_radius if is_boss_lockon else 145.0, 1.0)
	if is_inside_tree():
		var world_2d: World2D = get_world_2d()
		if world_2d != null and world_2d.direct_space_state:
			var q := PhysicsRayQueryParameters2D.create(to_global(muzzle_start), to_global(laser_end), 1, [self])
			var hit: Dictionary = world_2d.direct_space_state.intersect_ray(q)
			if not hit.is_empty():
				laser_end = to_local(hit["position"])
	_cached_laser_end = laser_end

func _on_glow_overlay_draw() -> void:
	if not _glow_overlay:
		return
	for g_info in active_boss_grenades:
		var local_g := _glow_overlay.to_local(g_info["pos"])
		var g_rad := float(g_info.get("radius", 120.0))
		var g_ratio := 1.0 - clampf(float(g_info.get("timer", 0.0)) / float(g_info.get("max_time", 1.8)), 0.0, 1.0)
		_glow_overlay.draw_circle(local_g, g_rad, Color(0.95, 0.15, 0.15, 0.14 + 0.18 * g_ratio))
		_glow_overlay.draw_arc(local_g, g_rad, 0, TAU, 32, Color(1.6, 0.3, 0.2, 0.88), 2.0)
		if _enemies_tex:
			_glow_overlay.draw_texture_rect_region(_enemies_tex, Rect2(local_g - Vector2(24, 24), Vector2(48, 48)), Rect2(3 * 48, 48, 48, 48))
		else:
			_glow_overlay.draw_circle(local_g, 5.0, Color(0.2, 0.25, 0.2, 0.95))

	var visuals := get_node_or_null("Visuals")
	if visuals and visuals.modulate.a < 0.05:
		return

	if is_ranged_human:
		if enemy_type == EnemyType.BOSS:
			_glow_overlay.draw_rect(Rect2(2.5, -4.5, 4.0, 9.0), Color(2.2, 0.28, 0.22, 0.92))
		elif enemy_type == EnemyType.RAIDER:
			_glow_overlay.draw_rect(Rect2(4.0, -3.5, 3.0, 2.5), Color(0.28, 2.0, 0.50, 0.88))
			_glow_overlay.draw_rect(Rect2(4.0, 1.0, 3.0, 2.5), Color(0.28, 2.0, 0.50, 0.88))

		if (enemy_type == EnemyType.RAIDER or enemy_type == EnemyType.BOSS) and current_state == State.CHASE and reload_timer <= 0:
			var is_boss_lockon := (enemy_type == EnemyType.BOSS and boss_telegraph_timer > 0.0)
			var laser_col := Color(2.2, 1.5, 0.22, 0.62) if enemy_type == EnemyType.BOSS else Color(2.2, 0.24, 0.24, 0.52)
			var laser_w := 1.2
			var muzzle_start := Vector2(28.0, 1.0)
			var laser_end := _cached_laser_end
			if is_boss_lockon:
				var pulse := 0.55 + 0.45 * sin(float(Time.get_ticks_msec()) * 0.025)
				laser_col = Color(2.6, 0.32 + 0.9 * pulse, 0.18, 0.94)
				laser_w = 2.6
				_glow_overlay.draw_arc(Vector2.ZERO, 26.0 + 4.0 * pulse, 0.0, TAU, 24, Color(2.4, 0.28, 0.18, 0.25 + 0.72 * pulse), 2.0)
			_glow_overlay.draw_line(muzzle_start, laser_end, laser_col, laser_w)
	else:
		if enemy_type == EnemyType.NIGHT_STALKER:
			var ns_alpha := get_night_stalker_body_alpha()
			var aura_a := 0.28 if ns_alpha < 0.5 else 0.14
			_glow_overlay.draw_circle(Vector2(5.5, -2.5), 3.2, Color(0.35, 1.6, 2.0, aura_a))
			_glow_overlay.draw_circle(Vector2(5.5, 2.5), 3.2, Color(0.35, 1.6, 2.0, aura_a))
			_glow_overlay.draw_rect(Rect2(4.5, -3.5, 2.0, 2.0), Color(0.5, 2.4, 2.6, 0.98))
			_glow_overlay.draw_rect(Rect2(4.5, 1.5, 2.0, 2.0), Color(0.5, 2.4, 2.6, 0.98))
		else:
			var eye_x := 6.0 if enemy_type == EnemyType.TANK else 4.0
			var eye_y := 3.2 if enemy_type == EnemyType.TANK else 2.4
			_glow_overlay.draw_rect(Rect2(eye_x, -eye_y - 1.0, 2.0, 2.0), Color(2.2, 0.22, 0.22, 0.95))
			_glow_overlay.draw_rect(Rect2(eye_x, eye_y - 1.0, 2.0, 2.0), Color(2.2, 0.22, 0.22, 0.95))

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
		elif enemy_type == EnemyType.NIGHT_STALKER and dist <= 180.0 and dot_p >= 0.35:
			# 야간 추격자는 어둠 속에서도 안광이 희미하게 번뜩임
			target_alpha = 0.35
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
				EventBus.event_logged.emit("[icon:star] [icon:skull] [보스 처치] 구역 지휘관 '강철의 보스'를 사살했습니다! 최고급 전리품을 확인하십시오!")
		EnemyType.NIGHT_STALKER:
			type_str = "night_stalker"
			faction_str = "infected"
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("[icon:moon] [변이체 처치] 어둠 속의 '야간 추격자'를 사살했습니다!")
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
			drops.append({"id": "Scav 인식표", "amount": 1})
			var ammo_pool = [
				{"id": "9mm", "amount": randi_range(12, 24)},
				{"id": ".45ACP", "amount": randi_range(10, 20)},
				{"id": "12게이지_벅샷", "amount": randi_range(6, 12)}
			]
			drops.append(ammo_pool.pick_random())
			if randf() < 0.60:
				var scav_guns = ["M9_리시버", "레밍턴_리시버", "MP5_리시버"]
				var g_id: String = scav_guns.pick_random()
				drops.append({"id": g_id, "amount": 1, "custom_data": WeaponPartsDatabase.create_loot_weapon(g_id, 0.05)})
			if randf() < 0.75:
				var gear_pool = [
					{"id": "붕대", "amount": 1},
					{"id": "진통제", "amount": 1},
					{"id": "생수", "amount": 1},
					{"id": "식량통조림", "amount": 1},
					{"id": "레드닷_사이트", "amount": 1},
					{"id": "수직_포어그립", "amount": 1}
				]
				drops.append(gear_pool.pick_random())
		EnemyType.RAIDER:
			drops.append({"id": "Scav 인식표", "amount": 1})
			var ammo_pool = [
				{"id": "5.56mm", "amount": randi_range(18, 30)},
				{"id": "7.62mm", "amount": randi_range(18, 30)},
				{"id": "12게이지_슬러그", "amount": randi_range(8, 14)}
			]
			drops.append(ammo_pool.pick_random())
			if randf() < 0.80:
				var raider_guns = ["AK_리시버", "M4_리시버", "MP5_리시버", "레버액션_리시버"]
				var r_id: String = raider_guns.pick_random()
				drops.append({"id": r_id, "amount": 1, "custom_data": WeaponPartsDatabase.create_loot_weapon(r_id, 0.10)})
			var high_pool = [
				{"id": "구급상자", "amount": 1},
				{"id": "고급 치료킷", "amount": 1},
				{"id": "수류탄", "amount": 1},
				{"id": "2레벨_방탄복", "amount": 1},
				{"id": "2레벨_헬멧", "amount": 1},
				{"id": "2배율_조준경", "amount": 1},
				{"id": "대용량_확장_탄창", "amount": 1},
				{"id": "소음기", "amount": 1}
			]
			drops.append(high_pool.pick_random())
			if randf() < 0.32:
				drops.append({"id": "보안 키카드" if randf() < 0.35 else "무기고 열쇠", "amount": 1})
		EnemyType.NIGHT_STALKER:
			var night_pool = [
				{"id": "고급 치료킷", "amount": 1},
				{"id": "암호화된 SSD", "amount": 1},
				{"id": "금시계", "amount": 1}
			]
			drops.append(night_pool.pick_random())
			if randf() < 0.35:
				drops.append({"id": "보안 키카드" if randf() < 0.5 else "무기고 열쇠", "amount": 1})
		EnemyType.BOSS:
			drops.append({"id": "Scav 인식표", "amount": 2})
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
			drops.append({"id": "암호화된 SSD", "amount": 1})
			drops.append({"id": "장거리 무전기", "amount": 1})
			drops.append({"id": "보안 키카드", "amount": 1})
			drops.append({"id": "무기고 열쇠", "amount": 1})
			
	if is_ranged_human or enemy_type in [EnemyType.SCAV, EnemyType.RAIDER, EnemyType.BOSS]:
		_spawn_corpse_loot_box(drops)
		return

	for i in range(drops.size()):
		var d = drops[i]
		var g_item = GroundItemScene.instantiate()
		var offset = Vector2(randf_range(-14, 14), randf_range(-14, 14))
		g_item.global_position = global_position + offset
		get_parent().call_deferred("add_child", g_item)
		g_item.call_deferred("setup", d["id"], d["amount"], d.get("custom_data", {}))

func _spawn_corpse_loot_box(drops: Array) -> void:
	if not get_parent() or drops.is_empty():
		return
	var scene: Node = get_tree().current_scene if get_tree() else null
	if scene == null or not ("container_inventories" in scene):
		var p := get_parent()
		while p != null:
			if "container_inventories" in p:
				scene = p
				break
			p = p.get_parent()

	var base_tile := Vector2i(int(floor(global_position.x / 32.0)), int(floor(global_position.y / 32.0)))
	var chosen_tile := base_tile
	if scene and "container_inventories" in scene:
		var c_dict: Dictionary = scene.container_inventories
		if c_dict.has(chosen_tile):
			var found_free := false
			for rad in range(1, 5):
				for dy in range(-rad, rad + 1):
					for dx in range(-rad, rad + 1):
						var cand := base_tile + Vector2i(dx, dy)
						if not c_dict.has(cand):
							chosen_tile = cand
							found_free = true
							break
					if found_free:
						break
				if found_free:
					break

	var title := "[icon:backpack] 스캐브 유품 가방"
	var rank := 3
	if enemy_type == EnemyType.RAIDER:
		title = "[icon:backpack] 정예 레이더 군장 상자"
		rank = 4
	elif enemy_type == EnemyType.BOSS:
		title = "[icon:skull] 보스 지휘관 특수 군장함"
		rank = 5

	var inv := Inventory.new()
	inv.max_slots = 12 if enemy_type == EnemyType.BOSS else 8
	inv.clear()
	inv.set_meta("custom_title", title)
	if scene:
		scene.add_child(inv)
	else:
		get_parent().add_child(inv)

	var corpse_equipment := {
		"primary1": {},
		"helmet": {},
		"vest": {},
		"backpack": {}
	}
	var bag_drops: Array = []
	for d in drops:
		if not (d is Dictionary):
			continue
		var item_id := String(d.get("id", ""))
		if item_id == "":
			continue
		var amt := maxi(1, int(d.get("amount", 1)))
		var c_data: Dictionary = d.get("custom_data", {}).duplicate(true)
		if c_data.is_empty() and WeaponPartsDatabase.RECEIVERS.has(item_id):
			c_data = WeaponPartsDatabase.create_loot_weapon(item_id, 0.06)
		var idata := ItemDatabase.get_item_data(item_id)
		var sz := ItemDatabase.get_item_grid_size(item_id)
		var clean_cd := InventoryGrid.sanitize_custom_data(c_data)
		var item_dict := {
			"uid": InventoryGrid.next_uid(),
			"id": item_id,
			"amount": amt,
			"w": sz.x,
			"h": sz.y,
			"custom_data": clean_cd.duplicate(true)
		}
		for pk in InventoryGrid.PRESERVED_CUSTOM_KEYS:
			if clean_cd.has(pk):
				item_dict[pk] = clean_cd[pk]
		InventoryGrid.ensure_container_defaults(item_dict)

		var equip_slot := ItemDatabase.get_item_equip_slot(item_id)
		if equip_slot in ["primary", "sidearm"] and corpse_equipment["primary1"].is_empty():
			corpse_equipment["primary1"] = item_dict
		elif equip_slot == "helmet" and corpse_equipment["helmet"].is_empty():
			corpse_equipment["helmet"] = item_dict
		elif equip_slot == "vest" and corpse_equipment["vest"].is_empty():
			corpse_equipment["vest"] = item_dict
		elif equip_slot == "backpack" and corpse_equipment["backpack"].is_empty():
			corpse_equipment["backpack"] = item_dict
		else:
			bag_drops.append(item_dict)

	# 인간형 적의 착용 방탄복/가방 보강 (루팅 슬롯 분리)
	if corpse_equipment["vest"].is_empty():
		var vest_chance := 0.35 if enemy_type == EnemyType.SCAV else (0.55 if enemy_type == EnemyType.RAIDER else 1.0)
		if randf() < vest_chance:
			var vest_id := "1레벨_방탄복" if enemy_type == EnemyType.SCAV else ("2레벨_방탄복" if enemy_type == EnemyType.RAIDER else "3레벨_방탄복")
			var vsz := ItemDatabase.get_item_grid_size(vest_id)
			var v_item := {"uid": InventoryGrid.next_uid(), "id": vest_id, "amount": 1, "w": vsz.x, "h": vsz.y, "custom_data": {}}
			InventoryGrid.ensure_container_defaults(v_item)
			corpse_equipment["vest"] = v_item

	if corpse_equipment["backpack"].is_empty() and not bag_drops.is_empty():
		var bp_id := "3레벨_가방" if enemy_type == EnemyType.BOSS else ("2레벨_가방" if enemy_type == EnemyType.RAIDER else "1레벨_가방")
		var bsz := ItemDatabase.get_item_grid_size(bp_id)
		var bp_item := {"uid": InventoryGrid.next_uid(), "id": bp_id, "amount": 1, "w": bsz.x, "h": bsz.y, "custom_data": {}}
		InventoryGrid.ensure_container_defaults(bp_item)
		corpse_equipment["backpack"] = bp_item

	# 가방 내부 그리드에 전리품 수납 및 미탐색("unsearched") 마킹
	var overflow_drops: Array = []
	var bp_slot: Dictionary = corpse_equipment.get("backpack", {})
	if not bp_slot.is_empty() and not bag_drops.is_empty():
		var spec := InventoryGrid.get_container_spec(bp_slot)
		var gw := maxi(1, int(spec.get("grid_w", 4)))
		var gh := maxi(1, int(spec.get("grid_h", 4)))
		var tmp_grid := InventoryGrid.new()
		tmp_grid.grid_width = gw
		tmp_grid.grid_height = gh
		tmp_grid._init_grid_map()
		for bd in bag_drops:
			var b_id := str(bd.get("id", ""))
			var b_amt := int(bd.get("amount", 1))
			var rem := tmp_grid.auto_add_item(b_id, b_amt, bd)
			if rem > 0:
				var ov: Dictionary = (bd as Dictionary).duplicate(true)
				ov["amount"] = rem
				overflow_drops.append(ov)
		for git in tmp_grid.items:
			if git is Dictionary and not git.is_empty():
				git["unsearched"] = true
				if not (git.get("custom_data", null) is Dictionary):
					git["custom_data"] = {}
				git["custom_data"]["unsearched"] = true
		InventoryGrid.sync_container_item_contents(bp_slot, tmp_grid)
		tmp_grid.free()
	else:
		overflow_drops = bag_drops

	inv.set_meta("is_corpse", true)
	inv.set_meta("corpse_equipment", corpse_equipment)
	for ov_item in overflow_drops:
		if ov_item is Dictionary:
			inv.add_item(String(ov_item.get("id", "")), int(ov_item.get("amount", 1)), ov_item)

	if scene and "container_inventories" in scene:
		scene.container_inventories[chosen_tile] = inv
		if "container_titles" in scene and scene.container_titles is Dictionary:
			scene.container_titles[chosen_tile] = title

	var box := StaticBody2D.new()
	box.set_script(CorpseBoxScript)
	box.global_position = global_position
	box.call("setup_corpse_box", chosen_tile, inv, title, rank)
	get_parent().call_deferred("add_child", box)

func _on_visuals_draw() -> void:
	var visuals = get_node("Visuals")
	_sync_enemy_pixel_layers(visuals)
	if _hud_overlay:
		_hud_overlay.queue_redraw()

func _on_hud_overlay_draw() -> void:
	if not _hud_overlay:
		return
	var visuals := get_node_or_null("Visuals")
	if not visuals:
		return

	# 은폐 상태(modulate.a < 0.05)일 때 머리 위 느낌표, HP 바까지 일괄 숨김 처리
	if visuals.modulate.a < 0.05:
		return

	var scale_f := _get_type_scale()
	# 머리 위 UI(재장전 게이지, HP 바, ! / ? 경고)는 항상 정방향(회전 무효화) 렌더링
	_hud_overlay.draw_set_transform(Vector2(0.0, -visuals.position.y), -rotation - visuals.rotation, Vector2.ONE)

	# 재장전 게이지 표시 (인간형 무장 적)
	if is_ranged_human and reload_timer > 0:
		var r_w := 24.0
		var r_pos := Vector2(-r_w / 2.0, -18.0 * scale_f - 16.0)
		_hud_overlay.draw_rect(Rect2(r_pos, Vector2(r_w, 3.0)), Color(0.15, 0.15, 0.2, 0.85))
		var r_ratio := clampf(1.0 - (reload_timer / 1.9), 0.0, 1.0)
		_hud_overlay.draw_rect(Rect2(r_pos, Vector2(r_w * r_ratio, 3.0)), Color(1.0, 0.85, 0.25))

	# HP 바 (보스는 상시 표시, 일반 적은 피격 시 표시)
	if (hp < max_hp or enemy_type == EnemyType.BOSS) and hp > 0:
		var bar_w := 38.0 if enemy_type == EnemyType.BOSS else 26.0
		var bar_h := 5.0 if enemy_type == EnemyType.BOSS else 4.0
		var bar_pos := Vector2(-bar_w / 2.0, -18.0 * scale_f - 10.0)
		_hud_overlay.draw_rect(Rect2(bar_pos + Vector2(-1, -1), Vector2(bar_w + 2, bar_h + 2)), Color(0.05, 0.05, 0.08, 0.9))
		_hud_overlay.draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.15, 0.15, 0.18))
		var fill_w := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0) * bar_w
		var bar_col := Color(1.0, 0.75, 0.15) if enemy_type == EnemyType.BOSS else Color(0.9, 0.2, 0.2)
		_hud_overlay.draw_rect(Rect2(bar_pos, Vector2(fill_w, bar_h)), bar_col)

	# 느낌표/물음표 경고 아이콘 (소음 감지 또는 플레이어 발견 시)
	if alert_timer > 0:
		var icon_pos := Vector2(0, -22.0 * scale_f - 12.0)
		var icon_col := Color(1.0, 0.2, 0.2) if alert_icon_type == "!" else Color(1.0, 0.8, 0.2)
		var bg_alpha := clampf(alert_timer, 0.0, 1.0)
		_hud_overlay.draw_circle(icon_pos, 8.0, Color(0.1, 0.1, 0.1, 0.8 * bg_alpha))
		_hud_overlay.draw_arc(icon_pos, 8.0, 0, TAU, 16, icon_col * Color(1, 1, 1, bg_alpha), 1.5)

		if alert_icon_type == "!":
			_hud_overlay.draw_line(icon_pos + Vector2(0, -4), icon_pos + Vector2(0, 1), icon_col * Color(1, 1, 1, bg_alpha), 2.5)
			_hud_overlay.draw_circle(icon_pos + Vector2(0, 4), 1.2, icon_col * Color(1, 1, 1, bg_alpha))
		else:
			_hud_overlay.draw_circle(icon_pos + Vector2(0, 4), 1.2, icon_col * Color(1, 1, 1, bg_alpha))
			_hud_overlay.draw_arc(icon_pos + Vector2(0, -2), 3.0, -PI, 0, 8, icon_col * Color(1, 1, 1, bg_alpha), 2.0)
			_hud_overlay.draw_line(icon_pos + Vector2(3, -2), icon_pos + Vector2(0, 1), icon_col * Color(1, 1, 1, bg_alpha), 2.0)

	_hud_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
