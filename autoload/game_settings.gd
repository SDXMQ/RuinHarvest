# res://autoload/game_settings.gd
extends Node

## 게임 설정, 상수, 색상 팔레트 및 바이옴 정의

# ============================================================
# 화면 및 그리드 상수
# ============================================================
const RESOLUTION_OPTIONS: Array[Vector2i] = [
	Vector2i(640, 360),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]
const DEFAULT_RESOLUTION: Vector2i = Vector2i(1280, 720)
const FPS: int = 60
const TILE_SIZE: int = 32
const CHUNK_SIZE: int = 16  # 1청크 = 16x16 타일
const RENDER_DISTANCE: int = 3 # 렌더링 청크 반경

# ============================================================
# 색상 팔레트 (Colors)
# ============================================================
class Colors:
	# 기본
	const BLACK = Color8(10, 10, 15)
	const WHITE = Color8(240, 240, 245)
	const GRAY = Color8(128, 128, 135)
	const DARK_GRAY = Color8(45, 45, 55)
	const LIGHT_GRAY = Color8(180, 180, 190)

	# UI 색상
	const UI_BG = Color8(20, 22, 30, 200)
	const UI_BG_SOLID = Color8(20, 22, 30)
	const UI_BORDER = Color8(60, 65, 80)
	const UI_ACCENT = Color8(80, 180, 255)
	const UI_ACCENT_WARM = Color8(255, 160, 60)
	const UI_DANGER = Color8(255, 70, 70)
	const UI_SUCCESS = Color8(70, 220, 100)
	const UI_WARNING = Color8(255, 200, 50)
	const UI_TEXT = Color8(220, 225, 235)
	const UI_TEXT_DIM = Color8(140, 145, 160)
	const UI_PANEL = Color8(30, 32, 42, 220)
	const UI_HIGHLIGHT = Color8(100, 200, 255, 40)

	# 하늘 색상 (시간대별)
	const SKY_DAWN = Color8(255, 180, 120)
	const SKY_DAY = Color8(135, 200, 255)
	const SKY_DUSK = Color8(200, 100, 80)
	const SKY_NIGHT = Color8(15, 15, 40)

	# 바이옴 타일 색상
	const GRASS_1 = Color8(65, 130, 55)
	const GRASS_2 = Color8(75, 145, 60)
	const GRASS_3 = Color8(55, 120, 50)
	const DIRT_1 = Color8(140, 110, 70)
	const DIRT_2 = Color8(155, 120, 75)
	const ROAD = Color8(80, 80, 90)
	const ROAD_LINE = Color8(200, 200, 60)
	const CONCRETE = Color8(160, 160, 165)
	const WATER_1 = Color8(40, 100, 180)
	const WATER_2 = Color8(50, 120, 200)
	const SAND = Color8(210, 190, 140)
	const MUD = Color8(100, 80, 50)

	# 건물 색상
	const WALL_BRICK = Color8(150, 80, 60)
	const WALL_CONCRETE = Color8(140, 140, 145)
	const WALL_WOOD = Color8(130, 95, 55)
	const ROOF_1 = Color8(100, 60, 45)
	const ROOF_2 = Color8(70, 70, 80)
	const DOOR = Color8(90, 65, 40)
	const WINDOW = Color8(150, 200, 230, 150)
	const FLOOR_WOOD = Color8(160, 120, 70)
	const FLOOR_TILE = Color8(170, 170, 175)

	# 캐릭터 색상
	const PLAYER_SKIN = Color8(220, 185, 150)
	const PLAYER_SHIRT = Color8(60, 90, 60)
	const PLAYER_PANTS = Color8(50, 55, 65)
	const PLAYER_HAIR = Color8(60, 40, 25)

	const ENEMY_SKIN = Color8(120, 155, 100)
	const ENEMY_SKIN_DARK = Color8(90, 120, 75)
	const ENEMY_CLOTHES = Color8(80, 70, 65)
	const ENEMY_BLOOD = Color8(150, 30, 30)

	const NPC_MERCHANT_CLOAK = Color8(100, 75, 55)
	const NPC_SURVIVOR_SHIRT = Color8(70, 80, 120)
	const NPC_SOLDIER_UNIFORM = Color8(80, 95, 60)

	# 자연물 색상
	const TREE_TRUNK = Color8(90, 65, 40)
	const TREE_LEAVES_1 = Color8(45, 105, 35)
	const TREE_LEAVES_2 = Color8(35, 90, 30)
	const TREE_PINE = Color8(30, 75, 45)
	const TREE_DEAD = Color8(95, 80, 65)
	const ROCK_1 = Color8(130, 130, 135)
	const ROCK_2 = Color8(105, 105, 110)
	const BUSH_1 = Color8(55, 115, 45)

	# 효과 색상
	const MUZZLE_FLASH = Color8(255, 220, 100)
	const BULLET_TRACER = Color8(255, 240, 180)
	const BLOOD_PARTICLE = Color8(180, 25, 25)
	const DUST_PARTICLE = Color8(160, 150, 130)
	const SPARK_PARTICLE = Color8(255, 200, 50)
	const SMOKE_PARTICLE = Color8(100, 100, 110, 120)

	# 스탯 바 색상
	const HP_BAR = Color8(220, 50, 50)
	const HUNGER_BAR = Color8(230, 150, 40)
	const THIRST_BAR = Color8(40, 150, 230)
	const STRESS_BAR = Color8(180, 70, 200)
	const STAMINA_BAR = Color8(60, 200, 90)

