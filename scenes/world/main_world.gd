# res://scenes/world/main_world.gd
extends Node2D

@onready var chunk_manager: Node = $ChunkManager
@onready var entities_layer: Node2D = $Entities
@onready var pause_menu: Control = $UI/PauseMenu
@onready var resume_btn: Button = $UI/PauseMenu/CenterPanel/VBoxContainer/ResumeBtn
@onready var exit_btn: Button = $UI/PauseMenu/CenterPanel/VBoxContainer/ExitBtn
@onready var debug_label: Label = $UI/HUD/DebugLabel
@onready var interact_prompt: Label = $UI/HUD/InteractPrompt
@onready var hp_bar: ProgressBar = $UI/HUD/Panel/VBox/HPBar
@onready var stamina_bar: ProgressBar = $UI/HUD/Panel/VBox/StaminaBar
@onready var hunger_bar: ProgressBar = $UI/HUD/Panel/VBox/HBox/HungerBar
@onready var thirst_bar: ProgressBar = $UI/HUD/Panel/VBox/HBox/ThirstBar
@onready var status_label: Label = $UI/HUD/Panel/VBox/StatusLabel
@onready var raid_timer_label: Label = $UI/HUD/RaidTimerPanel/RaidTimerLabel
@onready var extract_bar: ProgressBar = $UI/HUD/ExtractProgressBar
@onready var day_night_modulate: CanvasModulate = $DayNightModulate
@onready var compass_bar: Control = $UI/HUD/CompassBar
@onready var event_log_vbox: VBoxContainer = $UI/HUD/EventLog

const MapWindowScene = preload("res://scenes/ui/map_window.tscn")
var current_map_window: Control = null
var extraction_points_data: Array = []

const PlayerScene = preload("res://scenes/entities/player/player.tscn")
var player: CharacterBody2D
var player_inventory: Inventory
var container_inventories: Dictionary = {} # tile_pos -> Inventory

const LootWindowScene = preload("res://scenes/ui/loot_window.tscn")
var current_loot_window: Control = null

const EnemyScene = preload("res://scenes/entities/enemies/enemy.tscn")
var enemy_spawn_timer: float = 2.0
var max_enemies_count: int = 15

const ExtractionZoneScene = preload("res://scenes/world/extraction_zone.tscn")
var raid_time_remaining: float = 300.0 # 5분

const PostProcessLayerScene = preload("res://graphics/post_process_layer.tscn")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # 일시정지 중에도 메인 월드 스크립트 실행 유지
	
	# 후처리 셰이더 레이어 추가
	var pp = PostProcessLayerScene.instantiate()
	add_child(pp)
	
	if compass_bar:
		compass_bar.draw.connect(_on_compass_draw)
		
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.connect(_on_event_logged)
	
	# 플레이어 인벤토리 생성 및 데이터 복원
	player_inventory = Inventory.new()
	player_inventory.max_slots = 12
	add_child(player_inventory)
	
	if GameManager and not GameManager.current_world_data.is_empty():
		var p_items = GameManager.current_world_data.get("player", {}).get("inventory", [])
		for item in p_items:
			if item:
				player_inventory.add_item(item["id"], item["amount"])
	
	# 플레이어 인스턴스화
	player = PlayerScene.instantiate()
	var spawn_pos = Vector2.ZERO
	if GameManager and GameManager.current_world_data.has("current_interior"):
		var info = GameManager.current_world_data["current_interior"]
		if info.has("return_pos"):
			spawn_pos = info["return_pos"]
		GameManager.current_world_data.erase("current_interior")
		
	# 복귀 시 스탯 및 타이머 복원
	if GameManager and GameManager.current_world_data.has("player_stats"):
		var s = GameManager.current_world_data["player_stats"]
		player.hp = s.get("hp", 100.0)
		player.stamina = s.get("stamina", 100.0)
		player.hunger = s.get("hunger", 100.0)
		player.thirst = s.get("thirst", 100.0)
		player.is_bleeding = s.get("is_bleeding", false)
		player.is_fractured = s.get("is_fractured", false)
		player.is_infected = s.get("is_infected", false)
		player.set_flashlight(s.get("flashlight_enabled", true))
		GameManager.current_world_data.erase("player_stats")
		
	if GameManager and GameManager.current_world_data.has("raid_time_remaining"):
		raid_time_remaining = GameManager.current_world_data["raid_time_remaining"]
		GameManager.current_world_data.erase("raid_time_remaining")
		
	player.position = spawn_pos
	entities_layer.add_child(player)
	
	player.stats_changed.connect(_on_player_stats_changed)
	player.interact_prompt.connect(_on_interact_prompt)
	player.object_interacted.connect(_on_object_interacted)
	
	# 일시정지 메뉴 버튼 시그널 연결
	resume_btn.pressed.connect(_on_resume_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)
	pause_menu.visible = false

	# 청크 매니저 시그널 연결
	chunk_manager.chunk_loaded.connect(_on_chunk_loaded)
	chunk_manager.chunk_unloaded.connect(_on_chunk_unloaded)
	
	# 초기 청크 로드
	chunk_manager.update_chunks(player.global_position)
	_on_player_stats_changed()
	
	# 시작 시 주변에 초기 좀비 3마리 스폰
	for i in range(3):
		_spawn_enemy_near_player(200.0 + i * 50.0)
		
	# 탈출 지점 3개 스폰 (동, 서, 남 방향 약 600~900px 거리)
	_spawn_extraction_zones()
	
	GameManager.current_state = GameManager.GameState.IN_GAME
	
	# 작전 개시 및 초기 상태 안내 로그 출력
	_on_event_logged("★ [작전 개시] 30일간의 생존 레이드가 시작되었습니다.")
	if WeatherSystem:
		_on_event_logged("🌦️ 현재 날씨: [%s]" % WeatherSystem.get_weather_name(WeatherSystem.current_weather))

