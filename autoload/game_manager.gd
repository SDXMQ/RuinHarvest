# res://autoload/game_manager.gd
extends Node

## 게임 전역 상태, 씬 전환 및 플로우 제어

enum GameState {
	MAIN_MENU,
	WORLD_CREATION,
	HIDEOUT,
	RAID_LOADING,
	IN_GAME,
	INVENTORY,
	PAUSED,
	GAME_OVER,
	EXTRACTION
}

var current_state: GameState = GameState.MAIN_MENU

# 현재 로드된 세이브 데이터(또는 진행 중인 월드)
var current_save_slot: String = ""
var current_world_data: Dictionary = {}

var is_paused: bool = false
var raid_start_time: float = 0.0
var raid_duration_minutes: float = 10.0 # 레이드 기본 제한 시간(분)
var time_elapsed_in_raid: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # 일시정지 중에도 동작

func _process(delta: float) -> void:
	if current_state == GameState.IN_GAME and not is_paused:
		time_elapsed_in_raid += delta
		# 레이드 시간 초과 시 MIA(Missing In Action) 처리
		if time_elapsed_in_raid >= raid_duration_minutes * 60.0:
			end_raid("mia")

# ============================================================
# 씬 전환 및 플로우 제어
# ============================================================
func change_state(new_state: GameState) -> void:
	current_state = new_state
	
	match current_state:
		GameState.MAIN_MENU:
			get_tree().paused = false
			TransitionManager.change_scene("res://scenes/main_menu/main_menu.tscn", "fade", 0.8)
		GameState.HIDEOUT:
			get_tree().paused = false
			TransitionManager.change_scene("res://scenes/hideout/hideout.tscn", "fade", 0.8)
		GameState.RAID_LOADING:
			# 로딩 씬 표시 후 실제 인게임 씬 전환
			pass
		GameState.IN_GAME:
			get_tree().paused = false
		GameState.PAUSED:
			get_tree().paused = true
		GameState.GAME_OVER:
			get_tree().paused = true
			# 사망 UI 표시

func toggle_pause() -> void:
	if current_state == GameState.IN_GAME:
		change_state(GameState.PAUSED)
	elif current_state == GameState.PAUSED:
		change_state(GameState.IN_GAME)

# ============================================================
# 세이브/로드 연계
# ============================================================
func start_new_game(world_settings: Dictionary = {}) -> void:
	current_save_slot = "save_" + str(Time.get_unix_time_from_system())
	
	# 기본 초기 데이터 세팅
	current_world_data = {
		"world_name": world_settings.get("world_name", "New World"),
		"difficulty": world_settings.get("difficulty", "normal"),
		"current_day": 1,
		"playtime": 0.0,
		"player": {
			"hp": GameSettings.PLAYER_MAX_HP,
			"hunger": 100.0,
			"thirst": 100.0,
			"stress": 0.0,
			"stamina": 100.0,
			"rubles": 5000,
			"inventory": [
				{"id": "권총", "amount": 1},
				{"id": "탄약", "amount": 30},
				{"id": "붕대", "amount": 2},
				{"id": "생수", "amount": 1}
			],
			"equipment": {}
		},
		"hideout": {
			"stash": [],
			"upgrades": {}
		},
		"world_settings": world_settings
	}
	
	SaveManager.save_game(current_world_data, current_save_slot)
	change_state(GameState.HIDEOUT)

func load_game(slot_name: String) -> void:
	var data = SaveManager.load_game(slot_name)
	if not data.is_empty():
		current_save_slot = slot_name
		current_world_data = data
		change_state(GameState.HIDEOUT)

# ============================================================
# 레이드 사이클 제어
# ============================================================
func start_raid() -> void:
	time_elapsed_in_raid = 0.0
	change_state(GameState.RAID_LOADING)
	TransitionManager.change_scene("res://scenes/world/main_world.tscn", "fade", 1.0)
	current_state = GameState.IN_GAME
	EventBus.raid_started.emit()

var last_raid_result: Dictionary = {}

func end_raid(result: String, looted_items: Array = []) -> void:
	# result: "survived" (탈출), "kia" (사망), "mia" (시간 초과)
	last_raid_result = {
		"result": result,
		"day": current_world_data.get("current_day", 1),
		"time_spent": time_elapsed_in_raid,
		"items": looted_items
	}
	
	if not current_world_data.has("player"):
		current_world_data["player"] = {}
	if not current_world_data.has("hideout"):
		current_world_data["hideout"] = {"stash": []}
	elif not current_world_data["hideout"].has("stash"):
		current_world_data["hideout"]["stash"] = []
	
	if result == "survived":
		if current_world_data.has("current_day"):
			current_world_data["current_day"] += 1
		else:
			current_world_data["current_day"] = 2
			
		# 탈출 성공: 레이드에서 가져온 배낭 아이템들을 플레이어 소지품으로 정확히 보존
		var saved_items = []
		for item in looted_items:
			if item:
				saved_items.append(item.duplicate())
		current_world_data["player"]["inventory"] = saved_items
		
		if current_save_slot != "":
			SaveManager.save_game(current_world_data, current_save_slot)
	else:
		# 사망/실종: 배낭에 있던 모든 아이템 분실 (창고 스태쉬는 안전하게 보존)
		current_world_data["player"]["inventory"] = []
		
		var diff = current_world_data.get("difficulty", "normal")
		if GameSettings.DIFFICULTY_PRESETS.has(diff) and GameSettings.DIFFICULTY_PRESETS[diff].get("permadeath", false):
			if current_save_slot != "":
				SaveManager.delete_save(current_save_slot)
				current_save_slot = ""
				current_world_data.clear()
		else:
			if current_save_slot != "":
				SaveManager.save_game(current_world_data, current_save_slot)
	
	EventBus.raid_ended.emit(result)
	change_state(GameState.HIDEOUT)
