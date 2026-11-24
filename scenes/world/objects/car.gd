extends StaticBody2D

var body_color: Color
var rotation_angle: float = 0.0
var car_variant: int = -1

var interactable_type: Vector2i = TileManager.INTERACT_CAR # 기존 OBJ_CAR(폐차)와 동일한 타입 코드

func get_prompt_text() -> String:
	return "[E] 폐차 트렁크 열기"

var _car_spr: Sprite2D = null

func _ready() -> void:
	# 차량의 외형 변형 및 미세 부식 틴트 결정 (위치 기반 결정론적 변형)
	if car_variant < 0:
		var h: int = int(abs(round(position.x * 0.13 + position.y * 0.29)))
		car_variant = h % 4

	var tint_pool := [
		Color(1.0, 0.96, 0.94),
		Color(0.94, 0.98, 1.02),
		Color(0.95, 1.0, 0.92),
		Color(1.0, 0.97, 0.88)
	]
	body_color = tint_pool[car_variant % tint_pool.size()]
	rotation = rotation_angle

	var visuals := get_node_or_null("Visuals")
	if visuals == null:
		visuals = Node2D.new()
		visuals.name = "Visuals"
		add_child(visuals)
	_setup_car_sprite(visuals)
	visuals.draw.connect(_on_visuals_draw)
	visuals.queue_redraw()

func _setup_car_sprite(visuals: Node2D) -> void:
	if _car_spr:
		return
	_car_spr = Sprite2D.new()
	_car_spr.name = "CarPixelSprite"
	_car_spr.centered = true
	_car_spr.region_enabled = true
	_car_spr.region_rect = Rect2(float(car_variant * 48), 0.0, 48.0, 96.0)
	_car_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_car_spr.modulate = body_color
	_car_spr.z_index = 0
	if PixelAssetManager:
		var props_tex := PixelAssetManager.get_canvas_texture("props/world_props")
		if props_tex:
			_car_spr.texture = props_tex
		_car_spr.material = PixelAssetManager.create_pixel_entity_material(0.24)
	visuals.add_child(_car_spr)

func _on_visuals_draw() -> void:
	var visuals = get_node("Visuals")
	# 남동쪽(+5, +6) 지면 드롭 섀도우 (차량 회전을 상쇄하여 광원 방향 통일)
	var shadow_off := Vector2(5.0, 6.0).rotated(-rotation)
	visuals.draw_rect(Rect2(shadow_off - Vector2(21.0, 45.0), Vector2(42.0, 90.0)), Color(0.02, 0.03, 0.05, 0.42))
