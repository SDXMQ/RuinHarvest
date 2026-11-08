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

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(32, 32)
	col.shape = rect
	add_child(col)

func _process(delta: float) -> void:
	pulse_timer += delta
	if (_wave_spawned or hold_progress > 0.01) and not is_completed:
		_noise_pulse_timer += delta
		if _noise_pulse_timer >= 0.85:
			_noise_pulse_timer = 0.0
			if EventBus.has_signal("noise_created"):
				EventBus.noise_created.emit(global_position, 420.0, "beacon")
	else:
		_noise_pulse_timer = 0.0
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
		player_node.inventory_grid.auto_add_item("암호화된 SSD", 1)
		if objective_kind == ObjectiveKind.HOSPITAL_BIOSAMPLER:
			player_node.inventory_grid.auto_add_item("고급 치료킷", 1)
		elif objective_kind == ObjectiveKind.COMMERCIAL_RELAY:
			player_node.inventory_grid.auto_add_item("장거리 무전기", 1)
		
	if SoundManager:
		SoundManager.play("level_up")
	if EventBus.has_signal("noise_created"):
		EventBus.noise_created.emit(global_position, 320.0, "beacon")
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("★ %s 성공! (암호화된 SSD 확보 & 생존 탈출 시 +15,000 RUB 보너스)" % get_objective_title())
	queue_redraw()
	return true

func _draw() -> void:
	var accent_col = Color(0.2, 0.85, 1.0)
	if objective_kind == ObjectiveKind.HOSPITAL_BIOSAMPLER:
		accent_col = Color(0.25, 0.95, 0.55)
	elif objective_kind == ObjectiveKind.COMMERCIAL_RELAY:
		accent_col = Color(1.0, 0.72, 0.25)

	# 디펜스 웨이브 활성화 바닥 펄스 링 (빨간색 경고 파동)
	if _wave_spawned and not is_completed:
		var ring_t = clamp(_noise_pulse_timer / 0.85, 0.0, 1.0)
		var ring_rad = lerp(12.0, 140.0, ring_t)
		var ring_alpha = (1.0 - ring_t) * 0.65
		draw_arc(Vector2.ZERO, ring_rad, 0.0, TAU, 36, Color(1.0, 0.2, 0.2, ring_alpha), 2.5)
		# 내부 보조 링
		var inner_rad = lerp(8.0, 90.0, ring_t)
		draw_arc(Vector2.ZERO, inner_rad, 0.0, TAU, 28, Color(1.0, 0.4, 0.1, ring_alpha * 0.5), 1.5)

	# 단말기 베이스 및 안테나/챔버 타워
	draw_rect(Rect2(-16, -14, 32, 28), Color(0.10, 0.13, 0.17, 0.95))
	draw_rect(Rect2(-14, -12, 28, 24), Color(0.18, 0.23, 0.29, 0.95))
	draw_rect(Rect2(-10, -8, 20, 12), accent_col.darkened(0.65))
	
	# 안테나 폴대
	draw_line(Vector2(10, -12), Vector2(10, -28), Color(0.55, 0.62, 0.70), 2.0)
	var led_col = Color(0.25, 0.95, 0.45) if is_completed else accent_col
	var pulse = 0.5 + 0.5 * sin(pulse_timer * 5.0)
	
	if _wave_spawned and not is_completed:
		var flash_ratio = 0.5 + 0.5 * sin(pulse_timer * 16.0)
		led_col = Color(1.0, 0.1, 0.1).lerp(Color(1.0, 0.45, 0.1), flash_ratio)
		pulse = 0.7 + 0.5 * flash_ratio

	draw_circle(Vector2(10, -29), 3.2, led_col)
	if not is_completed:
		draw_circle(Vector2(10, -29), 8.0 * pulse, Color(led_col.r, led_col.g, led_col.b, 0.4 * pulse))
		
	# 홀드 진행 게이지 표시
	if hold_progress > 0.01 and not is_completed:
		var bw = 38.0
		var bh = 5.0
		var bpos = Vector2(-bw * 0.5, -38.0)
		draw_rect(Rect2(bpos + Vector2(-1, -1), Vector2(bw + 2, bh + 2)), Color(0, 0, 0, 0.85))
		draw_rect(Rect2(bpos, Vector2(bw * hold_progress, bh)), accent_col)
