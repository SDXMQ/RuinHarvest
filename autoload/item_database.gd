# res://autoload/item_database.gd
extends Node

## 아이템 데이터베이스, 전리품 생성 테이블 및 인벤토리 데이터 헬퍼

# ============================================================
# 아이템 카테고리 상수
# ============================================================
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

const CATEGORY_NAMES: Dictionary = {
	Category.FOOD: "식량",
	Category.WATER: "음료",
	Category.MEDICAL: "의료",
	Category.WEAPON: "무기",
	Category.TOOL: "도구",
	Category.MATERIAL: "재료",
	Category.EQUIPMENT: "장비",
	Category.QUEST: "퀘스트",
	Category.MISC: "기타"
}

# ============================================================
# 아이템 데이터베이스 (ITEM_DATABASE)
# ============================================================
var ITEM_DATABASE: Dictionary = {
	# === 식량 ===
	"식량통조림": {
		"category": Category.FOOD,
		"description": "밀봉된 고기 통조림. 유통기한은 지났지만 아직 먹을 수 있다.",
		"stackable": true,
		"max_stack": 10,
		"weight": 0.5,
		"effects": {"hunger": 30.0, "hp": 5.0},
		"rarity": 0.6,
		"value": 1500
	},
	"마른 빵": {
		"category": Category.FOOD,
		"description": "딱딱하게 굳은 빵. 배는 채울 수 있다.",
		"stackable": true,
		"max_stack": 10,
		"weight": 0.2,
		"effects": {"hunger": 15.0},
		"rarity": 0.7,
		"value": 500
	},
	"에너지바": {
		"category": Category.FOOD,
		"description": "고칼로리 에너지바. 빠르게 에너지를 보충할 수 있다.",
		"stackable": true,
		"max_stack": 10,
		"weight": 0.1,
		"effects": {"hunger": 20.0, "stamina": 30.0},
		"rarity": 0.4,
		"value": 1200
	},
	"고기 구이": {
		"category": Category.FOOD,
		"description": "불에 구운 고기. 영양가가 높다.",
		"stackable": true,
		"max_stack": 5,
		"weight": 0.4,
		"effects": {"hunger": 45.0, "hp": 10.0},
		"rarity": 0.2,
		"value": 2000
	},
	"전투 식량": {
		"category": Category.FOOD,
		"description": "군용 전투 식량. 포만감을 크게 채워주고 에너지를 제공한다.",
		"stackable": true,
		"max_stack": 5,
		"weight": 0.8,
		"effects": {"hunger": 70.0, "stamina": 20.0, "hp": 10.0},
		"rarity": 0.08,
		"value": 4500
	},
	"농작물": {
		"category": Category.FOOD,
		"description": "밭에서 자란 싱싱한 농작물. 배를 든든하게 채운다.",
		"stackable": true,
		"max_stack": 5,
		"weight": 1.0,
		"effects": {"hunger": 40.0, "hp": 5.0},
		"rarity": 0.2,
		"value": 800
	},

	# === 음료 ===
	"생수": {
		"category": Category.WATER,
		"description": "깨끗한 생수 한 병.",
		"stackable": true,
		"max_stack": 10,
		"weight": 0.5,
		"effects": {"thirst": 35.0, "stress": -5.0},
		"rarity": 0.6,
		"value": 1000
	},
	"탄산음료": {
		"category": Category.WATER,
		"description": "따끈한 탄산음료. 갈증 해소와 기분 전환에 좋다.",
		"stackable": true,
		"max_stack": 5,
		"weight": 0.4,
		"effects": {"thirst": 25.0, "stress": -10.0},
		"rarity": 0.4,
		"value": 800
	},
	"에너지 드링크": {
		"category": Category.WATER,
		"description": "고농축 카페인 음료. 갈증을 해소하고 스태미나를 대폭 회복한다.",
		"stackable": true,
		"max_stack": 5,
		"weight": 0.3,
		"effects": {"thirst": 20.0, "stamina": 80.0, "stress": -10.0},
		"rarity": 0.12,
		"value": 2500
	},
	"커피": {
		"category": Category.WATER,
		"description": "인스턴트 커피. 졸음을 쫓아준다.",
		"stackable": true,
		"max_stack": 5,
		"weight": 0.1,
		"effects": {"thirst": 15.0, "stamina": 40.0, "stress": -5.0},
		"rarity": 0.3,
		"value": 1200
	},

	# === 의료 ===
	"붕대": {
		"category": Category.MEDICAL,
		"description": "깨끗한 붕대. 출혈을 멈출 수 있다.",
		"stackable": true,
		"max_stack": 5,
		"weight": 0.1,
		"effects": {"hp": 15.0, "stop_bleeding": true},
		"rarity": 0.5,
		"value": 1200
	},
	"구급상자": {
		"category": Category.MEDICAL,
		"description": "기본적인 응급 처치 키트.",
		"stackable": true,
		"max_stack": 3,
		"weight": 1.0,
		"effects": {"hp": 40.0, "stop_bleeding": true},
		"rarity": 0.3,
		"value": 3500
	},
	"진통제": {
		"category": Category.MEDICAL,
		"description": "강력한 진통제. 통증을 잠시 잊게 해준다.",
		"stackable": true,
		"max_stack": 5,
		"weight": 0.1,
		"effects": {"hp": 25.0, "stress": -15.0, "fix_bone": true},
		"rarity": 0.35,
		"value": 2000
	},
	"고급 치료킷": {
		"category": Category.MEDICAL,
		"description": "전문 의료 키트. 중상도 치료 가능.",
		"stackable": true,
		"max_stack": 2,
		"weight": 1.5,
		"effects": {"hp": 70.0, "stress": -10.0, "stop_bleeding": true, "fix_bone": true},
		"rarity": 0.1,
		"value": 7000
	},
	"약초": {
		"category": Category.MEDICAL,
		"description": "야생에서 채집한 약초. 크래프팅 재료.",
		"stackable": true,
		"max_stack": 10,
		"weight": 0.1,
		"effects": {"hp": 10.0},
		"rarity": 0.5,
		"value": 400
	},

	# === 무기 ===
	"파이프": {
		"category": Category.WEAPON,
		"description": "녹슨 쇠파이프.",
		"stackable": false,
		"weight": 1.5,
		"damage": 10.0,
		"range": 1.0,
		"attack_speed": 0.5,
		"type": "melee",
		"rarity": 0.5,
		"value": 800
	},
	"무기": {
		"category": Category.WEAPON,
		"description": "쇠파이프. 기본적인 근접 무기.",
		"stackable": false,
		"weight": 2.0,
		"damage": 15.0,
		"range": 1.2,
		"attack_speed": 0.6,
		"type": "melee",
		"rarity": 0.3,
		"value": 1500
	},
	"나이프": {
		"category": Category.WEAPON,
		"description": "날카로운 사냥용 나이프.",
		"stackable": false,
		"weight": 0.5,
		"damage": 12.0,
		"range": 0.8,
		"attack_speed": 0.3,
		"type": "melee",
		"rarity": 0.35,
		"value": 1800
	},
	"도끼": {
		"category": Category.WEAPON,
		"description": "목재 벌목용 도끼. 강력하지만 느리다.",
		"stackable": false,
		"weight": 2.5,
		"damage": 25.0,
		"range": 1.1,
		"attack_speed": 0.9,
		"type": "melee",
		"rarity": 0.2,
		"value": 3000
	},
	"야구방망이": {
		"category": Category.WEAPON,
		"description": "알루미늄 야구방망이. 넓은 타격 범위.",
		"stackable": false,
		"weight": 1.8,
		"damage": 18.0,
		"range": 1.3,
		"attack_speed": 0.7,
		"type": "melee",
		"rarity": 0.25,
		"value": 2200
	},
	"권총": {
		"category": Category.WEAPON,
		"description": "9mm 권총. 탄약 필요.",
		"stackable": false,
		"weight": 1.0,
		"damage": 14.0,
		"range": 8.0,
		"attack_speed": 0.4,
		"type": "ranged",
		"ammo": "탄약",
		"rarity": 0.1,
		"value": 8500
	},
	"레버액션 소총": {
		"category": Category.WEAPON,
		"description": "클래식한 레버액션 소총. 강력하지만 재장전이 느리다.",
		"stackable": false,
		"weight": 3.5,
		"damage": 22.0,
		"range": 12.0,
		"attack_speed": 1.2,
		"type": "ranged",
		"ammo": "탄약",
		"rarity": 0.05,
		"value": 18000
	},
	"탄약": {
		"category": Category.WEAPON,
		"description": "9mm 탄약.",
		"stackable": true,
		"max_stack": 30,
		"weight": 0.05,
		"rarity": 0.15,
		"value": 150
	},
	"수류탄": {
		"category": Category.WEAPON,
		"description": "신관 안전핀을 뽑아 투척하는 대인 수류탄. 광역 피해.",
		"stackable": true,
		"max_stack": 3,
		"weight": 0.5,
		"rarity": 0.05,
		"value": 4000
	},

	# === 장비 ===
	"가방": {
		"category": Category.EQUIPMENT,
		"description": "튼튼한 배낭. 인벤토리 최대 무게를 +15.0kg 늘려준다.",
		"stackable": false,
		"weight": 0.5,
		"equip_slot": "back",
		"weight_bonus": 15.0,
		"rarity": 0.15,
		"value": 6000
	},
	"방독면": {
		"category": Category.EQUIPMENT,
		"description": "오염된 공기를 차단하는 방독면.",
		"stackable": false,
		"weight": 0.8,
		"equip_slot": "head",
		"effects": {"poison_resist": true},
		"rarity": 0.2,
		"value": 4500
	},
	"방탄조끼": {
		"category": Category.EQUIPMENT,
		"description": "방탄 재질의 조끼. 대미지를 크게 줄여준다.",
		"stackable": false,
		"weight": 3.0,
		"equip_slot": "body",
		"defense": 15.0,
		"rarity": 0.1,
		"value": 12000
	},
	"운동화": {
		"category": Category.EQUIPMENT,
		"description": "가볍고 튼튼한 운동화. 이동 속도가 빨라진다.",
		"stackable": false,
		"weight": 0.5,
		"equip_slot": "feet",
		"speed_bonus": 0.3,
		"rarity": 0.3,
		"value": 3500
	},

	# === 도구 ===
	"손전등": {
		"category": Category.TOOL,
		"description": "LED 손전등. 밤에 시야를 밝혀준다.",
		"stackable": false,
		"weight": 0.3,
		"effects": {"night_vision": true},
		"rarity": 0.35,
		"value": 1500
	},
	"개조 손전등": {
		"category": Category.TOOL,
		"description": "초강력 개조 손전등. 밤에도 낮처럼 볼 수 있다.",
		"stackable": false,
		"weight": 0.8,
		"effects": {"night_vision": true, "blind_enemies": true},
		"rarity": 0.05,
		"value": 5000
	},
	"비상용 배터리": {
		"category": Category.TOOL,
		"description": "충전식 비상 배터리. 여러 장비에 사용 가능.",
		"stackable": true,
		"max_stack": 5,
		"weight": 0.5,
		"rarity": 0.25,
		"value": 1000
	},
	"지도": {
		"category": Category.TOOL,
		"description": "이 지역의 약도. 미니맵 범위가 넓어진다.",
		"stackable": false,
		"weight": 0.1,
		"effects": {"map_range": 2},
		"rarity": 0.2,
		"value": 2000
	},
	"조명탄": {
		"category": Category.TOOL,
		"description": "고광도 조명탄. 밤 시야 보정 등 유용한 유틸리티 도구.",
		"stackable": true,
		"max_stack": 5,
		"weight": 0.3,
		"rarity": 0.1,
		"value": 1500
	},
	"군용 나침반": {
		"category": Category.TOOL,
		"description": "혹독한 오염 지대에서도 정상 작동하는 전술 군용 나침반.",
		"stackable": false,
		"weight": 0.2,
		"rarity": 0.05,
		"value": 10000
	},

	# === 재료 ===
	"나무": {
		"category": Category.MATERIAL,
		"description": "건축 및 크래프팅용 목재.",
		"stackable": true,
		"max_stack": 20,
		"weight": 1.0,
		"rarity": 0.7,
		"value": 200
	},
	"못": {
		"category": Category.MATERIAL,
		"description": "건축용 못. 바리케이드 제작에 필요.",
		"stackable": true,
		"max_stack": 30,
		"weight": 0.1,
		"rarity": 0.6,
		"value": 100
	},
	"천": {
		"category": Category.MATERIAL,
		"description": "찢어진 천 조각. 다양한 용도.",
		"stackable": true,
		"max_stack": 15,
		"weight": 0.2,
		"rarity": 0.6,
		"value": 300
	},
	"고철": {
		"category": Category.MATERIAL,
		"description": "재활용 가능한 금속 조각.",
		"stackable": true,
		"max_stack": 15,
		"weight": 0.8,
		"rarity": 0.5,
		"value": 500
	},
	"바리케이드 재료": {
		"category": Category.MATERIAL,
		"description": "은신처 창고 슬롯 확장 및 제작대 레벨업에 사용되는 강철 바리케이드 재료.",
		"stackable": true,
		"max_stack": 10,
		"weight": 2.0,
		"rarity": 0.2,
		"value": 2500
	},
	"기계 부품": {
		"category": Category.MATERIAL,
		"description": "복잡한 기계의 부품. 정밀 장비 개조에 필수적이다.",
		"stackable": true,
		"max_stack": 20,
		"weight": 0.5,
		"rarity": 0.1,
		"value": 3000
	},
	"폐전선": {
		"category": Category.MATERIAL,
		"description": "공장 또는 주거지 전자 제품 등에서 나오는 흔한 구리 전선.",
		"stackable": true,
		"max_stack": 15,
		"weight": 0.4,
		"rarity": 0.5,
		"value": 1200
	},
	"화약": {
		"category": Category.MATERIAL,
		"description": "화력 병기를 조립하기 위한 군용 등급 화약.",
		"stackable": true,
		"max_stack": 10,
		"weight": 0.2,
		"rarity": 0.15,
		"value": 2000
	},
	"CPU": {
		"category": Category.MATERIAL,
		"description": "컴퓨터 파밍에서 발견되는 정밀 가공 프로세서 전리품.",
		"stackable": true,
		"max_stack": 5,
		"weight": 0.2,
		"rarity": 0.15,
		"value": 8000
	},
	"그래픽카드": {
		"category": Category.MATERIAL,
		"description": "컴퓨터 본체에서 극히 희박하게 입수되는 최고가 전자 전리품.",
		"stackable": true,
		"max_stack": 2,
		"weight": 1.0,
		"rarity": 0.04,
		"value": 25000
	},

	# === 퀘스트 및 고가치 전리품 ===
	"라디오 부품": {
		"category": Category.QUEST,
		"description": "장거리 무전기 조립에 필요한 핵심 부품. 3개를 모으면 구조 신호 송신 가능.",
		"stackable": true,
		"max_stack": 5,
		"weight": 0.5,
		"rarity": 0.08,
		"value": 5000
	},
	"장거리 무전기": {
		"category": Category.QUEST,
		"description": "극히 드물게 발견되는 고가치 군용 통신기. 상인 우호도 퀘스트 및 최고가 전리품.",
		"stackable": false,
		"weight": 1.5,
		"rarity": 0.01,
		"value": 80000
	},
	"군사 문서": {
		"category": Category.QUEST,
		"description": "기밀 등급의 군사 문서. 감염의 원인에 대한 단서가 적혀있다.",
		"stackable": false,
		"weight": 0.1,
		"rarity": 0.03,
		"value": 15000
	},
	"암호화된 SSD": {
		"category": Category.QUEST,
		"description": "기밀 데이터가 담긴 암호화된 군용 SSD. 플리마켓에서 고가에 거래된다.",
		"stackable": true,
		"max_stack": 5,
		"weight": 0.1,
		"rarity": 0.03,
		"value": 16000
	},
	"금시계": {
		"category": Category.MISC,
		"description": "고급 주거지나 금고 등에서 발견되는 고풍스러운 귀금속 시계.",
		"stackable": true,
		"max_stack": 5,
		"weight": 0.1,
		"rarity": 0.1,
		"value": 12000
	},
	"은반지": {
		"category": Category.MISC,
		"description": "주거지 침실이나 금고 등에서 발견되는 은빛 귀금속 전리품.",
		"stackable": true,
		"max_stack": 10,
		"weight": 0.05,
		"rarity": 0.25,
		"value": 6000
	},
	"골동품": {
		"category": Category.MISC,
		"description": "상당히 묵직하고 가치 높은 골동품 도자기.",
		"stackable": true,
		"max_stack": 2,
		"weight": 2.0,
		"rarity": 0.08,
		"value": 18000
	},
	"사진": {
		"category": Category.QUEST,
		"description": "누군가의 가족 사진. 뒷면에 메시지가 적혀있다.",
		"stackable": false,
		"weight": 0.01,
		"rarity": 0.05,
		"value": 500
	}
}

