# res://systems/inventory_grid.gd
class_name InventoryGrid
extends Node

## 타르코프식 2D WxH 점유 맵 그리드 인벤토리 시스템

signal grid_changed

@export var grid_width: int = 6
@export var grid_height: int = 4
@export var has_secure_container: bool = false
@export var container_depth: int = 0
@export var owner_container_uid: String = ""
@export var allowed_filter: String = ""

static var _uid_counter: int = 0

const PRESERVED_CUSTOM_KEYS: Array[String] = [
	"parts", "attachments", "loaded_ammo", "current_magazine_ammo",
	"computed_stats", "durability", "max_durability", "receiver",
	"name", "type", "inner_items", "inner_grid_w", "inner_grid_h", "locked"
]

static func next_uid() -> String:
	_uid_counter += 1
	return "item_%d" % _uid_counter

static func _sync_uid_counter_for_uid(uid_str: String) -> void:
	if uid_str.begins_with("item_"):
		var num_str := uid_str.substr(5)
		if num_str.is_valid_int():
			_uid_counter = maxi(_uid_counter, num_str.to_int())

static func sync_uid_counter_from_items(item_list: Array) -> void:
	for it in item_list:
		if not (it is Dictionary):
			continue
		var u := String(it.get("uid", ""))
		if u != "":
			_sync_uid_counter_for_uid(u)
		var inner = it.get("inner_items", [])
		if inner is Array and not inner.is_empty():
			sync_uid_counter_from_items(inner)

static func is_same_item_id(a: String, b: String) -> bool:
	if a == b:
		return true
	var na = a.replace("_", " ").strip_edges()
	var nb = b.replace("_", " ").strip_edges()
	if na == nb:
		return true
	if (na == "9mm" or na == "탄약" or na == "9mm 탄약") and (nb == "9mm" or nb == "탄약" or nb == "9mm 탄약"):
		return true
	if (na == "군용 나침반" or na == "나침반") and (nb == "군용 나침반" or nb == "나침반"):
		return true
	if (na == "기밀 SSD" or na == "암호화된 SSD") and (nb == "기밀 SSD" or nb == "암호화된 SSD"):
		return true
	if na in ["무전기", "군용 무전기", "장거리 무전기"] and nb in ["무전기", "군용 무전기", "장거리 무전기"]:
		return true
	return false

static func get_container_spec(item_or_id) -> Dictionary:
	var item_id := ""
	var item_dict: Dictionary = {}
	if item_or_id is Dictionary:
		item_dict = item_or_id
		item_id = str(item_dict.get("id", ""))
	else:
		item_id = str(item_or_id)
	if item_id == "":
		return {"is_container": false, "grid_w": 0, "grid_h": 0, "allowed_filter": "", "kind": ""}
	var resolved := ItemDatabase.resolve_item_id(item_id) if ItemDatabase and ItemDatabase.has_method("resolve_item_id") else item_id
	var data: Dictionary = ItemDatabase.get_item_data(resolved) if ItemDatabase else {}
	var item_type := str(data.get("type", item_dict.get("type", "")))
	var eq_slot := str(data.get("equip_slot", ""))

	if item_type == "storage_case" or resolved in ["탄약 케이스", "의약품 케이스", "무기 부품 상자", "인식표 지갑"]:
		var ig = data.get("inner_grid", Vector2i(6, 6))
		var gw := int(item_dict.get("inner_grid_w", ig.x if ig is Vector2i else 6))
		var gh := int(item_dict.get("inner_grid_h", ig.y if ig is Vector2i else 6))
		return {
			"is_container": true,
			"grid_w": maxi(1, gw),
			"grid_h": maxi(1, gh),
			"allowed_filter": str(data.get("allowed_filter", "")),
			"kind": "case"
		}
	if eq_slot == "backpack" or resolved.contains("가방") or resolved.contains("배낭"):
		var bg = data.get("backpack_grid", data.get("inner_grid", Vector2i(6, 5)))
		var gw := int(item_dict.get("inner_grid_w", bg.x if bg is Vector2i else 6))
		var gh := int(item_dict.get("inner_grid_h", bg.y if bg is Vector2i else 5))
		return {
			"is_container": true,
			"grid_w": maxi(1, gw),
			"grid_h": maxi(1, gh),
			"allowed_filter": "",
			"kind": "backpack"
		}
	if eq_slot == "vest" or resolved.contains("방탄") or resolved.contains("조끼"):
		var rg = data.get("rig_grid", data.get("inner_grid", Vector2i(3, 2)))
		var gw := int(item_dict.get("inner_grid_w", rg.x if rg is Vector2i else 3))
		var gh := int(item_dict.get("inner_grid_h", rg.y if rg is Vector2i else 2))
		return {
			"is_container": true,
			"grid_w": maxi(1, gw),
			"grid_h": maxi(1, gh),
			"allowed_filter": "",
			"kind": "vest"
		}
	return {"is_container": false, "grid_w": 0, "grid_h": 0, "allowed_filter": "", "kind": ""}

