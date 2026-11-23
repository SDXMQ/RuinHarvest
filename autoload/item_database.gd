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
	var seen_files: Dictionary = {}
	var dir = DirAccess.open("res://data/items/")
	if dir:
		dir.list_dir_begin()
		var raw_name = dir.get_next()
		while raw_name != "":
			var fname := raw_name.trim_suffix(".remap")
			if fname.ends_with(".tres") and fname != "탄약.tres" and not seen_files.has(fname):
				seen_files[fname] = true
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
						d["inner_grid"] = res.backpack_grid
					if res.equip_slot == "vest":
						var vest_grid := Vector2i(3, 2)
						if res.id.contains("3레벨"):
							vest_grid = Vector2i(4, 3)
						elif res.id.contains("2레벨"):
							vest_grid = Vector2i(4, 2)
						d["rig_grid"] = vest_grid
						d["inner_grid"] = vest_grid
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
			raw_name = dir.get_next()
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
	if not items.has("Scav 인식표"):
		items["Scav 인식표"] = {
			"id": "Scav 인식표",
			"name": "Scav 인식표 (Dogtag)",
			"category": ItemCategory.QUEST,
			"type": "dogtag",
			"description": "사살한 무장 스캐브·레이더·보스에게서 회수한 금속 군번줄입니다. 은신처 전술 기록실 전적 집계 및 고가 납품에 사용됩니다. (안전 컨테이너 보관 가능)",
			"stackable": true,
			"max_stack": 10,
			"weight": 0.05,
			"rarity": 3,
			"value": 4500,
			"effects": {}
		}
	if not items.has("초콜릿"):
		items["초콜릿"] = {
			"id": "초콜릿",
			"name": "초콜릿 바",
			"category": ItemCategory.FOOD,
			"description": "열량이 높은 비상용 초콜릿 바입니다. 허기와 스태미나를 빠르게 회복합니다.",
			"stackable": true,
			"max_stack": 5,
			"weight": 0.12,
			"rarity": 1,
			"value": 450,
			"effects": {
				"hunger": 20,
				"stamina": 20,
				"stress": -5
			}
		}

	if not items.has("함정"):
		items["함정"] = {
			"id": "함정",
			"name": "강철 덫 (함정)",
			"category": ItemCategory.TOOL,
			"type": "trap",
			"description": "접근하는 감염체나 적의 발목을 물어 피해와 이동 저지를 가하는 강철 덫입니다. 인벤토리에서 사용하여 설치합니다.",
			"stackable": true,
			"max_stack": 3,
			"weight": 1.2,
			"rarity": 2,
			"value": 2400,
			"effects": {}
		}

	# 특수 보관 케이스 4종 (외형 2x2 압축 보관함, 내부 6x6~8x8 카테고리 필터 수납)
	if not items.has("탄약 케이스"):
		items["탄약 케이스"] = {
			"id": "탄약 케이스",
			"name": "탄약 케이스",
			"category": ItemCategory.EQUIPMENT,
			"type": "storage_case",
			"description": "각종 구경의 탄약을 압축 보관하는 강철 탄약통입니다. 외부 2x2 칸만 차지하며 내부 6x6(36칸) 탄약 전용 공간을 제공합니다.",
			"stackable": false,
			"max_stack": 1,
			"grid_w": 2,
			"grid_h": 2,
			"inner_grid": Vector2i(6, 6),
			"allowed_filter": "ammo",
			"weight": 1.2,
			"rarity": 0.08,
			"value": 28000,
			"effects": {}
		}
	if not items.has("의약품 케이스"):
		items["의약품 케이스"] = {
			"id": "의약품 케이스",
			"name": "의약품 케이스",
			"category": ItemCategory.EQUIPMENT,
			"type": "storage_case",
			"description": "응급 치료킷과 항생제를 위생적으로 정리하는 의료 보관함입니다. 외부 2x2 칸만 차지하며 내부 7x7(49칸) 의료품 전용 공간을 제공합니다.",
			"stackable": false,
			"max_stack": 1,
			"grid_w": 2,
			"grid_h": 2,
			"inner_grid": Vector2i(7, 7),
			"allowed_filter": "medical",
			"weight": 1.4,
			"rarity": 0.06,
			"value": 32000,
			"effects": {}
		}
	if not items.has("무기 부품 상자"):
		items["무기 부품 상자"] = {
			"id": "무기 부품 상자",
			"name": "무기 부품 상자",
			"category": ItemCategory.EQUIPMENT,
			"type": "storage_case",
			"description": "총열·조준경·소음기 등 총기 모딩 부품을 대량 보관하는 폼 패딩 상자입니다. 외부 2x2 칸만 차지하며 내부 8x8(64칸) 부품 전용 공간을 제공합니다.",
			"stackable": false,
			"max_stack": 1,
			"grid_w": 2,
			"grid_h": 2,
			"inner_grid": Vector2i(8, 8),
			"allowed_filter": "weapon_part",
			"weight": 1.8,
			"rarity": 0.04,
			"value": 45000,
			"effects": {}
		}
	if not items.has("인식표 지갑"):
		items["인식표 지갑"] = {
			"id": "인식표 지갑",
			"name": "인식표 지갑",
			"category": ItemCategory.EQUIPMENT,
			"type": "storage_case",
			"description": "Scav 인식표와 열쇠·보안 키카드를 모아두는 전술 기밀 파우치입니다. 외부 2x2 칸만 차지하며 내부 6x6(36칸)을 제공합니다.",
			"stackable": false,
			"max_stack": 1,
			"grid_w": 2,
			"grid_h": 2,
			"inner_grid": Vector2i(6, 6),
			"allowed_filter": "dogtag_key",
			"weight": 0.4,
			"rarity": 0.06,
			"value": 24000,
			"effects": {}
		}

