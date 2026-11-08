# res://scenes/ui/map_window.gd
extends Control

@onready var map_canvas: Control = $Center/Panel/MapCanvas
@onready var info_label: Label = $Center/Panel/InfoLabel
@onready var close_btn: Button = $Center/Panel/CloseBtn

var player_pos: Vector2 = Vector2.ZERO
var player_rot: float = 0.0
var extraction_points: Array = []
var current_biome: String = "주거지"
var boss_entity: Node2D = null
var airdrop_points: Array = []
var field_objectives_list: Array = []
var loaded_chunks: Dictionary = {}
var scale_factor: float = 0.085
var map_pan_offset: Vector2 = Vector2.ZERO
var is_panning: bool = false

signal window_closed

func setup(pos: Vector2, rot: float, extract_pts: Array, biome: String, boss_node: Node2D = null, airdrops: Array = [], objectives: Array = [], loaded_chunks_dict: Dictionary = {}) -> void:
	player_pos = pos
	player_rot = rot
	extraction_points = extract_pts
	current_biome = biome
	boss_entity = boss_node
	airdrop_points = airdrops
	field_objectives_list = objectives
	loaded_chunks = loaded_chunks_dict
	
	if info_label:
		info_label.text = "현재 위치: (%.1f, %.1f) | 작전 구역: %s | 로드 청크: %d개" % [player_pos.x, player_pos.y, current_biome, loaded_chunks.size()]
	if map_canvas:
		map_canvas.queue_redraw()

func _ready() -> void:
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
	if map_canvas:
		map_canvas.draw.connect(_on_map_draw)
		map_canvas.gui_input.connect(_on_map_canvas_gui_input)

func _on_map_canvas_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			scale_factor = clamp(scale_factor * 1.15, 0.05, 0.28)
			map_canvas.queue_redraw()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			scale_factor = clamp(scale_factor / 1.15, 0.05, 0.28)
			map_canvas.queue_redraw()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = event.pressed
			accept_event()
	elif event is InputEventMouseMotion and is_panning:
		map_pan_offset += event.relative
		map_canvas.queue_redraw()
		accept_event()

