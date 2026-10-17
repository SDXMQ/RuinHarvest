# res://scenes/world/objects/airdrop_crate.gd
extends StaticBody2D

var interactable_type: Vector2i = Vector2i(7, 2) # 군용 항공 보급품 상자
var flare_timer: float = 0.0
var is_looted: bool = false

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(36, 36)
	col.shape = rect
	add_child(col)

func _process(delta: float) -> void:
	flare_timer += delta
	queue_redraw()

func _draw() -> void:
	# 낙하산 천 (상자 뒤편에 펼쳐진 카모플라주 낙하산)
	var chute_pts = PackedVector2Array([
		Vector2(-18, -14), Vector2(-36, -34), Vector2(-12, -42),
		Vector2(14, -38), Vector2(32, -26), Vector2(18, -14)
	])
	draw_colored_polygon(chute_pts, Color(0.32, 0.38, 0.26, 0.85))
	draw_line(Vector2(-14, -14), Vector2(-28, -32), Color(0.7, 0.7, 0.6, 0.6), 1.0)
	draw_line(Vector2(14, -14), Vector2(24, -26), Color(0.7, 0.7, 0.6, 0.6), 1.0)

	# 그림자
	draw_rect(Rect2(-20, -16, 40, 36), Color(0, 0, 0, 0.5))

	# 군용 컨테이너 본체
	draw_rect(Rect2(-18, -18, 36, 36), Color(0.12, 0.14, 0.10))
	draw_rect(Rect2(-16, -16, 32, 32), Color(0.24, 0.32, 0.20))

	# 철제 보강 프레임 및 노란색 UN/군수 마킹
	draw_rect(Rect2(-16, -4, 32, 8), Color(0.18, 0.22, 0.15))
	draw_rect(Rect2(-4, -16, 8, 32), Color(0.18, 0.22, 0.15))
	draw_rect(Rect2(-8, -8, 16, 16), Color(0.85, 0.68, 0.15), false, 2.0)

	# 붉은색 신호탄 플레어 및 연기 애니메이션
	var pulse = 0.6 + 0.4 * sin(flare_timer * 6.0)
	var flare_pos = Vector2(22, 14)
	draw_circle(flare_pos, 4.0, Color(0.9, 0.2, 0.1))
	draw_circle(flare_pos, 10.0 * pulse, Color(1.0, 0.25, 0.15, 0.45 * pulse))
	draw_circle(flare_pos, 20.0 * pulse, Color(1.0, 0.15, 0.1, 0.2 * pulse))

	# 피어오르는 붉은 연막 원들
	for i in range(3):
		var t = fmod(flare_timer * 0.8 + float(i) * 0.33, 1.0)
		var smoke_pos = flare_pos + Vector2(sin(flare_timer * 2.0 + i) * 8.0 * t, -t * 32.0)
		var smoke_alpha = (1.0 - t) * 0.45
		draw_circle(smoke_pos, 5.0 + t * 10.0, Color(0.95, 0.25, 0.2, smoke_alpha))