# ============================================================
# 난이도 프리셋
# ============================================================
const DIFFICULTY_PRESETS: Dictionary = {
	"peaceful": {
		"name": "평화로움",
		"enemy_spawn_mult": 0.0,
		"resource_mult": 2.0,
		"damage_taken_mult": 0.0,
		"metabolism_mult": 0.5,
		"night_raid_chance": 0.0,
		"permadeath": false,
		"desc": "적이 스폰되지 않으며, 자원이 풍부합니다. 건설과 탐험에 집중할 수 있습니다."
	},
	"easy": {
		"name": "쉬움",
		"enemy_spawn_mult": 0.5,
		"resource_mult": 1.5,
		"damage_taken_mult": 0.7,
		"metabolism_mult": 0.75,
		"night_raid_chance": 0.15,
		"permadeath": false,
		"desc": "적의 수와 피해량이 적고, 자원이 넉넉합니다. 초보자에게 권장합니다."
	},
	"casual": {
		"name": "캐주얼",
		"enemy_spawn_mult": 0.5,
		"resource_mult": 2.0,
		"damage_taken_mult": 0.7,
		"metabolism_mult": 0.75,
		"night_raid_chance": 0.15,
		"permadeath": false,
		"desc": "적의 수와 피해량이 적고, 자원이 넉넉합니다. 초보자에게 권장합니다."
	},
	"normal": {
		"name": "보통",
		"enemy_spawn_mult": 1.0,
		"resource_mult": 1.0,
		"damage_taken_mult": 1.0,
		"metabolism_mult": 1.0,
		"night_raid_chance": 0.35,
		"permadeath": false,
		"desc": "기본 생존 경험입니다. 균형 잡힌 도전 과제를 제공합니다."
	},
	"hard": {
		"name": "어려움",
		"enemy_spawn_mult": 1.5,
		"resource_mult": 0.7,
		"damage_taken_mult": 1.4,
		"metabolism_mult": 1.25,
		"night_raid_chance": 0.55,
		"permadeath": false,
		"desc": "적이 많고 자원이 부족합니다. 전략적인 판단이 필요합니다."
	},
	"hardcore": {
		"name": "하드코어",
		"enemy_spawn_mult": 2.0,
		"resource_mult": 0.5,
		"damage_taken_mult": 1.8,
		"metabolism_mult": 1.5,
		"night_raid_chance": 0.75,
		"permadeath": true,
		"desc": "사망 시 세이브 파일이 삭제됩니다. 극도의 긴장감을 원한다면 추천합니다."
	},
	"challenge": {
		"name": "악몽 챌린지",
		"enemy_spawn_mult": 2.5,
		"resource_mult": 0.3,
		"damage_taken_mult": 2.0,
		"metabolism_mult": 2.0,
		"night_raid_chance": 0.9,
		"permadeath": true,
		"desc": "생존이 거의 불가능에 가깝습니다. 가장 숙련된 생존자만을 위한 난이도입니다."
	},
	"custom": {
		"name": "커스텀 모딩",
		"enemy_spawn_mult": 1.0,
		"resource_mult": 1.0,
		"damage_taken_mult": 1.0,
		"metabolism_mult": 1.0,
		"night_raid_chance": 0.35,
		"permadeath": false,
		"desc": "사용자 지정 규칙이 적용된 커스텀 난이도입니다."
	}
}

