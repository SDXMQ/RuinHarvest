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

# 상태이상 배지
@onready var status_badges_container: HBoxContainer = get_node_or_null("UI/HUD/Panel/VBox/StatusBadgesContainer")
@onready var badge_bleed: PanelContainer = get_node_or_null("UI/HUD/Panel/VBox/StatusBadgesContainer/BleedBadge")
@onready var badge_fracture: PanelContainer = get_node_or_null("UI/HUD/Panel/VBox/StatusBadgesContainer/FractureBadge")
@onready var badge_biohazard: PanelContainer = get_node_or_null("UI/HUD/Panel/VBox/StatusBadgesContainer/BiohazardBadge")

# 채널링 진행 바
@onready var channeling_bar: ProgressBar = get_node_or_null("UI/HUD/ChannelingBar")
@onready var channeling_label: Label = get_node_or_null("UI/HUD/ChannelingBar/Label")

# 퀵슬롯 HUD 바
@onready var quickslot_bar: PanelContainer = get_node_or_null("UI/HUD/QuickslotBar")
@onready var quickslot_hbox: HBoxContainer = get_node_or_null("UI/HUD/QuickslotBar/HBox")

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
var container_inventories: Dictionary = {} # tile_pos -> Inventory

const InventoryWindowScene = preload("res://scenes/ui/inventory_window.tscn")
var current_inventory_window: Control = null

const ItemSpawnerScene = preload("res://scenes/ui/item_spawner_window.tscn")
var current_spawner_window: Control = null

const EnemyScene = preload("res://scenes/entities/enemies/enemy.tscn")
const AirdropCrateScript = preload("res://scenes/world/objects/airdrop_crate.gd")
const FieldObjectiveScript = preload("res://scenes/world/objects/field_objective.gd")
var enemy_spawn_timer: float = 10.0
var max_enemies_count: int = 22
var airdrop_timer: float = 65.0
var airdrop_count: int = 0
var max_airdrops: int = 3
var airdrop_points_data: Array = []
var weather_particle_timer: float = 0.0
var crosshair_overlay: Control = null
var crosshair_spread: float = 12.0
var hit_arc_overlay: Control = null
var hit_arcs: Array = []
var boss_entity: Node2D = null
var landmark_objective: Node2D = null
var field_objectives: Array = []

var storm_lightning_timer: float = 18.0
var storm_lightning_active: bool = false
var storm_lightning_duration: float = 0.0
var storm_thunder_delay: float = -1.0

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
	if EventBus.has_signal("random_world_event_triggered"):
		EventBus.random_world_event_triggered.connect(_on_random_world_event_triggered)
	if EventBus.has_signal("radio_scan_requested"):
		EventBus.radio_scan_requested.connect(_on_radio_scan_requested)
	
	# 플레이어 인스턴스화 및 씬 트리 등록 (@onready 컴포넌트 초기화 선행)
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
		
	player.position = spawn_pos
	entities_layer.add_child(player)
		
	# 복귀 시 스탯 및 타이머 복원 (add_child 이후에 적용해야 SurvivalStats._ready()에 덮어써지지 않음)
	if GameManager and GameManager.current_world_data.has("player_stats"):
		var s = GameManager.current_world_data["player_stats"]
		player.hp = s.get("hp", player.max_hp)
		player.stamina = s.get("stamina", player.max_stamina)
		player.hunger = s.get("hunger", player.max_hunger)
		player.thirst = s.get("thirst", player.max_thirst)
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
	if player.has_signal("channel_started"):
		player.channel_started.connect(_on_player_channel_started)
	if player.has_signal("channel_progress"):
		player.channel_progress.connect(_on_player_channel_progress)
	if player.has_signal("channel_completed"):
		player.channel_completed.connect(_on_player_channel_finished)
	if player.has_signal("channel_cancelled"):
		player.channel_cancelled.connect(_on_player_channel_finished)
	if player.inventory_grid:
		player.inventory_grid.grid_changed.connect(_on_player_stats_changed)
		player.inventory_grid.grid_changed.connect(_update_quickslot_bar)
	if player.weapon_handler:
		if player.weapon_handler.has_signal("weapon_changed"):
			player.weapon_handler.weapon_changed.connect(_update_quickslot_bar)
		if player.weapon_handler.has_signal("ammo_changed"):
			player.weapon_handler.ammo_changed.connect(_update_quickslot_bar)
	_setup_quickslot_bar()
	
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
	_spawn_landmark_boss()
		
	# 탈출 지점 3개 스폰 (1800~2500px 원거리 배치)
	_spawn_extraction_zones()
	
	# 동적 조준원(Dynamic Crosshair) 오버레이 생성
	crosshair_overlay = Control.new()
	crosshair_overlay.name = "DynamicCrosshair"
	crosshair_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair_overlay.draw.connect(_on_crosshair_draw)
	$UI/HUD.add_child(crosshair_overlay)
	
	# 피격 방향 인디케이터(Hit Arc) 오버레이 생성 및 시그널 연결
	hit_arc_overlay = Control.new()
	hit_arc_overlay.name = "HitArcOverlay"
	hit_arc_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit_arc_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit_arc_overlay.draw.connect(_on_hit_arc_draw)
	$UI/HUD.add_child(hit_arc_overlay)
	
	if EventBus.has_signal("player_hit_direction"):
		EventBus.player_hit_direction.connect(_on_player_hit_direction)
	
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