static func is_container_item(item_or_id) -> bool:
	return bool(get_container_spec(item_or_id).get("is_container", false))

static func is_item_allowed_by_filter(item_id: String, filter_kind: String) -> bool:
	if filter_kind == "" or item_id == "":
		return true
	var resolved := ItemDatabase.resolve_item_id(item_id) if ItemDatabase and ItemDatabase.has_method("resolve_item_id") else item_id
	var data: Dictionary = ItemDatabase.get_item_data(resolved) if ItemDatabase else {}
	var item_type := str(data.get("type", ""))
	var cat := int(data.get("category", -1))
	match filter_kind:
		"ammo":
			return (ItemDatabase and ItemDatabase.is_ammo_item(resolved)) or item_type == "ammo" or (WeaponPartsDatabase and WeaponPartsDatabase.AMMO_TYPES.has(resolved))
		"medical":
			return cat == ItemDatabase.ItemCategory.MEDICAL
		"weapon_part":
			return (WeaponPartsDatabase and WeaponPartsDatabase.PARTS.has(resolved)) or item_type == "part"
		"dogtag_key":
			return (
				item_type in ["dogtag", "key", "keycard"]
				or resolved in ["Scav 인식표", "Scav 식별줄(Dogtag)", "무기고 열쇠", "보안 키카드"]
				or resolved.contains("인식표")
				or resolved.contains("식별줄")
				or resolved.contains("열쇠")
				or resolved.contains("키카드")
			)
	return true

static func has_nested_container_inside(item: Dictionary) -> bool:
	var inner = item.get("inner_items", [])
	if not (inner is Array):
		return false
	for sub in inner:
		if sub is Dictionary and not sub.is_empty():
			if is_container_item(sub) or has_nested_container_inside(sub):
				return true
	return false

static func sanitize_inner_items_array(raw_arr: Array) -> Array:
	var out: Array = []
	for entry in raw_arr:
		if not (entry is Dictionary) or not entry.has("id"):
			continue
		var sub: Dictionary = entry.duplicate(true)
		var sid := str(sub.get("id", ""))
		if sid == "탄약":
			sid = "9mm"
			sub["id"] = sid
		elif sid == "나침반":
			sid = "군용 나침반"
			sub["id"] = sid
		if not sub.has("uid") or str(sub["uid"]) == "":
			sub["uid"] = next_uid()
		if ItemDatabase:
			var bsize := ItemDatabase.get_item_grid_size(sid)
			sub["w"] = bsize.x
			sub["h"] = bsize.y
		if sub.get("custom_data") is Dictionary:
			sub["custom_data"] = sanitize_custom_data(sub["custom_data"])
		if sub.get("inner_items") is Array:
			sub["inner_items"] = sanitize_inner_items_array(sub["inner_items"])
		out.append(sub)
	return out

static func ensure_container_defaults(item: Dictionary) -> void:
	if item.is_empty():
		return
	var spec := get_container_spec(item)
	if bool(spec.get("is_container", false)):
		item["inner_grid_w"] = int(spec["grid_w"])
		item["inner_grid_h"] = int(spec["grid_h"])
		if not item.has("inner_items") or not (item["inner_items"] is Array):
			item["inner_items"] = []
		else:
			item["inner_items"] = sanitize_inner_items_array(item["inner_items"])

static func get_item_total_weight(item: Dictionary) -> float:
	if item.is_empty():
		return 0.0
	var item_id := str(item.get("id", ""))
	var amt := maxi(1, int(item.get("amount", 1)))
	var unit_w := 0.1
	if item.get("computed_stats") is Dictionary and item["computed_stats"].has("weight"):
		unit_w = float(item["computed_stats"]["weight"])
	elif ItemDatabase:
		var d: Dictionary = ItemDatabase.get_item_data(item_id)
		unit_w = float(d.get("weight", 0.1))
	var total := unit_w * float(amt)
	var inner = item.get("inner_items", [])
	if inner is Array:
		for sub in inner:
			if sub is Dictionary and not sub.is_empty():
				total += get_item_total_weight(sub)
	return total

