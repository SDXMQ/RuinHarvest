# res://scenes/world/objects/field_objective.gd
extends StaticBody2D

## 레이드 현장 다중 상호작용 퀘스트 오브젝트 (군사 단말기 / 병원 생체 표본 채취기 / 상업 무선 중계기 + 디펜스 웨이브 기믹)

signal defense_wave_triggered(obj_pos: Vector2, obj_kind: int)

const HOLD_DURATION: float = 3.0

enum ObjectiveKind { MILITARY_TERMINAL = 0, HOSPITAL_BIOSAMPLER = 1, COMMERCIAL_RELAY = 2 }

@export var objective_kind: int = ObjectiveKind.MILITARY_TERMINAL
var is_completed: bool = false
var hold_progress: float = 0.0
var interactable_type: Vector2i = Vector2i(8, 2)
var pulse_timer: float = 0.0
var _noise_pulse_timer: float = 0.0
var _wave_spawned: bool = false

var _obj_spr: Sprite2D = null
var _beacon_light: PointLight2D = null
var _last_synced_kind: int = -1

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(32, 32)
	col.shape = rect
	add_child(col)
	_setup_pixel_visuals()

func _setup_pixel_visuals() -> void:
	_obj_spr = Sprite2D.new()
	_obj_spr.name = "ObjectivePixelSprite"
	_obj_spr.centered = true
	_obj_spr.region_enabled = true
	_obj_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_obj_spr.z_index = 0
	if PixelAssetManager:
		var props_tex := PixelAssetManager.get_canvas_texture("props/world_props")
		if props_tex:
			_obj_spr.texture = props_tex
		_obj_spr.material = PixelAssetManager.create_pixel_entity_material(0.26)
	add_child(_obj_spr)

	_beacon_light = PointLight2D.new()
	_beacon_light.name = "BeaconLight"
	_beacon_light.energy = 0.85
	_beacon_light.height = 36.0
	_beacon_light.texture_scale = 1.6
	if PixelAssetManager:
		_beacon_light.texture = PixelAssetManager.get_radial_light_texture()
	add_child(_beacon_light)

	_sync_kind_visuals()

func _get_accent_color() -> Color:
	if objective_kind == ObjectiveKind.HOSPITAL_BIOSAMPLER:
		return Color(0.25, 0.95, 0.55)
	elif objective_kind == ObjectiveKind.COMMERCIAL_RELAY:
		return Color(1.0, 0.72, 0.25)
	return Color(0.2, 0.85, 1.0)

func _get_led_offset() -> Vector2:
	match objective_kind:
		ObjectiveKind.HOSPITAL_BIOSAMPLER:
			return Vector2(0.0, 0.0)
		ObjectiveKind.COMMERCIAL_RELAY:
			return Vector2(11.0, -21.0)
		_:
			return Vector2(11.5, -20.0)

func _sync_kind_visuals() -> void:
	_last_synced_kind = objective_kind
	var col_idx := clampi(objective_kind, 0, 2)
	if _obj_spr:
		_obj_spr.region_rect = Rect2(float(col_idx * 48), 144.0, 48.0, 48.0)
	if _beacon_light:
		_beacon_light.position = _get_led_offset()
		_beacon_light.color = _get_accent_color()

func _process(delta: float) -> void:
	pulse_timer += delta
	if _last_synced_kind != objective_kind:
		_sync_kind_visuals()

	if (_wave_spawned or hold_progress > 0.01) and not is_completed:
		_noise_pulse_timer += delta
		if _noise_pulse_timer >= 0.85:
			_noise_pulse_timer = 0.0
			if EventBus.has_signal("noise_created"):
				EventBus.noise_created.emit(global_position, 420.0, "beacon")
	else:
		_noise_pulse_timer = 0.0

	if _beacon_light:
		if is_completed:
			_beacon_light.color = Color(0.25, 0.95, 0.45)
			_beacon_light.energy = 0.60
		elif _wave_spawned:
			var flash_r := 0.5 + 0.5 * sin(pulse_timer * 16.0)
			_beacon_light.color = Color(1.0, 0.15, 0.12).lerp(Color(1.0, 0.5, 0.15), flash_r)
			_beacon_light.energy = 0.85 + 0.45 * flash_r
		else:
			_beacon_light.color = _get_accent_color()
			_beacon_light.energy = 0.45 + 0.20 * sin(pulse_timer * 4.5)

	queue_redraw()

func get_objective_title() -> String:
	match objective_kind:
		ObjectiveKind.HOSPITAL_BIOSAMPLER:
			return "🧬 병원 생체 표본 채취기 가동"
		ObjectiveKind.COMMERCIAL_RELAY:
			return "📻 상업 지구 무선 중계기 수리"
		_:
			return "📡 군사 기지 전술 단말기 해킹"

func get_prompt_text() -> String:
	return "[E 3초 홀드] %s" % get_objective_title()

func get_compass_icon() -> String:
	match objective_kind:
		ObjectiveKind.HOSPITAL_BIOSAMPLER: return "🧬"
		ObjectiveKind.COMMERCIAL_RELAY: return "📻"
		_: return "📡"