func _apply_responsive_layout(bp: ResponsiveManager.Breakpoint, _vp_size: Vector2) -> void:
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
	
	var zone_configs = [
		{
			"type": 0, # DEFAULT
			"name": "일반 탈출 지점 (헬기 착륙장)",
			"time": 7.0,
			"desc": "기본 탈출로 (소요: 7.0초)"
		},
		{
			"type": 1, # VEHICLE
			"name": "유료 탈출 지점 (장갑 SUV)",
			"time": 2.0,
			"desc": "급속 탈출 (3,000 RUB / 소요: 2.0초)"
		},
		{
			"type": 2, # BUNKER
			"name": "비상 벙커 탈출구 (지하 방공호)",
			"time": 5.0,
			"desc": "밀폐 벙커 (필드 단말기 해킹 필요 / 소요: 5.0초)"
		}
	]

	for i in range(angles.size()):
		var angle = angles[i]
		var dist = randf_range(1800.0, 2400.0) # 원거리 탈출구
		var pos = Vector2.RIGHT.rotated(angle) * dist
		var cfg = zone_configs[i]
		var zone = ExtractionZoneScene.instantiate()
		zone.position = pos
		zone.extraction_type = cfg["type"]
		zone.zone_name = cfg["name"]
		zone.extract_time = cfg["time"]
		zone.extract_progress.connect(_on_extract_progress)
		zone.extract_cancelled.connect(_on_extract_cancelled)
		add_child(zone)
		
		extraction_points_data.append({
			"name": zone.zone_name,
			"pos": pos,
			"type": zone.extraction_type,
			"extract_time": zone.extract_time,
			"desc": cfg["desc"]
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

func is_night_time() -> bool:
	if day_night_cycle_duration <= 0.0:
		return false
	var time_elapsed = raid_total_time - raid_time_remaining
	var progress = fposmod(time_elapsed, day_night_cycle_duration) / day_night_cycle_duration
	return progress >= 0.5 and progress < 0.85

func _spawn_enemy_near_player(dist: float = 350.0) -> void:
	if not player: return
	var angle = randf() * TAU
	var spawn_pos = player.global_position + Vector2.RIGHT.rotated(angle) * dist
	
	var enemy = EnemyScene.instantiate()
	enemy.position = spawn_pos
	# 무작위 적 타입 결정 (야간에는 변이체 '야간 추격자' 스폰 확률 부여)
	var r = randf()
	if is_night_time() and r < 0.28:
		enemy.enemy_type = 6 # NIGHT_STALKER (야간 추격자)
	elif r < 0.08: enemy.enemy_type = 4 # RAIDER (정예 무장 용병)
	elif r < 0.25: enemy.enemy_type = 3 # SCAV (무장 약탈자)
	elif r < 0.43: enemy.enemy_type = 1 # RUNNER
	elif r < 0.55: enemy.enemy_type = 2 # TANK
	else: enemy.enemy_type = 0 # ZOMBIE
	
	entities_layer.add_child(enemy)

const CraftingWindowScene = preload("res://scenes/ui/crafting_window.tscn")
const RadioWindowScene = preload("res://scenes/ui/radio_window.tscn")
var current_crafting_window: Control = null
var current_radio_window: Control = null

func _unhandled_input(event: InputEvent) -> void:
	if current_inventory_window != null or current_crafting_window != null or current_map_window != null or current_radio_window != null:
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

	# 전술 무전기 열기 (U 키 — 가방에 무전기 보유 시)
	if event is InputEventKey and event.physical_keycode == KEY_U and event.pressed and not event.echo:
		if player_has_radio():
			open_radio_window()
		else:
			_on_event_logged("⚠️ 가방에 [장거리 무전기]가 없어 통신망을 열 수 없습니다.")
		get_viewport().set_input_as_handled()
		
	# 크리에이티브 아이템 스포너 열기 (F1 키)
	if event is InputEventKey and event.physical_keycode == KEY_F1 and event.pressed:
		_open_item_spawner()
		get_viewport().set_input_as_handled()

func player_has_radio() -> bool:
	if not player or not player.inventory_grid:
		return false
	if player.inventory_grid.has_item("장거리 무전기", 1) or player.inventory_grid.has_item("군용 무전기", 1) or player.inventory_grid.has_item("무전기", 1):
		return true
	for it in player.inventory_grid.items:
		if String(it.get("id", "")).contains("무전기"):
			return true
	return false

func open_radio_window() -> Control:
	if current_radio_window != null:
		return current_radio_window
	if is_inside_tree() and get_tree():
		get_tree().paused = true
	current_radio_window = RadioWindowScene.instantiate()
	if has_node("UI"):
		$UI.add_child(current_radio_window)
	else:
		add_child(current_radio_window)
	if current_radio_window.has_method("setup"):
		current_radio_window.setup(player, self)
	current_radio_window.window_closed.connect(func():
		current_radio_window = null
		if is_inside_tree() and get_tree():
			get_tree().paused = false
		_on_player_stats_changed()
	)
	return current_radio_window

func _is_tile_in_locked_room(tile_pos: Vector2i) -> bool:
	if not chunk_manager or not chunk_manager.generator:
		return false
	var b_at = chunk_manager.generator.get_building_at(tile_pos.x, tile_pos.y)
	if b_at.is_empty():
		return false
	var b_preset: Dictionary = b_at.get("preset", {})
	if not b_preset.has("locked_rect"):
		return false
	var l_rect: Rect2i = b_preset["locked_rect"]
	var rel_pt := Vector2i(tile_pos.x - int(b_at["wx"]), tile_pos.y - int(b_at["wy"]))
	return l_rect.has_point(rel_pt)

func _is_valid_drone_drop_tile(t_pos: Vector2i, origin_tile: Vector2i) -> bool:
	if t_pos == origin_tile:
		return false
	if container_inventories.has(t_pos):
		return false
	if _is_tile_in_locked_room(t_pos):
		return false
	if chunk_manager and chunk_manager.object_layer:
		if chunk_manager.object_layer.get_cell_source_id(t_pos) != -1:
			return false
	return true

func find_valid_drone_drop_tile(origin_tile: Vector2i, preferred_tile: Vector2i) -> Vector2i:
	if _is_valid_drone_drop_tile(preferred_tile, origin_tile):
		return preferred_tile
	for radius in range(1, 4):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var cand := origin_tile + Vector2i(dx, dy)
				if _is_valid_drone_drop_tile(cand, origin_tile):
					return cand
	return preferred_tile

func spawn_emergency_drone_crate(drop_pos: Vector2, primary_ammo: String = "5.56mm") -> Node2D:
	var preferred_tile := Vector2i(int(floor(drop_pos.x / 32.0)), int(floor(drop_pos.y / 32.0)))
	var origin_tile := Vector2i(int(floor(player.global_position.x / 32.0)), int(floor(player.global_position.y / 32.0))) if (player != null and is_instance_valid(player)) else (preferred_tile - Vector2i(2, 0))
	var tile_pos := find_valid_drone_drop_tile(origin_tile, preferred_tile)
	var snapped_pos := Vector2(tile_pos) * 32.0 + Vector2(16.0, 16.0)
	var crate := StaticBody2D.new()
	crate.set_script(AirdropCrateScript)
	crate.position = snapped_pos
	if entities_layer:
		entities_layer.add_child(crate)
	else:
		add_child(crate)
	# 긴급 드론 투하는 신호탄 대기 시간을 단축하여 신속히 낙하(CHUTE_FALL)
	crate.current_state = 1 # DropState.CHUTE_FALL
	crate.state_timer = 1.6

	var inv := Inventory.new()
	inv.max_slots = 12
	inv.clear()
	add_child(inv)
	inv.add_item(primary_ammo, 60)
	if primary_ammo != "9mm":
		inv.add_item("9mm", 30)
	inv.add_item("고급 치료킷", 1)
	inv.add_item("구급상자", 1)
	inv.add_item("붕대", 2)
	inv.add_item("생수", 1)
	inv.set_meta("custom_title", "🚁 암시장 긴급 탄약·의료 드론 보급함")
	container_inventories[tile_pos] = inv

	airdrop_points_data.append({
		"name": "긴급 드론 보급품",
		"pos": snapped_pos
	})
	return crate

func _on_radio_scan_requested(scan_type: String) -> void:
	if not player:
		return
	if scan_type == "survivor":
		var enemies_cnt := get_tree().get_nodes_in_group("enemies").size() if get_tree() else 0
		_on_event_logged("📻 [주파수 스캔] 현재 반경 내 감지된 생체/적대 신호: %d개" % enemies_cnt)
	elif scan_type == "supply":
		if airdrop_points_data.is_empty():
			_spawn_airdrop_crate()
		else:
			var nearest = airdrop_points_data.back()
			var dist = player.global_position.distance_to(nearest["pos"])
			_on_event_logged("📻 [보급 추적] 최근 보급 투하 지점까지 거리: %.0fm" % dist)
	elif scan_type == "military":
		if is_instance_valid(boss_entity):
			var dist_b = player.global_position.distance_to(boss_entity.global_position)
			_on_event_logged("📻 [군사 암호 감청] 지휘관 보스 신호 포착 — 거리 %.0fm" % dist_b)
		else:
			_on_event_logged("📻 [군사 암호 감청] 보스 생체 신호 소멸 확인.")

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
		var inv_target = player.inventory_grid if player else null
		win.setup(inv_target, null, cur_w)
		win.window_closed.connect(func(): _on_player_stats_changed())

func _open_crafting_window() -> void:
	get_tree().paused = true
	current_crafting_window = CraftingWindowScene.instantiate()
	$UI.add_child(current_crafting_window)
	var inv_target = player.inventory_grid if player else null
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
		
	var chunks_dict = chunk_manager.loaded_chunks if chunk_manager else {}
	current_map_window.setup(player.global_position, player.rotation, extraction_points_data, biome, boss_entity, airdrop_points_data, field_objectives, chunks_dict)
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
			var pt_type = int(pt.get("type", 0))
			var pt_col = Color(0.2, 1.0, 0.3)
			var txt_col = Color(0.3, 1.0, 0.4)
			var lock_suffix = ""
			if pt_type == 1:
				var cur_rub = int(GameManager.current_world_data.get("player", {}).get("rubles", GameManager.current_world_data.get("rubles", 0))) if GameManager else 0
				if cur_rub < 3000:
					pt_col = Color(0.55, 0.55, 0.58, 0.55)
					txt_col = Color(0.95, 0.42, 0.42, 0.78)
					lock_suffix = " [잠김: 3,000R 필요]"
				else:
					pt_col = Color(1.0, 0.82, 0.15)
					txt_col = Color(1.0, 0.9, 0.3)
			elif pt_type == 2:
				var bunker_unlocked = false
				if GameManager:
					if GameManager.raid_landmark_completed:
						bunker_unlocked = true
					elif int(GameManager.current_world_data.get("player", {}).get("field_objectives_completed", 0)) >= 1:
						bunker_unlocked = true
				for f_obj in field_objectives:
					if is_instance_valid(f_obj) and bool(f_obj.get("is_completed")):
						bunker_unlocked = true
						break
				if not bunker_unlocked:
					pt_col = Color(0.55, 0.55, 0.58, 0.55)
					txt_col = Color(0.95, 0.42, 0.42, 0.78)
					lock_suffix = " [잠김: 단말기 미해킹]"
				else:
					pt_col = Color(0.2, 0.85, 1.0)
					txt_col = Color(0.4, 0.9, 1.0)
			compass_bar.draw_colored_polygon(diamond, pt_col)
			compass_bar.draw_string(ThemeDB.fallback_font, Vector2(x - 12, 22), "%.0fm%s" % [dist, lock_suffix], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, txt_col)

	# 항공 보급품 마커 (주황/붉은 다이아몬드)
	for ad in airdrop_points_data:
		var dir_to_ad = player.global_position.direction_to(ad["pos"])
		var ad_deg = rad_to_deg(dir_to_ad.angle())
		if ad_deg < 0: ad_deg += 360.0
		var diff = ad_deg - player_deg
		while diff < -180.0: diff += 360.0
		while diff > 180.0: diff -= 360.0
		if abs(diff) <= fov / 2.0:
			var x = center_x + diff * pixels_per_deg
			var dist = player.global_position.distance_to(ad["pos"])
			var box_mark = PackedVector2Array([
				Vector2(x - 4, 5), Vector2(x + 4, 5), Vector2(x + 4, 13), Vector2(x - 4, 13)
			])
			compass_bar.draw_colored_polygon(box_mark, Color(1.0, 0.45, 0.15))
			compass_bar.draw_string(ThemeDB.fallback_font, Vector2(x - 14, 22), "📦%.0fm" % dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.65, 0.25))
			
	# 랜드마크 보스 마커 (붉은 왕관/해골 표식)
	if is_instance_valid(boss_entity) and boss_entity.get("hp") != null and boss_entity.hp > 0:
		var dir_to_boss = player.global_position.direction_to(boss_entity.global_position)
		var boss_deg = rad_to_deg(dir_to_boss.angle())
		if boss_deg < 0: boss_deg += 360.0
		var b_diff = boss_deg - player_deg
		while b_diff < -180.0: b_diff += 360.0
		while b_diff > 180.0: b_diff -= 360.0
		if abs(b_diff) <= fov / 2.0:
			var bx = center_x + b_diff * pixels_per_deg
			var b_dist = player.global_position.distance_to(boss_entity.global_position)
			compass_bar.draw_circle(Vector2(bx, 9), 4.5, Color(0.95, 0.15, 0.2))
			compass_bar.draw_string(ThemeDB.fallback_font, Vector2(bx - 16, 22), "💀%.0fm" % b_dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.35, 0.35))
			
	# 랜드마크 현장 단말기 마커 (다중 현장 임무 3종 지원)
	var objs_to_draw = field_objectives if field_objectives.size() > 0 else ([landmark_objective] if is_instance_valid(landmark_objective) else [])
	for obj_ref in objs_to_draw:
		if is_instance_valid(obj_ref) and not bool(obj_ref.get("is_completed")):
			var dir_to_obj = player.global_position.direction_to(obj_ref.global_position)
			var obj_deg = rad_to_deg(dir_to_obj.angle())
			if obj_deg < 0: obj_deg += 360.0
			var o_diff = obj_deg - player_deg
			while o_diff < -180.0: o_diff += 360.0
			while o_diff > 180.0: o_diff -= 360.0
			if abs(o_diff) <= fov / 2.0:
				var ox = center_x + o_diff * pixels_per_deg
				var o_dist = player.global_position.distance_to(obj_ref.global_position)
				var icon_str = obj_ref.get_compass_icon() if obj_ref.has_method("get_compass_icon") else "📡"
				compass_bar.draw_circle(Vector2(ox, 9), 4.0, Color(0.2, 0.88, 1.0))
				compass_bar.draw_string(ThemeDB.fallback_font, Vector2(ox - 16, 22), "%s%.0fm" % [icon_str, o_dist], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.4, 0.92, 1.0))

	# 정중앙 조준 눈금 (노란 역삼각형)
	var pointer = PackedVector2Array([
		Vector2(center_x - 4, 0), Vector2(center_x + 4, 0), Vector2(center_x, 6)
	])
	compass_bar.draw_colored_polygon(pointer, Color(1.0, 0.85, 0.2))

