extends Control

## 마인크래프트 인벤토리 스타일의 캐릭터 장비 착용 프리뷰 (헬멧/방탄복/배낭/하의)
var equipment_data: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(126, 184)

func update_equipment(new_equipment: Dictionary) -> void:
	equipment_data = new_equipment.duplicate(true)
	queue_redraw()

func _get_tier_from_id(item_id: String) -> int:
	if "3레벨" in item_id:
		return 3
	if "2레벨" in item_id:
		return 2
	if "1레벨" in item_id:
		return 1
	return 1 if item_id != "" else 0

func _calc_total_armor_def() -> int:
	var total := 0
	for slot_key in ["helmet", "vest", "bottom"]:
		var eq: Dictionary = equipment_data.get(slot_key, {})
		if not eq.is_empty():
			var d := ItemDatabase.get_item_data(str(eq.get("id", "")))
			total += int(d.get("defense", eq.get("defense", 0)))
	return total

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	# 배경 (어두운 전술 격납 스탠드)
	draw_rect(rect, Color(0.06, 0.08, 0.11, 0.96), true)
	draw_rect(rect, Color(0.24, 0.34, 0.44, 0.85), false, 1.0)

	# 바닥 격자 및 스포트라이트 그림자
	var plot_h: float = maxf(40.0, size.y - 26.0)
	var px: float = maxf(3.0, floorf(minf((size.x - 16.0) / 18.0, (plot_h - 14.0) / 26.0)))
	var char_w: float = 14.0 * px
	var char_h: float = 24.0 * px
	var ox: float = floorf((size.x - char_w) * 0.5)
	var oy: float = floorf((plot_h - char_h) * 0.5) + 4.0

	# 배경 바닥 받침대
	var base_cx: float = ox + char_w * 0.5
	var base_cy: float = oy + 23.2 * px
	draw_rect(Rect2(base_cx - 6.5 * px, base_cy, 13.0 * px, 1.8 * px), Color(0.11, 0.16, 0.22, 0.9), true)
	draw_rect(Rect2(base_cx - 5.5 * px, base_cy + 0.3 * px, 11.0 * px, 1.0 * px), Color(0.16, 0.23, 0.31, 0.65), true)

	var helmet_eq: Dictionary = equipment_data.get("helmet", {})
	var vest_eq: Dictionary = equipment_data.get("vest", {})
	var bp_eq: Dictionary = equipment_data.get("backpack", {})
	var bottom_eq: Dictionary = equipment_data.get("bottom", {})

	var helmet_id := str(helmet_eq.get("id", ""))
	var vest_id := str(vest_eq.get("id", ""))
	var bp_id := str(bp_eq.get("id", ""))
	var bottom_id := str(bottom_eq.get("id", ""))

	# 1. 배낭 (캐릭터 등 뒤 좌우 돌출 실루엣)
	if not bp_eq.is_empty():
		var bp_tier := _get_tier_from_id(bp_id)
		var bp_col := Color(0.32, 0.38, 0.24)
		var bp_dark := Color(0.20, 0.24, 0.14)
		var pad_x := 1.5 * px
		var bp_top := 7.0 * px
		var bp_h := 7.0 * px
		if bp_tier == 2:
			bp_col = Color(0.24, 0.33, 0.26)
			bp_dark = Color(0.15, 0.21, 0.16)
			pad_x = 2.2 * px
			bp_top = 6.2 * px
			bp_h = 8.4 * px
		elif bp_tier >= 3:
			bp_col = Color(0.27, 0.30, 0.20)
			bp_dark = Color(0.16, 0.18, 0.11)
			pad_x = 2.8 * px
			bp_top = 5.4 * px
			bp_h = 9.8 * px
		draw_rect(Rect2(ox + 2.0 * px - pad_x, oy + bp_top, 10.0 * px + pad_x * 2.0, bp_h), bp_dark, true)
		draw_rect(Rect2(ox + 2.5 * px - pad_x, oy + bp_top + 0.5 * px, 9.0 * px + pad_x * 2.0, bp_h - 1.0 * px), bp_col, true)
		# 배낭 사이드 포켓/스트랩 디테일
		draw_rect(Rect2(ox + 1.5 * px - pad_x * 0.6, oy + bp_top + 1.5 * px, 1.0 * px, bp_h - 3.0 * px), bp_dark, true)
		draw_rect(Rect2(ox + 11.5 * px + pad_x * 0.6, oy + bp_top + 1.5 * px, 1.0 * px, bp_h - 3.0 * px), bp_dark, true)

	# 2. 팔 (기본 티셔츠/군복 팔 + 아머 견장)
	var arm_shirt := Color(0.24, 0.29, 0.33)
	var arm_skin := Color(0.84, 0.67, 0.53)
	# 왼팔 / 오른팔
	draw_rect(Rect2(ox + 1.2 * px, oy + 6.5 * px, 2.8 * px, 5.8 * px), arm_shirt, true)
	draw_rect(Rect2(ox + 10.0 * px, oy + 6.5 * px, 2.8 * px, 5.8 * px), arm_shirt, true)
	draw_rect(Rect2(ox + 1.2 * px, oy + 12.3 * px, 2.8 * px, 2.2 * px), arm_skin, true)
	draw_rect(Rect2(ox + 10.0 * px, oy + 12.3 * px, 2.8 * px, 2.2 * px), arm_skin, true)

	# 3. 다리 / 하의 & 신발
	var pants_col := Color(0.20, 0.24, 0.28)
	var boot_col := Color(0.14, 0.14, 0.16)
	var knee_col := Color(0.16, 0.19, 0.22)
	if not bottom_eq.is_empty():
		var b_tier := _get_tier_from_id(bottom_id)
		if b_tier == 1:
			pants_col = Color(0.28, 0.30, 0.24)
			boot_col = Color(0.22, 0.18, 0.14)
		elif b_tier == 2:
			pants_col = Color(0.22, 0.29, 0.22)
			boot_col = Color(0.16, 0.19, 0.16)
			knee_col = Color(0.35, 0.40, 0.33)
		else:
			pants_col = Color(0.18, 0.22, 0.28)
			boot_col = Color(0.11, 0.13, 0.17)
			knee_col = Color(0.32, 0.38, 0.48)
	# 왼다리 / 오른다리
	draw_rect(Rect2(ox + 4.1 * px, oy + 14.2 * px, 2.7 * px, 6.8 * px), pants_col, true)
	draw_rect(Rect2(ox + 7.2 * px, oy + 14.2 * px, 2.7 * px, 6.8 * px), pants_col, true)
	# 무릎 보호대 (하의 착용 시 강조)
	if not bottom_eq.is_empty():
		draw_rect(Rect2(ox + 4.3 * px, oy + 16.5 * px, 2.3 * px, 1.5 * px), knee_col, true)
		draw_rect(Rect2(ox + 7.4 * px, oy + 16.5 * px, 2.3 * px, 1.5 * px), knee_col, true)
	# 전투화
	draw_rect(Rect2(ox + 4.0 * px, oy + 21.0 * px, 2.8 * px, 2.2 * px), boot_col, true)
	draw_rect(Rect2(ox + 7.2 * px, oy + 21.0 * px, 2.8 * px, 2.2 * px), boot_col, true)
	draw_rect(Rect2(ox + 4.0 * px, oy + 22.6 * px, 2.8 * px, 0.6 * px), Color(0.08, 0.08, 0.10), true)
	draw_rect(Rect2(ox + 7.2 * px, oy + 22.6 * px, 2.8 * px, 0.6 * px), Color(0.08, 0.08, 0.10), true)

	# 4. 몸통 & 방탄복
	draw_rect(Rect2(ox + 4.0 * px, oy + 6.4 * px, 6.0 * px, 7.8 * px), Color(0.28, 0.34, 0.38), true)
	# 벨트
	draw_rect(Rect2(ox + 4.0 * px, oy + 13.2 * px, 6.0 * px, 1.0 * px), Color(0.13, 0.13, 0.15), true)
	if not vest_eq.is_empty():
		var v_tier := _get_tier_from_id(vest_id)
		var v_main := Color(0.39, 0.36, 0.25)
		var v_plate := Color(0.29, 0.27, 0.19)
		var v_pouch := Color(0.47, 0.43, 0.30)
		if v_tier == 2:
			v_main = Color(0.24, 0.35, 0.25)
			v_plate = Color(0.16, 0.25, 0.17)
			v_pouch = Color(0.32, 0.44, 0.32)
		elif v_tier >= 3:
			v_main = Color(0.24, 0.27, 0.34)
			v_plate = Color(0.15, 0.18, 0.24)
			v_pouch = Color(0.35, 0.41, 0.50)
			# 3레벨 중갑 어깨 견장 + 목 보호대
			draw_rect(Rect2(ox + 1.0 * px, oy + 6.1 * px, 3.0 * px, 2.3 * px), v_plate, true)
			draw_rect(Rect2(ox + 10.0 * px, oy + 6.1 * px, 3.0 * px, 2.3 * px), v_plate, true)
			draw_rect(Rect2(ox + 4.5 * px, oy + 5.7 * px, 5.0 * px, 1.2 * px), v_plate, true)
		draw_rect(Rect2(ox + 3.8 * px, oy + 6.5 * px, 6.4 * px, 6.9 * px), v_main, true)
		draw_rect(Rect2(ox + 4.5 * px, oy + 7.2 * px, 5.0 * px, 3.4 * px), v_plate, true)
		# 탄창 파우치 3칸
		draw_rect(Rect2(ox + 4.3 * px, oy + 10.9 * px, 1.4 * px, 1.9 * px), v_pouch, true)
		draw_rect(Rect2(ox + 6.3 * px, oy + 10.9 * px, 1.4 * px, 1.9 * px), v_pouch, true)
		draw_rect(Rect2(ox + 8.3 * px, oy + 10.9 * px, 1.4 * px, 1.9 * px), v_pouch, true)

	# 배낭 어깨끈 (배낭 착용 시 항상 표시)
	if not bp_eq.is_empty():
		draw_rect(Rect2(ox + 4.1 * px, oy + 6.4 * px, 0.8 * px, 5.0 * px), Color(0.14, 0.14, 0.12), true)
		draw_rect(Rect2(ox + 9.1 * px, oy + 6.4 * px, 0.8 * px, 5.0 * px), Color(0.14, 0.14, 0.12), true)

	# 5. 머리 & 헬멧 / 방독면
	var head_rect := Rect2(ox + 4.3 * px, oy + 1.0 * px, 5.4 * px, 5.2 * px)
	draw_rect(head_rect, Color(0.86, 0.69, 0.55), true)
	# 머리카락 (맨머리 기준)
	if helmet_eq.is_empty():
		draw_rect(Rect2(ox + 4.3 * px, oy + 0.8 * px, 5.4 * px, 1.5 * px), Color(0.18, 0.14, 0.11), true)
	# 눈
	draw_rect(Rect2(ox + 5.2 * px, oy + 3.2 * px, 1.0 * px, 1.0 * px), Color(0.14, 0.18, 0.24), true)
	draw_rect(Rect2(ox + 7.8 * px, oy + 3.2 * px, 1.0 * px, 1.0 * px), Color(0.14, 0.18, 0.24), true)

	if not helmet_eq.is_empty():
		if "방독면" in helmet_id:
			# 방독면 고글 & 쌍둥이 필터
			draw_rect(Rect2(ox + 4.2 * px, oy + 2.5 * px, 5.6 * px, 3.8 * px), Color(0.16, 0.17, 0.19), true)
			draw_rect(Rect2(ox + 4.7 * px, oy + 2.8 * px, 1.8 * px, 1.4 * px), Color(0.42, 0.78, 0.88), true)
			draw_rect(Rect2(ox + 7.5 * px, oy + 2.8 * px, 1.8 * px, 1.4 * px), Color(0.42, 0.78, 0.88), true)
			draw_rect(Rect2(ox + 6.0 * px, oy + 4.6 * px, 2.0 * px, 1.5 * px), Color(0.28, 0.30, 0.34), true)
			draw_rect(Rect2(ox + 3.8 * px, oy + 4.4 * px, 1.4 * px, 1.4 * px), Color(0.25, 0.28, 0.24), true)
			draw_rect(Rect2(ox + 8.8 * px, oy + 4.4 * px, 1.4 * px, 1.4 * px), Color(0.25, 0.28, 0.24), true)
		else:
			var h_tier := _get_tier_from_id(helmet_id)
			var h_col := Color(0.31, 0.35, 0.27)
			var h_rim := Color(0.21, 0.24, 0.18)
			if h_tier == 2:
				h_col = Color(0.23, 0.29, 0.24)
				h_rim = Color(0.14, 0.18, 0.15)
			elif h_tier >= 3:
				h_col = Color(0.20, 0.23, 0.28)
				h_rim = Color(0.12, 0.14, 0.18)
			# 헬멧 쉘
			draw_rect(Rect2(ox + 3.8 * px, oy + 0.3 * px, 6.4 * px, 2.5 * px), h_col, true)
			draw_rect(Rect2(ox + 3.6 * px, oy + 2.2 * px, 6.8 * px, 0.8 * px), h_rim, true)
			# 2레벨 NVG 마운트 & 사이드 레일
			if h_tier == 2:
				draw_rect(Rect2(ox + 6.2 * px, oy + 0.9 * px, 1.6 * px, 1.1 * px), Color(0.65, 0.68, 0.72), true)
				draw_rect(Rect2(ox + 3.5 * px, oy + 2.5 * px, 0.9 * px, 2.4 * px), h_rim, true)
				draw_rect(Rect2(ox + 9.6 * px, oy + 2.5 * px, 0.9 * px, 2.4 * px), h_rim, true)
			# 3레벨 알틴 방탄 바이저
			elif h_tier >= 3:
				draw_rect(Rect2(ox + 3.6 * px, oy + 2.6 * px, 6.8 * px, 3.3 * px), Color(0.26, 0.30, 0.36, 0.92), true)
				draw_rect(Rect2(ox + 4.4 * px, oy + 3.3 * px, 5.2 * px, 1.0 * px), Color(0.48, 0.78, 0.96, 0.85), true)

	# 6. 하단 요약 스탯 바
	var bar_rect := Rect2(2.0, size.y - 24.0, size.x - 4.0, 22.0)
	draw_rect(bar_rect, Color(0.08, 0.11, 0.15, 0.95), true)
	draw_line(Vector2(2.0, size.y - 24.0), Vector2(size.x - 2.0, size.y - 24.0), Color(0.24, 0.34, 0.44, 0.7), 1.0)

	var total_def := _calc_total_armor_def()
	var bp_str := "기본 6x3"
	if not bp_eq.is_empty():
		var d := ItemDatabase.get_item_data(bp_id)
		var g: Vector2i = d.get("backpack_grid", Vector2i(6, 5))
		bp_str = "%dx%d" % [g.x, g.y]
	var font := PixelAssetManager.get_pixel_font_micro() if PixelAssetManager else ThemeDB.fallback_font
	var summary_txt := "🛡️%d  🎒%s" % [total_def, bp_str]
	draw_string(font, Vector2(4.0, size.y - 8.0), summary_txt, HORIZONTAL_ALIGNMENT_CENTER, size.x - 8.0, 10, Color(0.75, 0.88, 0.98))
