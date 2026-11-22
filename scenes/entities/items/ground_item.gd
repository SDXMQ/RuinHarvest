# res://scenes/entities/items/ground_item.gd
class_name GroundItem
extends Area2D

## 월드 바닥에 스폰되거나 드롭된 물리 아이템 엔티티 (2D 시야 차폐 마스킹 적용)

@export var item_id: String = ""
@export var amount: int = 1
@export var custom_data: Dictionary = {}

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

var is_hovered: bool = false
var _los_timer: float = 0.0
var _target_alpha: float = 1.0

func _ready() -> void:
	add_to_group("ground_items")
	update_visuals()
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _process(delta: float) -> void:
	_los_timer -= delta
	if _los_timer <= 0.0:
		_los_timer = 0.12
		_evaluate_visibility()
	modulate.a = lerp(modulate.a, _target_alpha, clamp(delta * 12.0, 0.0, 1.0))

func _evaluate_visibility() -> void:
	var p = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(p):
		_target_alpha = 1.0
		return
	var dist = global_position.distance_to(p.global_position)
	if dist > 480.0:
		_target_alpha = 0.0
		return
	var p_forward = Vector2.RIGHT.rotated(p.rotation)
	var dir_from_p = p.global_position.direction_to(global_position)
	var in_close_circle = dist <= 85.0
	var in_fov_cone = p_forward.dot(dir_from_p) >= 0.35 # 약 140도 전방 시야각
	if not in_close_circle and not in_fov_cone:
		_target_alpha = 0.0
		return
	# 벽면(Collision Layer 1) 차폐 검사
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(p.global_position, global_position, 1)
	query.exclude = [p.get_rid()]
	var hit = space_state.intersect_ray(query)
	_target_alpha = 1.0 if hit.is_empty() else 0.0

func setup(p_id: String, p_amount: int = 1, p_custom: Dictionary = {}) -> void:
	item_id = p_id
	amount = p_amount
	custom_data = p_custom
	update_visuals()

func _get_or_create_wishlist_badge() -> Sprite2D:
	var badge: Sprite2D = get_node_or_null("WishlistBadge") as Sprite2D
	if badge == null:
		badge = Sprite2D.new()
		badge.name = "WishlistBadge"
		if UiIconManager:
			badge.texture = UiIconManager.get_icon("star")
		badge.scale = Vector2(0.75, 0.75)
		badge.position = Vector2(10.0, -10.0)
		badge.z_index = 2
		add_child(badge)
	return badge

func update_visuals() -> void:
	if not is_node_ready(): return
	
	var badge := _get_or_create_wishlist_badge()
	if item_id != "":
		if ItemIconManager:
			sprite.texture = ItemIconManager.get_icon(item_id)
			sprite.scale = Vector2(0.6, 0.6)
			
		var data = ItemDatabase.get_item_data(item_id)
		var display_name = data.get("name", item_id)
		var is_wish := HideoutProgression.is_wishlist_item(item_id)
		if amount > 1:
			label.text = "%s (%d)" % [display_name, amount]
		else:
			label.text = "%s" % display_name
		if is_wish:
			label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
		else:
			label.remove_theme_color_override("font_color")
		badge.visible = is_wish
	else:
		label.text = ""
		label.remove_theme_color_override("font_color")
		badge.visible = false

func _on_mouse_entered() -> void:
	is_hovered = true
	modulate = Color(1.3, 1.3, 1.3, modulate.a)

func _on_mouse_exited() -> void:
	is_hovered = false
	modulate = Color(1.0, 1.0, 1.0, modulate.a)
