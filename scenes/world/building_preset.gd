# res://scenes/world/building_preset.gd
class_name BuildingPresets
extends RefCounted

## 12종의 건물 프리셋 데이터 및 레이아웃 정의

enum BuildingType {
	SMALL_HOUSE,
	MEDIUM_HOUSE,
	L_SHAPE_HOUSE,
	SHOP,
	APARTMENT,
	WAREHOUSE,
	GAS_STATION,
	CHURCH,
	POLICE_STATION,
	HOSPITAL,
	MILITARY_BUNKER,
	SUPERMARKET
}

static func get_preset_for_biome(biome: String, rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array[BuildingType] = []
	match biome:
		"residential":
			pool = [
				BuildingType.SMALL_HOUSE,
				BuildingType.MEDIUM_HOUSE,
				BuildingType.L_SHAPE_HOUSE,
				BuildingType.SHOP,
				BuildingType.CHURCH,
				BuildingType.APARTMENT
			]
		"commercial":
			pool = [
				BuildingType.SHOP,
				BuildingType.SUPERMARKET,
				BuildingType.GAS_STATION,
				BuildingType.POLICE_STATION,
				BuildingType.HOSPITAL,
				BuildingType.APARTMENT
			]
		"industrial":
			pool = [
				BuildingType.WAREHOUSE,
				BuildingType.GAS_STATION,
				BuildingType.SHOP
			]
		"military":
			pool = [
				BuildingType.MILITARY_BUNKER,
				BuildingType.WAREHOUSE,
				BuildingType.POLICE_STATION,
				BuildingType.HOSPITAL
			]
		_: # forest / default
			pool = [
				BuildingType.SMALL_HOUSE,
				BuildingType.WAREHOUSE
			]
			
	var choice = pool[rng.randi_range(0, pool.size() - 1)]
	return get_preset(choice)

static func get_preset(type: BuildingType) -> Dictionary:
	match type:
		BuildingType.SMALL_HOUSE:
			return {
				"type_name": "small_house",
				"width": 7, "height": 7,
				"floor_tile": TileManager.TILE_FLOOR_WOOD,
				"has_yard": true,
				"yard_margin": 2,
				"doors": [Vector2i(3, 6)],
				"windows": [Vector2i(1, 0), Vector2i(5, 0), Vector2i(0, 3), Vector2i(6, 3)],
				"inner_walls": [Vector2i(3, 1), Vector2i(3, 2), Vector2i(1, 3), Vector2i(3, 3)],
				"inner_doors": [Vector2i(2, 3)],
				"locked_doors": [],
				"furniture": [
					{"x": 1, "y": 1, "type": "bed"},
					{"x": 2, "y": 1, "type": "desk"},
					{"x": 5, "y": 1, "type": "fridge"},
					{"x": 5, "y": 2, "type": "shelf"},
					{"x": 5, "y": 4, "type": "desk"},
					{"x": 1, "y": 5, "type": "shelf"}
				],
				"shape": "rect"
			}
		BuildingType.MEDIUM_HOUSE:
			return {
				"type_name": "medium_house",
				"width": 9, "height": 8,
				"floor_tile": TileManager.TILE_FLOOR_WOOD,
				"has_yard": true,
				"yard_margin": 2,
				"doors": [Vector2i(4, 7)],
				"windows": [Vector2i(2, 0), Vector2i(6, 0), Vector2i(0, 2), Vector2i(8, 2), Vector2i(0, 5), Vector2i(8, 5)],
				"inner_walls": [
					Vector2i(3, 1), Vector2i(3, 3), Vector2i(3, 4), Vector2i(1, 4), Vector2i(2, 4),
					Vector2i(5, 1), Vector2i(5, 3), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4)
				],
				"inner_doors": [Vector2i(3, 2), Vector2i(5, 2)],
				"locked_doors": [],
				"furniture": [
					{"x": 1, "y": 1, "type": "bed"},
					{"x": 1, "y": 3, "type": "desk"},
					{"x": 7, "y": 1, "type": "fridge"},
					{"x": 7, "y": 3, "type": "shelf"},
					{"x": 1, "y": 5, "type": "shelf"},
					{"x": 1, "y": 6, "type": "desk"},
					{"x": 7, "y": 6, "type": "crate"}
				],
				"shape": "rect"
			}
		BuildingType.L_SHAPE_HOUSE:
			return {
				"type_name": "l_shape_house",
				"width": 10, "height": 10,
				"floor_tile": TileManager.TILE_FLOOR_WOOD,
				"has_yard": true,
				"yard_margin": 2,
				"doors": [Vector2i(3, 9)],
				"windows": [Vector2i(2, 0), Vector2i(0, 3), Vector2i(0, 7), Vector2i(7, 5), Vector2i(9, 7)],
				"inner_walls": [
					Vector2i(1, 4), Vector2i(3, 4),
					Vector2i(5, 6), Vector2i(5, 8)
				],
				"inner_doors": [Vector2i(2, 4), Vector2i(5, 7)],
				"locked_doors": [],
				"furniture": [
					{"x": 1, "y": 1, "type": "bed"},
					{"x": 3, "y": 1, "type": "desk"},
					{"x": 1, "y": 6, "type": "fridge"},
					{"x": 1, "y": 8, "type": "shelf"},
					{"x": 8, "y": 6, "type": "bed"},
					{"x": 8, "y": 8, "type": "shelf"}
				],
				"shape": "l_shape"
			}
		BuildingType.SHOP:
			return {
				"type_name": "shop",
				"width": 8, "height": 8,
				"floor_tile": TileManager.TILE_FLOOR_TILE,
				"has_yard": false,
				"yard_margin": 0,
				"doors": [Vector2i(4, 7)],
				"windows": [Vector2i(2, 7), Vector2i(6, 7), Vector2i(2, 0), Vector2i(5, 0)],
				"inner_walls": [Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(6, 3)],
				"inner_doors": [Vector2i(5, 3)],
				"locked_doors": [],
				"furniture": [
					{"x": 1, "y": 1, "type": "crate"},
					{"x": 2, "y": 1, "type": "shelf"},
					{"x": 6, "y": 1, "type": "barrel"},
					{"x": 1, "y": 4, "type": "fridge"},
					{"x": 1, "y": 5, "type": "fridge"},
					{"x": 3, "y": 5, "type": "shelf"},
					{"x": 6, "y": 5, "type": "desk"}
				],
				"shape": "rect"
			}
		BuildingType.APARTMENT:
			return {
				"type_name": "apartment",
				"width": 12, "height": 10,
				"floor_tile": TileManager.TILE_FLOOR_TILE,
				"has_yard": false,
				"yard_margin": 1,
				"doors": [Vector2i(5, 9), Vector2i(6, 9)],
				"windows": [Vector2i(2, 0), Vector2i(9, 0), Vector2i(0, 3), Vector2i(11, 3), Vector2i(0, 7), Vector2i(11, 7)],
				"inner_walls": [
					Vector2i(4, 1), Vector2i(4, 3), Vector2i(4, 4), Vector2i(4, 5), Vector2i(4, 6), Vector2i(4, 8),
					Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5),
					Vector2i(7, 1), Vector2i(7, 3), Vector2i(7, 4), Vector2i(7, 5), Vector2i(7, 6), Vector2i(7, 8),
					Vector2i(8, 5), Vector2i(9, 5), Vector2i(10, 5)
				],
				"inner_doors": [Vector2i(4, 2), Vector2i(4, 7), Vector2i(7, 2), Vector2i(7, 7)],
				"locked_doors": [],
				"furniture": [
					{"x": 1, "y": 1, "type": "bed"}, {"x": 1, "y": 4, "type": "desk"}, {"x": 3, "y": 4, "type": "fridge"},
					{"x": 1, "y": 8, "type": "bed"}, {"x": 1, "y": 6, "type": "shelf"}, {"x": 3, "y": 8, "type": "desk"},
					{"x": 10, "y": 1, "type": "bed"}, {"x": 10, "y": 4, "type": "fridge"}, {"x": 8, "y": 1, "type": "shelf"},
					{"x": 10, "y": 8, "type": "bed"}, {"x": 10, "y": 6, "type": "desk"}, {"x": 8, "y": 8, "type": "crate"}
				],
				"shape": "rect"
			}
		BuildingType.WAREHOUSE:
			return {
				"type_name": "warehouse",
				"width": 10, "height": 8,
				"floor_tile": TileManager.TILE_CONCRETE,
				"has_yard": false,
				"yard_margin": 1,
				"doors": [Vector2i(5, 7)],
				"windows": [Vector2i(2, 0), Vector2i(7, 0)],
				"inner_walls": [Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 3), Vector2i(1, 3), Vector2i(3, 3)],
				"inner_doors": [Vector2i(2, 3)],
				"locked_doors": [],
				"furniture": [
					{"x": 1, "y": 1, "type": "desk"},
					{"x": 3, "y": 1, "type": "shelf"},
					{"x": 8, "y": 1, "type": "crate"},
					{"x": 8, "y": 2, "type": "crate"},
					{"x": 8, "y": 4, "type": "barrel"},
					{"x": 8, "y": 5, "type": "barrel"},
					{"x": 6, "y": 2, "type": "shelf"},
					{"x": 1, "y": 5, "type": "crate"}
				],
				"shape": "rect"
			}
		BuildingType.GAS_STATION:
			return {
				"type_name": "gas_station",
				"width": 10, "height": 7,
				"floor_tile": TileManager.TILE_CONCRETE,
				"has_yard": false,
				"yard_margin": 0,
				"doors": [Vector2i(3, 6)],
				"windows": [Vector2i(1, 6), Vector2i(5, 6), Vector2i(2, 0), Vector2i(7, 0)],
				"inner_walls": [Vector2i(6, 1), Vector2i(6, 2), Vector2i(6, 4), Vector2i(6, 5)],
				"inner_doors": [Vector2i(6, 3)],
				"locked_doors": [],
				"furniture": [
					{"x": 1, "y": 1, "type": "fridge"},
					{"x": 2, "y": 1, "type": "fridge"},
					{"x": 1, "y": 4, "type": "shelf"},
					{"x": 4, "y": 2, "type": "desk"},
					{"x": 8, "y": 1, "type": "barrel"},
					{"x": 8, "y": 2, "type": "crate"},
					{"x": 8, "y": 5, "type": "shelf"}
				],
				"shape": "rect"
			}
		BuildingType.CHURCH:
			return {
				"type_name": "church",
				"width": 8, "height": 12,
				"floor_tile": TileManager.TILE_FLOOR_WOOD,
				"has_yard": true,
				"yard_margin": 2,
				"doors": [Vector2i(4, 11)],
				"windows": [Vector2i(0, 3), Vector2i(7, 3), Vector2i(0, 6), Vector2i(7, 6), Vector2i(0, 9), Vector2i(7, 9), Vector2i(4, 0)],
				"inner_walls": [Vector2i(1, 3), Vector2i(2, 3), Vector2i(5, 3), Vector2i(6, 3)],
				"inner_doors": [Vector2i(3, 3), Vector2i(4, 3)],
				"locked_doors": [],
				"furniture": [
					{"x": 1, "y": 1, "type": "shelf"},
					{"x": 6, "y": 1, "type": "desk"},
					{"x": 3, "y": 1, "type": "crate"},
					{"x": 1, "y": 5, "type": "desk"},
					{"x": 6, "y": 5, "type": "desk"},
					{"x": 1, "y": 8, "type": "desk"},
					{"x": 6, "y": 8, "type": "desk"}
				],
				"shape": "rect"
			}
		BuildingType.POLICE_STATION:
			return {
				"type_name": "police_station",
				"width": 10, "height": 8,
				"floor_tile": TileManager.TILE_FLOOR_TILE,
				"has_yard": false,
				"yard_margin": 1,
				"doors": [Vector2i(4, 7)],
				"windows": [Vector2i(2, 7), Vector2i(7, 7), Vector2i(2, 0), Vector2i(0, 4)],
				"inner_walls": [
					Vector2i(1, 4), Vector2i(2, 4), Vector2i(4, 4),
					Vector2i(5, 1), Vector2i(5, 2), Vector2i(5, 3), Vector2i(5, 4),
					Vector2i(6, 4), Vector2i(8, 4)
				],
				"inner_doors": [Vector2i(3, 4)],
				"locked_doors": [Vector2i(7, 4)],
				"locked_rect": Rect2i(6, 1, 3, 3),
				"locked_key": "무기고 열쇠",
				"furniture": [
					{"x": 1, "y": 1, "type": "desk"},
					{"x": 4, "y": 1, "type": "shelf"},
					{"x": 6, "y": 1, "type": "crate"},
					{"x": 8, "y": 1, "type": "shelf"},
					{"x": 8, "y": 2, "type": "crate"},
					{"x": 1, "y": 5, "type": "desk"},
					{"x": 8, "y": 6, "type": "shelf"}
				],
				"shape": "rect"
			}
		BuildingType.HOSPITAL:
			return {
				"type_name": "hospital",
				"width": 12, "height": 10,
				"floor_tile": TileManager.TILE_FLOOR_TILE,
				"has_yard": false,
				"yard_margin": 1,
				"doors": [Vector2i(5, 9), Vector2i(6, 9)],
				"windows": [Vector2i(2, 9), Vector2i(9, 9), Vector2i(2, 0), Vector2i(5, 0), Vector2i(0, 3), Vector2i(11, 7)],
				"inner_walls": [
					Vector2i(4, 1), Vector2i(4, 2), Vector2i(4, 4), Vector2i(4, 5), Vector2i(4, 6), Vector2i(4, 8),
					Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5),
					Vector2i(7, 1), Vector2i(7, 2), Vector2i(7, 3), Vector2i(7, 4),
					Vector2i(8, 4), Vector2i(10, 4)
				],
				"inner_doors": [Vector2i(4, 3), Vector2i(4, 7)],
				"locked_doors": [Vector2i(9, 4)],
				"locked_rect": Rect2i(8, 1, 3, 3),
				"locked_key": "보안 키카드",
				"furniture": [
					{"x": 1, "y": 1, "type": "bed"}, {"x": 1, "y": 3, "type": "bed"}, {"x": 3, "y": 1, "type": "shelf"},
					{"x": 1, "y": 6, "type": "bed"}, {"x": 1, "y": 8, "type": "bed"}, {"x": 3, "y": 8, "type": "fridge"},
					{"x": 8, "y": 1, "type": "desk"}, {"x": 10, "y": 1, "type": "crate"}, {"x": 10, "y": 2, "type": "fridge"},
					{"x": 10, "y": 6, "type": "desk"}, {"x": 10, "y": 8, "type": "shelf"}
				],
				"shape": "rect"
			}
		BuildingType.MILITARY_BUNKER:
			return {
				"type_name": "military_bunker",
				"width": 9, "height": 9,
				"floor_tile": TileManager.TILE_CONCRETE,
				"has_yard": true,
				"yard_margin": 2,
				"doors": [Vector2i(4, 8)],
				"windows": [Vector2i(2, 0)],
				"inner_walls": [
					Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 4), Vector2i(1, 4), Vector2i(2, 4),
					Vector2i(5, 1), Vector2i(5, 2), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4)
				],
				"inner_doors": [Vector2i(3, 3)],
				"locked_doors": [Vector2i(5, 3)],
				"locked_rect": Rect2i(6, 1, 2, 3),
				"locked_key": "무기고 열쇠",
				"furniture": [
					{"x": 1, "y": 1, "type": "bed"}, {"x": 1, "y": 3, "type": "bed"},
					{"x": 7, "y": 1, "type": "crate"}, {"x": 7, "y": 2, "type": "shelf"}, {"x": 7, "y": 3, "type": "crate"},
					{"x": 1, "y": 6, "type": "desk"}, {"x": 1, "y": 7, "type": "shelf"}, {"x": 7, "y": 7, "type": "barrel"}
				],
				"shape": "rect"
			}
		BuildingType.SUPERMARKET:
			return {
				"type_name": "supermarket",
				"width": 14, "height": 10,
				"floor_tile": TileManager.TILE_FLOOR_TILE,
				"has_yard": false,
				"yard_margin": 1,
				"doors": [Vector2i(6, 9), Vector2i(7, 9)],
				"windows": [Vector2i(2, 9), Vector2i(4, 9), Vector2i(9, 9), Vector2i(11, 9), Vector2i(3, 0), Vector2i(10, 0)],
				"inner_walls": [
					Vector2i(1, 3), Vector2i(2, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(6, 3),
					Vector2i(7, 3), Vector2i(8, 3), Vector2i(9, 3), Vector2i(11, 3), Vector2i(12, 3)
				],
				"inner_doors": [Vector2i(3, 3), Vector2i(10, 3)],
				"locked_doors": [],
				"furniture": [
					{"x": 1, "y": 1, "type": "crate"}, {"x": 2, "y": 1, "type": "crate"}, {"x": 6, "y": 1, "type": "shelf"},
					{"x": 7, "y": 1, "type": "shelf"}, {"x": 11, "y": 1, "type": "barrel"}, {"x": 12, "y": 1, "type": "crate"},
					{"x": 1, "y": 4, "type": "fridge"}, {"x": 1, "y": 5, "type": "fridge"}, {"x": 1, "y": 6, "type": "fridge"},
					{"x": 4, "y": 5, "type": "shelf"}, {"x": 4, "y": 6, "type": "shelf"},
					{"x": 9, "y": 5, "type": "shelf"}, {"x": 9, "y": 6, "type": "shelf"},
					{"x": 2, "y": 8, "type": "desk"}, {"x": 11, "y": 8, "type": "desk"}
				],
				"shape": "rect"
			}
			
	return {}
