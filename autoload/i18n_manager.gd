# res://autoload/i18n_manager.gd
extends Node

## 다국어(i18n) 시스템 매니저 (Godot TranslationServer 기반)

var current_lang: String = "ko"

func _ready() -> void:
	_load_translations_from_csv()
	if GameSettings:
		current_lang = GameSettings.language
	TranslationServer.set_locale(current_lang)

func _load_translations_from_csv() -> void:
	var csv_file = FileAccess.open("res://resources/i18n/translations.csv", FileAccess.READ)
	if not csv_file:
		_load_compiled_translations()
		return
		
	var tr_ko = Translation.new()
	tr_ko.locale = "ko"
	var tr_en = Translation.new()
	tr_en.locale = "en"
	
	var line_idx = 0
	while not csv_file.eof_reached():
		var row = csv_file.get_csv_line()
		if row.size() < 3 or (row.size() == 1 and row[0] == ""):
			continue
		if line_idx == 0:
			line_idx += 1
			continue
			
		var key = row[0]
		var ko_text = row[1]
		var en_text = row[2]
		
		tr_ko.add_message(key, ko_text)
		tr_en.add_message(key, en_text)
		line_idx += 1
		
	csv_file.close()
	TranslationServer.add_translation(tr_ko)
	TranslationServer.add_translation(tr_en)

func _load_compiled_translations() -> void:
	for tr_path in [
		"res://resources/i18n/translations.ko.translation",
		"res://resources/i18n/translations.en.translation"
	]:
		if ResourceLoader.exists(tr_path):
			var tr_res = ResourceLoader.load(tr_path)
			if tr_res is Translation:
				TranslationServer.add_translation(tr_res)

func set_language(lang: String) -> void:
	current_lang = lang
	TranslationServer.set_locale(current_lang)
	if GameSettings:
		GameSettings.language = lang
		GameSettings.save_settings()

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
