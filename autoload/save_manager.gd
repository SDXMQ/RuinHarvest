# res://autoload/save_manager.gd
extends Node

## 세이브/로드 매니저 (JSON 직렬화)

const SAVE_DIR: String = "user://saves"

func _ready() -> void:
	ensure_save_dir()

func ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)

func get_save_files() -> Array:
	ensure_save_dir()
	var saves: Array = []
	var dir = DirAccess.open(SAVE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				var path = SAVE_DIR + "/" + file_name
				var file = FileAccess.open(path, FileAccess.READ)
				if file:
					var content = file.get_as_text()
					file.close()
					var json = JSON.new()
					if json.parse(content) == OK and json.data is Dictionary:
						var data = json.data
						var player_data = data.get("player", {})
						var rubles = player_data.get("rubles", 0) if typeof(player_data) == TYPE_DICTIONARY else 0
						
						saves.append({
							"filename": file_name,
							"path": path,
							"world_name": data.get("world_name", "알 수 없음"),
							"day": data.get("current_day", 0),
							"difficulty": data.get("difficulty", "normal"),
							"save_time": data.get("save_time", ""),
							"created_at": data.get("created_at", ""),
							"playtime": data.get("playtime", 0.0),
							"funds": rubles,
							"unix_time": Time.get_unix_time_from_datetime_string(data.get("save_time", "2000-01-01 00:00:00").replace(" ", "T"))
						})
			file_name = dir.get_next()
			
	# 최신순 정렬
	saves.sort_custom(func(a, b): return a.get("unix_time", 0) > b.get("unix_time", 0))
	return saves

func save_game(game_state: Dictionary, slot_name: String = "autosave") -> bool:
	ensure_save_dir()
	var filename = slot_name
	if not filename.ends_with(".json"):
		filename += ".json"
	
	var path = SAVE_DIR + "/" + filename
	var tmp_path = path + ".tmp"
	
	var current_datetime = Time.get_datetime_dict_from_system()
	var save_time = "%04d-%02d-%02d %02d:%02d:%02d" % [
		current_datetime.year, current_datetime.month, current_datetime.day,
		current_datetime.hour, current_datetime.minute, current_datetime.second
	]
	
	game_state["save_version"] = 2
	game_state["save_time"] = save_time
	
	# created_at 처리
	if not game_state.has("created_at"):
		if FileAccess.file_exists(path):
			var file = FileAccess.open(path, FileAccess.READ)
			if file:
				var json = JSON.new()
				if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
					game_state["created_at"] = json.data.get("created_at", save_time)
				file.close()
		else:
			game_state["created_at"] = save_time

	# 임시 파일 저장 후 원자적 덮어쓰기 흉내 (GDScript FileAccess)
	var tmp_file = FileAccess.open(tmp_path, FileAccess.WRITE)
	if tmp_file:
		tmp_file.store_string(JSON.stringify(game_state, "\t"))
		tmp_file.close()
		
		# 원본 덮어쓰기
		var dir = DirAccess.open(SAVE_DIR)
		if dir.file_exists(path):
			dir.remove(path)
		dir.rename(tmp_path, path)
		return true
		
	return false

func load_game(slot_name: String = "autosave") -> Dictionary:
	ensure_save_dir()
	var filename = slot_name
	if not filename.ends_with(".json"):
		filename += ".json"
		
	var path = SAVE_DIR + "/" + filename
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(content) == OK and json.data is Dictionary:
				return _migrate_save_data(json.data)
				
	return {}

func _migrate_save_data(data: Dictionary) -> Dictionary:
	var ver = int(data.get("save_version", 1))
	if not data.has("player") or typeof(data["player"]) != TYPE_DICTIONARY:
		data["player"] = {}
	if not data["player"].has("equipment"):
		data["player"]["equipment"] = {}
	if not data["player"].has("insured"):
		data["player"]["insured"] = false
	if not data.has("hideout") or typeof(data["hideout"]) != TYPE_DICTIONARY:
		data["hideout"] = {"stash": [], "upgrades": {}, "completed_quests": []}
	else:
		if not data["hideout"].has("stash"): data["hideout"]["stash"] = []
		if not data["hideout"].has("upgrades"): data["hideout"]["upgrades"] = {}
		if not data["hideout"].has("completed_quests"): data["hideout"]["completed_quests"] = []
	if ver < 2:
		data["save_version"] = 2
	return data

func delete_save(slot_name: String) -> bool:
	ensure_save_dir()
	var filename = slot_name
	if not filename.ends_with(".json"):
		filename += ".json"
		
	var path = SAVE_DIR + "/" + filename
	var dir = DirAccess.open(SAVE_DIR)
	if dir and dir.file_exists(path):
		dir.remove(path)
		return true
	return false
