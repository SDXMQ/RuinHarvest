# res://scenes/world/chunk_manager.gd
extends Node

## 플레이어 위치 기반 청크 동적 로딩 및 TileMapLayer 렌더링 (바닥, 오브젝트, 지붕) + 월드 델타 보존
const CHUNK_SIZE: int = 16
const TILE_SIZE: int = 32

var loaded_chunks: Dictionary = {}
var active_chunks: Array[Vector2i] = []
var pending_chunk_queue: Array[Vector2i] = []
var chunk_deltas: Dictionary = {} # tile_pos (Vector2i) -> atlas_coords (Vector2i)
var render_distance: int = 4

var generator: WorldGenerator

var ground_layer: TileMapLayer
var object_layer: TileMapLayer
var roof_layer: TileMapLayer

const CarScene = preload("res://scenes/world/objects/car.tscn")
var chunk_entities: Dictionary = {} # chunk_pos (Vector2i) -> Array[Node]

# 현재 플레이어가 들어가 있는 건물 정보
var current_inside_building: Dictionary = {}
var hidden_roof_cells: Array[Vector2i] = []

signal chunk_loaded(chunk_pos: Vector2i, data: Dictionary)
signal chunk_unloaded(chunk_pos: Vector2i)

func _ready() -> void:
	# WorldGenerator 초기화
	generator = WorldGenerator.new(randi())
	if GameManager and GameManager.current_world_data.has("chunk_deltas"):
		chunk_deltas = GameManager.current_world_data["chunk_deltas"].duplicate()
	
	# 동적으로 TileMapLayer 생성
	ground_layer = TileMapLayer.new()
	ground_layer.name = "GroundLayer"
	ground_layer.z_index = -10
	add_child(ground_layer)
	
	object_layer = TileMapLayer.new()
	object_layer.name = "ObjectLayer"
	object_layer.z_index = 0
	object_layer.y_sort_enabled = true # y-sorting 활성화
	add_child(object_layer)
	
	roof_layer = TileMapLayer.new()
	roof_layer.name = "RoofLayer"
	roof_layer.z_index = 10 # 플레이어 및 오브젝트 위를 덮는 지붕 레이어
	add_child(roof_layer)
	
	# TileManager에서 생성된 절차적 타일셋 할당
	if TileManager.tileset:
		ground_layer.tile_set = TileManager.tileset
		object_layer.tile_set = TileManager.tileset
		roof_layer.tile_set = TileManager.tileset
		
	if EventBus.has_signal("door_toggled"):
		EventBus.door_toggled.connect(_on_door_toggled)
	if EventBus.has_signal("window_broken"):
		EventBus.window_broken.connect(_on_window_broken)

func _exit_tree() -> void:
	if EventBus:
		if EventBus.door_toggled.is_connected(_on_door_toggled):
			EventBus.door_toggled.disconnect(_on_door_toggled)
		if EventBus.window_broken.is_connected(_on_window_broken):
			EventBus.window_broken.disconnect(_on_window_broken)

func _on_door_toggled(tile_pos: Vector2i, is_open: bool) -> void:
	var cur_atlas = object_layer.get_cell_atlas_coords(tile_pos) if object_layer else Vector2i(-1, -1)
	if cur_atlas == TileManager.OBJ_WINDOW_BROKEN:
		chunk_deltas[tile_pos] = TileManager.OBJ_WINDOW_BROKEN
	else:
		chunk_deltas[tile_pos] = TileManager.OBJ_DOOR_OPEN if is_open else TileManager.OBJ_DOOR_CLOSED
	if GameManager:
		GameManager.current_world_data["chunk_deltas"] = chunk_deltas

func _on_window_broken(tile_pos: Vector2i) -> void:
	chunk_deltas[tile_pos] = TileManager.OBJ_WINDOW_BROKEN
	if GameManager:
		GameManager.current_world_data["chunk_deltas"] = chunk_deltas

func _process(_delta: float) -> void:
	# 프레임당 최대 2개 청크만 분할 생성/렌더링하여 이동 시 프레임 스터터링 방지
	var processed = 0
	while not pending_chunk_queue.is_empty() and processed < 2:
		var next_pos = pending_chunk_queue.pop_front()
		if active_chunks.has(next_pos) and not loaded_chunks.has(next_pos):
			load_chunk(next_pos)
			processed += 1

