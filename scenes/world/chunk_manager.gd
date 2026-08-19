# res://scenes/world/chunk_manager.gd
extends Node

## 플레이어 위치 기반 청크 동적 로딩 매니저

const CHUNK_SIZE: int = 16
const TILE_SIZE: int = 32

var loaded_chunks: Dictionary = {}
var active_chunks: Array[Vector2i] = []
var render_distance: int = 3

var noise: FastNoiseLite
var biome_noise: FastNoiseLite
var rng: RandomNumberGenerator

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

func update_chunks(player_pos: Vector2) -> void:
	var center_chunk_x: int = floor(player_pos.x / (CHUNK_SIZE * TILE_SIZE))
	var center_chunk_y: int = floor(player_pos.y / (CHUNK_SIZE * TILE_SIZE))
	var center_chunk = Vector2i(center_chunk_x, center_chunk_y)
	
	var new_active_chunks: Array[Vector2i] = []
	
	# 주변 청크 범위 탐색
	for y in range(center_chunk_y - render_distance, center_chunk_y + render_distance + 1):
		for x in range(center_chunk_x - render_distance, center_chunk_x + render_distance + 1):
			var chunk_pos = Vector2i(x, y)
			new_active_chunks.append(chunk_pos)
			
			if not loaded_chunks.has(chunk_pos):
				load_chunk(chunk_pos)
				
	# 범위를 벗어난 청크 언로드
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
	chunk_loaded.emit(chunk_pos, chunk_data)

func unload_chunk(chunk_pos: Vector2i) -> void:
	if loaded_chunks.has(chunk_pos):
		# 상태 저장 후 메모리에서 해제 (청크 델타 저장)
		loaded_chunks.erase(chunk_pos)
		chunk_unloaded.emit(chunk_pos)

func generate_chunk(chunk_pos: Vector2i) -> Dictionary:
	var tiles: Array = []
	tiles.resize(CHUNK_SIZE * CHUNK_SIZE)
	var objects: Array = []
	
	var start_wx = chunk_pos.x * CHUNK_SIZE
	var start_wy = chunk_pos.y * CHUNK_SIZE
	
	for ly in range(CHUNK_SIZE):
		for lx in range(CHUNK_SIZE):
			var wx = start_wx + lx
			var wy = start_wy + ly
			
			var idx = ly * CHUNK_SIZE + lx
			var b_val = biome_noise.get_noise_2d(wx * 4.0, wy * 4.0)
			
			var tile_type = 0 # 0: 풀, 1: 흙, 2: 도로
			if b_val > 0.3:
				tile_type = 1 # 흙
			elif b_val < -0.3:
				tile_type = 0 # 풀
			else:
				tile_type = 0 # 기본 풀
				
			# 노이즈 기반 도로망 (간단한 격자 도로 시뮬레이션)
			if abs(wx % 20) < 2 or abs(wy % 20) < 2:
				tile_type = 2 # 도로
				
			tiles[idx] = tile_type
			
			# 장식물 랜덤 배치
			if tile_type != 2 and rng.randf() < 0.05:
				objects.append({"type": "tree" if rng.randf() > 0.3 else "rock", "x": lx, "y": ly})
	
	return {
		"tiles": tiles,
		"objects": objects
	}
