# res://scenes/world/world_renderer.gd
extends Node2D

## 청크 데이터를 받아 시각적으로 렌더링하는 절차적 월드 렌더러

const CHUNK_SIZE: int = 16
const TILE_SIZE: int = 32

var active_chunks: Dictionary = {}

func _ready() -> void:
	z_index = -10 # 엔티티 아래에 렌더링

func add_chunk(chunk_pos: Vector2i, chunk_data: Dictionary) -> void:
	active_chunks[chunk_pos] = chunk_data
	queue_redraw()

func remove_chunk(chunk_pos: Vector2i) -> void:
	if active_chunks.has(chunk_pos):
		active_chunks.erase(chunk_pos)
		queue_redraw()

func _draw() -> void:
	# 타일 색상 매핑
	var colors = [
		Color(0.25, 0.5, 0.2), # 0: 풀
		Color(0.55, 0.45, 0.3), # 1: 흙
		Color(0.3, 0.3, 0.35)   # 2: 도로
	]
	
	for chunk_pos in active_chunks.keys():
		var data = active_chunks[chunk_pos]
		var tiles = data.get("tiles", [])
		var objects = data.get("objects", [])
		
		var offset_x = chunk_pos.x * CHUNK_SIZE * TILE_SIZE
		var offset_y = chunk_pos.y * CHUNK_SIZE * TILE_SIZE
		
		# 1. 타일 렌더링
		for i in range(tiles.size()):
			var lx = i % CHUNK_SIZE
			var ly = int(float(i) / float(CHUNK_SIZE))
			var tile_type = tiles[i]
			
			var rect = Rect2(
				offset_x + lx * TILE_SIZE,
				offset_y + ly * TILE_SIZE,
				TILE_SIZE, TILE_SIZE
			)
			draw_rect(rect, colors[tile_type])
			
		# 2. 오브젝트 렌더링
		for obj in objects:
			var lx = obj["x"]
			var ly = obj["y"]
			var center = Vector2(
				offset_x + lx * TILE_SIZE + TILE_SIZE / 2.0,
				offset_y + ly * TILE_SIZE + TILE_SIZE / 2.0
			)
			
			if obj["type"] == "tree":
				draw_circle(center, TILE_SIZE * 0.8, Color(0.15, 0.35, 0.15, 0.9))
				draw_circle(center, TILE_SIZE * 0.3, Color(0.35, 0.25, 0.15))
			elif obj["type"] == "rock":
				draw_rect(Rect2(center.x - TILE_SIZE / 2.0, center.y - TILE_SIZE / 2.0, TILE_SIZE, TILE_SIZE * 0.8), Color(0.4, 0.4, 0.45))
