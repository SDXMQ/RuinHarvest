# res://scenes/ui/shooting_range_window.gd
extends Control

## 은신처 사격장 (Shooting Range) 테스트 모드
## 무한 탄약, 과녁 실루엣(10m, 25m, 50m), 탄착군(Bullet Holes), 반동/집탄율/조준경 줌 테스트 지원

signal window_closed

var weapon_data: Dictionary = {}
var computed_stats: Dictionary = {}

var is_infinite_ammo: bool = true
var current_ammo: int = 30
var max_mag_size: int = 30

var shots_fired: int = 0
var hits_count: int = 0
var headshots_count: int = 0
var torsoshots_count: int = 0
var total_damage: float = 0.0

var bullet_holes: Array = [] # Array of {pos: Vector2, target_idx: int, zone: String, color: Color}
var floating_texts: Array = [] # Array of {text: String, pos: Vector2, color: Color, life: float}

var recoil_offset: Vector2 = Vector2.ZERO
var fire_cooldown: float = 0.0
var is_ads: bool = false
var muzzle_flash_timer: float = 0.0

var range_canvas: Control = null
var stats_label: Label = null
var weapon_title_label: Label = null
var ammo_label: Label = null
var infinite_ammo_chk: CheckBox = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func setup(w_data: Dictionary = {}) -> void:
	weapon_data = w_data.duplicate(true)
	if weapon_data.is_empty():
		weapon_data = WeaponPartsDatabase.create_default_weapon("M4_리시버")
	
	computed_stats = weapon_data.get("computed_stats", {})
	if computed_stats.is_empty():
		computed_stats = WeaponPartsDatabase.compute_weapon_from_dict(weapon_data).get("computed_stats", {})
	
	max_mag_size = int(computed_stats.get("magazine_size", 30))
	current_ammo = max_mag_size
	
	_refresh_header()
	_refresh_stats()

func _build_ui() -> void:
	# 배경 암전 패널
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.08, 0.07, 0.98)
	add_child(bg)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.offset_left = 24.0
	main_vbox.offset_top = 16.0
	main_vbox.offset_right = -24.0
	main_vbox.offset_bottom = -16.0
	main_vbox.add_theme_constant_override("separation", 10)
	add_child(main_vbox)
	
	# 상단 헤더 패널
	var header_panel = PanelContainer.new()
	var h_style = StyleBoxFlat.new()
	h_style.bg_color = Color(0.12, 0.16, 0.13, 0.95)
	h_style.set_corner_radius_all(6)
	h_style.border_width_bottom = 2
	h_style.border_color = Color(0.25, 0.45, 0.3)
	header_panel.add_theme_stylebox_override("panel", h_style)
	main_vbox.add_child(header_panel)
	
	var header_hbox = HBoxContainer.new()
	header_hbox.custom_minimum_size.y = 44.0
	header_panel.add_child(header_hbox)
	
	weapon_title_label = Label.new()
	weapon_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_title_label.text = "🎯 은신처 지하 사격 시험장 (Shooting Range)"
	weapon_title_label.add_theme_font_size_override("font_size", 16)
	header_hbox.add_child(weapon_title_label)
	
	infinite_ammo_chk = CheckBox.new()
	infinite_ammo_chk.text = "무한 탄약"
	infinite_ammo_chk.button_pressed = is_infinite_ammo
	infinite_ammo_chk.toggled.connect(func(val): is_infinite_ammo = val; _refresh_header())
	header_hbox.add_child(infinite_ammo_chk)
	
	var reset_holes_btn = Button.new()
	reset_holes_btn.text = "과녁 초기화"
	reset_holes_btn.pressed.connect(_reset_targets)
	header_hbox.add_child(reset_holes_btn)
	
	var close_btn = Button.new()
	close_btn.text = " 사격장 나가기 (ESC) "
	close_btn.pressed.connect(_on_close_pressed)
	header_hbox.add_child(close_btn)
	
	# 중앙 사격장 캔버스
	range_canvas = Control.new()
	range_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	range_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	range_canvas.clip_contents = true
	range_canvas.draw.connect(_on_range_canvas_draw)
	main_vbox.add_child(range_canvas)
	
	# 하단 전술 통계 & 안내 바
	var footer_panel = PanelContainer.new()
	var f_style = StyleBoxFlat.new()
	f_style.bg_color = Color(0.10, 0.13, 0.11, 0.95)
	f_style.set_corner_radius_all(6)
	footer_panel.add_theme_stylebox_override("panel", f_style)
	main_vbox.add_child(footer_panel)
	
	var footer_hbox = HBoxContainer.new()
	footer_hbox.custom_minimum_size.y = 40.0
	footer_panel.add_child(footer_hbox)
	
	ammo_label = Label.new()
	ammo_label.custom_minimum_size.x = 180.0
	ammo_label.text = "탄약: 30 / 30 (무한)"
	ammo_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	footer_hbox.add_child(ammo_label)
	
	stats_label = Label.new()
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_label.text = "사격 통계: 0발 발사 | 명중 0 (헤드 0 / 몸통 0) | 명중률 0.0% | 총 데미지: 0"
	footer_hbox.add_child(stats_label)
	
	var hint_lbl = Label.new()
	hint_lbl.text = "[좌클릭] 사격  |  [우클릭] 정조준(ADS 줌)  |  [R] 탄창 재장전"
	hint_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
	footer_hbox.add_child(hint_lbl)