func set_hold_progress(ratio: float) -> void:
	hold_progress = clamp(ratio, 0.0, 1.0)
	if hold_progress >= 0.25 and not _wave_spawned and not is_completed:
		_wave_spawned = true
		defense_wave_triggered.emit(global_position, objective_kind)
		if EventBus.has_signal("noise_created"):
			EventBus.noise_created.emit(global_position, 480.0, "beacon")
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("🚨 [%s] 가동 소음으로 인해 주변 감염체와 무장 병력이 몰려옵니다!" % get_objective_title())
	queue_redraw()

func complete_objective(player_node: Node2D = null) -> bool:
	if is_completed:
		return false
	is_completed = true
	hold_progress = 0.0
	interactable_type = Vector2i(-1, -1)
	
	if GameManager:
		GameManager.raid_landmark_completed = true
		if not GameManager.current_world_data.has("player"):
			GameManager.current_world_data["player"] = {}
		var prev_cnt = int(GameManager.current_world_data["player"].get("field_objectives_completed", 0))
		GameManager.current_world_data["player"]["field_objectives_completed"] = prev_cnt + 1
		
	if player_node and "inventory_grid" in player_node and player_node.inventory_grid:
		var reward_ids: Array[String] = ["암호화된 SSD"]
		if objective_kind == ObjectiveKind.HOSPITAL_BIOSAMPLER:
			reward_ids.append("고급 치료킷")
		elif objective_kind == ObjectiveKind.COMMERCIAL_RELAY:
			reward_ids.append("장거리 무전기")
		var dropped_rewards: Array[String] = []
		for r_id in reward_ids:
			var rem: int = player_node.inventory_grid.auto_add_item(r_id, 1)
			if rem > 0:
				var GroundItemScene = preload("res://scenes/entities/items/ground_item.tscn")
				var g_item = GroundItemScene.instantiate()
				g_item.global_position = player_node.global_position + Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0))
				var cur_scene = get_tree().current_scene if (is_inside_tree() and get_tree()) else null
				var parent_target: Node = null
				if cur_scene:
					parent_target = cur_scene.get_node_or_null("Entities") if cur_scene.has_node("Entities") else cur_scene
				elif get_parent():
					parent_target = get_parent()
				if parent_target:
					parent_target.add_child(g_item)
					g_item.setup(r_id, rem, {})
					dropped_rewards.append(r_id)
				else:
					g_item.free()
		if not dropped_rewards.is_empty() and EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("📦 가방 공간이 부족하여 임무 보상(%s)을 바닥에 드랍했습니다." % ", ".join(dropped_rewards))
		
	if SoundManager:
		SoundManager.play("level_up")
	if EventBus.has_signal("noise_created"):
		EventBus.noise_created.emit(global_position, 320.0, "beacon")
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("★ %s 성공! (암호화된 SSD 확보 & 생존 탈출 시 +15,000 RUB 보너스)" % get_objective_title())
	queue_redraw()
	return true

func _draw() -> void:
	var accent_col := _get_accent_color()

	# 디펜스 웨이브 활성화 바닥 HDR 펄스 링 (빨간색 경고 파동)
	if _wave_spawned and not is_completed:
		var ring_t = clamp(_noise_pulse_timer / 0.85, 0.0, 1.0)
		var ring_rad = lerp(12.0, 140.0, ring_t)
		var ring_alpha = (1.0 - ring_t) * 0.70
		draw_arc(Vector2.ZERO, ring_rad, 0.0, TAU, 36, Color(2.0, 0.25, 0.2, ring_alpha), 2.2)
		var inner_rad = lerp(8.0, 90.0, ring_t)
		draw_arc(Vector2.ZERO, inner_rad, 0.0, TAU, 28, Color(1.8, 0.5, 0.15, ring_alpha * 0.55), 1.4)

	# 지면 남동쪽 드롭 섀도우
	draw_rect(Rect2(-12, -10, 34, 30), Color(0.02, 0.03, 0.05, 0.45))

	# HDR LED 비콘 표시 (안테나 마스트 끝 또는 생체 챔버)
	var led_pos := _get_led_offset()
	var led_col := Color(0.3, 2.2, 0.65) if is_completed else Color(accent_col.r * 2.0, accent_col.g * 2.0, accent_col.b * 2.0)
	var pulse := 0.55 + 0.45 * sin(pulse_timer * 5.0)
	if _wave_spawned and not is_completed:
		var flash_ratio := 0.5 + 0.5 * sin(pulse_timer * 16.0)
		led_col = Color(2.4, 0.2, 0.18).lerp(Color(2.2, 0.65, 0.18), flash_ratio)
		pulse = 0.75 + 0.45 * flash_ratio

	if not is_completed:
		draw_circle(led_pos, 7.5 * pulse, Color(led_col.r, led_col.g, led_col.b, 0.24 * pulse))
	draw_rect(Rect2(led_pos - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), led_col)

	# 홀드 진행 게이지 표시
	if hold_progress > 0.01 and not is_completed:
		var bw = 38.0
		var bh = 5.0
		var bpos = Vector2(-bw * 0.5, -38.0)
		draw_rect(Rect2(bpos + Vector2(-1, -1), Vector2(bw + 2, bh + 2)), Color(0, 0, 0, 0.85))
		draw_rect(Rect2(bpos, Vector2(bw * hold_progress, bh)), accent_col)