func _spawn_landmark_boss() -> void:
	if not player: return
	var angle = randf() * TAU
	var dist = randf_range(580.0, 820.0)
	var boss_pos = player.global_position + Vector2.RIGHT.rotated(angle) * dist
	var boss = EnemyScene.instantiate()
	boss.position = boss_pos
	boss.enemy_type = 5 # EnemyType.BOSS
	entities_layer.add_child(boss)
	boss_entity = boss
	# 보스 호위 레이더 1기 배치
	var escort = EnemyScene.instantiate()
	escort.position = boss_pos + Vector2(36, -24)
	escort.enemy_type = 4 # EnemyType.RAIDER
	entities_layer.add_child(escort)
	# 랜드마크 현장 상호작용 퀘스트 오브젝트 3종 스폰 (군사 단말기 / 병원 생체 표본 채취기 / 상업 지구 무선 중계기)
	field_objectives.clear()
	var obj_Offsets = [
		boss_pos + Vector2(-220, 140),
		player.global_position + Vector2.RIGHT.rotated(angle + TAU / 3.0) * randf_range(560.0, 760.0),
		player.global_position + Vector2.RIGHT.rotated(angle + 2.0 * TAU / 3.0) * randf_range(560.0, 760.0)
	]
	for idx in range(3):
		var obj_node = StaticBody2D.new()
		obj_node.set_script(FieldObjectiveScript)
		obj_node.objective_kind = idx
		obj_node.position = obj_Offsets[idx]
		if obj_node.has_signal("defense_wave_triggered"):
			obj_node.defense_wave_triggered.connect(_on_field_objective_wave_triggered)
		entities_layer.add_child(obj_node)
		field_objectives.append(obj_node)
		if idx == 0:
			landmark_objective = obj_node

