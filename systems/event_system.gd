# res://systems/event_system.gd
extends Node

## 게임 내 돌발 이벤트 관리 시스템

enum EventType {
	WEATHER,
	RAID,
	MERCHANT,
	SUPPLY_DROP,
	SURVIVOR,
	MILITARY_CONVOY,
	HORDE,
	MYSTERY,
	RADIO_SIGNAL
}

const RANDOM_EVENTS = {
	"폭우_피해": {
		"type": EventType.WEATHER,
		"title": "폭우가 몰아칩니다",
		"description": "은신처에 비가 새어 들어왔습니다. 습기로 인해 컨디션이 나빠집니다.",
		"effects": {"stress": 5, "hp": -5},
		"chance": 0.08,
		"day_min": 1,
	},
	"맑은_날": {
		"type": EventType.WEATHER,
		"title": "맑은 하늘",
		"description": "오랜만의 맑은 날씨입니다. 마음이 한결 가벼워집니다.",
		"effects": {"stress": -10},
		"chance": 0.1,
		"day_min": 1,
	},
	"야간_습격": {
		"type": EventType.RAID,
		"title": "야간 습격!",
		"description": "밤사이 적대 세력이 은신처를 공격했습니다!",
		"effects": {"stress": 15},
		"defense_check": 20,
		"defense_fail_effects": {"hp": -20, "stress": 25},
		"defense_success_msg": "튼튼한 바리케이드 덕분에 적대 세력이 물러갔습니다!",
		"defense_fail_msg": "방어도가 낮아 일부 피해를 입었습니다.",
		"chance": 0.1,
		"day_min": 3,
	},
	"물자_투하": {
		"type": EventType.SUPPLY_DROP,
		"title": "물자 투하 발견!",
		"description": "근처에서 군용 물자 투하 상자를 발견했습니다!",
		"loot": ["식량통조림", "생수", "구급상자", "탄약"],
		"chance": 0.04,
		"day_min": 5,
	},
	"적대_세력_웨이브": {
		"type": EventType.HORDE,
		"title": "적대 세력 웨이브!",
		"description": "대규모 적대 세력 무리가 이 지역으로 이동 중입니다!",
		"enemy_count": 8,
		"chance": 0.06,
		"day_min": 7,
	},
	"군사_호송대": {
		"type": EventType.MILITARY_CONVOY,
		"title": "군사 호송대 잔해",
		"description": "파괴된 군용 트럭을 발견했습니다. 물자가 남아있을 수 있습니다.",
		"loot": ["탄약", "구급상자", "라디오 부품"],
		"chance": 0.03,
		"day_min": 10,
	},
	"무전_신호": {
		"type": EventType.RADIO_SIGNAL,
		"title": "미약한 무전 신호",
		"description": "라디오에서 미약한 신호가 잡힙니다... '...구조대... 30일 후... 좌표...'",
		"effects": {"stress": -10},
		"chance": 0.05,
		"day_min": 1,
	},
}

class GameEvent:
	var id: String
	var data: Dictionary
	var title: String
	var description: String
	var effects: Dictionary = {}
	var display_timer: float = 5.0
	
	func _init(event_id: String, event_data: Dictionary) -> void:
		id = event_id
		data = event_data
		title = data.get("title", "이벤트")
		description = data.get("description", "")
		effects = data.get("effects", {})
		
	func apply_effects(player_data: Dictionary) -> void:
		var eff = data.get("effects", {})
		if eff.has("hp"):
			player_data["hp"] += eff["hp"]
		if eff.has("stress"):
			player_data["stress"] += eff["stress"]
		if eff.has("hunger"):
			player_data["hunger"] += eff["hunger"]
		if eff.has("thirst"):
			player_data["thirst"] += eff["thirst"]

var active_events: Array = []
var event_log: Array = []
var check_timer: float = 10.0 # 10초 후 첫 이벤트 체크
var check_interval: float = 20.0 # 20초 주기

func _process(delta: float) -> void:
	# 인게임 레이드 진행 중일 때만 동작
	if GameManager.current_state != GameManager.GameState.IN_GAME or get_tree().paused:
		return
		
	check_timer += delta
	
	for i in range(active_events.size() - 1, -1, -1):
		active_events[i].display_timer -= delta
		if active_events[i].display_timer <= 0:
			active_events.remove_at(i)
			
	for i in range(event_log.size() - 1, -1, -1):
		event_log[i]["timer"] -= delta
		if event_log[i]["timer"] <= 0:
			event_log.remove_at(i)
			
	if check_timer >= check_interval:
		check_timer = 0.0
		var current_day = GameManager.current_world_data.get("current_day", 1)
		_check_random_events(current_day)

func _apply_effect_dict(eff: Dictionary, p_override: Node = null) -> void:
	if eff.is_empty():
		return
	if GameManager and GameManager.current_world_data.has("player"):
		var player_data = GameManager.current_world_data["player"]
		if eff.has("hp"):
			player_data["hp"] = float(player_data.get("hp", 100.0)) + float(eff["hp"])
		if eff.has("stress"):
			player_data["stress"] = float(player_data.get("stress", 0.0)) + float(eff["stress"])
		if eff.has("hunger"):
			player_data["hunger"] = float(player_data.get("hunger", 100.0)) + float(eff["hunger"])
		if eff.has("thirst"):
			player_data["thirst"] = float(player_data.get("thirst", 100.0)) + float(eff["thirst"])
	var p = p_override
	if not is_instance_valid(p) and is_inside_tree() and get_tree():
		p = get_tree().get_first_node_in_group("player")
	if is_instance_valid(p):
		if eff.has("hp"):
			p.hp = clamp(p.hp + float(eff["hp"]), 1.0, p.max_hp)
		if eff.has("hunger"):
			p.hunger = clamp(p.hunger + float(eff["hunger"]), 0.0, p.max_hunger)
		if eff.has("thirst"):
			p.thirst = clamp(p.thirst + float(eff["thirst"]), 0.0, p.max_thirst)
		if p.has_signal("stats_changed"):
			p.stats_changed.emit()

