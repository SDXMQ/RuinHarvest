# res://systems/inventory_grid.gd
class_name InventoryGrid
extends Node

## 타르코프식 2D WxH 점유 맵 그리드 인벤토리 시스템

signal grid_changed

@export var grid_width: int = 6
@export var grid_height: int = 4
@export var has_secure_container: bool = false

static func is_same_item_id(a: String, b: String) -> bool:
	if a == b:
		return true
	var na = a.replace("_", " ").strip_edges()
	var nb = b.replace("_", " ").strip_edges()
	if na == nb:
		return true
	if (na == "기밀 SSD" or na == "암호화된 SSD") and (nb == "기밀 SSD" or nb == "암호화된 SSD"):
		return true
	return false

func is_allowed_in_secure_container(item_id: String) -> bool:
	if item_id == "":
		return true
	var data = ItemDatabase.get_item_data(item_id)
	var item_type = str(data.get("type", ""))
	if item_type == "ammo" or item_id == "탄약" or item_id.contains("9mm") or item_id.contains("5.56") or item_id.contains("7.62") or item_id.contains("12게이지") or item_id.contains(".45"):
		return true
	var cat = int(data.get("category", -1))
	if cat == ItemDatabase.ItemCategory.WEAPON or cat == ItemDatabase.ItemCategory.EQUIPMENT:
		return false
	if item_type == "receiver" or (WeaponPartsDatabase and WeaponPartsDatabase.RECEIVERS.has(item_id)):
		return false
	return true

# items: Array[Dictionary]
# item schema:
# {
#   "uid": "item_123456",
#   "id": "item_id",
#   "x": 0,
#   "y": 0,
#   "w": 1,
#   "h": 1,
#   "rotated": false,
#   "amount": 1,
#   "durability": 100.0,
#   "custom_data": {}
# }
var items: Array[Dictionary] = []
var grid_map: Array = [] # [y][x] -> uid (String or "")

func _ready() -> void:
	_init_grid_map()

func clear() -> void:
	items.clear()
	_init_grid_map()
	grid_changed.emit()

func load_items(saved_items: Array) -> void:
	clear()
	for it in saved_items:
		if not (it is Dictionary) or not it.has("id"): continue
		var item = it.duplicate(true)
		var ix = item.get("x", -1)
		var iy = item.get("y", -1)
		var is_rot = item.get("rotated", false)
		var base_size = ItemDatabase.get_item_grid_size(item["id"])
		var cur_w = base_size.y if is_rot else base_size.x
		var cur_h = base_size.x if is_rot else base_size.y
		item["w"] = base_size.x
		item["h"] = base_size.y
		if not item.has("uid"):
			item["uid"] = "item_%d_%d" % [Time.get_ticks_msec(), randi() % 10000]
		
		# 원래 좌표에 배치 가능하면 그대로 배치
		if ix >= 0 and iy >= 0 and can_place_item(cur_w, cur_h, ix, iy, "", item["id"]):
			place_item(item, ix, iy, is_rot)
		else:
			# 불가하면 Auto-Fit으로 공간 찾아 배치
			auto_add_item(item["id"], item.get("amount", 1), item)
	grid_changed.emit()

func _init_grid_map() -> void:
	grid_map.clear()
	for y in range(grid_height):
		var row: Array[String] = []
		for x in range(grid_width):
			row.append("")
		grid_map.append(row)
		
	# 기존 items 재매핑
	for item in items:
		var cur_w = item.get("h", 1) if item.get("rotated", false) else item.get("w", 1)
		var cur_h = item.get("w", 1) if item.get("rotated", false) else item.get("h", 1)
		_mark_grid(item.get("x", 0), item.get("y", 0), cur_w, cur_h, item.get("uid", ""))

func can_place_item(w: int, h: int, target_x: int, target_y: int, ignore_uid: String = "", item_id: String = "") -> bool:
	if target_x < 0 or target_y < 0:
		return false
	if target_x + w > grid_width or target_y + h > grid_height:
		return false
		
	var check_id = item_id
	if check_id == "" and ignore_uid != "":
		var existing = get_item_by_uid(ignore_uid)
		check_id = existing.get("id", "")
	if has_secure_container and target_x < 2 and target_y < 2:
		# 안전 컨테이너(2x2) 영역과 겹치는 아이템은 경계를 걸쳐 놓을 수 없으며 완전히 내부(2x2)에 들어와야 함
		if target_x + w > 2 or target_y + h > 2:
			return false
		if check_id != "" and not is_allowed_in_secure_container(check_id):
			return false
		
	for dy in range(h):
		for dx in range(w):
			var gx = target_x + dx
			var gy = target_y + dy
			if gy >= grid_map.size() or gx >= grid_map[gy].size():
				return false
			var occ = grid_map[gy][gx]
			if occ != "" and occ != ignore_uid:
				return false
				
	return true

