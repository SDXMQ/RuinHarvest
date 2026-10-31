# res://graphics/post_process_controller.gd
extends ColorRect

var target_tint: Color = Color(1, 1, 1, 1)
var current_tint: Color = Color(1, 1, 1, 1)
var hp_pulse_time: float = 0.0
var lightning_timer: float = 14.0
var lightning_flash_val: float = 0.0

func _ready() -> void:
	# 시간대/날씨에 따른 틴트 조절
	if EventBus.has_signal("weather_changed"):
		EventBus.weather_changed.connect(_on_weather_changed)

func _process(delta: float) -> void:
	# 1. 컬러 그레이딩 부드러운 전환
	current_tint = current_tint.lerp(target_tint, delta * 0.5)
	if material:
		material.set_shader_parameter("tint_color", current_tint)
		
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