func _spawn_extraction_zones() -> void:
	extraction_points_data.clear()
	var angles = [0.0, 2.0944, 4.18879] # 0도, 120도, 240도
	for i in range(angles.size()):
		var angle = angles[i]
		var dist = 800.0
		var pos = Vector2.RIGHT.rotated(angle) * dist
		var zone = ExtractionZoneScene.instantiate()
		zone.position = pos
		zone.zone_name = "탈출구 " + str(i + 1)
		zone.extract_progress.connect(_on_extract_progress)
		zone.extract_cancelled.connect(_on_extract_cancelled)
		add_child(zone)
		
		extraction_points_data.append({
			"name": zone.zone_name,
			"pos": pos
		})

func _on_extract_progress(cur: float, max_t: float) -> void:
	if extract_bar:
		extract_bar.visible = true
		extract_bar.max_value = max_t
		extract_bar.value = cur
		var remain = max(0.0, max_t - cur)
		extract_bar.get_node("Label").text = "탈출 중... %.1f초" % remain

func _on_extract_cancelled() -> void:
	if extract_bar:
		extract_bar.visible = false

func _on_event_logged(msg: String) -> void:
	if not event_log_vbox: return
	
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.85)
	style.border_width_left = 4
	style.border_color = Color(1.0, 0.8, 0.2)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	
	var lbl = Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 13)
	
	# 이벤트 성격별 테두리 및 폰트 색상 구분
	if msg.begins_with("★"):
		style.border_color = Color(1.0, 0.8, 0.2)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	elif msg.begins_with("✓") or msg.begins_with("📦"):
		style.border_color = Color(0.3, 0.9, 0.4)
		lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	elif msg.begins_with("✗") or msg.begins_with("💀"):
		style.border_color = Color(0.9, 0.3, 0.3)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	elif msg.begins_with("🌦️") or msg.begins_with("🌅"):
		style.border_color = Color(0.3, 0.7, 1.0)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
		
	panel.add_child(lbl)
	event_log_vbox.add_child(panel)
	
	# 최대 6개 로그 유지
	while event_log_vbox.get_child_count() > 6:
		var oldest = event_log_vbox.get_child(0)
		oldest.queue_free()
		event_log_vbox.remove_child(oldest)
	
	var tween = create_tween()
	tween.tween_interval(7.0) # 7초 대기
	tween.tween_property(panel, "modulate:a", 0.0, 1.5) # 1.5초간 부드럽게 페이드아웃
	tween.tween_callback(panel.queue_free)

