# res://scenes/entities/items/ground_item.gd
class_name GroundItem
extends Area2D

## 월드 바닥에 스폰되거나 드롭된 물리 아이템 엔티티

@export var item_id: String = ""
@export var amount: int = 1
@export var custom_data: Dictionary = {}

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

var is_hovered: bool = false

func _ready() -> void:
	add_to_group("ground_items")
	update_visuals()
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup(p_id: String, p_amount: int = 1, p_custom: Dictionary = {}) -> void:
	item_id = p_id
	amount = p_amount
	custom_data = p_custom
	update_visuals()

func update_visuals() -> void:
	if not is_node_ready(): return
	
	if item_id != "":
		if ItemIconManager:
			sprite.texture = ItemIconManager.get_icon(item_id)
			sprite.scale = Vector2(0.6, 0.6)
			
		var data = ItemDatabase.get_item_data(item_id)
		var display_name = data.get("name", item_id)
		if amount > 1:
			label.text = "%s (%d)" % [display_name, amount]
		else:
			label.text = display_name
	else:
		label.text = ""

func _on_mouse_entered() -> void:
	is_hovered = true
	modulate = Color(1.3, 1.3, 1.3, 1.0)

func _on_mouse_exited() -> void:
	is_hovered = false
	modulate = Color(1.0, 1.0, 1.0, 1.0)