# ============================================================
# 기본 월드 생성 설정
# ============================================================
const DEFAULT_WORLD_SETTINGS: Dictionary = {
	"world_name": "폐허의 땅",
	"seed": 0,
	"difficulty": "normal",
	"day_length_minutes": 12.0, # 하루 = 현실 12분
	"resource_density": 1.0,
	"weather_variability": 1.0,
	"enemy_activity": 1.0,
	"building_density": 1.0,
	"survival_goal_days": 30,
	"sandbox_mode": false
}

# ============================================================
# 플레이어 & 전투 상수
# ============================================================
const PLAYER_MAX_HP: float = 100.0
const PLAYER_SPEED: float = 4.0        # 타일/초
const PLAYER_SPRINT_MULT: float = 1.6
const PLAYER_CROUCH_MULT: float = 0.5
const PLAYER_STAMINA_DRAIN_SPRINT: float = 20.0
const PLAYER_STAMINA_RECOVER: float = 15.0

const MELEE_RANGE: float = 1.5         # 타일
const RANGED_MAX_RANGE: float = 12.0   # 타일
const ATTACK_COOLDOWN: float = 0.4     # 초
const KNOCKBACK_FORCE: float = 3.0
const INVINCIBILITY_FRAMES: float = 0.5 # 초

# ============================================================
# 바이옴 정의
# ============================================================
const BIOMES: Dictionary = {
	"residential": {
		"name": "주거지",
		"tiles": ["grass", "dirt", "concrete"],
		"building_chance": 0.45,
		"tree_chance": 0.15,
		"enemy_density": 0.8,
		"loot_mult": 1.0,
		"road_interval": 14,
		"color": Color8(70, 130, 60)
	},
	"city": {
		"name": "도시",
		"tiles": ["concrete", "road", "dirt"],
		"building_chance": 0.7,
		"tree_chance": 0.05,
		"enemy_density": 1.4,
		"loot_mult": 1.3,
		"road_interval": 10,
		"color": Color8(100, 100, 110)
	},
	"forest": {
		"name": "산림",
		"tiles": ["grass", "dirt"],
		"building_chance": 0.05,
		"tree_chance": 0.55,
		"enemy_density": 0.6,
		"loot_mult": 0.7,
		"road_interval": 30,
		"color": Color8(40, 95, 35)
	},
	"hospital_zone": {
		"name": "병원구역",
		"tiles": ["concrete", "road", "grass"],
		"building_chance": 0.5,
		"tree_chance": 0.1,
		"enemy_density": 1.2,
		"loot_mult": 1.5,
		"road_interval": 12,
		"color": Color8(120, 140, 160)
	},
	"military_base": {
		"name": "군사기지",
		"tiles": ["concrete", "dirt", "road"],
		"building_chance": 0.6,
		"tree_chance": 0.05,
		"enemy_density": 1.8,
		"loot_mult": 2.0,
		"road_interval": 12,
		"color": Color8(90, 100, 80)
	},
	"lake": {
		"name": "호수",
		"tiles": ["water", "sand", "grass"],
		"building_chance": 0.0,
		"tree_chance": 0.2,
		"enemy_density": 0.3,
		"loot_mult": 0.5,
		"road_interval": 40,
		"color": Color8(50, 100, 180)
	},
	"wasteland": {
		"name": "황무지",
		"tiles": ["dirt", "sand", "rock"],
		"building_chance": 0.15,
		"tree_chance": 0.08,
		"enemy_density": 1.0,
		"loot_mult": 0.8,
		"road_interval": 20,
		"color": Color8(140, 115, 80)
	},
	"factory_zone": {
		"name": "공장단지",
		"tiles": ["concrete", "dirt", "road"],
		"building_chance": 0.55,
		"tree_chance": 0.05,
		"enemy_density": 1.3,
		"loot_mult": 1.4,
		"road_interval": 12,
		"color": Color8(110, 95, 90)
	},
	"wheat_field": {
		"name": "밀밭",
		"tiles": ["dirt", "grass"],
		"building_chance": 0.1,
		"tree_chance": 0.1,
		"enemy_density": 0.5,
		"loot_mult": 0.9,
		"road_interval": 24,
		"color": Color8(180, 160, 90)
	}
}

