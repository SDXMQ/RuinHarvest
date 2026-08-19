# res://autoload/item_database.gd
extends Node

## 게임 내 모든 아이템의 메타데이터와 드롭 확률(Loot Table)을 관리합니다.

enum ItemCategory {
	WEAPON,
	AMMO,
	MEDICAL,
	FOOD,
	MATERIAL,
	VALUABLE,
	KEY
}

# 딕셔너리: [아이템ID] -> { 이름, 카테고리, 무게, 스택제한, 아이콘색(임시), 효과 }
var items: Dictionary = {
	"pistol_9mm": {
		"name": "9mm 권총",
		"category": ItemCategory.WEAPON,
		"weight": 1.2,
		"max_stack": 1,
		"color": Color(0.2, 0.2, 0.2)
	},
	"ammo_9mm": {
		"name": "9mm 탄약",
		"category": ItemCategory.AMMO,
		"weight": 0.01,
		"max_stack": 60,
		"color": Color(0.8, 0.7, 0.2)
	},
	"bandage": {
		"name": "붕대",
		"category": ItemCategory.MEDICAL,
		"weight": 0.1,
		"max_stack": 5,
		"color": Color(0.9, 0.9, 0.9),
		"heal": 20,
		"cures_bleeding": true
	},
	"canned_food": {
		"name": "통조림",
		"category": ItemCategory.FOOD,
		"weight": 0.4,
		"max_stack": 3,
		"color": Color(0.7, 0.3, 0.1),
		"hunger": 40
	},
	"water_bottle": {
		"name": "생수",
		"category": ItemCategory.FOOD,
		"weight": 0.5,
		"max_stack": 3,
		"color": Color(0.2, 0.6, 0.9),
		"thirst": 50
	},
	"scrap_metal": {
		"name": "고철",
		"category": ItemCategory.MATERIAL,
		"weight": 0.3,
		"max_stack": 20,
		"color": Color(0.5, 0.5, 0.55)
	},
	"gold_ring": {
		"name": "금반지",
		"category": ItemCategory.VALUABLE,
		"weight": 0.05,
		"max_stack": 10,
		"color": Color(1.0, 0.8, 0.1)
	}
}

# 컨테이너 종류별 드롭 테이블 (확률과 롤 횟수)
var loot_tables: Dictionary = {
	"crate": {
		"rolls": 3,
		"pool": [
			{"id": "canned_food", "weight": 30, "min": 1, "max": 2},
			{"id": "water_bottle", "weight": 30, "min": 1, "max": 2},
			{"id": "bandage", "weight": 20, "min": 1, "max": 3},
			{"id": "pistol_9mm", "weight": 5, "min": 1, "max": 1},
			{"id": "ammo_9mm", "weight": 15, "min": 10, "max": 30}
		]
	},
	"barrel": {
		"rolls": 2,
		"pool": [
			{"id": "scrap_metal", "weight": 60, "min": 2, "max": 8},
			{"id": "water_bottle", "weight": 40, "min": 1, "max": 1}
		]
	},
	"car": {
		"rolls": 2,
		"pool": [
			{"id": "scrap_metal", "weight": 50, "min": 1, "max": 4},
			{"id": "gold_ring", "weight": 10, "min": 1, "max": 1},
			{"id": "bandage", "weight": 40, "min": 1, "max": 2}
		]
	}
}

func get_item_data(id: String) -> Dictionary:
	if items.has(id):
		return items[id]
	return {}

func generate_loot(table_name: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not loot_tables.has(table_name):
		return results
		
	var table = loot_tables[table_name]
	var total_weight = 0
	for entry in table["pool"]:
		total_weight += entry["weight"]
		
	for i in range(table["rolls"]):
		# 빈 꽝(Nothing) 확률 추가 가능, 지금은 무조건 드롭
		var r = randi() % total_weight
		var current = 0
		for entry in table["pool"]:
			current += entry["weight"]
			if r < current:
				var amount = randi_range(entry["min"], entry["max"])
				_add_to_loot_results(results, entry["id"], amount)
				break
				
	return results

func _add_to_loot_results(results: Array, id: String, amount: int) -> void:
	var item_data = get_item_data(id)
	var max_stack = item_data.get("max_stack", 1)
	
	# 기존 스택에 추가 시도
	for res in results:
		if res["id"] == id and res["amount"] < max_stack:
			var space = max_stack - res["amount"]
			if amount <= space:
				res["amount"] += amount
				return
			else:
				res["amount"] += space
				amount -= space
				
	# 남은 양은 새 슬롯에 추가
	while amount > 0:
		var add_amt = min(amount, max_stack)
		results.append({"id": id, "amount": add_amt})
		amount -= add_amt
