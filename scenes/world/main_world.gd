# res://scenes/world/main_world.gd
extends Node2D

@onready var chunk_manager: Node = $ChunkManager
@onready var entities_layer: Node2D = $Entities
@onready var pause_menu: Control = $UI/PauseMenu
@onready var resume_btn: Button = $UI/PauseMenu/CenterPanel/VBoxContainer/ResumeBtn
@onready var exit_btn: Button = $UI/PauseMenu/CenterPanel/VBoxContainer/ExitBtn
@onready var debug_label: Label = $UI/HUD/DebugLabel
@onready var interact_prompt: Label = $UI/HUD/InteractPrompt
@onready var hp_bar: ProgressBar = $UI/HUD/VitalsPanel/VBox/HPBar
@onready var stamina_bar: ProgressBar = $UI/HUD/VitalsPanel/VBox/StaminaBar
@onready var hunger_bar: ProgressBar = $UI/HUD/VitalsPanel/VBox/HBox/HungerBar
@onready var thirst_bar: ProgressBar = $UI/HUD/VitalsPanel/VBox/HBox/ThirstBar
@onready var status_label: Label = $UI/HUD/Panel/VBox/StatusLabel
@onready var raid_timer_label: Label = $UI/HUD/RaidTimerPanel/RaidTimerLabel
@onready var extract_bar: ProgressBar = $UI/HUD/ExtractProgressBar
@onready var day_night_modulate: CanvasModulate = $DayNightModulate
@onready var compass_bar: Control = $UI/HUD/CompassBar
@onready var event_log_vbox: VBoxContainer = $UI/HUD/EventLog

# 상태이상 배지
@onready var status_badges_container: VBoxContainer = get_node_or_null("UI/HUD/Panel/VBox/StatusBadgesContainer")
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
var enemy_spawn_timer: float = 18.0
var max_enemies_count: int = 10
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
const BOSS_WARNING_RADIUS: float = 680.0
const BOSS_DANGER_RADIUS: float = 360.0
var boss_hud_widgets: Dictionary = {}
var _boss_perimeter_warned: bool = false
var landmark_objective: Node2D = null
var field_objectives: Array = []

var storm_lightning_timer: float = 18.0
var storm_lightning_active: bool = false
var storm_lightning_duration: float = 0.0
var storm_thunder_delay: float = -1.0
var last_fulton_balloon: Node2D = null

func spawn_fulton_balloon_effect(start_pos: Vector2, item_name: String = "") -> Node2D:
	var balloon := Node2D.new()
	balloon.name = "FultonRecoveryBalloon"
	balloon.global_position = start_pos
	balloon.z_index = 65
	balloon.set_meta("start_y", start_pos.y)
	balloon.set_meta("target_y", start_pos.y - 400.0)
	balloon.set_meta("duration", 1.2)
	balloon.set_meta("item_name", item_name)
	balloon.draw.connect(func():
		# 회수 화물 상자 및 로프
		balloon.draw_line(Vector2(-5, -6), Vector2(-9, -24), Color(0.85, 0.85, 0.8, 0.9), 1.4)
		balloon.draw_line(Vector2(5, -6), Vector2(9, -24), Color(0.85, 0.85, 0.8, 0.9), 1.4)
		balloon.draw_rect(Rect2(Vector2(-7, -6), Vector2(14, 12)), Color(0.24, 0.34, 0.22, 0.95))
		balloon.draw_rect(Rect2(Vector2(-7, -6), Vector2(14, 12)), Color(0.75, 0.85, 0.45, 0.95), false, 1.4)
		# 고고도 풀턴 회수 기구(풍선)
		balloon.draw_circle(Vector2(0, -32), 12.0, Color(1.0, 0.50, 0.12, 0.95))
		balloon.draw_circle(Vector2(-4, -35), 4.0, Color(1.0, 0.82, 0.45, 0.75))
	)
	if entities_layer:
		entities_layer.add_child(balloon)
	else:
		add_child(balloon)
	last_fulton_balloon = balloon
	if balloon.is_inside_tree():
		var tw := balloon.create_tween()
		tw.set_parallel(true)
		tw.tween_property(balloon, "global_position:y", start_pos.y - 400.0, 1.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		tw.tween_property(balloon, "scale", Vector2(0.45, 0.45), 1.2)
		tw.tween_property(balloon, "modulate:a", 0.0, 1.2)
		tw.chain().tween_callback(balloon.queue_free)
	return balloon

const ExtractionZoneScene = preload("res://scenes/world/extraction_zone.tscn")
var raid_time_remaining: float = 1800.0 # 30분
var raid_total_time: float = 1800.0
var day_night_cycle_duration: float = 300.0 # 낮/밤 1주기 시간(초)
var raid_power_restored: bool = false
var power_lights_container: Node2D = null
static var _shared_point_light_tex: GradientTexture2D = null

static func _get_shared_point_light_tex() -> GradientTexture2D:
	if _shared_point_light_tex == null:
		var grad := GradientTexture2D.new()
		grad.width = 128
		grad.height = 128
		grad.fill = GradientTexture2D.FILL_RADIAL
		grad.fill_from = Vector2(0.5, 0.5)
		grad.fill_to = Vector2(0.5, 0.0)
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.65, 0.65, 0.65, 0.55), Color(0, 0, 0, 0)])
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		grad.gradient = g
		_shared_point_light_tex = grad
	return _shared_point_light_tex

func spawn_transient_point_light(world_pos: Vector2, col: Color = Color(1.0, 0.78, 0.28), energy_val: float = 1.9, scale_val: float = 1.8, duration: float = 0.06, height_val: float = 48.0) -> PointLight2D:
	var pl := PointLight2D.new()
	pl.global_position = world_pos
	pl.texture = _get_shared_point_light_tex()
	pl.texture_scale = scale_val
	pl.color = col
	pl.energy = energy_val
	pl.height = height_val
	if entities_layer:
		entities_layer.add_child(pl)
	else:
		add_child(pl)
	if pl.is_inside_tree():
		var tw := pl.create_tween()
		tw.tween_property(pl, "energy", 0.0, maxf(0.02, duration)).set_ease(Tween.EASE_OUT)
		tw.tween_callback(pl.queue_free)
	return pl

