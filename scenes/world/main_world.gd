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

# 좌하단 무기 상태 패널
@onready var weapon_panel: Panel = $UI/HUD/WeaponPanel
@onready var weapon_icon: TextureRect = $UI/HUD/WeaponPanel/HBox/WeaponIcon
@onready var weapon_name_label: Label = $UI/HUD/WeaponPanel/HBox/VBox/WeaponNameLabel
@onready var ammo_label: Label = $UI/HUD/WeaponPanel/HBox/VBox/AmmoLabel
@onready var weapon_durability_bar: ProgressBar = $UI/HUD/WeaponPanel/HBox/VBox/DurabilityBar

const MapWindowScene = preload("res://scenes/ui/map_window.tscn")
var current_map_window: Control = null
var extraction_points_data: Array = []

const PlayerScene = preload("res://scenes/entities/player/player.tscn")
var player: CharacterBody2D
var player_inventory: Inventory
var container_inventories: Dictionary = {} # tile_pos -> Inventory

const LootWindowScene = preload("res://scenes/ui/loot_window.tscn")
var current_loot_window: Control = null

const InventoryWindowScene = preload("res://scenes/ui/inventory_window.tscn")
var current_inventory_window: Control = null

const ItemSpawnerScene = preload("res://scenes/ui/item_spawner_window.tscn")
var current_spawner_window: Control = null

const EnemyScene = preload("res://scenes/entities/enemies/enemy.tscn")
var enemy_spawn_timer: float = 10.0
var max_enemies_count: int = 22

const ExtractionZoneScene = preload("res://scenes/world/extraction_zone.tscn")
var raid_time_remaining: float = 1800.0 # 30분
var raid_total_time: float = 1800.0
var day_night_cycle_duration: float = 300.0 # 낮/밤 1주기 시간(초)

const PostProcessLayerScene = preload("res://graphics/post_process_layer.tscn")

