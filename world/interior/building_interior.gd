# res://world/interior/building_interior.gd
class_name BuildingInterior
extends RefCounted

## 다중 방 분할(BSP 기반), 논리적 가구 배치 및 실내 좀비 스폰을 지원하는 실내 생성기

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
		{"id": "권총", "chance": 0.3}, {"id": "9mm", "chance": 0.55, "amount": 20},
		{"id": ".45ACP", "chance": 0.35, "amount": 16}, {"id": "5.56mm", "chance": 0.32, "amount": 20},
		{"id": "7.62mm", "chance": 0.28, "amount": 18}, {"id": "12게이지_벅샷", "chance": 0.28, "amount": 10},
		{"id": "12게이지_슬러그", "chance": 0.16, "amount": 8},
		{"id": "레버액션 소총", "chance": 0.15}, {"id": "방탄조끼", "chance": 0.22},
		{"id": "레드닷_사이트", "chance": 0.20}, {"id": "2배율_조준경", "chance": 0.15},
		{"id": "소음기", "chance": 0.12}, {"id": "대용량_확장_탄창", "chance": 0.18},
		{"id": "수직_포어그립", "chance": 0.16}, {"id": "컴펜세이터", "chance": 0.14}
	],
	"선반": [
		{"id": "고철", "chance": 0.4}, {"id": "못", "chance": 0.5},
		{"id": "천", "chance": 0.4}, {"id": "손전등", "chance": 0.2},
		{"id": "9mm", "chance": 0.22, "amount": 15}, {"id": "경량_접이식_스톡", "chance": 0.10},
		{"id": "전술_손전등", "chance": 0.10}
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
		"furnitures": ["냉장고", "선반", "약품장", "선반"],
		"zombie_count": [0, 1]
	},
	"store": {
		"title": "약탈당한 상점",
		"furnitures": ["선반", "냉장고", "금고", "선반"],
		"zombie_count": [1, 2]
	},
	"hospital": {
		"title": "폐쇄된 병원",
		"furnitures": ["약품장", "약품장", "선반", "금고"],
		"zombie_count": [1, 2]
	},
	"military": {
		"title": "군사 시설 격납고",
		"furnitures": ["무기함", "무기함", "금고", "선반"],
		"zombie_count": [1, 2]
	}
}

static func generate_interior(b_type: String, seed_val: int) -> Dictionary:
	var layout = BUILDING_LAYOUTS.get(b_type, BUILDING_LAYOUTS["house"])
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	
	var width = 24
	var height = 18
	
	# 0: 벽, 1: 바닥, 2: 출구 문, 3: 창문, 4: 스위치
	var tiles: Array = []
	tiles.resize(width * height)
	for i in range(width * height):
		tiles[i] = 1 # 기본 바닥
		
	# 1. 외곽 벽 둘러치기
	for x in range(width):
		tiles[x] = 0
		tiles[(height - 1) * width + x] = 0
	for y in range(height):
		tiles[y * width] = 0
		tiles[y * width + (width - 1)] = 0
		
	# 2. 방 분할 벽 생성 (다중 방 구성: 좌/우 + 상/하 분할)
	var split_x = int(width * 0.5)
	var split_y = int(height * 0.5)
	
	# 세로 칸막이
	for y in range(1, height - 1):
		tiles[y * width + split_x] = 0
	# 가로 칸막이 (좌측 방 분할)
	for x in range(1, split_x):
		tiles[split_y * width + x] = 0
	# 가로 칸막이 (우측 방 분할)
	for x in range(split_x + 1, width - 1):
		tiles[split_y * width + x] = 0
		
	# 3. 방 사이 통로 개방 (문)
	tiles[int(split_y * 0.5) * width + split_x] = 1 # 좌상 ↔ 우상 통로
	tiles[(split_y + int((height - split_y) * 0.5)) * width + split_x] = 1 # 좌하 ↔ 우하 통로
	tiles[split_y * width + int(split_x * 0.5)] = 1 # 좌상 ↔ 좌하 통로
	tiles[split_y * width + (split_x + int((width - split_x) * 0.5))] = 1 # 우상 ↔ 우하 통로
	
	# 4. 출입구/출구 문 배치 (하단 좌측 방 중앙)
	var exit_door_pos = Vector2i(int(split_x * 0.5), height - 1)
	tiles[exit_door_pos.y * width + exit_door_pos.x] = 2
	
	# 5. 외벽 창문 배치
	tiles[4] = 3
	tiles[width - 5] = 3
	tiles[4 * width] = 3
	tiles[(height - 5) * width] = 3
	tiles[4 * width + (width - 1)] = 3
	
	# 6. 실내 조명 스위치 배치 (출구 옆 벽면)
	var switch_pos = Vector2i(exit_door_pos.x + 2, height - 2)
	tiles[switch_pos.y * width + switch_pos.x] = 4
	
	# 7. 가구 배치 (방 구석/벽면에 배치)
	var furnitures = []
	var f_types = layout["furnitures"]
	
	var candidate_f_positions = [
		Vector2i(2, 2), Vector2i(split_x - 2, 2),
		Vector2i(split_x + 2, 2), Vector2i(width - 3, 2),
		Vector2i(2, split_y - 2), Vector2i(split_x + 2, split_y - 2),
		Vector2i(split_x + 2, height - 3), Vector2i(width - 3, height - 3),
		Vector2i(2, height - 4)
	]
	candidate_f_positions.shuffle()
	
	for i in range(min(f_types.size(), candidate_f_positions.size())):
		var f_type = f_types[i]
		var f_pos = candidate_f_positions[i]
		
		# 전리품 생성
		var loot = []
		var pool = FURNITURE_LOOT_TABLES.get(f_type, [])
		for entry in pool:
			if rng.randf() < entry["chance"]:
				var drop_id := String(entry["id"])
				var drop_amt := int(entry.get("amount", 1))
				loot.append({"id": drop_id, "amount": drop_amt})
				
		if loot.is_empty() and pool.size() > 0:
			var guaranteed_entry = pool[rng.randi() % pool.size()]
			loot.append({"id": String(guaranteed_entry["id"]), "amount": int(guaranteed_entry.get("amount", 1))})
				
		furnitures.append({
			"type": f_type,
			"pos": f_pos,
			"loot": loot
		})
		
	# 8. 실내 좀비 스폰 위치 (Jump scare 깜놀 요소)
	var enemies = []
	var z_range = layout.get("zombie_count", [1, 2])
	var num_zombies = rng.randi_range(z_range[0], z_range[1])
	
	var zombie_spawn_candidates = [
		Vector2i(width - 4, 3), # 우상단 방 구석
		Vector2i(split_x + 3, split_y + 3), # 우하단 방 중앙
		Vector2i(3, 4), # 좌상단 방
		Vector2i(width - 5, height - 4)
	]
	zombie_spawn_candidates.shuffle()
	
	for i in range(min(num_zombies, zombie_spawn_candidates.size())):
		var z_pos = zombie_spawn_candidates[i]
		var z_type = 0 # 일반 좀비
		if b_type == "hospital" and rng.randf() < 0.4:
			z_type = 1 # 러너
		elif b_type == "military" and rng.randf() < 0.3:
			z_type = 2 # 탱커
		enemies.append({
			"pos": z_pos,
			"type": z_type
		})
		
	return {
		"title": layout["title"],
		"width": width,
		"height": height,
		"tiles": tiles,
		"exit_pos": exit_door_pos,
		"switch_pos": switch_pos,
		"furnitures": furnitures,
		"enemies": enemies
	}
