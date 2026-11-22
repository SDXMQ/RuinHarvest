# res://autoload/sound_manager.gd
extends Node

## 절차적 사운드 생성 및 재생 매니저 (AudioStreamWAV 기반)

const SAMPLE_RATE: int = 22050
const MAX_PLAYERS: int = 16
const SFX_BASE_GAIN_DB: float = -8.0
const MIN_REPEAT_INTERVAL_MS: int = 35

var _cache: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _last_play_ms: Dictionary = {}

func _ensure_audio_buses() -> void:
	if GameSettings and GameSettings.has_method("ensure_audio_buses"):
		GameSettings.ensure_audio_buses()
		return
	if AudioServer.get_bus_index("BGM") == -1:
		var bgm_idx: int = AudioServer.bus_count
		AudioServer.add_bus(bgm_idx)
		AudioServer.set_bus_name(bgm_idx, "BGM")
		AudioServer.set_bus_send(bgm_idx, "Master")
	if AudioServer.get_bus_index("SFX") == -1:
		var sfx_idx: int = AudioServer.bus_count
		AudioServer.add_bus(sfx_idx)
		AudioServer.set_bus_name(sfx_idx, "SFX")
		AudioServer.set_bus_send(sfx_idx, "Master")

func _ready() -> void:
	_ensure_audio_buses()
	# 사운드 플레이어 풀 초기화
	for i in range(MAX_PLAYERS):
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
		
	# BGM 플레이어
	var bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMPlayer"
	bgm_player.bus = "BGM"
	add_child(bgm_player)
	
	if GameSettings and GameSettings.has_method("apply_audio_settings"):
		GameSettings.apply_audio_settings()
	
	# 자주 사용하는 사운드 미리 캐싱
	_preload_sounds()

func _preload_sounds() -> void:
	# 비동기 또는 초기 로딩 시 한 번에 생성
	var sounds_to_load = [
		"hit_melee", "hit_ranged", "player_hurt", "enemy_die",
		"pickup", "craft_complete", "menu_hover", "menu_select",
		"door_open", "footstep", "alert", "game_over", "day_start",
		"dry_fire", "armor_ricochet"
	]
	for s in sounds_to_load:
		get_sound(s)

func play(sound_name: String, volume_mult: float = 1.0, pitch_scale: float = 1.0) -> void:
	if volume_mult <= 0.0:
		return
	var now_ms: int = Time.get_ticks_msec()
	if _last_play_ms.has(sound_name) and (now_ms - int(_last_play_ms[sound_name])) < MIN_REPEAT_INTERVAL_MS:
		return
	_last_play_ms[sound_name] = now_ms
	var stream = get_sound(sound_name)
	if not stream:
		return
		
	# 가용한 플레이어 찾기
	var player_to_use: AudioStreamPlayer = null
	for p in _players:
		if not p.playing:
			player_to_use = p
			break
			
	# 모든 플레이어가 사용 중이면 가장 재생 진행도가 높은(오래된) 것 덮어쓰기 (또는 무시)
	if player_to_use == null:
		player_to_use = _players[0]
		var max_pos = 0.0
		for p in _players:
			if p.get_playback_position() > max_pos:
				max_pos = p.get_playback_position()
				player_to_use = p
				
	player_to_use.stream = stream
	player_to_use.volume_db = SFX_BASE_GAIN_DB + linear_to_db(clampf(volume_mult, 0.001, 1.5))
	var final_pitch = pitch_scale
	if is_equal_approx(pitch_scale, 1.0) and (sound_name.begins_with("footstep") or sound_name in ["hit_ranged", "hit_melee", "enemy_die", "player_hurt", "explosion_distant", "dry_fire", "armor_ricochet"]):
		final_pitch = randf_range(0.92, 1.08)
	player_to_use.pitch_scale = final_pitch
	player_to_use.play()

func get_sound(sound_name: String) -> AudioStreamWAV:
	if _cache.has(sound_name):
		return _cache[sound_name]
		
	var stream = _create_sound(sound_name)
	_cache[sound_name] = stream
	return stream