static func sync_container_item_contents(container_item: Dictionary, inner_grid: InventoryGrid) -> void:
	if container_item.is_empty() or inner_grid == null:
		return
	container_item["inner_items"] = inner_grid.items.duplicate(true)
	container_item["inner_grid_w"] = inner_grid.grid_width
	container_item["inner_grid_h"] = inner_grid.grid_height
	if container_item.get("custom_data") is Dictionary:
		container_item["custom_data"].erase("inner_items")

static func sanitize_custom_data(raw_data: Dictionary) -> Dictionary:
	if raw_data.is_empty():
		return {}
	var clean: Dictionary = raw_data.duplicate(true)
	while clean.get("custom_data") is Dictionary:
		var inner: Dictionary = clean["custom_data"]
		clean.erase("custom_data")
		for k in inner.keys():
			if not clean.has(k):
				clean[k] = inner[k]
	for k in ["uid", "x", "y", "w", "h", "rotated", "id", "amount", "custom_data"]:
		clean.erase(k)
	if clean.get("inner_items") is Array:
		clean["inner_items"] = sanitize_inner_items_array(clean["inner_items"])
	return clean

func can_accept_item(item: Dictionary, item_id_fallback: String = "") -> Dictionary:
	var uid := str(item.get("uid", ""))
	var check_id := str(item.get("id", item_id_fallback))
	if owner_container_uid != "" and uid != "" and uid == owner_container_uid:
		return {"ok": false, "reason": "self_drop"}
	if container_depth >= 1 and check_id != "" and is_container_item(check_id):
		return {"ok": false, "reason": "max_depth_exceeded"}
	if container_depth == 0 and not item.is_empty() and has_nested_container_inside(item):
		return {"ok": false, "reason": "max_depth_exceeded"}
	if allowed_filter != "" and check_id != "" and not is_item_allowed_by_filter(check_id, allowed_filter):
		return {"ok": false, "reason": "filter_mismatch"}
	return {"ok": true, "reason": ""}

func is_item_in_secure_zone(item: Dictionary) -> bool:
	if not has_secure_container or item.is_empty():
		return false
	var ix := int(item.get("x", 99))
	var iy := int(item.get("y", 99))
	var is_rot := bool(item.get("rotated", false))
	var base_size := ItemDatabase.get_item_grid_size(str(item.get("id", ""))) if ItemDatabase else Vector2i(int(item.get("w", 1)), int(item.get("h", 1)))
	var w := base_size.y if is_rot else base_size.x
	var h := base_size.x if is_rot else base_size.y
	return ix >= 0 and iy >= 0 and ix < 2 and iy < 2 and ix + w <= 2 and iy + h <= 2

func toggle_item_lock(uid: String) -> bool:
	var item := get_item_by_uid(uid)
	if item.is_empty():
		return false
	var next_state := not bool(item.get("locked", false))
	item["locked"] = next_state
	grid_changed.emit()
	return next_state

func is_allowed_in_secure_container(item_id: String) -> bool:
	if item_id == "":
		return true
	var data = ItemDatabase.get_item_data(item_id)
	var item_type = str(data.get("type", ""))
	if item_type in ["key", "keycard", "dogtag"] or item_id.contains("열쇠") or item_id.contains("키카드") or item_id.contains("인식표") or str(data.get("allowed_filter", "")) == "dogtag_key":
		return true
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
	sync_uid_counter_from_items(saved_items)
	for it in saved_items:
		if not (it is Dictionary) or not it.has("id"): continue
		var item = it.duplicate(true)
		if String(item["id"]) == "탄약":
			item["id"] = "9mm"
		elif String(item["id"]) == "나침반":
			item["id"] = "군용 나침반"
		var ix: int = int(item.get("x", -1))
		var iy: int = int(item.get("y", -1))
		var is_rot = item.get("rotated", false)
		var base_size = ItemDatabase.get_item_grid_size(item["id"])
		var cur_w = base_size.y if is_rot else base_size.x
		var cur_h = base_size.x if is_rot else base_size.y
		item["w"] = base_size.x
		item["h"] = base_size.y
		if item.get("custom_data") is Dictionary:
			item["custom_data"] = sanitize_custom_data(item["custom_data"])
		if item.get("inner_items") is Array:
			item["inner_items"] = sanitize_inner_items_array(item["inner_items"])
		ensure_container_defaults(item)
		if not item.has("uid") or String(item["uid"]) == "":
			item["uid"] = next_uid()
		
		# 원래 좌표에 배치 가능하면 그대로 배치
		if ix >= 0 and iy >= 0 and can_place_item(cur_w, cur_h, ix, iy, "", item["id"], item):
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

func _can_place_in_map(target_map: Array, w: int, h: int, target_x: int, target_y: int, ignore_uid: String = "", check_id: String = "", probe_dict: Dictionary = {}) -> bool:
	if target_x < 0 or target_y < 0:
		return false
	if target_x + w > grid_width or target_y + h > grid_height:
		return false

	var accept_res := can_accept_item(probe_dict, check_id)
	if not bool(accept_res.get("ok", true)):
		return false

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
			if gy >= target_map.size() or gx >= target_map[gy].size():
				return false
			var occ = target_map[gy][gx]
			if occ != "" and occ != ignore_uid:
				return false

	return true

func can_place_item(w: int, h: int, target_x: int, target_y: int, ignore_uid: String = "", item_id: String = "", item_dict: Dictionary = {}) -> bool:
	var check_id = item_id
	var probe_dict: Dictionary = item_dict
	if check_id == "" and ignore_uid != "":
		var existing = get_item_by_uid(ignore_uid)
		check_id = existing.get("id", "")
		if probe_dict.is_empty():
			probe_dict = existing
	return _can_place_in_map(grid_map, w, h, target_x, target_y, ignore_uid, check_id, probe_dict)

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
		uid = next_uid()
		item["uid"] = uid
	else:
		_sync_uid_counter_for_uid(String(uid))
		
	if not can_place_item(actual_w, actual_h, target_x, target_y, uid, item_id, item):
		return false
		
	# 기존 아이템 목록에 있으면 제거 후 재배치
	remove_item_by_uid(uid, false)
	
	# custom_data 내부 핵심 속성을 최상위로 승격 및 재귀 중첩 제거 (기존 최상위 값이 있으면 보존)
	var cdata = item.get("custom_data", {})
	if cdata is Dictionary and not cdata.is_empty():
		var clean_c := sanitize_custom_data(cdata)
		for k in PRESERVED_CUSTOM_KEYS:
			if not item.has(k) and clean_c.has(k):
				item[k] = clean_c[k].duplicate(true) if (clean_c[k] is Dictionary or clean_c[k] is Array) else clean_c[k]
		clean_c.erase("inner_items")
		clean_c.erase("inner_grid_w")
		clean_c.erase("inner_grid_h")
		item["custom_data"] = clean_c
	if not item.has("durability") and item_data.has("max_durability"):
		item["durability"] = item_data["max_durability"]
	
	item["x"] = target_x
	item["y"] = target_y
	item["w"] = w
	item["h"] = h
	item["rotated"] = rotated
	if not item.has("amount"):
		item["amount"] = 1
	ensure_container_defaults(item)
		
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
	
	if not can_place_item(actual_w, actual_h, target_x, target_y, uid, item_id, item):
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

func _count_item_recursive(item_list: Array, id: String) -> int:
	var total := 0
	for item in item_list:
		if not (item is Dictionary) or item.is_empty():
			continue
		if is_same_item_id(String(item.get("id", "")), id):
			total += int(item.get("amount", 1))
		var inner = item.get("inner_items", [])
		if inner is Array and not inner.is_empty():
			total += _count_item_recursive(inner, id)
	return total

func get_item_count(id: String) -> int:
	return _count_item_recursive(items, id)

func has_item(id: String, amount: int = 1) -> bool:
	return get_item_count(id) >= amount