func _spawn_power_restored_lights(switch_tile: Vector2i) -> int:
	if power_lights_container == null or not is_instance_valid(power_lights_container):
		power_lights_container = Node2D.new()
		power_lights_container.name = "PowerRestoredLights"
		add_child(power_lights_container)
	var light_positions: Array[Vector2] = [Vector2(switch_tile) * 32.0 + Vector2(16.0, 16.0)]
	if chunk_manager and chunk_manager.object_layer:
		var obj_layer: TileMapLayer = chunk_manager.object_layer
		for dy in range(-14, 15):
			for dx in range(-14, 15):
				var check_t := switch_tile + Vector2i(dx, dy)
				if obj_layer.get_cell_source_id(check_t) != -1:
					var c_coords := obj_layer.get_cell_atlas_coords(check_t)
					if c_coords == TileManager.OBJ_LIGHT_SWITCH or TileManager.is_door_open(c_coords) or TileManager.is_desk(c_coords):
						var w_pt := Vector2(check_t) * 32.0 + Vector2(16.0, 16.0)
						var too_close := false
						for existing_pt in light_positions:
							if existing_pt.distance_to(w_pt) < 120.0:
								too_close = true
								break
						if not too_close and light_positions.size() < 8:
							light_positions.append(w_pt)
	var tex := _get_shared_point_light_tex()
	for pt in light_positions:
		var pl := PointLight2D.new()
		pl.position = pt
		pl.texture = tex
		pl.texture_scale = 3.2
		pl.color = Color(1.0, 0.80, 0.44)
		pl.energy = 1.55
		pl.height = 64.0
		power_lights_container.add_child(pl)
	return light_positions.size()