func update_chunks(player_pos: Vector2) -> void:
	var player_tile_x = int(floor(player_pos.x / TILE_SIZE))
	var player_tile_y = int(floor(player_pos.y / TILE_SIZE))
	
	_update_roof_visibility(player_tile_x, player_tile_y)
	
	var center_chunk_x: int = floor(player_pos.x / (CHUNK_SIZE * TILE_SIZE))
	var center_chunk_y: int = floor(player_pos.y / (CHUNK_SIZE * TILE_SIZE))
	var center_chunk = Vector2i(center_chunk_x, center_chunk_y)
	
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

func _update_roof_visibility(tile_x: int, tile_y: int) -> void:
	if not generator: return
	
	var b = generator.get_building_at(tile_x, tile_y)
	
	# 건물이 바뀌었는지 확인
	var current_b_seed = current_inside_building.get("seed", -1)
	var new_b_seed = b.get("seed", -1)
	
	if current_b_seed != new_b_seed:
		# 이전 건물의 지붕 타일들 복원
		if not hidden_roof_cells.is_empty():
			for pos in hidden_roof_cells:
				roof_layer.set_cell(pos, 0, TileManager.TILE_ROOF)
			hidden_roof_cells.clear()
			
		current_inside_building = b
		
		# 새로운 건물에 들어갔으면 해당 건물의 지붕 타일 지우기
		if not b.is_empty():
			var bx = b["wx"]
			var by = b["wy"]
			var bw = b["width"]
			var bh = b["height"]
			
			for ry in range(by, by + bh):
				for rx in range(bx, bx + bw):
					var cell_pos = Vector2i(rx, ry)
					if roof_layer.get_cell_source_id(cell_pos) != -1:
						hidden_roof_cells.append(cell_pos)
						roof_layer.erase_cell(cell_pos)

func load_chunk(chunk_pos: Vector2i) -> void:
	var chunk_data = generator.generate_chunk(chunk_pos)
	loaded_chunks[chunk_pos] = chunk_data
	chunk_entities[chunk_pos] = []
	
	var start_wx = chunk_pos.x * CHUNK_SIZE
	var start_wy = chunk_pos.y * CHUNK_SIZE
	
	var has_roofs = chunk_data.has("roofs")
	
	for ly in range(CHUNK_SIZE):
		for lx in range(CHUNK_SIZE):
			var idx = ly * CHUNK_SIZE + lx
			var wx = start_wx + lx
			var wy = start_wy + ly
			var tile_pos = Vector2i(wx, wy)
			
			# 바닥 타일
			ground_layer.set_cell(tile_pos, 0, chunk_data["tiles"][idx])
			
			# 오브젝트 타일 (벽, 문, 창문, 가구 등) + 월드 델타(문 개폐/창문 파괴) 우선 적용
			if chunk_deltas.has(tile_pos):
				object_layer.set_cell(tile_pos, 0, chunk_deltas[tile_pos])
			elif chunk_data["objects"][idx] != Vector2i(-1, -1):
				object_layer.set_cell(tile_pos, 0, chunk_data["objects"][idx])
				
			# 지붕 타일
			if has_roofs and chunk_data["roofs"][idx] != Vector2i(-1, -1):
				# 현재 플레이어가 숨겨둔 셀이 아닐 때만 렌더링
				if not hidden_roof_cells.has(tile_pos):
					roof_layer.set_cell(tile_pos, 0, chunk_data["roofs"][idx])
	
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
				
	chunk_loaded.emit(chunk_pos, chunk_data)

func unload_chunk(chunk_pos: Vector2i) -> void:
	if loaded_chunks.has(chunk_pos):
		var start_wx = chunk_pos.x * CHUNK_SIZE
		var start_wy = chunk_pos.y * CHUNK_SIZE
		for ly in range(CHUNK_SIZE):
			for lx in range(CHUNK_SIZE):
				var pos = Vector2i(start_wx + lx, start_wy + ly)
				ground_layer.erase_cell(pos)
				object_layer.erase_cell(pos)
				roof_layer.erase_cell(pos)
				hidden_roof_cells.erase(pos)
				
		if chunk_entities.has(chunk_pos):
			for ent in chunk_entities[chunk_pos]:
				if is_instance_valid(ent):
					ent.queue_free()
			chunk_entities.erase(chunk_pos)
				
		loaded_chunks.erase(chunk_pos)
		chunk_unloaded.emit(chunk_pos)
