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

var items: Dictionary = {
	# === 식량 ===
	"식량통조림": {
		"category": ItemCategory.FOOD,
		"description": "밀봉된 고기 통조림. 유통기한은 이미 지났지만 아직 먹을 수 있다.",
		"stackable": true, "max_stack": 10, "weight": 0.5,
		"effects": {"hunger": 30, "hp": 5}, "rarity": 0.6, "value": 1200
	},
	"마른 빵": {
		"category": ItemCategory.FOOD,
		"description": "딱딱하게 굳은 빵. 배는 채울 수 있다.",
		"stackable": true, "max_stack": 10, "weight": 0.2,
		"effects": {"hunger": 15}, "rarity": 0.7, "value": 400
	},
	"에너지바": {
		"category": ItemCategory.FOOD,
		"description": "고칼로리 에너지바. 빠르게 에너지를 보충할 수 있다.",
		"stackable": true, "max_stack": 10, "weight": 0.1,
		"effects": {"hunger": 20, "stamina": 30}, "rarity": 0.4, "value": 800
	},
	"고기 구이": {
		"category": ItemCategory.FOOD,
		"description": "불에 구운 고기. 영양가가 높다.",
		"stackable": true, "max_stack": 5, "weight": 0.4,
		"effects": {"hunger": 45, "hp": 10}, "rarity": 0.2, "value": 1500
	},
	"전투 식량": {
		"category": ItemCategory.FOOD,
		"description": "군용 전투 식량. 포만감을 크게 채워주고 에너지를 제공한다.",
		"stackable": true, "max_stack": 5, "weight": 0.8,
		"effects": {"hunger": 70, "stamina": 20, "hp": 10}, "rarity": 0.08, "value": 3000
	},
	"농작물": {
		"category": ItemCategory.FOOD,
		"description": "밭에서 자란 싱싱한 농작물. 배를 든든하게 채운다.",
		"stackable": true, "max_stack": 5, "weight": 1.0,
		"effects": {"hunger": 40, "hp": 5}, "rarity": 0.2, "value": 800
	},

	# === 음료 ===
	"생수": {
		"category": ItemCategory.WATER,
		"description": "깨끗한 생수 한 병.",
		"stackable": true, "max_stack": 10, "weight": 0.5,
		"effects": {"thirst": 35, "stress": -5}, "rarity": 0.6, "value": 600
	},
	"탄산음료": {
		"category": ItemCategory.WATER,
		"description": "따끈한 탄산음료. 갈증 해소와 기분 전환에 좋다.",
		"stackable": true, "max_stack": 5, "weight": 0.4,
		"effects": {"thirst": 25, "stress": -10}, "rarity": 0.4, "value": 1000
	},
	"에너지 드링크": {
		"category": ItemCategory.WATER,
		"description": "고농축 카페인 음료. 갈증을 해소하고 스태미나를 대폭 회복한다.",
		"stackable": true, "max_stack": 5, "weight": 0.3,
		"effects": {"thirst": 20, "stamina": 80, "stress": -10}, "rarity": 0.12, "value": 1800
	},
	"커피": {
		"category": ItemCategory.WATER,
		"description": "인스턴트 커피. 졸음을 쫓아준다.",
		"stackable": true, "max_stack": 5, "weight": 0.1,
		"effects": {"thirst": 15, "stamina": 40, "stress": -5}, "rarity": 0.3, "value": 1200
	},

	# === 의료 ===
	"붕대": {
		"category": ItemCategory.MEDICAL,
		"description": "깨끗한 붕대. 출혈을 멈출 수 있다.",
		"stackable": true, "max_stack": 5, "weight": 0.1,
		"effects": {"hp": 15, "cures_bleeding": true}, "rarity": 0.5, "value": 800
	},
	"진통제": {
		"category": ItemCategory.MEDICAL,
		"description": "강력한 진통제. 통증을 잠시 잊게 해준다.",
		"stackable": true, "max_stack": 5, "weight": 0.1,
		"effects": {"hp": 25, "stress": -15}, "rarity": 0.35, "value": 2500
	},
	"구급상자": {
		"category": ItemCategory.MEDICAL,
		"description": "기본적인 응급 처치 키트.",
		"stackable": true, "max_stack": 3, "weight": 1.0,
		"effects": {"hp": 40, "cures_bleeding": true}, "rarity": 0.3, "value": 4000
	},
	"고급 치료킷": {
		"category": ItemCategory.MEDICAL,
		"description": "전문 의료 키트. 중상도 치료 가능.",
		"stackable": true, "max_stack": 2, "weight": 1.5,
		"effects": {"hp": 70, "stress": -10, "cures_bleeding": true, "cures_fracture": true}, "rarity": 0.1, "value": 8000
	},
	"약초": {
		"category": ItemCategory.MEDICAL,
		"description": "야생에서 채집한 약초. 크래프팅 재료.",
		"stackable": true, "max_stack": 10, "weight": 0.1,
		"effects": {"hp": 10}, "rarity": 0.5, "value": 500
	},

	# === 무기 및 탄약 ===
	"파이프": {
		"category": ItemCategory.WEAPON,
		"description": "녹슨 쇠파이프.",
		"stackable": false, "weight": 1.5, "damage": 10, "range": 1.0,
		"attack_speed": 0.5, "type": "melee", "rarity": 0.5, "value": 1500,
		"max_durability": 100
	},
	"나이프": {
		"category": ItemCategory.WEAPON,
		"description": "날카로운 사냥용 나이프.",
		"stackable": false, "weight": 0.5, "damage": 12, "range": 0.8,
		"attack_speed": 0.3, "type": "melee", "rarity": 0.35, "value": 3000,
		"max_durability": 100
	},
	"야구방망이": {
		"category": ItemCategory.WEAPON,
		"description": "알루미늄 야구방망이. 넓은 타격 범위.",
		"stackable": false, "weight": 1.8, "damage": 18, "range": 1.3,
		"attack_speed": 0.7, "type": "melee", "rarity": 0.25, "value": 4500,
		"max_durability": 100
	},
	"도끼": {
		"category": ItemCategory.WEAPON,
		"description": "목재 벌목용 도끼. 강력하지만 느리다.",
		"stackable": false, "weight": 2.5, "damage": 25, "range": 1.1,
		"attack_speed": 0.9, "type": "melee", "rarity": 0.2, "value": 7000,
		"max_durability": 100
	},
	"권총": {
		"category": ItemCategory.WEAPON,
		"description": "9mm 권총. 탄약 필요.",
		"stackable": false, "weight": 1.0, "damage": 14, "range": 8.0,
		"attack_speed": 0.4, "type": "ranged", "ammo": "탄약", "rarity": 0.1, "value": 18000,
		"max_durability": 100
	},
	"레버액션 소총": {
		"category": ItemCategory.WEAPON,
		"description": "클래식한 레버액션 소총. 강력하지만 재장전이 느리다.",
		"stackable": false, "weight": 3.5, "damage": 22, "range": 12.0,
		"attack_speed": 1.2, "type": "ranged", "ammo": "탄약", "rarity": 0.05, "value": 35000,
		"max_durability": 100
	},
	"수류탄": {
		"category": ItemCategory.WEAPON,
		"description": "신관 안전핀을 뽑아 투척하는 강력한 대량 살상용 대인 수류탄.",
		"stackable": true, "max_stack": 3, "weight": 0.5, "rarity": 0.05, "value": 4000
	},
	"탄약": {
		"category": ItemCategory.WEAPON,
		"description": "9mm 탄약.",
		"stackable": true, "max_stack": 30, "weight": 0.05, "rarity": 0.15, "value": 200
	},

	# === 장비 ===
	"가방": {
		"category": ItemCategory.EQUIPMENT,
		"description": "튼튼한 배낭. 인벤토리 최대 무게를 늘려준다.",
		"stackable": false, "weight": 0.5, "equip_slot": "back",
		"weight_bonus": 15.0, "rarity": 0.15, "value": 8000
	},
	"방독면": {
		"category": ItemCategory.EQUIPMENT,
		"description": "오염된 공기를 차단하는 방독면.",
		"stackable": false, "weight": 0.8, "equip_slot": "head",
		"effects": {"poison_resist": true}, "rarity": 0.2, "value": 6000,
		"max_durability": 100
	},
	"방탄조끼": {
		"category": ItemCategory.EQUIPMENT,
		"description": "방탄 재질의 조끼. 대미지를 크게 줄여준다.",
		"stackable": false, "weight": 3.0, "equip_slot": "body",
		"defense": 15, "rarity": 0.1, "value": 15000,
		"max_durability": 100
	},
	"운동화": {
		"category": ItemCategory.EQUIPMENT,
		"description": "가볍고 튼튼한 운동화. 이동 속도가 빨라진다.",
		"stackable": false, "weight": 0.5, "equip_slot": "feet",
		"speed_bonus": 0.3, "rarity": 0.3, "value": 5000
	},

	# === 도구 ===
	"손전등": {
		"category": ItemCategory.TOOL,
		"description": "LED 손전등. 밤에 시야를 밝혀준다.",
		"stackable": false, "weight": 0.3, "effects": {"night_vision": true}, "rarity": 0.35, "value": 2000
	},
	"망원경": {
		"category": ItemCategory.TOOL,
		"description": "군용 5배율 관측용 망원경. 우클릭 시 넓은 시야로 원거리를 정찰할 수 있다.",
		"stackable": false, "weight": 0.6, "effects": {"telescope_zoom": 5.0}, "rarity": 0.08, "value": 14000
	},
	"고배율_망원경": {
		"category": ItemCategory.TOOL,
		"description": "10배율 초고성능 군용 관측 망원경. 극도로 먼 거리의 적과 지형을 정찰한다.",
		"stackable": false, "weight": 1.0, "effects": {"telescope_zoom": 10.0}, "rarity": 0.03, "value": 38000
	},
	"비상용 배터리": {
		"category": ItemCategory.TOOL,
		"description": "충전식 비상 배터리. 여러 장비에 사용 가능.",
		"stackable": true, "max_stack": 5, "weight": 0.5, "rarity": 0.25, "value": 1500
	},
	"지도": {
		"category": ItemCategory.TOOL,
		"description": "이 지역의 약도. 미니맵 범위가 넓어진다.",
		"stackable": false, "weight": 0.1, "effects": {"map_range": 2}, "rarity": 0.2, "value": 1000
	},
	"군용 나침반": {
		"category": ItemCategory.TOOL,
		"description": "혹독한 오염 지대에서도 정상 작동하는 전술 군용 나침반.",
		"stackable": false, "weight": 0.2, "rarity": 0.05, "value": 10000
	},

	# === 탄약류 ===
	"9mm": {
		"category": ItemCategory.WEAPON,
		"description": "9x19mm 권총/SMG 표준 탄약.",
		"stackable": true, "max_stack": 60, "weight": 0.02, "rarity": 0.3, "value": 150
	},
	".45ACP": {
		"category": ItemCategory.WEAPON,
		"description": ".45 ACP 대구경 권총탄. 높은 저지력.",
		"stackable": true, "max_stack": 50, "weight": 0.03, "rarity": 0.2, "value": 250
	},
	"5.56mm": {
		"category": ItemCategory.WEAPON,
		"description": "5.56x45mm NATO 고속 소총탄.",
		"stackable": true, "max_stack": 60, "weight": 0.03, "rarity": 0.15, "value": 350
	},
	"7.62mm": {
		"category": ItemCategory.WEAPON,
		"description": "7.62x39mm 고위력 관통 소총탄.",
		"stackable": true, "max_stack": 40, "weight": 0.04, "rarity": 0.1, "value": 450
	},
	"12게이지_벅샷": {
		"category": ItemCategory.WEAPON,
		"description": "12게이지 8펠릿 산탄. 근거리 파괴력 극대화.",
		"stackable": true, "max_stack": 20, "weight": 0.05, "rarity": 0.2, "value": 300
	},
	"12게이지_슬러그": {
		"category": ItemCategory.WEAPON,
		"description": "12게이지 중량 슬러그탄. 단발 관통력 극대화.",
		"stackable": true, "max_stack": 20, "weight": 0.06, "rarity": 0.08, "value": 500
	},

	# === 리시버류 ===
	"M9_리시버": {
		"category": ItemCategory.WEAPON,
		"description": "M9 베레타 권총 리시버. 모딩 가능.",
		"stackable": false, "weight": 0.5, "type": "receiver", "rarity": 0.15, "value": 8000
	},
	"AK_리시버": {
		"category": ItemCategory.WEAPON,
		"description": "AK-47 소총 리시버. 강력한 7.62mm 화력 지원.",
		"stackable": false, "weight": 1.8, "type": "receiver", "rarity": 0.08, "value": 24000
	},
	"M4_리시버": {
		"category": ItemCategory.WEAPON,
		"description": "M4A1 카빈 리시버. 3개 레일과 높은 확장성.",
		"stackable": false, "weight": 1.6, "type": "receiver", "rarity": 0.05, "value": 32000
	},
	"레밍턴_리시버": {
		"category": ItemCategory.WEAPON,
		"description": "레밍턴 870 펌프액션 샷건 리시버.",
		"stackable": false, "weight": 2.1, "type": "receiver", "rarity": 0.1, "value": 18000
	},
	"SV98_리시버": {
		"category": ItemCategory.WEAPON,
		"description": "SV-98 정밀 볼트액션 저격 리시버.",
		"stackable": false, "weight": 3.0, "type": "receiver", "rarity": 0.03, "value": 45000
	},

	# === 재료 ===
	"나무": {
		"category": ItemCategory.MATERIAL,
		"description": "건축 및 크래프팅용 목재.",
		"stackable": true, "max_stack": 20, "weight": 1.0, "rarity": 0.7, "value": 300
	},
	"못": {
		"category": ItemCategory.MATERIAL,
		"description": "건축용 못. 바리케이드 제작에 필요.",
		"stackable": true, "max_stack": 30, "weight": 0.1, "rarity": 0.6, "value": 100
	},
	"천": {
		"category": ItemCategory.MATERIAL,
		"description": "찢어진 천 조각. 다양한 용도.",
		"stackable": true, "max_stack": 15, "weight": 0.2, "rarity": 0.6, "value": 200
	},
	"고철": {
		"category": ItemCategory.MATERIAL,
		"description": "재활용 가능한 금속 조각.",
		"stackable": true, "max_stack": 15, "weight": 0.8, "rarity": 0.5, "value": 400
	},
	"기계 부품": {
		"category": ItemCategory.MATERIAL,
		"description": "복잡한 기계의 부품. 정밀 장비 개조에 필수적이다.",
		"stackable": true, "max_stack": 20, "weight": 0.5, "rarity": 0.1, "value": 2500
	},
	"폐전선": {
		"category": ItemCategory.MATERIAL,
		"description": "공장 또는 주거지 전자 제품 등에서 나오는 흔한 구리 전선.",
		"stackable": true, "max_stack": 15, "weight": 0.4, "rarity": 0.5, "value": 1200
	},
	"화약": {
		"category": ItemCategory.MATERIAL,
		"description": "화력 병기를 조립하기 위한 군용 등급 화약.",
		"stackable": true, "max_stack": 10, "weight": 0.2, "rarity": 0.15, "value": 2000
	},
	"CPU": {
		"category": ItemCategory.MATERIAL,
		"description": "컴퓨터 파밍에서 발견되는 정밀 가공 프로세서.",
		"stackable": true, "max_stack": 5, "weight": 0.2, "rarity": 0.15, "value": 8000
	},
	"그래픽카드": {
		"category": ItemCategory.MATERIAL,
		"description": "컴퓨터 본체에서 극히 희박하게 입수되는 최고가 정밀 전자 전리품.",
		"stackable": true, "max_stack": 2, "weight": 1.0, "rarity": 0.04, "value": 25000
	},

	# === 전리품 & 퀘스트 ===
	"금시계": {
		"category": ItemCategory.MISC,
		"description": "고풍스러운 장식용 귀금속 시계.",
		"stackable": true, "max_stack": 5, "weight": 0.1, "rarity": 0.1, "value": 12000
	},
	"은반지": {
		"category": ItemCategory.MISC,
		"description": "은빛 귀금속 전리품.",
		"stackable": true, "max_stack": 10, "weight": 0.05, "rarity": 0.25, "value": 6000
	},
	"골동품": {
		"category": ItemCategory.MISC,
		"description": "묵직하고 가치 높은 골동품 도자기.",
		"stackable": true, "max_stack": 2, "weight": 2.0, "rarity": 0.08, "value": 18000
	},
	"라디오 부품": {
		"category": ItemCategory.QUEST,
		"description": "장거리 무전기 조립에 필요한 핵심 부품.",
		"stackable": true, "max_stack": 5, "weight": 0.5, "rarity": 0.08, "value": 5000
	},
	"장거리 무전기": {
		"category": ItemCategory.QUEST,
		"description": "극히 드물게 발견되는 고가치 군용 통신기.",
		"stackable": false, "weight": 1.5, "rarity": 0.01, "value": 80000
	},
	"암호화된 SSD": {
		"category": ItemCategory.QUEST,
		"description": "기밀 데이터가 담긴 군용 SSD.",
		"stackable": true, "max_stack": 5, "weight": 0.1, "rarity": 0.03, "value": 16000
	}
}

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