func activate_power_switch(tile_pos: Vector2i, world_pos: Vector2 = Vector2.ZERO) -> Dictionary:
	if raid_power_restored:
		return {
			"power_restored": true,
			"unlocked_doors": 0,
			"bunker_unlocked": true
		}
	raid_power_restored = true
	if GameManager:
		GameManager.raid_power_restored = true
		if GameManager.current_world_data is Dictionary:
			GameManager.current_world_data["raid_power_restored"] = true
	var unlocked_door_coords := {}
	if chunk_manager and chunk_manager.object_layer:
		var obj_layer: TileMapLayer = chunk_manager.object_layer
		for dy in range(-14, 15):
			for dx in range(-14, 15):
				var check_t := tile_pos + Vector2i(dx, dy)
				if obj_layer.get_cell_source_id(check_t) != -1:
					var cur_coords := obj_layer.get_cell_atlas_coords(check_t)
					if TileManager.is_door_locked(cur_coords):
						obj_layer.set_cell(check_t, 0, TileManager.get_unlocked_door_tile(cur_coords))
						unlocked_door_coords[check_t] = true
						EventBus.door_toggled.emit(check_t, true)
	if chunk_manager and chunk_manager.loaded_chunks is Dictionary:
		for cpos in chunk_manager.loaded_chunks.keys():
			var c_data = chunk_manager.loaded_chunks[cpos]
			if c_data is Dictionary and c_data.get("objects") is Array:
				var objs: Array = c_data["objects"]
				for idx in range(objs.size()):
					if TileManager.is_door_locked(objs[idx]):
						var lx := idx % 16
						var ly := floori(float(idx) / 16.0)
						var wx := int(cpos.x) * 16 + lx
						var wy := int(cpos.y) * 16 + ly
						if abs(wx - tile_pos.x) <= 14 and abs(wy - tile_pos.y) <= 14:
							objs[idx] = TileManager.get_unlocked_door_tile(objs[idx])
							unlocked_door_coords[Vector2i(wx, wy)] = true
	var unlocked_doors := unlocked_door_coords.size()
	var lit_count := _spawn_power_restored_lights(tile_pos)
	if SoundManager:
		SoundManager.play("menu_select")
	if world_pos != Vector2.ZERO:
		EventBus.noise_created.emit(world_pos, 180.0, "generator")
	EventBus.event_logged.emit("[icon:power] [주 발전기 가동] 건물 실내 조명(%d개소) 및 전력이 복구되었습니다! 전자식 보안 잠금문 및 지하 벙커 탈출구가 개방됩니다!" % lit_count)
	return {
		"power_restored": true,
		"unlocked_doors": unlocked_doors,
		"lights_spawned": lit_count,
		"bunker_unlocked": true
	}

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
		player.painkiller_timer = float(s.get("painkiller_timer", 0.0))
		player.painkiller_damage_reduction = float(s.get("painkiller_damage_reduction", 0.0))
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
	if pause_menu:
		var pause_center := pause_menu.get_node_or_null("CenterPanel") as Control
		var pause_vbox := pause_menu.get_node_or_null("CenterPanel/VBoxContainer") as VBoxContainer
		if pause_center:
			pause_center.offset_top = -170.0
			pause_center.offset_bottom = 170.0
		if pause_vbox and not pause_vbox.has_node("SettingsBtn"):
			var p_sett_btn := Button.new()
			p_sett_btn.name = "SettingsBtn"
			p_sett_btn.custom_minimum_size = Vector2(0, 44)
			p_sett_btn.add_theme_font_size_override("font_size", 16)
			if UiIconManager:
				UiIconManager.set_button(p_sett_btn, "settings", "설정 (Settings)", 16)
			else:
				p_sett_btn.text = "설정 (Settings)"
			p_sett_btn.pressed.connect(_open_settings_window)
			pause_vbox.add_child(p_sett_btn)
			if exit_btn and exit_btn.get_parent() == pause_vbox:
				pause_vbox.move_child(p_sett_btn, exit_btn.get_index())
	pause_menu.visible = false

	# 청크 매니저 시그널 연결
	chunk_manager.chunk_loaded.connect(_on_chunk_loaded)
	chunk_manager.chunk_unloaded.connect(_on_chunk_unloaded)
	
	# 초기 청크 로드
	chunk_manager.update_chunks(player.global_position)
	HudTacticalHelper.style_hud_bars(hp_bar, stamina_bar, hunger_bar, thirst_bar)
	HudTacticalHelper.style_vitals_and_status_containers(get_node_or_null("UI/HUD/Panel"), get_node_or_null("UI/HUD/VitalsPanel"))
	boss_hud_widgets = HudTacticalHelper.ensure_boss_hud_widgets(get_node_or_null("UI/HUD"))
	_on_player_stats_changed()
	
	# 시작 시 주변에 초기 좀비 스폰 (설정된 밀도 반영)
	var init_zombies = int(1 * (GameManager.current_world_data.get("world_settings", {}).get("zombie_multiplier", 1.0) if GameManager else 1.0))
	for i in range(init_zombies):
		_spawn_enemy_near_player(450.0 + i * 90.0)
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
	hit_arc_overlay.z_index = 150
	hit_arc_overlay.draw.connect(_on_hit_arc_draw)
	$UI/HUD.add_child(hit_arc_overlay)
	
	if EventBus.has_signal("player_hit_direction"):
		EventBus.player_hit_direction.connect(_on_player_hit_direction)
	if EventBus.has_signal("player_died") and not EventBus.player_died.is_connected(_on_player_died_ui):
		EventBus.player_died.connect(_on_player_died_ui)
	
	var is_sandbox: bool = GameManager and GameManager.is_sandbox_mode()
	if EventBus.has_signal("event_logged"):
		if is_sandbox:
			EventBus.event_logged.emit("[icon:sandbox] 샌드박스 모드: [F1] 키를 눌러 모든 무기/부품을 소환할 수 있습니다.")
		else:
			EventBus.event_logged.emit("[icon:star] 레이드 시작: 탈출 지점을 찾아 안전하게 탈출하십시오.")
	
	GameManager.current_state = GameManager.GameState.IN_GAME
	
	# 작전 개시 및 초기 상태 안내 로그 출력
	if raid_total_time >= 90000.0 * 60.0 or (GameManager and GameManager.raid_duration_minutes >= 90000.0):
		_on_event_logged("[icon:star] [작전 개시] 무제한 시간 샌드박스 레이드가 시작되었습니다.")
	else:
		var raid_mins = int(round(raid_total_time / 60.0))
		_on_event_logged("[icon:star] [작전 개시] %d분 생존 레이드가 시작되었습니다." % raid_mins)
	if WeatherSystem:
		_on_event_logged("[icon:weather] 현재 날씨: [%s]" % WeatherSystem.get_weather_name(WeatherSystem.current_weather))
		
	# 화면 우상단 샌드박스/치트 도구 버튼은 샌드박스 모드에서만 노출
	if is_sandbox:
		var tool_btn = Button.new()
		tool_btn.name = "SandboxToolBtn"
		if UiIconManager:
			UiIconManager.set_button(tool_btn, "sandbox", "샌드박스 도구 (F1)", 15)
		else:
			tool_btn.text = "샌드박스 도구 (F1)"
		tool_btn.focus_mode = Control.FOCUS_NONE
		tool_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		tool_btn.offset_left = -170.0
		tool_btn.offset_top = 10.0
		tool_btn.offset_right = -10.0
		tool_btn.offset_bottom = 44.0
		tool_btn.pressed.connect(_open_item_spawner)
		$UI.add_child(tool_btn)
	HudTacticalHelper.style_status_badges([badge_bleed, badge_fracture, badge_biohazard])
	
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
	var tool_btn = $UI.get_node_or_null("SandboxToolBtn") as Button
	if tool_btn:
		if bp == ResponsiveManager.Breakpoint.COMPACT:
			if UiIconManager:
				UiIconManager.set_button(tool_btn, "sandbox", "(F1)", 14)
			else:
				tool_btn.text = "(F1)"
			tool_btn.offset_left = -84.0
		else:
			if UiIconManager:
				UiIconManager.set_button(tool_btn, "sandbox", "샌드박스 도구 (F1)", 15)
			else:
				tool_btn.text = "샌드박스 도구 (F1)"
			tool_btn.offset_left = -170.0

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
	HudTacticalHelper.spawn_event_toast(self, event_log_vbox, msg)

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
	# 무작위 적 타입 결정 (전체적인 난이도 및 인간형 용병 조우 빈도 대폭 완화)
	var r = randf()
	if is_night_time() and r < 0.14:
		enemy.enemy_type = 6 # NIGHT_STALKER (야간 추격자)
	elif r < 0.025: enemy.enemy_type = 4 # RAIDER (정예 무장 용병 2.5%)
	elif r < 0.09: enemy.enemy_type = 3 # SCAV (무장 약탈자 6.5%)
	elif r < 0.25: enemy.enemy_type = 1 # RUNNER
	elif r < 0.34: enemy.enemy_type = 2 # TANK
	else: enemy.enemy_type = 0 # ZOMBIE
	
	entities_layer.add_child(enemy)

const CraftingWindowScene = preload("res://scenes/ui/crafting_window.tscn")
const RadioWindowScene = preload("res://scenes/ui/radio_window.tscn")
const SettingsWindowScene = preload("res://scenes/ui/settings_window.tscn")
var current_crafting_window: Control = null
var current_radio_window: Control = null
var current_modding_window: Control = null
var current_settings_window: Control = null

func _has_open_modal_window() -> bool:
	return (
		is_instance_valid(current_inventory_window)
		or is_instance_valid(current_crafting_window)
		or is_instance_valid(current_map_window)
		or is_instance_valid(current_radio_window)
		or is_instance_valid(current_modding_window)
		or is_instance_valid(current_spawner_window)
		or is_instance_valid(current_settings_window)
	)

func _input(event: InputEvent) -> void:
	if _has_open_modal_window() or (pause_menu and pause_menu.visible):
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit or focus_owner is TextEdit:
		return
	var is_inv_key: bool = event.is_action_pressed("inventory") or (event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_TAB or event.keycode == KEY_TAB))
	if is_inv_key:
		_open_inventory_window()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if _has_open_modal_window():
		return
		
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			_toggle_pause()
			get_viewport().set_input_as_handled()
			return
			
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
		
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
			_on_event_logged("[icon:warn] 가방에 [장거리 무전기]가 없어 통신망을 열 수 없습니다.")
		get_viewport().set_input_as_handled()
		
	# 크리에이티브 아이템 스포너 열기 (F1 키 — 샌드박스 모드 전용)
	if event is InputEventKey and event.physical_keycode == KEY_F1 and event.pressed and not event.echo:
		if GameManager and GameManager.is_sandbox_mode():
			_open_item_spawner()
			get_viewport().set_input_as_handled()

