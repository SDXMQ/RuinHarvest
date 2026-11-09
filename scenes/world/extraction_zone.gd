# res://scenes/world/extraction_zone.gd
extends Area2D

enum ExtractionType { DEFAULT = 0, VEHICLE = 1, BUNKER = 2 }

@export var extraction_type: int = ExtractionType.DEFAULT
@export var zone_name: String = "탈출 지점 A"
@export var extract_time: float = 7.0
@export var required_rubles: int = 3000

var current_timer: float = 0.0
var player_inside: bool = false
var player_ref: Node2D = null
var pulse_timer: float = 0.0

signal extract_progress(current: float, max_time: float)
signal extract_cancelled

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	pulse_timer += delta
	queue_redraw()
	
	if player_inside and not get_tree().paused:
		current_timer += delta
		extract_progress.emit(current_timer, extract_time)
		
		if current_timer >= extract_time:
			player_inside = false
			_trigger_extraction()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_ref = body
		
		if extraction_type == ExtractionType.VEHICLE:
			var rubles = 0
			if GameManager and GameManager.current_world_data.has("player"):
				rubles = int(GameManager.current_world_data["player"].get("rubles", 0))
			if rubles < required_rubles:
				if player_ref.has_method("show_floating_text"):
					player_ref.show_floating_text("[%d RUB 필요]" % required_rubles, Color(1.0, 0.8, 0.2))
				if EventBus.has_signal("event_logged"):
					EventBus.event_logged.emit("🚕 탈출 차량 이용 불가: 탑승 비용 %d RUB가 필요합니다! (현재: %d RUB)" % [required_rubles, rubles])
				if SoundManager: SoundManager.play("hit_melee")
				return
		elif extraction_type == ExtractionType.BUNKER:
			var obj_done = false
			if GameManager:
				if GameManager.raid_landmark_completed or GameManager.raid_power_restored:
					obj_done = true
				elif bool(GameManager.current_world_data.get("raid_power_restored", false)):
					obj_done = true
				elif GameManager.current_world_data.has("player") and GameManager.current_world_data["player"].get("field_objectives_completed", 0) >= 1:
					obj_done = true
			if not obj_done:
				if player_ref.has_method("show_floating_text"):
					player_ref.show_floating_text("[벙커 격벽 폐쇄: 필드 목표 완료 필요]", Color(0.2, 0.85, 1.0))
				if EventBus.has_signal("event_logged"):
					EventBus.event_logged.emit("🔒 지하 벙커 탈출구 폐쇄됨: 필드 목표 단말기 1개 이상 가동/해킹 필요!")
				if SoundManager: SoundManager.play("hit_melee")
				return

		player_inside = true
		current_timer = 0.0
		if SoundManager:
			SoundManager.play("menu_select")

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false
		player_ref = null
		current_timer = 0.0
		extract_cancelled.emit()

func _trigger_extraction() -> void:
	if extraction_type == ExtractionType.VEHICLE:
		if GameManager and GameManager.current_world_data.has("player"):
			var cur_rub = int(GameManager.current_world_data["player"].get("rubles", 0))
			if cur_rub < required_rubles:
				if EventBus.has_signal("event_logged"):
					EventBus.event_logged.emit("🚕 탈출 차량 이용 불가: 탑승 비용 %d RUB가 부족합니다! (현재: %d RUB)" % [required_rubles, cur_rub])
				extract_cancelled.emit()
				return
			GameManager.current_world_data["player"]["rubles"] = max(0, cur_rub - required_rubles)
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("🚕 탈출 차량 탑승료 %d RUB 결제 완료." % required_rubles)
	elif extraction_type == ExtractionType.BUNKER:
		var obj_done = false
		if GameManager:
			if GameManager.raid_landmark_completed or GameManager.raid_power_restored:
				obj_done = true
			elif bool(GameManager.current_world_data.get("raid_power_restored", false)):
				obj_done = true
			elif GameManager.current_world_data.has("player") and GameManager.current_world_data["player"].get("field_objectives_completed", 0) >= 1:
				obj_done = true
		if not obj_done:
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("🔒 지하 벙커 탈출구 폐쇄됨: 필드 목표 단말기 1개 이상 가동/해킹 필요!")
			extract_cancelled.emit()
			return
				
	EventBus.extraction_started.emit(zone_name, extract_time)
	if GameManager:
		var items_to_keep = []
		var main_world = get_node_or_null("/root/MainWorld")
		if main_world:
			if main_world.has_method("get_backpack_items"):
				items_to_keep = main_world.get_backpack_items()
			elif main_world.player and main_world.player.inventory_grid:
				for item in main_world.player.inventory_grid.items:
					if item and not item.is_empty():
						items_to_keep.append(item.duplicate(true))
			
			if main_world.player and not main_world.player.equipment.is_empty():
				if not GameManager.current_world_data.has("player"):
					GameManager.current_world_data["player"] = {}
				GameManager.current_world_data["player"]["equipment"] = main_world.player.equipment.duplicate(true)
		elif player_ref and "inventory_grid" in player_ref and player_ref.inventory_grid:
			for item in player_ref.inventory_grid.items:
				if item and not item.is_empty():
					items_to_keep.append(item.duplicate(true))
					
		GameManager.end_raid("survived", items_to_keep)

func _draw() -> void:
	var radius = 64.0
	var col = Color(0.2, 1.0, 0.3) # DEFAULT (헬기/녹색)
	if extraction_type == ExtractionType.VEHICLE:
		col = Color(1.0, 0.82, 0.15) # VEHICLE (차량/호박색)
	elif extraction_type == ExtractionType.BUNKER:
		col = Color(0.2, 0.85, 1.0) # BUNKER (벙커/시안색)

	var pulse = 0.8 + 0.2 * sin(pulse_timer * 3.5)
	draw_circle(Vector2.ZERO, radius, Color(col.r, col.g, col.b, 0.18 * pulse))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 36, Color(col.r, col.g, col.b, 0.85), 2.5)
	
	# 중앙 상징 글리프
	if extraction_type == ExtractionType.VEHICLE:
		# 다이아몬드 (차량)
		var d = 11.0
		var pts = PackedVector2Array([Vector2(0, -d), Vector2(d, 0), Vector2(0, d), Vector2(-d, 0)])
		draw_colored_polygon(pts, col)
		draw_arc(Vector2.ZERO, 16.0, 0, TAU, 16, col, 1.5)
	elif extraction_type == ExtractionType.BUNKER:
		# 육각형 (벙커)
		var pts = PackedVector2Array()
		for i in range(6):
			pts.append(Vector2.RIGHT.rotated(i * TAU / 6.0) * 11.0)
		draw_colored_polygon(pts, col)
		draw_arc(Vector2.ZERO, 17.0, 0, TAU, 18, col, 1.5)
	else:
		# 원형 (헬기장)
		draw_circle(Vector2.ZERO, 7.0, col)
		draw_arc(Vector2.ZERO, 15.0, 0, TAU, 20, col, 1.5)
