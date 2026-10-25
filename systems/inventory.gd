# res://systems/inventory.gd
class_name Inventory
extends Node

## 인벤토리 시스템 (플레이어 및 루팅 상자 공용)

signal inventory_changed

@export var max_slots: int = 12
# 배열 요소: {"id": "item_id", "amount": 1}
var items: Array = []

func _ready() -> void:
	if items.is_empty():
		clear()

func clear() -> void:
	items.clear()
	items.resize(max_slots)
	for i in range(max_slots):
		items[i] = null
	inventory_changed.emit()

func load_items(item_list: Array) -> void:
	items.resize(max_slots)
	for i in range(max_slots):
		if i < item_list.size() and item_list[i] != null:
			items[i] = item_list[i].duplicate()
		else:
			items[i] = null
	inventory_changed.emit()

func get_item_count(id: String) -> int:
	var total = 0
	for item in items:
		if item and item["id"] == id:
			total += item["amount"]
	return total

func add_item(id: String, amount: int) -> int:
	var item_data = ItemDatabase.get_item_data(id)
	if item_data.is_empty(): return amount
	
	var max_stack = item_data.get("max_stack", 1)
	var remaining = amount
	
	# 1. 기존 스택 채우기
	for i in range(max_slots):
		var slot = items[i]
		if slot != null and slot["id"] == id and slot["amount"] < max_stack:
			var space = max_stack - slot["amount"]
			var to_add = min(space, remaining)
			slot["amount"] += to_add
			remaining -= to_add
			if remaining <= 0:
				inventory_changed.emit()
				return 0
				
	# 2. 빈 슬롯에 넣기
	for i in range(max_slots):
		if items[i] == null:
			var to_add = min(max_stack, remaining)
			var item_dict = {"id": id, "amount": to_add}
			if item_data.has("max_durability"):
				item_dict["durability"] = item_data["max_durability"]
			items[i] = item_dict
			remaining -= to_add
			if remaining <= 0:
				inventory_changed.emit()
				return 0
				
	inventory_changed.emit()
	return remaining # 남은 잉여 수량 리턴

func remove_item_at(index: int, amount: int) -> bool:
	if index < 0 or index >= max_slots: return false
	var slot = items[index]
	if slot == null: return false
	
	if slot["amount"] > amount:
		slot["amount"] -= amount
	else:
		items[index] = null
		
	inventory_changed.emit()
	return true
	
func move_item(from_index: int, to_index: int, target_inv: Inventory = null) -> bool:
	if from_index < 0 or from_index >= max_slots: return false
	
	if target_inv == null:
		target_inv = self
		
	if to_index < 0 or to_index >= target_inv.max_slots: return false
	
	var src_item = items[from_index]
	if src_item == null: return false
	
	var dest_item = target_inv.items[to_index]
	
	if dest_item == null:
		target_inv.items[to_index] = src_item.duplicate()
		items[from_index] = null
	elif dest_item["id"] == src_item["id"]:
		var item_data = ItemDatabase.get_item_data(dest_item["id"])
		var max_stack = item_data.get("max_stack", 1)
		var space = max_stack - dest_item["amount"]
		if space >= src_item["amount"]:
			dest_item["amount"] += src_item["amount"]
			items[from_index] = null
		else:
			dest_item["amount"] = max_stack
			src_item["amount"] -= space
	else:
		# Swap
		target_inv.items[to_index] = src_item
		items[from_index] = dest_item
		
	inventory_changed.emit()
	if target_inv != self:
		target_inv.inventory_changed.emit()
		
	return true
