import os, re

with open('scripts/tools/original_item_db.gd', 'r', encoding='utf-8') as f:
    text = f.read()

m = re.search(r'var items: Dictionary = (\{.*?\n\})\n\n', text, re.DOTALL)
raw = m.group(1)

# Only match top-level keys that start with one tab and a quote
top_keys = re.findall(r'^\t\"([^\"]+)\": \{', raw, re.MULTILINE)
print(f"True top-level item count: {len(top_keys)}")

existing_files = set()
for fname in os.listdir('data/items'):
    if fname.endswith('.tres'):
        existing_files.add(fname[:-5])

missing = []
for k in top_keys:
    safe_k = k.replace("/", "_").replace(" ", "_").replace(":", "_")
    if safe_k not in existing_files:
        missing.append(k)

print(f"Missing items ({len(missing)}):")
for m_item in sorted(missing):
    print(" -", m_item)
