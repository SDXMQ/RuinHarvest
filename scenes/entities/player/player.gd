extends CharacterBody2D
class_name Player

signal stats_changed
signal interact_prompt(can_interact: bool, prompt_text: String)
signal object_interacted(world_pos: Vector2, tile_pos: Vector2i, type: Vector2i)

@export var walk_speed: float = 120.0
@export var sprint_speed: float = 210.0
@export var crouch_speed: float = 60.0
@export var acceleration: float = 1200.0
@export var friction: float = 900.0

var is_crouching: bool = false
var is_sprinting: bool = false

var inventory: Inventory
var inventory_grid: InventoryGrid

@onready var survival_stats = $SurvivalStats
@onready var weapon_handler = $WeaponHandler
@onready var interaction_detector = $InteractionDetector
@onready var player_lighting = $PlayerLighting
@onready var player_camera = $PlayerCamera
@onready var player_visuals = $Visuals

# 외부 호환성을 위한 프록시 프로퍼티들
var hp: float:
	get: return survival_stats.hp if survival_stats else 100.0
	set(v): if survival_stats: survival_stats.hp = v
var stamina: float:
	get: return survival_stats.stamina if survival_stats else 100.0
	set(v): if survival_stats: survival_stats.stamina = v
var hunger: float:
	get: return survival_stats.hunger if survival_stats else 100.0
	set(v): if survival_stats: survival_stats.hunger = v
var thirst: float:
	get: return survival_stats.thirst if survival_stats else 100.0
	set(v): if survival_stats: survival_stats.thirst = v
var is_god_mode: bool:
	get: return survival_stats.is_god_mode if survival_stats else false
	set(v): if survival_stats: survival_stats.is_god_mode = v

var is_bleeding: bool:
	get: return survival_stats.is_bleeding if survival_stats else false
	set(v): if survival_stats: survival_stats.is_bleeding = v
var is_infected: bool:
	get: return survival_stats.is_infected if survival_stats else false
	set(v): if survival_stats: survival_stats.is_infected = v
var is_fractured: bool:
	get: return survival_stats.is_fractured if survival_stats else false
	set(v): if survival_stats: survival_stats.is_fractured = v
var is_exhausted: bool:
	get: return survival_stats.is_exhausted if survival_stats else false
	set(v): if survival_stats: survival_stats.is_exhausted = v

var max_hp: float:
	get: return survival_stats.max_hp if survival_stats else 100.0
var max_stamina: float:
	get: return survival_stats.max_stamina if survival_stats else 100.0
var max_hunger: float:
	get: return survival_stats.max_hunger if survival_stats else 100.0
var max_thirst: float:
	get: return survival_stats.max_thirst if survival_stats else 100.0
var armor_defense: float:
	get: return survival_stats.armor_defense if survival_stats else 0.0
	set(v): if survival_stats: survival_stats.armor_defense = v

var equipment: Dictionary:
	get: return weapon_handler.equipment if weapon_handler else {}
	set(v): if weapon_handler: weapon_handler.equipment = v
var equipped_weapon: String:
	get: return weapon_handler.equipped_weapon if weapon_handler else "맨손"
	set(v): if weapon_handler: weapon_handler.equipped_weapon = v
var equipped_weapon_data: Dictionary:
	get: return weapon_handler.equipped_weapon_data if weapon_handler else {}
	set(v): if weapon_handler: weapon_handler.equipped_weapon_data = v
var active_weapon_slot: String:
	get: return weapon_handler.active_weapon_slot if weapon_handler else "primary1"
	set(v): if weapon_handler: weapon_handler.active_weapon_slot = v

var flashlight_enabled: bool:
	get: return player_lighting.flashlight_enabled if player_lighting else true
	set(v): if player_lighting: player_lighting.set_flashlight(v)

func _ready() -> void:
	add_to_group("player")
	if not has_node("InventoryGrid"):
		inventory_grid = InventoryGrid.new()
		inventory_grid.name = "InventoryGrid"
		inventory_grid.resize_grid(6, 5)
		add_child(inventory_grid)
	else:
		inventory_grid = get_node("InventoryGrid")

	if not has_node("Inventory"):
		inventory = Inventory.new()
		inventory.name = "Inventory"
		add_child(inventory)
	else:
		inventory = get_node("Inventory")

	# 컴포넌트 시그널 릴레이
	if survival_stats:
		survival_stats.stats_changed.connect(func(): stats_changed.emit())
	if interaction_detector:
		interaction_detector.interact_prompt.connect(func(can, text): interact_prompt.emit(can, text))
		interaction_detector.object_interacted.connect(func(pos, tile, type): object_interacted.emit(pos, tile, type))

	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.player_died.connect(_on_death)

func _process(delta: float) -> void:
	look_at(get_global_mouse_position())

func _physics_process(delta: float) -> void:
	if hp <= 0: return
	_handle_movement(delta)

