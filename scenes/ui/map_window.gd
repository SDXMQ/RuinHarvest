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
var chunk_minimap_textures: Dictionary = {}
var scale_factor: float = 0.085
var map_pan_offset: Vector2 = Vector2.ZERO
var view_center_world: Vector2 = Vector2.ZERO
var player_ref: Node2D = null
var chunk_manager_ref: Node = null
var recenter_btn: Button = null
var is_panning: bool = false

signal window_closed

func get_or_bake_chunk_texture(cpos: Vector2i, c_data: Dictionary) -> ImageTexture:
	if chunk_minimap_textures.has(cpos):
		return chunk_minimap_textures[cpos] as ImageTexture
	if GameManager and GameManager.raid_map_chunk_cache.has(cpos):
		var cached_tex: ImageTexture = GameManager.raid_map_chunk_cache[cpos] as ImageTexture
		if cached_tex:
			chunk_minimap_textures[cpos] = cached_tex
			return cached_tex
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var base_col := Color(0.13, 0.17, 0.12, 0.5)
	var wall_col := Color(0.38, 0.44, 0.52, 0.9)
	var road_col := Color(0.26, 0.28, 0.30, 0.85)
	var water_col := Color(0.15, 0.30, 0.48, 0.8)
	var tiles: Array = c_data.get("tiles", [])
	var objects: Array = c_data.get("objects", [])
	for ly in range(16):
		for lx in range(16):
			var idx: int = ly * 16 + lx
			var tile_coords: Vector2i = tiles[idx] if idx < tiles.size() else Vector2i(-1, -1)
			var obj_coords: Vector2i = objects[idx] if idx < objects.size() else Vector2i(-1, -1)
			var px_col := base_col
			if TileManager.is_wall(obj_coords) or TileManager.is_door_closed(obj_coords) or TileManager.is_door_open(obj_coords) or TileManager.is_door_locked(obj_coords):
				px_col = wall_col
			elif TileManager.is_road_asphalt(tile_coords) or TileManager.is_sidewalk_tile(tile_coords):
				px_col = road_col
			elif tile_coords == TileManager.TILE_WATER:
				px_col = water_col
			img.set_pixel(lx, ly, px_col)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	chunk_minimap_textures[cpos] = tex
	if GameManager:
		GameManager.raid_map_chunk_cache[cpos] = tex
	return tex

func is_point_in_live_sight(world_pos: Vector2) -> bool:
	var reveal_r: float = GameManager.MAP_REVEAL_RADIUS if GameManager else 420.0
	return player_pos.distance_to(world_pos) <= reveal_r

func is_point_revealed(world_pos: Vector2) -> bool:
	if is_point_in_live_sight(world_pos):
		return true
	return GameManager != null and GameManager.is_world_pos_explored(world_pos)

func setup(pos: Vector2, rot: float, extract_pts: Array, biome: String, boss_node: Node2D = null, airdrops: Array = [], objectives: Array = [], loaded_chunks_dict: Dictionary = {}, p_player_ref: Node2D = null, p_chunk_manager: Node = null) -> void:
	player_pos = pos
	view_center_world = pos
	player_rot = rot
	extraction_points = extract_pts
	current_biome = biome
	boss_entity = boss_node
	airdrop_points = airdrops
	field_objectives_list = objectives
	loaded_chunks = loaded_chunks_dict
	player_ref = p_player_ref
	chunk_manager_ref = p_chunk_manager
	if GameManager:
		GameManager.reveal_map_fog_at(player_pos)
	chunk_minimap_textures.clear()
	if GameManager:
		for cached_cpos in GameManager.raid_map_chunk_cache.keys():
			var c_tex: ImageTexture = GameManager.raid_map_chunk_cache[cached_cpos] as ImageTexture
			if c_tex:
				chunk_minimap_textures[cached_cpos] = c_tex
	for cpos in loaded_chunks.keys():
		var c_data = loaded_chunks[cpos]
		if c_data is Dictionary:
			get_or_bake_chunk_texture(cpos, c_data)
	
	if info_label:
		var explored_cnt: int = GameManager.raid_explored_cells.size() if GameManager else 0
		info_label.text = "현재 위치: (%.1f, %.1f) | 작전 구역: %s | 탐색 구역: %d셀" % [player_pos.x, player_pos.y, current_biome, explored_cnt]
	if map_canvas:
		map_canvas.queue_redraw()

