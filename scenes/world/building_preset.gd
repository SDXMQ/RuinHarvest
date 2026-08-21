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
				BuildingType.CHURCH
			]
		"commercial":
			pool = [
				BuildingType.SHOP,
				BuildingType.SUPERMARKET,
				BuildingType.GAS_STATION,
				BuildingType.POLICE_STATION,
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
				BuildingType.POLICE_STATION
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
				"width": 6, "height": 6,
				"floor_tile": TileManager.TILE_FLOOR_WOOD,
				"has_yard": true,
				"yard_margin": 2,
				"doors": [Vector2i(3, 5)],
				"windows": [Vector2i(1, 0), Vector2i(4, 0), Vector2i(0, 3), Vector2i(5, 3)],
				"shape": "rect"
			}
		BuildingType.MEDIUM_HOUSE:
			return {
				"type_name": "medium_house",
				"width": 8, "height": 8,
				"floor_tile": TileManager.TILE_FLOOR_WOOD,
				"has_yard": true,
				"yard_margin": 3,
				"doors": [Vector2i(4, 7)],
				"windows": [Vector2i(2, 0), Vector2i(5, 0), Vector2i(0, 3), Vector2i(7, 3), Vector2i(0, 5), Vector2i(7, 5)],
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
				"windows": [Vector2i(2, 0), Vector2i(6, 0), Vector2i(0, 4), Vector2i(9, 3)],
				"shape": "l_shape"
			}
		BuildingType.SHOP:
			return {
				"type_name": "shop",
				"width": 8, "height": 6,
				"floor_tile": TileManager.TILE_FLOOR_TILE,
				"has_yard": false,
				"yard_margin": 0,
				"doors": [Vector2i(4, 5)],
				"windows": [Vector2i(2, 5), Vector2i(6, 5), Vector2i(2, 0), Vector2i(5, 0)],
				"shape": "rect"
			}
		BuildingType.APARTMENT:
			return {
				"type_name": "apartment",
				"width": 12, "height": 10,
				"floor_tile": TileManager.TILE_FLOOR_TILE,
				"has_yard": false,
				"yard_margin": 1,
				"doors": [Vector2i(4, 9), Vector2i(7, 9)],
				"windows": [Vector2i(2, 0), Vector2i(5, 0), Vector2i(8, 0), Vector2i(10, 0), Vector2i(0, 3), Vector2i(11, 3), Vector2i(0, 6), Vector2i(11, 6)],
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
				"shape": "rect"
			}
		BuildingType.GAS_STATION:
			return {
				"type_name": "gas_station",
				"width": 10, "height": 7,
				"floor_tile": TileManager.TILE_CONCRETE,
				"has_yard": false,
				"yard_margin": 0,
				"doors": [Vector2i(5, 6)],
				"windows": [Vector2i(3, 6), Vector2i(7, 6), Vector2i(2, 0), Vector2i(7, 0)],
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
				"shape": "rect"
			}
		BuildingType.POLICE_STATION:
			return {
				"type_name": "police_station",
				"width": 10, "height": 8,
				"floor_tile": TileManager.TILE_FLOOR_TILE,
				"has_yard": false,
				"yard_margin": 1,
				"doors": [Vector2i(5, 7)],
				"windows": [Vector2i(2, 7), Vector2i(8, 7), Vector2i(2, 0), Vector2i(7, 0), Vector2i(0, 4), Vector2i(9, 4)],
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
				"windows": [Vector2i(2, 9), Vector2i(9, 9), Vector2i(2, 0), Vector2i(5, 0), Vector2i(8, 0), Vector2i(0, 4), Vector2i(11, 4)],
				"shape": "rect"
			}
		BuildingType.MILITARY_BUNKER:
			return {
				"type_name": "military_bunker",
				"width": 8, "height": 8,
				"floor_tile": TileManager.TILE_CONCRETE,
				"has_yard": true,
				"yard_margin": 3,
				"doors": [Vector2i(4, 7)],
				"windows": [Vector2i(2, 0), Vector2i(5, 0)],
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
				"shape": "rect"
			}
			
	return {}