func place_item(item: Dictionary, target_x: int, target_y: int, rotated: bool = false) -> bool:
	var item_id = item.get("id", "")
	var item_data = ItemDatabase.get_item_data(item_id)
	var base_size = ItemDatabase.get_item_grid_size(item_id)
	var w = base_size.x
	var h = base_size.y
	
	var actual_w = h if rotated else w
	var actual_h = w if rotated else h
	
	var uid = item.get("uid", "")
	if uid == "":
		uid = "item_%d_%d" % [Time.get_ticks_msec(), randi() % 10000]
		item["uid"] = uid
		
	if not can_place_item(actual_w, actual_h, target_x, target_y, uid, item_id):
		return false
		
	# 기존 아이템 목록에 있으면 제거 후 재배치
	remove_item_by_uid(uid, false)
	
	# custom_data 내부 핵심 속성을 최상위로 승격 (기존 최상위 값이 있으면 보존)
	var cdata = item.get("custom_data", {})
	if cdata is Dictionary and not cdata.is_empty():
		for k in ["parts", "attachments", "loaded_ammo", "current_magazine_ammo", "computed_stats", "durability", "max_durability", "receiver", "name", "type"]:
			if not item.has(k) and cdata.has(k):
				item[k] = cdata[k]
	if not item.has("durability") and item_data.has("max_durability"):
		item["durability"] = item_data["max_durability"]
	
	item["x"] = target_x
	item["y"] = target_y
	item["w"] = w
	item["h"] = h
	item["rotated"] = rotated
	if not item.has("amount"):
		item["amount"] = 1
		
	items.append(item)
	_mark_grid(target_x, target_y, actual_w, actual_h, uid)
	grid_changed.emit()
	return true

func move_item(uid: String, target_x: int, target_y: int, rotated: bool) -> bool:
	var item = get_item_by_uid(uid)
	if item.is_empty(): return false
	
	var item_id = item.get("id", "")
	var base_size = ItemDatabase.get_item_grid_size(item_id)
	var base_w = item.get("w", base_size.x)
	var base_h = item.get("h", base_size.y)
	var actual_w = base_h if rotated else base_w
	var actual_h = base_w if rotated else base_h
	
	if not can_place_item(actual_w, actual_h, target_x, target_y, uid, item_id):
		return false
		
	# 기존 영역 해제
	var old_w = base_h if item.get("rotated", false) else base_w
	var old_h = base_w if item.get("rotated", false) else base_h
	_mark_grid(item.get("x", 0), item.get("y", 0), old_w, old_h, "")
	
	# 새 위치 설정
	item["x"] = target_x
	item["y"] = target_y
	item["rotated"] = rotated
	
	_mark_grid(target_x, target_y, actual_w, actual_h, uid)
	grid_changed.emit()
	return true

func remove_item_by_uid(uid: String, should_emit: bool = true) -> Dictionary:
	var target_item: Dictionary = {}
	var target_idx = -1
	
	for i in range(items.size()):
		if items[i].get("uid", "") == uid:
			target_item = items[i]
			target_idx = i
			break
			
	if target_idx != -1:
		items.remove_at(target_idx)
		var cur_w = target_item.get("h", 1) if target_item.get("rotated", false) else target_item.get("w", 1)
		var cur_h = target_item.get("w", 1) if target_item.get("rotated", false) else target_item.get("h", 1)
		_mark_grid(target_item.get("x", 0), target_item.get("y", 0), cur_w, cur_h, "")
		if should_emit:
			grid_changed.emit()
			
	return target_item

func get_item_count(id: String) -> int:
	var total = 0
	for item in items:
		if is_same_item_id(String(item.get("id", "")), id):
			total += item.get("amount", 1)
	return total

func has_item(id: String, amount: int = 1) -> bool:
	return get_item_count(id) >= amount

func remove_item(id: String, amount: int = 1) -> int:
	var remaining = amount
	var i = items.size() - 1
	while i >= 0 and remaining > 0:
		var item = items[i]
		if is_same_item_id(String(item.get("id", "")), id):
			var cur_amt = item.get("amount", 1)
			if cur_amt <= remaining:
				remaining -= cur_amt
				remove_item_by_uid(item.get("uid", ""), false)
			else:
				item["amount"] = cur_amt - remaining
				remaining = 0
		i -= 1
	grid_changed.emit()
	return remaining

