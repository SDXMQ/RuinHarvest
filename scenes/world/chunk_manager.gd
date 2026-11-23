# res://scenes/world/chunk_manager.gd
extends Node

## 플레이어 위치 기반 청크 동적 로딩 및 TileMapLayer 렌더링 (바닥, 그림자/데코, 수면/수풀 셰이더, 오브젝트, 부드러운 지붕 페이드) + 월드 델타 보존
const CHUNK_SIZE: int = 16
const TILE_SIZE: int = 32

const WaterFoliageShader = preload("res://graphics/shaders/water_foliage.gdshader")
const CarScene = preload("res://scenes/world/objects/car.tscn")

var loaded_chunks: Dictionary = {}
var active_chunks: Array[Vector2i] = []
var pending_chunk_queue: Array[Vector2i] = []
var chunk_deltas: Dictionary = {} # tile_pos (Vector2i) -> atlas_coords (Vector2i)
var render_distance: int = 4

var generator: WorldGenerator

var ground_layer: TileMapLayer
var water_fx_layer: TileMapLayer
var deco_shadow_layer: TileMapLayer
var object_shadow_layer: TileMapLayer
var object_layer: TileMapLayer
var foliage_fx_layer: TileMapLayer
var roof_layer: TileMapLayer
var roof_fade_out_layer: TileMapLayer
var roof_fade_in_layer: TileMapLayer
var door_indicator_overlay: Node2D
var _door_tiles: Dictionary = {} # tile_pos (Vector2i) -> atlas_coords (Vector2i)

var _water_mat: ShaderMaterial
var _foliage_mat: ShaderMaterial
var _last_rain_fx: float = -1.0
var _last_wind_fx: float = -1.0

var chunk_entities: Dictionary = {} # chunk_pos (Vector2i) -> Array[Node]

# 현재 플레이어가 들어가 있는 건물 정보 및 지붕 페이드 트윈
var current_inside_building: Dictionary = {}
var hidden_roof_cells: Array[Vector2i] = []
var _fading_in_cells: Array[Vector2i] = []
var _fade_out_tween: Tween = null
var _fade_in_tween: Tween = null
var _last_player_tile: Vector2i = Vector2i(999999, 999999)
var _last_player_chunk: Vector2i = Vector2i(999999, 999999)

signal chunk_loaded(chunk_pos: Vector2i, data: Dictionary)
signal chunk_unloaded(chunk_pos: Vector2i)

static func _tile_hash(wx: int, wy: int, salt: int = 0) -> float:
	var h: int = (wx * 73856093) ^ (wy * 19349663) ^ (salt * 83492791)
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	h = (h ^ (h >> 16)) & 0xFFFF
	return float(h) / 65535.0

static func _is_structure_wall(coords: Vector2i) -> bool:
	return TileManager.is_structure_wall_line(coords)

static func _casts_oval_shadow(coords: Vector2i) -> bool:
	return coords == TileManager.OBJ_TREE or TileManager.casts_oval_shadow(coords)