# 장소 및 가구별 루트 테이블
var loot_tables: Dictionary = {
	"crate": [
		{"id": "식량통조림", "chance": 0.35}, {"id": "생수", "chance": 0.35},
		{"id": "붕대", "chance": 0.25}, {"id": "9mm", "chance": 0.32, "amount": 20},
		{"id": ".45ACP", "chance": 0.22, "amount": 15}, {"id": "12게이지_벅샷", "chance": 0.20, "amount": 8},
		{"id": "5.56mm", "chance": 0.16, "amount": 18}, {"id": "7.62mm", "chance": 0.14, "amount": 15},
		{"id": "M9_리시버", "chance": 0.16}, {"id": "레밍턴_리시버", "chance": 0.12},
		{"id": "MP5_리시버", "chance": 0.08}, {"id": "권총", "chance": 0.08}, {"id": "손전등", "chance": 0.12},
		{"id": "레드닷_사이트", "chance": 0.12}, {"id": "수직_포어그립", "chance": 0.10},
		{"id": "플래시_소염기", "chance": 0.10}, {"id": "경량_접이식_스톡", "chance": 0.09}
	],
	"barrel": [
		{"id": "고철", "chance": 0.5}, {"id": "화약", "chance": 0.25},
		{"id": "폐전선", "chance": 0.3}, {"id": "생수", "chance": 0.15},
		{"id": "9mm", "chance": 0.18, "amount": 15}
	],
	"car": [
		{"id": "고철", "chance": 0.4}, {"id": "비상용 배터리", "chance": 0.22},
		{"id": "군용 나침반", "chance": 0.12}, {"id": "금시계", "chance": 0.06},
		{"id": "지도", "chance": 0.12}, {"id": "9mm", "chance": 0.24, "amount": 18},
		{"id": ".45ACP", "chance": 0.18, "amount": 15}, {"id": "12게이지_벅샷", "chance": 0.16, "amount": 8},
		{"id": "M9_리시버", "chance": 0.14}, {"id": "레밍턴_리시버", "chance": 0.08},
		{"id": "전술_손전등", "chance": 0.10}, {"id": "짧은_총열", "chance": 0.08}
	],
	"fridge": [
		{"id": "식량통조림", "chance": 0.5}, {"id": "생수", "chance": 0.5},
		{"id": "초콜릿", "chance": 0.3}, {"id": "에너지 드링크", "chance": 0.25}
	],
	"residential": [
		{"id": "식량통조림", "chance": 0.5}, {"id": "생수", "chance": 0.5},
		{"id": "초콜릿", "chance": 0.25}, {"id": "에너지 드링크", "chance": 0.25}
	],
	"bed": [
		{"id": "붕대", "chance": 0.45}, {"id": "진통제", "chance": 0.3},
		{"id": "천", "chance": 0.4}, {"id": "1레벨_가방", "chance": 0.15},
		{"id": "은반지", "chance": 0.12}, {"id": "9mm", "chance": 0.22, "amount": 15}
	],
	"desk": [
		{"id": "군용 나침반", "chance": 0.18}, {"id": "지도", "chance": 0.20},
		{"id": "9mm", "chance": 0.32, "amount": 20}, {"id": ".45ACP", "chance": 0.22, "amount": 15},
		{"id": "5.56mm", "chance": 0.16, "amount": 18}, {"id": "CPU", "chance": 0.15},
		{"id": "금시계", "chance": 0.12}, {"id": "장거리 무전기", "chance": 0.08},
		{"id": "무기고 열쇠", "chance": 0.10}, {"id": "보안 키카드", "chance": 0.06},
		{"id": "M9_리시버", "chance": 0.14}, {"id": "MP5_리시버", "chance": 0.08},
		{"id": "레드닷_사이트", "chance": 0.12}, {"id": "적색_레이저_표적지시기", "chance": 0.10},
		{"id": "대용량_확장_탄창", "chance": 0.10}
	],
	"shelf": [
		{"id": "식량통조림", "chance": 0.35}, {"id": "생수", "chance": 0.35},
		{"id": "고철", "chance": 0.35}, {"id": "못", "chance": 0.3},
		{"id": "손전등", "chance": 0.2}, {"id": "비상용 배터리", "chance": 0.2},
		{"id": "12게이지_벅샷", "chance": 0.20, "amount": 8}, {"id": "레밍턴_리시버", "chance": 0.12},
		{"id": "레버액션 소총", "chance": 0.08}, {"id": "컴펜세이터", "chance": 0.10},
		{"id": "수직_포어그립", "chance": 0.10}
	],
	"house": [
		{"id": "식량통조림", "chance": 0.3}, {"id": "생수", "chance": 0.3},
		{"id": "마른 빵", "chance": 0.2}, {"id": "나이프", "chance": 0.12},
		{"id": "천", "chance": 0.2}, {"id": "붕대", "chance": 0.18},
		{"id": "9mm", "chance": 0.25, "amount": 18}, {"id": ".45ACP", "chance": 0.18, "amount": 14},
		{"id": "12게이지_벅샷", "chance": 0.15, "amount": 8},
		{"id": "M9_리시버", "chance": 0.12}, {"id": "레밍턴_리시버", "chance": 0.08},
		{"id": "은반지", "chance": 0.15}, {"id": "금시계", "chance": 0.05}
	],
	"hospital": [
		{"id": "구급상자", "chance": 0.4}, {"id": "진통제", "chance": 0.3},
		{"id": "붕대", "chance": 0.4}, {"id": "약초", "chance": 0.15},
		{"id": "고급 치료킷", "chance": 0.12}, {"id": "항생제", "chance": 0.22}
	],
	"military": [
		{"id": "9mm", "chance": 0.38, "amount": 25}, {"id": "5.56mm", "chance": 0.38, "amount": 25},
		{"id": "7.62mm", "chance": 0.34, "amount": 20}, {"id": ".45ACP", "chance": 0.28, "amount": 20},
		{"id": "12게이지_벅샷", "chance": 0.26, "amount": 10}, {"id": "12게이지_슬러그", "chance": 0.20, "amount": 8},
		{"id": "권총", "chance": 0.12}, {"id": "MP5_리시버", "chance": 0.22},
		{"id": "AK_리시버", "chance": 0.20}, {"id": "M4_리시버", "chance": 0.18},
		{"id": "레밍턴_리시버", "chance": 0.15}, {"id": "레버액션 소총", "chance": 0.12},
		{"id": "SV98_리시버", "chance": 0.10}, {"id": "방탄조끼", "chance": 0.15},
		{"id": "구급상자", "chance": 0.22}, {"id": "수류탄", "chance": 0.15}, {"id": "암호화된 SSD", "chance": 0.06},
		{"id": "2배율_조준경", "chance": 0.16}, {"id": "4배율_ACOG", "chance": 0.12},
		{"id": "소음기", "chance": 0.12}, {"id": "대용량_확장_탄창", "chance": 0.16},
		{"id": "컴펜세이터", "chance": 0.14}, {"id": "RK-1_인체공학_그립", "chance": 0.12},
		{"id": "적색_레이저_표적지시기", "chance": 0.14}
	],
	"locked_armory": [
		{"id": "5.56mm", "chance": 0.65, "amount": 30}, {"id": "7.62mm", "chance": 0.65, "amount": 30},
		{"id": "9mm", "chance": 0.50, "amount": 30}, {"id": "12게이지_슬러그", "chance": 0.45, "amount": 12},
		{"id": "M4_리시버", "chance": 0.28}, {"id": "AK_리시버", "chance": 0.28},
		{"id": "MP5_리시버", "chance": 0.22}, {"id": "SV98_리시버", "chance": 0.18},
		{"id": "3레벨_방탄복", "chance": 0.35}, {"id": "3레벨_헬멧", "chance": 0.35},
		{"id": "수류탄", "chance": 0.45}, {"id": "소음기", "chance": 0.35},
		{"id": "4배율_ACOG", "chance": 0.30}, {"id": "8배율_스나이퍼_스코프", "chance": 0.22},
		{"id": "50발_드럼_탄창", "chance": 0.25}, {"id": "PRS_정밀_저격_스톡", "chance": 0.25},
		{"id": "정밀_롱헤비_총열", "chance": 0.25}, {"id": "암호화된 SSD", "chance": 0.25},
		{"id": "장거리 무전기", "chance": 0.25}
	],
	"locked_medical": [
		{"id": "고급 치료킷", "chance": 0.75}, {"id": "구급상자", "chance": 0.65},
		{"id": "진통제", "chance": 0.55}, {"id": "항생제", "chance": 0.55},
		{"id": "암호화된 SSD", "chance": 0.35},
		{"id": "그래픽카드", "chance": 0.22}, {"id": "금시계", "chance": 0.3}
	]
}