static func get_extraction_lock_info(z_type: int, objectives: Array = []) -> Dictionary:
	if z_type == 1:
		var rubles = 0
		if GameManager and GameManager.current_world_data:
			var p_data = GameManager.current_world_data.get("player", {})
			rubles = int(p_data.get("rubles", GameManager.current_world_data.get("rubles", 0)))
		if rubles < 3000:
			return {"locked": true, "reason": "잠김: 3,000R 필요"}
	elif z_type == 2:
		var obj_done = false
		if GameManager:
			if GameManager.raid_landmark_completed or GameManager.raid_power_restored:
				obj_done = true
			elif bool(GameManager.current_world_data.get("raid_power_restored", false)):
				obj_done = true
			elif int(GameManager.current_world_data.get("player", {}).get("field_objectives_completed", 0)) >= 1:
				obj_done = true
		for obj in objectives:
			if is_instance_valid(obj) and bool(obj.get("is_completed")):
				obj_done = true
				break
		if not obj_done:
			return {"locked": true, "reason": "잠김: 단말기 미해킹"}
	return {"locked": false, "reason": ""}

static func is_vault_intel_unlocked() -> bool:
	if not GameManager or not (GameManager.current_world_data is Dictionary):
		return false
	var w_data: Dictionary = GameManager.current_world_data
	if bool(w_data.get("raid_radio_scanned", false)):
		return true
	if HideoutProgression.get_facility_level(w_data, "intel_center") >= 1:
		return true
	var hideout_fac: Dictionary = w_data.get("hideout", {}).get("facilities", {})
	if int(hideout_fac.get("intel_center", 0)) >= 1:
		return true
	var top_fac: Dictionary = w_data.get("facilities", {})
	if int(top_fac.get("intel_center", 0)) >= 1:
		return true
	return false

static func extract_locked_vault_markers(chunks_dict: Dictionary) -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	for cpos in chunks_dict.keys():
		var c_data = chunks_dict[cpos]
		if not (c_data is Dictionary):
			continue
		var objects: Array = c_data.get("objects", [])
		for ly in range(16):
			for lx in range(16):
				var idx := ly * 16 + lx
				if idx < objects.size() and TileManager.is_door_locked(objects[idx]):
					var wx: int = int(cpos.x) * 16 + lx
					var wy: int = int(cpos.y) * 16 + ly
					var wpos := Vector2(float(wx) * 32.0 + 16.0, float(wy) * 32.0 + 16.0)
					markers.append({
						"tile": Vector2i(wx, wy),
						"pos": wpos,
						"icon": "lock_gold",
						"label": "보안 구역 (무기고/금고)"
					})
	return markers

func _ready() -> void:
	var title_lbl: Label = get_node_or_null("Center/Panel/Title") as Label
	if title_lbl and UiIconManager:
		UiIconManager.set_label_icon(title_lbl, "map", "전술 작전 지도 (Tactical Map)", 18, 6, true)
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
		var panel_parent := close_btn.get_parent()
		if panel_parent and not panel_parent.has_node("RecenterBtn"):
			recenter_btn = Button.new()
			recenter_btn.name = "RecenterBtn"
			if UiIconManager:
				UiIconManager.set_button(recenter_btn, "target_blue", "내 위치", 15)
			else:
				recenter_btn.text = "내 위치"
			recenter_btn.tooltip_text = "내 현재 위치로 지도 중심 이동 (Space)"
			recenter_btn.custom_minimum_size = Vector2(104, 36)
			recenter_btn.layout_mode = 1
			recenter_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			recenter_btn.offset_left = -236.0
			recenter_btn.offset_top = -56.0
			recenter_btn.offset_right = -128.0
			recenter_btn.offset_bottom = -20.0
			recenter_btn.pressed.connect(recenter_on_player)
			panel_parent.add_child(recenter_btn)
	if info_label:
		info_label.offset_right = -246.0
		info_label.clip_text = true
	if map_canvas:
		map_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		map_canvas.draw.connect(_on_map_draw)
		map_canvas.gui_input.connect(_on_map_canvas_gui_input)