func _on_map_draw() -> void:
	var w = map_canvas.size.x
	var h = map_canvas.size.y
	var center = Vector2(w / 2.0, h / 2.0)
	
	# 1. 지도 배경 및 전술 격자선
	map_canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(0.09, 0.12, 0.10, 0.96))
	
	var grid_size = 32.0
	for x in range(0, int(w), int(grid_size)):
		map_canvas.draw_line(Vector2(x, 0), Vector2(x, h), Color(0.18, 0.26, 0.18, 0.35))
	for y in range(0, int(h), int(grid_size)):
		map_canvas.draw_line(Vector2(0, y), Vector2(w, y), Color(0.18, 0.26, 0.18, 0.35))
		
	var map_origin = center + map_pan_offset - player_pos * scale_factor

	# 2. 로드된 청크 지형/도로/건물 개요 렌더링
	var chunk_px_size = 16.0 * 32.0 * scale_factor # 512 * 0.085 = 43.52px
	for cpos in loaded_chunks.keys():
		var c_data = loaded_chunks[cpos]
		var c_wx = cpos.x * 512.0
		var c_wy = cpos.y * 512.0
		var c_scr = map_origin + Vector2(c_wx, c_wy) * scale_factor
		
		# 캔버스 뷰포트 내에 포함되는지 간이 컬링
		if c_scr.x + chunk_px_size < 0 or c_scr.x > w or c_scr.y + chunk_px_size < 0 or c_scr.y > h:
			continue
			
		# 청크 기본 바닥 영역
		map_canvas.draw_rect(Rect2(c_scr, Vector2(chunk_px_size, chunk_px_size)), Color(0.13, 0.17, 0.12, 0.5))
		map_canvas.draw_rect(Rect2(c_scr, Vector2(chunk_px_size, chunk_px_size)), Color(0.22, 0.32, 0.22, 0.2), false, 1.0)
		
		var tiles = c_data.get("tiles", [])
		var objects = c_data.get("objects", [])
		var cell_w = 32.0 * scale_factor
		
		# 도로 및 건물 타일 전술 개요도 렌더링
		for ly in range(16):
			for lx in range(16):
				var idx = ly * 16 + lx
				var tile_coords = tiles[idx] if idx < tiles.size() else Vector2i(-1, -1)
				var obj_coords = objects[idx] if idx < objects.size() else Vector2i(-1, -1)
				var t_scr = c_scr + Vector2(lx * cell_w, ly * cell_w)
				var t_sz = Vector2(cell_w + 0.3, cell_w + 0.3)
				
				if obj_coords == TileManager.OBJ_WALL or obj_coords == TileManager.OBJ_DOOR_CLOSED or obj_coords == TileManager.OBJ_DOOR_OPEN or obj_coords == TileManager.OBJ_DOOR_LOCKED:
					map_canvas.draw_rect(Rect2(t_scr, t_sz), Color(0.38, 0.44, 0.52, 0.9)) # 건물 구조체
				elif tile_coords == TileManager.TILE_ROAD or tile_coords == TileManager.TILE_ROAD_LINE or tile_coords == TileManager.TILE_ROAD_LINE_H or tile_coords == TileManager.TILE_CROSSWALK or tile_coords == TileManager.TILE_CONCRETE:
					map_canvas.draw_rect(Rect2(t_scr, t_sz), Color(0.26, 0.28, 0.30, 0.85)) # 도로/아스팔트
				elif tile_coords == TileManager.TILE_WATER:
					map_canvas.draw_rect(Rect2(t_scr, t_sz), Color(0.15, 0.30, 0.48, 0.8)) # 수역
	
	# 3. 은신처(0,0) 및 동심원 거리계
	map_canvas.draw_circle(map_origin, 4.0, Color(0.85, 0.85, 0.2))
	map_canvas.draw_string(ThemeDB.fallback_font, map_origin + Vector2(6, 4), "은신처 (0,0)", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.85, 0.2, 0.8))
	
	map_canvas.draw_arc(map_origin, 1000.0 * scale_factor, 0, TAU, 36, Color(0.35, 0.45, 0.35, 0.25), 1.0)
	map_canvas.draw_arc(map_origin, 2000.0 * scale_factor, 0, TAU, 48, Color(0.35, 0.45, 0.35, 0.25), 1.0)
	
	# 4. 필드 목표 단말기 (퀘스트 오브젝트)
	for obj in field_objectives_list:
		if is_instance_valid(obj):
			var o_pos = map_origin + obj.global_position * scale_factor
			if o_pos.x >= -40 and o_pos.x <= w + 40 and o_pos.y >= -40 and o_pos.y <= h + 40:
				var dist = player_pos.distance_to(obj.global_position)
				var o_col = Color(0.2, 0.95, 0.45) if obj.is_completed else Color(0.2, 0.85, 1.0)
				var o_icon = obj.get_compass_icon() if obj.has_method("get_compass_icon") else "📡"
				var o_title = obj.get_objective_title() if obj.has_method("get_objective_title") else "단말기"
				if obj.is_completed:
					o_title += " [완료]"
				map_canvas.draw_circle(o_pos, 6.0, o_col)
				map_canvas.draw_arc(o_pos, 9.5, 0, TAU, 16, o_col, 1.5)
				var obj_label_offset = Vector2(11, 4)
				if is_instance_valid(boss_entity) and boss_entity.get("hp") != null and boss_entity.hp > 0:
					var b_pos = map_origin + boss_entity.global_position * scale_factor
					if o_pos.distance_to(b_pos) < 32.0:
						obj_label_offset = Vector2(11, 14)
				map_canvas.draw_string(ThemeDB.fallback_font, o_pos + obj_label_offset, "%s %s (%.0fm)" % [o_icon, o_title, dist], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, o_col)
				
	# 5. 항공 보급품 (에어드랍 크레이트)
	for a_pt in airdrop_points:
		var a_pos = map_origin + a_pt["pos"] * scale_factor
		if a_pos.x >= -40 and a_pos.x <= w + 40 and a_pos.y >= -40 and a_pos.y <= h + 40:
			var dist = player_pos.distance_to(a_pt["pos"])
			map_canvas.draw_rect(Rect2(a_pos - Vector2(5, 5), Vector2(10, 10)), Color(1.0, 0.65, 0.15))
			map_canvas.draw_arc(a_pos, 8.5, 0, TAU, 12, Color(1.0, 0.85, 0.3), 1.5)
			map_canvas.draw_string(ThemeDB.fallback_font, a_pos + Vector2(11, 4), "🪂 %s (%.0fm)" % [a_pt.get("name", "보급품"), dist], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.75, 0.25))

	# 6. 랜드마크 보스 마커
	if is_instance_valid(boss_entity) and boss_entity.get("hp") != null and boss_entity.hp > 0:
		var b_pos = map_origin + boss_entity.global_position * scale_factor
		if b_pos.x >= -40 and b_pos.x <= w + 40 and b_pos.y >= -40 and b_pos.y <= h + 40:
			var dist = player_pos.distance_to(boss_entity.global_position)
			map_canvas.draw_circle(b_pos, 7.5, Color(1.0, 0.15, 0.15, 0.9))
			map_canvas.draw_arc(b_pos, 11.5, 0, TAU, 16, Color(1.0, 0.35, 0.35), 1.8)
			var b_label_offset = Vector2(13, 4)
			for obj in field_objectives_list:
				if is_instance_valid(obj):
					var o_pos = map_origin + obj.global_position * scale_factor
					if b_pos.distance_to(o_pos) < 32.0:
						b_label_offset = Vector2(13, -10)
						break
			map_canvas.draw_string(ThemeDB.fallback_font, b_pos + b_label_offset, "💀 랜드마크 보스 (%.0fm)" % dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.35, 0.35))

	# 7. 조건부 탈출구 3종 마커 (일반 / 차량 / 벙커)
	for pt in extraction_points:
		var pt_pos = map_origin + pt["pos"] * scale_factor
		if pt_pos.x >= -60 and pt_pos.x <= w + 60 and pt_pos.y >= -60 and pt_pos.y <= h + 60:
			var z_type = pt.get("type", 0)
			var z_col = Color(0.2, 1.0, 0.3)
			var z_tag = "일반"
			if z_type == 1:
				z_col = Color(1.0, 0.82, 0.15)
				z_tag = "차량(3천R)"
			elif z_type == 2:
				z_col = Color(0.2, 0.85, 1.0)
				z_tag = "벙커(해킹필요)"
				
			var dist = player_pos.distance_to(pt["pos"])
			if z_type == 1:
				var pts = PackedVector2Array([pt_pos + Vector2(0, -7), pt_pos + Vector2(7, 0), pt_pos + Vector2(0, 7), pt_pos + Vector2(-7, 0)])
				map_canvas.draw_colored_polygon(pts, z_col)
			elif z_type == 2:
				var pts = PackedVector2Array()
				for vi in range(6):
					pts.append(pt_pos + Vector2.RIGHT.rotated(vi * TAU / 6.0) * 7.5)
				map_canvas.draw_colored_polygon(pts, z_col)
			else:
				map_canvas.draw_circle(pt_pos, 7.0, z_col)
				
			map_canvas.draw_arc(pt_pos, 11.0, 0, TAU, 16, z_col, 1.5)
			var label_text = "[%s] %s (%.0fm)" % [z_tag, pt["name"], dist]
			map_canvas.draw_string(ThemeDB.fallback_font, pt_pos + Vector2(13, 4), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, z_col)
			
	# 8. 플레이어 위치 (중앙, 노란색 시선 화살표)
	map_canvas.draw_circle(center, 6.0, Color.RED)
	var forward = Vector2.RIGHT.rotated(player_rot) * 16.0
	map_canvas.draw_line(center, center + forward, Color.YELLOW, 2.5)
	map_canvas.draw_string(ThemeDB.fallback_font, center + Vector2(10, -6), "내 위치", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.YELLOW)

	# 9. 우상단 전술 범례 (TACTICAL LEGEND) 패널
	var leg_w = 154.0
	var leg_h = 136.0
	var leg_x = w - leg_w - 8.0
	var leg_y = 8.0
	map_canvas.draw_rect(Rect2(leg_x, leg_y, leg_w, leg_h), Color(0.06, 0.09, 0.07, 0.9))
	map_canvas.draw_rect(Rect2(leg_x, leg_y, leg_w, leg_h), Color(0.25, 0.38, 0.25, 0.85), false, 1.0)
	map_canvas.draw_string(ThemeDB.fallback_font, Vector2(leg_x + 8, leg_y + 15), "■ 전술 범례 (LEGEND)", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.65, 0.95, 0.65))
	
	var legend_entries = [
		{"col": Color.YELLOW, "text": "▲ 플레이어"},
		{"col": Color(0.2, 1.0, 0.3), "text": "● 일반 탈출구 (7s)"},
		{"col": Color(1.0, 0.82, 0.15), "text": "◆ 차량 탈출 (3,000 R)"},
		{"col": Color(0.2, 0.85, 1.0), "text": "⬢ 비상 벙커 (해킹)"},
		{"col": Color(0.2, 0.85, 1.0), "text": "📡 필드 퀘스트 목표"},
		{"col": Color(1.0, 0.65, 0.15), "text": "🪂 군용 항공 보급품"},
		{"col": Color(1.0, 0.2, 0.2), "text": "💀 랜드마크 보스"}
	]
	var cur_ly = leg_y + 30.0
	for le in legend_entries:
		map_canvas.draw_circle(Vector2(leg_x + 12, cur_ly - 3), 3.0, le["col"])
		map_canvas.draw_string(ThemeDB.fallback_font, Vector2(leg_x + 22, cur_ly), le["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.85, 0.9, 0.85))
		cur_ly += 14.5

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("map") or event.is_action_pressed("pause") or (event is InputEventKey and event.physical_keycode == KEY_M and event.pressed)):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func _on_close_pressed() -> void:
	get_tree().paused = false
	queue_free()
	window_closed.emit()