func _create_sound(s_name: String) -> AudioStreamWAV:
	if s_name == "hit_melee":
		return _generate_tone(150.0, 0.14, 0.18, "square")
	elif s_name == "hit_ranged":
		return _generate_tone(800.0, 0.08, 0.16, "noise")
	elif s_name == "dry_fire":
		return _generate_dry_fire_sound()
	elif s_name == "armor_ricochet":
		return _generate_tone(1420.0, 0.06, 0.14, "square")
	elif s_name == "player_hurt":
		return _generate_tone(200.0, 0.28, 0.18, "sawtooth")
	elif s_name == "enemy_die":
		return _generate_tone(100.0, 0.36, 0.16, "sawtooth")
	elif s_name == "pickup" or s_name == "item_pickup":
		return _generate_tone(640.0, 0.1, 0.14, "sine")
	elif s_name == "craft_complete":
		return _generate_tone(800.0, 0.15, 0.14, "sine")
	elif s_name == "menu_hover" or s_name == "menu_move":
		return _generate_tone(380.0, 0.04, 0.08, "sine")
	elif s_name == "menu_select":
		return _generate_tone(500.0, 0.09, 0.10, "sine")
	elif s_name == "door_open":
		return _generate_tone(250.0, 0.18, 0.13, "square")
	elif s_name == "footstep" or s_name == "footstep_grass":
		return _generate_tone(80.0, 0.05, 0.07, "noise")
	elif s_name == "footstep_concrete":
		return _generate_tone(220.0, 0.04, 0.09, "square")
	elif s_name == "footstep_wood":
		return _generate_tone(145.0, 0.05, 0.09, "sawtooth")
	elif s_name == "footstep_water":
		return _generate_tone(420.0, 0.08, 0.10, "noise")
	elif s_name == "alert":
		return _generate_tone(700.0, 0.25, 0.15, "square")
	elif s_name == "explosion_distant":
		return _generate_tone(65.0, 0.40, 0.14, "noise")
	elif s_name == "explosion":
		return _generate_tone(65.0, 0.45, 0.22, "noise")
	elif s_name == "reload":
		return _generate_tone(320.0, 0.12, 0.15, "square")
	elif s_name == "game_over":
		return _generate_tone(150.0, 0.75, 0.18, "sawtooth")
	elif s_name == "day_start":
		return _generate_tone(440.0, 0.28, 0.13, "sine")
	else:
		return _generate_tone(440.0, 0.1, 0.09, "sine")

func _generate_dry_fire_sound() -> AudioStreamWAV:
	var duration := 0.075
	var num_samples: int = int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	for i in range(num_samples):
		var t: float = float(i) / SAMPLE_RATE
		# 철컥! 이중 금속 공이 타격음 (초반 고주파 클릭 + 중반 노리쇠 걸림음)
		var env1: float = exp(-t * 95.0)
		var click1: float = sin(TAU * 1680.0 * t) * 0.65 + randf_range(-0.35, 0.35)
		var env2: float = exp(-max(0.0, t - 0.022) * 80.0) if t >= 0.022 else 0.0
		var click2: float = sin(TAU * 620.0 * (t - 0.022)) * 0.50
		var sample_val: float = clampf((click1 * env1 + click2 * env2) * 0.20, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample_val * 32767.0))
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav

func _generate_tone(frequency: float, duration: float, volume: float = 0.2, wave_type: String = "sine", fade_out: bool = true) -> AudioStreamWAV:
	var num_samples: int = maxi(1, int(SAMPLE_RATE * duration))
	var data := PackedByteArray()
	data.resize(num_samples * 2) # 16비트 오디오 (2 바이트)
	var lp_state: float = 0.0
	var cutoff: float = clampf(frequency * 2.2, 180.0, 2200.0)
	var noise_alpha: float = clampf((TAU * cutoff) / (SAMPLE_RATE + TAU * cutoff), 0.04, 0.45)
	var attack_samples: float = maxf(1.0, num_samples * 0.05)
	
	for i in range(num_samples):
		var t: float = float(i) / SAMPLE_RATE
		var value: float = 0.0
		
		if wave_type == "sine":
			value = sin(2.0 * PI * frequency * t)
		elif wave_type == "square":
			var raw_sq: float = 1.0 if sin(2.0 * PI * frequency * t) > 0.0 else -1.0
			lp_state = lerpf(lp_state, raw_sq, 0.35)
			value = lp_state
		elif wave_type == "noise":
			var raw_n: float = randf_range(-1.0, 1.0)
			lp_state = lerpf(lp_state, raw_n, noise_alpha)
			value = lp_state
		elif wave_type == "sawtooth":
			var raw_saw: float = 2.0 * fmod(t * frequency, 1.0) - 1.0
			lp_state = lerpf(lp_state, raw_saw, 0.45)
			value = lp_state
		else:
			value = sin(2.0 * PI * frequency * t)
			
		# 페이드 아웃 및 어택
		var envelope: float = 1.0
		if fade_out:
			var ratio: float = float(i) / float(num_samples)
			envelope = pow(maxf(0.0, 1.0 - ratio), 1.35)
			
		# 어택 (앞 5%)
		if float(i) < attack_samples:
			envelope *= (float(i) / attack_samples)
			
		# 최종 샘플 계산 (-32768 ~ 32767)
		var final_sample: float = clampf(value * volume * envelope, -1.0, 1.0)
		var int_val: int = int(final_sample * 32767.0)
		data.encode_s16(i * 2, int_val)
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav
