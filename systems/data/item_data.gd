class_name ItemData
extends Resource

enum Category {
	FOOD,
	WATER,
	MEDICAL,
	WEAPON,
	TOOL,
	MATERIAL,
	EQUIPMENT,
	QUEST,
	MISC
}

@export var id: String = ""
@export var name: String = ""
@export var category: Category = Category.MISC
@export var description: String = ""
@export var stackable: bool = true
@export var max_stack: int = 1
@export var weight: float = 0.1
@export var rarity: float = 0.5
@export var value: int = 0
@export var effects: Dictionary = {}

# Grid size for Tarkov-style inventory
@export var grid_w: int = 1
@export var grid_h: int = 1

# Equipment-specific
@export var equip_slot: String = ""
@export var armor_defense: float = 0.0
@export var backpack_grid: Vector2i = Vector2i(6, 5)
@export var max_durability: int = 100
@export var weight_bonus: float = 0.0
@export var speed_bonus: float = 0.0

# Weapon-specific
@export var is_weapon: bool = false
@export var item_type: String = ""
@export var damage: float = 0.0
@export var attack_range: float = 1.0
@export var attack_speed: float = 0.5
@export var ammo: String = ""

# Tool-specific
@export var map_range: int = 0
@export var telescope_zoom: float = 1.0
@export var night_vision: bool = false

var grid_size: Vector2i:
	get: return Vector2i(grid_w, grid_h)
	set(v):
		grid_w = v.x
		grid_h = v.y

func _init(p_id: String = ""):
	id = p_id
