# res://graphics/post_process_controller.gd
extends ColorRect

var target_tint: Color = Color(1, 1, 1, 1)
var current_tint: Color = Color(1, 1, 1, 1)
var hp_pulse_time: float = 0.0
var infection_pulse_time: float = 0.0
var current_infection_pulse: float = 0.0
var lightning_timer: float = 14.0
var lightning_flash_val: float = 0.0
var chromatic_aberration_val: float = 0.0
var current_rain_intensity: float = 0.0
var _ca_tween: Tween = null

static func compute_infection_vignette_strength(infected: bool, pulse_time: float = 0.0) -> float:
	if not infected:
		return 0.0
	return 0.45 + 0.25 * (sin(pulse_time) * 0.5 + 0.5)

func _ready() -> void:
	# 시간대/날씨에 따른 틴트 조절
	if EventBus.has_signal("weather_changed") and not EventBus.weather_changed.is_connected(_on_weather_changed):
		EventBus.weather_changed.connect(_on_weather_changed)
	if EventBus.has_signal("player_damaged") and not EventBus.player_damaged.is_connected(_on_player_damaged):
		EventBus.player_damaged.connect(_on_player_damaged)
	if EventBus.has_signal("camera_shake_requested") and not EventBus.camera_shake_requested.is_connected(_on_camera_shake_requested):
		EventBus.camera_shake_requested.connect(_on_camera_shake_requested)

	if WeatherSystem:
		_on_weather_changed(WeatherSystem.get_weather_name(WeatherSystem.current_weather))
		current_tint = target_tint
		current_rain_intensity = _get_target_rain_intensity()
	if material:
		material.set_shader_parameter("tint_color", current_tint)
		material.set_shader_parameter("rain_intensity", current_rain_intensity)
		material.set_shader_parameter("chromatic_aberration", chromatic_aberration_val)

func _get_target_rain_intensity() -> float:
	var current_scene = get_tree().current_scene if get_tree() else null
	var is_interior = current_scene != null and "Interior" in current_scene.name
	if is_interior or not WeatherSystem:
		return 0.0
	match WeatherSystem.current_weather:
		WeatherSystem.WeatherType.RAIN:
			return 0.50
		WeatherSystem.WeatherType.HEAVY_RAIN:
			return 0.85
		WeatherSystem.WeatherType.STORM:
			return 1.0
		_:
			return 0.0

func trigger_chromatic_aberration(strength: float, duration: float = 0.28) -> void:
	var setting_scale := 1.0
	if GameSettings and "chromatic_aberration" in GameSettings:
		setting_scale = clampf(float(GameSettings.chromatic_aberration) / 0.3, 0.0, 2.0)
	var peak: float = clampf(strength * setting_scale, 0.0, 1.0)
	if peak <= chromatic_aberration_val and chromatic_aberration_val > 0.01:
		return
	chromatic_aberration_val = peak
	if material:
		material.set_shader_parameter("chromatic_aberration", chromatic_aberration_val)
	if _ca_tween and is_instance_valid(_ca_tween):
		_ca_tween.kill()
	if is_inside_tree() and peak > 0.001:
		_ca_tween = create_tween()
		_ca_tween.set_ease(Tween.EASE_OUT)
		_ca_tween.set_trans(Tween.TRANS_QUAD)
		_ca_tween.tween_property(self, "chromatic_aberration_val", 0.0, maxf(duration, 0.08))

func _on_player_damaged(amount: float, _source: String) -> void:
	var strength := clampf(0.28 + amount * 0.015, 0.25, 0.95)
	trigger_chromatic_aberration(strength, 0.35)

func _on_camera_shake_requested(intensity: float, duration: float) -> void:
	var strength := clampf(intensity * 0.075, 0.12, 0.85)
	trigger_chromatic_aberration(strength, clampf(duration * 1.1, 0.16, 0.42))

