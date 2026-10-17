import re
import os
import json

with open("autoload/item_database.gd", "r", encoding="utf-8") as f:
    content = f.read()

# var items: Dictionary = { ... } 부분 추출
match = re.search(r'var items: Dictionary = (\{.*?\n\})', content, re.DOTALL)
if not match:
    print("Could not find items dict")
    exit(1)

dict_str = match.group(1)

# GDScript 딕셔너리를 Python 딕셔너리로 평가할 수 있게 약간의 변환
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

# 주석 제거
dict_str = re.sub(r'#.*', '', dict_str)

try:
    items = eval(dict_str)
except Exception as e:
    print("Error parsing:", e)
    # 수동으로라도 대충 정규식 추출
    items = {}

if items:
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
            
            if "category" in data: f.write(f'category = {data["category"]}\n')
            if "description" in data: 
                desc = data["description"].replace('"', '\\"')
                f.write(f'description = "{desc}"\n')
            if "stackable" in data: f.write(f'stackable = {"true" if data["stackable"] else "false"}\n')
            if "max_stack" in data: f.write(f'max_stack = {data["max_stack"]}\n')
            if "weight" in data: f.write(f'weight = {data["weight"]}\n')
            if "rarity" in data: f.write(f'rarity = {data["rarity"]}\n')
            if "value" in data: f.write(f'value = {data["value"]}\n')
            if "equip_slot" in data: f.write(f'equip_slot = "{data["equip_slot"]}"\n')
            if "defense" in data: f.write(f'armor_defense = {data["defense"]}\n')
            
            if "effects" in data:
                f.write('effects = {\n')
                effs = []
                for k, v in data["effects"].items():
                    val_str = "true" if v is True else "false" if v is False else str(v)
                    effs.append(f'"{k}": {val_str}')
                f.write(", ".join(effs) + '\n}\n')
                
            if "backpack_grid" in data:
                f.write(f'backpack_grid = Vector2i({data["backpack_grid"][0]}, {data["backpack_grid"][1]})\n')
                
        print(f"Created {tres_path}")