func _ready() -> void:
	# WorldGenerator 초기화
	generator = WorldGenerator.new(randi())
	if GameManager and GameManager.current_world_data.has("chunk_deltas"):
		chunk_deltas = GameManager.current_world_data["chunk_deltas"].duplicate()

	# 동적으로 TileMapLayer 계층 생성
	ground_layer = TileMapLayer.new()
	ground_layer.name = "GroundLayer"
	ground_layer.z_index = -10
	add_child(ground_layer)

	_water_mat = ShaderMaterial.new()
	_water_mat.shader = WaterFoliageShader
	_water_mat.set_shader_parameter("effect_mode", 0)
	_water_mat.set_shader_parameter("rain_intensity", 0.0)

	water_fx_layer = TileMapLayer.new()
	water_fx_layer.name = "WaterFxLayer"
	water_fx_layer.z_index = -9
	water_fx_layer.collision_enabled = false
	water_fx_layer.occlusion_enabled = false
	water_fx_layer.material = _water_mat
	add_child(water_fx_layer)

	deco_shadow_layer = TileMapLayer.new()
	deco_shadow_layer.name = "DecoShadowLayer"
	deco_shadow_layer.z_index = -5
	deco_shadow_layer.collision_enabled = false
	deco_shadow_layer.occlusion_enabled = false
	add_child(deco_shadow_layer)

	object_shadow_layer = TileMapLayer.new()
	object_shadow_layer.name = "ObjectShadowLayer"
	object_shadow_layer.z_index = -4
	object_shadow_layer.position = Vector2(5.0, 6.0)
	object_shadow_layer.collision_enabled = false
	object_shadow_layer.occlusion_enabled = false
	add_child(object_shadow_layer)

	object_layer = TileMapLayer.new()
	object_layer.name = "ObjectLayer"
	object_layer.z_index = 0
	object_layer.y_sort_enabled = true # y-sorting 활성화
	add_child(object_layer)

	_foliage_mat = ShaderMaterial.new()
	_foliage_mat.shader = WaterFoliageShader
	_foliage_mat.set_shader_parameter("effect_mode", 1)
	_foliage_mat.set_shader_parameter("wind_strength", 0.65)
	_foliage_mat.set_shader_parameter("tile_v_range", Vector2(32.0 / 192.0, 64.0 / 192.0))

	foliage_fx_layer = TileMapLayer.new()
	foliage_fx_layer.name = "FoliageFxLayer"
	foliage_fx_layer.z_index = 0
	foliage_fx_layer.y_sort_enabled = true
	foliage_fx_layer.collision_enabled = false
	foliage_fx_layer.occlusion_enabled = false
	foliage_fx_layer.material = _foliage_mat
	add_child(foliage_fx_layer)

	roof_layer = TileMapLayer.new()
	roof_layer.name = "RoofLayer"
	roof_layer.z_index = 10 # 플레이어 및 오브젝트 위를 덮는 지붕 레이어
	add_child(roof_layer)

	roof_fade_out_layer = TileMapLayer.new()
	roof_fade_out_layer.name = "RoofFadeOutLayer"
	roof_fade_out_layer.z_index = 10
	roof_fade_out_layer.collision_enabled = false
	roof_fade_out_layer.occlusion_enabled = false
	add_child(roof_fade_out_layer)

	roof_fade_in_layer = TileMapLayer.new()
	roof_fade_in_layer.name = "RoofFadeInLayer"
	roof_fade_in_layer.z_index = 10
	roof_fade_in_layer.collision_enabled = false
	roof_fade_in_layer.occlusion_enabled = false
	add_child(roof_fade_in_layer)

	# TileManager에서 생성된 픽셀 타일셋 할당
	var ts = TileManager.get_tileset()
	if ts:
		ground_layer.tile_set = ts
		water_fx_layer.tile_set = ts
		deco_shadow_layer.tile_set = ts
		object_shadow_layer.tile_set = ts
		object_layer.tile_set = ts
		foliage_fx_layer.tile_set = ts
		roof_layer.tile_set = ts
		roof_fade_out_layer.tile_set = ts
		roof_fade_in_layer.tile_set = ts
		if ts.get_source_count() > 0:
			var atlas_src := ts.get_source(0) as TileSetAtlasSource
			if atlas_src and atlas_src.texture:
				var tex_h := float(atlas_src.texture.get_height())
				if tex_h > 0.0:
					_foliage_mat.set_shader_parameter("tile_v_range", Vector2(32.0 / tex_h, 64.0 / tex_h))

	if EventBus.has_signal("door_toggled"):
		EventBus.door_toggled.connect(_on_door_toggled)
	if EventBus.has_signal("window_broken"):
		EventBus.window_broken.connect(_on_window_broken)

	door_indicator_overlay = Node2D.new()
	door_indicator_overlay.name = "DoorIndicatorOverlay"
	door_indicator_overlay.z_index = 12
	door_indicator_overlay.draw.connect(_on_door_indicator_draw)
	add_child(door_indicator_overlay)

func _exit_tree() -> void:
	if EventBus:
		if EventBus.door_toggled.is_connected(_on_door_toggled):
			EventBus.door_toggled.disconnect(_on_door_toggled)
		if EventBus.window_broken.is_connected(_on_window_broken):
			EventBus.window_broken.disconnect(_on_window_broken)

