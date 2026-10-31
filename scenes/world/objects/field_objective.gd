# res://scenes/world/objects/field_objective.gd
extends StaticBody2D

## 레이드 현장 상호작용 퀘스트 오브젝트 (3.0초 홀드 단말기 해킹 / 무선 비콘 송출)

const HOLD_DURATION: float = 3.0

var is_completed: bool = false
var hold_progress: float = 0.0
var interactable_type: Vector2i = Vector2i(8, 2)
var pulse_timer: float = 0.0

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
	queue_redraw()

func set_hold_progress(ratio: float) -> void:
	hold_progress = clamp(ratio, 0.0, 1.0)
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
		player_node.inventory_grid.auto_add_item("암호화된_SSD", 1)
		
	if SoundManager:
		SoundManager.play("level_up")
	if EventBus.has_signal("noise_created"):
		EventBus.noise_created.emit(global_position, 320.0, "beacon")
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("★ 📡 [현장 임무 완수] 랜드마크 단말기 해킹 성공! (생존 탈출 시 +15,000 RUB 작전 보너스)")
	queue_redraw()
	return true

func _draw() -> void:
	# 단말기 베이스 및 안테나 타워
	draw_rect(Rect2(-16, -14, 32, 28), Color(0.10, 0.13, 0.17, 0.95))
	draw_rect(Rect2(-14, -12, 28, 24), Color(0.18, 0.23, 0.29, 0.95))
	draw_rect(Rect2(-10, -8, 20, 12), Color(0.06, 0.14, 0.18, 0.95))
	
	# 안테나 폴대
	draw_line(Vector2(10, -12), Vector2(10, -28), Color(0.55, 0.62, 0.70), 2.0)
	var led_col = Color(0.25, 0.95, 0.45) if is_completed else Color(0.2, 0.85, 1.0)
	var pulse = 0.5 + 0.5 * sin(pulse_timer * 5.0)
	draw_circle(Vector2(10, -29), 3.2, led_col)
	if not is_completed:
		draw_circle(Vector2(10, -29), 7.5 * pulse, Color(0.2, 0.85, 1.0, 0.35 * pulse))
		
	# 홀드 진행 게이지 표시
	if hold_progress > 0.01 and not is_completed:
		var bw = 38.0
		var bh = 5.0
		var bpos = Vector2(-bw * 0.5, -38.0)
		draw_rect(Rect2(bpos + Vector2(-1, -1), Vector2(bw + 2, bh + 2)), Color(0, 0, 0, 0.85))
		draw_rect(Rect2(bpos, Vector2(bw * hold_progress, bh)), Color(0.25, 0.92, 1.0))
