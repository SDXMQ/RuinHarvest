# res://systems/weapon_parts_database.gd
class_name WeaponPartsDatabase
extends RefCounted

## 타르코프 & 배그 하이브리드 총기 모딩 데이터베이스 및 스탯 계산 엔진

# ============================================================
# 1. 탄종 정의 (Ammo Types)
# ============================================================
const AMMO_TYPES = {
	"9mm": {
		"name": "9mm 탄약",
		"damage_mult": 1.0,
		"penetration": 10,
		"recoil_mult": 1.0,
		"noise_mult": 1.0,
		"pellets": 1,
		"value": 150
	},
	".45ACP": {
		"name": ".45 ACP 탄약",
		"damage_mult": 1.35,
		"penetration": 8,
		"recoil_mult": 1.25,
		"noise_mult": 1.1,
		"pellets": 1,
		"value": 250
	},
	"5.56mm": {
		"name": "5.56x45mm NATO 탄약",
		"damage_mult": 1.25,
		"penetration": 25,
		"recoil_mult": 1.1,
		"noise_mult": 1.2,
		"pellets": 1,
		"value": 350
	},
	"7.62mm": {
		"name": "7.62x39mm 소총탄",
		"damage_mult": 1.6,
		"penetration": 35,
		"recoil_mult": 1.45,
		"noise_mult": 1.3,
		"pellets": 1,
		"value": 450
	},
	"12게이지_벅샷": {
		"name": "12게이지 산탄 (8펠릿)",
		"damage_mult": 0.4, # 펠릿당 0.4 x 8 = 3.2
		"penetration": 5,
		"recoil_mult": 1.8,
		"noise_mult": 1.4,
		"pellets": 8,
		"value": 300
	},
	"12게이지_슬러그": {
		"name": "12게이지 슬러그탄 (단발)",
		"damage_mult": 2.8,
		"penetration": 30,
		"recoil_mult": 2.0,
		"noise_mult": 1.5,
		"pellets": 1,
		"value": 500
	}
}