var particle_system: Node2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # 일시정지 중에도 메인 노드는 입력(UI) 처리를 위해 유지
	
	if chunk_manager:
		chunk_manager.process_mode = Node.PROCESS_MODE_PAUSABLE
	if player:
		player.process_mode = Node.PROCESS_MODE_PAUSABLE
	if has_node("Entities"):
		$Entities.process_mode = Node.PROCESS_MODE_PAUSABLE
		
	if pause_menu:
		pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
		
	# 포스트프로세싱 및 파티클
	var pp = PostProcessLayerScene.instantiate()
	add_child(pp)
	
	var ps_script = load("res://systems/particle_system.gd")
	particle_system = Node2D.new()
	particle_system.name = "ParticleSystem"
	particle_system.process_mode = Node.PROCESS_MODE_PAUSABLE
	particle_system.set_script(ps_script)
	add_child(particle_system)
	
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
		player_inventory.load_items(p_items)
	
	# 플레이어 인스턴스화
	player = PlayerScene.instantiate()
	var spawn_pos = Vector2.ZERO
	if GameManager and GameManager.current_world_data.has("current_interior"):
		var info = GameManager.current_world_data["current_interior"]
		if info.has("return_pos"):
			spawn_pos = info["return_pos"]
		GameManager.current_world_data.erase("current_interior")
	else:
		# 첫 레이드 출격 시 맵 중심 안전지대 주변 (300~600px) 랜덤 스폰
		spawn_pos = _get_random_spawn_pos()
		
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
		
	# 커스텀/샌드박스 설정 반영
	if GameManager and GameManager.current_world_data.has("world_settings"):
		var ws = GameManager.current_world_data["world_settings"]
		if ws.has("raid_duration_minutes"):
			var r_mins = ws["raid_duration_minutes"]
			raid_time_remaining = r_mins * 60.0
			raid_total_time = raid_time_remaining
		if ws.has("zombie_multiplier"):
			max_enemies_count = int(22 * ws["zombie_multiplier"])
		if ws.has("day_night_cycle_duration"):
			day_night_cycle_duration = ws["day_night_cycle_duration"]

	if GameManager and GameManager.current_world_data.has("raid_time_remaining"):
		raid_time_remaining = GameManager.current_world_data["raid_time_remaining"]
		GameManager.current_world_data.erase("raid_time_remaining")
		
	player.position = spawn_pos
	player.inventory = player_inventory
	entities_layer.add_child(player)
	
	# 세이브 데이터의 인벤토리 및 장비 복원
	if GameManager and not GameManager.current_world_data.is_empty():
		var p_data = GameManager.current_world_data.get("player", {})
		var saved_items = p_data.get("inventory", [])
		if p_data.has("equipment") and not p_data["equipment"].is_empty():
			player.equipment = p_data["equipment"].duplicate(true)
		if player.has_method("apply_backpack_grid_size"):
			player.apply_backpack_grid_size()
		if player.inventory_grid:
			if player.inventory_grid.has_method("load_items"):
				player.inventory_grid.load_items(saved_items)
			else:
				for s_item in saved_items:
					if s_item and not s_item.is_empty():
						player.inventory_grid.auto_add_item(s_item.get("id", ""), s_item.get("amount", 1), s_item)
	
	if player.has_method("refresh_equipped_weapon"):
		player.refresh_equipped_weapon(true)
	
	player.stats_changed.connect(_on_player_stats_changed)
	player.interact_prompt.connect(_on_interact_prompt)
	player.object_interacted.connect(_on_object_interacted)
	player_inventory.inventory_changed.connect(_on_player_stats_changed)
	if player.inventory_grid:
		player.inventory_grid.grid_changed.connect(_on_player_stats_changed)
	
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
	
	# 시작 시 주변에 초기 좀비 스폰 (설정된 밀도 반영)
	var init_zombies = int(2 * (GameManager.current_world_data.get("world_settings", {}).get("zombie_multiplier", 1.0) if GameManager else 1.0))
	for i in range(init_zombies):
		_spawn_enemy_near_player(350.0 + i * 80.0)
		
	# 탈출 지점 3개 스폰 (1800~2500px 원거리 배치)
	_spawn_extraction_zones()
	
	if EventBus.has_signal("event_logged"):
		var is_sandbox = GameManager and GameManager.current_world_data.get("world_settings", {}).get("mode", "") == "sandbox"
		if is_sandbox:
			EventBus.event_logged.emit("🛠️ 샌드박스 모드: [F1] 키를 눌러 모든 무기/부품을 소환할 수 있습니다.")
		else:
			EventBus.event_logged.emit("★ 레이드 시작: 탈출 지점을 찾아 안전하게 탈출하십시오. [F1: 치트/스포너]")
	
	GameManager.current_state = GameManager.GameState.IN_GAME
	
	# 작전 개시 및 초기 상태 안내 로그 출력
	_on_event_logged("★ [작전 개시] 30분 생존 레이드가 시작되었습니다.")
	if WeatherSystem:
		_on_event_logged("🌦️ 현재 날씨: [%s]" % WeatherSystem.get_weather_name(WeatherSystem.current_weather))
		
	# 화면 우상단 샌드박스/치트 도구 버튼 추가
	var tool_btn = Button.new()
	tool_btn.name = "SandboxToolBtn"
	tool_btn.text = "🛠️ 샌드박스 도구 (F1)"
	tool_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tool_btn.offset_left = -160.0
	tool_btn.offset_top = 10.0
	tool_btn.offset_right = -10.0
	tool_btn.offset_bottom = 44.0
	tool_btn.pressed.connect(_open_item_spawner)
	$UI.add_child(tool_btn)
	
	if ResponsiveManager:
		ResponsiveManager.breakpoint_changed.connect(_on_responsive_breakpoint_changed)
		ResponsiveManager.window_resized.connect(_on_responsive_window_resized)
		_apply_responsive_layout(ResponsiveManager.current_breakpoint, ResponsiveManager.current_viewport_size)