func _process(delta: float) -> void:
	if GameSettings and "enable_post_process" in GameSettings:
		visible = bool(GameSettings.enable_post_process)
		if not visible:
			return

	# 1. 컬러 그레이딩 부드러운 전환 & 비/색수차 유니폼 동기화
	current_tint = current_tint.lerp(target_tint, delta * 0.5)
	var target_rain := _get_target_rain_intensity()
	current_rain_intensity = lerp(current_rain_intensity, target_rain, delta * 2.0)
	if material:
		material.set_shader_parameter("tint_color", current_tint)
		material.set_shader_parameter("rain_intensity", current_rain_intensity)
		material.set_shader_parameter("chromatic_aberration", chromatic_aberration_val)

	# 2. 플레이어 저체력 펄스 및 야간투시경(NVG) 셰이더 동기화
	var player = get_tree().get_first_node_in_group("player")
	var nvg_on = false
	if player:
		if "player_lighting" in player and player.player_lighting:
			nvg_on = bool(player.player_lighting.nvg_enabled)
		elif player.has_node("PlayerLighting"):
			nvg_on = bool(player.get_node("PlayerLighting").nvg_enabled)
	if material:
		material.set_shader_parameter("nvg_active", 1.0 if nvg_on else 0.0)

	if player and "hp" in player and "max_hp" in player:
		var hp_ratio = float(player.hp) / float(player.max_hp)
		if hp_ratio <= 0.35: # 체력 35% 이하일 때 점멸
			hp_pulse_time += delta * 4.0 # 심장 박동 속도
			var pulse = (sin(hp_pulse_time) * 0.5 + 0.5) * (1.0 - (hp_ratio / 0.35))
			if material:
				material.set_shader_parameter("low_hp_pulse", pulse)
		else:
			hp_pulse_time = 0.0
			if material:
				material.set_shader_parameter("low_hp_pulse", 0.0)

	if player and "is_infected" in player and bool(player.is_infected):
		infection_pulse_time += delta * 3.0
		current_infection_pulse = compute_infection_vignette_strength(true, infection_pulse_time)
	else:
		infection_pulse_time = 0.0
		current_infection_pulse = 0.0
	if material:
		material.set_shader_parameter("infection_pulse", current_infection_pulse)

	# 3. 낮/밤 환경광 기반 비네팅 자동 제어 (낮에는 0.0, 밤이나 실내에서만 부드럽게 점진적 증가)
	var current_scene = get_tree().current_scene
	var day_night = current_scene.get_node_or_null("DayNightModulate") if current_scene else null
	var target_vignette = 0.0
	var is_interior = current_scene != null and "Interior" in current_scene.name

	if day_night and day_night is CanvasModulate:
		var brightness = day_night.color.v
		# 밝기 0.85 이상(낮)이면 0, 0.25 이하(심야)면 0.28
		var night_t = clamp((0.85 - brightness) / 0.6, 0.0, 1.0)
		target_vignette = night_t * 0.28
	elif is_interior:
		target_vignette = 0.15 # 실내는 은은하게

	if material:
		var cur_vignette = material.get_shader_parameter("vignette_intensity")
		if cur_vignette == null: cur_vignette = 0.0
		var new_v = lerp(float(cur_vignette), target_vignette, delta * 1.5)
		material.set_shader_parameter("vignette_intensity", new_v)

	# 4. 악천후(STORM) 낙뢰(Lightning Flash) 및 천둥 연출
	if lightning_flash_val > 0.0:
		lightning_flash_val = max(0.0, lightning_flash_val - delta * 6.5)
		if material:
			material.set_shader_parameter("lightning_flash", lightning_flash_val)
	if not get_tree().paused and not is_interior and WeatherSystem and WeatherSystem.current_weather == WeatherSystem.WeatherType.STORM:
		lightning_timer -= delta
		if lightning_timer <= 0.0:
			lightning_timer = randf_range(12.0, 22.0)
			trigger_lightning_flash()

func trigger_lightning_flash() -> void:
	lightning_flash_val = 1.0
	if material:
		material.set_shader_parameter("lightning_flash", 1.0)
	trigger_chromatic_aberration(0.45, 0.30)
	if SoundManager:
		SoundManager.play("explosion_distant")
	if EventBus.has_signal("camera_shake_requested"):
		EventBus.camera_shake_requested.emit(3.5, 0.25)

func _on_weather_changed(new_weather: String) -> void:
	match new_weather:
		"맑음": target_tint = Color(1.0, 1.0, 1.0, 1.0)
		"흐림": target_tint = Color(0.9, 0.9, 0.95, 1.0)
		"비", "폭우": target_tint = Color(0.8, 0.85, 0.95, 1.0)
		"안개": target_tint = Color(0.95, 0.95, 0.95, 1.0)
		"폭풍": target_tint = Color(0.7, 0.7, 0.85, 1.0)
		_: target_tint = Color(1.0, 1.0, 1.0, 1.0)