func _spawn_enemy_near_player(dist: float = 350.0) -> void:
	if not player: return
	var angle = randf() * TAU
	var spawn_pos = player.global_position + Vector2.RIGHT.rotated(angle) * dist
	
	var enemy = EnemyScene.instantiate()
	enemy.position = spawn_pos
	# 무작위 적 타입 결정 (일반, 러너, 탱커)
	var r = randf()
	if r < 0.2: enemy.enemy_type = 1 # RUNNER
	elif r < 0.35: enemy.enemy_type = 2 # TANK
	else: enemy.enemy_type = 0 # ZOMBIE
	
	entities_layer.add_child(enemy)

const CraftingWindowScene = preload("res://scenes/ui/crafting_window.tscn")
var current_crafting_window: Control = null

func _unhandled_input(event: InputEvent) -> void:
	if current_loot_window != null or current_crafting_window != null or current_map_window != null:
		return
		
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			_toggle_pause()
			get_viewport().set_input_as_handled()
			return
			
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		
	# 인벤토리 열기 (Tab 또는 I 키로 내 배낭만 열기)
	if event.is_action_pressed("inventory") or (event is InputEventKey and event.physical_keycode == KEY_TAB and event.pressed):
		_open_loot_window(null)
		get_viewport().set_input_as_handled()
		
	# 제작창 열기 (C 키)
	if event.is_action_pressed("crafting") or (event is InputEventKey and event.physical_keycode == KEY_C and event.pressed):
		_open_crafting_window()
		get_viewport().set_input_as_handled()
		
	# 전술 지도 열기 (M 키)
	if event.is_action_pressed("map") or (event is InputEventKey and event.physical_keycode == KEY_M and event.pressed):
		_open_map_window()
		get_viewport().set_input_as_handled()

func _open_crafting_window() -> void:
	get_tree().paused = true
	current_crafting_window = CraftingWindowScene.instantiate()
	$UI.add_child(current_crafting_window)
	current_crafting_window.setup(player_inventory)
	current_crafting_window.window_closed.connect(func(): current_crafting_window = null)

func _open_map_window() -> void:
	get_tree().paused = true
	current_map_window = MapWindowScene.instantiate()
	$UI.add_child(current_map_window)
	
	var biome = "주거지"
	if chunk_manager and chunk_manager.generator:
		var cx = int(floor(player.global_position.x / 32.0))
		var cy = int(floor(player.global_position.y / 32.0))
		biome = chunk_manager.generator.get_biome(cx, cy)
		
	current_map_window.setup(player.global_position, player.rotation, extraction_points_data, biome)
	current_map_window.window_closed.connect(func(): current_map_window = null)

func _on_compass_draw() -> void:
	if not player: return
	var w = compass_bar.size.x
	var h = compass_bar.size.y
	var center_x = w / 2.0
	
	# 반투명 배경
	compass_bar.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(0.1, 0.1, 0.15, 0.6))
	compass_bar.draw_line(Vector2(0, h), Vector2(w, h), Color(0.5, 0.5, 0.5, 0.5), 1.0)
	
	# 플레이어 시선 각도 (도)
	var player_deg = rad_to_deg(player.rotation)
	if player_deg < 0: player_deg += 360.0
	
	# 시야각 FOV (180도)
	var fov = 160.0
	var pixels_per_deg = w / fov
	
	# N, E, S, W 방위각 눈금
	var cardinal_dirs = {
		0.0: "E",
		90.0: "S",
		180.0: "W",
		270.0: "N"
	}
	
	for deg in cardinal_dirs.keys():
		var diff = deg - player_deg
		while diff < -180.0: diff += 360.0
		while diff > 180.0: diff -= 360.0
		
		if abs(diff) <= fov / 2.0:
			var x = center_x + diff * pixels_per_deg
			compass_bar.draw_line(Vector2(x, h - 8), Vector2(x, h), Color.WHITE, 1.5)
			compass_bar.draw_string(ThemeDB.fallback_font, Vector2(x - 4, h - 10), cardinal_dirs[deg], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.9, 0.3))
			
	# 탈출구 마커 (초록색 다이아몬드)
	for pt in extraction_points_data:
		var dir_to_pt = player.global_position.direction_to(pt["pos"])
		var pt_deg = rad_to_deg(dir_to_pt.angle())
		if pt_deg < 0: pt_deg += 360.0
		
		var diff = pt_deg - player_deg
		while diff < -180.0: diff += 360.0
		while diff > 180.0: diff -= 360.0
		
		if abs(diff) <= fov / 2.0:
			var x = center_x + diff * pixels_per_deg
			var dist = player.global_position.distance_to(pt["pos"])
			# 다이아몬드 마커
			var diamond = PackedVector2Array([
				Vector2(x, 4), Vector2(x + 4, 9), Vector2(x, 14), Vector2(x - 4, 9)
			])
			compass_bar.draw_colored_polygon(diamond, Color(0.2, 1.0, 0.3))
			compass_bar.draw_string(ThemeDB.fallback_font, Vector2(x - 12, 22), "%.0fm" % dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.3, 1.0, 0.4))
			
	# 정중앙 조준 눈금 (노란 역삼각형)
	var pointer = PackedVector2Array([
		Vector2(center_x - 4, 0), Vector2(center_x + 4, 0), Vector2(center_x, 6)
	])
	compass_bar.draw_colored_polygon(pointer, Color(1.0, 0.85, 0.2))