func _refresh_header() -> void:
	if not weapon_title_label: return
	var w_name = weapon_data.get("name", weapon_data.get("id", "소총"))
	var rpm = computed_stats.get("rpm", 150)
	var dmg = computed_stats.get("damage", 25.0)
	var acc = computed_stats.get("accuracy", 75.0)
	var rec = computed_stats.get("recoil", 20.0)
	var zm = computed_stats.get("zoom", 1.0)
	weapon_title_label.text = "🎯 사격장 | [%s] 데미지:%.1f | 연사:%d RPM | 명중률:%d%% | 반동:%.1f | 줌:%.1fx" % [w_name, dmg, rpm, int(acc), rec, zm]
	
	if ammo_label:
		if is_infinite_ammo:
			ammo_label.text = "탄약: %d / %d (무한)" % [current_ammo, max_mag_size]
		else:
			ammo_label.text = "탄약: %d / %d" % [current_ammo, max_mag_size]

func _refresh_stats() -> void:
	if not stats_label: return
	var acc_pct = (float(hits_count) / float(max(1, shots_fired))) * 100.0
	stats_label.text = "발사: %d발 | 명중: %d (헤드: %d, 몸통: %d) | 명중률: %.1f%% | 누적 데미지: %.0f" % [
		shots_fired, hits_count, headshots_count, torsoshots_count, acc_pct, total_damage
	]

func _reset_targets() -> void:
	bullet_holes.clear()
	floating_texts.clear()
	shots_fired = 0
	hits_count = 0
	headshots_count = 0
	torsoshots_count = 0
	total_damage = 0.0
	_refresh_stats()
	if range_canvas: range_canvas.queue_redraw()
	if SoundManager: SoundManager.play("menu_select")

func _process(delta: float) -> void:
	recoil_offset = recoil_offset.lerp(Vector2.ZERO, delta * 12.0)
	if fire_cooldown > 0.0:
		fire_cooldown -= delta
	if muzzle_flash_timer > 0.0:
		muzzle_flash_timer -= delta
		
	# 연사 총기(RPM >= 300)는 좌클릭 유지 시 자동 사격
	if range_canvas and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and fire_cooldown <= 0.0:
		var mouse_p = range_canvas.get_local_mouse_position()
		if Rect2(Vector2.ZERO, range_canvas.size).has_point(mouse_p):
			var rpm = computed_stats.get("rpm", 150)
			if rpm >= 300:
				_try_fire()
			
	# 플로팅 텍스트 업데이트
	if floating_texts.size() > 0:
		for i in range(floating_texts.size() - 1, -1, -1):
			floating_texts[i]["life"] -= delta
			floating_texts[i]["pos"].y -= delta * 32.0
			if floating_texts[i]["life"] <= 0.0:
				floating_texts.remove_at(i)
				
	if range_canvas:
		range_canvas.queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed:
		if range_canvas:
			var mouse_p = range_canvas.get_local_mouse_position()
			if not Rect2(Vector2.ZERO, range_canvas.size).has_point(mouse_p):
				return
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_fire()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			is_ads = not is_ads
			if SoundManager: SoundManager.play("menu_select")
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			_reload_weapon()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			_on_close_pressed()
			get_viewport().set_input_as_handled()

