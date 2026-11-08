# res://scenes/entities/projectiles/bullet.gd
extends Area2D

@export var speed: float = 720.0
@export var damage: float = 25.0
@export var max_lifetime: float = 2.5

var direction: Vector2 = Vector2.RIGHT
var traveled_time: float = 0.0
var traveled_dist: float = 0.0
var max_range: float = 650.0
var penetration: int = 1
var pierce_count: int = 0
var shooter_group: String = "player"
var hit_targets: Array = []

func setup(pos: Vector2, dir: Vector2, dmg: float, p_range: float = 650.0, p_penetration: int = 1, p_shooter_group: String = "player", p_speed: float = 720.0) -> void:
	global_position = pos
	direction = dir.normalized()
	rotation = direction.angle()
	damage = dmg
	max_range = max(180.0, p_range)
	penetration = p_penetration
	shooter_group = p_shooter_group
	speed = p_speed
	queue_redraw()

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	var step = speed * delta
	global_position += direction * step
	traveled_dist += step
	traveled_time += delta
	if traveled_dist >= max_range or traveled_time >= max_lifetime:
		queue_free()

func _get_effective_damage() -> float:
	var falloff_start = max_range * 0.7
	if traveled_dist <= falloff_start:
		return damage
	var t = clamp((traveled_dist - falloff_start) / max(1.0, max_range - falloff_start), 0.0, 1.0)
	return damage * lerp(1.0, 0.55, t)

static func compute_armor_damage_multiplier(pen: float, target_armor_val: float) -> float:
	if target_armor_val <= 0.0 or pen >= target_armor_val:
		return 1.0
	var deficit_ratio = clamp((target_armor_val - pen) / target_armor_val, 0.0, 1.0)
	return clamp(1.0 - deficit_ratio * 0.60, 0.40, 1.0)

func _on_body_entered(body: Node2D) -> void:
	if body in hit_targets:
		return
	if shooter_group == "player" and body.is_in_group("player"):
		return
	if shooter_group == "enemies" and body.is_in_group("enemies"):
		# 인간형 적(Scav/Raider/Boss)이 쏜 총알은 감염체(좀비)를 타격 가능 (AI vs AI 교전)
		if body.get("is_ranged_human") == true:
			return
		
	if shooter_group == "enemies" and body.is_in_group("player"):
		hit_targets.append(body)
		var eff_dmg = _get_effective_damage()
		EventBus.player_damaged.emit(eff_dmg, "gunshot")
		if EventBus.has_signal("player_hit_direction"):
			EventBus.player_hit_direction.emit(global_position)
		var ps = get_tree().current_scene.get_node_or_null("ParticleSystem") if get_tree() and get_tree().current_scene else null
		if ps:
			ps.emit("blood", global_position.x, global_position.y, 5)
		queue_free()
		return
		
	if body.has_method("take_damage"):
		hit_targets.append(body)
		var eff_dmg = _get_effective_damage()
		# 적 방어력(armor_value: 스캐브 15 / 레이더 30 / 보스 45) 대비 탄종 관통력(penetration) 상성 연산
		var target_armor_val: float = 0.0
		if body.get("armor_value") != null:
			target_armor_val = float(body.get("armor_value"))
		elif body.get("armor_tier") != null:
			target_armor_val = float(int(body.get("armor_tier")) * 15)
		var armor_mult = compute_armor_damage_multiplier(float(penetration), target_armor_val)
		if armor_mult < 0.999:
			eff_dmg *= armor_mult
			var ps = get_tree().current_scene.get_node_or_null("ParticleSystem") if get_tree() and get_tree().current_scene else null
			if ps: ps.emit("spark", global_position.x, global_position.y, 5)
			if SoundManager: SoundManager.play("armor_ricochet", 0.7)
		body.take_damage(eff_dmg, direction)
		# 고관통 대구경 탄환(관통력 30 이상: 7.62mm, 12게이지 슬러그 등)은 장갑을 완전 관통했을 때 후방 적 1기 추가 타격
		if penetration >= 30 and float(penetration) >= target_armor_val and pierce_count < 1:
			pierce_count += 1
			damage *= 0.6
		else:
			queue_free()
	elif body is TileMapLayer:
		var layer = body as TileMapLayer
		var hit_tile_pos = layer.local_to_map(global_position + direction * 4.0)
		var coords = layer.get_cell_atlas_coords(hit_tile_pos)
		if coords == TileManager.OBJ_WINDOW:
			layer.set_cell(hit_tile_pos, 0, TileManager.OBJ_WINDOW_BROKEN)
			EventBus.noise_created.emit(global_position, 400.0, "break")
			EventBus.window_broken.emit(hit_tile_pos)
			EventBus.event_logged.emit("💥 총격으로 창문이 깨졌습니다!")
			if SoundManager: SoundManager.play("hit_melee")
			var ps = get_tree().current_scene.get_node_or_null("ParticleSystem") if get_tree() and get_tree().current_scene else null
			if ps: ps.emit("spark", global_position.x, global_position.y, 6)
			if penetration < 8:
				queue_free()
		else:
			var ps = get_tree().current_scene.get_node_or_null("ParticleSystem") if get_tree() and get_tree().current_scene else null
			if ps: ps.emit("spark", global_position.x, global_position.y, 3)
			queue_free()
	elif body is StaticBody2D:
		var ps = get_tree().current_scene.get_node_or_null("ParticleSystem") if get_tree() and get_tree().current_scene else null
		if ps: ps.emit("spark", global_position.x, global_position.y, 4)
		queue_free()

func _draw() -> void:
	if shooter_group == "enemies":
		# 적군 사격 예광탄 (주황/붉은색)
		draw_line(Vector2(-10, 0), Vector2(6, 0), Color(1.0, 0.35, 0.15, 0.9), 2.5)
		draw_circle(Vector2(6, 0), 2.0, Color(1.0, 0.8, 0.6))
	else:
		# 아군 예광탄 (노란색 일반탄 / 청백색 고관통탄 구분)
		var trail_col = Color(0.6, 0.9, 1.0, 0.95) if penetration >= 25 else Color(1.0, 0.9, 0.3, 0.95)
		draw_line(Vector2(-12, 0), Vector2(6, 0), trail_col, 2.5)
		draw_circle(Vector2(6, 0), 2.0, Color.WHITE)