# ============================================================
# 2. 리시버 (기본 프레임) 정의
# ============================================================
const RECEIVERS = {
	"M9_리시버": {
		"name": "M9 베레타 리시버",
		"category": "pistol",
		"base_damage": 16.0,
		"base_range": 9.0,
		"base_rpm": 180,
		"base_recoil": 25.0,
		"base_accuracy": 75.0,
		"ammo_types": ["9mm", ".45ACP"],
		"default_ammo": "9mm",
		"slots": {
			"barrel": 1, "muzzle": 1, "grip": 1,
			"magazine": 1, "optic": 1, "rail": 1
		},
		"value": 8000,
		"weight": 0.5
	},
	"MP5_리시버": {
		"name": "MP5A5 기관단총 리시버",
		"category": "smg",
		"base_damage": 19.0,
		"base_range": 11.5,
		"base_rpm": 210,
		"base_recoil": 18.0,
		"base_accuracy": 78.0,
		"ammo_types": ["9mm", ".45ACP"],
		"default_ammo": "9mm",
		"slots": {
			"barrel": 1, "muzzle": 1, "stock": 1, "grip": 1,
			"magazine": 1, "optic": 1, "rail": 2
		},
		"value": 26000,
		"weight": 1.3
	},
	"AK_리시버": {
		"name": "AK-47 돌격소총 리시버",
		"category": "rifle",
		"base_damage": 26.0,
		"base_range": 14.0,
		"base_rpm": 110,
		"base_recoil": 45.0,
		"base_accuracy": 65.0,
		"ammo_types": ["7.62mm"],
		"default_ammo": "7.62mm",
		"slots": {
			"barrel": 1, "muzzle": 1, "stock": 1, "grip": 1,
			"magazine": 1, "optic": 1, "rail": 2
		},
		"value": 24000,
		"weight": 1.8
	},
	"M4_리시버": {
		"name": "M4A1 카빈 리시버",
		"category": "rifle",
		"base_damage": 22.0,
		"base_range": 15.0,
		"base_rpm": 135,
		"base_recoil": 35.0,
		"base_accuracy": 80.0,
		"ammo_types": ["5.56mm"],
		"default_ammo": "5.56mm",
		"slots": {
			"barrel": 1, "muzzle": 1, "stock": 1, "grip": 1,
			"magazine": 1, "optic": 1, "rail": 3
		},
		"value": 32000,
		"weight": 1.6
	},
	"레밍턴_리시버": {
		"name": "레밍턴 870 샷건 리시버",
		"category": "shotgun",
		"base_damage": 38.0,
		"base_range": 6.0,
		"base_rpm": 55,
		"base_recoil": 65.0,
		"base_accuracy": 45.0,
		"ammo_types": ["12게이지_벅샷", "12게이지_슬러그"],
		"default_ammo": "12게이지_벅샷",
		"slots": {
			"barrel": 1, "muzzle": 1, "stock": 1,
			"optic": 1, "rail": 2
		},
		"value": 18000,
		"weight": 2.1
	},
	"레버액션_리시버": {
		"name": "윈체스터 레버액션 소총",
		"category": "rifle",
		"base_damage": 38.0,
		"base_range": 16.0,
		"base_rpm": 65,
		"base_recoil": 38.0,
		"base_accuracy": 85.0,
		"ammo_types": [".45ACP", "7.62mm", "9mm"],
		"default_ammo": ".45ACP",
		"slots": {
			"barrel": 1, "muzzle": 1, "stock": 1,
			"optic": 1, "rail": 2
		},
		"value": 35000,
		"weight": 2.8
	},
	"레버액션 소총": {
		"name": "윈체스터 레버액션 소총",
		"category": "rifle",
		"base_damage": 38.0,
		"base_range": 16.0,
		"base_rpm": 65,
		"base_recoil": 38.0,
		"base_accuracy": 85.0,
		"ammo_types": [".45ACP", "7.62mm", "9mm"],
		"default_ammo": ".45ACP",
		"slots": {
			"barrel": 1, "muzzle": 1, "stock": 1,
			"optic": 1, "rail": 2
		},
		"value": 35000,
		"weight": 2.8
	},
	"SV98_리시버": {
		"name": "SV-98 정밀 저격 리시버",
		"category": "sniper",
		"base_damage": 65.0,
		"base_range": 22.0,
		"base_rpm": 35,
		"base_recoil": 75.0,
		"base_accuracy": 95.0,
		"ammo_types": ["7.62mm"],
		"default_ammo": "7.62mm",
		"slots": {
			"barrel": 1, "muzzle": 1, "stock": 1,
			"magazine": 1, "optic": 1, "rail": 2
		},
		"value": 45000,
		"weight": 3.0
	}
}

static func resolve_receiver_id(item_id: String) -> String:
	if RECEIVERS.has(item_id):
		return item_id
	if item_id == "레버액션 소총" or item_id == "레버액션_소총" or item_id.contains("레버액션"):
		return "레버액션_리시버"
	elif item_id.contains("MP5") or item_id.contains("기관단총"):
		return "MP5_리시버"
	elif item_id == "M4A1 소총" or item_id == "M4A1" or item_id.contains("M4"):
		return "M4_리시버"
	elif item_id == "AK-47 돌격소총" or item_id == "AK-47" or item_id.contains("AK"):
		return "AK_리시버"
	elif item_id == "9mm 권총" or item_id == "권총" or item_id.contains("베레타") or item_id.contains("M9"):
		return "M9_리시버"
	elif item_id == "산탄총" or item_id.contains("샷건") or item_id.contains("레밍턴"):
		return "레밍턴_리시버"
	elif item_id.contains("SV98") or item_id.contains("SV-98") or item_id.contains("저격"):
		return "SV98_리시버"
	return item_id

static func is_modifiable_weapon(item: Dictionary) -> bool:
	if item.is_empty(): return false
	var it_id = item.get("id", "")
	if RECEIVERS.has(it_id) or item.get("type", "") == "assembled_weapon":
		return true
	var res_id = resolve_receiver_id(it_id)
	if RECEIVERS.has(res_id):
		return true
	var d = ItemDatabase.get_item_data(it_id)
	var cat = d.get("category", -1)
	var it_type = d.get("type", "")
	if cat == ItemDatabase.ItemCategory.WEAPON and (it_type == "ranged" or it_id.contains("소총") or it_id.contains("권총") or it_id.contains("샷건")):
		return true
	return false

# ============================================================
# 3. 부품 정의 (Weapon Parts)
# ============================================================
const PARTS = {
	# --- 총열 (Barrel) ---
	"짧은_총열": {
		"name": "카빈용 단축 총열",
		"slot": "barrel",
		"compatible_categories": ["pistol", "smg", "rifle", "shotgun"],
		"stat_modifiers": {"range": -2.0, "accuracy": -5, "ads_speed": +15, "weight": -0.3},
		"tier": "cheap", "value": 3500
	},
	"정밀_롱헤비_총열": {
		"name": "매치그레이드 롱 헤비 총열",
		"slot": "barrel",
		"compatible_categories": ["rifle", "smg", "sniper", "pistol"],
		"stat_modifiers": {"range": +4.0, "accuracy": +18, "damage": +3, "recoil": -5, "weight": +0.5},
		"tier": "expensive", "value": 16000
	},

	# --- 총구 (Muzzle) ---
	"소음기": {
		"name": "전술 소음기 (소음 대폭 감소)",
		"slot": "muzzle",
		"compatible_categories": ["all"],
		"stat_modifiers": {"noise_radius": -380, "recoil": -8, "muzzle_flash": false, "range": +1.0},
		"tier": "expensive", "value": 20000
	},
	"컴펜세이터": {
		"name": "반동 제어 컴펜세이터",
		"slot": "muzzle",
		"compatible_categories": ["rifle", "smg", "pistol", "shotgun"],
		"stat_modifiers": {"recoil": -18, "accuracy": +8, "noise_radius": +50},
		"tier": "mid", "value": 8500
	},
	"플래시_소염기": {
		"name": "플래시 하이더 소염기",
		"slot": "muzzle",
		"compatible_categories": ["all"],
		"stat_modifiers": {"muzzle_flash": false, "recoil": -5},
		"tier": "cheap", "value": 4000
	},

	# --- 조준경/스코프 (Optic) ---
	"기본_아이언사이트": {
		"name": "기본 기계식 조준기",
		"slot": "optic",
		"compatible_categories": ["all"],
		"stat_modifiers": {"zoom": 1.0, "accuracy": 0},
		"tier": "cheap", "value": 500
	},
	"레드닷_사이트": {
		"name": "홀로그래픽 레드닷 (1.5x)",
		"slot": "optic",
		"compatible_categories": ["all"],
		"stat_modifiers": {"zoom": 1.5, "accuracy": +10, "ads_speed": +5},
		"tier": "cheap", "value": 6500
	},
	"2배율_조준경": {
		"name": "2배율 전술 스코프 (2.0x)",
		"slot": "optic",
		"compatible_categories": ["all"],
		"stat_modifiers": {"zoom": 2.0, "accuracy": +15, "range": +2.0},
		"tier": "mid", "value": 12000
	},
	"4배율_ACOG": {
		"name": "4배율 ACOG 전투 스코프 (4.0x)",
		"slot": "optic",
		"compatible_categories": ["rifle", "sniper"],
		"stat_modifiers": {"zoom": 4.0, "accuracy": +25, "range": +4.0, "ads_speed": -10},
		"tier": "expensive", "value": 28000
	},
	"8배율_스나이퍼_스코프": {
		"name": "8배율 초장거리 저격 스코프 (8.0x)",
		"slot": "optic",
		"compatible_categories": ["rifle", "sniper"],
		"stat_modifiers": {"zoom": 8.0, "accuracy": +40, "range": +8.0, "ads_speed": -25},
		"tier": "expensive", "value": 48000
	},

	# --- 탄창 (Magazine) ---
	"표준_탄창": {
		"name": "표준형 탄창",
		"slot": "magazine",
		"compatible_categories": ["all"],
		"stat_modifiers": {"magazine_size": 15, "reload_speed": 1.8},
		"tier": "cheap", "value": 2500
	},
	"대용량_확장_탄창": {
		"name": "30발 확장 탄창",
		"slot": "magazine",
		"compatible_categories": ["rifle", "smg", "pistol"],
		"stat_modifiers": {"magazine_size": 30, "reload_speed": 2.2, "weight": +0.3},
		"tier": "mid", "value": 9000
	},
	"50발_드럼_탄창": {
		"name": "50발 대용량 드럼 탄창",
		"slot": "magazine",
		"compatible_categories": ["rifle", "smg", "pistol"],
		"stat_modifiers": {"magazine_size": 50, "reload_speed": 2.8, "weight": +0.9, "recoil": +5},
		"tier": "expensive", "value": 22000
	},

	# --- 개머리판 (Stock) ---
	"경량_접이식_스톡": {
		"name": "경량 접이식 개머리판",
		"slot": "stock",
		"compatible_categories": ["rifle", "smg", "shotgun", "sniper"],
		"stat_modifiers": {"recoil": -10, "ads_speed": +10, "weight": -0.2},
		"tier": "cheap", "value": 4500
	},
	"PRS_정밀_저격_스톡": {
		"name": "PRS 조절식 정밀 반동제어 스톡",
		"slot": "stock",
		"compatible_categories": ["rifle", "smg", "sniper", "shotgun"],
		"stat_modifiers": {"recoil": -28, "accuracy": +12, "weight": +0.5},
		"tier": "expensive", "value": 18000
	},

	# --- 손잡이 (Grip) ---
	"수직_포어그립": {
		"name": "전술 수직 포어그립",
		"slot": "grip",
		"compatible_categories": ["rifle", "smg", "pistol", "sniper"],
		"stat_modifiers": {"recoil": -15, "accuracy": +5},
		"tier": "cheap", "value": 4000
	},
	"RK-1_인체공학_그립": {
		"name": "RK-1 고급 앵글 포어그립",
		"slot": "grip",
		"compatible_categories": ["rifle", "smg", "sniper"],
		"stat_modifiers": {"recoil": -22, "accuracy": +10, "ads_speed": +8},
		"tier": "expensive", "value": 14000
	},

	# --- 레일 부착물 (Rail - 복수 장착 가능!) ---
	"전술_손전등": {
		"name": "무기 장착형 고광량 손전등",
		"slot": "rail",
		"compatible_categories": ["all"],
		"stat_modifiers": {"flashlight_boost": true},
		"tier": "cheap", "value": 5000
	},
	"적색_레이저_표적지시기": {
		"name": "적색 레이저 사이트 (지향사격 정확도 대폭 향상)",
		"slot": "rail",
		"compatible_categories": ["all"],
		"stat_modifiers": {"accuracy": +12, "laser_sight": true},
		"tier": "mid", "value": 11000
	}
}

# ============================================================
# 4. 스탯 계산 엔진 (Compute Stats)
# ============================================================
static func compute_weapon_from_dict(weapon_dict: Dictionary) -> Dictionary:
	var rec_id = weapon_dict.get("receiver", weapon_dict.get("id", "M9_리시버"))
	var parts = weapon_dict.get("parts", weapon_dict.get("attachments", {}))
	var ammo = weapon_dict.get("loaded_ammo", "")
	var stats = compute_weapon_stats(rec_id, parts, ammo)
	var res = weapon_dict.duplicate(true)
	res["computed_stats"] = stats
	return res

static func compute_weapon_stats(receiver_id: String, parts: Dictionary = {}, loaded_ammo: String = "") -> Dictionary:
	var receiver = RECEIVERS.get(receiver_id, RECEIVERS.get("M9_리시버", {}))
	if receiver.is_empty():
		receiver = RECEIVERS["M9_리시버"]
		
	var ammo_id = loaded_ammo if loaded_ammo != "" else receiver.get("default_ammo", "9mm")
	var ammo_data = AMMO_TYPES.get(ammo_id, AMMO_TYPES["9mm"])
	
	var stats = {
		"damage": receiver["base_damage"],
		"range": receiver["base_range"],
		"rpm": receiver["base_rpm"],
		"recoil": receiver["base_recoil"],
		"accuracy": receiver["base_accuracy"],
		"zoom": 1.0,
		"magazine_size": 10,
		"reload_speed": 1.8,
		"noise_radius": 600.0,
		"weight": receiver["weight"],
		"ads_speed": 0,
		"muzzle_flash": true,
		"flashlight_boost": false,
		"laser_sight": false,
		"pellets": ammo_data.get("pellets", 1),
		"penetration": ammo_data.get("penetration", 10),
		"ammo_type": ammo_id,
		"ammo_types": receiver.get("ammo_types", [ammo_id])
	}
	
	# 부품 보정치 누적
	for slot_key in parts.keys():
		var val = parts[slot_key]
		if val is Array:
			# rail 등 다중 부품 슬롯
			for p_id in val:
				_apply_part_modifier(stats, p_id)
		elif val is String and val != "":
			_apply_part_modifier(stats, val)
			
	# 탄종 계수 곱연산
	stats["damage"] *= ammo_data["damage_mult"]
	stats["recoil"] *= ammo_data["recoil_mult"]
	stats["noise_radius"] *= ammo_data["noise_mult"]
	
	# 안전 클램핑
	stats["recoil"] = max(5.0, stats["recoil"])
	stats["accuracy"] = clamp(stats["accuracy"], 15.0, 99.0)
	stats["range"] = max(3.0, stats["range"])
	
	return stats

static func _apply_part_modifier(stats: Dictionary, part_id: String) -> void:
	if not PARTS.has(part_id): return
	var p = PARTS[part_id]
	var mods = p.get("stat_modifiers", {})
	
	for k in mods.keys():
		var mod_val = mods[k]
		if typeof(mod_val) == TYPE_BOOL:
			stats[k] = mod_val
		elif typeof(mod_val) == TYPE_FLOAT or typeof(mod_val) == TYPE_INT:
			if k == "zoom":
				stats["zoom"] = max(stats["zoom"], float(mod_val))
			elif k == "magazine_size" or k == "reload_speed":
				stats[k] = mod_val
			else:
				stats[k] += mod_val
				
	stats["weight"] += p.get("weight", 0.1)

static func create_default_weapon(receiver_id: String) -> Dictionary:
	var receiver = RECEIVERS.get(receiver_id, RECEIVERS["M9_리시버"])
	var parts: Dictionary = {}
	var def_ammo = receiver.get("default_ammo", "9mm")
	
	match receiver_id:
		"M9_리시버":
			parts = {
				"barrel": "짧은_총열",
				"optic": "기본_아이언사이트",
				"magazine": "표준_탄창",
				"rail": []
			}
		"AK_리시버":
			parts = {
				"barrel": "정밀_롱헤비_총열",
				"optic": "레드닷_사이트",
				"stock": "경량_접이식_스톡",
				"grip": "수직_포어그립",
				"magazine": "대용량_확장_탄창",
				"rail": ["적색_레이저_표적지시기"]
			}
		"M4_리시버":
			parts = {
				"barrel": "정밀_롱헤비_총열",
				"muzzle": "소음기",
				"optic": "4배율_ACOG",
				"stock": "PRS_정밀_저격_스톡",
				"grip": "RK-1_인체공학_그립",
				"magazine": "대용량_확장_탄창",
				"rail": ["전술_손전등", "적색_레이저_표적지시기"]
			}
		"레밍턴_리시버":
			parts = {
				"barrel": "짧은_총열",
				"optic": "기본_아이언사이트",
				"stock": "경량_접이식_스톡",
				"rail": []
			}
		"SV98_리시버":
			parts = {
				"barrel": "정밀_롱헤비_총열",
				"muzzle": "소음기",
				"optic": "8배율_스나이퍼_스코프",
				"stock": "PRS_정밀_저격_스톡",
				"magazine": "표준_탄창",
				"rail": []
			}
		"레버액션_리시버", "레버액션 소총":
			parts = {
				"barrel": "정밀_롱헤비_총열",
				"optic": "2배율_조준경",
				"stock": "PRS_정밀_저격_스톡",
				"rail": []
			}
			
	var stats = compute_weapon_stats(receiver_id, parts, def_ammo)
	return {
		"id": receiver_id,
		"type": "assembled_weapon",
		"name": receiver["name"],
		"receiver": receiver_id,
		"loaded_ammo": def_ammo,
		"current_magazine_ammo": stats["magazine_size"],
		"parts": parts,
		"computed_stats": stats,
		"durability": 100
	}