# ============================================================
# 루트 테이블 (건물/위치별 스폰 확률)
# ============================================================
const LOOT_TABLES: Dictionary = {
	"house": [
		["식량통조림", 0.3], ["생수", 0.3], ["마른 빵", 0.2],
		["나이프", 0.1], ["천", 0.2], ["붕대", 0.15],
		["못", 0.15], ["탄산음료", 0.1], ["손전등", 0.08],
		["사진", 0.04], ["은반지", 0.15], ["금시계", 0.05], ["골동품", 0.03], ["폐전선", 0.1]
	],
	"store": [
		["식량통조림", 0.4], ["생수", 0.4], ["에너지바", 0.2],
		["탄산음료", 0.2], ["마른 빵", 0.3], ["천", 0.15],
		["야구방망이", 0.08], ["커피", 0.1], ["에너지 드링크", 0.15],
		["은반지", 0.1], ["폐전선", 0.2]
	],
	"hospital": [
		["구급상자", 0.4], ["진통제", 0.3], ["붕대", 0.4],
		["약초", 0.15], ["방독면", 0.08], ["생수", 0.15]
	],
	"police": [
		["권총", 0.1], ["탄약", 0.25], ["방탄조끼", 0.08],
		["무기", 0.15], ["손전등", 0.15], ["비상용 배터리", 0.1],
		["지도", 0.08], ["화약", 0.15], ["군용 나침반", 0.08]
	],
	"military": [
		["탄약", 0.35], ["권총", 0.08], ["방탄조끼", 0.12],
		["구급상자", 0.2], ["비상용 배터리", 0.15], ["라디오 부품", 0.05],
		["군사 문서", 0.03], ["에너지바", 0.15], ["전투 식량", 0.15], ["에너지 드링크", 0.2],
		["화약", 0.25], ["장거리 무전기", 0.01], ["수류탄", 0.1], ["암호화된 SSD", 0.05], ["군용 나침반", 0.1]
	],
	"shelter": [
		["나무", 0.5], ["못", 0.4], ["천", 0.3],
		["고철", 0.3], ["식량통조림", 0.2], ["생수", 0.2]
	],
	"forest": [
		["나무", 0.6], ["약초", 0.4]
	],
	"car": [
		["고철", 0.35], ["비상용 배터리", 0.12], ["생수", 0.08],
		["에너지바", 0.08], ["지도", 0.04], ["폐전선", 0.15]
	],
	"radio_tower": [
		["라디오 부품", 0.3], ["비상용 배터리", 0.25],
		["고철", 0.25], ["손전등", 0.12], ["CPU", 0.1]
	],
	"factory": [
		["기계 부품", 0.5], ["고철", 0.4], ["못", 0.3],
		["비상용 배터리", 0.2], ["가방", 0.08], ["폐전선", 0.35],
		["CPU", 0.15], ["그래픽카드", 0.03], ["화약", 0.1], ["암호화된 SSD", 0.04]
	],
	"warehouse": [
		["나무", 0.4], ["고철", 0.4], ["천", 0.25],
		["야구방망이", 0.15], ["못", 0.3], ["바리케이드 재료", 0.1]
	],
	"school": [
		["마른 빵", 0.3], ["생수", 0.3], ["가방", 0.15],
		["천", 0.25], ["사진", 0.1], ["은반지", 0.05]
	],
	"barn": [
		["농작물", 0.5], ["나무", 0.4], ["고철", 0.15],
		["생수", 0.2]
	]
}

# ============================================================
# 아이템 생성 및 조회 헬퍼
# ============================================================
func get_item_data(item_name: String) -> Dictionary:
	return ITEM_DATABASE.get(item_name, {})

func generate_loot(loot_table_name: String, resource_multiplier: float = 1.0, count_min: int = 1, count_max: int = 4) -> Array[String]:
	var table: Array = LOOT_TABLES.get(loot_table_name, [])
	var loot: Array[String] = []
	if table.is_empty():
		return loot

	var num_rolls: int = randi_range(count_min, count_max)
	for r in range(num_rolls):
		for entry in table:
			var item_name: String = entry[0]
			var chance: float = entry[1]
			if randf() < chance * resource_multiplier:
				loot.append(item_name)
				break
	return loot