func _on_field_objective_wave_triggered(obj_pos: Vector2, obj_kind: int) -> void:
	for i in range(2):
		var wave_enemy = EnemyScene.instantiate()
		var spawn_ang = randf() * TAU
		wave_enemy.position = obj_pos + Vector2.RIGHT.rotated(spawn_ang) * randf_range(190.0, 260.0)
		if obj_kind == 0:
			wave_enemy.enemy_type = 4 if i == 0 else 3 # 군사기지: 레이더 + 스캐브
		elif obj_kind == 1:
			wave_enemy.enemy_type = 1 if i == 0 else 2 # 병원구역: 러너 + 탱커
		else:
			wave_enemy.enemy_type = 3 if i == 0 else 1 # 상업지구: 스캐브 + 러너
		entities_layer.add_child(wave_enemy)

func _on_crosshair_draw() -> void:
	if not crosshair_overlay or not player or get_tree().paused:
		return
	var m_pos = crosshair_overlay.get_local_mouse_position()
	var gap = clamp(crosshair_spread, 4.0, 48.0)
	var line_len = 7.0
	var is_ads = player.player_camera.is_aiming_ads if player.player_camera else false
	var col = Color(0.25, 1.0, 0.45, 0.88) if is_ads else Color(1.0, 0.96, 0.82, 0.82)
	var shadow_col = Color(0.0, 0.0, 0.0, 0.65)
	
	var dirs = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	for d in dirs:
		var p1 = m_pos + d * gap
		var p2 = m_pos + d * (gap + line_len)
		crosshair_overlay.draw_line(p1, p2, shadow_col, 3.0)
		crosshair_overlay.draw_line(p1, p2, col, 1.6)
	crosshair_overlay.draw_circle(m_pos, 1.8, col)

	# 총기 기능고장 (JAM) 발생 시 우하단 붉은색 점멸 라벨 표시
	var w_handler = player.weapon_handler if player and "weapon_handler" in player else null
	if w_handler and bool(w_handler.get("is_jammed")):
		if (Time.get_ticks_msec() / 250) % 2 == 0:
			var jam_pos = m_pos + Vector2(16, 16)
			crosshair_overlay.draw_string(ThemeDB.fallback_font, jam_pos + Vector2(1, 1), "[JAM - Press R]", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.8))
			crosshair_overlay.draw_string(ThemeDB.fallback_font, jam_pos, "[JAM - Press R]", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.2, 0.2, 1.0))