# 3인 상인 데이터 정의 (우호도 Lv.1~Lv.4 해금 및 안정 소비재 공급)
var traders: Dictionary = {
	"prapor": {
		"name": "프라포 (무기/군수품)",
		"desc": "전직 군수 보급관. 무기·탄약·방어구·부품을 최고가(70%)로 매입하며 고등급 군용품을 해금합니다.",
		"stock": [
			{"id": "권총", "price": 18000, "min_level": 1},
			{"id": "9mm", "price": 4500, "amount": 30, "min_level": 1},
			{ "id": ".45ACP", "price": 6250, "amount": 25, "min_level": 1 },
			{"id": "12게이지_벅샷", "price": 3600, "amount": 12, "min_level": 1},
			{"id": "레드닷_사이트", "price": 6500, "min_level": 1},
			{"id": "수류탄", "price": 4000, "min_level": 1},
			{"id": "파이프", "price": 1500, "min_level": 1},
			{"id": "1레벨_방탄복", "price": 9000, "min_level": 1},
			{"id": "방탄조끼", "price": 15000, "min_level": 1},
			{"id": "1레벨_헬멧", "price": 6000, "min_level": 1},
			{"id": "MP5_리시버", "price": 26000, "min_level": 2},
			{"id": "레버액션 소총", "price": 35000, "min_level": 2},
			{"id": "12게이지_슬러그", "price": 5000, "amount": 10, "min_level": 2},
			{"id": "대용량_확장_탄창", "price": 9000, "min_level": 2},
			{"id": "수직_포어그립", "price": 4000, "min_level": 2},
			{"id": "2레벨_방탄복", "price": 21000, "min_level": 2},
			{"id": "5.56mm", "price": 10500, "amount": 30, "min_level": 3},
			{"id": "7.62mm", "price": 11250, "amount": 25, "min_level": 3},
			{"id": "AK_리시버", "price": 28000, "min_level": 3},
			{"id": "탄약 케이스", "price": 28000, "min_level": 3},
			{"id": "3레벨_방탄복", "price": 38000, "min_level": 4},
			{"id": "M4_리시버", "price": 36000, "min_level": 4},
			{"id": "무기 부품 상자", "price": 45000, "min_level": 4}
		]
	},
	"therapist": {
		"name": "테라피스트 (의료/식량)",
		"desc": "응급 의사 출신. 의약품과 식량/음료를 최고가(75%)로 매입하며 구급 물자를 상시 공급합니다.",
		"stock": [
			{"id": "붕대", "price": 800, "min_level": 1},
			{"id": "생수", "price": 600, "min_level": 1},
			{"id": "식량통조림", "price": 1200, "min_level": 1},
			{"id": "에너지바", "price": 800, "min_level": 1},
			{"id": "진통제", "price": 2500, "min_level": 1},
			{"id": "구급상자", "price": 4000, "min_level": 1},
			{"id": "항생제", "price": 3400, "min_level": 2},
			{"id": "고급 치료킷", "price": 8500, "min_level": 2},
			{"id": "의약품 케이스", "price": 32000, "min_level": 3},
			{"id": "인식표 지갑", "price": 24000, "min_level": 4}
		]
	},
	"fence": {
		"name": "펜스 (잡화/암시장)",
		"desc": "무엇이든 취급하는 브로커. 잡동사니·재료·기타 품목을 고르게 매입(55%)하며 특수 도구를 판매합니다.",
		"stock": [
			{"id": "고철", "price": 2000, "amount": 5, "min_level": 1},
			{"id": "못", "price": 1000, "amount": 10, "min_level": 1},
			{"id": "천", "price": 1000, "amount": 5, "min_level": 1},
			{"id": "폐전선", "price": 1200, "min_level": 1},
			{"id": "손전등", "price": 2000, "min_level": 1},
			{"id": "1레벨_가방", "price": 6500, "min_level": 1},
			{"id": "가방", "price": 8000, "min_level": 1},
			{"id": "장거리 무전기", "price": 9500, "min_level": 2},
			{"id": "2레벨_가방", "price": 15000, "min_level": 2},
			{"id": "함정", "price": 2600, "min_level": 2},
			{"id": "무기고 열쇠", "price": 22000, "min_level": 3},
			{"id": "인식표 지갑", "price": 24000, "min_level": 3},
			{"id": "보안 키카드", "price": 32000, "min_level": 4},
			{"id": "3레벨_가방", "price": 30000, "min_level": 4}
		]
	}
}

