import os
import re

with open("autoload/i18n_manager.gd", "r", encoding="utf-8") as f:
    content = f.read()

# 딕셔너리 부분 추출
match = re.search(r'const STRINGS: Dictionary = (\{.*?\n\})', content, re.DOTALL)
if not match:
    print("Could not find STRINGS dict")
    exit(1)

dict_str = match.group(1)
dict_str = re.sub(r'#.*', '', dict_str) # 주석 제거

try:
    strings = eval(dict_str)
except Exception as e:
    print("Error parsing strings:", e)
    strings = {"ko": {}, "en": {}}

ko_dict = strings.get("ko", {})
en_dict = strings.get("en", {})

os.makedirs("resources/i18n", exist_ok=True)
csv_path = "resources/i18n/translations.csv"

# 모든 키 수집
all_keys = set(ko_dict.keys()) | set(en_dict.keys())

with open(csv_path, "w", encoding="utf-8") as f:
    f.write("id,ko,en\n")
    for key in all_keys:
        ko_val = ko_dict.get(key, "").replace('"', '""').replace("\n", "\\n")
        en_val = en_dict.get(key, "").replace('"', '""').replace("\n", "\\n")
        f.write(f'"{key}","{ko_val}","{en_val}"\n')

print("Created translations.csv")

# i18n_manager.gd 리팩토링
new_manager = """extends Node

var current_lang: String = "ko"

func _ready() -> void:
	TranslationServer.set_locale(current_lang)

func set_language(lang: String) -> void:
	current_lang = lang
	TranslationServer.set_locale(current_lang)

func t(key: String, args: Array = []) -> String:
	var tr_text = TranslationServer.translate(key)
	if tr_text == key:
		var item_key = "item_" + key
		var tr_item = TranslationServer.translate(item_key)
		if tr_item != item_key:
			tr_text = tr_item
	
	if args.size() > 0:
		var formatted = tr_text
		for i in range(args.size()):
			formatted = formatted.replace("{" + str(i) + "}", str(args[i]))
		return formatted
		
	return tr_text
"""

with open("autoload/i18n_manager.gd", "w", encoding="utf-8") as f:
    f.write(new_manager)

print("Refactored i18n_manager.gd")