func _on_player_hit_direction(attacker_pos: Vector2) -> void:
	if not player: return
	var diff = attacker_pos - player.global_position
	var dist = diff.length()
	var angle = diff.angle() if dist > 0.001 else 0.0
	hit_arcs.append({
		"angle": angle,
		"timer": 0.4,
		"max_time": 0.4
	})
	if EventBus.has_signal("camera_shake_requested"):
		EventBus.camera_shake_requested.emit(4.0, 0.2)
	if hit_arc_overlay:
		hit_arc_overlay.queue_redraw()

func _on_hit_arc_draw() -> void:
	if not hit_arc_overlay or hit_arcs.is_empty():
		return
	var center = hit_arc_overlay.size * 0.5
	var arc_radius = 130.0
	var arc_width = 3.5
	var arc_spread = deg_to_rad(38.0) # 아크 각도 범위 (약 38도)

	for arc_data in hit_arcs:
		var alpha = clamp(arc_data["timer"] / arc_data["max_time"], 0.0, 1.0)
		var arc_angle = arc_data["angle"]
		var col = Color(1.0, 0.15, 0.15, 0.85 * alpha)
		var shadow_col = Color(0.1, 0.0, 0.0, 0.45 * alpha)

		# 붉은색 호 및 외곽 쉐도우
		hit_arc_overlay.draw_arc(center, arc_radius, arc_angle - arc_spread * 0.5, arc_angle + arc_spread * 0.5, 16, shadow_col, arc_width + 2.0)
		hit_arc_overlay.draw_arc(center, arc_radius, arc_angle - arc_spread * 0.5, arc_angle + arc_spread * 0.5, 16, col, arc_width)

		# 공격자 방향을 가리키는 전술적 화살표 팁
		var tip_dir = Vector2.RIGHT.rotated(arc_angle)
		var tip_pos = center + tip_dir * (arc_radius + 6.0)
		var p_left = center + Vector2.RIGHT.rotated(arc_angle - 0.09) * (arc_radius + 1.0)
		var p_right = center + Vector2.RIGHT.rotated(arc_angle + 0.09) * (arc_radius + 1.0)
		hit_arc_overlay.draw_colored_polygon(PackedVector2Array([tip_pos, p_left, p_right]), col)

func _spawn_airdrop_crate() -> void:
	if not player: return
	var angle = randf() * TAU
	var dist = randf_range(420.0, 780.0)
	var drop_pos = player.global_position + Vector2.RIGHT.rotated(angle) * dist
	
	var crate = StaticBody2D.new()
	crate.set_script(AirdropCrateScript)
	crate.position = drop_pos
	if crate.has_signal("crate_landed"):
		crate.crate_landed.connect(_on_airdrop_crate_landed)
	entities_layer.add_child(crate)
	
	airdrop_points_data.append({
		"name": "항공 보급품 #%d" % (airdrop_count + 1),
		"pos": drop_pos
	})
	airdrop_count += 1
		
	if SoundManager:
		SoundManager.play("explosion_distant")
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("★ 🪂 [긴급 공수] 군용 항공 보급품이 투하되었습니다! (나침반 📦 마커 확인)")

func _on_airdrop_crate_landed(drop_pos: Vector2) -> void:
	# 보급품 착지(LANDED_IMPACT) 시점에 주변 정예 호위 병력(RAIDER 1명, SCAV 1명) 스폰
	for i in range(2):
		var guard = EnemyScene.instantiate()
		guard.position = drop_pos + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(45.0, 90.0)
		guard.enemy_type = 4 if i == 0 else 3
		entities_layer.add_child(guard)

func _update_weather_particles(delta: float) -> void:
	if not particle_system or not WeatherSystem or not player:
		return
	weather_particle_timer -= delta
	if weather_particle_timer > 0.0:
		return
	weather_particle_timer = 0.08
	var w = WeatherSystem.current_weather
	var px = player.global_position.x
	var py = player.global_position.y
	if w == WeatherSystem.WeatherType.RAIN:
		particle_system.emit("rain", px, py, 6, 0.0, {"wind": -1.5})
	elif w == WeatherSystem.WeatherType.HEAVY_RAIN:
		particle_system.emit("rain", px, py, 14, 0.0, {"wind": -3.5})
	elif w == WeatherSystem.WeatherType.STORM:
		particle_system.emit("rain", px, py, 20, 0.0, {"wind": -6.0})
	elif w == WeatherSystem.WeatherType.FOG:
		if randf() < 0.35:
			particle_system.emit("fog", px, py, 2)

func _process(delta: float) -> void:
	if player:
		chunk_manager.update_chunks(player.global_position)
		if compass_bar:
			compass_bar.queue_redraw()
		if crosshair_overlay:
			var w_stats = player.equipped_weapon_data.get("computed_stats", {}) if not player.equipped_weapon_data.is_empty() else {}
			var acc = float(w_stats.get("accuracy", 78.0))
			var base_spread = max(5.0, (100.0 - acc) * 0.45)
			var move_penalty = player.velocity.length() * 0.075
			var recoil_pen = (player.weapon_handler.recoil_offset * 1.8) if player.weapon_handler else 0.0
			var target_spread = base_spread + move_penalty + recoil_pen
			if player.player_camera and player.player_camera.is_aiming_ads:
				target_spread *= 0.48
			elif player.is_crouching:
				target_spread *= 0.72
			crosshair_spread = lerp(crosshair_spread, target_spread, clamp(delta * 14.0, 0.0, 1.0))
			crosshair_overlay.queue_redraw()
		
		# 피격 방향 인디케이터(Hit Arc) 타이머 갱신 및 페이드아웃
		if hit_arcs.size() > 0:
			for i in range(hit_arcs.size() - 1, -1, -1):
				hit_arcs[i]["timer"] -= delta
				if hit_arcs[i]["timer"] <= 0.0:
					hit_arcs.remove_at(i)
			if hit_arc_overlay:
				hit_arc_overlay.queue_redraw()
		
		# 상태이상 배지 맥동 점멸 연출 (0.35 ~ 1.0)
		var pulse_alpha = 0.675 + 0.325 * sin(Time.get_ticks_msec() * 0.008)
		if badge_bleed and badge_bleed.visible:
			badge_bleed.modulate.a = pulse_alpha
		if badge_fracture and badge_fracture.visible:
			badge_fracture.modulate.a = pulse_alpha
		if badge_biohazard and badge_biohazard.visible:
			badge_biohazard.modulate.a = pulse_alpha

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
				if GameManager: GameManager.end_raid("mia", get_backpack_items())
				
		# 환경 조명 및 날씨 파티클 변화
		if not get_tree().paused:
			if WeatherSystem and WeatherSystem.current_weather == WeatherSystem.WeatherType.STORM:
				storm_lightning_timer -= delta
				if storm_lightning_timer <= 0.0:
					storm_lightning_timer = randf_range(15.0, 25.0)
					storm_lightning_active = true
					storm_lightning_duration = 0.35
					storm_thunder_delay = 1.0
					if day_night_modulate:
						day_night_modulate.color = Color(1.6, 1.8, 2.2) # 번개 섬광
				
				if storm_lightning_active:
					storm_lightning_duration -= delta
					if storm_lightning_duration <= 0.0:
						storm_lightning_active = false
						_update_day_night_cycle()
					elif day_night_modulate:
						# 부드러운 잔광 (Afterglow) lerp 보간
						var flash_color = Color(1.6, 1.8, 2.2)
						var target_ambient = _get_current_ambient_color()
						var t = clamp(storm_lightning_duration / 0.35, 0.0, 1.0)
						day_night_modulate.color = target_ambient.lerp(flash_color, t)
				else:
					_update_day_night_cycle()
				
				if storm_thunder_delay > 0.0:
					storm_thunder_delay -= delta
					if storm_thunder_delay <= 0.0:
						storm_thunder_delay = -1.0
						if SoundManager:
							SoundManager.play("explosion_distant")
						if EventBus.has_signal("camera_shake_requested"):
							EventBus.camera_shake_requested.emit(4.5, 0.45)
						if EventBus.has_signal("event_logged"):
							EventBus.event_logged.emit("⚡ 콰르릉! 폭풍우 뇌우가 근처에 내리쳤습니다!")
			else:
				storm_lightning_active = false
				_update_day_night_cycle()
				
			_update_weather_particles(delta)
			if airdrop_count < max_airdrops:
				airdrop_timer -= delta
				if airdrop_timer <= 0.0:
					airdrop_timer = randf_range(95.0, 140.0)
					_spawn_airdrop_crate()
		
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

