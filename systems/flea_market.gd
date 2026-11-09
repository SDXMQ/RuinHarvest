# res://systems/flea_market.gd
extends Node

## 은신처 가상 플리마켓 시스템

var trends: Dictionary = {}
var price_multipliers: Dictionary = {}
var listings: Array = []
var player_listings: Array = []
var daily_bounties: Array[Dictionary] = []

const BOUNTY_MULTIPLIER: float = 2.5
const BOUNTY_CANDIDATE_POOL: Array[String] = [
	"고철", "폐전선", "비상용 배터리", "CPU", "그래픽카드",
	"라디오 부품", "기계 부품", "화약", "금시계", "은반지", "암호화된 SSD", "약초"
]

var next_listing_id: int = 1
var next_player_listing_id: int = 1
var current_day: int = 1

func _ready() -> void:
	_initialize_market()

func _initialize_market() -> void:
	for item_name in ItemDatabase.items.keys():
		trends[item_name] = randf_range(-0.15, 0.20)
		price_multipliers[item_name] = 1.0
	
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
		var m_price: int = get_current_price(resolved)
		unit_bounty = maxi(25, int(round(float(m_price) * BOUNTY_MULTIPLIER)))
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

func get_current_price(item_name: String) -> int:
	if not ItemDatabase.items.has(item_name):
		return 1000
		
	var data = ItemDatabase.items[item_name]
	var base_price = data.get("value", 1000)
	var mult = price_multipliers.get(item_name, 1.0)
	return max(10, int(base_price * mult))

func update_market_prices(in_game_day: int) -> void:
	var rng = RandomNumberGenerator.new()
	
	for item_name in ItemDatabase.items.keys():
		var data = ItemDatabase.items[item_name]
		# 날짜와 아이템 이름으로 시드 고정
		rng.seed = hash(item_name) + in_game_day * 10007
		
		if rng.randf() < 0.2:
			trends[item_name] = rng.randf_range(-0.15, 0.30)
			
		var category = data.get("category", "")
		var sigma = 0.05
		if category in [ItemDatabase.ItemCategory.WEAPON, ItemDatabase.ItemCategory.EQUIPMENT]:
			sigma = 0.15
			
		# Box-Muller 변환으로 가우시안 노이즈 생성
		var u1 = rng.randf()
		var u2 = rng.randf()
		var z0 = sqrt(-2.0 * log(max(u1, 0.0001))) * cos(2.0 * PI * u2)
		var noise = z0 * sigma
		
		var r_trend = trends[item_name]
		var mult = 1.0 + r_trend + noise
		price_multipliers[item_name] = clamp(mult, 0.4, 2.5)

func refresh_listings(in_game_day: int) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = in_game_day * 20011
	
	listings.clear()
	var all_items = ItemDatabase.items.keys()
	var num_listings = rng.randi_range(15, 25)
	
	for i in range(num_listings):
		var item_name = all_items[rng.randi_range(0, all_items.size() - 1)]
		var data = ItemDatabase.items[item_name]
		
		# 예: 거래 불가 품목 필터
		if item_name in ["Scav 식별줄(Dogtag)", "Scav 인식표"]:
			continue
			
		var current_price = get_current_price(item_name)
		var price_factor = rng.randf_range(0.85, 1.15)
		var price = max(5, int(current_price * price_factor))
		
		var count = 1
		if data.get("stackable", false):
			var max_stack = data.get("max_stack", 5)
			count = rng.randi_range(1, max(2, int(max_stack * 0.5)))
			
		listings.append({
			"id": next_listing_id,
			"item_name": item_name,
			"count": count,
			"price": price
		})
		next_listing_id += 1
		
	# 가격 순 오름차순 정렬
	listings.sort_custom(func(a, b): return a["price"] < b["price"])

func process_player_sales(player_data: Dictionary) -> Dictionary:
	var completed = []
	var failed = []
	var pending = []
	
	for sale in player_listings:
		var item_name = sale["item_name"]
		var p_register = sale["price"]
		var count = sale["count"]
		
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
			var net_earned = int(earned * 0.95) # 5% 수수료
			if player_data.has("rubles"):
				player_data["rubles"] += net_earned
			completed.append({
				"item_name": item_name,
				"count": count,
				"earned": net_earned
			})
		else:
			sale["timer"] -= 1.0
			if sale["timer"] <= 0:
				failed.append(sale)
			else:
				pending.append(sale)
				
	player_listings = pending
	return {"completed": completed, "failed": failed}

func register_item(item_name: String, count: int, price: int) -> bool:
	if item_name in ["Scav 식별줄(Dogtag)", "Scav 인식표"]:
		return false
		
	var entry = {
		"id": next_player_listing_id,
		"item_name": item_name,
		"count": count,
		"price": price,
		"seller": "플레이어",
		"timer": 2.0
	}
	player_listings.append(entry)
	listings.append(entry.duplicate())
	listings.sort_custom(func(a, b): return a["price"] < b["price"])
	next_player_listing_id += 1
	return true

func add_listing(listing_data: Dictionary) -> bool:
	return register_item(
		listing_data.get("item_name", ""),
		int(listing_data.get("count", 1)),
		int(listing_data.get("price", 100))
	)
