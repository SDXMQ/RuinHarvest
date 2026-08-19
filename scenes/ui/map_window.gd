# res://scenes/ui/map_window.gd
extends Control

@onready var map_canvas: Control = $Center/Panel/MapCanvas
@onready var info_label: Label = $Center/Panel/InfoLabel
@onready var close_btn: Button = $Center/Panel/CloseBtn

var player_pos: Vector2 = Vector2.ZERO
var player_rot: float = 0.0
var extraction_points: Array = []
var current_biome: String = "주거지"

signal window_closed

func setup(pos: Vector2, rot: float, extract_pts: Array, biome: String) -> void:
	player_pos = pos
	player_rot = rot
	extraction_points = extract_pts
	current_biome = biome
	
	info_label.text = "현재 위치: (%.1f, %.1f) | 지역: %s" % [player_pos.x, player_pos.y, current_biome]
	map_canvas.queue_redraw()

func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	map_canvas.draw.connect(_on_map_draw)

func _on_map_draw() -> void:
	var w = map_canvas.size.x
	var h = map_canvas.size.y
	var center = Vector2(w / 2.0, h / 2.0)
	var scale_factor = 0.25 # 월드 좌표 대비 맵 축척
	
	# 1. 지도 배경 및 격자선
	map_canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(0.12, 0.15, 0.12, 0.95))
	
	var grid_size = 40.0
	for x in range(0, int(w), int(grid_size)):
		map_canvas.draw_line(Vector2(x, 0), Vector2(x, h), Color(0.2, 0.3, 0.2, 0.4))
	for y in range(0, int(h), int(grid_size)):
		map_canvas.draw_line(Vector2(0, y), Vector2(w, y), Color(0.2, 0.3, 0.2, 0.4))
		
	# 2. 동심원 거리계 (중앙 은신처 기준)
	var map_origin = center - player_pos * scale_factor
	map_canvas.draw_circle(map_origin, 4.0, Color(0.8, 0.8, 0.2)) # 은신처 (0,0)
	map_canvas.draw_string(ThemeDB.fallback_font, map_origin + Vector2(8, 4), "은신처 (0,0)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.8, 0.2))
	
	# 500px, 1000px 거리 링
	map_canvas.draw_arc(map_origin, 500.0 * scale_factor, 0, TAU, 32, Color(0.4, 0.5, 0.4, 0.3), 1.0)
	map_canvas.draw_arc(map_origin, 800.0 * scale_factor, 0, TAU, 32, Color(0.4, 0.5, 0.4, 0.3), 1.0)
	
	# 3. 탈출구 (초록색 마커)
	for pt in extraction_points:
		var pt_pos = map_origin + pt["pos"] * scale_factor
		if pt_pos.x >= 0 and pt_pos.x <= w and pt_pos.y >= 0 and pt_pos.y <= h:
			map_canvas.draw_circle(pt_pos, 7.0, Color(0.2, 0.9, 0.3))
			map_canvas.draw_circle(pt_pos, 4.0, Color.WHITE)
			var dist = player_pos.distance_to(pt["pos"])
			var label_text = "%s (%.0fm)" % [pt["name"], dist]
			map_canvas.draw_string(ThemeDB.fallback_font, pt_pos + Vector2(10, 4), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 1.0, 0.4))
			
	# 4. 플레이어 위치 (정중앙, 빨간 화살표 마커)
	map_canvas.draw_circle(center, 6.0, Color.RED)
	var forward = Vector2.RIGHT.rotated(player_rot) * 16.0
	map_canvas.draw_line(center, center + forward, Color.YELLOW, 2.5)
	map_canvas.draw_string(ThemeDB.fallback_font, center + Vector2(10, -6), "내 위치", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.YELLOW)

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("map") or event.is_action_pressed("pause") or (event is InputEventKey and event.physical_keycode == KEY_M and event.pressed)):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func _on_close_pressed() -> void:
	get_tree().paused = false
	queue_free()
	window_closed.emit()
