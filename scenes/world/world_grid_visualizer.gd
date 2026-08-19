# res://scenes/world/world_grid_visualizer.gd
extends Node2D

## 바닥 그리드 및 랜드마크 시각화 스크립트 (이동감 체감용)

const GRID_SIZE: int = 64
const WORLD_RADIUS: int = 40

func _draw() -> void:
	# 1. 바닥 배경 채우기
	var bg_rect = Rect2(-2500, -2500, 5000, 5000)
	draw_rect(bg_rect, Color(0.2, 0.22, 0.24)) # 짙은 회색 폐허 바닥
	
	# 2. 격자선 그리기
	var line_color = Color(0.28, 0.3, 0.34, 0.6)
	for x in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
		var px = x * GRID_SIZE
		draw_line(Vector2(px, -WORLD_RADIUS * GRID_SIZE), Vector2(px, WORLD_RADIUS * GRID_SIZE), line_color, 1.0)
		
	for y in range(-WORLD_RADIUS, WORLD_RADIUS + 1):
		var py = y * GRID_SIZE
		draw_line(Vector2(-WORLD_RADIUS * GRID_SIZE, py), Vector2(WORLD_RADIUS * GRID_SIZE, py), line_color, 1.0)
		
	# 3. 중앙 기준점 및 도로 느낌의 표시
	draw_circle(Vector2.ZERO, 16.0, Color(0.9, 0.7, 0.2, 0.8)) # 원점 마커
	draw_rect(Rect2(-10, -800, 20, 1600), Color(0.35, 0.35, 0.38)) # 세로 도로
	draw_rect(Rect2(-800, -10, 1600, 20), Color(0.35, 0.35, 0.38)) # 가로 도로
	
	# 4. 몇 가지 랜드마크(나무, 바위 모양) 배치
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345
	for i in range(40):
		var rx = rng.randf_range(-1000, 1000)
		var ry = rng.randf_range(-1000, 1000)
		if Vector2(rx, ry).length() < 100:
			continue
		var radius = rng.randf_range(16, 32)
		var is_tree = rng.randf() > 0.4
		if is_tree:
			draw_circle(Vector2(rx, ry), radius, Color(0.2, 0.45, 0.25, 0.9)) # 나무
			draw_circle(Vector2(rx, ry), radius * 0.4, Color(0.4, 0.3, 0.2)) # 나무 기둥
		else:
			draw_rect(Rect2(rx - radius, ry - radius * 0.7, radius * 2, radius * 1.4), Color(0.45, 0.45, 0.48)) # 바위
