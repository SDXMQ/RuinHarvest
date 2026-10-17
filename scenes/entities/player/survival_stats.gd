extends Node
class_name SurvivalStats

signal stats_changed

@export var max_hp: float = 100.0
var hp: float = 100.0
@export var max_stamina: float = 100.0
var stamina: float = 100.0
@export var max_hunger: float = 100.0
var hunger: float = 100.0
@export var max_thirst: float = 100.0
var thirst: float = 100.0

var is_bleeding: bool = false
var is_infected: bool = false
var is_fractured: bool = false
var is_exhausted: bool = false
var is_god_mode: bool = false

var armor_defense: float = 0.0

func _process(delta: float) -> void:
	if is_god_mode:
		hunger = max_hunger
		thirst = max_thirst
		hp = max_hp
		stamina = max_stamina
		stats_changed.emit()
		return
		
	hunger -= 0.15 * delta
	thirst -= 0.25 * delta
	
	if is_bleeding: hp -= 1.0 * delta
	if is_infected: hp -= 0.5 * delta
	if hunger <= 0: hp -= 0.5 * delta
	if thirst <= 0: hp -= 1.0 * delta
	
	hunger = clamp(hunger, 0.0, max_hunger)
	thirst = clamp(thirst, 0.0, max_thirst)
	hp = clamp(hp, 0.0, max_hp)
	
	if hp <= 0:
		EventBus.player_died.emit()
		
	stats_changed.emit()

func regen_stamina(delta: float, multiplier: float) -> void:
	if hunger > 20.0 and thirst > 20.0:
		stamina += 10.0 * multiplier * delta
	stamina = clamp(stamina, 0.0, max_stamina)
	if is_exhausted and stamina >= 25.0:
		is_exhausted = false

func consume_stamina(amount: float) -> void:
	stamina -= amount
	if stamina <= 0.0:
		is_exhausted = true

func take_damage(amount: float, source: String) -> void:
	if is_god_mode: return
	var dmg_reduction = armor_defense / (armor_defense + 100.0)
	var actual_damage = max(1.0, amount * (1.0 - dmg_reduction))
	hp -= actual_damage
	if source == "zombie" and randf() < 0.3:
		is_infected = true
	elif source == "gunfire" and randf() < 0.5:
		is_bleeding = true
	stats_changed.emit()