func player_has_radio() -> bool:
	if not player or not player.inventory_grid:
		return false
	if player.inventory_grid.has_item("장거리 무전기", 1) or player.inventory_grid.has_item("군용 무전기", 1) or player.inventory_grid.has_item("무전기", 1):
		return true
	var match_res: Dictionary = player.inventory_grid.find_item_recursive_by_predicate(func(it: Dictionary) -> bool:
		return String(it.get("id", "")).contains("무전기")
	)
	return bool(match_res.get("found", false))

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
	inv.set_meta("custom_title", "[icon:drone] 암시장 긴급 탄약·의료 드론 보급함")
	container_inventories[tile_pos] = inv

	airdrop_points_data.append({
		"name": "긴급 드론 보급품",
		"pos": snapped_pos
	})
	return crate

func _on_radio_scan_requested(scan_type: String) -> void:
	if GameManager and GameManager.current_world_data is Dictionary:
		GameManager.current_world_data["raid_radio_scanned"] = true
	if not player:
		return
	if scan_type == "survivor":
		var enemies_cnt := get_tree().get_nodes_in_group("enemies").size() if get_tree() else 0
		_on_event_logged("[icon:radio] [주파수 스캔] 현재 반경 내 감지된 생체/적대 신호: %d개" % enemies_cnt)
	elif scan_type == "supply":
		if airdrop_points_data.is_empty():
			_spawn_airdrop_crate()
		else:
			var nearest = airdrop_points_data.back()
			var dist = player.global_position.distance_to(nearest["pos"])
			_on_event_logged("[icon:radio] [보급 추적] 최근 보급 투하 지점까지 거리: %.0fm" % dist)
	elif scan_type == "military":
		if is_instance_valid(boss_entity):
			var dist_b = player.global_position.distance_to(boss_entity.global_position)
			_on_event_logged("[icon:radio] [군사 암호 감청] 지휘관 보스 신호 포착 — 거리 %.0fm" % dist_b)
		else:
			_on_event_logged("[icon:radio] [군사 암호 감청] 보스 생체 신호 소멸 확인.")

func _open_item_spawner() -> void:
	if not (GameManager and GameManager.is_sandbox_mode()):
		return
	if current_spawner_window != null: return
	get_tree().paused = true
	current_spawner_window = ItemSpawnerScene.instantiate()
	$UI.add_child(current_spawner_window)
	current_spawner_window.window_closed.connect(func():
		current_spawner_window = null
		_on_player_stats_changed()
	)

func _open_settings_window() -> void:
	if is_instance_valid(current_settings_window):
		return
	if SoundManager: SoundManager.play("menu_select")
	current_settings_window = SettingsWindowScene.instantiate()
	$UI.add_child(current_settings_window)
	current_settings_window.window_closed.connect(func():
		current_settings_window = null
	)

func _open_weapon_modding_window() -> void:
	if current_modding_window != null: return
	var modding_script = load("res://scenes/ui/weapon_modding_window.gd")
	if modding_script:
		get_tree().paused = true
		var win = modding_script.new()
		current_modding_window = win
		$UI.add_child(win)
		var cur_w = player.equipped_weapon_data if player else {}
		var inv_target = player.inventory_grid if player else null
		var slot_key: String = player.active_weapon_slot if (player and "active_weapon_slot" in player) else ""
		win.setup(inv_target, null, cur_w, slot_key)
		win.window_closed.connect(func():
			current_modding_window = null
			_on_player_stats_changed()
		)

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
	if is_instance_valid(current_map_window):
		return
	current_map_window = MapWindowScene.instantiate()
	$UI.add_child(current_map_window)
	
	var biome = "주거지"
	if chunk_manager and chunk_manager.generator:
		var cx = int(floor(player.global_position.x / 32.0))
		var cy = int(floor(player.global_position.y / 32.0))
		biome = chunk_manager.generator.get_biome(cx, cy)
		
	var chunks_dict = chunk_manager.loaded_chunks if chunk_manager else {}
	current_map_window.setup(player.global_position, player.rotation, extraction_points_data, biome, boss_entity, airdrop_points_data, field_objectives, chunks_dict, player, chunk_manager)
	if is_instance_valid(player):
		player.ui_input_blocked = _has_open_modal_window()
	current_map_window.window_closed.connect(func():
		current_map_window = null
		if is_instance_valid(player):
			player.ui_input_blocked = _has_open_modal_window()
	)