func resolve_item_id(id: String) -> String:
	if id in ["탄약", "9mm 탄약", "9mm_탄약"]:
		return "9mm"
	if id == "나침반":
		if items.has("군용 나침반"):
			return "군용 나침반"
	if id == "에너지드링크":
		if items.has("에너지 드링크"):
			return "에너지 드링크"
	if id in ["기밀_SSD", "기밀 SSD", "암호화된_SSD", "암호화된 SSD"]:
		if items.has("암호화된 SSD"):
			return "암호화된 SSD"
	if id in ["Scav 식별줄(Dogtag)", "Scav 인식표 (Dogtag)", "Scav_인식표", "Scav 인식표"]:
		if items.has("Scav 인식표"):
			return "Scav 인식표"
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
	var pool: Array = loot_tables.get(table_name, loot_tables.get("crate", []))
	if pool.is_empty() or rolls <= 0:
		return results

	var total_weight: float = 0.0
	for entry in pool:
		total_weight += max(0.0, float(entry.get("chance", 0.0)))
	if total_weight <= 0.0:
		return results

	for i in range(rolls):
		var roll_val: float = randf() * total_weight
		var acc: float = 0.0
		var chosen: Dictionary = pool[pool.size() - 1]
		for entry in pool:
			acc += max(0.0, float(entry.get("chance", 0.0)))
			if roll_val <= acc:
				chosen = entry
				break
		var drop_id: String = resolve_item_id(String(chosen["id"]))
		var drop_amt: int = int(chosen.get("amount", 0))
		if drop_amt <= 0:
			if is_ammo_item(drop_id):
				drop_amt = randi_range(6, 12) if drop_id.contains("12게이지") else randi_range(12, 24)
			else:
				drop_amt = 1
		_add_to_loot(results, drop_id, drop_amt)
				
	return results