func _reload_weapon() -> void:
	current_ammo = max_mag_size
	if SoundManager: SoundManager.play("menu_select")
	_refresh_header()
	_add_floating_text("RELOADED", get_local_mouse_position(), Color(0.4, 0.9, 1.0))

func _try_fire() -> void:
	if fire_cooldown > 0.0: return
	if current_ammo <= 0 and not is_infinite_ammo:
		if SoundManager: SoundManager.play("hit_melee")
		_add_floating_text("NO AMMO (R)", get_local_mouse_position(), Color(1.0, 0.3, 0.3))
		return
		
	if not is_infinite_ammo:
		current_ammo -= 1
	_refresh_header()
	
	shots_fired += 1
	var rpm = computed_stats.get("rpm", 150)
	fire_cooldown = 60.0 / float(max(45, rpm))
	muzzle_flash_timer = 0.06
	
	# 반동 적용
	var rec_val = float(computed_stats.get("recoil", 20.0))
	var kick_y = -randf_range(rec_val * 0.35, rec_val * 0.65)
	var kick_x = randf_range(-rec_val * 0.18, rec_val * 0.18)
	if is_ads:
		kick_y *= 0.5
		kick_x *= 0.5
	recoil_offset += Vector2(kick_x, kick_y)
	
	# 집탄율/탄착군 분산도 계산
	var acc = float(computed_stats.get("accuracy", 75.0))
	var spread_max = max(2.0, (100.0 - acc) * 0.5)
	if is_ads:
		spread_max *= 0.45
		
	var mouse_p = range_canvas.get_local_mouse_position() if range_canvas else Vector2.ZERO
	var aim_center = mouse_p + recoil_offset
	var pellets = int(computed_stats.get("pellets", 1))
	var base_dmg = float(computed_stats.get("damage", 24.0))
	
	for p in range(pellets):
		var spread_vec = Vector2(randf_range(-spread_max, spread_max), randf_range(-spread_max, spread_max))
		var impact_pos = aim_center + spread_vec
		_process_bullet_impact(impact_pos, base_dmg)
		
	if SoundManager: SoundManager.play("hit_ranged")
	_refresh_stats()

func _process_bullet_impact(impact_pos: Vector2, base_dmg: float) -> void:
	if not range_canvas: return
	var w = range_canvas.size.x
	var h = range_canvas.size.y
	
	# 3개 과녁 좌표 정의 (10m 좌측, 25m 중앙, 50m 우측)
	var targets = _get_target_defs(w, h)
	var hit_zone = "MISS"
	var final_dmg = 0.0
	var hit_target_idx = -1
	
	for idx in range(targets.size()):
		var t = targets[idx]
		var t_pos = t["pos"]
		var t_scale = t["scale"]
		
		# 1) 헤드 판정 (원형)
		var head_center = t_pos + Vector2(0, -70.0 * t_scale)
		var head_radius = 24.0 * t_scale
		if impact_pos.distance_to(head_center) <= head_radius:
			hit_zone = "HEAD"
			final_dmg = base_dmg * 2.2 # 헤드샷 2.2배 치명타
			hit_target_idx = idx
			headshots_count += 1
			hits_count += 1
			break
			
		# 2) 가슴 판정 (원형 10점 링)
		var chest_center = t_pos + Vector2(0, -18.0 * t_scale)
		var chest_radius = 38.0 * t_scale
		if impact_pos.distance_to(chest_center) <= chest_radius:
			hit_zone = "CHEST"
			final_dmg = base_dmg * 1.15
			hit_target_idx = idx
			torsoshots_count += 1
			hits_count += 1
			break
			
		# 3) 몸통/복부 사각 판정
		var torso_rect = Rect2(t_pos + Vector2(-36.0 * t_scale, -50.0 * t_scale), Vector2(72.0 * t_scale, 110.0 * t_scale))
		if torso_rect.has_point(impact_pos):
			hit_zone = "BODY"
			final_dmg = base_dmg * 0.85
			hit_target_idx = idx
			torsoshots_count += 1
			hits_count += 1
			break
			
	var hole_col = Color(0.12, 0.12, 0.12)
	if hit_zone == "HEAD":
		hole_col = Color(1.0, 0.2, 0.2)
		_add_floating_text("HEADSHOT! %.0f" % final_dmg, impact_pos, Color(1.0, 0.2, 0.2))
	elif hit_zone == "CHEST":
		hole_col = Color(1.0, 0.8, 0.2)
		_add_floating_text("CHEST %.0f" % final_dmg, impact_pos, Color(1.0, 0.8, 0.2))
	elif hit_zone == "BODY":
		hole_col = Color(0.4, 0.9, 0.4)
		_add_floating_text("HIT %.0f" % final_dmg, impact_pos, Color(0.4, 0.9, 0.4))
	else:
		_add_floating_text("MISS", impact_pos, Color(0.5, 0.5, 0.5))
		
	total_damage += final_dmg
	bullet_holes.append({
		"pos": impact_pos,
		"target_idx": hit_target_idx,
		"zone": hit_zone,
		"col": hole_col
	})
	if bullet_holes.size() > 150:
		bullet_holes.remove_at(0)

