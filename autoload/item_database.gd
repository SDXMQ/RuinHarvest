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
var _cached_item_data: Dictionary = {}
var _cached_grid_sizes: Dictionary = {}
var _cached_equip_slots: Dictionary = {}

func _ready():
	_load_all_items()

func _load_all_items():
	_cached_item_data.clear()
	_cached_grid_sizes.clear()
	_cached_equip_slots.clear()
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
						d["armor_defense"] = res.armor_defense
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
	# 잠긴 특수 방(무기고/원장실) 개방용 열쇠 및 보안 키카드 내장 등록 (내구도/사용 횟수 적용)
	if not items.has("무기고 열쇠"):
		items["무기고 열쇠"] = {
			"id": "무기고 열쇠",
			"name": "무기고 열쇠",
			"category": ItemCategory.QUEST,
			"type": "key",
			"description": "경찰서 및 군사 시설의 잠긴 무기고 보안문을 여는 강철 열쇠입니다. (최대 5회 사용, 안전 컨테이너 보관 가능)",
			"stackable": false,
			"max_stack": 1,
			"max_durability": 5,
			"weight": 0.05,
			"rarity": 3,
			"value": 18000,
			"effects": {}
		}
	else:
		items["무기고 열쇠"]["max_durability"] = 5
	if not items.has("보안 키카드"):
		items["보안 키카드"] = {
			"id": "보안 키카드",
			"name": "보안 키카드",
			"category": ItemCategory.QUEST,
			"type": "keycard",
			"description": "병원 원장실 및 특수 보안 구역의 전자 잠금장치를 해제하는 마그네틱 키카드입니다. (최대 3회 사용, 안전 컨테이너 보관 가능)",
			"stackable": false,
			"max_stack": 1,
			"max_durability": 3,
			"weight": 0.05,
			"rarity": 4,
			"value": 28000,
			"effects": {}
		}
	else:
		items["보안 키카드"]["max_durability"] = 3
	if not items.has("항생제"):
		items["항생제"] = {
			"id": "항생제",
			"name": "광범위 항생제",
			"category": ItemCategory.MEDICAL,
			"description": "변이체 및 야간 추격자에게 피격되어 발생한 생체 감염(최대 스태미나 감소 및 지속 피해)을 완치하는 특수 항생제입니다.",
			"stackable": true,
			"max_stack": 3,
			"weight": 0.15,
			"rarity": 2,
			"value": 3200,
			"effects": {
				"hp": 15,
				"cures_infection": true
			}
		}
	if items.has("고급 치료킷"):
		if not (items["고급 치료킷"].get("effects") is Dictionary):
			items["고급 치료킷"]["effects"] = {}
		items["고급 치료킷"]["effects"]["cures_infection"] = true
		items["고급 치료킷"]["effects"]["cures_bleeding"] = true
		items["고급 치료킷"]["effects"]["cures_fracture"] = true

# 장소 및 가구별 루트 테이블
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
	"residential": [
		{"id": "식량통조림", "chance": 0.5}, {"id": "생수", "chance": 0.5},
		{"id": "초콜릿", "chance": 0.25}, {"id": "에너지드링크", "chance": 0.25}
	],
	"bed": [
		{"id": "붕대", "chance": 0.45}, {"id": "진통제", "chance": 0.3},
		{"id": "천", "chance": 0.4}, {"id": "1레벨_가방", "chance": 0.12},
		{"id": "은반지", "chance": 0.12}
	],
	"desk": [
		{"id": "나침반", "chance": 0.18}, {"id": "지도", "chance": 0.18},
		{"id": "9mm", "chance": 0.28}, {"id": "CPU", "chance": 0.15},
		{"id": "금시계", "chance": 0.12}, {"id": "장거리 무전기", "chance": 0.08},
		{"id": "무기고 열쇠", "chance": 0.08}, {"id": "보안 키카드", "chance": 0.05}
	],
	"shelf": [
		{"id": "식량통조림", "chance": 0.35}, {"id": "생수", "chance": 0.35},
		{"id": "고철", "chance": 0.35}, {"id": "못", "chance": 0.3},
		{"id": "손전등", "chance": 0.2}, {"id": "비상용 배터리", "chance": 0.2}
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
	],
	"locked_armory": [
		{"id": "5.56mm", "chance": 0.65}, {"id": "7.62mm", "chance": 0.65},
		{"id": "3레벨_방탄복", "chance": 0.35}, {"id": "3레벨_헬멧", "chance": 0.35},
		{"id": "수류탄", "chance": 0.45}, {"id": "소음기", "chance": 0.3},
		{"id": "4배율_ACOG", "chance": 0.28}, {"id": "암호화된 SSD", "chance": 0.25},
		{"id": "장거리 무전기", "chance": 0.25}
	],
	"locked_medical": [
		{"id": "고급 치료킷", "chance": 0.75}, {"id": "구급상자", "chance": 0.65},
		{"id": "진통제", "chance": 0.55}, {"id": "암호화된 SSD", "chance": 0.35},
		{"id": "그래픽카드", "chance": 0.22}, {"id": "금시계", "chance": 0.3}
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
			{"id": "가방", "price": 8000},
			{"id": "장거리 무전기", "price": 9500},
			{"id": "무기고 열쇠", "price": 22000},
			{"id": "보안 키카드", "price": 32000}
		]
	}
}

