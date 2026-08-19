# res://scenes/world/chunk_manager.gd
extends Node

## 플레이어 위치 기반 청크 동적 로딩 및 TileMapLayer 렌더링

const CHUNK_SIZE: int = 16
const TILE_SIZE: int = 32

var loaded_chunks: Dictionary = {}
var active_chunks: Array[Vector2i] = []
var render_distance: int = 4

var noise: FastNoiseLite
var biome_noise: FastNoiseLite
var rng: RandomNumberGenerator

var ground_layer: TileMapLayer
var object_layer: TileMapLayer

signal chunk_loaded(chunk_pos: Vector2i, data: Dictionary)
signal chunk_unloaded(chunk_pos: Vector2i)

func _ready() -> void:
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	
	biome_noise = FastNoiseLite.new()
	biome_noise.seed = noise.seed + 1
	biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	
	rng = RandomNumberGenerator.new()
	rng.seed = noise.seed
	
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
	
	# TileManager에서 생성된 절차적 타일셋 할당
	if TileManager.tileset:
		ground_layer.tile_set = TileManager.tileset
		object_layer.tile_set = TileManager.tileset

func update_chunks(player_pos: Vector2) -> void:
	var center_chunk_x: int = floor(player_pos.x / (CHUNK_SIZE * TILE_SIZE))
	var center_chunk_y: int = floor(player_pos.y / (CHUNK_SIZE * TILE_SIZE))
	var center_chunk = Vector2i(center_chunk_x, center_chunk_y)
	
	var new_active_chunks: Array[Vector2i] = []
	
	for y in range(center_chunk_y - render_distance, center_chunk_y + render_distance + 1):
		for x in range(center_chunk_x - render_distance, center_chunk_x + render_distance + 1):
			var chunk_pos = Vector2i(x, y)
			new_active_chunks.append(chunk_pos)
			
			if not loaded_chunks.has(chunk_pos):
				load_chunk(chunk_pos)
				
	var to_unload: Array[Vector2i] = []
	for chunk_pos in active_chunks:
		if not new_active_chunks.has(chunk_pos):
			to_unload.append(chunk_pos)
			
	for chunk_pos in to_unload:
		unload_chunk(chunk_pos)
		
	active_chunks = new_active_chunks

func load_chunk(chunk_pos: Vector2i) -> void:
	var chunk_data = generate_chunk(chunk_pos)
	loaded_chunks[chunk_pos] = chunk_data
	
	# 타일맵 적용
	var start_wx = chunk_pos.x * CHUNK_SIZE
	var start_wy = chunk_pos.y * CHUNK_SIZE
	
	for ly in range(CHUNK_SIZE):
		for lx in range(CHUNK_SIZE):
			var idx = ly * CHUNK_SIZE + lx
			var wx = start_wx + lx
			var wy = start_wy + ly
			
			# 바닥
			ground_layer.set_cell(Vector2i(wx, wy), 0, chunk_data["tiles"][idx])
			
			# 오브젝트
			if chunk_data["objects"][idx] != Vector2i(-1, -1):
				object_layer.set_cell(Vector2i(wx, wy), 0, chunk_data["objects"][idx])
	
	chunk_loaded.emit(chunk_pos, chunk_data)

func unload_chunk(chunk_pos: Vector2i) -> void:
	if loaded_chunks.has(chunk_pos):
		# 타일맵에서 제거
		var start_wx = chunk_pos.x * CHUNK_SIZE
		var start_wy = chunk_pos.y * CHUNK_SIZE
		for ly in range(CHUNK_SIZE):
			for lx in range(CHUNK_SIZE):
				ground_layer.erase_cell(Vector2i(start_wx + lx, start_wy + ly))
				object_layer.erase_cell(Vector2i(start_wx + lx, start_wy + ly))
				
		loaded_chunks.erase(chunk_pos)
		chunk_unloaded.emit(chunk_pos)

func generate_chunk(chunk_pos: Vector2i) -> Dictionary:
	var tiles: Array[Vector2i] = []
	var objects: Array[Vector2i] = []
	tiles.resize(CHUNK_SIZE * CHUNK_SIZE)
	objects.resize(CHUNK_SIZE * CHUNK_SIZE)
	
	var start_wx = chunk_pos.x * CHUNK_SIZE
	var start_wy = chunk_pos.y * CHUNK_SIZE
	
	# 임시 건물 배치(바이옴) 로직 준비
	# 중앙에서 거리가 멀어질수록 노이즈 기반 숲/군사기지 생성
	for ly in range(CHUNK_SIZE):
		for lx in range(CHUNK_SIZE):
			var idx = ly * CHUNK_SIZE + lx
			var wx = start_wx + lx
			var wy = start_wy + ly
			
			var dist = sqrt(wx * wx + wy * wy)
			var b_val = biome_noise.get_noise_2d(wx * 2.0, wy * 2.0)
			
			var tile_coords = TileManager.TILE_GRASS
			var obj_coords = Vector2i(-1, -1)
			
			if b_val > 0.3:
				tile_coords = TileManager.TILE_DIRT
			elif b_val < -0.4:
				tile_coords = TileManager.TILE_GRASS
				
			# 원점 기준 + 모양 거대 도로망 시뮬레이션
			if abs(wx % 20) < 2 or abs(wy % 20) < 2:
				tile_coords = TileManager.TILE_ROAD
			
			# 건물/오브젝트 배치
			if tile_coords != TileManager.TILE_ROAD:
				if rng.randf() < 0.08:
					if rng.randf() > 0.4:
						obj_coords = TileManager.OBJ_TREE
					else:
						obj_coords = TileManager.OBJ_ROCK
				
				# 아주 드물게 파밍 상자(Crate) 생성
				if rng.randf() < 0.005:
					obj_coords = TileManager.OBJ_CRATE
					
				# 특정 노이즈 구역(도시/군사기지) 건물 벽체 생성 (간단 시뮬레이션)
				if b_val > 0.55 and rng.randf() < 0.6:
					tile_coords = TileManager.TILE_CONCRETE
					obj_coords = TileManager.OBJ_WALL
					
			tiles[idx] = tile_coords
			objects[idx] = obj_coords
			
	return {
		"tiles": tiles,
		"objects": objects
	}
