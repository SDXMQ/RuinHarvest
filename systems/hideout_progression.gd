# res://systems/hideout_progression.gd
class_name HideoutProgression
extends RefCounted

## 은신처 시설 업그레이드 및 상인 의뢰(퀘스트) 관리 모듈

const FACILITIES: Dictionary = {
	"stash_expansion": {
		"name": "보관함 확장 설비",
		"icon": "stash",
		"desc": "창고 그리드 세로 공간을 레벨당 +4줄 확장합니다. (기본 10x12 -> 최대 10x24)",
		"max_level": 3,
		"levels": [
			{"rubles": 4000, "items": {"나무": 2, "못": 2}, "bonus_rows": 4},
			{"rubles": 9000, "items": {"나무": 3, "고철": 2, "못": 3}, "bonus_rows": 8},
			{"rubles": 18000, "items": {"고철": 4, "기계 부품": 2}, "bonus_rows": 12}
		]
	},
	"med_station": {
		"name": "응급 의료 스테이션",
		"icon": "hospital",
		"desc": "출격 시 최대 체력(Max HP) 보너스를 부여하고 복귀 시 부상을 완화합니다.",
		"max_level": 3,
		"levels": [
			{"rubles": 3500, "items": {"붕대": 2, "생수": 1}, "bonus_hp": 15.0},
			{"rubles": 8000, "items": {"구급상자": 1, "약초": 2, "진통제": 1}, "bonus_hp": 30.0},
			{"rubles": 16000, "items": {"고급 치료킷": 1, "구급상자": 2}, "bonus_hp": 50.0}
		]
	},
	"bitcoin_farm": {
		"name": "발전기 & 채굴 서버렉",
		"icon": "power",
		"desc": "레이드에서 생존 복귀할 때마다 고정 패시브 수익(RUB)을 창출합니다.",
		"max_level": 3,
		"levels": [
			{"rubles": 5000, "items": {"폐전선": 2, "비상용 배터리": 1}, "income": 1500},
			{"rubles": 12000, "items": {"기계 부품": 2, "CPU": 1}, "income": 3500},
			{"rubles": 25000, "items": {"그래픽카드": 1, "CPU": 1}, "income": 7500}
		]
	},
	"intel_center": {
		"name": "통신 & 거래소 인텔 센터",
		"icon": "signal",
		"desc": "상인 구매 가격을 할인받고 아이템 매각 단가 비율을 높입니다.",
		"max_level": 3,
		"levels": [
			{"rubles": 4500, "items": {"라디오 부품": 1, "폐전선": 1}, "discount": 0.05, "sell_bonus": 0.06},
			{"rubles": 10000, "items": {"장거리 무전기": 1, "라디오 부품": 2}, "discount": 0.10, "sell_bonus": 0.12},
			{"rubles": 22000, "items": {"암호화된 SSD": 1, "장거리 무전기": 1}, "discount": 0.15, "sell_bonus": 0.20}
		]
	}
}

const QUESTS: Array = [
	{
		"id": "q_therapist_1",
		"trader": "테라피스트",
		"title": "[의뢰 1] 응급 의료 물자 확보",
		"desc": "생존자 치료를 위해 붕대 2개와 생수 1병을 창고나 가방에서 납품하십시오.",
		"req_items": {"붕대": 2, "생수": 1},
		"req_kills": 0,
		"req_human_kills": 0,
		"reward_rubles": 4500,
		"reward_items": [{"id": "구급상자", "amount": 2}, {"id": "진통제", "amount": 1}]
	},
	{
		"id": "q_prapor_1",
		"trader": "프라포",
		"title": "[의뢰 2] 폐허 정찰 및 감염체 토벌",
		"desc": "레이드에서 적(좀비 또는 약탈자)을 누적 5명 이상 처치하십시오.",
		"req_items": {},
		"req_kills": 5,
		"req_human_kills": 0,
		"reward_rubles": 6500,
		"reward_items": [{"id": "AK_리시버", "amount": 1}, {"id": "7.62mm", "amount": 60}]
	},
	{
		"id": "q_fence_1",
		"trader": "펜스",
		"title": "[의뢰 3] 은신처 보수용 고철 수거",
		"desc": "고철 2개와 폐전선 1개를 찾아 납품하십시오.",
		"req_items": {"고철": 2, "폐전선": 1},
		"req_kills": 0,
		"req_human_kills": 0,
		"reward_rubles": 6000,
		"reward_items": [{"id": "2레벨_가방", "amount": 1}, {"id": "수류탄", "amount": 2}]
	},
	{
		"id": "q_prapor_2",
		"trader": "프라포",
		"title": "[의뢰 4] 무장 스캐브 소탕 작전",
		"desc": "총기로 무장한 인간형 적(스캐브/레이더)을 누적 3명 이상 처치하십시오.",
		"req_items": {},
		"req_kills": 0,
		"req_human_kills": 3,
		"reward_rubles": 11000,
		"reward_items": [{"id": "2레벨_방탄복", "amount": 1}, {"id": "5.56mm", "amount": 60}]
	},
	{
		"id": "q_therapist_2",
		"trader": "테라피스트",
		"title": "[의뢰 5] 중증 외상 수술 키트 조달",
		"desc": "구급상자 1개와 진통제 2개를 조달하여 납품하십시오.",
		"req_items": {"구급상자": 1, "진통제": 2},
		"req_kills": 0,
		"req_human_kills": 0,
		"reward_rubles": 14000,
		"reward_items": [{"id": "고급 치료킷", "amount": 2}, {"id": "2레벨_헬멧", "amount": 1}]
	},
	{
		"id": "q_fence_2",
		"trader": "펜스",
		"title": "[의뢰 6] 기밀 전자부품 회수",
		"desc": "CPU 1개 또는 암호화된 SSD 1개를 확보하여 CPU 1개를 납품하십시오.",
		"req_items": {"CPU": 1},
		"req_kills": 0,
		"req_human_kills": 0,
		"reward_rubles": 24000,
		"reward_items": [{"id": "SV98_리시버", "amount": 1}, {"id": "3레벨_방탄복", "amount": 1}]
	},
	{
		"id": "q_field_terminal_1",
		"trader": "펜스",
		"title": "[의뢰 7] 랜드마크 기밀 단말기 해킹 작전",
		"desc": "레이드 현장의 랜드마크 단말기에서 [E] 키를 3.0초간 홀드해 신호를 송출하고 암호화된 SSD를 회수하십시오.",
		"req_items": {"암호화된 SSD": 1},
		"req_kills": 0,
		"req_human_kills": 0,
		"req_field_objectives": 1,
		"reward_rubles": 15000,
		"reward_items": [{"id": "M4_리시버", "amount": 1}, {"id": "3레벨_헬멧", "amount": 1}]
	}
]

static func get_facility_level(world_data: Dictionary, fac_id: String) -> int:
	return int(world_data.get("hideout", {}).get("upgrades", {}).get(fac_id, 0))

static func get_stash_grid_height(world_data: Dictionary) -> int:
	var lv = get_facility_level(world_data, "stash_expansion")
	if lv <= 0: return 12
	var levels = FACILITIES["stash_expansion"]["levels"]
	return 12 + int(levels[min(lv - 1, levels.size() - 1)]["bonus_rows"])

