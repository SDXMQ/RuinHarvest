# res://systems/weather_system.gd
extends Node

## 게임 내 시간 및 날씨 변화 시스템

const GAME_HOURS_PER_DAY = 24.0
const DAWN_HOUR = 5.0
const DAY_HOUR = 8.0
const DUSK_HOUR = 18.0
const NIGHT_HOUR = 21.0

# 시간 변수
var day_length_seconds: float = 12.0 * 60.0 # 기본 12분 = 1일
var seconds_per_game_hour: float = day_length_seconds / GAME_HOURS_PER_DAY
var current_day: int = 1
var current_hour: float = 8.0
var total_elapsed: float = 0.0
var time_speed: float = 1.0

# 날씨 종류
enum WeatherType {
	CLEAR,
	CLOUDY,
	RAIN,
	HEAVY_RAIN,
	FOG,
	STORM
}

# 날씨 변수
var variability: float = 1.0
var current_weather: WeatherType = WeatherType.CLEAR
var target_weather: WeatherType = WeatherType.CLEAR
var transition_timer: float = 0.0
var transition_duration: float = 5.0
var weather_duration: float = 0.0
var weather_timer: float = 0.0
var intensity: float = 0.0

var weather_weights = {
	WeatherType.CLEAR: 35.0,
	WeatherType.CLOUDY: 25.0,
	WeatherType.RAIN: 18.0,
	WeatherType.HEAVY_RAIN: 8.0,
	WeatherType.FOG: 10.0,
	WeatherType.STORM: 4.0
}

signal weather_changed(new_weather: WeatherType)
signal time_changed(hour: int, minute: int)
signal day_changed(new_day: int)

func _ready() -> void:
	_randomize_weather()

func _process(delta: float) -> void:
	var game_dt = delta * time_speed
	var hours_passed = game_dt / seconds_per_game_hour
	
	var old_hour = int(current_hour)
	var old_minute = int((current_hour - old_hour) * 60)
	
	current_hour += hours_passed
	total_elapsed += game_dt
	
	if current_hour >= 24.0:
		current_hour -= 24.0
		current_day += 1
		day_changed.emit(current_day)
		EventBus.day_changed.emit(current_day)
		
	var new_hour = int(current_hour)
	var new_minute = int((current_hour - new_hour) * 60)
	if old_hour != new_hour or old_minute != new_minute:
		time_changed.emit(new_hour, new_minute)
		
	_update_weather(delta)

func _update_weather(dt: float) -> void:
	weather_timer += dt
	
	if transition_timer < transition_duration:
		transition_timer += dt
		var t = clamp(transition_timer / transition_duration, 0.0, 1.0)
		if current_weather != target_weather:
			intensity = t
			if t >= 1.0:
				current_weather = target_weather
				EventBus.weather_changed.emit(get_weather_name(current_weather))
				if EventBus.has_signal("event_logged"):
					EventBus.event_logged.emit("🌦️ 기상 변화: [%s]" % get_weather_name(current_weather))
				weather_changed.emit(current_weather)
	else:
		intensity = 1.0
		
	if weather_timer >= weather_duration:
		_randomize_weather()

func _randomize_weather() -> void:
	var weights = []
	var weathers = []
	
	for w in weather_weights.keys():
		weathers.append(w)
		if w != WeatherType.CLEAR:
			weights.append(weather_weights[w] * variability)
		else:
			weights.append(weather_weights[w])
			
	var total = 0.0
	for weight in weights:
		total += weight
		
	var r = randf_range(0, total)
	var cumulative = 0.0
	
	for i in range(weights.size()):
		cumulative += weights[i]
		if r <= cumulative:
			target_weather = weathers[i]
			break
			
	weather_duration = randf_range(60.0, 300.0) * variability
	weather_timer = 0.0
	transition_timer = 0.0

func get_ambient_color() -> Color:
	var h = current_hour
	var night_color = Color(10.0/255.0, 10.0/255.0, 35.0/255.0, 160.0/255.0)
	var dawn_color = Color(255.0/255.0, 200.0/255.0, 150.0/255.0, 0.0)
	var day_color = Color(1.0, 1.0, 1.0, 0.0)
	var dusk_color = Color(200.0/255.0, 120.0/255.0, 60.0/255.0, 160.0/255.0)
	
	if h < DAWN_HOUR:
		return night_color
	elif h < DAY_HOUR:
		var t = (h - DAWN_HOUR) / (DAY_HOUR - DAWN_HOUR)
		var alpha = lerp(160.0, 0.0, t) / 255.0
		var color = night_color.lerp(dawn_color, t)
		color.a = alpha
		return color
	elif h < DUSK_HOUR:
		return day_color
	elif h < NIGHT_HOUR:
		var t = (h - DUSK_HOUR) / (NIGHT_HOUR - DUSK_HOUR)
		var alpha = lerp(0.0, 160.0, t) / 255.0
		var color = dusk_color.lerp(night_color, t)
		color.a = alpha
		return color
	else:
		return night_color

func get_visibility_modifier() -> float:
	match current_weather:
		WeatherType.CLEAR: return 1.0
		WeatherType.CLOUDY: return 0.9
		WeatherType.RAIN: return 0.7
		WeatherType.HEAVY_RAIN: return 0.5
		WeatherType.FOG: return 0.3
		WeatherType.STORM: return 0.4
		_: return 1.0

func get_movement_modifier() -> float:
	match current_weather:
		WeatherType.RAIN: return 0.9
		WeatherType.HEAVY_RAIN: return 0.75
		WeatherType.FOG: return 0.95
		WeatherType.STORM: return 0.7
		_: return 1.0

func get_weather_name(wt: WeatherType) -> String:
	match wt:
		WeatherType.CLEAR: return "맑음"
		WeatherType.CLOUDY: return "흐림"
		WeatherType.RAIN: return "비"
		WeatherType.HEAVY_RAIN: return "폭우"
		WeatherType.FOG: return "안개"
		WeatherType.STORM: return "폭풍"
		_: return "알수없음"

func get_time_string() -> String:
	var h = int(current_hour)
	var m = int((current_hour - h) * 60)
	return "%02d:%02d" % [h, m]

func is_night() -> bool:
	return current_hour >= NIGHT_HOUR or current_hour < DAWN_HOUR