func _on_door_toggled(tile_pos: Vector2i, is_open: bool) -> void:
	var cur_atlas = object_layer.get_cell_atlas_coords(tile_pos) if object_layer else Vector2i(-1, -1)
	if TileManager.is_window_broken(cur_atlas) or TileManager.is_window(cur_atlas):
		chunk_deltas[tile_pos] = TileManager.get_window_broken_tile(cur_atlas)
		_door_tiles.erase(tile_pos)
	else:
		var is_v := TileManager.is_vertical_variant(cur_atlas)
		var next_atlas := TileManager.get_door_open_tile(is_v) if is_open else TileManager.get_door_closed_tile(is_v)
		chunk_deltas[tile_pos] = next_atlas
		_door_tiles[tile_pos] = next_atlas
		if deco_shadow_layer:
			var south_pos := tile_pos + Vector2i(0, 1)
			if is_open:
				if deco_shadow_layer.get_cell_atlas_coords(south_pos) == TileManager.SHADOW_SOUTH:
					deco_shadow_layer.erase_cell(south_pos)
			elif ground_layer and ground_layer.get_cell_source_id(south_pos) != -1:
				var south_obj := object_layer.get_cell_atlas_coords(south_pos) if object_layer else Vector2i(-1, -1)
				if not _is_structure_wall(south_obj):
					deco_shadow_layer.set_cell(south_pos, 0, TileManager.SHADOW_SOUTH)
	if GameManager:
		GameManager.current_world_data["chunk_deltas"] = chunk_deltas
	if door_indicator_overlay:
		door_indicator_overlay.queue_redraw()

func _on_door_indicator_draw() -> void:
	if not door_indicator_overlay or _door_tiles.is_empty():
		return
	var has_p := _last_player_tile.x < 900000
	var p_world := Vector2(_last_player_tile) * float(TILE_SIZE)
	for t_pos in _door_tiles.keys():
		if roof_layer and roof_layer.get_cell_source_id(t_pos) != -1:
			continue
		var px: float = float(t_pos.x * TILE_SIZE)
		var py: float = float(t_pos.y * TILE_SIZE)
		if has_p and Vector2(px, py).distance_squared_to(p_world) > 560.0 * 560.0:
			continue
		var atlas: Vector2i = object_layer.get_cell_atlas_coords(t_pos) if object_layer else _door_tiles[t_pos]
		var is_v := TileManager.is_vertical_variant(atlas)
		if TileManager.is_door_locked(atlas):
			var lock_col := Color(1.0, 0.35, 0.25, 0.88)
			door_indicator_overlay.draw_rect(Rect2(px + 3.0, py + 3.0, 26.0, 26.0), lock_col, false, 1.0)
			door_indicator_overlay.draw_rect(Rect2(px + 13.0, py + 13.0, 6.0, 6.0), Color(1.0, 0.82, 0.25, 0.95), true)
		elif TileManager.is_door_open(atlas):
			var open_col := Color(0.32, 0.94, 0.56, 0.85)
			if is_v:
				door_indicator_overlay.draw_rect(Rect2(px + 2.0, py + 4.0, 4.0, 2.0), open_col, true)
				door_indicator_overlay.draw_rect(Rect2(px + 2.0, py + 26.0, 4.0, 2.0), open_col, true)
				door_indicator_overlay.draw_rect(Rect2(px + 14.0, py + 4.0, 3.0, 24.0), Color(0.32, 0.94, 0.56, 0.32), true)
			else:
				door_indicator_overlay.draw_rect(Rect2(px + 4.0, py + 26.0, 2.0, 4.0), open_col, true)
				door_indicator_overlay.draw_rect(Rect2(px + 26.0, py + 26.0, 2.0, 4.0), open_col, true)
				door_indicator_overlay.draw_rect(Rect2(px + 4.0, py + 13.0, 24.0, 3.0), Color(0.32, 0.94, 0.56, 0.32), true)
		elif TileManager.is_door_closed(atlas):
			var closed_col := Color(0.96, 0.72, 0.25, 0.88)
			if is_v:
				door_indicator_overlay.draw_rect(Rect2(px + 2.0, py + 6.0, 3.0, 20.0), closed_col, true)
				door_indicator_overlay.draw_rect(Rect2(px + 22.0, py + 14.0, 4.0, 4.0), Color(1.0, 0.92, 0.45, 0.95), true)
			else:
				door_indicator_overlay.draw_rect(Rect2(px + 6.0, py + 27.0, 20.0, 3.0), closed_col, true)
				door_indicator_overlay.draw_rect(Rect2(px + 21.0, py + 14.0, 4.0, 4.0), Color(1.0, 0.92, 0.45, 0.95), true)

