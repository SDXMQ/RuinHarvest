import os, re

# Simulate ItemDatabase loading and check compatibility with original item database
with open('scripts/tools/original_item_db.gd', 'r', encoding='utf-8') as f:
    text = f.read()

m = re.search(r'var items: Dictionary = (\{.*?\n\})\n\n', text, re.DOTALL)
dict_str = m.group(1)
dict_str = dict_str.replace("ItemCategory.FOOD", "0").replace("ItemCategory.WATER", "1")
dict_str = dict_str.replace("ItemCategory.MEDICAL", "2").replace("ItemCategory.WEAPON", "3")
dict_str = dict_str.replace("ItemCategory.TOOL", "4").replace("ItemCategory.MATERIAL", "5")
dict_str = dict_str.replace("ItemCategory.EQUIPMENT", "6").replace("ItemCategory.QUEST", "7")
dict_str = dict_str.replace("ItemCategory.MISC", "8")
dict_str = dict_str.replace("true", "True").replace("false", "False")
dict_str = re.sub(r'Vector2i\((\d+),\s*(\d+)\)', r'(\1, \2)', dict_str)
dict_str = re.sub(r'#.*', '', dict_str)

orig_items = eval(dict_str)

# Now check all .tres files in data/items/
tres_items = {}
for fname in os.listdir("data/items"):
    if fname.endswith(".tres"):
        with open(f"data/items/{fname}", "r", encoding="utf-8") as f:
            content = f.read()
        
        # parse properties from tres
        id_m = re.search(r'id = \"([^\"]+)\"', content)
        if id_m:
            item_id = id_m.group(1)
            tres_items[item_id] = fname

print(f"Total .tres files: {len(tres_items)}")

missing = set(orig_items.keys()) - set(tres_items.keys())
if missing:
    print(f"[FAIL] Missing in .tres: {missing}")
else:
    print("[PASS] All 68 original items exist as .tres resources!")

# Check critical equipment & weapons
critical_checks = ["1레벨_가방", "1레벨_헬멧", "1레벨_방탄복", "권총", "파이프", "식량통조림", "생수", "붕대"]
for item_name in critical_checks:
    fname = tres_items[item_name]
    with open(f"data/items/{fname}", "r", encoding="utf-8") as f:
        c = f.read()
    print(f"--- {item_name} ({fname}) ---")
    for line in c.splitlines():
        if any(k in line for k in ["id =", "name =", "category =", "grid_", "defense =", "backpack_grid", "damage ="]):
            print(" ", line.strip())

print("\nVerification complete.")