func _process(delta: float) -> void:
	if player:
		chunk_manager.update_chunks(player.global_position)
		if compass_bar:
			compass_bar.queue_redraw()
		
		# 레이드 제한 시간 감소 및 낮/밤 조명 제어
		if raid_time_remaining > 0:
			raid_time_remaining -= delta
			var minutes = int(raid_time_remaining) / 60
			var seconds = int(raid_time_remaining) % 60
			if raid_timer_label:
				raid_timer_label.text = "탈출 시간: %02d:%02d" % [minutes, seconds]
				if raid_time_remaining < 60:
					raid_timer_label.add_theme_color_override("font_color", Color.RED)
			if raid_time_remaining <= 0:
				GameManager.end_raid("mia")
				
			_update_day_night_cycle()
		
		# 적 주기적 스폰
		enemy_spawn_timer -= delta
		if enemy_spawn_timer <= 0:
			enemy_spawn_timer = randf_range(4.0, 8.0)
			var current_enemies = get_tree().get_nodes_in_group("enemies").size()
			if current_enemies < max_enemies_count:
				_spawn_enemy_near_player(randf_range(350.0, 550.0))
		
		if debug_label:
			var cx = floor(player.global_position.x / (16 * 32))
			var cy = floor(player.global_position.y / (16 * 32))
			debug_label.text = "위치: (%.1f, %.1f) | 청크: (%d, %d)" % [player.global_position.x, player.global_position.y, cx, cy]

func _update_day_night_cycle() -> void:
	if not day_night_modulate: return
	var progress = 1.0 - (raid_time_remaining / 300.0) # 0.0 (시작) ~ 1.0 (끝)
	
	# 낮 -> 황혼 -> 밤 -> 새벽 사이클
	var target_color: Color
	if progress < 0.3: # 낮 (0.0 ~ 0.3)
		target_color = Color(1.0, 1.0, 1.0)
	elif progress < 0.5: # 황혼 (0.3 ~ 0.5)
		var t = (progress - 0.3) / 0.2
		target_color = Color(1.0, 1.0, 1.0).lerp(Color(0.7, 0.45, 0.4), t)
	elif progress < 0.8: # 심야 (0.5 ~ 0.8)
		var t = (progress - 0.5) / 0.3
		target_color = Color(0.7, 0.45, 0.4).lerp(Color(0.12, 0.12, 0.22), t)
	else: # 새벽/여명 (0.8 ~ 1.0)
		var t = (progress - 0.8) / 0.2
		target_color = Color(0.12, 0.12, 0.22).lerp(Color(0.5, 0.5, 0.65), t)
		
	day_night_modulate.color = target_color

func _on_player_stats_changed() -> void:
	if hp_bar:
		hp_bar.value = player.hp
		hp_bar.get_node("Label").text = "HP: %d/%d" % [int(player.hp), int(player.max_hp)]
	if stamina_bar:
		stamina_bar.value = player.stamina
		stamina_bar.get_node("Label").text = "STAMINA: %d/%d" % [int(player.stamina), int(player.max_stamina)]
	if hunger_bar:
		hunger_bar.value = player.hunger
	if thirst_bar:
		thirst_bar.value = player.thirst
		
	if status_label:
		var statuses = []
		if player.is_bleeding: statuses.append("출혈")
		if player.is_fractured: statuses.append("골절")
		if player.is_infected: statuses.append("감염")
		status_label.text = "상태이상: " + (", ".join(statuses) if statuses.size() > 0 else "없음")
		