func _on_window_broken(tile_pos: Vector2i) -> void:
	var cur_atlas = object_layer.get_cell_atlas_coords(tile_pos) if object_layer else Vector2i(-1, -1)
	chunk_deltas[tile_pos] = TileManager.get_window_broken_tile(cur_atlas)
	if GameManager:
		GameManager.current_world_data["chunk_deltas"] = chunk_deltas

func _process(delta: float) -> void:
	# 프레임당 최대 2개 청크만 분할 생성/렌더링하여 이동 시 프레임 스터터링 방지
	var processed = 0
	while not pending_chunk_queue.is_empty() and processed < 2:
		var next_pos = pending_chunk_queue.pop_front()
		if active_chunks.has(next_pos) and not loaded_chunks.has(next_pos):
			load_chunk(next_pos)
			processed += 1

	# 날씨에 따른 수면 빗방울 파문 & 나무 바람 세기 실시간 동기화
	if WeatherSystem:
		var target_rain := 0.0
		var target_wind := 0.65
		match WeatherSystem.current_weather:
			WeatherSystem.WeatherType.CLOUDY:
				target_wind = 0.85
			WeatherSystem.WeatherType.FOG:
				target_wind = 0.35
			WeatherSystem.WeatherType.RAIN:
				target_rain = 0.55
				target_wind = 1.15
			WeatherSystem.WeatherType.HEAVY_RAIN:
				target_rain = 0.85
				target_wind = 1.50
			WeatherSystem.WeatherType.STORM:
				target_rain = 1.0
				target_wind = 2.00
		if _last_rain_fx < 0.0:
			_last_rain_fx = target_rain
			_last_wind_fx = target_wind
		else:
			_last_rain_fx = lerp(_last_rain_fx, target_rain, clampf(delta * 2.0, 0.0, 1.0))
			_last_wind_fx = lerp(_last_wind_fx, target_wind, clampf(delta * 2.0, 0.0, 1.0))
		if _water_mat:
			_water_mat.set_shader_parameter("rain_intensity", _last_rain_fx)
		if _foliage_mat:
			_foliage_mat.set_shader_parameter("wind_strength", _last_wind_fx)

func update_chunks(player_pos: Vector2, force: bool = false) -> void:
	var player_tile_x: int = int(floor(player_pos.x / TILE_SIZE))
	var player_tile_y: int = int(floor(player_pos.y / TILE_SIZE))
	var cur_tile := Vector2i(player_tile_x, player_tile_y)

	if force or cur_tile != _last_player_tile:
		_last_player_tile = cur_tile
		_update_roof_visibility(player_tile_x, player_tile_y)
		if door_indicator_overlay:
			door_indicator_overlay.queue_redraw()

	var center_chunk_x: int = int(floor(player_pos.x / (CHUNK_SIZE * TILE_SIZE)))
	var center_chunk_y: int = int(floor(player_pos.y / (CHUNK_SIZE * TILE_SIZE)))
	var center_chunk := Vector2i(center_chunk_x, center_chunk_y)

	if not force and not loaded_chunks.is_empty() and center_chunk == _last_player_chunk:
		return
	_last_player_chunk = center_chunk

	var new_active_chunks: Array[Vector2i] = []
	var is_initial_load = loaded_chunks.is_empty()

	for y in range(center_chunk_y - render_distance, center_chunk_y + render_distance + 1):
		for x in range(center_chunk_x - render_distance, center_chunk_x + render_distance + 1):
			var chunk_pos = Vector2i(x, y)
			new_active_chunks.append(chunk_pos)

			if not loaded_chunks.has(chunk_pos):
				if is_initial_load or chunk_pos.distance_squared_to(center_chunk) <= 2:
					load_chunk(chunk_pos)
				elif not pending_chunk_queue.has(chunk_pos):
					pending_chunk_queue.append(chunk_pos)

	var to_unload: Array[Vector2i] = []
	for chunk_pos in active_chunks:
		if not new_active_chunks.has(chunk_pos):
			to_unload.append(chunk_pos)

	for chunk_pos in to_unload:
		unload_chunk(chunk_pos)

	active_chunks = new_active_chunks