func _unhandled_input(event: InputEvent) -> void:
	if hp <= 0: return
	
	if event.is_action_pressed("flashlight"):
		player_lighting.toggle_flashlight()
		if SoundManager: SoundManager.play("menu_select")
		
	if event.is_action_pressed("reload"):
		weapon_handler.start_reload()
		
	if event.is_action_pressed("attack"):
		weapon_handler.try_attack(Vector2.RIGHT.rotated(rotation), global_position)
		
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			weapon_handler.cycle_weapon(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			weapon_handler.cycle_weapon(1)
			
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_1: weapon_handler.switch_weapon_slot("primary1")
		elif event.keycode == KEY_2: weapon_handler.switch_weapon_slot("primary2")
		elif event.keycode == KEY_3: weapon_handler.switch_weapon_slot("sidearm")
		elif event.keycode == KEY_4: weapon_handler.switch_weapon_slot("throwable")

func _handle_movement(delta: float) -> void:
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_axis("move_left", "move_right")
	if input_vector.x == 0: input_vector.x = int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A))
	input_vector.y = Input.get_axis("move_up", "move_down")
	if input_vector.y == 0: input_vector.y = int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W))
	input_vector = input_vector.normalized()
	
	is_crouching = Input.is_action_pressed("crouch") or Input.is_physical_key_pressed(KEY_CTRL)
	is_sprinting = Input.is_action_pressed("sprint") or Input.is_physical_key_pressed(KEY_SHIFT)
	
	var target_speed = walk_speed
	var speed_mult = 1.0
	
	if is_fractured: speed_mult *= 0.6
	if equipment.has("backpack") and not equipment["backpack"].is_empty():
		speed_mult -= 0.1
		
	var w_data = weapon_handler.equipped_weapon_data if weapon_handler else {}
	if not w_data.is_empty() and w_data.has("computed_stats"):
		var w_weight = w_data["computed_stats"].get("weight", 3.0)
		speed_mult -= min(0.3, w_weight * 0.05)
		
	if is_crouching:
		target_speed = crouch_speed * speed_mult
		if survival_stats: survival_stats.regen_stamina(delta, 1.5)
	elif is_sprinting and not is_exhausted and input_vector.length() > 0:
		target_speed = sprint_speed * speed_mult
		if survival_stats: survival_stats.consume_stamina(15.0 * delta)
	else:
		target_speed = walk_speed * speed_mult
		if input_vector.length() == 0:
			if survival_stats: survival_stats.regen_stamina(delta, 2.0)
		else:
			if survival_stats: survival_stats.regen_stamina(delta, 0.5)
			
	if input_vector != Vector2.ZERO:
		velocity = velocity.move_toward(input_vector * target_speed, acceleration * delta)
		if randf() < 0.05 and SoundManager: SoundManager.play("footstep")
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		
	if player_camera:
		player_camera.is_aiming_ads = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not is_sprinting
		if player_camera.is_aiming_ads:
			velocity *= 0.5
		
	move_and_slide()

func set_flashlight(enabled: bool) -> void:
	if player_lighting:
		player_lighting.set_flashlight(enabled)

func refresh_equipped_weapon(prefer_first_available: bool = true) -> void:
	if weapon_handler:
		if prefer_first_available:
			var cur_dict = equipment.get(active_weapon_slot, {})
			if cur_dict.is_empty():
				for slot in WeaponHandler.WEAPON_SLOT_ORDER:
					var d = equipment.get(slot, {})
					if not d.is_empty():
						active_weapon_slot = slot
						break
		weapon_handler.switch_weapon_slot(active_weapon_slot)

func switch_weapon_slot(slot_name: String) -> void:
	if weapon_handler:
		weapon_handler.switch_weapon_slot(slot_name)

func cycle_weapon(direction: int) -> void:
	if weapon_handler:
		weapon_handler.cycle_weapon(direction)

func _get_available_ammo_count() -> int:
	return weapon_handler.get_available_ammo_count() if weapon_handler else 0

func _get_compatible_ammo_types() -> Array:
	return weapon_handler.get_compatible_ammo_types() if weapon_handler else ["9mm"]

func _get_slot_display_name(slot_name: String) -> String:
	return weapon_handler.get_slot_display_name(slot_name) if weapon_handler else slot_name

func apply_backpack_grid_size() -> void:
	if not inventory_grid: return
	var bp = equipment.get("backpack", {})
	var new_w = 6
	var new_h = 3
	if not bp.is_empty():
		var id = bp.get("id", "")
		var d = ItemDatabase.get_item_data(id)
		var b_grid = d.get("backpack_grid", Vector2i(6, 5))
		new_w = b_grid.x
		new_h = b_grid.y
	if inventory_grid.has_method("resize_grid"):
		inventory_grid.resize_grid(new_w, new_h)
	elif inventory_grid.has_method("resize"):
		inventory_grid.resize(new_w, new_h)

func apply_damage(amount: float, source: String = "unknown") -> void:
	_on_player_damaged(amount, source)

func take_damage(amount: float, source: String = "unknown") -> void:
	_on_player_damaged(amount, source)

var _hit_flash_tween: Tween = null
var _is_dying: bool = false

func _on_player_damaged(amount: float, source: String) -> void:
	if survival_stats:
		survival_stats.take_damage(amount, source)
	if source != "status_effect":
		if SoundManager:
			SoundManager.play("hit_melee")
		if player_visuals and player_visuals.material:
			if _hit_flash_tween:
				_hit_flash_tween.kill()
			_hit_flash_tween = create_tween()
			player_visuals.material.set_shader_parameter("flash_color", Color(1.0, 0.25, 0.25, 1.0))
			player_visuals.material.set_shader_parameter("flash_modifier", 0.85)
			_hit_flash_tween.tween_property(player_visuals.material, "shader_parameter/flash_modifier", 0.0, 0.18)

func _on_death() -> void:
	if _is_dying: return
	_is_dying = true
	velocity = Vector2.ZERO
	if SoundManager: SoundManager.play("player_death")
	EventBus.event_logged.emit("☠️ 플레이어가 사망했습니다. (작전 실패)")
	var timer = get_tree().create_timer(1.2, true, false, true)
	timer.timeout.connect(func():
		get_tree().paused = false
		if GameManager:
			GameManager.is_paused = false
			GameManager.end_raid("kia")
	)
