# res://systems/flea_market.gd
extends Node

## 은신처 가상 플리마켓 시스템

var trends: Dictionary = {}
var price_multipliers: Dictionary = {}
var supply_pressure: Dictionary = {} # item_id -> float (양수: 공급과잉/하락, 음수: 수요초과/상승)
var listings: Array = []
var player_listings: Array = []
var daily_bounties: Array[Dictionary] = []

const MAX_PLAYER_LISTINGS: int = 3
const MIN_LISTING_FEE_RATE: float = 0.05
const MAX_LISTING_FEE_RATE: float = 0.35
const PRESSURE_MIN: float = -0.60
const PRESSURE_MAX: float = 0.50
const PRESSURE_STEP_PER_UNIT: float = 0.06
const PRESSURE_DAILY_DECAY: float = 0.60 # 일일 40% 기준가 평균 회귀

const RARE_MARKET_POOL: Array[String] = [
	"그래픽카드", "CPU", "암호화된 SSD", "금시계", "은반지",
	"라디오 부품", "기계 부품", "장거리 무전기",
	"무기고 열쇠", "보안 키카드",
	"소음기", "컴펜세이터", "4배율_ACOG", "8배율_스나이퍼_스코프",
	"50발_드럼_탄창", "정밀_롱헤비_총열", "PRS_정밀_저격_스톡",
	"RK-1_인체공학_그립", "적색_레이저_표적지시기",
	"3레벨_방탄복", "3레벨_헬멧", "3레벨_가방",
	"SV98_리시버", "M4_리시버", "AK_리시버",
	"탄약 케이스", "의약품 케이스", "무기 부품 상자", "인식표 지갑"
]

const BOUNTY_MULTIPLIER: float = 2.5
const BOUNTY_CANDIDATE_POOL: Array[String] = [
	"비상용 배터리", "CPU", "그래픽카드",
	"라디오 부품", "기계 부품", "화약", "금시계", "은반지", "암호화된 SSD", "약초"
]

var next_listing_id: int = 1
var next_player_listing_id: int = 1
var current_day: int = 1

func _ready() -> void:
	_initialize_market()

func _get_all_known_item_ids() -> Array[String]:
	var seen: Dictionary = {}
	var result: Array[String] = []
	if ItemDatabase:
		for k in ItemDatabase.items.keys():
			var ks := String(k)
			if not seen.has(ks):
				seen[ks] = true
				result.append(ks)
	for pk in WeaponPartsDatabase.PARTS.keys():
		var pks := String(pk)
		if not seen.has(pks):
			seen[pks] = true
			result.append(pks)
	for rk in WeaponPartsDatabase.RECEIVERS.keys():
		var rks := String(rk)
		if not seen.has(rks):
			seen[rks] = true
			result.append(rks)
	return result

func _resolve_id(item_name: String) -> String:
	if ItemDatabase and ItemDatabase.has_method("resolve_item_id"):
		return ItemDatabase.resolve_item_id(item_name)
	return item_name

func _initialize_market() -> void:
	for item_name in _get_all_known_item_ids():
		trends[item_name] = randf_range(-0.15, 0.20)
		price_multipliers[item_name] = 1.0
	supply_pressure.clear()
	
	update_market_prices(current_day)
	refresh_listings(current_day)
	refresh_daily_bounties(current_day)

func advance_day(day_num: int = -1) -> void:
	if day_num > 0:
		current_day = day_num
	elif GameManager and GameManager.current_world_data and GameManager.current_world_data.has("current_day"):
		current_day = int(GameManager.current_world_data["current_day"]) + 1
	else:
		current_day += 1
	decay_supply_pressure()
	update_market_prices(current_day)
	refresh_listings(current_day)
	refresh_daily_bounties(current_day)

func refresh_daily_bounties(in_game_day: int = -1) -> Array[Dictionary]:
	var target_day := in_game_day if in_game_day > 0 else current_day
	var rng := RandomNumberGenerator.new()
	rng.seed = target_day * 30013 + 777
	daily_bounties.clear()
	var pool: Array[String] = []
	for cand in BOUNTY_CANDIDATE_POOL:
		if ItemDatabase.items.has(cand):
			pool.append(cand)
	if pool.is_empty():
		for k in ItemDatabase.items.keys():
			if not (String(k) in ["Scav 식별줄(Dogtag)", "Scav 인식표"]):
				pool.append(String(k))
	var chosen: Array[String] = []
	var count_to_pick: int = min(2, pool.size())
	var attempts := 0
	while chosen.size() < count_to_pick and attempts < 30:
		attempts += 1
		var pick := pool[rng.randi_range(0, pool.size() - 1)]
		if not (pick in chosen):
			chosen.append(pick)
	for item_id in chosen:
		var market_price: int = get_current_price(item_id)
		var bounty_price: int = maxi(25, int(round(float(market_price) * BOUNTY_MULTIPLIER)))
		var data: Dictionary = ItemDatabase.get_item_data(item_id)
		daily_bounties.append({
			"item_id": item_id,
			"name": String(data.get("name", item_id)),
			"market_price": market_price,
			"bounty_price": bounty_price,
			"multiplier": BOUNTY_MULTIPLIER,
			"day": target_day
		})
	return daily_bounties

func get_daily_bounties(in_game_day: int = -1) -> Array[Dictionary]:
	if in_game_day > 0 and (daily_bounties.is_empty() or int(daily_bounties[0].get("day", -1)) != in_game_day):
		return refresh_daily_bounties(in_game_day)
	if daily_bounties.is_empty():
		return refresh_daily_bounties(current_day)
	# 현재 시세와 2.5배 가격 동기화
	for b in daily_bounties:
		var m_price: int = get_current_price(String(b.get("item_id", "")))
		b["market_price"] = m_price
		b["bounty_price"] = maxi(25, int(round(float(m_price) * BOUNTY_MULTIPLIER)))
	return daily_bounties

func get_bounty_price(item_id: String) -> int:
	var resolved: String = ItemDatabase.resolve_item_id(item_id) if ItemDatabase else item_id
	for b in get_daily_bounties():
		if String(b.get("item_id", "")) == resolved or String(b.get("item_id", "")) == item_id:
			return int(b.get("bounty_price", int(round(float(get_current_price(resolved)) * BOUNTY_MULTIPLIER))))
	return 0

func is_bounty_item(item_id: String) -> bool:
	return get_bounty_price(item_id) > 0

func fulfill_bounty_order(item_id: String, amount: int, world_data: Dictionary, player_grid: InventoryGrid = null, stash_grid: InventoryGrid = null) -> Dictionary:
	var resolved: String = ItemDatabase.resolve_item_id(item_id) if ItemDatabase else item_id
	var unit_bounty: int = get_bounty_price(resolved)
	if unit_bounty <= 0:
		return {"success": false, "earned": 0, "sold": 0}
	var sell_amt: int = maxi(1, amount)
	if player_grid != null or stash_grid != null:
		var owned: int = 0
		if player_grid:
			owned += player_grid.get_item_count(resolved)
		if stash_grid:
			owned += stash_grid.get_item_count(resolved)
		if owned <= 0:
			return {"success": false, "earned": 0, "sold": 0}
		sell_amt = mini(sell_amt, owned)
		var rem: int = sell_amt
		if stash_grid:
			rem = stash_grid.remove_item(resolved, rem)
		if rem > 0 and player_grid:
			player_grid.remove_item(resolved, rem)
	var earned: int = unit_bounty * sell_amt
	if not world_data.has("player"):
		world_data["player"] = {}
	world_data["player"]["rubles"] = int(world_data["player"].get("rubles", 0)) + earned
	return {
		"success": true,
		"item_id": resolved,
		"sold": sell_amt,
		"unit_price": unit_bounty,
		"market_price": get_current_price(resolved),
		"earned": earned
	}

func get_supply_pressure(item_name: String) -> float:
	var resolved := _resolve_id(item_name)
	return float(supply_pressure.get(resolved, 0.0))

func get_supply_elasticity_multiplier(item_name: String, extra_pressure: float = 0.0) -> float:
	var resolved := _resolve_id(item_name)
	var p := clampf(float(supply_pressure.get(resolved, 0.0)) + extra_pressure, PRESSURE_MIN, PRESSURE_MAX)
	return clampf(1.0 - p, 0.50, 1.60)

func get_pressure_step_for_amount(item_name: String, amount: int) -> float:
	var resolved := _resolve_id(item_name)
	var data: Dictionary = ItemDatabase.get_item_data(resolved) if ItemDatabase else {}
	var max_s := maxi(1, int(data.get("max_stack", 1)))
	var norm_unit := maxf(1.0, float(max_s) * 0.5) if max_s > 1 else 1.0
	return (float(maxi(1, amount)) / norm_unit) * PRESSURE_STEP_PER_UNIT

func record_player_sale(item_name: String, amount: int = 1) -> float:
	var resolved := _resolve_id(item_name)
	if resolved == "":
		return 0.0
	var step := get_pressure_step_for_amount(resolved, amount)
	var next_p := clampf(float(supply_pressure.get(resolved, 0.0)) + step, PRESSURE_MIN, PRESSURE_MAX)
	supply_pressure[resolved] = next_p
	_sync_npc_listing_prices()
	return next_p

func record_player_purchase(item_name: String, amount: int = 1) -> float:
	var resolved := _resolve_id(item_name)
	if resolved == "":
		return 0.0
	var step := get_pressure_step_for_amount(resolved, amount)
	var next_p := clampf(float(supply_pressure.get(resolved, 0.0)) - step, PRESSURE_MIN, PRESSURE_MAX)
	supply_pressure[resolved] = next_p
	_sync_npc_listing_prices()
	return next_p

func decay_supply_pressure() -> void:
	var to_erase: Array[String] = []
	for k in supply_pressure.keys():
		var next_val := float(supply_pressure[k]) * PRESSURE_DAILY_DECAY
		if absf(next_val) < 0.005:
			to_erase.append(String(k))
		else:
			supply_pressure[k] = next_val
	for ek in to_erase:
		supply_pressure.erase(ek)

func _sync_npc_listing_prices() -> void:
	for entry in listings:
		if not (entry is Dictionary):
			continue
		if bool(entry.get("is_player", false)) or bool(entry.get("sold_out", false)):
			continue
		var item_name := String(entry.get("item_name", ""))
		var factor := float(entry.get("price_factor", 1.0))
		entry["price"] = maxi(10, int(round(float(get_current_price(item_name)) * factor)))

func get_base_market_price(item_name: String) -> int:
	var resolved := _resolve_id(item_name)
	if not ItemDatabase:
		return 1000
	var has_known := ItemDatabase.items.has(resolved) or WeaponPartsDatabase.PARTS.has(resolved) or WeaponPartsDatabase.RECEIVERS.has(resolved)
	if not has_known:
		return 1000
	var data: Dictionary = ItemDatabase.get_item_data(resolved)
	var base_price := int(data.get("value", 1000))
	var mult := float(price_multipliers.get(resolved, price_multipliers.get(item_name, 1.0)))
	return maxi(10, int(round(float(base_price) * mult)))

func get_current_price(item_name: String) -> int:
	var base_market := get_base_market_price(item_name)
	var elasticity := get_supply_elasticity_multiplier(item_name)
	return maxi(10, int(round(float(base_market) * elasticity)))

func update_market_prices(in_game_day: int) -> void:
	var rng = RandomNumberGenerator.new()
	
	for item_name in _get_all_known_item_ids():
		var data: Dictionary = ItemDatabase.get_item_data(item_name) if ItemDatabase else {}
		# 날짜와 아이템 이름으로 시드 고정
		rng.seed = hash(item_name) + in_game_day * 10007
		
		if rng.randf() < 0.2:
			trends[item_name] = rng.randf_range(-0.15, 0.30)
			
		var category = data.get("category", -1)
		var sigma = 0.05
		if category in [ItemDatabase.ItemCategory.WEAPON, ItemDatabase.ItemCategory.EQUIPMENT]:
			sigma = 0.15
			
		# Box-Muller 변환으로 가우시안 노이즈 생성
		var u1 = rng.randf()
		var u2 = rng.randf()
		var z0 = sqrt(-2.0 * log(max(u1, 0.0001))) * cos(2.0 * PI * u2)
		var noise = z0 * sigma
		
		var r_trend = float(trends.get(item_name, 0.0))
		var mult = 1.0 + r_trend + noise
		price_multipliers[item_name] = clamp(mult, 0.4, 2.5)

func refresh_listings(in_game_day: int) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = in_game_day * 20011 + 17
	
	listings.clear()
	var pool: Array[String] = []
	for cand in RARE_MARKET_POOL:
		var resolved := _resolve_id(cand)
		if ItemDatabase and (ItemDatabase.items.has(resolved) or WeaponPartsDatabase.PARTS.has(resolved) or WeaponPartsDatabase.RECEIVERS.has(resolved)):
			if not (resolved in ["Scav 식별줄(Dogtag)", "Scav 인식표"]) and not (resolved in pool):
				pool.append(resolved)
	if pool.is_empty():
		for k in _get_all_known_item_ids():
			if not (k in ["Scav 식별줄(Dogtag)", "Scav 인식표"]):
				pool.append(k)
	
	# 6~8개 내외 희소·고부가가치 매물 선정 (결정론적 셔플)
	var shuffled := pool.duplicate()
	for idx in range(shuffled.size() - 1, 0, -1):
		var swap_idx := rng.randi_range(0, idx)
		var tmp = shuffled[idx]
		shuffled[idx] = shuffled[swap_idx]
		shuffled[swap_idx] = tmp
	
	var target_count := mini(shuffled.size(), rng.randi_range(6, 8))
	for i in range(target_count):
		var item_name := String(shuffled[i])
		var current_price := get_current_price(item_name)
		var price_factor := rng.randf_range(0.95, 1.22)
		var unit_price := maxi(10, int(round(float(current_price) * price_factor)))
		var stock_rem := rng.randi_range(1, 3)
		
		listings.append({
			"id": next_listing_id,
			"item_name": item_name,
			"count": 1,
			"stock_remaining": stock_rem,
			"max_stock": stock_rem,
			"sold_out": false,
			"is_player": false,
			"price_factor": price_factor,
			"price": unit_price
		})
		next_listing_id += 1
	
	# 대기 중인 플레이어 매물 보존
	for p_sale in player_listings:
		if p_sale is Dictionary and not bool(p_sale.get("sold_out", false)):
			listings.append(p_sale.duplicate(true))
		
	# 가격 순 오름차순 정렬
	listings.sort_custom(func(a, b): return int(a.get("price", 0)) < int(b.get("price", 0)))

func purchase_listing(listing_or_id, buy_qty: int = 1) -> Dictionary:
	var qty := maxi(1, buy_qty)
	var target: Dictionary = {}
	if listing_or_id is Dictionary:
		target = listing_or_id
	else:
		var lid := int(listing_or_id)
		for entry in listings:
			if entry is Dictionary and int(entry.get("id", -1)) == lid and not bool(entry.get("is_player", false)):
				target = entry
				break
	if target.is_empty():
		return {"success": false, "reason": "not_found"}
	var rem_stock := int(target.get("stock_remaining", 0))
	if bool(target.get("sold_out", false)) or rem_stock < qty:
		return {"success": false, "reason": "sold_out"}
	
	var item_name := String(target.get("item_name", ""))
	var pack_count := maxi(1, int(target.get("count", 1)))
	var unit_price := int(target.get("price", get_current_price(item_name)))
	var total_price := unit_price * pack_count * qty
	
	rem_stock -= qty
	target["stock_remaining"] = maxi(0, rem_stock)
	if rem_stock <= 0:
		target["sold_out"] = true
	
	var total_items := pack_count * qty
	record_player_purchase(item_name, total_items)
	return {
		"success": true,
		"item_name": item_name,
		"amount": total_items,
		"unit_price": unit_price,
		"total_price": total_price,
		"stock_remaining": int(target["stock_remaining"]),
		"sold_out": bool(target["sold_out"])
	}

func calculate_listing_fee_rate(item_name: String, unit_price: int) -> float:
	var ref_price := maxi(1, get_current_price(item_name))
	var ratio := float(maxi(1, unit_price)) / float(ref_price)
	if ratio <= 1.0:
		return MIN_LISTING_FEE_RATE
	return clampf(MIN_LISTING_FEE_RATE + (ratio - 1.0) * 0.25, MIN_LISTING_FEE_RATE, MAX_LISTING_FEE_RATE)

func calculate_listing_fee(item_name: String, count: int, unit_price: int) -> int:
	var rate := calculate_listing_fee_rate(item_name, unit_price)
	return maxi(1, int(round(float(maxi(1, unit_price) * maxi(1, count)) * rate)))

func can_register_more_listings() -> bool:
	return player_listings.size() < MAX_PLAYER_LISTINGS

func get_remaining_listing_slots() -> int:
	return maxi(0, MAX_PLAYER_LISTINGS - player_listings.size())

func process_player_sales(player_data: Dictionary) -> Dictionary:
	var completed = []
	var failed = []
	var pending = []
	
	for sale in player_listings:
		var item_name = sale["item_name"]
		var p_register = sale["price"]
		var count = sale["count"]
		var fee_rate := float(sale.get("fee_rate", calculate_listing_fee_rate(item_name, p_register)))
		
		var p_current = get_current_price(item_name)
		var p_min = p_current * 0.8
		var p_max = p_current * 1.2
		
		var denom = p_max - p_min
		var pr_buy = 0.5
		if denom > 0:
			pr_buy = 1.0 - ((p_register - p_min) / denom)
		pr_buy = clamp(pr_buy, 0.01, 0.99)
		
		if randf() < pr_buy:
			var earned = p_register * count
			var net_earned = earned if bool(sale.get("upfront_fee_paid", false)) else int(round(float(earned) * (1.0 - fee_rate)))
			if player_data.has("rubles"):
				player_data["rubles"] += net_earned
			completed.append({
				"item_name": item_name,
				"count": count,
				"earned": net_earned
			})
			_remove_player_listing_mirror(int(sale.get("id", -1)))
		else:
			sale["timer"] -= 1.0
			if sale["timer"] <= 0:
				failed.append(sale)
				_remove_player_listing_mirror(int(sale.get("id", -1)))
			else:
				pending.append(sale)
				
	player_listings = pending
	return {"completed": completed, "failed": failed}

func _remove_player_listing_mirror(player_listing_id: int) -> void:
	for i in range(listings.size() - 1, -1, -1):
		var l = listings[i]
		if l is Dictionary and bool(l.get("is_player", false)) and int(l.get("id", -1)) == player_listing_id:
			listings.remove_at(i)

func register_item(item_name: String, count: int, price: int, upfront_fee_paid: bool = false, custom_data: Dictionary = {}) -> bool:
	var resolved := _resolve_id(item_name)
	if resolved in ["Scav 식별줄(Dogtag)", "Scav 인식표"] or item_name in ["Scav 식별줄(Dogtag)", "Scav 인식표"]:
		return false
	if player_listings.size() >= MAX_PLAYER_LISTINGS:
		return false
	if count <= 0 or price <= 0:
		return false
		
	var fee_rate := calculate_listing_fee_rate(resolved, price)
	var sanitized_cd := InventoryGrid.sanitize_custom_data(custom_data) if not custom_data.is_empty() else {}
	var entry = {
		"id": next_player_listing_id,
		"item_name": resolved,
		"count": count,
		"price": price,
		"stock_remaining": 1,
		"max_stock": 1,
		"sold_out": false,
		"is_player": true,
		"fee_rate": fee_rate,
		"upfront_fee_paid": upfront_fee_paid,
		"seller": "플레이어",
		"timer": 2.0
	}
	if not sanitized_cd.is_empty():
		entry["custom_data"] = sanitized_cd
	player_listings.append(entry)
	listings.append(entry.duplicate(true))
	listings.sort_custom(func(a, b): return int(a.get("price", 0)) < int(b.get("price", 0)))
	next_player_listing_id += 1
	record_player_sale(resolved, count)
	return true

func add_listing(listing_data: Dictionary) -> bool:
	var raw_cd: Dictionary = listing_data.get("custom_data", {}) if (listing_data.get("custom_data") is Dictionary) else {}
	return register_item(
		String(listing_data.get("item_name", "")),
		int(listing_data.get("count", 1)),
		int(listing_data.get("price", 100)),
		bool(listing_data.get("upfront_fee_paid", false)),
		raw_cd
	)

func to_save_dict() -> Dictionary:
	return {
		"current_day": current_day,
		"trends": trends.duplicate(true),
		"supply_pressure": supply_pressure.duplicate(true),
		"player_listings": player_listings.duplicate(true),
		"next_listing_id": next_listing_id,
		"next_player_listing_id": next_player_listing_id
	}

func load_from_save_dict(data: Dictionary) -> void:
	if data.is_empty():
		return
	if data.has("current_day"):
		current_day = maxi(1, int(data.get("current_day", current_day)))
	if data.get("trends") is Dictionary:
		trends = data["trends"].duplicate(true)
	if data.get("supply_pressure") is Dictionary:
		supply_pressure = data["supply_pressure"].duplicate(true)
	if data.get("player_listings") is Array:
		player_listings = []
		for p in data["player_listings"]:
			if p is Dictionary:
				player_listings.append(p.duplicate(true))
	next_listing_id = maxi(next_listing_id, int(data.get("next_listing_id", next_listing_id)))
	next_player_listing_id = maxi(next_player_listing_id, int(data.get("next_player_listing_id", next_player_listing_id)))
	update_market_prices(current_day)
	refresh_listings(current_day)
	refresh_daily_bounties(current_day)