func _get_current_ambient_color() -> Color:
	if day_night_cycle_duration <= 0.0:
		return Color(1.0, 1.0, 1.0)
	var time_elapsed = raid_total_time - raid_time_remaining
	var cycle_pos = fposmod(time_elapsed, day_night_cycle_duration)
	var progress = cycle_pos / day_night_cycle_duration
	if progress < 0.3:
		return Color(1.0, 1.0, 1.0)
	elif progress < 0.5:
		var t = (progress - 0.3) / 0.2
		return Color(1.0, 1.0, 1.0).lerp(Color(0.7, 0.45, 0.4), t)
	elif progress < 0.8:
		var t = (progress - 0.5) / 0.3
		return Color(0.7, 0.45, 0.4).lerp(Color(0.12, 0.12, 0.22), t)
	else:
		var t = (progress - 0.8) / 0.2
		return Color(0.12, 0.12, 0.22).lerp(Color(0.5, 0.5, 0.65), t)

func _update_day_night_cycle() -> void:
	if not day_night_modulate or storm_lightning_active: return
	day_night_modulate.color = _get_current_ambient_color()

func _on_random_world_event_triggered(_event_id: String, event_data: Dictionary) -> void:
	if not player: return
	if event_data.has("raider_count"):
		var r_count = int(event_data.get("raider_count", 2))
		for i in range(r_count):
			var angle = randf() * TAU
			var spawn_pos = player.global_position + Vector2.RIGHT.rotated(angle) * randf_range(280.0, 420.0)
			var raider = EnemyScene.instantiate()
			raider.position = spawn_pos
			raider.enemy_type = 4 # EnemyType.RAIDER
			entities_layer.add_child(raider)
	elif event_data.has("enemy_count"):
		var count = int(event_data.get("enemy_count", 8))
		for i in range(count):
			_spawn_enemy_near_player(randf_range(320.0, 520.0))
	elif event_data.has("loot"):
		_spawn_airdrop_crate()

func _on_player_stats_changed() -> void:
	if not player: return
	if hp_bar:
		hp_bar.max_value = player.max_hp
		hp_bar.value = player.hp
		hp_bar.get_node("Label").text = "HP: %d/%d" % [int(player.hp), int(player.max_hp)]
	if stamina_bar:
		stamina_bar.max_value = player.max_stamina
		stamina_bar.value = player.stamina
		stamina_bar.get_node("Label").text = "STAMINA: %d/%d" % [int(player.stamina), int(player.max_stamina)]
	if hunger_bar:
		hunger_bar.value = player.hunger
	if thirst_bar:
		thirst_bar.value = player.thirst
		
	var has_status = player.is_bleeding or player.is_fractured or player.is_infected
	if badge_bleed:
		badge_bleed.visible = player.is_bleeding
	if badge_fracture:
		badge_fracture.visible = player.is_fractured
	if badge_biohazard:
		badge_biohazard.visible = player.is_infected
		
	if status_label:
		var statuses = []
		if player.is_bleeding: statuses.append("출혈")
		if player.is_fractured: statuses.append("골절")
		if player.is_infected: statuses.append("감염")
		status_label.text = "상태이상: " + (", ".join(statuses) if statuses.size() > 0 else "없음")
		status_label.visible = not has_status
		
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
			var max_dur = float(player.equipped_weapon_data.get("max_durability", wep_data.get("max_durability", 100.0)))
			var cur_dur = float(player.equipped_weapon_data.get("durability", max_dur))
			weapon_durability_bar.max_value = max_dur
			weapon_durability_bar.value = cur_dur
			
			var fill_style: StyleBoxFlat
			if weapon_durability_bar.has_theme_stylebox_override("fill"):
				fill_style = weapon_durability_bar.get_theme_stylebox("fill") as StyleBoxFlat
			if not fill_style:
				var base_style = weapon_durability_bar.get_theme_stylebox("fill")
				fill_style = base_style.duplicate() as StyleBoxFlat if base_style is StyleBoxFlat else StyleBoxFlat.new()
				weapon_durability_bar.add_theme_stylebox_override("fill", fill_style)
			var ratio = float(cur_dur) / max(1.0, float(max_dur))
			var target_fill_col = Color(0.2, 0.8, 0.3) if ratio > 0.6 else (Color(0.9, 0.7, 0.1) if ratio > 0.3 else Color(0.9, 0.2, 0.2))
			if fill_style.bg_color != target_fill_col:
				fill_style.bg_color = target_fill_col

