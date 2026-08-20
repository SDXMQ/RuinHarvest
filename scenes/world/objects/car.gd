extends StaticBody2D

var body_color: Color
var rotation_angle: float = 0.0

func _ready() -> void:
	# 차량의 외형 색상 랜덤화
	var colors = [Color(0.6, 0.2, 0.2), Color(0.2, 0.3, 0.6), Color(0.5, 0.5, 0.5), Color(0.8, 0.7, 0.2), Color(0.15, 0.2, 0.15)]
	body_color = colors[randi() % colors.size()]
	
	# 심하게 부식된 느낌 추가
	var rust = Color(0.5, 0.3, 0.1)
	body_color = body_color.lerp(rust, randf_range(0.3, 0.7))
	
	rotation = rotation_angle
	
	if has_node("Visuals"):
		get_node("Visuals").draw.connect(_on_visuals_draw)
		get_node("Visuals").queue_redraw()

func _on_visuals_draw() -> void:
	var visuals = get_node("Visuals")
	# 차량 크기 (가로 48, 세로 96 - 약 1.5 x 3 타일 크기)
	var width = 48.0
	var length = 96.0
	
	var half_w = width / 2.0
	var half_l = length / 2.0
	
	# 그림자 (차량 아래)
	visuals.draw_rect(Rect2(-half_w, -half_l, width, length), Color(0, 0, 0, 0.5))
	
	# 기본 차체 (테두리 포함)
	visuals.draw_rect(Rect2(-half_w, -half_l, width, length), Color(0.1, 0.1, 0.1)) # 외곽선
	visuals.draw_rect(Rect2(-half_w + 2, -half_l + 2, width - 4, length - 4), body_color)
	
	# 차 지붕 (루프)
	var roof_w = width - 10.0
	var roof_l = length * 0.45
	visuals.draw_rect(Rect2(-roof_w/2, -roof_l/2 - 4.0, roof_w, roof_l), body_color.lightened(0.1))
	
	# 앞유리 (Windshield)
	var win_w = width - 12.0
	var win_y = -roof_l/2 - 12.0
	visuals.draw_rect(Rect2(-win_w/2, win_y, win_w, 8.0), Color(0.1, 0.15, 0.2))
	# 깨진 앞유리 디테일
	if randf() < 0.7:
		visuals.draw_line(Vector2(-win_w/2 + 2, win_y + 2), Vector2(0, win_y + 6), Color(0.3, 0.35, 0.4), 2.0)
	
	# 뒷유리
	var rwin_y = roof_l/2 - 4.0
	visuals.draw_rect(Rect2(-win_w/2, rwin_y, win_w, 6.0), Color(0.1, 0.15, 0.2))
	
	# 보닛 (Hood) 노이즈/녹 표현
	# 폴리곤이나 점을 이용해 녹슨 얼룩 표현
	for i in range(15):
		var rx = randf_range(-half_w + 4, half_w - 4)
		var ry = randf_range(-half_l + 4, win_y - 2)
		visuals.draw_circle(Vector2(rx, ry), randf_range(1.0, 3.0), Color(0.6, 0.3, 0.15, 0.8))
		
	# 전조등 (헤드라이트 - 깨짐/꺼짐)
	visuals.draw_rect(Rect2(-half_w + 4, -half_l + 2, 8, 4), Color(0.2, 0.2, 0.2))
	visuals.draw_rect(Rect2(half_w - 12, -half_l + 2, 8, 4), Color(0.2, 0.2, 0.2))
	
	# 사이드 미러
	visuals.draw_rect(Rect2(-half_w - 2, win_y + 4, 4, 6), body_color)
	visuals.draw_rect(Rect2(half_w - 2, win_y + 4, 4, 6), body_color)