func get_item_by_uid(uid: String) -> Dictionary:
	for item in items:
		if item.get("uid", "") == uid:
			return item
	return {}

func get_item_at(grid_x: int, grid_y: int) -> Dictionary:
	if grid_y < 0 or grid_y >= grid_map.size(): return {}
	if grid_x < 0 or grid_x >= grid_map[grid_y].size(): return {}
	
	var uid = grid_map[grid_y][grid_x]
	if uid != "":
		return get_item_by_uid(uid)
	return {}

func find_first_fit(base_w: int, base_h: int, item_id: String = "") -> Dictionary:
	# 1. 정방향 (W x H) 탐색 (0,0부터)
	for y in range(grid_height - base_h + 1):
		for x in range(grid_width - base_w + 1):
			if can_place_item(base_w, base_h, x, y, "", item_id):
				return {"found": true, "x": x, "y": y, "rotated": false}
				
	# 2. 회전방향 (H x W) 탐색 (크기가 다를 때만)
	if base_w != base_h:
		for y in range(grid_height - base_w + 1):
			for x in range(grid_width - base_h + 1):
				if can_place_item(base_h, base_w, x, y, "", item_id):
					return {"found": true, "x": x, "y": y, "rotated": true}
					
	return {"found": false, "x": -1, "y": -1, "rotated": false}

func auto_add_item(id: String, amount: int, custom_data: Dictionary = {}) -> int:
	var resolved_id = ItemDatabase.resolve_item_id(id) if ItemDatabase and ItemDatabase.has_method("resolve_item_id") else id
	var item_data = ItemDatabase.get_item_data(resolved_id)
	var max_stack = int(item_data.get("max_stack", 1))
	var remaining = amount
	
	# 1. 스택 가능한 아이템이면 기존 스택에 먼저 채우기
	if max_stack > 1:
		for item in items:
			if is_same_item_id(String(item.get("id", "")), resolved_id) and int(item.get("amount", 1)) < max_stack:
				var space = max_stack - int(item.get("amount", 1))
				var to_add = min(space, remaining)
				item["amount"] = int(item.get("amount", 1)) + to_add
				remaining -= to_add
				if remaining <= 0:
					grid_changed.emit()
					return 0
					
	# 2. 남은 수량을 빈 공간에 Auto-Fit
	var base_size = ItemDatabase.get_item_grid_size(resolved_id)
	while remaining > 0:
		var fit = find_first_fit(base_size.x, base_size.y, resolved_id)
		if not fit["found"]:
			grid_changed.emit()
			return remaining # 더 이상 넣을 공간 없음
			
		var to_add = min(max_stack, remaining)
		var new_item = {
			"uid": "item_%d_%d" % [Time.get_ticks_msec(), randi() % 10000],
			"id": resolved_id,
			"amount": to_add,
			"w": base_size.x,
			"h": base_size.y,
			"rotated": fit["rotated"]
		}
		if not custom_data.is_empty():
			for k in ["parts", "attachments", "loaded_ammo", "current_magazine_ammo", "computed_stats", "durability", "max_durability", "receiver", "name", "type"]:
				if custom_data.has(k):
					new_item[k] = custom_data[k]
			new_item["custom_data"] = custom_data
		if not new_item.has("durability") and item_data.has("max_durability"):
			new_item["durability"] = item_data["max_durability"]
			
		place_item(new_item, fit["x"], fit["y"], fit["rotated"])
		remaining -= to_add
		
	grid_changed.emit()
	return 0

## 동일 아이템 스택 자동 통합 (최대 스택 한도 준수)
func consolidate_stacks() -> void:
	if items.is_empty(): return
	var changed = false
	var i = 0
	while i < items.size():
		var item = items[i]
		var id = item.get("id", "")
		var item_data = ItemDatabase.get_item_data(id)
		var max_stack = int(item_data.get("max_stack", 1))
		if max_stack > 1 and int(item.get("amount", 1)) < max_stack:
			var cur_amt = int(item.get("amount", 1))
			for j in range(items.size() - 1, i, -1):
				var other = items[j]
				if other.get("id", "") == id and other.get("uid", "") != item.get("uid", ""):
					var space = max_stack - cur_amt
					var other_amt = int(other.get("amount", 1))
					var to_take = min(space, other_amt)
					cur_amt += to_take
					item["amount"] = cur_amt
					other["amount"] = other_amt - to_take
					changed = true
					if other["amount"] <= 0:
						remove_item_by_uid(other.get("uid", ""), false)
					if cur_amt >= max_stack:
						break
		i += 1
	if changed:
		grid_changed.emit()