func _apply_event_to_live_player(event: GameEvent, p_override: Node = null) -> void:
	var eff: Dictionary = event.data.get("effects", {}) if event and event.data else {}
	_apply_effect_dict(eff, p_override)

func evaluate_raid_defense(threshold: float, p_override: Node = null) -> bool:
	var p = p_override
	if not is_instance_valid(p) and is_inside_tree() and get_tree():
		p = get_tree().get_first_node_in_group("player")
	var defense_score: float = 0.0
	if is_instance_valid(p):
		defense_score += float(p.get("armor_defense") if p.get("armor_defense") != null else 0.0)
		var wep_data = p.get("equipped_weapon_data")
		var wep_name = str(p.get("equipped_weapon") if p.get("equipped_weapon") != null else "맨손")
		if wep_data is Dictionary and not wep_data.is_empty() and wep_name != "맨손":
			if int(wep_data.get("current_magazine_ammo", 0)) > 0:
				defense_score += 8.0
			else:
				defense_score += 3.0
		var eq = p.get("equipment")
		if eq is Dictionary:
			for s in ["primary1", "primary2", "sidearm"]:
				var sw = eq.get(s, {})
				if sw is Dictionary and not sw.is_empty():
					defense_score = max(defense_score, float(p.get("armor_defense") if p.get("armor_defense") != null else 0.0) + (8.0 if int(sw.get("current_magazine_ammo", 0)) > 0 else 3.0))
	elif GameManager and GameManager.current_world_data.has("player"):
		var eq_saved: Dictionary = GameManager.current_world_data["player"].get("equipment", {})
		for slot_k in ["helmet", "vest"]:
			var arm = eq_saved.get(slot_k, {})
			if arm is Dictionary and not arm.is_empty():
				var idata = ItemDatabase.get_item_data(arm.get("id", ""))
				var max_d = float(arm.get("max_durability", idata.get("max_durability", 100.0)))
				var cur_d = float(arm.get("durability", max_d))
				if cur_d > 0.0:
					defense_score += float(idata.get("defense", 0.0)) * clamp(cur_d / max(1.0, max_d), 0.0, 1.0)
		for ws in ["primary1", "primary2", "sidearm"]:
			var sw2 = eq_saved.get(ws, {})
			if sw2 is Dictionary and not sw2.is_empty():
				defense_score += 8.0 if int(sw2.get("current_magazine_ammo", 0)) > 0 else 3.0
				break
	return defense_score >= threshold

func _resolve_and_apply_event(event: GameEvent, p_override: Node = null) -> bool:
	var event_data = event.data
	if event_data.has("defense_check"):
		var threshold = float(event_data.get("defense_check", 20.0))
		if evaluate_raid_defense(threshold, p_override):
			_apply_event_to_live_player(event, p_override)
			add_log("✓ " + event.title + ": " + event_data.get("defense_success_msg", ""))
			return true
		else:
			var fail_eff: Dictionary = event_data.get("defense_fail_effects", {})
			_apply_effect_dict(fail_eff, p_override)
			add_log("⚠ " + event.title + ": " + event_data.get("defense_fail_msg", "습격 방어에 실패했습니다!"))
			var payload = event_data.duplicate(true)
			if not payload.has("raider_count"):
				payload["raider_count"] = randi_range(2, 3)
			if EventBus and EventBus.has_signal("random_world_event_triggered"):
				EventBus.random_world_event_triggered.emit(event.id, payload)
			return false
	else:
		_apply_event_to_live_player(event, p_override)
		add_log("★ " + event.title + ": " + event.description)
		if EventBus and EventBus.has_signal("random_world_event_triggered"):
			EventBus.random_world_event_triggered.emit(event.id, event.data)
		return true

func _check_random_events(current_day: int) -> void:
	var event_keys = RANDOM_EVENTS.keys()
	event_keys.shuffle()
	
	for event_id in event_keys:
		var event_data = RANDOM_EVENTS[event_id]
		if current_day < event_data.get("day_min", 1):
			continue
			
		var chance = event_data.get("chance", 0.0)
		if randf() < chance:
			var event = GameEvent.new(event_id, event_data)
			_resolve_and_apply_event(event)
			active_events.append(event)
			break # 한 번에 한 이벤트만 발생

func add_log(msg: String, duration: float = 8.0) -> void:
	event_log.push_front({"message": msg, "timer": duration})
	if event_log.size() > 8:
		event_log.resize(8)
	
	if EventBus.has_signal("event_logged"):
		EventBus.emit_signal("event_logged", msg)

func trigger_event(event_id: String, p_override: Node = null) -> bool:
	if RANDOM_EVENTS.has(event_id):
		var event_data = RANDOM_EVENTS[event_id]
		var event = GameEvent.new(event_id, event_data)
		var defended = _resolve_and_apply_event(event, p_override)
		active_events.append(event)
		return defended
	return false
