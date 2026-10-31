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

var base_armor_defense: float = 0.0
var armor_defense: float:
	get:
		return get_total_armor_defense()
	set(v):
		base_armor_defense = v
var _ui_sync_timer: float = 0.0

@onready var player = get_parent()

func _ready() -> void:
	if GameManager and not GameManager.current_world_data.is_empty():
		var bonus_hp = HideoutProgression.get_bonus_max_hp(GameManager.current_world_data)
		max_hp = 100.0 + bonus_hp
		hp = max_hp

func get_total_armor_defense() -> float:
	var total = base_armor_defense
	var p = player if player else get_parent()
	if p and "equipment" in p:
		for slot in ["helmet", "vest"]:
			var eq = p.equipment.get(slot, {})
			if not eq.is_empty():
				var d = ItemDatabase.get_item_data(eq.get("id", ""))
				var base_defense = float(d.get("armor_defense", d.get("defense", 0)))
				var max_dur = float(eq.get("max_durability", d.get("max_durability", 100.0)))
				var cur_dur = float(eq.get("durability", max_dur))
				if max_dur > 0.0 and cur_dur > 0.0:
					var ratio = clamp(cur_dur / max_dur, 0.0, 1.0)
					total += base_defense * ratio
				# 내구도 0 도달 시 관통 방어 불가 (0% 추가)
	return total

func _process(delta: float) -> void:
	if is_god_mode:
		hunger = max_hunger
		thirst = max_thirst
		hp = max_hp
		stamina = max_stamina
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
		stats_changed.emit()
		EventBus.player_died.emit()
		return
		
	_ui_sync_timer += delta
	if _ui_sync_timer >= 0.2:
		_ui_sync_timer = 0.0
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
	var def = get_total_armor_defense()
	var dmg_reduction = def / (def + 80.0)
	var actual_damage = max(1.0, amount * (1.0 - dmg_reduction))
	hp = max(0.0, hp - actual_damage)
	
	# 피격 시 착용 중인 vest와 helmet의 durability를 피격 데미지 비례(amount * 0.35)로 차감
	if player and "equipment" in player:
		for slot in ["helmet", "vest"]:
			var eq = player.equipment.get(slot, {})
			if not eq.is_empty():
				var d = ItemDatabase.get_item_data(eq.get("id", ""))
				var max_dur = float(eq.get("max_durability", d.get("max_durability", 100.0)))
				var prev_dur = float(eq.get("durability", max_dur))
				var cur_dur = max(0.0, prev_dur - (amount * 0.35))
				eq["durability"] = cur_dur
				if not eq.has("max_durability"):
					eq["max_durability"] = max_dur
				player.equipment[slot] = eq
				if prev_dur > 0.0 and cur_dur <= 0.0:
					if player.has_method("show_floating_text"):
						player.show_floating_text("[BROKEN]", Color(1.0, 0.25, 0.25))
					if EventBus.has_signal("event_logged"):
						EventBus.event_logged.emit("🛡️ [%s] 내구도가 0이 되어 방어력을 상실했습니다!" % d.get("name", eq.get("id", slot)))
				
	if source == "zombie" and randf() < 0.28:
		is_infected = true
	elif source in ["gunfire", "gunshot", "explosion"] and randf() < 0.38:
		is_bleeding = true
	if hp <= 0:
		EventBus.player_died.emit()
	stats_changed.emit()
	if player and player.has_signal("stats_changed"):
		player.stats_changed.emit()