func resolve_item_id(id: String) -> String:
	if id in ["기밀_SSD", "기밀 SSD", "암호화된_SSD", "암호화된 SSD"]:
		if items.has("암호화된 SSD"):
			return "암호화된 SSD"
	if items.has(id) or WeaponPartsDatabase.PARTS.has(id) or WeaponPartsDatabase.RECEIVERS.has(id):
		return id
	var id_space = id.replace("_", " ")
	var id_under = id.replace(" ", "_")
	if items.has(id_space) or WeaponPartsDatabase.PARTS.has(id_space) or WeaponPartsDatabase.RECEIVERS.has(id_space):
		return id_space
	elif items.has(id_under) or WeaponPartsDatabase.PARTS.has(id_under) or WeaponPartsDatabase.RECEIVERS.has(id_under):
		return id_under
	return id

func get_item_data(id: String) -> Dictionary:
	if _cached_item_data.has(id):
		return _cached_item_data[id]
		
	var target_id = resolve_item_id(id)
	if target_id in ["무전기", "군용 무전기"] and items.has("장거리 무전기"):
		target_id = "장거리 무전기"
	if not items.has(target_id) and not WeaponPartsDatabase.PARTS.has(target_id) and not WeaponPartsDatabase.RECEIVERS.has(target_id):
		var id_space = id.replace("_", " ")
		var id_under = id.replace(" ", "_")
		if items.has(id_space) or WeaponPartsDatabase.PARTS.has(id_space) or WeaponPartsDatabase.RECEIVERS.has(id_space):
			target_id = id_space
		elif items.has(id_under) or WeaponPartsDatabase.PARTS.has(id_under) or WeaponPartsDatabase.RECEIVERS.has(id_under):
			target_id = id_under

	var d: Dictionary = {}
	if items.has(target_id):
		d = items[target_id].duplicate()
		if not d.has("name") or d["name"] == "":
			d["name"] = target_id
	elif WeaponPartsDatabase.PARTS.has(target_id):
		var p = WeaponPartsDatabase.PARTS[target_id].duplicate()
		p["category"] = ItemCategory.TOOL
		p["stackable"] = false
		p["max_stack"] = 1
		p["weight"] = p.get("weight", 0.3)
		p["description"] = "[총기 부품: %s] %s" % [p.get("slot", ""), p.get("name", target_id)]
		d = p
	elif WeaponPartsDatabase.RECEIVERS.has(target_id):
		var r = WeaponPartsDatabase.RECEIVERS[target_id].duplicate()
		r["category"] = ItemCategory.WEAPON
		r["stackable"] = false
		r["max_stack"] = 1
		r["type"] = "receiver"
		r["description"] = "[총기 리시버] %s" % r.get("name", target_id)
		d = r
	else:
		d = {"name": id, "weight": 0.1, "max_stack": 1, "value": 500}
		
	_cached_item_data[id] = d
	return d

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
	if _cached_grid_sizes.has(id):
		return _cached_grid_sizes[id]
		
	var data = get_item_data(id)
	var size = Vector2i(1, 1)
	if data.has("grid_w") and data.has("grid_h"):
		size = Vector2i(data["grid_w"], data["grid_h"])
	else:
		var cat = data.get("category", -1)
		var type = data.get("type", "")
		
		# 무기 부착물/파츠
		if WeaponPartsDatabase and WeaponPartsDatabase.PARTS.has(id):
			var pslot = WeaponPartsDatabase.PARTS[id].get("slot", "")
			if pslot == "barrel" or pslot == "stock":
				size = Vector2i(1, 2)
			else:
				size = Vector2i(1, 1)
		elif cat == ItemCategory.WEAPON or type == "receiver":
			if type == "melee":
				size = Vector2i(1, 3)
			elif id == "권총" or id.begins_with("M9") or id.begins_with("MP5"):
				size = Vector2i(1, 2)
			elif id == "수류탄":
				size = Vector2i(1, 1)
			elif id == "탄약" or id.contains("9mm") or id.contains("5.56") or id.contains("7.62") or id.contains("12게이지") or id.contains(".45"):
				size = Vector2i(1, 1)
			else:
				size = Vector2i(2, 4) # 소총, 샷건, 저격총 등
		elif cat == ItemCategory.EQUIPMENT:
			var slot = data.get("equip_slot", "")
			if slot == "helmet": size = Vector2i(2, 2)
			elif slot == "vest": size = Vector2i(2, 2)
			elif slot == "backpack": size = Vector2i(2, 3)
			elif slot == "bottom": size = Vector2i(2, 1)
			else: size = Vector2i(2, 2)
		elif cat == ItemCategory.MEDICAL:
			if id.contains("상자") or id.contains("키트"):
				size = Vector2i(2, 2)
			else:
				size = Vector2i(1, 1)
		elif cat == ItemCategory.TOOL:
			if id.contains("망원경"):
				size = Vector2i(1, 2)
			else:
				size = Vector2i(1, 1)
				
	_cached_grid_sizes[id] = size
	return size

func get_item_equip_slot(id: String) -> String:
	if _cached_equip_slots.has(id):
		return _cached_equip_slots[id]
		
	var data = get_item_data(id)
	var slot = ""
	if data.has("equip_slot"):
		slot = data["equip_slot"]
	else:
		var cat = data.get("category", -1)
		var type = data.get("type", "")
		if cat == ItemCategory.WEAPON or type == "receiver":
			if id == "수류탄":
				slot = "throwable"
			elif type == "melee":
				slot = "melee"
			elif id == "권총" or id.begins_with("M9"):
				slot = "sidearm"
			else:
				slot = "primary" # primary1 / primary2 호환
		elif WeaponPartsDatabase.PARTS.has(id):
			slot = "attachment"
			
	_cached_equip_slots[id] = slot
	return slot
