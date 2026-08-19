# res://scenes/world/chunk_manager.gd
extends Node

## 플레이어 위치 기반 청크 동적 로딩 및 TileMapLayer 렌더링

const CHUNK_SIZE: int = 16
const TILE_SIZE: int = 32

var loaded_chunks: Dictionary = {}
var active_chunks: Array[Vector2i] = []
var render_distance: int = 4

var generator: WorldGenerator

var ground_layer: TileMapLayer
var object_layer: TileMapLayer

signal chunk_loaded(chunk_pos: Vector2i, data: Dictionary)
signal chunk_unloaded(chunk_pos: Vector2i)

func _ready() -> void:
	# WorldGenerator 초기화
	generator = WorldGenerator.new(randi())
	
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
	var chunk_data = generator.generate_chunk(chunk_pos)
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
