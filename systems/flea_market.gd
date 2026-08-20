# res://systems/flea_market.gd
extends Node

## 은신처 가상 플리마켓 시스템

var trends: Dictionary = {}
var price_multipliers: Dictionary = {}
var listings: Array = []
var player_listings: Array = []

var next_listing_id: int = 1
var next_player_listing_id: int = 1

func _ready() -> void:
	_initialize_market()

func _initialize_market() -> void:
	for item_name in ItemDatabase.items.keys():
		trends[item_name] = randf_range(-0.15, 0.20)
		price_multipliers[item_name] = 1.0
	
	update_market_prices(1)
	refresh_listings(1)

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
		if item_name == "Scav 식별줄(Dogtag)":
			continue
			
		var current_price = get_current_price(item_name)
		var price_factor = rng.randf_range(0.85, 1.15)
		var price = max(5, int(current_price * price_factor))
		
		var count = 1
		if data.get("stackable", false):
			var max_stack = data.get("max_stack", 5)
			count = rng.randi_range(1, max(2, max_stack / 2))
			
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
	if item_name == "Scav 식별줄(Dogtag)":
		return false
		
	player_listings.append({
		"id": next_player_listing_id,
		"item_name": item_name,
		"count": count,
		"price": price,
		"timer": 2.0
	})
	next_player_listing_id += 1
	return true