func resize_grid(new_w: int, new_h: int) -> Array[Dictionary]:
	var dropped_items: Array[Dictionary] = []
	grid_width = max(1, new_w)
	grid_height = max(1, new_h)
	
	# 기존 items 보존 및 재배치
	var old_items = items.duplicate(true)
	items.clear()
	_init_grid_map()
	
	for item in old_items:
		var cur_w = item.get("h", 1) if item.get("rotated", false) else item.get("w", 1)
		var cur_h = item.get("w", 1) if item.get("rotated", false) else item.get("h", 1)
		var ix = item.get("x", 0)
		var iy = item.get("y", 0)
		
		if can_place_item(cur_w, cur_h, ix, iy, "", item.get("id", "")):
			place_item(item, ix, iy, item.get("rotated", false))
		else:
			# 기존 자리에 못 들어가면 빈 자리에 Auto-Fit 시도
			var fit = find_first_fit(item.get("w", 1), item.get("h", 1), item.get("id", ""))
			if fit["found"]:
				place_item(item, fit["x"], fit["y"], fit["rotated"])
			else:
				# 그래도 안 들어가면 가방 밖으로 튕겨나감 (Drop)
				dropped_items.append(item)
				
	grid_changed.emit()
	return dropped_items

func get_total_weight() -> float:
	var total = 0.0
	for item in items:
		var d = ItemDatabase.get_item_data(item.get("id", ""))
		var w = d.get("weight", 0.1)
		var amt = item.get("amount", 1)
		total += w * amt
	return total

func _mark_grid(target_x: int, target_y: int, w: int, h: int, uid: String) -> void:
	for dy in range(h):
		for dx in range(w):
			var gx = target_x + dx
			var gy = target_y + dy
			if gy >= 0 and gy < grid_map.size() and gx >= 0 and gx < grid_map[gy].size():
				grid_map[gy][gx] = uid

func sort_items() -> void:
	if items.is_empty():
		return
	var backup_items = items.duplicate(true)
	
	# 1. 동일 아이템 스택 병합
	var merged: Array[Dictionary] = []
	for raw_item in backup_items:
		var item = raw_item.duplicate(true)
		var id = item.get("id", "")
		var d = ItemDatabase.get_item_data(id)
		var max_stack = int(d.get("max_stack", 1))
		var base_size = ItemDatabase.get_item_grid_size(id)
		item["w"] = base_size.x
		item["h"] = base_size.y
		
		if max_stack > 1:
			var rem = int(item.get("amount", 1))
			for ex in merged:
				if ex.get("id", "") == id and int(ex.get("amount", 1)) < max_stack:
					var space = max_stack - int(ex.get("amount", 1))
					var add = min(space, rem)
					ex["amount"] = int(ex.get("amount", 1)) + add
					rem -= add
					if rem <= 0:
						break
			while rem > 0:
				var chunk = min(max_stack, rem)
				var new_entry = item.duplicate(true)
				new_entry["uid"] = "item_%d_%d" % [Time.get_ticks_msec(), randi() % 100000]
				new_entry["amount"] = chunk
				merged.append(new_entry)
				rem -= chunk
		else:
			merged.append(item)
			
	# 2. 큰 면적 -> 긴 변 -> 이름 순 정렬
	merged.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var area_a = int(a.get("w", 1)) * int(a.get("h", 1))
		var area_b = int(b.get("w", 1)) * int(b.get("h", 1))
		if area_a != area_b:
			return area_a > area_b
		var max_a = max(int(a.get("w", 1)), int(a.get("h", 1)))
		var max_b = max(int(b.get("w", 1)), int(b.get("h", 1)))
		if max_a != max_b:
			return max_a > max_b
		return String(a.get("id", "")) < String(b.get("id", ""))
	)
	
	# 3. 좌상단부터 재배치
	items.clear()
	_init_grid_map()
	var all_placed = true
	for it in merged:
		var bw = int(it.get("w", 1))
		var bh = int(it.get("h", 1))
		var fit = find_first_fit(bw, bh, it.get("id", ""))
		if fit["found"]:
			place_item(it, fit["x"], fit["y"], fit["rotated"])
		else:
			all_placed = false
			break
			
	if not all_placed:
		# 만약 특수한 격자 형태로 인해 모두 들어가지 못했다면 백업 복원
		items = backup_items
		_init_grid_map()
	grid_changed.emit()