func remove_item(id: String, amount: int = 1) -> int:
	var remaining = amount
	var i = items.size() - 1
	while i >= 0 and remaining > 0:
		var item = items[i]
		if is_same_item_id(String(item.get("id", "")), id):
			var cur_amt = int(item.get("amount", 1))
			if cur_amt <= remaining:
				remaining -= cur_amt
				remove_item_by_uid(item.get("uid", ""), false)
			else:
				item["amount"] = cur_amt - remaining
				remaining = 0
		i -= 1
	if remaining > 0:
		for container_it in items:
			if remaining <= 0:
				break
			var inner = container_it.get("inner_items", [])
			if inner is Array and not inner.is_empty():
				for j in range(inner.size() - 1, -1, -1):
					if remaining <= 0:
						break
					var sub = inner[j]
					if sub is Dictionary and is_same_item_id(String(sub.get("id", "")), id):
						var s_amt := int(sub.get("amount", 1))
						if s_amt <= remaining:
							remaining -= s_amt
							inner.remove_at(j)
						else:
							sub["amount"] = s_amt - remaining
							remaining = 0
	grid_changed.emit()
	return remaining

func get_item_by_uid(uid: String) -> Dictionary:
	for item in items:
		if item.get("uid", "") == uid:
			return item
	return {}

func _find_item_recursive_in_list(item_list: Array, pred: Callable, parent_item: Dictionary = {}) -> Dictionary:
	for it in item_list:
		if not (it is Dictionary) or it.is_empty():
			continue
		if pred.call(it):
			return {
				"found": true,
				"item": it,
				"parent_container": parent_item,
				"is_nested": not parent_item.is_empty()
			}
		var inner = it.get("inner_items", [])
		if inner is Array and not inner.is_empty():
			var nested := _find_item_recursive_in_list(inner, pred, it)
			if bool(nested.get("found", false)):
				return nested
	return {"found": false, "item": {}, "parent_container": {}, "is_nested": false}

func find_item_recursive_by_predicate(pred: Callable) -> Dictionary:
	return _find_item_recursive_in_list(items, pred)

func _collect_items_flat_in_list(item_list: Array, out: Array[Dictionary], include_nested: bool) -> void:
	for it in item_list:
		if not (it is Dictionary) or it.is_empty():
			continue
		out.append(it)
		if include_nested:
			var inner = it.get("inner_items", [])
			if inner is Array and not inner.is_empty():
				_collect_items_flat_in_list(inner, out, true)

func get_all_items_flat(include_nested: bool = true) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_collect_items_flat_in_list(items, out, include_nested)
	return out

func remove_item_by_uid_recursive(uid: String, should_emit: bool = true) -> Dictionary:
	if uid == "":
		return {}
	var top_removed := remove_item_by_uid(uid, false)
	if not top_removed.is_empty():
		if should_emit:
			grid_changed.emit()
		return top_removed
	var removed := _remove_uid_from_nested_lists(items, uid)
	if not removed.is_empty() and should_emit:
		grid_changed.emit()
	return removed

func _remove_uid_from_nested_lists(item_list: Array, uid: String) -> Dictionary:
	for it in item_list:
		if not (it is Dictionary) or it.is_empty():
			continue
		var inner = it.get("inner_items", [])
		if inner is Array and not inner.is_empty():
			for j in range(inner.size()):
				var sub = inner[j]
				if sub is Dictionary and str(sub.get("uid", "")) == uid:
					var popped: Dictionary = sub
					inner.remove_at(j)
					return popped
			var deeper := _remove_uid_from_nested_lists(inner, uid)
			if not deeper.is_empty():
				return deeper
	return {}

func consume_items_matching(pred: Callable, amount: int, should_emit: bool = true) -> int:
	if amount <= 0:
		return 0
	var taken := 0
	var i := items.size() - 1
	while i >= 0 and taken < amount:
		var it: Dictionary = items[i]
		if not it.is_empty() and pred.call(it):
			var amt := maxi(1, int(it.get("amount", 1)))
			var take := mini(amt, amount - taken)
			taken += take
			if amt - take <= 0:
				remove_item_by_uid(str(it.get("uid", "")), false)
			else:
				it["amount"] = amt - take
		i -= 1
	if taken < amount:
		taken += _consume_matching_in_nested(items, pred, amount - taken)
	if taken > 0 and should_emit:
		grid_changed.emit()
	return taken