func _process(_delta: float) -> void:
	var dirty := false
	if is_instance_valid(player_ref):
		if player_pos != player_ref.global_position or absf(player_rot - player_ref.rotation) > 0.001:
			player_pos = player_ref.global_position
			player_rot = player_ref.rotation
			if GameManager:
				GameManager.reveal_map_fog_at(player_pos)
			dirty = true
	if is_instance_valid(chunk_manager_ref):
		if "loaded_chunks" in chunk_manager_ref:
			loaded_chunks = chunk_manager_ref.loaded_chunks
			dirty = true
	if visible and not extraction_points.is_empty():
		dirty = true
	if info_label and is_instance_valid(player_ref):
		var explored_cnt: int = GameManager.raid_explored_cells.size() if GameManager else 0
		info_label.text = "현재 위치: (%.1f, %.1f) | 작전 구역: %s | 탐색 구역: %d셀" % [player_pos.x, player_pos.y, current_biome, explored_cnt]
	if dirty and map_canvas:
		map_canvas.queue_redraw()

func recenter_on_player() -> void:
	view_center_world = player_pos
	map_pan_offset = Vector2.ZERO
	if map_canvas:
		map_canvas.queue_redraw()

func get_player_screen_pos() -> Vector2:
	var c: Vector2 = (map_canvas.size * 0.5) if map_canvas else Vector2.ZERO
	return c + map_pan_offset + (player_pos - view_center_world) * scale_factor

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

func _draw_map_icon_and_text(ui_font: Font, pos: Vector2, icon_key: String, text_str: String, font_size: int, text_col: Color) -> void:
	var tex: Texture2D = UiIconManager.get_icon(icon_key) if UiIconManager else null
	if tex:
		var sz := float(font_size + 2)
		map_canvas.draw_texture_rect(tex, Rect2(pos.x, pos.y - sz + 2.0, sz, sz), false)
		map_canvas.draw_string(ui_font, Vector2(pos.x + sz + 3.0, pos.y), text_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)
	else:
		map_canvas.draw_string(ui_font, pos, text_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)

