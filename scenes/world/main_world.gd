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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # 일시정지 중에도 메인 월드 스크립트 실행 유지
	
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
	player.position = Vector2.ZERO
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

func _spawn_extraction_zones() -> void:
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

func _unhandled_input(event: InputEvent) -> void:
	if current_loot_window != null:
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

func _process(delta: float) -> void:
	if player:
		chunk_manager.update_chunks(player.global_position)
		
		# 레이드 제한 시간 감소
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
		print("문을 엽니다/닫습니다!")
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
		GameManager.end_raid("survived")
