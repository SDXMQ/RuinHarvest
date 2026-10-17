# res://autoload/item_database.gd
extends Node

## 게임 내 모든 40+ 종의 아이템 데이터와 13개 장소별 루트 테이블을 관리합니다.

enum ItemCategory {
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

var items: Dictionary = {}


func _ready():
	_load_all_items()

func _load_all_items():
	var dir = DirAccess.open("res://data/items/")
	if dir:
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if fname.ends_with(".tres"):
				var res = load("res://data/items/" + fname)
				if res and res is ItemData:
					var d: Dictionary = {
						"id": res.id,
						"name": res.name if res.name != "" else res.id,
						"category": res.category,
						"description": res.description,
						"stackable": res.stackable,
						"max_stack": res.max_stack,
						"weight": res.weight,
						"rarity": res.rarity,
						"value": res.value,
						"effects": res.effects.duplicate()
					}
					if res.grid_w > 1 or res.grid_h > 1:
						d["grid_w"] = res.grid_w
						d["grid_h"] = res.grid_h
					if res.equip_slot != "":
						d["equip_slot"] = res.equip_slot
					if res.armor_defense > 0.0:
						d["defense"] = res.armor_defense
					if res.max_durability > 0:
						d["max_durability"] = res.max_durability
					if res.weight_bonus != 0.0:
						d["weight_bonus"] = res.weight_bonus
					if res.speed_bonus != 0.0:
						d["speed_bonus"] = res.speed_bonus
					if res.backpack_grid != Vector2i.ZERO and res.category == ItemCategory.EQUIPMENT:
						d["backpack_grid"] = res.backpack_grid
					if res.item_type != "":
						d["type"] = res.item_type
					if res.damage > 0.0:
						d["damage"] = res.damage
					if res.attack_range > 0.0:
						d["range"] = res.attack_range
					if res.attack_speed > 0.0:
						d["attack_speed"] = res.attack_speed
					if res.ammo != "":
						d["ammo"] = res.ammo
					items[res.id] = d
			fname = dir.get_next()

# 13개 장소별 루트 테이블
var loot_tables: Dictionary = {
	"crate": [
		{"id": "식량통조림", "chance": 0.35}, {"id": "생수", "chance": 0.35},
		{"id": "붕대", "chance": 0.25}, {"id": "탄약", "chance": 0.2},
		{"id": "권총", "chance": 0.05}, {"id": "손전등", "chance": 0.1}
	],
	"barrel": [
		{"id": "고철", "chance": 0.5}, {"id": "화약", "chance": 0.2},
		{"id": "폐전선", "chance": 0.3}, {"id": "생수", "chance": 0.15}
	],
	"car": [
		{"id": "고철", "chance": 0.4}, {"id": "비상용 배터리", "chance": 0.2},
		{"id": "나침반", "chance": 0.1}, {"id": "금시계", "chance": 0.05},
		{"id": "지도", "chance": 0.05}
	],
	"fridge": [
		{"id": "식량통조림", "chance": 0.5}, {"id": "생수", "chance": 0.5},
		{"id": "초콜릿", "chance": 0.3}, {"id": "에너지드링크", "chance": 0.25}
	],
	"house": [
		{"id": "식량통조림", "chance": 0.3}, {"id": "생수", "chance": 0.3},
		{"id": "마른 빵", "chance": 0.2}, {"id": "나이프", "chance": 0.1},
		{"id": "천", "chance": 0.2}, {"id": "붕대", "chance": 0.15},
		{"id": "은반지", "chance": 0.15}, {"id": "금시계", "chance": 0.05}
	],
	"hospital": [
		{"id": "구급상자", "chance": 0.4}, {"id": "진통제", "chance": 0.3},
		{"id": "붕대", "chance": 0.4}, {"id": "약초", "chance": 0.15},
		{"id": "고급 치료킷", "chance": 0.1}
	],
	"military": [
		{"id": "탄약", "chance": 0.35}, {"id": "권총", "chance": 0.1},
		{"id": "레버액션 소총", "chance": 0.05}, {"id": "방탄조끼", "chance": 0.12},
		{"id": "구급상자", "chance": 0.2}, {"id": "수류탄", "chance": 0.1},
		{"id": "암호화된 SSD", "chance": 0.05}
	]
}

# 3인 상인 데이터 정의
var traders: Dictionary = {
	"prapor": {
		"name": "프라포 (무기/군수품)",
		"desc": "전직 군수 보급관. 총기와 탄약, 방어구를 취급합니다.",
		"stock": [
			{"id": "권총", "price": 18000},
			{"id": "레버액션 소총", "price": 35000},
			{"id": "탄약", "price": 200, "amount": 30},
			{"id": "수류탄", "price": 4000},
			{"id": "파이프", "price": 1500},
			{"id": "방탄조끼", "price": 15000}
		]
	},
	"therapist": {
		"name": "테라피스트 (의료/식량)",
		"desc": "응급 의사 출신. 의약품과 식수를 공정하게 거래합니다.",
		"stock": [
			{"id": "붕대", "price": 800},
			{"id": "진통제", "price": 2500},
			{"id": "구급상자", "price": 4000},
			{"id": "식량통조림", "price": 1200},
			{"id": "생수", "price": 600},
			{"id": "에너지바", "price": 800}
		]
	},
	"fence": {
		"name": "펜스 (잡화/암시장)",
		"desc": "무엇이든 사고파는 암시장 중개인. 희귀 부품과 도구를 취급합니다.",
		"stock": [
			{"id": "고철", "price": 400, "amount": 5},
			{"id": "못", "price": 100, "amount": 10},
			{"id": "천", "price": 200, "amount": 5},
			{"id": "폐전선", "price": 1200},
			{"id": "손전등", "price": 2000},
			{"id": "가방", "price": 8000}
		]
	}
}

func get_item_data(id: String) -> Dictionary:
	if items.has(id):
		var d = items[id].duplicate()
		d["name"] = id
		return d
		
	# 무기 부품 데이터베이스 조회
	if WeaponPartsDatabase.PARTS.has(id):
		var p = WeaponPartsDatabase.PARTS[id].duplicate()
		p["category"] = ItemCategory.TOOL
		p["stackable"] = false
		p["max_stack"] = 1
		p["weight"] = p.get("weight", 0.3)
		p["description"] = "[총기 부품: %s] %s" % [p.get("slot", ""), p.get("name", id)]
		return p
		
	# 리시버 데이터베이스 조회
	if WeaponPartsDatabase.RECEIVERS.has(id):
		var r = WeaponPartsDatabase.RECEIVERS[id].duplicate()
		r["category"] = ItemCategory.WEAPON
		r["stackable"] = false
		r["max_stack"] = 1
		r["type"] = "receiver"
		r["description"] = "[총기 리시버] %s" % r.get("name", id)
		return r
		
	return {"name": id, "weight": 0.1, "max_stack": 1, "value": 500}

func generate_loot(table_name: String, rolls: int = 3) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var pool = loot_tables.get(table_name, loot_tables.get("crate", []))
	
	for i in range(rolls):
		for entry in pool:
			if randf() < entry["chance"]:
				_add_to_loot(results, entry["id"], 1)
				break
				
	return results

func _add_to_loot(results: Array, id: String, amount: int) -> void:
	var item_data = get_item_data(id)
	var max_stack = item_data.get("max_stack", 1)
	
	for res in results:
		if res["id"] == id and res["amount"] < max_stack:
			res["amount"] += amount
			return
			
	results.append({"id": id, "amount": amount})

func get_item_grid_size(id: String) -> Vector2i:
	var data = get_item_data(id)
	if data.has("grid_w") and data.has("grid_h"):
		return Vector2i(data["grid_w"], data["grid_h"])
		
	var cat = data.get("category", -1)
	var type = data.get("type", "")
	
	# 무기 부착물/파츠
	if WeaponPartsDatabase and WeaponPartsDatabase.PARTS.has(id):
		var pslot = WeaponPartsDatabase.PARTS[id].get("slot", "")
		if pslot == "barrel" or pslot == "stock":
			return Vector2i(1, 2)
		return Vector2i(1, 1)
	
	# 무기 및 리시버
	if cat == ItemCategory.WEAPON or type == "receiver":
		if type == "melee":
			return Vector2i(1, 3)
		elif id == "권총" or id.begins_with("M9") or id.begins_with("MP5"):
			return Vector2i(1, 2)
		elif id == "수류탄":
			return Vector2i(1, 1)
		elif id == "탄약" or id.contains("9mm") or id.contains("5.56") or id.contains("7.62") or id.contains("12게이지") or id.contains(".45"):
			return Vector2i(1, 1)
		else:
			return Vector2i(2, 4) # 소총, 샷건, 저격총 등
			
	# 장비 (헬멧, 조끼, 가방 등)
	if cat == ItemCategory.EQUIPMENT:
		var slot = data.get("equip_slot", "")
		if slot == "helmet": return Vector2i(2, 2)
		elif slot == "vest": return Vector2i(2, 2)
		elif slot == "backpack": return Vector2i(2, 3)
		elif slot == "bottom": return Vector2i(2, 1)
		return Vector2i(2, 2)
		
	# 의료/치료
	if cat == ItemCategory.MEDICAL:
		if id.contains("상자") or id.contains("키트"):
			return Vector2i(2, 2)
		return Vector2i(1, 1)
		
	# 도구
	if cat == ItemCategory.TOOL:
		if id.contains("망원경"):
			return Vector2i(1, 2)
		return Vector2i(1, 1)
		
	return Vector2i(1, 1)

func get_item_equip_slot(id: String) -> String:
	var data = get_item_data(id)
	if data.has("equip_slot"):
		return data["equip_slot"]
		
	var cat = data.get("category", -1)
	var type = data.get("type", "")
	
	if cat == ItemCategory.WEAPON or type == "receiver":
		if id == "수류탄":
			return "throwable"
		elif type == "melee":
			return "melee"
		elif id == "권총" or id.begins_with("M9"):
			return "sidearm"
		else:
			return "primary" # primary1 / primary2 호환
			
	if WeaponPartsDatabase.PARTS.has(id):
		return "attachment"
		
	return ""