func _commit_fading_in_roofs() -> void:
	if _fade_in_tween and is_instance_valid(_fade_in_tween):
		_fade_in_tween.kill()
		_fade_in_tween = null
	if not _fading_in_cells.is_empty():
		for pos in _fading_in_cells:
			if ground_layer and ground_layer.get_cell_source_id(pos) != -1:
				roof_layer.set_cell(pos, 0, TileManager.TILE_ROOF)
		_fading_in_cells.clear()
	if roof_fade_in_layer:
		roof_fade_in_layer.clear()

func _update_roof_visibility(tile_x: int, tile_y: int) -> void:
	if not generator: return

	var b = generator.get_building_at(tile_x, tile_y)

	# 건물이 바뀌었는지 확인
	var current_b_seed = current_inside_building.get("seed", -1)
	var new_b_seed = b.get("seed", -1)

	if current_b_seed != new_b_seed:
		# 진행 중인 트윈 정리
		_commit_fading_in_roofs()
		if _fade_out_tween and is_instance_valid(_fade_out_tween):
			_fade_out_tween.kill()
			_fade_out_tween = null
		if roof_fade_out_layer:
			roof_fade_out_layer.clear()

		# 이전 건물의 지붕 타일들 부드럽게 페이드 인 복원
		if not hidden_roof_cells.is_empty():
			if is_inside_tree() and roof_fade_in_layer:
				_fading_in_cells = hidden_roof_cells.duplicate()
				hidden_roof_cells.clear()
				for pos in _fading_in_cells:
					roof_fade_in_layer.set_cell(pos, 0, TileManager.TILE_ROOF)
				roof_fade_in_layer.modulate.a = 0.0
				_fade_in_tween = create_tween()
				_fade_in_tween.set_ease(Tween.EASE_OUT)
				_fade_in_tween.set_trans(Tween.TRANS_SINE)
				_fade_in_tween.tween_property(roof_fade_in_layer, "modulate:a", 1.0, 0.24)
				_fade_in_tween.tween_callback(_commit_fading_in_roofs)
			else:
				for pos in hidden_roof_cells:
					roof_layer.set_cell(pos, 0, TileManager.TILE_ROOF)
				hidden_roof_cells.clear()

		current_inside_building = b

		# 새로운 건물에 들어갔으면 해당 건물의 지붕 타일 부드럽게 페이드 아웃
		if not b.is_empty():
			var bx = b["wx"]
			var by = b["wy"]
			var bw = b["width"]
			var bh = b["height"]

			var newly_hidden: Array[Vector2i] = []
			for ry in range(by, by + bh):
				for rx in range(bx, bx + bw):
					var cell_pos = Vector2i(rx, ry)
					if roof_layer.get_cell_source_id(cell_pos) != -1:
						hidden_roof_cells.append(cell_pos)
						newly_hidden.append(cell_pos)
						roof_layer.erase_cell(cell_pos)
						if roof_fade_out_layer:
							roof_fade_out_layer.set_cell(cell_pos, 0, TileManager.TILE_ROOF)

			if is_inside_tree() and roof_fade_out_layer and not newly_hidden.is_empty():
				roof_fade_out_layer.modulate.a = 1.0
				_fade_out_tween = create_tween()
				_fade_out_tween.set_ease(Tween.EASE_OUT)
				_fade_out_tween.set_trans(Tween.TRANS_QUAD)
				_fade_out_tween.tween_property(roof_fade_out_layer, "modulate:a", 0.0, 0.20)
				_fade_out_tween.tween_callback(roof_fade_out_layer.clear)
			elif roof_fade_out_layer:
				roof_fade_out_layer.clear()