func _on_responsive_breakpoint_changed(new_bp: ResponsiveManager.Breakpoint, vp_size: Vector2) -> void:
	_apply_responsive_layout(new_bp, vp_size)

func _on_responsive_window_resized(vp_size: Vector2) -> void:
	if ResponsiveManager:
		_apply_responsive_layout(ResponsiveManager.current_breakpoint, vp_size)

func _apply_responsive_layout(bp: ResponsiveManager.Breakpoint, vp_size: Vector2) -> void:
	var tool_btn = $UI.get_node_or_null("SandboxToolBtn")
	if tool_btn:
		if bp == ResponsiveManager.Breakpoint.COMPACT:
			tool_btn.text = "🛠️ (F1)"
			tool_btn.offset_left = -80.0
		else:
			tool_btn.text = "🛠️ 샌드박스 도구 (F1)"
			tool_btn.offset_left = -160.0

func _get_random_spawn_pos() -> Vector2:
	var angle = randf() * TAU
	var dist = randf_range(300.0, 600.0)
	var candidate = Vector2.RIGHT.rotated(angle) * dist
	return candidate

func _spawn_extraction_zones() -> void:
	extraction_points_data.clear()
	var base_angle = randf() * TAU
	var angles = [
		base_angle,
		base_angle + TAU / 3.0 + randf_range(-0.25, 0.25),
		base_angle + 2.0 * TAU / 3.0 + randf_range(-0.25, 0.25)
	]
	for i in range(angles.size()):
		var angle = angles[i]
		var dist = randf_range(1800.0, 2400.0) # 원거리 탈출구
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
	
	var max_logs = GameSettings.max_event_logs if GameSettings else 3
	
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
	elif msg.begins_with("✓") or msg.begins_with("📦") or msg.begins_with("💊"):
		style.border_color = Color(0.3, 0.9, 0.4)
		lbl.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	elif msg.begins_with("✗") or msg.begins_with("💀") or msg.begins_with("⚠️"):
		style.border_color = Color(0.9, 0.3, 0.3)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	elif msg.begins_with("🌦️") or msg.begins_with("🌅"):
		style.border_color = Color(0.3, 0.7, 1.0)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
		
	panel.add_child(lbl)
	event_log_vbox.add_child(panel)
	
	# 새 로그 추가 시 설정된 최대치를 초과하면 가장 오래된 로그(맨 위)를 즉시 제거
	while event_log_vbox.get_child_count() > max_logs:
		var oldest = event_log_vbox.get_child(0)
		oldest.queue_free()
		event_log_vbox.remove_child(oldest)
	
	var tween = create_tween()
	tween.tween_interval(5.0) # 5초 대기
	tween.tween_property(panel, "modulate:a", 0.0, 1.0) # 1.0초간 부드럽게 페이드아웃
	tween.tween_callback(panel.queue_free)