func _consume_matching_in_nested(item_list: Array, pred: Callable, needed: int) -> int:
	var taken := 0
	for container_it in item_list:
		if taken >= needed:
			break
		if not (container_it is Dictionary) or container_it.is_empty():
			continue
		var inner = container_it.get("inner_items", [])
		if inner is Array and not inner.is_empty():
			for j in range(inner.size() - 1, -1, -1):
				if taken >= needed:
					break
				var sub = inner[j]
				if sub is Dictionary and not sub.is_empty():
					if pred.call(sub):
						var s_amt := maxi(1, int(sub.get("amount", 1)))
						var take := mini(s_amt, needed - taken)
						taken += take
						if s_amt - take <= 0:
							inner.remove_at(j)
						else:
							sub["amount"] = s_amt - take
					else:
						var sub_inner = sub.get("inner_items", [])
						if sub_inner is Array and not sub_inner.is_empty():
							taken += _consume_matching_in_nested([sub], pred, needed - taken)
	return taken

func get_item_at(grid_x: int, grid_y: int) -> Dictionary:
	if grid_y < 0 or grid_y >= grid_map.size(): return {}
	if grid_x < 0 or grid_x >= grid_map[grid_y].size(): return {}
	
	var uid = grid_map[grid_y][grid_x]
	if uid != "":
		return get_item_by_uid(uid)
	return {}

func find_first_fit(base_w: int, base_h: int, item_id: String = "", item_dict: Dictionary = {}) -> Dictionary:
	# 1. 정방향 (W x H) 탐색 (0,0부터)
	for y in range(grid_height - base_h + 1):
		for x in range(grid_width - base_w + 1):
			if can_place_item(base_w, base_h, x, y, "", item_id, item_dict):
				return {"found": true, "x": x, "y": y, "rotated": false}
				
	# 2. 회전방향 (H x W) 탐색 (크기가 다를 때만)
	if base_w != base_h:
		for y in range(grid_height - base_w + 1):
			for x in range(grid_width - base_h + 1):
				if can_place_item(base_h, base_w, x, y, "", item_id, item_dict):
					return {"found": true, "x": x, "y": y, "rotated": true}
					
	return {"found": false, "x": -1, "y": -1, "rotated": false}

func can_fit_item(id: String, amount: int = 1, custom_data: Dictionary = {}) -> bool:
	if amount <= 0:
		return true
	var resolved_id = ItemDatabase.resolve_item_id(id) if ItemDatabase and ItemDatabase.has_method("resolve_item_id") else id
	var item_data = ItemDatabase.get_item_data(resolved_id)
	var max_stack = maxi(1, int(item_data.get("max_stack", 1)))
	var remaining = amount

	var probe_dict: Dictionary = custom_data.duplicate(true) if not custom_data.is_empty() else {}
	probe_dict["id"] = resolved_id
	var accept_res := can_accept_item(probe_dict, resolved_id)
	if not bool(accept_res.get("ok", true)):
		return false

	if max_stack > 1:
		for item in items:
			if is_same_item_id(String(item.get("id", "")), resolved_id) and int(item.get("amount", 1)) < max_stack:
				remaining -= (max_stack - int(item.get("amount", 1)))
				if remaining <= 0:
					return true

	var sim_map: Array = []
	for row in grid_map:
		sim_map.append(row.duplicate())

	var base_size := ItemDatabase.get_item_grid_size(resolved_id)
	var stack_idx := 0
	while remaining > 0:
		var fit := {"found": false, "x": -1, "y": -1, "w": base_size.x, "h": base_size.y}
		for y in range(grid_height - base_size.y + 1):
			for x in range(grid_width - base_size.x + 1):
				if _can_place_in_map(sim_map, base_size.x, base_size.y, x, y, "", resolved_id, probe_dict):
					fit = {"found": true, "x": x, "y": y, "w": base_size.x, "h": base_size.y}
					break
			if fit["found"]:
				break
		if not fit["found"] and base_size.x != base_size.y:
			for y in range(grid_height - base_size.x + 1):
				for x in range(grid_width - base_size.y + 1):
					if _can_place_in_map(sim_map, base_size.y, base_size.x, x, y, "", resolved_id, probe_dict):
						fit = {"found": true, "x": x, "y": y, "w": base_size.y, "h": base_size.x}
						break
				if fit["found"]:
					break
		if not fit["found"]:
			return false
		stack_idx += 1
		var mark_uid := "__sim_%d__" % stack_idx
		for dy in range(int(fit["h"])):
			for dx in range(int(fit["w"])):
				sim_map[int(fit["y"]) + dy][int(fit["x"]) + dx] = mark_uid
		remaining -= mini(max_stack, remaining)

	return true