func _on_compass_draw() -> void:
	if not player: return
	var w = compass_bar.size.x
	var h = compass_bar.size.y
	var center_x = floorf(w / 2.0)
	
	# 다크 택티컬 픽셀 프레임 배경 + 4모서리 코너 브래킷
	compass_bar.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(0.04, 0.05, 0.075, 0.88), true)
	compass_bar.draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(0.24, 0.30, 0.38, 0.92), false, 1.0)
	InventoryUIHelper._draw_pixel_corner_brackets(compass_bar, Rect2(1, 1, w - 2, h - 2), Color(0.92, 0.65, 0.22, 0.85), 5.0, 1.0)
	
	# 플레이어 시선 각도 (도)
	var player_deg = rad_to_deg(player.rotation)
	if player_deg < 0: player_deg += 360.0
	
	# 시야각 FOV (160도)
	var fov = 160.0
	var pixels_per_deg = w / fov
	
	# 15도 단위 픽셀 눈금 틱
	for step_deg in range(0, 360, 15):
		if step_deg % 90 == 0:
			continue
		var s_diff = float(step_deg) - player_deg
		while s_diff < -180.0: s_diff += 360.0
		while s_diff > 180.0: s_diff -= 360.0
		if abs(s_diff) <= fov / 2.0:
			var sx := floorf(center_x + s_diff * pixels_per_deg)
			var tick_h := 4.0 if (step_deg % 45 == 0) else 2.0
			compass_bar.draw_rect(Rect2(sx, h - 1.0 - tick_h, 1.0, tick_h), Color(0.42, 0.48, 0.58, 0.75), true)
	
	# N, E, S, W 방위각 눈금
	var compass_font: Font = PixelAssetManager.get_pixel_font_regular() if PixelAssetManager else ThemeDB.fallback_font
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
			var x = floorf(center_x + diff * pixels_per_deg)
			compass_bar.draw_rect(Rect2(x - 1.0, h - 7.0, 2.0, 6.0), Color(0.92, 0.68, 0.22, 0.95), true)
			compass_bar.draw_string(compass_font, Vector2(x - 4, h - 9), cardinal_dirs[deg], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.9, 0.3))
			
	# 탈출구 마커 (초록색 다이아몬드)
	for pt in extraction_points_data:
		var dir_to_pt = player.global_position.direction_to(pt["pos"])
		var pt_deg = rad_to_deg(dir_to_pt.angle())
		if pt_deg < 0: pt_deg += 360.0
		
		var diff = pt_deg - player_deg
		while diff < -180.0: diff += 360.0
		while diff > 180.0: diff -= 360.0
		
		if abs(diff) <= fov / 2.0:
			var x = floorf(center_x + diff * pixels_per_deg)
			var dist = player.global_position.distance_to(pt["pos"])
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
				var bunker_unlocked = raid_power_restored
				if GameManager:
					if GameManager.raid_landmark_completed or GameManager.raid_power_restored:
						bunker_unlocked = true
					elif bool(GameManager.current_world_data.get("raid_power_restored", false)):
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
			compass_bar.draw_string(compass_font, Vector2(x - 12, 22), "%.0fm%s" % [dist, lock_suffix], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, txt_col)

	# 항공 보급품 마커 (SVG 아이콘 + 거리)
	for ad in airdrop_points_data:
		var dir_to_ad = player.global_position.direction_to(ad["pos"])
		var ad_deg = rad_to_deg(dir_to_ad.angle())
		if ad_deg < 0: ad_deg += 360.0
		var diff = ad_deg - player_deg
		while diff < -180.0: diff += 360.0
		while diff > 180.0: diff -= 360.0
		if abs(diff) <= fov / 2.0:
			var x = floorf(center_x + diff * pixels_per_deg)
			var dist = player.global_position.distance_to(ad["pos"])
			var ad_tex: Texture2D = UiIconManager.get_icon("airdrop") if UiIconManager else null
			if ad_tex:
				compass_bar.draw_texture_rect(ad_tex, Rect2(x - 5.0, 3.0, 10.0, 10.0), false)
			else:
				compass_bar.draw_rect(Rect2(x - 4.0, 5.0, 8.0, 8.0), Color(1.0, 0.45, 0.15), true)
			compass_bar.draw_string(compass_font, Vector2(x - 12, 22), "%.0fm" % dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.65, 0.25))
			
	# 랜드마크 보스 마커 (SVG 해골 + 거리)
	if is_instance_valid(boss_entity) and boss_entity.get("hp") != null and boss_entity.hp > 0:
		var dir_to_boss = player.global_position.direction_to(boss_entity.global_position)
		var boss_deg = rad_to_deg(dir_to_boss.angle())
		if boss_deg < 0: boss_deg += 360.0
		var b_diff = boss_deg - player_deg
		while b_diff < -180.0: b_diff += 360.0
		while b_diff > 180.0: b_diff -= 360.0
		if abs(b_diff) <= fov / 2.0:
			var bx = floorf(center_x + b_diff * pixels_per_deg)
			var b_dist = player.global_position.distance_to(boss_entity.global_position)
			var boss_tex: Texture2D = UiIconManager.get_icon("skull") if UiIconManager else null
			if boss_tex:
				compass_bar.draw_texture_rect(boss_tex, Rect2(bx - 5.0, 3.0, 10.0, 10.0), false)
			else:
				compass_bar.draw_rect(Rect2(bx - 4.0, 5.0, 8.0, 8.0), Color(0.95, 0.15, 0.2), true)
			compass_bar.draw_string(compass_font, Vector2(bx - 12, 22), "%.0fm" % b_dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.35, 0.35))
			
	# 랜드마크 현장 단말기 마커 (다중 현장 임무 3종 SVG 아이콘 + 거리)
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
				var ox = floorf(center_x + o_diff * pixels_per_deg)
				var o_dist = player.global_position.distance_to(obj_ref.global_position)
				var icon_key: String = obj_ref.get_compass_icon() if obj_ref.has_method("get_compass_icon") else "signal"
				var obj_tex: Texture2D = UiIconManager.get_icon(icon_key) if UiIconManager else null
				if obj_tex:
					compass_bar.draw_texture_rect(obj_tex, Rect2(ox - 5.0, 3.0, 10.0, 10.0), false)
				else:
					compass_bar.draw_rect(Rect2(ox - 3.0, 6.0, 6.0, 6.0), Color(0.2, 0.88, 1.0), true)
				compass_bar.draw_string(compass_font, Vector2(ox - 12, 22), "%.0fm" % o_dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.4, 0.92, 1.0))

	# 정중앙 조준 눈금 (픽셀 스텝 역삼각형 포인터)
	compass_bar.draw_rect(Rect2(center_x - 3.0, 1.0, 6.0, 2.0), Color(1.0, 0.85, 0.2), true)
	compass_bar.draw_rect(Rect2(center_x - 2.0, 3.0, 4.0, 2.0), Color(1.0, 0.85, 0.2), true)
	compass_bar.draw_rect(Rect2(center_x - 1.0, 5.0, 2.0, 2.0), Color(1.0, 0.85, 0.2), true)

