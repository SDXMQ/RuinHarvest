import os

player_gd = """extends CharacterBody2D
class_name Player

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
@onready var player_visuals = $Visuals/PlayerVisuals

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
	
var equipment: Dictionary:
	get: return weapon_handler.equipment if weapon_handler else {}
	set(v): if weapon_handler: weapon_handler.equipment = v

func _ready() -> void:
	if not has_node("InventoryGrid"):
		inventory_grid = InventoryGrid.new()
		inventory_grid.name = "InventoryGrid"
		inventory_grid.resize(6, 5)
		add_child(inventory_grid)
	else:
		inventory_grid = get_node("InventoryGrid")

	if not has_node("Inventory"):
		inventory = Inventory.new()
		inventory.name = "Inventory"
		add_child(inventory)
	else:
		inventory = get_node("Inventory")

	EventBus.player_damaged.connect(_on_damaged_for_sound)
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
	
	if survival_stats.is_fractured: speed_mult *= 0.6
	if equipment.has("backpack") and not equipment["backpack"].is_empty():
		speed_mult -= 0.1
		
	var w_data = weapon_handler.equipped_weapon_data
	if not w_data.is_empty() and w_data.has("computed_stats"):
		var w_weight = w_data["computed_stats"].get("weight", 3.0)
		speed_mult -= min(0.3, w_weight * 0.05)
		
	if is_crouching:
		target_speed = crouch_speed * speed_mult
		survival_stats.regen_stamina(delta, 1.5)
	elif is_sprinting and not survival_stats.is_exhausted and input_vector.length() > 0:
		target_speed = sprint_speed * speed_mult
		survival_stats.consume_stamina(15.0 * delta)
	else:
		target_speed = walk_speed * speed_mult
		if input_vector.length() == 0:
			survival_stats.regen_stamina(delta, 2.0)
		else:
			survival_stats.regen_stamina(delta, 0.5)
			
	if input_vector != Vector2.ZERO:
		velocity = velocity.move_toward(input_vector * target_speed, acceleration * delta)
		if randf() < 0.05 and SoundManager: SoundManager.play("footstep")
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		
	player_camera.is_aiming_ads = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not is_sprinting
	if player_camera.is_aiming_ads:
		velocity *= 0.5
		
	move_and_slide()

func apply_damage(amount: float, source: String = "unknown") -> void:
	survival_stats.take_damage(amount, source)
	if EventBus.has_signal("player_damaged"):
		EventBus.player_damaged.emit(amount, source)

func _on_damaged_for_sound(amount: float, source: String) -> void:
	if source != "status_effect" and SoundManager:
		SoundManager.play("hit_melee")

func _on_death() -> void:
	velocity = Vector2.ZERO
	if SoundManager: SoundManager.play("player_death")
	EventBus.event_logged.emit("☠️ 플레이어가 사망했습니다.")
	get_tree().paused = true
"""

with open("scenes/entities/player/player.gd", "w", encoding="utf-8") as f:
    f.write(player_gd)

print("Overwrote player.gd with refactored version")