func auto_add_item(id: String, amount: int, custom_data: Dictionary = {}) -> int:
	var resolved_id = ItemDatabase.resolve_item_id(id) if ItemDatabase and ItemDatabase.has_method("resolve_item_id") else id
	var item_data = ItemDatabase.get_item_data(resolved_id)
	var max_stack = int(item_data.get("max_stack", 1))
	var remaining = amount
	
	var probe_dict: Dictionary = custom_data.duplicate(true) if not custom_data.is_empty() else {}
	probe_dict["id"] = resolved_id
	var accept_res := can_accept_item(probe_dict, resolved_id)
	if not bool(accept_res.get("ok", true)):
		return remaining
	
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
	var clean_custom := sanitize_custom_data(custom_data)
	var base_size = ItemDatabase.get_item_grid_size(resolved_id)
	while remaining > 0:
		var fit = find_first_fit(base_size.x, base_size.y, resolved_id, probe_dict)
		if not fit["found"]:
			grid_changed.emit()
			return remaining # 더 이상 넣을 공간 없음
			
		var to_add = min(max_stack, remaining)
		var new_item = {
			"uid": next_uid(),
			"id": resolved_id,
			"amount": to_add,
			"w": base_size.x,
			"h": base_size.y,
			"rotated": fit["rotated"]
		}
		if not clean_custom.is_empty():
			for k in PRESERVED_CUSTOM_KEYS:
				if clean_custom.has(k):
					new_item[k] = clean_custom[k].duplicate(true) if (clean_custom[k] is Dictionary or clean_custom[k] is Array) else clean_custom[k]
			var stripped_cd := clean_custom.duplicate(true)
			stripped_cd.erase("inner_items")
			stripped_cd.erase("inner_grid_w")
			stripped_cd.erase("inner_grid_h")
			new_item["custom_data"] = stripped_cd
		if not new_item.has("durability") and item_data.has("max_durability"):
			new_item["durability"] = item_data["max_durability"]
		ensure_container_defaults(new_item)
			
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
		
		if can_place_item(cur_w, cur_h, ix, iy, "", item.get("id", ""), item):
			place_item(item, ix, iy, item.get("rotated", false))
		else:
			# 기존 자리에 못 들어가면 빈 자리에 Auto-Fit 시도
			var fit = find_first_fit(item.get("w", 1), item.get("h", 1), item.get("id", ""), item)
			if fit["found"]:
				place_item(item, fit["x"], fit["y"], fit["rotated"])
			else:
				# 그래도 안 들어가면 가방 밖으로 튕겨나감 (Drop)
				dropped_items.append(item)
				
	grid_changed.emit()
	return dropped_items

func get_total_weight() -> float:
	var total := 0.0
	for item in items:
		total += get_item_total_weight(item)
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
	
	# 안전 컨테이너(has_secure_container)가 활성화되어 있으면,
	# 2x2 안전 파우치 구역 내부(x < 2, y < 2, x+w <= 2, y+h <= 2)에 있는 아이템은 정렬 대상에서 제외하고 위치를 보존
	var pouch_items: Array[Dictionary] = []
	var sortable_items: Array[Dictionary] = []
	
	if has_secure_container:
		for it in backup_items:
			var ix = int(it.get("x", 99))
			var iy = int(it.get("y", 99))
			var is_rot = it.get("rotated", false)
			var base_size = ItemDatabase.get_item_grid_size(it.get("id", ""))
			var w = base_size.y if is_rot else base_size.x
			var h = base_size.x if is_rot else base_size.y
			if ix < 2 and iy < 2 and ix + w <= 2 and iy + h <= 2:
				pouch_items.append(it.duplicate(true))
			else:
				sortable_items.append(it.duplicate(true))
	else:
		sortable_items = backup_items.duplicate(true)
	
	# 1. 동일 아이템 스택 병합 (일반 가방 아이템 대상)
	var merged: Array[Dictionary] = []
	for raw_item in sortable_items:
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
				new_entry["uid"] = next_uid()
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
	
	# 3. 파우치 아이템 먼저 원래 위치에 배치한 후, 남은 공간에 일반 아이템 자동 배치
	items.clear()
	_init_grid_map()
	for it in pouch_items:
		place_item(it, int(it["x"]), int(it["y"]), it.get("rotated", false))
		
	var all_placed = true
	for it in merged:
		var bw = int(it.get("w", 1))
		var bh = int(it.get("h", 1))
		var fit = find_first_fit(bw, bh, it.get("id", ""), it)
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