func _place_deco_if_clear(tile_pos: Vector2i, ground_type: Vector2i) -> void:
	if deco_shadow_layer.get_cell_source_id(tile_pos) != -1:
		return
	var r := _tile_hash(tile_pos.x, tile_pos.y, 77)
	if ground_type == TileManager.TILE_GRASS:
		if r < 0.12:
			deco_shadow_layer.set_cell(tile_pos, 0, TileManager.DECO_WEEDS)
		elif r < 0.16:
			deco_shadow_layer.set_cell(tile_pos, 0, TileManager.DECO_LEAVES)
		elif r < 0.175:
			deco_shadow_layer.set_cell(tile_pos, 0, TileManager.DECO_PUDDLE)
	elif ground_type == TileManager.TILE_DIRT or ground_type == TileManager.TILE_GRAVEL:
		if r < 0.08:
			deco_shadow_layer.set_cell(tile_pos, 0, TileManager.DECO_RUBBLE)
		elif r < 0.11:
			deco_shadow_layer.set_cell(tile_pos, 0, TileManager.DECO_LEAVES)
	elif ground_type == TileManager.TILE_ROAD:
		if r < 0.07:
			deco_shadow_layer.set_cell(tile_pos, 0, TileManager.DECO_CRACKS)
		elif r < 0.082:
			deco_shadow_layer.set_cell(tile_pos, 0, TileManager.DECO_MANHOLE)
		elif r < 0.092:
			deco_shadow_layer.set_cell(tile_pos, 0, TileManager.DECO_DRAIN)
		elif r < 0.112:
			deco_shadow_layer.set_cell(tile_pos, 0, TileManager.DECO_PUDDLE)
	elif ground_type == TileManager.TILE_CONCRETE:
		if r < 0.05:
			deco_shadow_layer.set_cell(tile_pos, 0, TileManager.DECO_RUBBLE)
		elif r < 0.065:
			deco_shadow_layer.set_cell(tile_pos, 0, TileManager.DECO_STAIN)
	elif ground_type == TileManager.TILE_FLOOR_WOOD or ground_type == TileManager.TILE_FLOOR_TILE:
		if r < 0.025:
			deco_shadow_layer.set_cell(tile_pos, 0, TileManager.DECO_STAIN)