static func get_bonus_max_hp(world_data: Dictionary) -> float:
	var lv = get_facility_level(world_data, "med_station")
	if lv <= 0: return 0.0
	var levels = FACILITIES["med_station"]["levels"]
	return float(levels[min(lv - 1, levels.size() - 1)]["bonus_hp"])

static func get_passive_raid_income(world_data: Dictionary) -> int:
	var lv = get_facility_level(world_data, "bitcoin_farm")
	if lv <= 0: return 0
	var levels = FACILITIES["bitcoin_farm"]["levels"]
	return int(levels[min(lv - 1, levels.size() - 1)]["income"])

static func get_trader_discount(world_data: Dictionary) -> float:
	var lv = get_facility_level(world_data, "intel_center")
	if lv <= 0: return 0.0
	var levels = FACILITIES["intel_center"]["levels"]
	return float(levels[min(lv - 1, levels.size() - 1)]["discount"])

static func get_trader_sell_ratio(world_data: Dictionary) -> float:
	var lv = get_facility_level(world_data, "intel_center")
	if lv <= 0: return 0.60
	var levels = FACILITIES["intel_center"]["levels"]
	return 0.60 + float(levels[min(lv - 1, levels.size() - 1)]["sell_bonus"])

static func get_trader_sell_bonus_only(world_data: Dictionary) -> float:
	var lv := get_facility_level(world_data, "intel_center")
	if lv <= 0:
		return 0.0
	var levels: Array = FACILITIES["intel_center"]["levels"]
	return float(levels[mini(lv - 1, levels.size() - 1)].get("sell_bonus", 0.0))

const TRADER_QUEST_NAMES: Dictionary = {
	"prapor": "프라포",
	"therapist": "테라피스트",
	"fence": "펜스"
}

const TRADER_LOYALTY_THRESHOLDS: Dictionary = {
	"prapor": [
		{"level": 1, "quests": 0, "spent": 0},
		{"level": 2, "quests": 1, "spent": 15000},
		{"level": 3, "quests": 2, "spent": 45000},
		{"level": 4, "quests": 2, "spent": 90000}
	],
	"therapist": [
		{"level": 1, "quests": 0, "spent": 0},
		{"level": 2, "quests": 1, "spent": 15000},
		{"level": 3, "quests": 2, "spent": 45000},
		{"level": 4, "quests": 2, "spent": 90000}
	],
	"fence": [
		{"level": 1, "quests": 0, "spent": 0},
		{"level": 2, "quests": 1, "spent": 15000},
		{"level": 3, "quests": 2, "spent": 45000},
		{"level": 4, "quests": 3, "spent": 90000}
	]
}

static func get_trader_base_sell_ratio(trader_id: String, item_id: String) -> float:
	var resolved := ItemDatabase.resolve_item_id(item_id) if (ItemDatabase and ItemDatabase.has_method("resolve_item_id")) else item_id
	var data: Dictionary = ItemDatabase.get_item_data(resolved) if ItemDatabase else {}
	var cat := int(data.get("category", -1))
	var itype := str(data.get("type", ""))
	if trader_id == "therapist":
		if cat in [ItemDatabase.ItemCategory.MEDICAL, ItemDatabase.ItemCategory.FOOD, ItemDatabase.ItemCategory.WATER]:
			return 0.75
		return 0.50
	elif trader_id == "prapor":
		var is_ammo := (itype == "ammo") or (ItemDatabase and ItemDatabase.is_ammo_item(resolved)) or (WeaponPartsDatabase and WeaponPartsDatabase.AMMO_TYPES.has(resolved))
		var is_part_or_rec := (itype in ["receiver", "assembled_weapon", "part"]) or (WeaponPartsDatabase and (WeaponPartsDatabase.PARTS.has(resolved) or WeaponPartsDatabase.RECEIVERS.has(resolved)))
		if cat in [ItemDatabase.ItemCategory.WEAPON, ItemDatabase.ItemCategory.EQUIPMENT] or is_ammo or is_part_or_rec:
			return 0.70
		return 0.48
	return 0.55

static func get_item_base_intrinsic_value(item: Dictionary) -> int:
	if item.is_empty():
		return 0
	var item_id := str(item.get("id", ""))
	var resolved := ItemDatabase.resolve_item_id(item_id) if (ItemDatabase and ItemDatabase.has_method("resolve_item_id")) else item_id
	var data: Dictionary = ItemDatabase.get_item_data(resolved) if ItemDatabase else {}
	var base_val := maxi(1, int(data.get("value", 500)))
	var inner = item.get("inner_items", [])
	if inner is Array and not inner.is_empty():
		for sub in inner:
			if sub is Dictionary and not sub.is_empty():
				var sub_amt := maxi(1, int(sub.get("amount", 1)))
				base_val += get_item_base_intrinsic_value(sub) * sub_amt
	return base_val

static func get_item_sell_unit_price(trader_id: String, item: Dictionary, world_data: Dictionary = {}, extra_pressure: float = 0.0, include_intel_bonus: bool = true) -> int:
	if item.is_empty():
		return 0
	var item_id := str(item.get("id", ""))
	var base_val := get_item_base_intrinsic_value(item)
	var base_ratio := get_trader_base_sell_ratio(trader_id, item_id)
	var intel_bon := get_trader_sell_bonus_only(world_data) if (include_intel_bonus and not world_data.is_empty()) else 0.0
	var eff_ratio := minf(0.95, base_ratio + intel_bon)
	var elasticity := FleaMarket.get_supply_elasticity_multiplier(item_id, extra_pressure) if FleaMarket else 1.0
	return maxi(1, int(round(float(base_val) * eff_ratio * elasticity)))

static func get_trader_completed_quest_count(world_data: Dictionary, trader_id: String) -> int:
	var target_name := String(TRADER_QUEST_NAMES.get(trader_id, ""))
	if target_name == "":
		return 0
	var completed: Array = world_data.get("hideout", {}).get("completed_quests", [])
	var count := 0
	for q in QUESTS:
		if String(q.get("trader", "")) == target_name and (String(q.get("id", "")) in completed):
			count += 1
	return count

static func get_trader_spent_rubles(world_data: Dictionary, trader_id: String) -> int:
	var stats = world_data.get("hideout", {}).get("trader_stats", {})
	if not (stats is Dictionary):
		return 0
	var entry = stats.get(trader_id, {})
	if not (entry is Dictionary):
		return 0
	return int(entry.get("spent_rubles", 0))

static func record_trader_transaction(world_data: Dictionary, trader_id: String, rubles_amount: int) -> void:
	if rubles_amount <= 0 or trader_id == "":
		return
	if not world_data.has("hideout") or not (world_data["hideout"] is Dictionary):
		world_data["hideout"] = {"stash": [], "upgrades": {}, "completed_quests": []}
	if not (world_data["hideout"].get("trader_stats") is Dictionary):
		world_data["hideout"]["trader_stats"] = {}
	if not (world_data["hideout"]["trader_stats"].get(trader_id) is Dictionary):
		world_data["hideout"]["trader_stats"][trader_id] = {"spent_rubles": 0}
	world_data["hideout"]["trader_stats"][trader_id]["spent_rubles"] = int(world_data["hideout"]["trader_stats"][trader_id].get("spent_rubles", 0)) + rubles_amount