func _spawn_landmark_boss() -> void:
	if not player: return
	var angle = randf() * TAU
	var dist = randf_range(680.0, 920.0)
	var boss_pos = player.global_position + Vector2.RIGHT.rotated(angle) * dist
	var boss = EnemyScene.instantiate()
	boss.position = boss_pos
	boss.enemy_type = 5 # EnemyType.BOSS
	entities_layer.add_child(boss)
	boss_entity = boss
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
	var wave_enemy = EnemyScene.instantiate()
	var spawn_ang = randf() * TAU
	wave_enemy.position = obj_pos + Vector2.RIGHT.rotated(spawn_ang) * randf_range(220.0, 300.0)
	if obj_kind == 0:
		wave_enemy.enemy_type = 3 # 군사기지: 스캐브 1기
	elif obj_kind == 1:
		wave_enemy.enemy_type = 1 # 병원구역: 러너 1기
	else:
		wave_enemy.enemy_type = 0 # 상업지구: 좀비 1기
	entities_layer.add_child(wave_enemy)

func _on_crosshair_draw() -> void:
	if not crosshair_overlay or not player or get_tree().paused or _has_open_modal_window():
		return
	var m_pos = crosshair_overlay.get_local_mouse_position()
	var is_ads = player.player_camera.is_aiming_ads if player.player_camera else false
	var w_handler = player.weapon_handler if player and "weapon_handler" in player else null
	var is_jammed = bool(w_handler.get("is_jammed")) if w_handler else false
	HudTacticalHelper.draw_pixel_crosshair(crosshair_overlay, m_pos, crosshair_spread, is_ads, is_jammed)

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
	HudTacticalHelper.draw_hit_arcs(hit_arc_overlay, hit_arcs)

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
		EventBus.event_logged.emit("[icon:airdrop] [긴급 공수] 군용 항공 보급품이 투하되었습니다! (나침반 [icon:airdrop] 마커 확인)")

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
		player.ui_input_blocked = _has_open_modal_window()
		chunk_manager.update_chunks(player.global_position)
		if compass_bar:
			compass_bar.queue_redraw()
		var boss_hud_state := HudTacticalHelper.update_boss_hud(boss_hud_widgets, boss_entity, player.global_position, BOSS_WARNING_RADIUS, BOSS_DANGER_RADIUS)
		var b_dist := float(boss_hud_state.get("dist", 99999.0))
		if bool(boss_hud_state.get("in_warning", false)):
			if not _boss_perimeter_warned:
				_boss_perimeter_warned = true
				if EventBus.has_signal("event_logged"):
					EventBus.event_logged.emit("[icon:warn] [보스 경보] 전방 %.0fm 지점에 랜드마크 보스 감지! 공격 사거리 밖으로 우회하세요." % b_dist)
		elif b_dist > BOSS_WARNING_RADIUS + 120.0:
			_boss_perimeter_warned = false
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

		# 게임이 일시정지된 상태가 아닐 때만 시간 감소 및 갱신 (99999분 이상 설정 시 무제한 표시)
		var is_unlimited_time: bool = raid_total_time >= 90000.0 * 60.0 or (GameManager and GameManager.raid_duration_minutes >= 90000.0)
		if is_unlimited_time:
			if raid_timer_label:
				raid_timer_label.text = "탈출 시간: 무제한"
		elif not get_tree().paused and raid_time_remaining > 0:
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
					if player:
						spawn_transient_point_light(player.global_position + Vector2(randf_range(-90.0, 90.0), -60.0), Color(0.75, 0.88, 1.0), 2.4, 7.5, 0.35, 160.0)
				
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
							EventBus.event_logged.emit("[icon:power] 콰르릉! 폭풍우 뇌우가 근처에 내리쳤습니다!")
			else:
				storm_lightning_active = false
				_update_day_night_cycle()
				
			_update_weather_particles(delta)
			if airdrop_count < max_airdrops:
				airdrop_timer -= delta
				if airdrop_timer <= 0.0:
					airdrop_timer = randf_range(95.0, 140.0)
					_spawn_airdrop_crate()
		
		# 적 주기적 스폰 (스폰 간격 완화 및 스폰 거리 확대)
		enemy_spawn_timer -= delta
		if enemy_spawn_timer <= 0:
			enemy_spawn_timer = randf_range(16.0, 26.0)
			var current_enemies = get_tree().get_nodes_in_group("enemies").size()
			if current_enemies < max_enemies_count:
				_spawn_enemy_near_player(randf_range(440.0, 680.0))
		
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
	HudTacticalHelper.update_player_hud(
		player,
		hp_bar,
		stamina_bar,
		hunger_bar,
		thirst_bar,
		status_label,
		badge_bleed,
		badge_fracture,
		badge_biohazard,
		weapon_panel,
		weapon_icon,
		weapon_name_label,
		ammo_label,
		weapon_durability_bar,
		player_has_radio()
	)

func _setup_quickslot_bar() -> void:
	if not quickslot_hbox or not player: return
	
	var slot1 = quickslot_hbox.get_node_or_null("Slot1")
	var slot2 = quickslot_hbox.get_node_or_null("Slot2")
	var slot3 = quickslot_hbox.get_node_or_null("Slot3")
	var slot4 = quickslot_hbox.get_node_or_null("Slot4")
	var slot5 = quickslot_hbox.get_node_or_null("Slot5")
	var slot6 = quickslot_hbox.get_node_or_null("Slot6")
	var slot7 = quickslot_hbox.get_node_or_null("Slot7")
	var slot8 = quickslot_hbox.get_node_or_null("Slot8")
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
	if slot8 and not slot8.pressed.is_connected(_on_quickslot_8_pressed):
		slot8.pressed.connect(_on_quickslot_8_pressed)
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
		player._use_quickslot_item("food")

func _on_quickslot_8_pressed() -> void:
	if player and player.has_method("_use_quickslot_item"):
		player._use_quickslot_item("water")

func _on_quickslot_N_pressed() -> void:
	if player and player.player_lighting and player.player_lighting.has_method("toggle_nvg"):
		player.player_lighting.toggle_nvg()
		if SoundManager: SoundManager.play("menu_select")
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:nvg] 야간투시경(NVG): %s" % ("ON" if player.player_lighting.nvg_enabled else "OFF"))
		_update_quickslot_bar()

func _on_quickslot_U_pressed() -> void:
	if player_has_radio():
		open_radio_window()
	else:
		_on_event_logged("[icon:warn] 가방에 [장거리 무전기]가 없어 통신망을 열 수 없습니다.")

