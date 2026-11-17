# res://scenes/world/objects/corpse_box.gd
extends StaticBody2D
class_name CorpseBox

## 용병(Scav / Raider / Boss) 사망 시 생성되는 전술 시체 전리품 가방/상자

var interactable_type: Vector2i = Vector2i(9, 2)
var corpse_tile_pos: Vector2i = Vector2i.ZERO
var box_title: String = "🎒 용병 유품 가방"
var enemy_rank: int = 3 # 3: SCAV, 4: RAIDER, 5: BOSS
var loot_inventory: Inventory = null
var is_empty_looted: bool = false

func _ready() -> void:
	add_to_group("corpse_boxes")
	collision_layer = 2
	collision_mask = 0
	z_index = 4

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 22)
	col.shape = rect
	add_child(col)

	if loot_inventory and not loot_inventory.inventory_changed.is_connected(_on_inventory_changed):
		loot_inventory.inventory_changed.connect(_on_inventory_changed)
	_on_inventory_changed()
	queue_redraw()

func setup_corpse_box(p_tile_pos: Vector2i, p_inv: Inventory, p_title: String, p_rank: int = 3) -> void:
	corpse_tile_pos = p_tile_pos
	loot_inventory = p_inv
	box_title = p_title
	enemy_rank = p_rank
	if is_inside_tree() and loot_inventory and not loot_inventory.inventory_changed.is_connected(_on_inventory_changed):
		loot_inventory.inventory_changed.connect(_on_inventory_changed)
	_on_inventory_changed()
	queue_redraw()

func _on_inventory_changed() -> void:
	var has_any := false
	if loot_inventory:
		for it in loot_inventory.items:
			if it != null and not it.is_empty() and String(it.get("id", "")) != "":
				has_any = true
				break
	is_empty_looted = not has_any
	modulate = Color(0.62, 0.64, 0.68, 0.78) if is_empty_looted else Color(1, 1, 1, 1)
	queue_redraw()

func get_prompt_text() -> String:
	if is_empty_looted:
		return "[E] %s (비어있음)" % box_title
	return "[E] %s 수색하기" % box_title

func _draw() -> void:
	# 바닥 그림자
	draw_rect(Rect2(-13, -7, 26, 18), Color(0.03, 0.04, 0.06, 0.65))
	# 외곽 검은색 도트 테두리 (1px)
	draw_rect(Rect2(-12, -9, 24, 18), Color(0.06, 0.07, 0.09, 0.98))

	var body_col := Color(0.27, 0.33, 0.24) # SCAV 카키 더플백
	var trim_col := Color(0.45, 0.52, 0.36)
	var badge_col := Color(0.88, 0.74, 0.28)
	if enemy_rank == 4:
		body_col = Color(0.20, 0.24, 0.30) # RAIDER 전술 하드케이스
		trim_col = Color(0.38, 0.46, 0.56)
		badge_col = Color(0.35, 0.85, 1.0)
	elif enemy_rank == 5:
		body_col = Color(0.32, 0.16, 0.16) # BOSS 지휘관 특수 군장함
		trim_col = Color(0.85, 0.68, 0.22)
		badge_col = Color(1.0, 0.85, 0.25)

	# 상자 본체 및 상단 하이라이트
	draw_rect(Rect2(-11, -8, 22, 16), body_col)
	draw_rect(Rect2(-11, -8, 22, 3), trim_col)
	draw_rect(Rect2(-11, 5, 22, 3), body_col.darkened(0.28))

	# 전술 스트랩 2줄
	draw_rect(Rect2(-7, -8, 2, 16), Color(0.12, 0.14, 0.16, 0.95))
	draw_rect(Rect2(5, -8, 2, 16), Color(0.12, 0.14, 0.16, 0.95))
	# 버클 도트
	draw_rect(Rect2(-7, -1, 2, 2), badge_col)
	draw_rect(Rect2(5, -1, 2, 2), badge_col)

	# 중앙 인식표/십자 마크
	draw_rect(Rect2(-2, -3, 4, 6), badge_col)
	draw_rect(Rect2(-1, -2, 2, 4), Color(0.12, 0.14, 0.18))