# ============================================================
# 설정 저장/로드 (GameSettings 싱글톤 데이터)
# ============================================================
var resolution_index: int = 1
var fullscreen: bool = false
var integer_scaling: bool = false
var vsync: bool = true
var master_volume: float = 0.7
var sfx_volume: float = 0.5
var bgm_volume: float = 0.5
var language: String = "ko"
var show_fps: bool = false
var screen_shake: bool = true
var particles_quality: int = 2 # 0: 끄기, 1: 30%, 2: 70%, 3: 100%
var max_event_logs: int = 3 # 왼쪽 HUD 이벤트 로그 최대 표시 개수
var movement_mode: int = 0 # 0: 기본 이동 (화면 상하좌우 WASD), 1: 시선 기준 이동 (마우스 방향 WASD)

# 셰이더 설정
var enable_post_process: bool = true
var vignette_intensity: float = 0.6
var bloom_intensity: float = 0.4
var chromatic_aberration: float = 0.3

const SETTINGS_FILE_PATH: String = "user://game_settings.json"

func _ready() -> void:
	setup_default_input_map()
	var had_saved_settings := FileAccess.file_exists(SETTINGS_FILE_PATH)
	load_settings()
	apply_audio_settings()
	if DisplayServer.get_name() != "headless" and (had_saved_settings or fullscreen or integer_scaling):
		apply_display_settings.call_deferred()

func _input(event: InputEvent) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if k == KEY_F11 or ((k == KEY_ENTER or k == KEY_KP_ENTER) and event.alt_pressed):
			toggle_fullscreen()
			if get_viewport():
				get_viewport().set_input_as_handled()

func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	apply_display_settings()
	save_settings()

func setup_default_input_map() -> void:
	var bindings = {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_E],
		"sprint": [KEY_SHIFT],
		"crouch": [KEY_CTRL],
		"inventory": [KEY_TAB, KEY_I],
		"crafting": [KEY_C],
		"map_toggle": [KEY_M],
		"pause": [KEY_ESCAPE],
		"reload": [KEY_R]
	}
	
	for action in bindings.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var ev = InputEventKey.new()
			ev.physical_keycode = key
			ev.keycode = key
			if not InputMap.action_has_event(action, ev):
				InputMap.action_add_event(action, ev)
	
	# 마우스 액션 등록
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var mb_left = InputEventMouseButton.new()
		mb_left.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", mb_left)
		
	if not InputMap.has_action("drop_item"):
		InputMap.add_action("drop_item")
		var mb_right = InputEventMouseButton.new()
		mb_right.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("drop_item", mb_right)