func _add_floating_text(txt: String, pos: Vector2, col: Color) -> void:
	floating_texts.append({
		"text": txt,
		"pos": pos,
		"color": col,
		"life": 0.65
	})
	if floating_texts.size() > 40:
		floating_texts.remove_at(0)

func _get_target_defs(w: float, h: float) -> Array:
	return [
		{"name": "10m (근거리)", "pos": Vector2(w * 0.22, h * 0.52), "scale": 1.25, "dist": 10},
		{"name": "25m (중거리)", "pos": Vector2(w * 0.50, h * 0.50), "scale": 0.85, "dist": 25},
		{"name": "50m (원거리)", "pos": Vector2(w * 0.78, h * 0.48), "scale": 0.52, "dist": 50}
	]

func _on_range_canvas_draw() -> void:
	var w = range_canvas.size.x
	var h = range_canvas.size.y
	
	# 1. 사격 레인 배경 (벽돌 및 바닥 원근선)
	range_canvas.draw_rect(Rect2(0, 0, w, h), Color(0.08, 0.10, 0.08))
	range_canvas.draw_line(Vector2(0, h * 0.72), Vector2(w, h * 0.72), Color(0.2, 0.26, 0.2), 2.0)
	
	# 바닥 원근 레인 라인
	var lane_xs = [w * 0.22, w * 0.50, w * 0.78]
	for lx in lane_xs:
		range_canvas.draw_line(Vector2(lx, h * 0.72), Vector2(lx, h), Color(0.18, 0.24, 0.18, 0.6), 1.5)
		
	# 2. 3개 과녁 실루엣 렌더링
	var targets = _get_target_defs(w, h)
	for t in targets:
		var tp = t["pos"]
		var sc = t["scale"]
		
		# 과녁 거치대 기둥
		range_canvas.draw_line(tp + Vector2(0, 60.0 * sc), Vector2(tp.x, h * 0.72), Color(0.3, 0.35, 0.3), 3.0 * sc)
		
		# 과녁 배경 종이 판자
		var board_rect = Rect2(tp + Vector2(-46.0 * sc, -100.0 * sc), Vector2(92.0 * sc, 160.0 * sc))
		range_canvas.draw_rect(board_rect, Color(0.85, 0.82, 0.72))
		range_canvas.draw_rect(board_rect, Color(0.25, 0.25, 0.25), false, 1.5)
		
		# 실루엣 몸통 (어두운 회색 실루엣)
		var torso_r = Rect2(tp + Vector2(-36.0 * sc, -50.0 * sc), Vector2(72.0 * sc, 105.0 * sc))
		range_canvas.draw_rect(torso_r, Color(0.22, 0.25, 0.28))
		
		# 실루엣 머리 (원형)
		var head_c = tp + Vector2(0, -70.0 * sc)
		var head_r = 24.0 * sc
		range_canvas.draw_circle(head_c, head_r, Color(0.22, 0.25, 0.28))
		range_canvas.draw_circle(head_c, head_r * 0.5, Color(0.85, 0.2, 0.2)) # 헤드 중앙 과녁 불스아이
		
		# 가슴 점수 링 (10점, 9점, 8점 원)
		var chest_c = tp + Vector2(0, -18.0 * sc)
		range_canvas.draw_arc(chest_c, 38.0 * sc, 0, TAU, 24, Color(0.8, 0.8, 0.8, 0.5), 1.0)
		range_canvas.draw_arc(chest_c, 24.0 * sc, 0, TAU, 24, Color(0.8, 0.8, 0.8, 0.7), 1.2)
		range_canvas.draw_circle(chest_c, 10.0 * sc, Color(0.9, 0.75, 0.2)) # 10점 중앙 링
		
		# 거리 라벨
		var dist_text = "%s" % t["name"]
		range_canvas.draw_string(ThemeDB.fallback_font, tp + Vector2(-40.0 * sc, 80.0 * sc), dist_text, HORIZONTAL_ALIGNMENT_CENTER, 80.0 * sc, int(11 * sc + 3), Color(0.9, 0.9, 0.8))

	# 3. 누적 탄흔(Bullet Holes) 렌더링
	for h_data in bullet_holes:
		var hp = h_data["pos"]
		var h_col = h_data["col"]
		range_canvas.draw_circle(hp, 3.2, h_col)
		range_canvas.draw_circle(hp, 1.2, Color.BLACK)

	# 4. 머즐 플래시 효과
	if muzzle_flash_timer > 0.0:
		range_canvas.draw_rect(Rect2(0, 0, w, h), Color(1.0, 0.95, 0.7, 0.12))

	# 5. 크로스헤어 / 조준선 렌더링
	var mouse_p = range_canvas.get_local_mouse_position()
	var crosshair_center = mouse_p + recoil_offset
	
	if is_ads:
		# 정조준(ADS 줌) 모드: 확대 조준선 및 정밀 십자선
		var zoom_val = computed_stats.get("zoom", 1.0)
		var reticle_r = 28.0
		range_canvas.draw_circle(crosshair_center, reticle_r, Color(0, 0, 0, 0.25))
		range_canvas.draw_arc(crosshair_center, reticle_r, 0, TAU, 32, Color(0.2, 1.0, 0.4, 0.85), 1.8)
		range_canvas.draw_line(crosshair_center + Vector2(-reticle_r - 12, 0), crosshair_center + Vector2(-6, 0), Color(0.2, 1.0, 0.4), 1.5)
		range_canvas.draw_line(crosshair_center + Vector2(6, 0), crosshair_center + Vector2(reticle_r + 12, 0), Color(0.2, 1.0, 0.4), 1.5)
		range_canvas.draw_line(crosshair_center + Vector2(0, -reticle_r - 12), crosshair_center + Vector2(0, -6), Color(0.2, 1.0, 0.4), 1.5)
		range_canvas.draw_line(crosshair_center + Vector2(0, 6), crosshair_center + Vector2(0, reticle_r + 12), Color(0.2, 1.0, 0.4), 1.5)
		range_canvas.draw_circle(crosshair_center, 2.5, Color(1.0, 0.2, 0.2)) # 적색 도트
		range_canvas.draw_string(ThemeDB.fallback_font, crosshair_center + Vector2(16, -16), "ADS [%.1fx]" % zoom_val, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.2, 1.0, 0.4))
	else:
		# 비조준 지향사격 모드: 동적 탄착군 분산 원 + 4방향 틱
		var acc = float(computed_stats.get("accuracy", 75.0))
		var spread_r = max(6.0, (100.0 - acc) * 0.45)
		range_canvas.draw_arc(crosshair_center, spread_r, 0, TAU, 24, Color(0.85, 0.9, 0.85, 0.4), 1.0)
		var gap = spread_r + 2.0
		var len_tick = 8.0
		range_canvas.draw_line(crosshair_center + Vector2(-gap - len_tick, 0), crosshair_center + Vector2(-gap, 0), Color.WHITE, 1.5)
		range_canvas.draw_line(crosshair_center + Vector2(gap, 0), crosshair_center + Vector2(gap + len_tick, 0), Color.WHITE, 1.5)
		range_canvas.draw_line(crosshair_center + Vector2(0, -gap - len_tick), crosshair_center + Vector2(0, -gap), Color.WHITE, 1.5)
		range_canvas.draw_line(crosshair_center + Vector2(0, gap), crosshair_center + Vector2(0, gap + len_tick), Color.WHITE, 1.5)
		range_canvas.draw_circle(crosshair_center, 2.0, Color.WHITE)

	# 6. 플로팅 데미지 텍스트 렌더링
	for ft in floating_texts:
		var alpha = clamp(ft["life"] / 0.65, 0.0, 1.0)
		var f_col = Color(ft["color"].r, ft["color"].g, ft["color"].b, alpha)
		range_canvas.draw_string(ThemeDB.fallback_font, ft["pos"] + Vector2(-20, -8), ft["text"], HORIZONTAL_ALIGNMENT_CENTER, 80, 12, f_col)

func _on_close_pressed() -> void:
	queue_free()
	window_closed.emit()
