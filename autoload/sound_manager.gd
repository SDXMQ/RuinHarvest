# res://autoload/sound_manager.gd
extends Node

## 절차적 사운드 생성 및 재생 매니저 (AudioStreamWAV 기반)

const SAMPLE_RATE: int = 22050
const MAX_PLAYERS: int = 16

var _cache: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []

func _ready() -> void:
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
	
	# 자주 사용하는 사운드 미리 캐싱
	_preload_sounds()

func _preload_sounds() -> void:
	# 비동기 또는 초기 로딩 시 한 번에 생성
	var sounds_to_load = [
		"hit_melee", "hit_ranged", "player_hurt", "enemy_die",
		"pickup", "craft_complete", "menu_hover", "menu_select",
		"door_open", "footstep", "alert", "game_over", "day_start"
	]
	for s in sounds_to_load:
		get_sound(s)

func play(sound_name: String, volume_mult: float = 1.0, pitch_scale: float = 1.0) -> void:
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
	player_to_use.volume_db = linear_to_db(volume_mult)
	player_to_use.pitch_scale = pitch_scale
	player_to_use.play()

func get_sound(sound_name: String) -> AudioStreamWAV:
	if _cache.has(sound_name):
		return _cache[sound_name]
		
	var stream = _create_sound(sound_name)
	_cache[sound_name] = stream
	return stream

func _create_sound(s_name: String) -> AudioStreamWAV:
	if s_name == "hit_melee":
		return _generate_tone(150.0, 0.15, 0.4, "square")
	elif s_name == "hit_ranged":
		return _generate_tone(800.0, 0.08, 0.3, "noise")
	elif s_name == "player_hurt":
		return _generate_tone(200.0, 0.3, 0.3, "sawtooth")
	elif s_name == "enemy_die":
		return _generate_tone(100.0, 0.4, 0.3, "sawtooth")
	elif s_name == "pickup":
		return _generate_tone(600.0, 0.1, 0.2, "sine")
	elif s_name == "craft_complete":
		return _generate_tone(800.0, 0.15, 0.2, "sine")
	elif s_name == "menu_hover":
		return _generate_tone(400.0, 0.05, 0.1, "sine")
	elif s_name == "menu_select":
		return _generate_tone(500.0, 0.1, 0.15, "sine")
	elif s_name == "door_open":
		return _generate_tone(250.0, 0.2, 0.2, "square")
	elif s_name == "footstep":
		return _generate_tone(80.0, 0.05, 0.1, "noise")
	elif s_name == "alert":
		return _generate_tone(700.0, 0.3, 0.3, "square")
	elif s_name == "game_over":
		return _generate_tone(150.0, 0.8, 0.4, "sawtooth")
	elif s_name == "day_start":
		return _generate_tone(440.0, 0.3, 0.2, "sine")
	else:
		return _generate_tone(440.0, 0.1, 0.1, "sine")

func _generate_tone(frequency: float, duration: float, volume: float = 0.3, wave_type: String = "sine", fade_out: bool = true) -> AudioStreamWAV:
	var num_samples: int = int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2) # 16비트 오디오 (2 바이트)
	
	for i in range(num_samples):
		var t: float = float(i) / SAMPLE_RATE
		var value: float = 0.0
		
		if wave_type == "sine":
			value = sin(2.0 * PI * frequency * t)
		elif wave_type == "square":
			value = 1.0 if sin(2.0 * PI * frequency * t) > 0 else -1.0
		elif wave_type == "noise":
			value = randf_range(-1.0, 1.0)
		elif wave_type == "sawtooth":
			value = 2.0 * fmod(t * frequency, 1.0) - 1.0
		else:
			value = sin(2.0 * PI * frequency * t)
			
		# 페이드 아웃 및 어택
		var envelope: float = 1.0
		if fade_out:
			envelope = 1.0 - (float(i) / float(num_samples))
			
		# 어택 (앞 5%)
		var attack_samples: float = num_samples * 0.05
		if i < attack_samples:
			envelope *= (float(i) / attack_samples)
			
		# 최종 샘플 계산 (-32768 ~ 32767)
		var int_val: int = int(value * volume * 32767.0 * envelope)
		data.encode_s16(i * 2, int_val)
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav
