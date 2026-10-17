class_name LootEntry
extends Resource

@export var item_id: String = ""
@export var weight: float = 1.0
@export var min_amount: int = 1
@export var max_amount: int = 1

func _init(p_item_id: String = "", p_weight: float = 1.0, p_min: int = 1, p_max: int = 1):
	item_id = p_item_id
	weight = p_weight
	min_amount = p_min
	max_amount = p_max