func get_current_resolution() -> Vector2i:
	if resolution_index >= 0 and resolution_index < RESOLUTION_OPTIONS.size():
		return RESOLUTION_OPTIONS[resolution_index]
	return DEFAULT_RESOLUTION

func apply_display_settings() -> void:
	var res: Vector2i = get_current_resolution()
	if get_tree() and get_tree().root:
		get_tree().root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if integer_scaling else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	if DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(res)
		# 화면 중앙 정렬
		var screen_size: Vector2i = DisplayServer.screen_get_size()
		var diff: Vector2i = screen_size - res
		DisplayServer.window_set_position(Vector2i(maxi(0, int(float(diff.x) / 2.0)), maxi(0, int(float(diff.y) / 2.0))))

func ensure_audio_buses() -> void:
	if AudioServer.get_bus_index("BGM") == -1:
		var bgm_idx: int = AudioServer.bus_count
		AudioServer.add_bus(bgm_idx)
		AudioServer.set_bus_name(bgm_idx, "BGM")
		AudioServer.set_bus_send(bgm_idx, "Master")
	if AudioServer.get_bus_index("SFX") == -1:
		var sfx_idx: int = AudioServer.bus_count
		AudioServer.add_bus(sfx_idx)
		AudioServer.set_bus_name(sfx_idx, "SFX")
		AudioServer.set_bus_send(sfx_idx, "Master")

func _apply_bus_volume(bus_name: String, linear_vol: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	var clamped: float = clampf(linear_vol, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, clamped <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(clamped, 0.0001)))

func apply_audio_settings() -> void:
	ensure_audio_buses()
	_apply_bus_volume("Master", master_volume)
	_apply_bus_volume("BGM", bgm_volume)
	_apply_bus_volume("SFX", sfx_volume)

func save_settings() -> void:
	var data: Dictionary = {
		"resolution_index": resolution_index,
		"fullscreen": fullscreen,
		"integer_scaling": integer_scaling,
		"vsync": vsync,
		"master_volume": master_volume,
		"sfx_volume": sfx_volume,
		"bgm_volume": bgm_volume,
		"language": language,
		"show_fps": show_fps,
		"screen_shake": screen_shake,
		"particles_quality": particles_quality,
		"max_event_logs": max_event_logs,
		"movement_mode": movement_mode,
		"enable_post_process": enable_post_process,
		"vignette_intensity": vignette_intensity,
		"bloom_intensity": bloom_intensity,
		"chromatic_aberration": chromatic_aberration
	}
	var file := FileAccess.open(SETTINGS_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_FILE_PATH):
		return
	var file := FileAccess.open(SETTINGS_FILE_PATH, FileAccess.READ)
	if file:
		var content := file.get_as_text()
		file.close()
		var json := JSON.new()
		if json.parse(content) == OK and json.data is Dictionary:
			var d: Dictionary = json.data
			resolution_index = d.get("resolution_index", resolution_index)
			fullscreen = d.get("fullscreen", fullscreen)
			integer_scaling = d.get("integer_scaling", integer_scaling)
			vsync = d.get("vsync", vsync)
			master_volume = d.get("master_volume", master_volume)
			sfx_volume = d.get("sfx_volume", sfx_volume)
			bgm_volume = d.get("bgm_volume", bgm_volume)
			language = d.get("language", language)
			show_fps = d.get("show_fps", show_fps)
			screen_shake = d.get("screen_shake", screen_shake)
			particles_quality = d.get("particles_quality", particles_quality)
			max_event_logs = d.get("max_event_logs", max_event_logs)
			movement_mode = clampi(int(d.get("movement_mode", movement_mode)), 0, 1)
			enable_post_process = d.get("enable_post_process", enable_post_process)
			vignette_intensity = d.get("vignette_intensity", vignette_intensity)
			bloom_intensity = d.get("bloom_intensity", bloom_intensity)
			chromatic_aberration = d.get("chromatic_aberration", chromatic_aberration)