func _spawn_enemy_near_player(dist: float = 350.0) -> void:
	if not player: return
	var angle = randf() * TAU
	var spawn_pos = player.global_position + Vector2.RIGHT.rotated(angle) * dist
	
	var enemy = EnemyScene.instantiate()
	enemy.position = spawn_pos
	# 무작위 적 타입 결정 (일반 좀비, 러너, 탱커, 무장 스캐브, 정예 레이더)
	var r = randf()
	if r < 0.08: enemy.enemy_type = 4 # RAIDER (정예 무장 용병)
	elif r < 0.25: enemy.enemy_type = 3 # SCAV (무장 약탈자)
	elif r < 0.43: enemy.enemy_type = 1 # RUNNER
	elif r < 0.55: enemy.enemy_type = 2 # TANK
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
		
	# 인벤토리 열기 (Tab 또는 I 키로 4단 인벤토리 열기)
	if event.is_action_pressed("inventory") or (event is InputEventKey and event.physical_keycode == KEY_TAB and event.pressed):
		_open_inventory_window()
		get_viewport().set_input_as_handled()
		
	# 제작창 열기 (C 키)
	if event.is_action_pressed("crafting") or (event is InputEventKey and event.physical_keycode == KEY_C and event.pressed):
		_open_crafting_window()
		get_viewport().set_input_as_handled()
		
	# 총기 모딩창 열기 (B 키)
	if event is InputEventKey and event.physical_keycode == KEY_B and event.pressed:
		_open_weapon_modding_window()
		get_viewport().set_input_as_handled()
		
	# 전술 지도 열기 (M 키)
	if event.is_action_pressed("map") or (event is InputEventKey and event.physical_keycode == KEY_M and event.pressed):
		_open_map_window()
		get_viewport().set_input_as_handled()
		
	# 크리에이티브 아이템 스포너 열기 (F1 키)
	if event is InputEventKey and event.physical_keycode == KEY_F1 and event.pressed:
		_open_item_spawner()
		get_viewport().set_input_as_handled()

func _open_item_spawner() -> void:
	if current_spawner_window != null: return
	get_tree().paused = true
	current_spawner_window = ItemSpawnerScene.instantiate()
	$UI.add_child(current_spawner_window)
	current_spawner_window.window_closed.connect(func():
		current_spawner_window = null
		_on_player_stats_changed()
	)

func _open_weapon_modding_window() -> void:
	var modding_script = load("res://scenes/ui/weapon_modding_window.gd")
	if modding_script:
		get_tree().paused = true
		var win = modding_script.new()
		$UI.add_child(win)
		var cur_w = player.equipped_weapon_data if player else {}
		var inv_target = player.inventory_grid if player and player.inventory_grid else player_inventory
		win.setup(inv_target, null, cur_w)
		win.window_closed.connect(func(): _on_player_stats_changed())