func _update_quickslot_bar() -> void:
	if not quickslot_hbox or not player: return
	HudTacticalHelper.update_quickslot_bar(quickslot_hbox, player)
	var slot8 = quickslot_hbox.get_node_or_null("Slot8")
	if slot8 and slot8 is Button and not slot8.pressed.is_connected(_on_quickslot_8_pressed):
		slot8.pressed.connect(_on_quickslot_8_pressed)
	var slotU = quickslot_hbox.get_node_or_null("SlotU")
	if slotU and slotU is Button and not slotU.pressed.is_connected(_on_quickslot_U_pressed):
		slotU.pressed.connect(_on_quickslot_U_pressed)

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
		elif item_str.contains("생수") or item_str.contains("물") or item_str.contains("음료") or item_str.contains("커피") or item_str.contains("드링크"): slot_key = "8"
		elif item_str.contains("식량") or item_str.contains("통조림") or item_str.contains("고기") or item_str.contains("빵") or item_str.contains("에너지바") or item_str.contains("농작물"): slot_key = "7"
		HudTacticalHelper.update_channeling_sweep(quickslot_hbox, slot_key, ratio)

func _on_player_channel_finished() -> void:
	if channeling_bar:
		channeling_bar.visible = false
	if quickslot_hbox:
		HudTacticalHelper.update_channeling_sweep(quickslot_hbox, "clear", 0.0)
	_update_quickslot_bar()
		
func _on_interact_prompt(can_interact: bool, text: String) -> void:
	if interact_prompt and current_inventory_window == null:
		if UiIconManager:
			var parsed := UiIconManager.parse_tagged_message(text)
			UiIconManager.set_label_icon(interact_prompt, String(parsed["icon_key"]), String(parsed["clean_text"]), 18, 6, true)
			UiIconManager.sync_label_row_visibility(interact_prompt, can_interact)
		else:
			interact_prompt.visible = can_interact
			interact_prompt.text = text
	elif interact_prompt:
		if UiIconManager:
			UiIconManager.sync_label_row_visibility(interact_prompt, false)
		else:
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
	elif TileManager.is_fridge(type): # OBJ_FRIDGE*
		table_name = "fridge"
		loot_title = "냉장고"
		slots = 6
	elif TileManager.is_bed(type): # OBJ_BED*
		table_name = "bed"
		loot_title = "침대 주변"
		slots = 6
	elif TileManager.is_desk(type): # OBJ_DESK*
		table_name = "desk"
		loot_title = "책상 서랍"
		slots = 8
	elif TileManager.is_shelf(type): # OBJ_SHELF*
		table_name = "shelf"
		loot_title = "수납 선반장"
		slots = 8
	elif type == Vector2i(7, 2): # Airdrop Crate
		table_name = "military"
		loot_title = "[icon:airdrop] 군용 항공 보급품"
		slots = 12
	elif type == Vector2i(9, 2): # Mercenary Corpse Box
		table_name = "military"
		loot_title = "[icon:backpack] 용병 유품 가방"
		slots = 8
	elif type == Vector2i(5, 2): # OBJ_LIGHT_SWITCH
		activate_power_switch(tile_pos, world_pos)
		return
	elif TileManager.is_door_locked(type): # OBJ_DOOR_LOCKED / _V
		var req_key = "무기고 열쇠"
		if chunk_manager and chunk_manager.generator:
			var b_info = chunk_manager.generator.get_building_at(tile_pos.x, tile_pos.y)
			if not b_info.is_empty():
				req_key = String(b_info.get("preset", {}).get("locked_key", "무기고 열쇠"))
		var has_valid_key = false
		var used_key_name = req_key
		var key_item_ref: Dictionary = {}
		if player and player.inventory_grid:
			var req_match: Dictionary = player.inventory_grid.find_item_recursive_by_predicate(func(it: Dictionary) -> bool:
				return InventoryGrid.is_same_item_id(String(it.get("id", "")), req_key)
			)
			if bool(req_match.get("found", false)):
				has_valid_key = true
				used_key_name = req_key
				key_item_ref = req_match.get("item", {})
			elif req_key == "무기고 열쇠":
				var card_match: Dictionary = player.inventory_grid.find_item_recursive_by_predicate(func(it: Dictionary) -> bool:
					return InventoryGrid.is_same_item_id(String(it.get("id", "")), "보안 키카드")
				)
				if bool(card_match.get("found", false)):
					has_valid_key = true
					used_key_name = "보안 키카드"
					key_item_ref = card_match.get("item", {})
		if not has_valid_key:
			if SoundManager: SoundManager.play("hit_melee")
			EventBus.event_logged.emit("[icon:lock] 잠겨 있습니다! [%s]가 가방 또는 안전 컨테이너에 필요합니다." % req_key)
			return
		var key_destroyed := false
		var rem_uses := 0
		var max_uses := 5 if used_key_name == "무기고 열쇠" else 3
		if not key_item_ref.is_empty() and player and player.inventory_grid:
			var k_data := ItemDatabase.get_item_data(used_key_name)
			max_uses = int(key_item_ref.get("max_durability", k_data.get("max_durability", max_uses)))
			var cur_uses := int(round(float(key_item_ref.get("durability", max_uses))))
			cur_uses -= 1
			rem_uses = max(0, cur_uses)
			key_item_ref["durability"] = float(rem_uses)
			key_item_ref["max_durability"] = float(max_uses)
			if rem_uses <= 0:
				var stack_amt := int(key_item_ref.get("amount", 1))
				key_destroyed = true
				if stack_amt > 1:
					key_item_ref["amount"] = stack_amt - 1
					key_item_ref["durability"] = float(max_uses)
					player.inventory_grid.grid_changed.emit()
				else:
					player.inventory_grid.remove_item_by_uid_recursive(String(key_item_ref.get("uid", "")))
			else:
				player.inventory_grid.grid_changed.emit()
		if chunk_manager and chunk_manager.object_layer:
			chunk_manager.object_layer.set_cell(tile_pos, 0, TileManager.get_unlocked_door_tile(type))
		EventBus.noise_created.emit(world_pos, 140.0, "door")
		EventBus.door_toggled.emit(tile_pos, true)
		if key_destroyed:
			EventBus.event_logged.emit("[icon:unlock] [%s]로 보안 잠금문을 개방했습니다! (열쇠 내구도 소진으로 파손됨)" % used_key_name)
		else:
			EventBus.event_logged.emit("[icon:unlock] [%s]로 보안 잠금문을 개방했습니다! (남은 사용 횟수: %d/%d)" % [used_key_name, rem_uses, max_uses])
		if SoundManager: SoundManager.play("item_pickup")
		return
	elif TileManager.is_door_closed(type): # OBJ_DOOR_CLOSED / _V
		# 닫힌 문 열기 -> 열린 문(방향 유지)으로 타일 교체 및 소음 발생
		if chunk_manager and chunk_manager.object_layer:
			chunk_manager.object_layer.set_cell(tile_pos, 0, TileManager.get_toggled_door_tile(type))
		EventBus.noise_created.emit(world_pos, 120.0, "door")
		EventBus.door_toggled.emit(tile_pos, true)
		EventBus.event_logged.emit("[icon:door] 문을 열었습니다.")
		if player and player.has_method("show_floating_text"):
			player.show_floating_text("문 열림", Color(0.45, 0.95, 0.65), 0.75)
		if SoundManager: SoundManager.play("door_open")
		return
	elif TileManager.is_door_open(type): # OBJ_DOOR_OPEN / _V
		# 열린 문 닫기 -> 닫힌 문(방향 유지)으로 교체
		if chunk_manager and chunk_manager.object_layer:
			chunk_manager.object_layer.set_cell(tile_pos, 0, TileManager.get_toggled_door_tile(type))
		EventBus.noise_created.emit(world_pos, 120.0, "door")
		EventBus.door_toggled.emit(tile_pos, false)
		EventBus.event_logged.emit("[icon:door] 문을 닫았습니다.")
		if player and player.has_method("show_floating_text"):
			player.show_floating_text("문 닫힘", Color(0.95, 0.78, 0.35), 0.75)
		if SoundManager: SoundManager.play("door_open")
		return
	elif TileManager.is_window(type): # OBJ_WINDOW / _V
		# 창문 깨기 -> 깨진 창문(방향 유지)으로 타일 교체 및 큰 소음 발생
		if chunk_manager and chunk_manager.object_layer:
			chunk_manager.object_layer.set_cell(tile_pos, 0, TileManager.get_window_broken_tile(type))
		EventBus.noise_created.emit(world_pos, 400.0, "break")
		EventBus.door_toggled.emit(tile_pos, true)
		EventBus.window_broken.emit(tile_pos)
		EventBus.event_logged.emit("[icon:explosion] 창문이 깨졌습니다! (큰 소음 발생)")
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
							loot_title = "[icon:hospital] 원장실 보안 보관함"
							slots = 12
						else:
							in_locked_vault_kind = "armory"
							table_name = "locked_armory"
							loot_title = "[icon:key] 특수 무기고 보관함"
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
				var w_dict = WeaponPartsDatabase.create_loot_weapon(rec_id, 0.14)
				inv.add_item(rec_id, 1, w_dict)
				inv.add_item(bonus_gear[randi() % bonus_gear.size()], 1)
				inv.add_item("수류탄", 2)
			elif in_locked_vault_kind == "armory" and type == Vector2i(3, 1):
				var vault_weapons = ["M4_리시버", "AK_리시버", "SV98_리시버"]
				var v_rec = vault_weapons[randi() % vault_weapons.size()]
				inv.add_item(v_rec, 1, WeaponPartsDatabase.create_loot_weapon(v_rec, 0.14))
			elif in_locked_vault_kind == "medical" and type == Vector2i(3, 1):
				inv.add_item("고급 치료킷", 1)
				inv.add_item("암호화된 SSD", 1)
			var loot_items = ItemDatabase.generate_loot(table_name)
			for item in loot_items:
				var it_id := String(item.get("id", ""))
				var w_custom: Dictionary = WeaponPartsDatabase.create_loot_weapon(it_id, 0.06) if WeaponPartsDatabase.is_modifiable_weapon({"id": it_id}) else {}
				inv.add_item(it_id, item["amount"], w_custom)
			container_inventories[tile_pos] = inv
			
		_open_loot_window(inv, loot_title)