func load_chunk(chunk_pos: Vector2i) -> void:
	var chunk_data = generator.generate_chunk(chunk_pos)
	loaded_chunks[chunk_pos] = chunk_data
	chunk_entities[chunk_pos] = []

	var start_wx = chunk_pos.x * CHUNK_SIZE
	var start_wy = chunk_pos.y * CHUNK_SIZE

	var has_roofs = chunk_data.has("roofs")
	var tiles_arr: Array = chunk_data["tiles"]
	var objs_arr: Array = chunk_data["objects"]
	var resolved_objs: Array[Vector2i] = []
	resolved_objs.resize(CHUNK_SIZE * CHUNK_SIZE)

	for ly in range(CHUNK_SIZE):
		for lx in range(CHUNK_SIZE):
			var idx = ly * CHUNK_SIZE + lx
			var wx = start_wx + lx
			var wy = start_wy + ly
			var tile_pos = Vector2i(wx, wy)
			var ground_type: Vector2i = tiles_arr[idx]

			# 바닥 타일 & 수면 셰이더 오버레이
			ground_layer.set_cell(tile_pos, 0, ground_type)
			if ground_type == TileManager.TILE_WATER and water_fx_layer:
				water_fx_layer.set_cell(tile_pos, 0, TileManager.TILE_WATER)

			# 오브젝트 타일 (벽, 문, 창문, 가구 등) + 월드 델타(문 개폐/창문 파괴) 우선 적용
			var obj_type: Vector2i = Vector2i(-1, -1)
			if chunk_deltas.has(tile_pos):
				obj_type = chunk_deltas[tile_pos]
			elif objs_arr[idx] != Vector2i(-1, -1):
				obj_type = objs_arr[idx]
			resolved_objs[idx] = obj_type

			if obj_type != Vector2i(-1, -1):
				if obj_type == TileManager.OBJ_TREE and foliage_fx_layer:
					# ObjectLayer는 투명 충돌체(alt=1) 유지, 시각 렌더링은 바람 흔들림 FoliageFxLayer(alt=0) 담당
					object_layer.set_cell(tile_pos, 0, TileManager.OBJ_TREE, 1)
					foliage_fx_layer.set_cell(tile_pos, 0, TileManager.OBJ_TREE, 0)
				else:
					object_layer.set_cell(tile_pos, 0, obj_type)
					if TileManager.is_door_closed(obj_type) or TileManager.is_door_open(obj_type) or TileManager.is_door_locked(obj_type):
						_door_tiles[tile_pos] = obj_type

				if object_shadow_layer and _casts_oval_shadow(obj_type):
					object_shadow_layer.set_cell(tile_pos, 0, TileManager.SHADOW_OVAL)

			# 지붕 타일
			if has_roofs and chunk_data["roofs"][idx] != Vector2i(-1, -1):
				# 현재 플레이어가 숨겨둔 셀이 아닐 때만 렌더링
				if not hidden_roof_cells.has(tile_pos) and not _fading_in_cells.has(tile_pos):
					roof_layer.set_cell(tile_pos, 0, chunk_data["roofs"][idx])

	# 2차 패스: 구조물 드롭 섀도우 (South / East / SE) 및 환경 데코 배치
	for ly in range(CHUNK_SIZE):
		for lx in range(CHUNK_SIZE):
			var idx = ly * CHUNK_SIZE + lx
			var wx = start_wx + lx
			var wy = start_wy + ly
			var tile_pos = Vector2i(wx, wy)
			var obj_type := resolved_objs[idx]

			if _is_structure_wall(obj_type):
				# 남쪽 그림자
				var s_obj: Vector2i = resolved_objs[(ly + 1) * CHUNK_SIZE + lx] if (ly + 1 < CHUNK_SIZE) else object_layer.get_cell_atlas_coords(Vector2i(wx, wy + 1))
				if not _is_structure_wall(s_obj):
					deco_shadow_layer.set_cell(Vector2i(wx, wy + 1), 0, TileManager.SHADOW_SOUTH)
				# 동쪽 그림자
				var e_obj: Vector2i = resolved_objs[ly * CHUNK_SIZE + lx + 1] if (lx + 1 < CHUNK_SIZE) else object_layer.get_cell_atlas_coords(Vector2i(wx + 1, wy))
				if not _is_structure_wall(e_obj):
					deco_shadow_layer.set_cell(Vector2i(wx + 1, wy), 0, TileManager.SHADOW_EAST)
				# 남동쪽 모서리 그림자
				var se_obj: Vector2i = resolved_objs[(ly + 1) * CHUNK_SIZE + lx + 1] if (lx + 1 < CHUNK_SIZE and ly + 1 < CHUNK_SIZE) else object_layer.get_cell_atlas_coords(Vector2i(wx + 1, wy + 1))
				if not _is_structure_wall(s_obj) and not _is_structure_wall(e_obj) and not _is_structure_wall(se_obj):
					deco_shadow_layer.set_cell(Vector2i(wx + 1, wy + 1), 0, TileManager.SHADOW_SE)
			else:
				# 인접 청크 경계(북쪽/서쪽/북서쪽) 벽체가 이미 로드되어 있으면 그림자 반영
				var has_cast_shadow := false
				if ly == 0 and _is_structure_wall(object_layer.get_cell_atlas_coords(Vector2i(wx, wy - 1))):
					deco_shadow_layer.set_cell(tile_pos, 0, TileManager.SHADOW_SOUTH)
					has_cast_shadow = true
				elif lx == 0 and _is_structure_wall(object_layer.get_cell_atlas_coords(Vector2i(wx - 1, wy))):
					deco_shadow_layer.set_cell(tile_pos, 0, TileManager.SHADOW_EAST)
					has_cast_shadow = true
				elif lx == 0 and ly == 0 and _is_structure_wall(object_layer.get_cell_atlas_coords(Vector2i(wx - 1, wy - 1))):
					deco_shadow_layer.set_cell(tile_pos, 0, TileManager.SHADOW_SE)
					has_cast_shadow = true

				if not has_cast_shadow and obj_type == Vector2i(-1, -1):
					_place_deco_if_clear(tile_pos, tiles_arr[idx])

	# 동적 엔티티 스폰 (차량 등)
	if chunk_data.has("entities"):
		for ent_data in chunk_data["entities"]:
			if ent_data["type"] == "car":
				var car = CarScene.instantiate()
				var world_pos = Vector2(ent_data["wx"] * TILE_SIZE + TILE_SIZE/2.0, ent_data["wy"] * TILE_SIZE + TILE_SIZE/2.0)
				car.position = world_pos
				car.rotation_angle = ent_data["rotation"]
				object_layer.add_child(car)
				chunk_entities[chunk_pos].append(car)

	if door_indicator_overlay:
		door_indicator_overlay.queue_redraw()
	chunk_loaded.emit(chunk_pos, chunk_data)