func _open_crafting_window() -> void:
	get_tree().paused = true
	current_crafting_window = CraftingWindowScene.instantiate()
	$UI.add_child(current_crafting_window)
	var inv_target = player.inventory_grid if player and player.inventory_grid else player_inventory
	current_crafting_window.setup(inv_target)
	current_crafting_window.window_closed.connect(func():
		current_crafting_window = null
		_on_player_stats_changed()
	)

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
		
		# 게임이 일시정지된 상태가 아닐 때만 시간 감소 및 갱신
		if not get_tree().paused and raid_time_remaining > 0:
			raid_time_remaining -= delta
			var minutes = int(raid_time_remaining / 60.0)
			var seconds = int(raid_time_remaining) % 60
			if raid_timer_label:
				raid_timer_label.text = "탈출 시간: %02d:%02d" % [minutes, seconds]
				if raid_time_remaining < 60:
					raid_timer_label.add_theme_color_override("font_color", Color.RED)
			if raid_time_remaining <= 0:
				EventBus.event_logged.emit("탈출 시간 초과. 작전 실패.")
				if GameManager: GameManager.end_raid("mia")
				
		# 환경 조명 변화
		if not get_tree().paused:
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
	
	# 영구 주간 (duration < 0) 설정 시 항상 밝은 낮 유지
	if day_night_cycle_duration <= 0.0:
		day_night_modulate.color = Color(1.0, 1.0, 1.0)
		return
		
	var time_elapsed = raid_total_time - raid_time_remaining
	var cycle_pos = fposmod(time_elapsed, day_night_cycle_duration)
	var progress = cycle_pos / day_night_cycle_duration # 0.0 ~ 1.0 순환 사이클
	
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
	if not player: return
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
		
	# 좌하단 무기 상태 패널 갱신
	if weapon_panel:
		var eq_wep = player.equipped_weapon
		var wep_data = ItemDatabase.get_item_data(player.equipped_weapon_data.get("id", eq_wep))
		var slot_disp = player._get_slot_display_name(player.active_weapon_slot) if player.has_method("_get_slot_display_name") else ""
		if weapon_name_label:
			weapon_name_label.text = "[%s] %s" % [slot_disp, eq_wep]
		if weapon_icon and ItemIconManager:
			weapon_icon.texture = ItemIconManager.get_icon(player.equipped_weapon_data.get("id", eq_wep))
			
		if ammo_label:
			if player.equipped_weapon_data.is_empty():
				ammo_label.text = "👊 맨손 (주먹)"
				ammo_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			elif player.active_weapon_slot == "throwable" or player.equipped_weapon_data.get("type", "") == "throwable":
				var amt = player.equipped_weapon_data.get("amount", 1)
				ammo_label.text = "💣 수량: %d개" % amt
				ammo_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
			else:
				var cur_mag = player.equipped_weapon_data.get("current_magazine_ammo", 0)
				var stats = player.equipped_weapon_data.get("computed_stats", {})
				var mag_size = stats.get("magazine_size", 15)
				var reserve_ammo = player._get_available_ammo_count() if player.has_method("_get_available_ammo_count") else 0
				var cal = player._get_compatible_ammo_types()[0] if player.has_method("_get_compatible_ammo_types") and player._get_compatible_ammo_types().size() > 0 else "탄약"
				
				ammo_label.text = "🔫 %d / %d  [%s: %d]" % [cur_mag, mag_size, cal, reserve_ammo]
				if cur_mag == 0:
					ammo_label.add_theme_color_override("font_color", Color.RED)
				else:
					ammo_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
				
		# 무기 내구도 바
		if weapon_durability_bar:
			var max_dur = wep_data.get("max_durability", 100.0)
			var cur_dur = player.equipped_weapon_data.get("durability", max_dur)
			weapon_durability_bar.max_value = max_dur
			weapon_durability_bar.value = cur_dur
			
			var fill_style = StyleBoxFlat.new()
			var ratio = float(cur_dur) / max(1.0, float(max_dur))
			if ratio > 0.6: fill_style.bg_color = Color(0.2, 0.8, 0.3)
			elif ratio > 0.3: fill_style.bg_color = Color(0.9, 0.7, 0.1)
			else: fill_style.bg_color = Color(0.9, 0.2, 0.2)
			weapon_durability_bar.add_theme_stylebox_override("fill", fill_style)
		
func _on_interact_prompt(show: bool, text: String) -> void:
	if interact_prompt and current_loot_window == null:
		interact_prompt.visible = show
		interact_prompt.text = text
	elif interact_prompt:
		interact_prompt.visible = false
		
func _on_object_interacted(world_pos: Vector2, tile_pos: Vector2i, type: Vector2i) -> void:
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
	elif type == Vector2i(0, 2): # OBJ_FRIDGE
		table_name = "residential"
		loot_title = "냉장고"
		slots = 6
	elif type == Vector2i(5, 2): # OBJ_LIGHT_SWITCH
		if player and player.has_method("set_flashlight"):
			player.set_flashlight(not player.flashlight_enabled)
		if SoundManager: SoundManager.play("menu_select")
		EventBus.event_logged.emit("💡 조명 스위치를 작동했습니다.")
		return
	elif type == Vector2i(6, 1): # OBJ_DOOR_CLOSED
		# 닫힌 문 열기 -> 열린 문으로 타일 교체 및 소음 발생
		if chunk_manager and chunk_manager.object_layer:
			chunk_manager.object_layer.set_cell(tile_pos, 0, TileManager.OBJ_DOOR_OPEN)
		EventBus.noise_created.emit(world_pos, 120.0, "door")
		EventBus.door_toggled.emit(tile_pos, true)
		EventBus.event_logged.emit("🚪 문을 열었습니다.")
		if SoundManager: SoundManager.play("menu_select")
		return
	elif type == Vector2i(7, 1): # OBJ_DOOR_OPEN
		# 열린 문 닫기 -> 닫힌 문으로 교체
		if chunk_manager and chunk_manager.object_layer:
			chunk_manager.object_layer.set_cell(tile_pos, 0, TileManager.OBJ_DOOR_CLOSED)
		EventBus.noise_created.emit(world_pos, 120.0, "door")
		EventBus.door_toggled.emit(tile_pos, false)
		EventBus.event_logged.emit("🚪 문을 닫았습니다.")
		if SoundManager: SoundManager.play("menu_select")
		return
	elif type == Vector2i(1, 2): # OBJ_WINDOW
		# 창문 깨기 -> 깨진 창문으로 타일 교체 및 큰 소음 발생
		if chunk_manager and chunk_manager.object_layer:
			chunk_manager.object_layer.set_cell(tile_pos, 0, TileManager.OBJ_WINDOW_BROKEN)
		EventBus.noise_created.emit(world_pos, 400.0, "break")
		EventBus.window_broken.emit(tile_pos)
		EventBus.event_logged.emit("💥 창문이 깨졌습니다! (큰 소음 발생)")
		if SoundManager: SoundManager.play("hit_melee")
		var ps = get_node_or_null("ParticleSystem")
		if ps: ps.emit("spark", world_pos.x, world_pos.y, 10)
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


func _open_inventory_window(target_inv: Inventory = null, title: String = "") -> void:
	if current_inventory_window != null: return
	get_tree().paused = true
	current_inventory_window = InventoryWindowScene.instantiate()
	$UI.add_child(current_inventory_window)
	current_inventory_window.setup(player, player.inventory_grid, player.equipment, target_inv, title)
	current_inventory_window.window_closed.connect(func():
		current_inventory_window = null
		_on_player_stats_changed()
	)

func _open_loot_window(target_inv: Inventory = null, title: String = "") -> void:
	_open_inventory_window(target_inv, title)

func _on_chunk_loaded(_chunk_pos: Vector2i, _data: Dictionary) -> void:
	pass

func _on_chunk_unloaded(_chunk_pos: Vector2i) -> void:
	pass

func _can_instant_extract() -> bool:
	if player and player.is_god_mode:
		return true
	if GameManager and GameManager.current_world_data.get("difficulty", "") == "casual":
		return true
	if player:
		for pt in extraction_points_data:
			if player.global_position.distance_to(pt["pos"]) <= 90.0:
				return true
	return false

func _toggle_pause() -> void:
	var next_pause_state = not get_tree().paused
	get_tree().paused = next_pause_state
	pause_menu.visible = next_pause_state
	if next_pause_state and exit_btn:
		if _can_instant_extract():
			exit_btn.text = "은신처로 안전 복귀 (전리품 보존)"
		else:
			exit_btn.text = "작전 포기 및 복귀 (MIA - 배낭 분실)"
	if GameManager:
		GameManager.is_paused = next_pause_state

func _on_resume_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	_toggle_pause()

func get_backpack_items() -> Array:
	var items_arr = []
	if player and player.inventory_grid:
		for item in player.inventory_grid.items:
			if item and not item.is_empty():
				items_arr.append(item.duplicate(true))
	elif player_inventory:
		for item in player_inventory.items:
			if item and not item.is_empty():
				items_arr.append(item.duplicate(true))
	return items_arr

func _on_exit_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	get_tree().paused = false
	if GameManager:
		GameManager.is_paused = false
		if player and not player.equipment.is_empty():
			if not GameManager.current_world_data.has("player"):
				GameManager.current_world_data["player"] = {}
			GameManager.current_world_data["player"]["equipment"] = player.equipment.duplicate(true)
		if _can_instant_extract():
			GameManager.end_raid("survived", get_backpack_items())
		else:
			GameManager.end_raid("mia")
