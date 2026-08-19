# res://world/interior/building_interior.gd
class_name BuildingInterior
extends RefCounted

## 건물 실내 절차적 생성기 및 가구 데이터

const FURNITURE_LOOT_TABLES = {
	"냉장고": [
		{"id": "생수", "chance": 0.7}, {"id": "식량통조림", "chance": 0.5},
		{"id": "마른 빵", "chance": 0.4}, {"id": "에너지 드링크", "chance": 0.25}
	],
	"약품장": [
		{"id": "붕대", "chance": 0.6}, {"id": "진통제", "chance": 0.45},
		{"id": "구급상자", "chance": 0.25}, {"id": "고급 치료킷", "chance": 0.1}
	],
	"무기함": [
		{"id": "권총", "chance": 0.3}, {"id": "탄약", "chance": 0.6},
		{"id": "레버액션 소총", "chance": 0.12}, {"id": "방탄조끼", "chance": 0.2}
	],
	"선반": [
		{"id": "고철", "chance": 0.4}, {"id": "못", "chance": 0.5},
		{"id": "천", "chance": 0.4}, {"id": "손전등", "chance": 0.2}
	],
	"금고": [
		{"id": "금시계", "chance": 0.4}, {"id": "은반지", "chance": 0.5},
		{"id": "CPU", "chance": 0.3}, {"id": "그래픽카드", "chance": 0.1},
		{"id": "암호화된 SSD", "chance": 0.15}
	]
}

const BUILDING_LAYOUTS = {
	"house": {
		"title": "버려진 주택",
		"rooms": ["주방", "거실", "침실"],
		"furnitures": ["냉장고", "선반", "약품장"]
	},
	"store": {
		"title": "약탈당한 편의점",
		"rooms": ["상점홀", "창고"],
		"furnitures": ["선반", "냉장고", "금고"]
	},
	"hospital": {
		"title": "폐쇄된 병원",
		"rooms": ["진료실", "병실", "약제실"],
		"furnitures": ["약품장", "약품장", "선반"]
	},
	"military": {
		"title": "군사 시설 무기고",
		"rooms": ["무기고", "통신실", "작전실"],
		"furnitures": ["무기함", "무기함", "금고"]
	}
}

static func generate_interior(b_type: String, seed_val: int) -> Dictionary:
	var layout = BUILDING_LAYOUTS.get(b_type, BUILDING_LAYOUTS["house"])
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	
	var width = 24
	var height = 18
	
	var tiles: Array = [] # 2D 타일맵 (0: 벽, 1: 바닥, 2: 출구 문)
	tiles.resize(width * height)
	for i in range(width * height):
		tiles[i] = 1 # 기본 바닥
		
	# 외곽 벽 둘러치기
	for x in range(width):
		tiles[x] = 0
		tiles[(height - 1) * width + x] = 0
	for y in range(height):
		tiles[y * width] = 0
		tiles[y * width + (width - 1)] = 0
		
	# 중앙 칸막이 벽 및 방 분할
	var mid_x = width / 2
	for y in range(1, height - 1):
		tiles[y * width + mid_x] = 0
	# 방 사이 통로 문 (y = 8)
	tiles[8 * width + mid_x] = 1
	
	# 입구/출구 문 배치 (하단 중앙)
	var exit_door_pos = Vector2i(width / 4, height - 1)
	tiles[exit_door_pos.y * width + exit_door_pos.x] = 2
	
	# 가구 배치
	var furnitures = []
	var f_types = layout["furnitures"]
	
	var f_positions = [
		Vector2i(3, 3), Vector2i(7, 3), Vector2i(3, 12),
		Vector2i(15, 3), Vector2i(19, 3), Vector2i(15, 12)
	]
	
	for i in range(min(f_types.size(), f_positions.size())):
		var f_type = f_types[i]
		var f_pos = f_positions[i]
		
		# 전리품 생성 (최소 1개 이상 100% 보장)
		var loot = []
		var pool = FURNITURE_LOOT_TABLES.get(f_type, [])
		for entry in pool:
			if rng.randf() < entry["chance"]:
				loot.append({"id": entry["id"], "amount": 1})
				
		if loot.is_empty() and pool.size() > 0:
			var guaranteed_entry = pool[rng.randi() % pool.size()]
			loot.append({"id": guaranteed_entry["id"], "amount": 1})
				
		furnitures.append({
			"type": f_type,
			"pos": f_pos,
			"loot": loot
		})
		
	return {
		"title": layout["title"],
		"width": width,
		"height": height,
		"tiles": tiles,
		"exit_pos": exit_door_pos,
		"furnitures": furnitures
	}