func _add_to_loot(results: Array, id: String, amount: int) -> void:
	var item_data: Dictionary = get_item_data(id)
	var max_stack: int = max(1, int(item_data.get("max_stack", 1)))
	var rem: int = amount
	
	for res in results:
		if rem <= 0:
			return
		if res["id"] == id and int(res["amount"]) < max_stack:
			var space: int = max_stack - int(res["amount"])
			var add_cnt: int = min(rem, space)
			res["amount"] = int(res["amount"]) + add_cnt
			rem -= add_cnt
			
	while rem > 0:
		var chunk: int = min(rem, max_stack)
		results.append({"id": id, "amount": chunk})
		rem -= chunk

func get_item_grid_size(id: String) -> Vector2i:
	if _cached_grid_sizes.has(id):
		return _cached_grid_sizes[id]
		
	var resolved_id: String = resolve_item_id(id)
	var data = get_item_data(resolved_id)
	var size = Vector2i(1, 1)
	if data.has("grid_w") and data.has("grid_h"):
		size = Vector2i(data["grid_w"], data["grid_h"])
	else:
		var cat = data.get("category", -1)
		var type = data.get("type", "")
		
		# 무기 부착물/파츠
		if WeaponPartsDatabase and WeaponPartsDatabase.PARTS.has(resolved_id):
			var pslot = WeaponPartsDatabase.PARTS[resolved_id].get("slot", "")
			if pslot == "barrel" or pslot == "stock":
				size = Vector2i(1, 2)
			else:
				size = Vector2i(1, 1)
		elif cat == ItemCategory.WEAPON or type == "receiver":
			if type == "melee":
				size = Vector2i(1, 3)
			elif resolved_id == "권총" or resolved_id.begins_with("M9") or resolved_id.begins_with("MP5"):
				size = Vector2i(1, 2)
			elif resolved_id == "수류탄":
				size = Vector2i(1, 1)
			elif resolved_id == "탄약" or resolved_id.contains("9mm") or resolved_id.contains("5.56") or resolved_id.contains("7.62") or resolved_id.contains("12게이지") or resolved_id.contains(".45"):
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
			if resolved_id.contains("상자") or resolved_id.contains("키트"):
				size = Vector2i(2, 2)
			else:
				size = Vector2i(1, 1)
		elif cat == ItemCategory.TOOL:
			if resolved_id.contains("망원경"):
				size = Vector2i(1, 2)
			else:
				size = Vector2i(1, 1)
				
	_cached_grid_sizes[id] = size
	return size

func is_ammo_item(item_id: String) -> bool:
	if item_id == "":
		return false
	return item_id == "탄약" or item_id.ends_with("mm") or item_id.contains("게이지") or item_id.contains("ACP")

func get_item_equip_slot(id: String) -> String:
	if _cached_equip_slots.has(id):
		return _cached_equip_slots[id]
		
	var data = get_item_data(id)
	var slot = ""
	var type = data.get("type", "")
	if type == "ammo" or is_ammo_item(id):
		_cached_equip_slots[id] = ""
		return ""
	if data.has("equip_slot"):
		slot = data["equip_slot"]
	else:
		var cat = data.get("category", -1)
		if cat == ItemCategory.WEAPON or type == "receiver":
			if id == "수류탄" or type == "throwable":
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