static func get_trader_loyalty_level(world_data: Dictionary, trader_id: String) -> int:
	var q_cnt := get_trader_completed_quest_count(world_data, trader_id)
	var spent := get_trader_spent_rubles(world_data, trader_id)
	var tiers: Array = TRADER_LOYALTY_THRESHOLDS.get(trader_id, TRADER_LOYALTY_THRESHOLDS["prapor"])
	var lv := 1
	for t in tiers:
		if q_cnt >= int(t.get("quests", 0)) and spent >= int(t.get("spent", 0)):
			lv = maxi(lv, int(t.get("level", 1)))
	return lv

static func get_trader_loyalty_info(world_data: Dictionary, trader_id: String) -> Dictionary:
	var cur_lv := get_trader_loyalty_level(world_data, trader_id)
	var q_cnt := get_trader_completed_quest_count(world_data, trader_id)
	var spent := get_trader_spent_rubles(world_data, trader_id)
	var tiers: Array = TRADER_LOYALTY_THRESHOLDS.get(trader_id, TRADER_LOYALTY_THRESHOLDS["prapor"])
	var next_req: Dictionary = {}
	if cur_lv < 4 and cur_lv < tiers.size():
		next_req = tiers[cur_lv]
	return {
		"trader_id": trader_id,
		"level": cur_lv,
		"max_level": 4,
		"quests": q_cnt,
		"spent": spent,
		"next_quests": int(next_req.get("quests", q_cnt)),
		"next_spent": int(next_req.get("spent", spent))
	}

static func is_trader_item_unlocked(world_data: Dictionary, trader_id: String, stock_entry: Dictionary) -> bool:
	var req_lv := maxi(1, int(stock_entry.get("min_level", 1)))
	return get_trader_loyalty_level(world_data, trader_id) >= req_lv

static func get_wishlist_needed_items(world_data: Dictionary, _player_grid: InventoryGrid = null, _stash_grid: InventoryGrid = null) -> Dictionary:
	var needed: Dictionary = {}
	var completed: Array = world_data.get("hideout", {}).get("completed_quests", [])
	# 1. 은신처 다음 단계 시설 업그레이드 요구 재료
	for fac_id in FACILITIES.keys():
		var f_data: Dictionary = FACILITIES[fac_id]
		var cur_lv := get_facility_level(world_data, fac_id)
		var max_lv := int(f_data.get("max_level", 0))
		if cur_lv < max_lv:
			var next_req: Dictionary = f_data["levels"][cur_lv].get("items", {})
			for it_id in next_req.keys():
				var resolved := ItemDatabase.resolve_item_id(String(it_id)) if (ItemDatabase and ItemDatabase.has_method("resolve_item_id")) else String(it_id)
				if not needed.has(resolved):
					needed[resolved] = {"amount": 0, "sources": []}
				needed[resolved]["amount"] += int(next_req[it_id])
				needed[resolved]["sources"].append("%s Lv.%d" % [String(f_data.get("name", fac_id)), cur_lv + 1])
	# 2. 진행 중(미완료) 상인 의뢰 요구 재료
	for q in QUESTS:
		var q_id := String(q.get("id", ""))
		if q_id in completed:
			continue
		var req_items: Dictionary = q.get("req_items", {})
		for it_id in req_items.keys():
			var resolved := ItemDatabase.resolve_item_id(String(it_id)) if (ItemDatabase and ItemDatabase.has_method("resolve_item_id")) else String(it_id)
			if not needed.has(resolved):
				needed[resolved] = {"amount": 0, "sources": []}
			needed[resolved]["amount"] += int(req_items[it_id])
			needed[resolved]["sources"].append(String(q.get("title", q_id)))
	return needed

static func is_wishlist_item(item_id: String, world_data: Dictionary = {}, _player_grid: InventoryGrid = null, _stash_grid: InventoryGrid = null) -> bool:
	if item_id == "":
		return false
	var w_data: Dictionary = world_data
	if w_data.is_empty() and GameManager and GameManager.current_world_data is Dictionary:
		w_data = GameManager.current_world_data
	if w_data.is_empty():
		return false
	var resolved := ItemDatabase.resolve_item_id(item_id) if (ItemDatabase and ItemDatabase.has_method("resolve_item_id")) else item_id
	var needed := get_wishlist_needed_items(w_data)
	return needed.has(resolved) or needed.has(item_id)

static func _resolve_bulk_entry_item(entry: Dictionary, player_grid: InventoryGrid, stash_grid: InventoryGrid) -> Dictionary:
	var uid := str(entry.get("uid", ""))
	var src_grid: InventoryGrid = entry.get("source_grid") as InventoryGrid
	if src_grid == null:
		src_grid = stash_grid if bool(entry.get("is_stash", false)) else player_grid
	var item: Dictionary = {}
	if src_grid != null and uid != "":
		item = src_grid.get_item_by_uid(uid)
	if item.is_empty() and entry.get("item") is Dictionary:
		item = entry["item"]
	return {"uid": uid, "grid": src_grid, "item": item}

static func preview_bulk_sell_receipt(trader_id: String, selected_entries: Array, world_data: Dictionary = {}, player_grid: InventoryGrid = null, stash_grid: InventoryGrid = null) -> Dictionary:
	var sim_pressure: Dictionary = {}
	var line_items: Array[Dictionary] = []
	var total_base_rubles := 0
	var total_final_rubles := 0
	var valid_count := 0
	var total_units := 0
	for raw_entry in selected_entries:
		if not (raw_entry is Dictionary):
			continue
		var res := _resolve_bulk_entry_item(raw_entry, player_grid, stash_grid)
		var item: Dictionary = res["item"]
		var grid: InventoryGrid = res["grid"]
		if item.is_empty():
			continue
		if bool(item.get("locked", false)):
			continue
		if grid != null and grid.is_item_in_secure_zone(item):
			continue
		var item_id := str(item.get("id", ""))
		var resolved := ItemDatabase.resolve_item_id(item_id) if (ItemDatabase and ItemDatabase.has_method("resolve_item_id")) else item_id
		var amt := maxi(1, int(item.get("amount", 1)))
		var prev_extra := float(sim_pressure.get(resolved, 0.0))
		var step := FleaMarket.get_pressure_step_for_amount(resolved, amt) if FleaMarket else 0.0
		var avg_extra := prev_extra + (step * 0.5 * float(amt - 1) / float(amt) if amt > 1 else 0.0)
		sim_pressure[resolved] = prev_extra + step

		var base_unit_p := get_item_sell_unit_price(trader_id, item, world_data, 0.0)
		var final_unit_p := get_item_sell_unit_price(trader_id, item, world_data, avg_extra)
		var line_base := base_unit_p * amt
		var line_final := final_unit_p * amt
		total_base_rubles += line_base
		total_final_rubles += line_final
		valid_count += 1
		total_units += amt
		line_items.append({
			"uid": str(item.get("uid", "")),
			"id": resolved,
			"amount": amt,
			"base_total": line_base,
			"final_total": line_final,
			"drop_amount": maxi(0, line_base - line_final)
		})
	var loss_rubles := maxi(0, total_base_rubles - total_final_rubles)
	var loss_pct := (float(loss_rubles) / float(total_base_rubles) * 100.0) if total_base_rubles > 0 else 0.0
	return {
		"valid_count": valid_count,
		"total_units": total_units,
		"total_base_rubles": total_base_rubles,
		"total_final_rubles": total_final_rubles,
		"elasticity_loss_rubles": loss_rubles,
		"elasticity_loss_pct": loss_pct,
		"line_items": line_items
	}

static func execute_bulk_sell(trader_id: String, selected_entries: Array, world_data: Dictionary, player_grid: InventoryGrid, stash_grid: InventoryGrid) -> Dictionary:
	var total_earned := 0
	var sold_count := 0
	var skipped_protected := 0
	var touched_grids: Array[InventoryGrid] = []
	for raw_entry in selected_entries:
		if not (raw_entry is Dictionary):
			continue
		var res := _resolve_bulk_entry_item(raw_entry, player_grid, stash_grid)
		var item: Dictionary = res["item"]
		var grid: InventoryGrid = res["grid"]
		var uid: String = res["uid"]
		if item.is_empty() or grid == null:
			continue
		if bool(item.get("locked", false)) or grid.is_item_in_secure_zone(item):
			skipped_protected += 1
			continue
		var item_id := str(item.get("id", ""))
		var amt := maxi(1, int(item.get("amount", 1)))
		var step := FleaMarket.get_pressure_step_for_amount(item_id, amt) if FleaMarket else 0.0
		var avg_extra := (step * 0.5 * float(amt - 1) / float(amt)) if amt > 1 else 0.0
		var unit_price := get_item_sell_unit_price(trader_id, item, world_data, avg_extra)
		var gain := unit_price * amt
		var removed := grid.remove_item_by_uid(uid, false)
		if not removed.is_empty():
			total_earned += gain
			sold_count += 1
			if not (grid in touched_grids):
				touched_grids.append(grid)
			if FleaMarket:
				FleaMarket.record_player_sale(item_id, amt)
	for g in touched_grids:
		g.grid_changed.emit()
	if total_earned > 0:
		if not world_data.has("player") or not (world_data["player"] is Dictionary):
			world_data["player"] = {}
		world_data["player"]["rubles"] = int(world_data["player"].get("rubles", 0)) + total_earned
		record_trader_transaction(world_data, trader_id, total_earned)
	return {
		"success": sold_count > 0,
		"sold_count": sold_count,
		"earned": total_earned,
		"skipped_protected": skipped_protected
	}

static func collect_bulk_sell_candidates(mode: String, player_grid: InventoryGrid, stash_grid: InventoryGrid) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var sources := [
		{"grid": player_grid, "is_stash": false},
		{"grid": stash_grid, "is_stash": true}
	]
	for src in sources:
		var mgr: InventoryGrid = src["grid"]
		var is_stash: bool = src["is_stash"]
		if mgr == null:
			continue
		for item in mgr.items:
			if item.is_empty():
				continue
			if bool(item.get("locked", false)):
				continue
			if mgr.is_item_in_secure_zone(item):
				continue
			var inner = item.get("inner_items", [])
			if inner is Array and not inner.is_empty():
				continue
			var item_id := str(item.get("id", ""))
			var data: Dictionary = ItemDatabase.get_item_data(item_id) if ItemDatabase else {}
			var cat := int(data.get("category", -1))
			var itype := str(data.get("type", item.get("type", "")))
			var include_item := false
			if mode == "valuables":
				include_item = (cat == ItemDatabase.ItemCategory.MISC or cat == ItemDatabase.ItemCategory.MATERIAL)
			elif mode == "non_gear":
				var is_gear_or_weapon := (
					cat == ItemDatabase.ItemCategory.WEAPON
					or cat == ItemDatabase.ItemCategory.EQUIPMENT
					or itype in ["receiver", "assembled_weapon", "storage_case", "key", "keycard", "ammo"]
					or (ItemDatabase and ItemDatabase.is_ammo_item(item_id))
				)
				include_item = not is_gear_or_weapon
			if include_item:
				results.append({
					"uid": str(item.get("uid", "")),
					"is_stash": is_stash,
					"source_grid": mgr
				})
	return results

static func count_total_item(item_id: String, player_grid: InventoryGrid, stash_grid: InventoryGrid) -> int:
	var c = 0
	if player_grid: c += player_grid.get_item_count(item_id)
	if stash_grid: c += stash_grid.get_item_count(item_id)
	return c

static func consume_total_item(item_id: String, amount: int, player_grid: InventoryGrid, stash_grid: InventoryGrid) -> void:
	var rem = amount
	if stash_grid:
		rem = stash_grid.remove_item(item_id, rem)
	if rem > 0 and player_grid:
		player_grid.remove_item(item_id, rem)

static func setup_progression_tab(_hideout: Control, tab_container: TabContainer) -> Control:
	var tab_root = HBoxContainer.new()
	tab_root.name = " 시설 & 의뢰 "
	tab_root.add_theme_constant_override("separation", 18)
	tab_container.add_child(tab_root)
	if UiIconManager:
		UiIconManager.set_tab_icon_by_control(tab_container, tab_root, "facility")
	
	# 좌측: 은신처 시설 업그레이드
	var fac_panel = PanelContainer.new()
	fac_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fac_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var fac_vbox_outer = VBoxContainer.new()
	fac_vbox_outer.add_theme_constant_override("separation", 10)
	fac_panel.add_child(fac_vbox_outer)
	
	var fac_title = Label.new()
	fac_title.text = "은신처 핵심 시설 업그레이드 (Facilities)"
	fac_title.add_theme_font_size_override("font_size", 16)
	fac_title.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	fac_vbox_outer.add_child(fac_title)
	if UiIconManager:
		UiIconManager.set_label_icon(fac_title, "facility", "", 18, 6)
	
	var fac_scroll = ScrollContainer.new()
	fac_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var fac_list = VBoxContainer.new()
	fac_list.name = "FacilitiesList"
	fac_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fac_list.add_theme_constant_override("separation", 10)
	fac_scroll.add_child(fac_list)
	fac_vbox_outer.add_child(fac_scroll)
	tab_root.add_child(fac_panel)
	
	# 우측: 상인 특별 의뢰 (퀘스트)
	var q_panel = PanelContainer.new()
	q_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var q_vbox_outer = VBoxContainer.new()
	q_vbox_outer.add_theme_constant_override("separation", 10)
	q_panel.add_child(q_vbox_outer)
	
	var q_title = Label.new()
	q_title.text = "상인 계약 의뢰 & 임무 (Trader Quests)"
	q_title.add_theme_font_size_override("font_size", 16)
	q_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	q_vbox_outer.add_child(q_title)
	if UiIconManager:
		UiIconManager.set_label_icon(q_title, "clipboard", "", 18, 6)
	
	var q_scroll = ScrollContainer.new()
	q_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var q_list = VBoxContainer.new()
	q_list.name = "QuestsList"
	q_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_list.add_theme_constant_override("separation", 10)
	q_scroll.add_child(q_list)
	q_vbox_outer.add_child(q_scroll)
	tab_root.add_child(q_panel)
	
	return tab_root

static func refresh_progression_tab(hideout: Control, tab_root: Control) -> void:
	if not tab_root or not GameManager: return
	var fac_list: VBoxContainer = tab_root.find_child("FacilitiesList", true, false)
	var q_list: VBoxContainer = tab_root.find_child("QuestsList", true, false)
	if not fac_list or not q_list: return
	
	for c in fac_list.get_children(): c.queue_free()
	for c in q_list.get_children(): c.queue_free()
	
	var w_data = GameManager.current_world_data
	if not w_data.has("player"): w_data["player"] = {}
	if not w_data.has("hideout"): w_data["hideout"] = {"stash": [], "upgrades": {}, "completed_quests": []}
	if not w_data["hideout"].has("upgrades"): w_data["hideout"]["upgrades"] = {}
	if not w_data["hideout"].has("completed_quests"): w_data["hideout"]["completed_quests"] = []
	
	var rubles = int(w_data["player"].get("rubles", 0))
	var p_grid: InventoryGrid = hideout.get("player_grid_mgr")
	var s_grid: InventoryGrid = hideout.get("stash_grid_mgr")
	
	# 1. 시설 목록 렌더링
	for fac_id in FACILITIES.keys():
		var f_data = FACILITIES[fac_id]
		var cur_lv = get_facility_level(w_data, fac_id)
		var max_lv = int(f_data["max_level"])
		
		var card = PanelContainer.new()
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)
		
		var header = Label.new()
		header.text = "%s  [Lv.%d / %d]" % [f_data["name"], cur_lv, max_lv]
		header.add_theme_font_size_override("font_size", 14)
		header.add_theme_color_override("font_color", Color(0.5, 0.95, 0.6) if cur_lv > 0 else Color(0.9, 0.9, 0.95))
		vbox.add_child(header)
		if UiIconManager:
			UiIconManager.set_label_icon(header, String(f_data.get("icon", "facility")), "", 16, 6)
		
		var desc = Label.new()
		desc.text = f_data["desc"]
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
		vbox.add_child(desc)
		
		if cur_lv < max_lv:
			var next_req = f_data["levels"][cur_lv]
			var req_rub = int(next_req["rubles"])
			var req_items: Dictionary = next_req["items"]
			var can_upgrade = (rubles >= req_rub)
			var req_parts = ["%d RUB" % req_rub]
			
			for it_id in req_items.keys():
				var need_c = int(req_items[it_id])
				var have_c = count_total_item(it_id, p_grid, s_grid)
				if have_c < need_c: can_upgrade = false
				req_parts.append("%s (%d/%d)" % [it_id, have_c, need_c])
				
			var req_lbl = Label.new()
			req_lbl.text = "필요 조건: " + ", ".join(req_parts)
			req_lbl.add_theme_font_size_override("font_size", 11)
			req_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5) if can_upgrade else Color(1.0, 0.55, 0.45))
			vbox.add_child(req_lbl)
			
			var up_btn = Button.new()
			if UiIconManager:
				UiIconManager.set_button(up_btn, "upgrade", "Lv.%d 업그레이드 시공" % (cur_lv + 1), 15)
			else:
				up_btn.text = "Lv.%d 업그레이드 시공" % (cur_lv + 1)
			up_btn.disabled = not can_upgrade
			var fid_cap = fac_id
			up_btn.pressed.connect(func():
				w_data["player"]["rubles"] = int(w_data["player"].get("rubles", 0)) - req_rub
				for it_id in req_items.keys():
					consume_total_item(it_id, int(req_items[it_id]), p_grid, s_grid)
				w_data["hideout"]["upgrades"][fid_cap] = cur_lv + 1
				if SoundManager: SoundManager.play("menu_select")
				if hideout.has_method("_apply_stash_upgrade_size"):
					hideout._apply_stash_upgrade_size()
				if hideout.has_method("_update_money_label"):
					hideout._update_money_label()
				if hideout.has_method("_on_grid_changed"):
					hideout._on_grid_changed()
				refresh_progression_tab(hideout, tab_root)
			)
			vbox.add_child(up_btn)
		else:
			var max_lbl = Label.new()
			max_lbl.text = "최고 단계 업그레이드 완료 (MAX)"
			max_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			vbox.add_child(max_lbl)
			if UiIconManager:
				UiIconManager.set_label_icon(max_lbl, "star", "", 15, 5)
			
		fac_list.add_child(card)
		
	# 2. 퀘스트 목록 렌더링
	var completed_list: Array = w_data["hideout"]["completed_quests"]
	var total_kills = int(w_data["player"].get("kills_total", 0))
	var human_kills = int(w_data["player"].get("human_kills", 0))
	
	for q in QUESTS:
		var q_id = q["id"]
		var is_done = q_id in completed_list
		
		var card = PanelContainer.new()
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)
		
		var header = Label.new()
		header.text = "[%s] %s%s" % [q["trader"], q["title"], " (완료)" if is_done else ""]
		header.add_theme_font_size_override("font_size", 14)
		header.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5) if is_done else Color(1.0, 0.88, 0.4))
		vbox.add_child(header)
		if UiIconManager:
			UiIconManager.set_label_icon(header, "ok" if is_done else "clipboard", "", 15, 5)
		
		var desc = Label.new()
		desc.text = q["desc"]
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", Color(0.78, 0.8, 0.86))
		vbox.add_child(desc)
		
		if not is_done:
			var can_complete = true
			var cond_strs = []
			var req_items: Dictionary = q.get("req_items", {})
			for it_id in req_items.keys():
				var need_c = int(req_items[it_id])
				var have_c = count_total_item(it_id, p_grid, s_grid)
				if have_c < need_c: can_complete = false
				cond_strs.append("%s (%d/%d)" % [it_id, have_c, need_c])
				
			var req_k = int(q.get("req_kills", 0))
			if req_k > 0:
				if total_kills < req_k: can_complete = false
				cond_strs.append("적 처치 (%d/%d)" % [total_kills, req_k])
				
			var req_hk = int(q.get("req_human_kills", 0))
			if req_hk > 0:
				if human_kills < req_hk: can_complete = false
				cond_strs.append("무장 적 처치 (%d/%d)" % [human_kills, req_hk])
				
			var req_fo = int(q.get("req_field_objectives", 0))
			if req_fo > 0:
				var fo_cnt = int(w_data["player"].get("field_objectives_completed", 0))
				if fo_cnt < req_fo: can_complete = false
				cond_strs.append("현장 단말기 해킹 (%d/%d)" % [fo_cnt, req_fo])
				
			var rew_strs = ["+%d RUB" % int(q["reward_rubles"])]
			for r_it in q.get("reward_items", []):
				rew_strs.append("%s x%d" % [r_it["id"], int(r_it["amount"])])
				
			var prog_lbl = Label.new()
			prog_lbl.text = "진행도: %s  |  보상: %s" % [", ".join(cond_strs), ", ".join(rew_strs)]
			prog_lbl.add_theme_font_size_override("font_size", 11)
			prog_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5) if can_complete else Color(0.85, 0.7, 0.45))
			vbox.add_child(prog_lbl)
			
			var comp_btn = Button.new()
			if UiIconManager:
				UiIconManager.set_button(comp_btn, "gift", "의뢰 완수 및 보상 수령", 15)
			else:
				comp_btn.text = "의뢰 완수 및 보상 수령"
			comp_btn.disabled = not can_complete
			var q_cap = q
			comp_btn.pressed.connect(func():
				var s_backup: Array = s_grid.items.duplicate(true) if s_grid else []
				var p_backup: Array = p_grid.items.duplicate(true) if p_grid else []
				for it_id in req_items.keys():
					consume_total_item(it_id, int(req_items[it_id]), p_grid, s_grid)
				var all_rewards_fit := true
				for r_it in q_cap.get("reward_items", []):
					var r_amt := int(r_it["amount"])
					var rem := s_grid.auto_add_item(r_it["id"], r_amt) if s_grid else r_amt
					if rem > 0 and p_grid:
						rem = p_grid.auto_add_item(r_it["id"], rem)
					if rem > 0:
						all_rewards_fit = false
						break
				if not all_rewards_fit:
					if s_grid:
						s_grid.load_items(s_backup)
					if p_grid:
						p_grid.load_items(p_backup)
					if EventBus.has_signal("event_logged"):
						EventBus.event_logged.emit("[icon:warn] 창고와 배낭 공간이 부족하여 의뢰 보상을 수령할 수 없습니다.")
					if SoundManager: SoundManager.play("hit_melee")
					return
				w_data["player"]["rubles"] = int(w_data["player"].get("rubles", 0)) + int(q_cap["reward_rubles"])
				completed_list.append(q_cap["id"])
				if SoundManager: SoundManager.play("level_up")
				if hideout.has_method("_update_money_label"):
					hideout._update_money_label()
				if hideout.has_method("_on_grid_changed"):
					hideout._on_grid_changed()
				refresh_progression_tab(hideout, tab_root)
			)
			vbox.add_child(comp_btn)
			
		q_list.add_child(card)

const WEAPON_MASTERY_LV1_KILLS: int = 15
const WEAPON_MASTERY_LV2_KILLS: int = 35
const WEAPON_MASTERY_LV3_KILLS: int = 70
const WEAPON_MASTERY_KILL_THRESHOLD: int = 15
const TRACKED_MASTERY_WEAPONS: Array[String] = [
	"M4_리시버", "AK_리시버", "SV98_리시버", "MP5_리시버", "레버액션_리시버", "레밍턴_리시버", "M9_리시버"
]

const DOGTAG_BARTER_TRADES: Array[Dictionary] = [
	{
		"id": "barter_keycard",
		"cost_tags": 5,
		"reward_id": "보안 키카드",
		"reward_amount": 1,
		"title": "보안 키카드 (Security Keycard)",
		"desc": "병원 원장실 및 특수 보안 잠금문을 개방하는 마그네틱 키카드"
	},
	{
		"id": "barter_armor3",
		"cost_tags": 10,
		"reward_id": "3레벨_방탄복",
		"reward_amount": 1,
		"title": "3레벨 중갑 방탄복 (Lv.3 Heavy Armor)",
		"desc": "최고 등급의 방탄 플레이트 캐리어 (방어력 +60)"
	},
	{
		"id": "barter_scope8x",
		"cost_tags": 10,
		"reward_id": "8배율_스나이퍼_스코프",
		"reward_amount": 1,
		"title": "8배율 초장거리 저격 스코프 (8.0x Scope)",
		"desc": "소총 및 저격총에 장착 가능한 최고배율 정밀 조준경"
	}
]

static func normalize_weapon_id(weapon_id: String) -> String:
	if weapon_id == "":
		return ""
	if weapon_id == "레버액션 소총" or weapon_id == "레버액션_소총":
		return "레버액션_리시버"
	return WeaponPartsDatabase.resolve_receiver_id(weapon_id)

static func execute_dogtag_barter(trade_id: String, _world_data: Dictionary, player_grid: InventoryGrid, stash_grid: InventoryGrid) -> Dictionary:
	var trade: Dictionary = {}
	for t in DOGTAG_BARTER_TRADES:
		if String(t.get("id", "")) == trade_id:
			trade = t
			break
	if trade.is_empty():
		return {"success": false, "reason": "invalid_trade"}
	var cost_tags := int(trade.get("cost_tags", 5))
	var have_tags := count_total_item("Scav 인식표", player_grid, stash_grid)
	if have_tags < cost_tags:
		return {"success": false, "reason": "not_enough_tags", "have": have_tags, "need": cost_tags}
	var reward_id := String(trade.get("reward_id", ""))
	var reward_amt := int(trade.get("reward_amount", 1))
	var target_grid: InventoryGrid = stash_grid if stash_grid != null else player_grid
	var fallback_grid: InventoryGrid = player_grid if target_grid == stash_grid else stash_grid
	if target_grid == null and fallback_grid == null:
		return {"success": false, "reason": "no_grid"}
	consume_total_item("Scav 인식표", cost_tags, player_grid, stash_grid)
	var rem := reward_amt
	if target_grid:
		rem = target_grid.auto_add_item(reward_id, rem)
	if rem > 0 and fallback_grid:
		rem = fallback_grid.auto_add_item(reward_id, rem)
	if rem >= reward_amt:
		# 공간 부족 시 인식표 복구
		if target_grid:
			target_grid.auto_add_item("Scav 인식표", cost_tags)
		return {"success": false, "reason": "inventory_full"}
	return {
		"success": true,
		"trade_id": trade_id,
		"spent_tags": cost_tags,
		"reward_id": reward_id,
		"reward_amount": reward_amt - rem
	}

static func record_weapon_kill(world_data: Dictionary, weapon_id: String, count: int = 1) -> int:
	if weapon_id == "" or weapon_id == "맨손":
		return 0
	var norm_id := normalize_weapon_id(weapon_id)
	if not world_data.has("player"):
		world_data["player"] = {}
	if not (world_data["player"].get("weapon_kills") is Dictionary):
		world_data["player"]["weapon_kills"] = {}
	var w_kills: Dictionary = world_data["player"]["weapon_kills"]
	var prev_cnt: int = int(w_kills.get(norm_id, 0))
	var next_cnt: int = prev_cnt + maxi(1, count)
	w_kills[norm_id] = next_cnt
	if EventBus and EventBus.has_signal("event_logged"):
		var w_data := ItemDatabase.get_item_data(norm_id) if ItemDatabase else {}
		var w_name := String(w_data.get("name", norm_id))
		if prev_cnt < WEAPON_MASTERY_LV3_KILLS and next_cnt >= WEAPON_MASTERY_LV3_KILLS:
			EventBus.event_logged.emit("[icon:trophy] [총기 숙련도 Lv.3 Мастер] %s 70킬 달성! 기능고장 확률 50%% 감소 및 황금 테두리가 해금되었습니다!" % w_name)
		elif prev_cnt < WEAPON_MASTERY_LV2_KILLS and next_cnt >= WEAPON_MASTERY_LV2_KILLS:
			EventBus.event_logged.emit("[icon:medal] [총기 숙련도 Lv.2] %s 35킬 달성! 반동 제어 +5%% 보너스가 해금되었습니다!" % w_name)
		elif prev_cnt < WEAPON_MASTERY_LV1_KILLS and next_cnt >= WEAPON_MASTERY_LV1_KILLS:
			EventBus.event_logged.emit("[icon:medal] [총기 숙련도 Lv.1] %s 15킬 달성! 재장전 속도 +3%% 보너스가 해금되었습니다!" % w_name)
	return next_cnt

static func get_weapon_kill_count(world_data: Dictionary, weapon_id: String) -> int:
	if weapon_id == "":
		return 0
	var norm_id := normalize_weapon_id(weapon_id)
	var w_kills: Dictionary = world_data.get("player", {}).get("weapon_kills", {})
	return int(w_kills.get(norm_id, w_kills.get(weapon_id, 0)))

static func get_weapon_mastery_bonus(world_data: Dictionary, weapon_id: String) -> Dictionary:
	var kills := get_weapon_kill_count(world_data, weapon_id)
	var lv := 0
	var next_th := WEAPON_MASTERY_LV1_KILLS
	var reload_mult := 1.0
	var recoil_mult := 1.0
	var jam_mult := 1.0
	var title_tag := "미숙련"
	if kills >= WEAPON_MASTERY_LV3_KILLS:
		lv = 3
		next_th = WEAPON_MASTERY_LV3_KILLS
		reload_mult = 0.95
		recoil_mult = 0.95
		jam_mult = 0.50
		title_tag = "Lv.3 Мастер"
	elif kills >= WEAPON_MASTERY_LV2_KILLS:
		lv = 2
		next_th = WEAPON_MASTERY_LV3_KILLS
		reload_mult = 0.97
		recoil_mult = 0.95
		jam_mult = 1.0
		title_tag = "Lv.2 전문"
	elif kills >= WEAPON_MASTERY_LV1_KILLS:
		lv = 1
		next_th = WEAPON_MASTERY_LV2_KILLS
		reload_mult = 0.97
		recoil_mult = 1.0
		jam_mult = 1.0
		title_tag = "Lv.1 숙련"
	var mastered := (lv >= 1)
	return {
		"weapon_id": normalize_weapon_id(weapon_id),
		"kills": kills,
		"level": lv,
		"title": title_tag,
		"threshold": WEAPON_MASTERY_KILL_THRESHOLD,
		"next_threshold": next_th,
		"max_threshold": WEAPON_MASTERY_LV3_KILLS,
		"mastered": mastered,
		"is_grandmaster": lv >= 3,
		"gold_border": lv >= 3,
		"reload_speed_mult": reload_mult,
		"recoil_mult": recoil_mult,
		"jam_chance_mult": jam_mult,
		"bonus_pct": 5 if lv >= 2 else (3 if lv == 1 else 0)
	}

static func get_service_record_data(world_data: Dictionary, player_grid: InventoryGrid = null, stash_grid: InventoryGrid = null) -> Dictionary:
	var p_data: Dictionary = world_data.get("player", {})
	var raids_survived := int(p_data.get("raids_survived", 0))
	var kills_total := int(p_data.get("kills_total", 0))
	var human_kills := int(p_data.get("human_kills", 0))
	var boss_kills := int(p_data.get("boss_kills", 0))
	var dogtag_count := count_total_item("Scav 인식표", player_grid, stash_grid)
	var mastered: Array[String] = []
	for w_id in TRACKED_MASTERY_WEAPONS:
		if get_weapon_kill_count(world_data, w_id) >= WEAPON_MASTERY_KILL_THRESHOLD:
			mastered.append(w_id)
	return {
		"raids_survived": raids_survived,
		"kills_total": kills_total,
		"human_kills": human_kills,
		"boss_kills": boss_kills,
		"dogtag_count": dogtag_count,
		"weapon_kills": p_data.get("weapon_kills", {}).duplicate(true) if p_data.get("weapon_kills") is Dictionary else {},
		"mastered_weapons": mastered
	}

static func setup_service_record_tab(_hideout: Control, tab_container: TabContainer) -> Control:
	var tab_root := HBoxContainer.new()
	tab_root.name = " 전술 기록실 "
	tab_root.add_theme_constant_override("separation", 18)
	tab_container.add_child(tab_root)
	if UiIconManager:
		UiIconManager.set_tab_icon_by_control(tab_container, tab_root, "medal")

	# 좌측: 레이드 전적 아카이브 & 인식표 휘장
	var rec_panel := PanelContainer.new()
	rec_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rec_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rec_vbox := VBoxContainer.new()
	rec_vbox.name = "ServiceStatsVBox"
	rec_vbox.add_theme_constant_override("separation", 10)
	rec_panel.add_child(rec_vbox)
	tab_root.add_child(rec_panel)

	# 우측: 총기별 킬 카운트 & 총기 숙련도(Weapon Mastery)
	var mas_panel := PanelContainer.new()
	mas_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mas_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var mas_vbox_outer := VBoxContainer.new()
	mas_vbox_outer.add_theme_constant_override("separation", 10)
	mas_panel.add_child(mas_vbox_outer)

	var mas_title := Label.new()
	mas_title.text = "총기 숙련도 3단계 (Lv.1 15킬 · Lv.2 35킬 · Lv.3 70킬 Мастер)"
	mas_title.add_theme_font_size_override("font_size", 16)
	mas_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	mas_vbox_outer.add_child(mas_title)
	if UiIconManager:
		UiIconManager.set_label_icon(mas_title, "gun_gold", "", 18, 6)

	var mas_scroll := ScrollContainer.new()
	mas_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var mas_list := VBoxContainer.new()
	mas_list.name = "WeaponMasteryList"
	mas_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mas_list.add_theme_constant_override("separation", 8)
	mas_scroll.add_child(mas_list)
	mas_vbox_outer.add_child(mas_scroll)
	tab_root.add_child(mas_panel)

	return tab_root

static func refresh_service_record_tab(hideout: Control, tab_root: Control) -> void:
	if not tab_root or not GameManager:
		return
	var rec_vbox: VBoxContainer = tab_root.find_child("ServiceStatsVBox", true, false)
	var mas_list: VBoxContainer = tab_root.find_child("WeaponMasteryList", true, false)
	if not rec_vbox or not mas_list:
		return
	for c in rec_vbox.get_children():
		c.queue_free()
	for c in mas_list.get_children():
		c.queue_free()

	var w_data: Dictionary = GameManager.current_world_data
	var p_grid: InventoryGrid = hideout.get("player_grid_mgr")
	var s_grid: InventoryGrid = hideout.get("stash_grid_mgr")
	var summary := get_service_record_data(w_data, p_grid, s_grid)

	var title := Label.new()
	title.text = "전술 기록실 (Service Record & Dogtag Archive)"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	rec_vbox.add_child(title)
	if UiIconManager:
		UiIconManager.set_label_icon(title, "medal", "", 18, 6)

	var stat_lines := [
		["extract", "누적 레이드 생환 횟수", "%d 회" % int(summary["raids_survived"]), Color(0.45, 1.0, 0.55)],
		["swords", "누적 전체 적 사살 수", "%d 명" % int(summary["kills_total"]), Color(0.92, 0.94, 0.98)],
		["target", "무장 세력(Scav/Raider) 사살", "%d 명" % int(summary["human_kills"]), Color(1.0, 0.82, 0.4)],
		["skull", "구역 지휘관(Boss) 사살", "%d 회" % int(summary["boss_kills"]), Color(1.0, 0.45, 0.45)],
		["tag", "보유 중인 Scav 인식표 (Dogtag)", "%d 개" % int(summary["dogtag_count"]), Color(0.4, 0.92, 1.0)],
		["star", "마스터 달성 총기 수", "%d / %d 종" % [summary["mastered_weapons"].size(), TRACKED_MASTERY_WEAPONS.size()], Color(1.0, 0.88, 0.3)]
	]

	for row in stat_lines:
		var card := PanelContainer.new()
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		card.add_child(hbox)
		if UiIconManager:
			hbox.add_child(UiIconManager.create_icon_rect(String(row[0]), 15))
		var k_lbl := Label.new()
		k_lbl.text = String(row[1])
		k_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		k_lbl.add_theme_font_size_override("font_size", 13)
		hbox.add_child(k_lbl)
		var v_lbl := Label.new()
		v_lbl.text = String(row[2])
		v_lbl.add_theme_font_size_override("font_size", 14)
		v_lbl.add_theme_color_override("font_color", row[3])
		hbox.add_child(v_lbl)
		rec_vbox.add_child(card)

	# === Scav 인식표 전용 암시장 물물교환소 (Dogtag Barter Shop) ===
	var barter_header := Label.new()
	barter_header.text = "Scav 인식표 암시장 물물교환소 (보유 인식표: %d개)" % int(summary["dogtag_count"])
	barter_header.add_theme_font_size_override("font_size", 15)
	barter_header.add_theme_color_override("font_color", Color(1.0, 0.84, 0.28))
	rec_vbox.add_child(barter_header)
	if UiIconManager:
		UiIconManager.set_label_icon(barter_header, "tag", "", 16, 6)

	for b_trade in DOGTAG_BARTER_TRADES:
		var b_card := PanelContainer.new()
		if PixelAssetManager:
			var b_sb := PixelAssetManager.get_pixel_stylebox("barter_card", 8.0, 6.0, 8.0, 6.0, 4)
			if b_sb != null:
				b_card.add_theme_stylebox_override("panel", b_sb)

		var b_hbox := HBoxContainer.new()
		b_hbox.add_theme_constant_override("separation", 10)
		b_card.add_child(b_hbox)

		var r_id := String(b_trade["reward_id"])
		if ItemIconManager:
			var b_icon := TextureRect.new()
			b_icon.custom_minimum_size = Vector2(32, 32)
			b_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			b_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			b_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			b_icon.texture = ItemIconManager.get_icon(r_id)
			b_hbox.add_child(b_icon)

		var b_info_v := VBoxContainer.new()
		b_info_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b_name_lbl := Label.new()
		b_name_lbl.text = "%s (인식표 %d개 교환)" % [String(b_trade["title"]), int(b_trade["cost_tags"])]
		b_name_lbl.add_theme_font_size_override("font_size", 13)
		b_name_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.78))
		b_info_v.add_child(b_name_lbl)

		var b_desc_lbl := Label.new()
		b_desc_lbl.text = String(b_trade["desc"])
		b_desc_lbl.add_theme_font_size_override("font_size", 11)
		b_desc_lbl.add_theme_color_override("font_color", Color(0.72, 0.76, 0.84))
		b_info_v.add_child(b_desc_lbl)
		b_hbox.add_child(b_info_v)

		var cost_c := int(b_trade["cost_tags"])
		var can_barter := int(summary["dogtag_count"]) >= cost_c
		var b_btn := Button.new()
		if UiIconManager:
			UiIconManager.set_button(b_btn, "tag", "%d개 교환" % cost_c, 14)
		else:
			b_btn.text = "%d개 교환" % cost_c
		b_btn.disabled = not can_barter
		var cap_tid := String(b_trade["id"])
		b_btn.pressed.connect(func():
			var res := execute_dogtag_barter(cap_tid, w_data, p_grid, s_grid)
			if bool(res.get("success", false)):
				if SoundManager:
					SoundManager.play("level_up")
				if hideout.has_method("_refresh_stash_ui"):
					hideout._refresh_stash_ui()
				if hideout.has_method("_sync_save_data"):
					hideout._sync_save_data()
				refresh_service_record_tab(hideout, tab_root)
		)
		b_hbox.add_child(b_btn)
		rec_vbox.add_child(b_card)

	for w_id in TRACKED_MASTERY_WEAPONS:
		var m_info := get_weapon_mastery_bonus(w_data, w_id)
		var kills := int(m_info["kills"])
		var lv := int(m_info.get("level", 0))
		var is_gm := bool(m_info.get("gold_border", false))
		var idata := ItemDatabase.get_item_data(w_id) if ItemDatabase else {}
		var w_name := String(idata.get("name", w_id))

		var card := PanelContainer.new()
		if is_gm and PixelAssetManager:
			var gm_sb := PixelAssetManager.get_pixel_stylebox("mastery_gold", 8.0, 6.0, 8.0, 6.0, 4)
			if gm_sb != null:
				card.add_theme_stylebox_override("panel", gm_sb)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)

		var h_row := HBoxContainer.new()
		h_row.add_theme_constant_override("separation", 8)
		vbox.add_child(h_row)

		if ItemIconManager:
			var icon_frame := PanelContainer.new()
			if PixelAssetManager:
				var ic_preset := "icon_frame_gold" if is_gm else ("workbench_slot_active" if lv >= 1 else "icon_frame")
				var ic_sb := PixelAssetManager.get_pixel_stylebox(ic_preset, 2.0, 2.0, 2.0, 2.0, 3)
				if ic_sb != null:
					icon_frame.add_theme_stylebox_override("panel", ic_sb)
			var w_icon := TextureRect.new()
			w_icon.custom_minimum_size = Vector2(28, 28)
			w_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			w_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			w_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			w_icon.texture = ItemIconManager.get_icon(w_id)
			icon_frame.add_child(w_icon)
			h_row.add_child(icon_frame)

		var header := Label.new()
		var badge_str := " [Lv.3 Мастер]" if lv >= 3 else (" [Lv.%d]" % lv if lv >= 1 else "")
		header.text = "%s  —  처치: %d / %d 킬%s" % [
			w_name,
			kills,
			WEAPON_MASTERY_LV3_KILLS,
			badge_str
		]
		header.add_theme_font_size_override("font_size", 13)
		header.add_theme_color_override("font_color", Color(1.0, 0.86, 0.25) if lv >= 3 else (Color(0.45, 0.95, 0.65) if lv >= 1 else Color(0.88, 0.9, 0.95)))
		if UiIconManager and lv >= 1:
			h_row.add_child(UiIconManager.create_icon_rect("trophy" if lv >= 3 else "star", 15))
		h_row.add_child(header)

		var bar := ProgressBar.new()
		bar.max_value = float(WEAPON_MASTERY_LV3_KILLS)
		bar.value = float(min(kills, WEAPON_MASTERY_LV3_KILLS))
		bar.custom_minimum_size = Vector2(0, 14)
		vbox.add_child(bar)

		var bonus_lbl := Label.new()
		var bonus_icon := ""
		if lv >= 3:
			bonus_icon = "trophy"
			bonus_lbl.text = "Lv.3 Мастер 달성: 재장전 +5% · 반동 제어 +5% · 기능고장(Jam) 확률 -50% · 황금 총기 테두리"
			bonus_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.28))
		elif lv == 2:
			bonus_icon = "ok"
			bonus_lbl.text = "Lv.2 활성화: 재장전 +3% & 반동 제어 +5%  |  다음 목표: 70킬 (Lv.3 Мастер: 기능고장 -50% & 황금 테두리)"
			bonus_lbl.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55))
		elif lv == 1:
			bonus_icon = "ok"
			bonus_lbl.text = "Lv.1 활성화: 재장전 속도 +3%  |  다음 목표: 35킬 (Lv.2: 반동 제어 +5%)"
			bonus_lbl.add_theme_color_override("font_color", Color(0.45, 0.92, 1.0))
		else:
			bonus_lbl.text = "단계별 보너스: Lv.1(15킬: 재장전+3%) → Lv.2(35킬: 반동+5%) → Lv.3 Мастер(70킬: 잼-50% & 황금 테두리)"
			bonus_lbl.add_theme_color_override("font_color", Color(0.7, 0.74, 0.82))
		bonus_lbl.add_theme_font_size_override("font_size", 11)
		vbox.add_child(bonus_lbl)
		if UiIconManager and bonus_icon != "":
			UiIconManager.set_label_icon(bonus_lbl, bonus_icon, "", 14, 5)

		mas_list.add_child(card)
