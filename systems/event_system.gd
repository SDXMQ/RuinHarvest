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
	var display_timer: float = 5.0
	
	func _init(event_id: String, event_data: Dictionary) -> void:
		id = event_id
		data = event_data
		title = data.get("title", "이벤트")
		description = data.get("description", "")
		
	func apply_effects(player_data: Dictionary) -> void:
		var effects = data.get("effects", {})
		if effects.has("hp"):
			player_data["hp"] += effects["hp"]
		if effects.has("stress"):
			player_data["stress"] += effects["stress"]
		if effects.has("hunger"):
			player_data["hunger"] += effects["hunger"]
		if effects.has("thirst"):
			player_data["thirst"] += effects["thirst"]

var active_events: Array = []
var event_log: Array = []
var check_timer: float = 0.0
var check_interval: float = 30.0 # 30초 주기

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.IN_GAME:
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

func _check_random_events(current_day: int) -> void:
	for event_id in RANDOM_EVENTS:
		var event_data = RANDOM_EVENTS[event_id]
		if current_day < event_data.get("day_min", 1):
			continue
			
		var chance = event_data.get("chance", 0.0)
		if randf() < chance:
			var event = GameEvent.new(event_id, event_data)
			
			if event_data.has("defense_check"):
				# 은신처 방어 체크 - 나중에 시스템 확장 시 사용
				add_log("✓ " + event.title + ": " + event_data.get("defense_success_msg", ""))
			else:
				if GameManager.current_world_data.has("player"):
					event.apply_effects(GameManager.current_world_data["player"])
				
				var loot = event_data.get("loot", [])
				if loot.size() > 0:
					# 이벤트 아이템 획득 시그널 (TODO: 필드 상자 스폰 등으로 처리)
					pass
					
				add_log("★ " + event.title + ": " + event.description)
				
			active_events.append(event)
			break # 한 번에 한 이벤트만 발생

func add_log(msg: String, duration: float = 8.0) -> void:
	event_log.push_front({"message": msg, "timer": duration})
	if event_log.size() > 8:
		event_log.resize(8)
	
	if EventBus.has_signal("event_logged"):
		EventBus.emit_signal("event_logged", msg)

func trigger_event(event_id: String) -> void:
	if RANDOM_EVENTS.has(event_id):
		var event_data = RANDOM_EVENTS[event_id]
		var event = GameEvent.new(event_id, event_data)
		if GameManager.current_world_data.has("player"):
			event.apply_effects(GameManager.current_world_data["player"])
		active_events.append(event)
		add_log("★ " + event.title + ": " + event.description)