func _setup_quickslot_bar() -> void:
	if not quickslot_hbox or not player: return
	
	var slot1 = quickslot_hbox.get_node_or_null("Slot1")
	var slot2 = quickslot_hbox.get_node_or_null("Slot2")
	var slot3 = quickslot_hbox.get_node_or_null("Slot3")
	var slot4 = quickslot_hbox.get_node_or_null("Slot4")
	var slot5 = quickslot_hbox.get_node_or_null("Slot5")
	var slot6 = quickslot_hbox.get_node_or_null("Slot6")
	var slot7 = quickslot_hbox.get_node_or_null("Slot7")
	var slotN = quickslot_hbox.get_node_or_null("SlotN")
	
	if slot1 and not slot1.pressed.is_connected(_on_quickslot_1_pressed):
		slot1.pressed.connect(_on_quickslot_1_pressed)
	if slot2 and not slot2.pressed.is_connected(_on_quickslot_2_pressed):
		slot2.pressed.connect(_on_quickslot_2_pressed)
	if slot3 and not slot3.pressed.is_connected(_on_quickslot_3_pressed):
		slot3.pressed.connect(_on_quickslot_3_pressed)
	if slot4 and not slot4.pressed.is_connected(_on_quickslot_4_pressed):
		slot4.pressed.connect(_on_quickslot_4_pressed)
	if slot5 and not slot5.pressed.is_connected(_on_quickslot_5_pressed):
		slot5.pressed.connect(_on_quickslot_5_pressed)
	if slot6 and not slot6.pressed.is_connected(_on_quickslot_6_pressed):
		slot6.pressed.connect(_on_quickslot_6_pressed)
	if slot7 and not slot7.pressed.is_connected(_on_quickslot_7_pressed):
		slot7.pressed.connect(_on_quickslot_7_pressed)
	if slotN and not slotN.pressed.is_connected(_on_quickslot_N_pressed):
		slotN.pressed.connect(_on_quickslot_N_pressed)
		
	_update_quickslot_bar()

func _on_quickslot_1_pressed() -> void:
	if player and player.weapon_handler:
		if player.is_channeling: player.cancel_channeling()
		player.weapon_handler.switch_weapon_slot("primary1")
		_update_quickslot_bar()

func _on_quickslot_2_pressed() -> void:
	if player and player.weapon_handler:
		if player.is_channeling: player.cancel_channeling()
		player.weapon_handler.switch_weapon_slot("primary2")
		_update_quickslot_bar()

func _on_quickslot_3_pressed() -> void:
	if player and player.weapon_handler:
		if player.is_channeling: player.cancel_channeling()
		player.weapon_handler.switch_weapon_slot("sidearm")
		_update_quickslot_bar()

func _on_quickslot_4_pressed() -> void:
	if player and player.weapon_handler:
		if player.is_channeling: player.cancel_channeling()
		player.weapon_handler.switch_weapon_slot("throwable")
		_update_quickslot_bar()

func _on_quickslot_5_pressed() -> void:
	if player and player.has_method("_use_quickslot_item"):
		player._use_quickslot_item("bleed")

func _on_quickslot_6_pressed() -> void:
	if player and player.has_method("_use_quickslot_item"):
		player._use_quickslot_item("heal")

func _on_quickslot_7_pressed() -> void:
	if player and player.has_method("_use_quickslot_item"):
		player._use_quickslot_item("ration")

func _on_quickslot_N_pressed() -> void:
	if player and player.player_lighting and player.player_lighting.has_method("toggle_nvg"):
		player.player_lighting.toggle_nvg()
		if SoundManager: SoundManager.play("menu_select")
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("🥽 야간투시경(NVG): %s" % ("ON" if player.player_lighting.nvg_enabled else "OFF"))
		_update_quickslot_bar()

func _update_quickslot_bar() -> void:
	if not quickslot_hbox or not player: return
	HudTacticalHelper.update_quickslot_bar(quickslot_hbox, player)

func _on_player_channel_started(duration: float, item_name: String) -> void:
	if channeling_bar:
		channeling_bar.visible = true
		channeling_bar.max_value = duration
		channeling_bar.value = 0.0
		if channeling_label:
			channeling_label.text = "%s 사용 중... (%.1f초)" % [item_name, duration]

func _on_player_channel_progress(current: float, total: float) -> void:
	if channeling_bar:
		channeling_bar.value = current
		if channeling_label:
			var rem = max(0.0, total - current)
			channeling_label.text = "%s (%.1f초)" % [player.channel_item_name, rem]
	if quickslot_hbox and player:
		var ratio = current / max(0.01, total)
		var item_str = player.channel_item_name
		var slot_key = "6"
		if item_str.contains("붕대") or item_str.contains("지혈"): slot_key = "5"
		elif item_str.contains("구급") or item_str.contains("키트") or item_str.contains("부목"): slot_key = "6"
		elif item_str.contains("식량") or item_str.contains("통조림") or item_str.contains("생수") or item_str.contains("물"): slot_key = "7"
		HudTacticalHelper.update_channeling_sweep(quickslot_hbox, slot_key, ratio)

func _on_player_channel_finished() -> void:
	if channeling_bar:
		channeling_bar.visible = false
	if quickslot_hbox:
		HudTacticalHelper.update_channeling_sweep(quickslot_hbox, "clear", 0.0)
	_update_quickslot_bar()
		
func _on_interact_prompt(can_interact: bool, text: String) -> void:
	if interact_prompt and current_inventory_window == null:
		interact_prompt.visible = can_interact
		interact_prompt.text = text
	elif interact_prompt:
		interact_prompt.visible = false
		
