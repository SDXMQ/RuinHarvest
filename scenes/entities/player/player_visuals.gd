extends Node2D
class_name PlayerVisuals

var hit_flash_tween: Tween
var floating_texts: Array = []
@onready var player = get_parent()

func _ready() -> void:
	if EventBus.has_signal("player_damaged"):
		EventBus.player_damaged.connect(_on_player_damaged)

func show_floating_text(text: String, color: Color = Color(1.0, 0.9, 0.4), duration: float = 0.8) -> void:
	# 동일 텍스트가 최근에 떠있다면 타이머 갱신
	for ft in floating_texts:
		if ft["text"] == text:
			ft["elapsed"] = 0.0
			ft["duration"] = duration
			ft["color"] = color
			return
	floating_texts.append({
		"text": text,
		"color": color,
		"elapsed": 0.0,
		"duration": max(0.2, duration)
	})
	queue_redraw()

func _process(delta: float) -> void:
	if floating_texts.size() > 0:
		for i in range(floating_texts.size() - 1, -1, -1):
			floating_texts[i]["elapsed"] += delta
			if floating_texts[i]["elapsed"] >= floating_texts[i]["duration"]:
				floating_texts.remove_at(i)
	queue_redraw()

func _on_player_damaged(_amount: float, _source: String) -> void:
	if hit_flash_tween: hit_flash_tween.kill()
	hit_flash_tween = create_tween()
	if material:
		material.set_shader_parameter("flash_color", Color(1, 0, 0, 1))
		material.set_shader_parameter("flash_modifier", 1.0)
		hit_flash_tween.tween_property(material, "shader_parameter/flash_modifier", 0.0, 0.2)
	if player and player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").request_shake(8.0, 0.3)

func _draw() -> void:
	var bob_y = 0.0
	var bob_rot = 0.0
	var recoil_offset = 0.0
	var muzzle_flash_timer = 0.0
	var vault_timer = 0.0
	var equipped_weapon_data: Dictionary = {}
	var active_slot: String = "primary1"
	var equip_dict: Dictionary = {}
	var nvg_on: bool = false
	
	if player.has_node("PlayerCamera"):
		bob_y = sin(player.get_node("PlayerCamera").walk_bob * 2.0) * 2.0
		bob_rot = sin(player.get_node("PlayerCamera").walk_bob) * 0.1
	if player.has_node("WeaponHandler"):
		var wh = player.get_node("WeaponHandler")
		recoil_offset = wh.recoil_offset
		equipped_weapon_data = wh.equipped_weapon_data
		active_slot = wh.active_weapon_slot
		equip_dict = wh.equipment
	if player.has_node("PlayerLighting"):
		var pl = player.get_node("PlayerLighting")
		muzzle_flash_timer = pl.muzzle_flash_timer
		nvg_on = pl.nvg_enabled
	if player.has_node("InteractionDetector"):
		vault_timer = player.get_node("InteractionDetector").vault_timer
		
	position = Vector2(0, bob_y)
	rotation = bob_rot
	
	var skin_color = Color(0.9, 0.8, 0.7)
	
	# 1. 배낭 레이어 (Backpack Layer)
	var bp_id = equip_dict.get("backpack", {}).get("id", "")
	if bp_id != "":
		var bp_h = 16.0
		var bp_w = 7.0
		var bp_col = Color(0.28, 0.32, 0.24)
		if bp_id.contains("대형") or bp_id.contains("3"):
			bp_h = 22.0; bp_w = 10.0; bp_col = Color(0.22, 0.28, 0.18)
		elif bp_id.contains("전술") or bp_id.contains("2"):
			bp_h = 19.0; bp_w = 8.5; bp_col = Color(0.38, 0.34, 0.24)
		draw_rect(Rect2(Vector2(-10.0 - bp_w, -bp_h * 0.5 - 1.0), Vector2(bp_w + 2.0, bp_h + 2.0)), Color(0.08, 0.08, 0.08))
		draw_rect(Rect2(Vector2(-9.5 - bp_w, -bp_h * 0.5), Vector2(bp_w, bp_h)), bp_col)
		draw_rect(Rect2(Vector2(-8.5 - bp_w, -bp_h * 0.3), Vector2(bp_w * 0.6, bp_h * 0.6)), bp_col.darkened(0.2))

	# 2. 방탄조끼 및 상의 레이어 (Vest / Torso Layer)
	var vest_id = equip_dict.get("vest", {}).get("id", "")
	var vest_base_col = Color(0.22, 0.26, 0.30) # 기본 자켓
	var pouch_col = Color(0.16, 0.20, 0.22)
	var has_heavy_pads = false
	if vest_id.contains("6B43") or vest_id.contains("중방탄"):
		vest_base_col = Color(0.25, 0.32, 0.22)
		pouch_col = Color(0.18, 0.24, 0.15)
		has_heavy_pads = true
	elif vest_id.contains("2레벨") or vest_id.contains("전술"):
		vest_base_col = Color(0.45, 0.40, 0.28)
		pouch_col = Color(0.35, 0.30, 0.20)
	elif vest_id.contains("1레벨") or vest_id.contains("경찰"):
		vest_base_col = Color(0.16, 0.22, 0.36)
		pouch_col = Color(0.12, 0.16, 0.28)

	var vest_points = PackedVector2Array([
		Vector2(-10, -12), Vector2(-10, 12),
		Vector2(2, 14), Vector2(12, 8),
		Vector2(12, -8), Vector2(2, -14)
	])
	var vest_colors = PackedColorArray()
	var vest_outline = PackedColorArray()
	var vest_outline_pts = PackedVector2Array()
	for p in vest_points:
		vest_colors.append(vest_base_col)
		vest_outline.append(Color(0.08, 0.08, 0.08))
		vest_outline_pts.append(p * 1.15)
		
	draw_polygon(vest_outline_pts, vest_outline)
	draw_polygon(vest_points, vest_colors)
	
	if vest_id != "":
		# 전술 탄창 파우치 및 플레이트 디테일
		draw_rect(Rect2(Vector2(2, 3), Vector2(6, 4)), pouch_col)
		draw_rect(Rect2(Vector2(2, -7), Vector2(6, 4)), pouch_col)
	if has_heavy_pads:
		draw_circle(Vector2(0, -13), 4.5, vest_base_col.lightened(0.08))
		draw_circle(Vector2(0, 13), 4.5, vest_base_col.lightened(0.08))

	# 3. 팔 & 모듈형 무기/부착물 레이어 (Arms & Modular Weapon Layer)
	var weapon_recoil_pos = Vector2(-recoil_offset, 0)
	var w_id = equipped_weapon_data.get("id", "")
	var w_type = equipped_weapon_data.get("type", "")
	var attachments: Dictionary = equipped_weapon_data.get("parts", equipped_weapon_data.get("attachments", {}))
	var sleeve_col = vest_base_col.lightened(0.05)

	if equipped_weapon_data.is_empty():
		# 맨손 파지
		draw_line(Vector2(0, 10), Vector2(10, 6), sleeve_col, 4.5)
		draw_circle(Vector2(10, 6), 3.2, skin_color)
		draw_line(Vector2(0, -10), Vector2(10, -6), sleeve_col, 4.5)
		draw_circle(Vector2(10, -6), 3.2, skin_color)
	elif active_slot == "throwable" or w_type == "throwable" or w_id.contains("수류탄"):
		# 수류탄 투척 자세
		var r_hand = Vector2(11, 7) + weapon_recoil_pos
		draw_line(Vector2(0, 10), r_hand, sleeve_col, 4.5)
		draw_circle(r_hand, 3.2, skin_color)
		draw_circle(r_hand + Vector2(3, -1), 3.5, Color(0.22, 0.35, 0.20))
		draw_line(Vector2(0, -10), Vector2(11, -5), sleeve_col, 4.5)
		draw_circle(Vector2(11, -5), 3.2, skin_color)
	elif w_type == "melee" or w_id.contains("검") or w_id.contains("도끼") or w_id.contains("나이프"):
		# 근접 무기 파지
		var r_hand = Vector2(12, 6) + weapon_recoil_pos
		draw_line(Vector2(0, 10), r_hand, sleeve_col, 4.5)
		draw_circle(r_hand, 3.2, skin_color)
		draw_line(r_hand, r_hand + Vector2(12, -8), Color(0.75, 0.80, 0.85), 2.5)
		if w_id.contains("도끼"):
			draw_rect(Rect2(r_hand + Vector2(8, -11), Vector2(5, 7)), Color(0.85, 0.2, 0.15))
		draw_line(Vector2(0, -10), Vector2(10, -6), sleeve_col, 4.5)
		draw_circle(Vector2(10, -6), 3.2, skin_color)
	else:
		# 총기 파지 (권총 vs 소총/저격총 + 장착 파츠 실시간 렌더링)
		var is_pistol = w_id.contains("M9") or w_id.contains("권총") or active_slot == "sidearm"
		var is_sniper = w_id.contains("AWM") or w_id.contains("SV-98") or w_id.contains("저격")
		var right_hand = Vector2(12, 5) + weapon_recoil_pos
		var left_hand = (Vector2(14, 2) if is_pistol else Vector2(19, 0)) + weapon_recoil_pos
		
		draw_line(Vector2(0, 10), right_hand, sleeve_col, 5.0)
		draw_circle(right_hand, 3.3, skin_color)
		draw_line(Vector2(2, -10), left_hand, sleeve_col, 5.0)
		draw_circle(left_hand, 3.3, skin_color)
		
		# 개머리판 (Stock)
		if not is_pistol or attachments.get("stock", "") != "":
			draw_rect(Rect2(right_hand + Vector2(-6, -2.5), Vector2(6, 3.5)), Color(0.22, 0.18, 0.14))
			
		# 리시버 & 총열 (Receiver & Dynamic Barrel Length)
		var barrel_id = String(attachments.get("barrel", ""))
		var barrel_len = 10.0 if is_pistol else (22.0 if is_sniper else 16.0)
		var is_long_barrel = barrel_id.contains("롱") or barrel_id.contains("장총열") or barrel_id.contains("정밀")
		var is_short_barrel = barrel_id.contains("짧은") or barrel_id.contains("단축")
		if is_long_barrel:
			barrel_len += 6.0
		elif is_short_barrel:
			barrel_len = max(8.0, barrel_len - 4.0)
		var gun_col = Color(0.18, 0.20, 0.22) if not is_sniper else Color(0.28, 0.34, 0.24)
		var receiver_len = max(7.0, barrel_len * 0.58)
		draw_rect(Rect2(right_hand + Vector2(-1, -3), Vector2(receiver_len, 4.5)), gun_col)
		draw_rect(Rect2(right_hand + Vector2(2, -2.2), Vector2(barrel_len, 2.8)), Color(0.12, 0.12, 0.14))
		if is_long_barrel:
			# 장총열 방열 핸드가드 및 강화 총신 디테일
			draw_rect(Rect2(right_hand + Vector2(receiver_len - 1.0, -2.6), Vector2(5.5, 3.6)), gun_col.darkened(0.18))
			draw_line(right_hand + Vector2(2.0 + barrel_len - 3.0, -2.2), right_hand + Vector2(2.0 + barrel_len - 3.0, 0.6), Color(0.32, 0.35, 0.38), 1.0)
		
		# 하단 전방 손잡이 (Underbarrel Foregrip)
		var grip_id = String(attachments.get("grip", ""))
		if not is_pistol and grip_id != "":
			draw_rect(Rect2(right_hand + Vector2(8.5, 1.0), Vector2(2.4, 4.8)), Color(0.14, 0.14, 0.16))
			
		# 탄창 (Magazine)
		var mag_id = String(attachments.get("magazine", ""))
		if not is_pistol:
			var mag_w = 5.0 if mag_id.contains("대용량") or mag_id.contains("드럼") else 3.0
			var mag_h = 6.5 if mag_id.contains("대용량") or mag_id.contains("드럼") else 4.5
			draw_rect(Rect2(right_hand + Vector2(4.2, 1.0), Vector2(mag_w, mag_h)), Color(0.25, 0.22, 0.18))
			
		# 조준경 (Optic: 8배율 스코프 / 4배율 ACOG / 레드닷 사이트 구분 렌더링)
		var optic_id = String(attachments.get("optic", ""))
		if optic_id != "" or is_sniper:
			if optic_id.contains("8배율") or optic_id.contains("스나이퍼") or (optic_id == "" and is_sniper):
				var scope_len = 11.5
				draw_rect(Rect2(right_hand + Vector2(1.5, -3.4), Vector2(1.5, 1.2)), Color(0.12, 0.12, 0.14))
				draw_rect(Rect2(right_hand + Vector2(7.0, -3.4), Vector2(1.5, 1.2)), Color(0.12, 0.12, 0.14))
				draw_rect(Rect2(right_hand + Vector2(0.0, -5.2), Vector2(scope_len, 2.2)), Color(0.07, 0.08, 0.10))
				draw_rect(Rect2(right_hand + Vector2(scope_len - 2.2, -5.8), Vector2(2.6, 3.4)), Color(0.09, 0.10, 0.13))
				draw_circle(right_hand + Vector2(scope_len + 0.4, -4.1), 1.4, Color(0.25, 0.85, 0.98, 0.9))
			elif optic_id.contains("4배율") or optic_id.contains("ACOG") or optic_id.contains("배율"):
				var acog_len = 7.5
				draw_rect(Rect2(right_hand + Vector2(1.0, -5.0), Vector2(acog_len, 2.6)), Color(0.10, 0.11, 0.14))
				draw_line(right_hand + Vector2(2.0, -5.2), right_hand + Vector2(6.5, -5.2), Color(0.95, 0.35, 0.15, 0.9), 1.0)
				draw_circle(right_hand + Vector2(1.0 + acog_len, -3.7), 1.2, Color(0.2, 0.8, 0.9, 0.85))
			else:
				draw_rect(Rect2(right_hand + Vector2(2.0, -4.8), Vector2(4.2, 2.2)), Color(0.10, 0.10, 0.12))
				draw_circle(right_hand + Vector2(4.1, -3.8), 1.0, Color(1.0, 0.2, 0.2, 0.9))
			
		# 소음기 / 총구 파츠 (Muzzle: 검은색 원통형 소음기 vs 총구 보정기 연장 렌더링)
		var muzzle_id = String(attachments.get("muzzle", ""))
		var muzzle_tip_x = 2.0 + barrel_len
		if muzzle_id != "":
			if muzzle_id.contains("소음기"):
				var sup_len = 8.5
				draw_rect(Rect2(right_hand + Vector2(muzzle_tip_x, -2.9), Vector2(sup_len, 4.2)), Color(0.06, 0.07, 0.08))
				draw_rect(Rect2(right_hand + Vector2(muzzle_tip_x + 1.5, -2.9), Vector2(1.0, 4.2)), Color(0.16, 0.17, 0.20))
				draw_rect(Rect2(right_hand + Vector2(muzzle_tip_x + 5.5, -2.9), Vector2(1.0, 4.2)), Color(0.16, 0.17, 0.20))
				muzzle_tip_x += sup_len
			else:
				var comp_len = 3.8
				draw_rect(Rect2(right_hand + Vector2(muzzle_tip_x, -2.4), Vector2(comp_len, 3.2)), Color(0.20, 0.22, 0.25))
				muzzle_tip_x += comp_len
			
		# 총구 화염 (Muzzle Flash)
		if muzzle_flash_timer > 0.0:
			var flash_tip = right_hand + Vector2(muzzle_tip_x, -1)
			var flash_poly = PackedVector2Array([
				flash_tip + Vector2(0, -3), flash_tip + Vector2(8, 0),
				flash_tip + Vector2(0, 3), flash_tip + Vector2(12, 0)
			])
			draw_polygon(flash_poly, PackedColorArray([
				Color(1.0, 0.9, 0.3, 0.9), Color(1.0, 0.7, 0.1, 0.8), 
				Color(1.0, 0.9, 0.3, 0.9), Color(1.0, 0.5, 0.1, 0.8)
			]))
			
		# 레이저 조준기 (Laser Sight)
		var stats = equipped_weapon_data.get("computed_stats", {})
		if stats.get("laser_sight", false):
			var laser_start = right_hand + Vector2(muzzle_tip_x, -1)
			var laser_end = laser_start + Vector2(350, 0)
			draw_line(laser_start, laser_end, Color(1.0, 0.15, 0.15, 0.65), 1.2)
			draw_circle(laser_end, 2.5, Color(1.0, 0.25, 0.25, 0.9))

	# 4. 머리 & 헬멧/야간투시경 레이어 (Head & Helmet/NVG Layer)
	var head_radius = 8.0
	draw_circle(Vector2(2, 0), head_radius + 1.5, Color.BLACK)
	draw_circle(Vector2(2, 0), head_radius, skin_color)
	
	var helmet_id = equip_dict.get("helmet", {}).get("id", "")
	if helmet_id == "":
		var hat_pts = PackedVector2Array([Vector2(1, -7), Vector2(1, 7), Vector2(11, 5), Vector2(11, -5)])
		draw_colored_polygon(hat_pts, Color(0.16, 0.16, 0.18))
	elif helmet_id.contains("알틴") or helmet_id.contains("3"):
		draw_circle(Vector2(2, 0), head_radius + 1.2, Color(0.20, 0.26, 0.18))
		# 알틴 전면 장갑 바이저 및 슬릿
		draw_rect(Rect2(Vector2(5, -6.5), Vector2(5.5, 13.0)), Color(0.14, 0.18, 0.14))
		draw_line(Vector2(9.2, -4.0), Vector2(9.2, 4.0), Color(0.75, 0.85, 0.75), 1.2)
	elif helmet_id.contains("2레벨") or helmet_id.contains("군용"):
		draw_circle(Vector2(2, 0), head_radius + 0.8, Color(0.24, 0.30, 0.22))
		draw_rect(Rect2(Vector2(6, -6), Vector2(3, 12)), Color(0.15, 0.18, 0.14))
	else:
		draw_circle(Vector2(2, 0), head_radius + 0.8, Color(0.18, 0.20, 0.26))
		draw_rect(Rect2(Vector2(6, -5.5), Vector2(3.5, 11.0)), Color(0.1, 0.25, 0.35, 0.85))
		
	if nvg_on:
		draw_circle(Vector2(10.5, -2.8), 2.0, Color(0.2, 1.0, 0.35))
		draw_circle(Vector2(10.5, 2.8), 2.0, Color(0.2, 1.0, 0.35))

	if vault_timer > 0.0:
		var ratio = clamp(vault_timer / 1.0, 0.0, 1.0)
		var bar_w = 36.0; var bar_h = 5.0
		var bar_pos = Vector2(-bar_w / 2.0, -26.0)
		draw_rect(Rect2(bar_pos + Vector2(-1, -1), Vector2(bar_w + 2, bar_h + 2)), Color(0, 0, 0, 0.8))
		var fill_color = Color(1.0, 0.8, 0.2).lerp(Color(0.2, 0.9, 0.3), ratio)
		draw_rect(Rect2(bar_pos, Vector2(bar_w * ratio, bar_h)), fill_color)

	# 5. 월드 플로팅 텍스트 및 전술 상태 팝업 (0.8초간 상승하며 페이드아웃, 플레이어 회전에 무관하게 정방향 표시)
	if floating_texts.size() > 0:
		var counter_rot = -(player.rotation if player else 0.0) - rotation
		draw_set_transform(Vector2(0, -bob_y), counter_rot, Vector2.ONE)
		var font = ThemeDB.fallback_font
		for idx in range(floating_texts.size()):
			var ft = floating_texts[idx]
			var t = clamp(float(ft["elapsed"]) / float(ft["duration"]), 0.0, 1.0)
			var alpha = clamp(1.0 - pow(t, 1.6), 0.0, 1.0)
			var y_off = -30.0 - t * 18.0 - idx * 14.0
			var txt: String = String(ft["text"])
			var col: Color = ft["color"]
			col.a = alpha
			var shadow_col = Color(0.0, 0.0, 0.0, 0.85 * alpha)
			draw_string(font, Vector2(-60.0 + 1.0, y_off + 1.0), txt, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 11, shadow_col)
			draw_string(font, Vector2(-60.0, y_off), txt, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 11, col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