func _open_inventory_window(target_inv: Inventory = null, title: String = "") -> void:
	if is_instance_valid(current_inventory_window): return
	if not is_inside_tree() or get_tree() == null: return
	current_inventory_window = InventoryWindowScene.instantiate()
	$UI.add_child(current_inventory_window)
	current_inventory_window.setup(player, player.inventory_grid, player.equipment, target_inv, title)
	if is_instance_valid(player):
		player.ui_input_blocked = _has_open_modal_window()
	current_inventory_window.window_closed.connect(func():
		current_inventory_window = null
		if is_instance_valid(player):
			player.ui_input_blocked = _has_open_modal_window()
		_on_player_stats_changed()
	)

func _on_player_died_ui() -> void:
	_close_non_pausing_modals()
	var hud: Control = get_node_or_null("UI/HUD") as Control
	if hud:
		HudTacticalHelper.show_death_overlay(hud)

func _close_non_pausing_modals() -> void:
	if is_instance_valid(current_inventory_window):
		if current_inventory_window.has_method("_on_close_pressed"):
			current_inventory_window._on_close_pressed()
		else:
			current_inventory_window.queue_free()
		current_inventory_window = null
	if is_instance_valid(current_map_window):
		current_map_window.queue_free()
		current_map_window = null
	if is_instance_valid(player):
		player.ui_input_blocked = _has_open_modal_window()

func _open_loot_window(target_inv: Inventory = null, title: String = "") -> void:
	_open_inventory_window(target_inv, title)

func _on_chunk_loaded(_chunk_pos: Vector2i, _data: Dictionary) -> void:
	pass

func _on_chunk_unloaded(_chunk_pos: Vector2i) -> void:
	pass

func _can_instant_extract() -> bool:
	# 샌드박스 모드에서만 ESC 메뉴를 통한 즉시 안전 탈출 허용 (일반 모드는 인게임 탈출구에서만 가능)
	return GameManager != null and GameManager.is_sandbox_mode()

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