func _on_object_interacted(world_pos: Vector2, tile_pos: Vector2i, type: Vector2i) -> void:
	if current_inventory_window != null: return
	
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
		table_name = "fridge"
		loot_title = "냉장고"
		slots = 6
	elif type == Vector2i(0, 3): # OBJ_BED
		table_name = "bed"
		loot_title = "침대 주변"
		slots = 6
	elif type == Vector2i(1, 3): # OBJ_DESK
		table_name = "desk"
		loot_title = "책상 서랍"
		slots = 8
	elif type == Vector2i(2, 3): # OBJ_SHELF
		table_name = "shelf"
		loot_title = "수납 선반장"
		slots = 8
	elif type == Vector2i(7, 2): # Airdrop Crate
		table_name = "military"
		loot_title = "🪂 군용 항공 보급품"
		slots = 12
	elif type == Vector2i(5, 2): # OBJ_LIGHT_SWITCH
		if player and player.has_method("set_flashlight"):
			player.set_flashlight(not player.flashlight_enabled)
		if SoundManager: SoundManager.play("menu_select")
		EventBus.event_logged.emit("💡 조명 스위치를 작동했습니다.")
		return
	elif type == Vector2i(3, 3): # OBJ_DOOR_LOCKED
		var req_key = "무기고 열쇠"
		if chunk_manager and chunk_manager.generator:
			var b_info = chunk_manager.generator.get_building_at(tile_pos.x, tile_pos.y)
			if not b_info.is_empty():
				req_key = String(b_info.get("preset", {}).get("locked_key", "무기고 열쇠"))
		var has_valid_key = false
		var used_key_name = req_key
		if player and player.inventory_grid:
			if player.inventory_grid.has_item(req_key, 1):
				has_valid_key = true
			elif req_key == "무기고 열쇠" and player.inventory_grid.has_item("보안 키카드", 1):
				has_valid_key = true
				used_key_name = "보안 키카드"
		if not has_valid_key:
			if SoundManager: SoundManager.play("hit_melee")
			EventBus.event_logged.emit("🔒 잠겨 있습니다! [%s]가 가방 또는 안전 컨테이너에 필요합니다." % req_key)
			return
		if chunk_manager and chunk_manager.object_layer:
			chunk_manager.object_layer.set_cell(tile_pos, 0, TileManager.OBJ_DOOR_OPEN)
		EventBus.noise_created.emit(world_pos, 140.0, "door")
		EventBus.door_toggled.emit(tile_pos, true)
		EventBus.event_logged.emit("🔓 [%s]로 보안 잠금문을 개방했습니다!" % used_key_name)
		if SoundManager: SoundManager.play("item_pickup")
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
		EventBus.door_toggled.emit(tile_pos, true)
		EventBus.window_broken.emit(tile_pos)
		EventBus.event_logged.emit("💥 창문이 깨졌습니다! (큰 소음 발생)")
		if SoundManager: SoundManager.play("hit_melee")
		var ps = get_node_or_null("ParticleSystem")
		if ps: ps.emit("spark", world_pos.x, world_pos.y, 10)
		return
		
	if table_name != "":
		var in_locked_vault_kind = ""
		if chunk_manager and chunk_manager.generator and type != Vector2i(7, 2):
			var b_at = chunk_manager.generator.get_building_at(tile_pos.x, tile_pos.y)
			if not b_at.is_empty():
				var b_preset: Dictionary = b_at.get("preset", {})
				if b_preset.has("locked_rect"):
					var l_rect: Rect2i = b_preset["locked_rect"]
					var rel_pt = Vector2i(tile_pos.x - int(b_at["wx"]), tile_pos.y - int(b_at["wy"]))
					if l_rect.has_point(rel_pt):
						var t_name = String(b_preset.get("type_name", ""))
						if t_name == "hospital":
							in_locked_vault_kind = "medical"
							table_name = "locked_medical"
							loot_title = "🏥 원장실 보안 보관함"
							slots = 12
						else:
							in_locked_vault_kind = "armory"
							table_name = "locked_armory"
							loot_title = "🔐 특수 무기고 보관함"
							slots = 12
		var inv: Inventory
		if container_inventories.has(tile_pos):
			inv = container_inventories[tile_pos]
			if inv.has_meta("custom_title"):
				loot_title = String(inv.get_meta("custom_title"))
		else:
			inv = Inventory.new()
			inv.max_slots = slots
			inv.clear()
			add_child(inv)
			if type == Vector2i(7, 2):
				var bonus_weapons = ["M4_리시버", "AK_리시버", "SV98_리시버"]
				var bonus_gear = ["3레벨_방탄복", "3레벨_헬멧", "3레벨_가방", "고급 치료킷", "구급상자", "장거리 무전기", "금시계"]
				var rec_id = bonus_weapons[randi() % bonus_weapons.size()]
				var w_dict = WeaponPartsDatabase.create_default_weapon(rec_id)
				inv.add_item(rec_id, 1, w_dict)
				inv.add_item(bonus_gear[randi() % bonus_gear.size()], 1)
				inv.add_item("수류탄", 2)
			elif in_locked_vault_kind == "armory" and type == Vector2i(3, 1):
				var vault_weapons = ["M4_리시버", "AK_리시버", "SV98_리시버"]
				var v_rec = vault_weapons[randi() % vault_weapons.size()]
				inv.add_item(v_rec, 1, WeaponPartsDatabase.create_default_weapon(v_rec))
			elif in_locked_vault_kind == "medical" and type == Vector2i(3, 1):
				inv.add_item("고급 치료킷", 1)
				inv.add_item("암호화된 SSD", 1)
			var loot_items = ItemDatabase.generate_loot(table_name)
			for item in loot_items:
				inv.add_item(item["id"], item["amount"])
			container_inventories[tile_pos] = inv
			
		_open_loot_window(inv, loot_title)


func _open_inventory_window(target_inv: Inventory = null, title: String = "") -> void:
	if current_inventory_window != null: return
	if not is_inside_tree() or get_tree() == null: return
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
	# 샌드박스 모드에서만 ESC 메뉴를 통한 즉시 안전 탈출 허용 (일반 모드는 인게임 탈출구에서만 가능)
	var is_sandbox = GameManager and GameManager.current_world_data.get("world_settings", {}).get("mode", "") == "sandbox"
	return is_sandbox

func _toggle_pause() -> void:
	var next_pause_state = not get_tree().paused
	get_tree().paused = next_pause_state
	pause_menu.visible = next_pause_state
	if next_pause_state and exit_btn:
		if _can_instant_extract():
			exit_btn.text = "은신처로 안전 복귀 (전리품 보존)"
			exit_btn.theme_type_variation = &"PrimaryButton"
		else:
			exit_btn.text = "작전 포기 및 탈주 (MIA - 전리품 유실)"
			exit_btn.theme_type_variation = &"DangerButton"
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
			GameManager.end_raid("mia", get_backpack_items())
