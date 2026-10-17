import re

with open('scripts/tools/original_item_db.gd', 'r', encoding='utf-8') as f:
    text = f.read()

m = re.search(r'var items: Dictionary = (\{.*?\n\})\n\n', text, re.DOTALL)
if m:
    raw = m.group(1)
    keys = re.findall(r'\t\"([^\"]+)\": \{', raw)
    print(f"Total items: {len(keys)}")
    props = set(re.findall(r'\"([a-zA-Z0-9_]+)\":', raw)) - set(keys)
    print("Properties used in items:", sorted(list(props)))
else:
    print("Not found")
