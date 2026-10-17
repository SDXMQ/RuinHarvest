import re

with open("autoload/item_database.gd", "r", encoding="utf-8") as f:
    content = f.read()

# var items: Dictionary = { ... } 덩어리 삭제
new_content = re.sub(r'var items: Dictionary = \{.*?\n\}\n\n', 'var items: Dictionary = {}\n\n', content, flags=re.DOTALL)

# _ready 추가
ready_code = """
func _ready():
	_load_all_items()

func _load_all_items():
	var dir = DirAccess.open("res://data/items/")
	if dir:
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if fname.ends_with(".tres"):
				var res = load("res://data/items/" + fname)
				if res and res is ItemData:
					var d = {
						"category": res.category,
						"description": res.description,
						"stackable": res.stackable,
						"max_stack": res.max_stack,
						"weight": res.weight,
						"rarity": res.rarity,
						"value": res.value,
						"effects": res.effects,
						"equip_slot": res.equip_slot,
						"defense": res.armor_defense,
						"backpack_grid": res.backpack_grid
					}
					# WeaponPartsDatabase 등 호환성을 위한 임시 필드
					if res.category == ItemCategory.WEAPON:
						if res.id == "권총" or res.id == "레버액션 소총":
							d["type"] = "ranged"
							d["ammo"] = "탄약"
						elif "리시버" in res.id:
							d["type"] = "receiver"
						elif res.id == "수류탄":
							d["type"] = "throwable"
						else:
							d["type"] = "melee"
					if res.category == ItemCategory.EQUIPMENT:
						d["grid_w"] = res.grid_size.x
						d["grid_h"] = res.grid_size.y
					items[res.id] = d
			fname = dir.get_next()

"""

new_content = new_content.replace('var items: Dictionary = {}\n\n', 'var items: Dictionary = {}\n\n' + ready_code)

with open("autoload/item_database.gd", "w", encoding="utf-8") as f:
    f.write(new_content)
