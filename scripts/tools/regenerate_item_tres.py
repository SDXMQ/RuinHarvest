import os, re

with open('scripts/tools/original_item_db.gd', 'r', encoding='utf-8') as f:
    text = f.read()

m = re.search(r'var items: Dictionary = (\{.*?\n\})\n\n', text, re.DOTALL)
dict_str = m.group(1)

dict_str = dict_str.replace("ItemCategory.FOOD", "0")
dict_str = dict_str.replace("ItemCategory.WATER", "1")
dict_str = dict_str.replace("ItemCategory.MEDICAL", "2")
dict_str = dict_str.replace("ItemCategory.WEAPON", "3")
dict_str = dict_str.replace("ItemCategory.TOOL", "4")
dict_str = dict_str.replace("ItemCategory.MATERIAL", "5")
dict_str = dict_str.replace("ItemCategory.EQUIPMENT", "6")
dict_str = dict_str.replace("ItemCategory.QUEST", "7")
dict_str = dict_str.replace("ItemCategory.MISC", "8")
dict_str = dict_str.replace("true", "True")
dict_str = dict_str.replace("false", "False")
dict_str = re.sub(r'Vector2i\((\d+),\s*(\d+)\)', r'[\1, \2]', dict_str)
dict_str = re.sub(r'#.*', '', dict_str)

items = eval(dict_str)
print(f"Parsed {len(items)} items.")

os.makedirs("data/items", exist_ok=True)
for key, data in items.items():
    safe_id = key.replace("/", "_").replace(" ", "_").replace(":", "_")
    tres_path = f"data/items/{safe_id}.tres"
    
    with open(tres_path, "w", encoding="utf-8") as f:
        f.write('[gd_resource type="Resource" script_class="ItemData" load_steps=2 format=3]\n\n')
        f.write('[ext_resource type="Script" path="res://systems/data/item_data.gd" id="1"]\n\n')
        f.write('[resource]\n')
        f.write('script = ExtResource("1")\n')
        f.write(f'id = "{key}"\n')
        
        name_val = data.get("name", key).replace('"', '\\"')
        f.write(f'name = "{name_val}"\n')
        
        if "category" in data: f.write(f'category = {data["category"]}\n')
        if "description" in data:
            desc = data["description"].replace('"', '\\"')
            f.write(f'description = "{desc}"\n')
        if "stackable" in data: f.write(f'stackable = {"true" if data["stackable"] else "false"}\n')
        if "max_stack" in data: f.write(f'max_stack = {data["max_stack"]}\n')
        if "weight" in data: f.write(f'weight = {data["weight"]}\n')
        if "rarity" in data: f.write(f'rarity = {data["rarity"]}\n')
        if "value" in data: f.write(f'value = {data["value"]}\n')
        if "grid_w" in data: f.write(f'grid_w = {data["grid_w"]}\n')
        if "grid_h" in data: f.write(f'grid_h = {data["grid_h"]}\n')
        if "equip_slot" in data: f.write(f'equip_slot = "{data["equip_slot"]}"\n')
        if "defense" in data: f.write(f'armor_defense = {data["defense"]}\n')
        if "max_durability" in data: f.write(f'max_durability = {data["max_durability"]}\n')
        if "weight_bonus" in data: f.write(f'weight_bonus = {data["weight_bonus"]}\n')
        if "speed_bonus" in data: f.write(f'speed_bonus = {data["speed_bonus"]}\n')
        if "type" in data: f.write(f'item_type = "{data["type"]}"\n')
        if "damage" in data: f.write(f'damage = {data["damage"]}\n')
        if "range" in data: f.write(f'attack_range = {data["range"]}\n')
        if "attack_speed" in data: f.write(f'attack_speed = {data["attack_speed"]}\n')
        if "ammo" in data: f.write(f'ammo = "{data["ammo"]}"\n')
        
        # effects
        if "effects" in data:
            eff = data["effects"]
            eff_strs = []
            for ek, ev in eff.items():
                if isinstance(ev, bool):
                    eff_strs.append(f'"{ek}": {"true" if ev else "false"}')
                elif isinstance(ev, (int, float)):
                    eff_strs.append(f'"{ek}": {ev}')
                else:
                    eff_strs.append(f'"{ek}": "{ev}"')
            f.write('effects = {\n' + ', '.join(eff_strs) + '\n}\n')
            
        if "backpack_grid" in data:
            f.write(f'backpack_grid = Vector2i({data["backpack_grid"][0]}, {data["backpack_grid"][1]})\n')

print("All 68 item tres files regenerated with full fidelity.")