func _on_interact_prompt(show: bool, text: String) -> void:
	if interact_prompt and current_loot_window == null:
		interact_prompt.visible = show
		interact_prompt.text = text
	elif interact_prompt:
		interact_prompt.visible = false
		
func _on_object_interacted(_world_pos: Vector2, tile_pos: Vector2i, type: Vector2i) -> void:
	if current_loot_window != null: return
	
	var table_name = ""
	var loot_title = ""
	var slots = 8
	
	if type == Vector2i(3, 1): # Crate
		table_name = "crate"
		loot_title = "파밍 상자"
		slots = 12
	elif type == Vector2i(4, 1): # Barrel
		table_name = "barrel"
		loot_title = "드럼통"
		slots = 4
	elif type == Vector2i(5, 1): # Car
		table_name = "car"
		loot_title = "폐차 트렁크"
		slots = 8
	elif type == Vector2i(6, 1): # Door
		_enter_building_interior(tile_pos)
		return
		
	if table_name != "":
		var inv: Inventory
		if container_inventories.has(tile_pos):
			inv = container_inventories[tile_pos]
		else:
			inv = Inventory.new()
			inv.max_slots = slots
			add_child(inv)
			var loot_items = ItemDatabase.generate_loot(table_name)
			for item in loot_items:
				inv.add_item(item["id"], item["amount"])
			container_inventories[tile_pos] = inv
			
		_open_loot_window(inv, loot_title)

func _enter_building_interior(tile_pos: Vector2i) -> void:
	if SoundManager: SoundManager.play("menu_select")
	
	# 현재 플레이어 데이터 및 배낭 저장
	if GameManager and not GameManager.current_world_data.is_empty():
		var saved_items = []
		for item in player_inventory.items:
			if item:
				saved_items.append(item.duplicate())
		GameManager.current_world_data["player"]["inventory"] = saved_items
		GameManager.current_world_data["raid_time_remaining"] = raid_time_remaining
		GameManager.current_world_data["player_stats"] = {
			"hp": player.hp,
			"stamina": player.stamina,
			"hunger": player.hunger,
			"thirst": player.thirst,
			"is_bleeding": player.is_bleeding,
			"is_fractured": player.is_fractured,
			"is_infected": player.is_infected,
			"flashlight_enabled": player.flashlight_enabled
		}
		
		# 바이옴에 따른 건물 타입 결정
		var b_type = "house"
		if chunk_manager and chunk_manager.generator:
			var biome = chunk_manager.generator.get_biome(tile_pos.x, tile_pos.y)
			if biome == "military": b_type = "military"
			elif biome == "commercial": b_type = "store"
			elif biome == "industrial": b_type = "hospital"
			
		GameManager.current_world_data["current_interior"] = {
			"type": b_type,
			"seed": tile_pos.x * 73856093 ^ tile_pos.y * 19349663,
			"return_pos": player.global_position
		}
		
	get_tree().change_scene_to_file("res://scenes/interior/building_interior_scene.tscn")

func _open_loot_window(target_inv: Inventory = null, title: String = "") -> void:
	get_tree().paused = true
	current_loot_window = LootWindowScene.instantiate()
	$UI.add_child(current_loot_window)
	current_loot_window.setup(player_inventory, target_inv, title)
	current_loot_window.window_closed.connect(func(): current_loot_window = null)

func _on_chunk_loaded(_chunk_pos: Vector2i, _data: Dictionary) -> void:
	pass

func _on_chunk_unloaded(_chunk_pos: Vector2i) -> void:
	pass

func _toggle_pause() -> void:
	var next_pause_state = not get_tree().paused
	get_tree().paused = next_pause_state
	pause_menu.visible = next_pause_state
	if GameManager:
		GameManager.is_paused = next_pause_state

func _on_resume_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	_toggle_pause()

func _on_exit_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	get_tree().paused = false
	if GameManager:
		GameManager.is_paused = false
		GameManager.end_raid("survived") # 테스트 편의용 안전 탈출 복귀