func _on_map_draw() -> void:
	var w: float = map_canvas.size.x
	var h: float = map_canvas.size.y
	var center: Vector2 = Vector2(w / 2.0, h / 2.0)
	
	# 1. 전장의 안개(Fog of War) 다크 배경 및 전술 격자선
	map_canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(0.035, 0.048, 0.042, 0.98))
	
	var grid_size = 32.0
	for x in range(0, int(w), int(grid_size)):
		map_canvas.draw_line(Vector2(x, 0), Vector2(x, h), Color(0.11, 0.17, 0.13, 0.32))
	for y in range(0, int(h), int(grid_size)):
		map_canvas.draw_line(Vector2(0, y), Vector2(w, y), Color(0.11, 0.17, 0.13, 0.32))
		
	var map_origin: Vector2 = center + map_pan_offset - view_center_world * scale_factor
	var fog_cell_size: float = GameManager.MAP_FOG_CELL_SIZE if GameManager else 128.0
	var reveal_r: float = GameManager.MAP_REVEAL_RADIUS if GameManager else 420.0

	# 2. 누적 탐색(Fog of War) 기반 지형/도로/건물 개요 렌더링
	for loaded_cpos in loaded_chunks.keys():
		var loaded_data = loaded_chunks[loaded_cpos]
		if loaded_data is Dictionary:
			get_or_bake_chunk_texture(loaded_cpos, loaded_data)

	var chunk_px_size: float = 16.0 * 32.0 * scale_factor # 512 * 0.085 = 43.52px
	var sub_px: float = chunk_px_size * 0.25
	for cpos_key in chunk_minimap_textures.keys():
		var cpos: Vector2i = cpos_key
		var c_wx := float(cpos.x) * 512.0
		var c_wy := float(cpos.y) * 512.0
		var c_scr := map_origin + Vector2(c_wx, c_wy) * scale_factor
		
		# 캔버스 뷰포트 내에 포함되는지 간이 컬링
		if c_scr.x + chunk_px_size < 0 or c_scr.x > w or c_scr.y + chunk_px_size < 0 or c_scr.y > h:
			continue
			
		var chunk_tex: ImageTexture = chunk_minimap_textures[cpos] as ImageTexture
		if not chunk_tex:
			continue
		var any_sub_explored := false
		for fy in range(4):
			for fx in range(4):
				var fog_cell := Vector2i(cpos.x * 4 + fx, cpos.y * 4 + fy)
				var cell_center := Vector2((float(fog_cell.x) + 0.5) * fog_cell_size, (float(fog_cell.y) + 0.5) * fog_cell_size)
				var in_sight: bool = player_pos.distance_to(cell_center) <= reveal_r
				var is_explored: bool = in_sight or (GameManager != null and GameManager.raid_explored_cells.has(fog_cell))
				if not is_explored:
					continue
				any_sub_explored = true
				var sub_rect := Rect2(c_scr.x + float(fx) * sub_px, c_scr.y + float(fy) * sub_px, sub_px, sub_px)
				var src_rect := Rect2(float(fx * 4), float(fy * 4), 4.0, 4.0)
				var tint := Color(1.0, 1.0, 1.0, 1.0) if in_sight else Color(0.52, 0.58, 0.54, 0.85)
				map_canvas.draw_texture_rect_region(chunk_tex, sub_rect, src_rect, tint, false)
		if any_sub_explored:
			map_canvas.draw_rect(Rect2(c_scr, Vector2(chunk_px_size, chunk_px_size)), Color(0.22, 0.32, 0.22, 0.16), false, 1.0)
	
	var ui_font: Font = PixelAssetManager.get_pixel_font_regular() if PixelAssetManager else ThemeDB.fallback_font
	var player_screen: Vector2 = map_origin + player_pos * scale_factor
	map_canvas.draw_arc(player_screen, reveal_r * scale_factor, 0.0, TAU, 48, Color(0.45, 0.85, 0.55, 0.28), 1.2)

	# 3. 은신처(0,0) 및 동심원 거리계
	map_canvas.draw_circle(map_origin, 4.0, Color(0.85, 0.85, 0.2))
	map_canvas.draw_string(ui_font, map_origin + Vector2(6, 4), "은신처 (0,0)", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.85, 0.2, 0.8))
	
	map_canvas.draw_arc(map_origin, 1000.0 * scale_factor, 0, TAU, 36, Color(0.35, 0.45, 0.35, 0.25), 1.0)
	map_canvas.draw_arc(map_origin, 2000.0 * scale_factor, 0, TAU, 48, Color(0.35, 0.45, 0.35, 0.25), 1.0)
	
	# 4. 필드 목표 단말기 (미완료 목표는 탐색 구역 내에서만 표기)
	for obj in field_objectives_list:
		if is_instance_valid(obj):
			if not bool(obj.is_completed) and not is_point_revealed(obj.global_position):
				continue
			var o_pos = map_origin + obj.global_position * scale_factor
			if o_pos.x >= -40 and o_pos.x <= w + 40 and o_pos.y >= -40 and o_pos.y <= h + 40:
				var dist = player_pos.distance_to(obj.global_position)
				var o_col = Color(0.2, 0.95, 0.45) if obj.is_completed else Color(0.2, 0.85, 1.0)
				var o_icon: String = obj.get_compass_icon() if obj.has_method("get_compass_icon") else "signal"
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
				_draw_map_icon_and_text(ui_font, o_pos + obj_label_offset, o_icon, "%s (%.0fm)" % [o_title, dist], 10, o_col)
				
	# 5. 항공 보급품 (에어드랍 크레이트)
	for a_pt in airdrop_points:
		var a_pos = map_origin + a_pt["pos"] * scale_factor
		if a_pos.x >= -40 and a_pos.x <= w + 40 and a_pos.y >= -40 and a_pos.y <= h + 40:
			var dist = player_pos.distance_to(a_pt["pos"])
			map_canvas.draw_rect(Rect2(a_pos - Vector2(5, 5), Vector2(10, 10)), Color(1.0, 0.65, 0.15))
			map_canvas.draw_arc(a_pos, 8.5, 0, TAU, 12, Color(1.0, 0.85, 0.3), 1.5)
			_draw_map_icon_and_text(ui_font, a_pos + Vector2(11, 4), "airdrop", "%s (%.0fm)" % [a_pt.get("name", "보급품"), dist], 10, Color(1.0, 0.75, 0.25))

	# 5-B. 잠긴 특수 건물(경찰서 무기고·병원 금고·군사 벙커) 자물쇠 마커 (무전 스캔 또는 정보 센터 보유 시)
	if is_vault_intel_unlocked():
		var vault_markers := extract_locked_vault_markers(loaded_chunks)
		for vm in vault_markers:
			var v_pos: Vector2 = map_origin + vm["pos"] * scale_factor
			if v_pos.x >= -40 and v_pos.x <= w + 40 and v_pos.y >= -40 and v_pos.y <= h + 40:
				var v_dist := player_pos.distance_to(vm["pos"])
				map_canvas.draw_circle(v_pos, 5.5, Color(0.98, 0.78, 0.18, 0.92))
				map_canvas.draw_arc(v_pos, 8.5, 0, TAU, 14, Color(1.0, 0.9, 0.35), 1.4)
				_draw_map_icon_and_text(ui_font, v_pos + Vector2(10, 4), String(vm.get("icon", "lock_gold")), "%s (%.0fm)" % [vm["label"], v_dist], 10, Color(1.0, 0.88, 0.32))

	# 6. 랜드마크 보스 마커 (탐색된 구역/시야 내에서만 노출)
	if is_instance_valid(boss_entity) and boss_entity.get("hp") != null and boss_entity.hp > 0 and is_point_revealed(boss_entity.global_position):
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
			_draw_map_icon_and_text(ui_font, b_pos + b_label_offset, "skull", "랜드마크 보스 (%.0fm)" % dist, 11, Color(1.0, 0.35, 0.35))

	# 7. 조건부 탈출구 3종 마커 (전장의 안개와 무관하게 상시 펄스 핑 표시)
	var ping_phase := fmod(float(Time.get_ticks_msec()) * 0.0014, 1.0)
	for pt in extraction_points:
		var pt_pos = map_origin + pt["pos"] * scale_factor
		if pt_pos.x >= -60 and pt_pos.x <= w + 60 and pt_pos.y >= -60 and pt_pos.y <= h + 60:
			var z_type = int(pt.get("type", 0))
			var lock_info = get_extraction_lock_info(z_type, field_objectives_list)
			var is_locked: bool = lock_info["locked"]
			var lock_reason: String = lock_info["reason"]
			var z_col = Color(0.2, 1.0, 0.3)
			var ping_base := Color(0.25, 1.0, 0.45)
			var z_tag = "일반"
			if z_type == 1:
				z_col = Color(0.55, 0.55, 0.58, 0.52) if is_locked else Color(1.0, 0.82, 0.15)
				ping_base = Color(1.0, 0.82, 0.20)
				z_tag = "차량"
			elif z_type == 2:
				z_col = Color(0.55, 0.55, 0.58, 0.52) if is_locked else Color(0.2, 0.85, 1.0)
				ping_base = Color(0.25, 0.88, 1.0)
				z_tag = "벙커"
				
			var dist = player_pos.distance_to(pt["pos"])
			var ping_col := Color(ping_base.r, ping_base.g, ping_base.b, (1.0 - ping_phase) * 0.72)
			map_canvas.draw_arc(pt_pos, 11.0 + 16.0 * ping_phase, 0.0, TAU, 20, ping_col, 1.6)
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
				
			var arc_col = Color(0.95, 0.35, 0.35, 0.55) if is_locked else z_col
			map_canvas.draw_arc(pt_pos, 11.0, 0, TAU, 16, arc_col, 1.5)
			var base_text = "[%s] %s (%.0fm)" % [z_tag, pt["name"], dist]
			var base_col = Color(0.72, 0.72, 0.75, 0.65) if is_locked else z_col
			map_canvas.draw_string(ui_font, pt_pos + Vector2(13, 4), base_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, base_col)
			if is_locked and lock_reason != "":
				var base_w = ui_font.get_string_size(base_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
				map_canvas.draw_string(ui_font, pt_pos + Vector2(17.0 + base_w, 4), "[%s]" % lock_reason, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.38, 0.38, 0.85))
			
	# 8. 플레이어 위치 (드래그 팬 및 실시간 이동이 반영된 실제 월드->화면 좌표)
	map_canvas.draw_circle(player_screen, 6.0, Color.RED)
	var forward = Vector2.RIGHT.rotated(player_rot) * 16.0
	map_canvas.draw_line(player_screen, player_screen + forward, Color.YELLOW, 2.5)
	map_canvas.draw_string(ui_font, player_screen + Vector2(10, -6), "내 위치", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.YELLOW)

	# 9. 우상단 전술 범례 (TACTICAL LEGEND) 패널
	var leg_w = 166.0
	var leg_h = 138.0
	var leg_x = w - leg_w - 8.0
	var leg_y = 8.0
	map_canvas.draw_rect(Rect2(leg_x, leg_y, leg_w, leg_h), Color(0.06, 0.09, 0.07, 0.9))
	map_canvas.draw_rect(Rect2(leg_x, leg_y, leg_w, leg_h), Color(0.25, 0.38, 0.25, 0.85), false, 1.0)
	_draw_map_icon_and_text(ui_font, Vector2(leg_x + 8, leg_y + 15), "map", "전술 범례 (LEGEND)", 10, Color(0.65, 0.95, 0.65))
	
	var legend_entries = [
		{"icon": "target_blue", "text": "플레이어"},
		{"icon": "extract", "text": "일반 탈출구 (7s)"},
		{"icon": "vehicle", "text": "차량 탈출 (3,000 R)"},
		{"icon": "bunker", "text": "비상 벙커 (해킹)"},
		{"icon": "signal", "text": "필드 퀘스트 목표"},
		{"icon": "airdrop", "text": "군용 항공 보급품"},
		{"icon": "skull", "text": "랜드마크 보스"}
	]
	var cur_ly = leg_y + 31.0
	for le in legend_entries:
		_draw_map_icon_and_text(ui_font, Vector2(leg_x + 10, cur_ly), String(le["icon"]), String(le["text"]), 9, Color(0.85, 0.9, 0.85))
		cur_ly += 14.5

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE:
			recenter_on_player()
			if get_viewport():
				get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("map") or event.is_action_pressed("pause") or event.physical_keycode == KEY_M or event.keycode == KEY_M or event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE:
			_on_close_pressed()
			if get_viewport():
				get_viewport().set_input_as_handled()

func _on_close_pressed() -> void:
	queue_free()
	window_closed.emit()
