extends SceneTree

func _init():
	print("Starting item migration...")
	var db = load("res://autoload/item_database.gd").new()
	var ItemData = load("res://systems/data/item_data.gd")
	var items = db.items
	var count = 0
	
	for id in items.keys():
		var data = items[id]
		var item = ItemData.new(id)
		if data.has("category"): item.category = data.category
		if data.has("description"): item.description = data.description
		if data.has("stackable"): item.stackable = data.stackable
		if data.has("max_stack"): item.max_stack = data.max_stack
		if data.has("weight"): item.weight = data.weight
		if data.has("rarity"): item.rarity = data.rarity
		if data.has("value"): item.value = data.value
		if data.has("effects"): item.effects = data.effects
		if data.has("equip_slot"): item.equip_slot = data.equip_slot
		if data.has("defense"): item.armor_defense = data.defense
		if data.has("backpack_grid"): item.backpack_grid = data.backpack_grid
		
		# 추가 필드들
		if data.has("grid_w") and data.has("grid_h"): 
			pass # grid_size를 ItemData에 정의해 두었지만 현재는 무시 또는 나중에 확장
			
		var safe_id = id.replace("/", "_").replace(" ", "_").replace(":", "_")
		var err = ResourceSaver.save(item, "res://data/items/" + safe_id + ".tres")
		if err == OK:
			count += 1
		else:
			print("Error saving: ", id)
			
	print("Migration complete! Saved ", count, " items.")
	quit()