func unload_chunk(chunk_pos: Vector2i) -> void:
	if loaded_chunks.has(chunk_pos):
		var start_wx = chunk_pos.x * CHUNK_SIZE
		var start_wy = chunk_pos.y * CHUNK_SIZE
		for ly in range(CHUNK_SIZE):
			for lx in range(CHUNK_SIZE):
				var pos = Vector2i(start_wx + lx, start_wy + ly)
				ground_layer.erase_cell(pos)
				if water_fx_layer:
					water_fx_layer.erase_cell(pos)
				if deco_shadow_layer:
					deco_shadow_layer.erase_cell(pos)
				if object_shadow_layer:
					object_shadow_layer.erase_cell(pos)
				object_layer.erase_cell(pos)
				_door_tiles.erase(pos)
				if foliage_fx_layer:
					foliage_fx_layer.erase_cell(pos)
				roof_layer.erase_cell(pos)
				if roof_fade_out_layer:
					roof_fade_out_layer.erase_cell(pos)
				if roof_fade_in_layer:
					roof_fade_in_layer.erase_cell(pos)
				hidden_roof_cells.erase(pos)
				if _fading_in_cells.has(pos):
					_fading_in_cells.erase(pos)

		# 청크 경계(남쪽 ly==16, 동쪽 lx==16, 남동쪽 (16,16))로 드리워졌던 고아 벽체 그림자 정리
		if deco_shadow_layer:
			for lx in range(CHUNK_SIZE):
				_clear_orphan_border_shadow(Vector2i(start_wx + lx, start_wy + CHUNK_SIZE))
			for ly in range(CHUNK_SIZE):
				_clear_orphan_border_shadow(Vector2i(start_wx + CHUNK_SIZE, start_wy + ly))
			_clear_orphan_border_shadow(Vector2i(start_wx + CHUNK_SIZE, start_wy + CHUNK_SIZE))

		if chunk_entities.has(chunk_pos):
			for ent in chunk_entities[chunk_pos]:
				if is_instance_valid(ent):
					ent.queue_free()
			chunk_entities.erase(chunk_pos)

		loaded_chunks.erase(chunk_pos)
		if door_indicator_overlay:
			door_indicator_overlay.queue_redraw()
		chunk_unloaded.emit(chunk_pos)

func _clear_orphan_border_shadow(pos: Vector2i) -> void:
	if not deco_shadow_layer or not object_layer:
		return
	if deco_shadow_layer.get_cell_source_id(pos) == -1:
		return
	var atlas := deco_shadow_layer.get_cell_atlas_coords(pos)
	if atlas == TileManager.SHADOW_SOUTH:
		if not _is_structure_wall(object_layer.get_cell_atlas_coords(pos + Vector2i(0, -1))):
			deco_shadow_layer.erase_cell(pos)
	elif atlas == TileManager.SHADOW_EAST:
		if not _is_structure_wall(object_layer.get_cell_atlas_coords(pos + Vector2i(-1, 0))):
			deco_shadow_layer.erase_cell(pos)
	elif atlas == TileManager.SHADOW_SE:
		if not _is_structure_wall(object_layer.get_cell_atlas_coords(pos + Vector2i(-1, -1))):
			deco_shadow_layer.erase_cell(pos)
