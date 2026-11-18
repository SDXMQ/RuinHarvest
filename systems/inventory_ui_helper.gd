# res://systems/inventory_ui_helper.gd
class_name InventoryUIHelper
extends RefCounted

## 타르코프식 2D 인벤토리 및 슬롯 상호작용 공통 UI 헬퍼
## 2D 그리드 셀 렌더링, 고스트 프리뷰, 슬롯 호환성 검사 및 스타일박스 하이라이트 공통 처리

const CELL_SIZE: float = 44.0

# 캐시된 StyleBoxFlat (마우스 이동 시 반복 생성 방지)
static var _sb_hover_compat: StyleBoxFlat = null
static var _sb_hover_incompat: StyleBoxFlat = null
static var _sb_guide_compat: StyleBoxFlat = null
static var _sb_guide_default: StyleBoxFlat = null

# StyleBoxTexture / StyleBoxFlat 겸용 안전 색상 오버라이드 헬퍼
static func apply_dynamic_tint(ctrl: Control, style_name: String, tint: Color) -> void:
	if not is_instance_valid(ctrl):
		return
	var base_sb: StyleBox = ctrl.get_theme_stylebox(style_name)
	var dup_sb: StyleBox = base_sb.duplicate() if base_sb else StyleBoxFlat.new()
	if dup_sb is StyleBoxTexture:
		dup_sb.modulate_color = tint
	elif dup_sb is StyleBoxFlat:
		dup_sb.corner_radius_top_left = 0
		dup_sb.corner_radius_top_right = 0
		dup_sb.corner_radius_bottom_left = 0
		dup_sb.corner_radius_bottom_right = 0
		dup_sb.corner_detail = 1
		dup_sb.anti_aliasing = false
		if style_name == "panel" and (dup_sb.border_width_left > 0 or dup_sb.border_width_top > 0):
			dup_sb.border_color = tint
		else:
			dup_sb.bg_color = tint
	ctrl.add_theme_stylebox_override(style_name, dup_sb)

static func clamp_popup_position(popup: Control, desired_pos: Vector2, container_size: Vector2, margin: float = 8.0) -> Vector2:
	if is_instance_valid(popup):
		popup.reset_size()
	var p_size: Vector2 = popup.get_combined_minimum_size() if is_instance_valid(popup) else Vector2(180.0, 160.0)
	if is_instance_valid(popup):
		p_size.x = maxf(p_size.x, popup.size.x)
		p_size.y = maxf(p_size.y, popup.size.y)
	var max_x: float = maxf(margin, container_size.x - p_size.x - margin)
	var max_y: float = maxf(margin, container_size.y - p_size.y - margin)
	return Vector2(
		floorf(clampf(desired_pos.x, margin, max_x)),
		floorf(clampf(desired_pos.y, margin, max_y))
	)

static func build_drag_preview(item: Dictionary, is_rot: bool, cell_size: float = CELL_SIZE) -> Control:
	var base_size: Vector2i = ItemDatabase.get_item_grid_size(str(item.get("id", "")))
	var base_w: int = int(item.get("w", base_size.x))
	var base_h: int = int(item.get("h", base_size.y))
	var cur_w: int = base_h if is_rot else base_w
	var cur_h: int = base_w if is_rot else base_h
	var total_w: float = float(cur_w) * cell_size
	var total_h: float = float(cur_h) * cell_size

	var preview := Control.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.z_index = 200
	preview.custom_minimum_size = Vector2(total_w, total_h)

	var bg_panel := Panel.new()
	bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_panel.position = Vector2(2.0, 2.0)
	bg_panel.size = Vector2(total_w - 4.0, total_h - 4.0)

	var sb: StyleBox = PixelAssetManager.get_ui_stylebox("equip_gold", 4, 4, 4, 4, 4) if PixelAssetManager else null
	if sb == null:
		sb = _make_stylebox(Color(0.09, 0.12, 0.16, 0.88), Color(0.92, 0.68, 0.24, 0.98), 2)
	bg_panel.add_theme_stylebox_override("panel", sb)
	preview.add_child(bg_panel)

	var icon := TextureRect.new()
	var min_dim: float = floorf(minf(total_w, total_h) * 0.72)
	icon.custom_minimum_size = Vector2(min_dim, min_dim)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ItemIconManager:
		icon.texture = ItemIconManager.get_icon(str(item.get("id", "")))
	icon.position = ((Vector2(total_w, total_h) - Vector2(min_dim, min_dim)) * 0.5).floor()
	preview.add_child(icon)

	var amt: int = int(item.get("amount", 1))
	if amt > 1:
		var amt_lbl := Label.new()
		amt_lbl.text = "x%d" % amt
		amt_lbl.add_theme_font_size_override("font_size", 10)
		amt_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		amt_lbl.position = Vector2(6.0, total_h - 18.0)
		amt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.add_child(amt_lbl)
	return preview

static func init_cached_styleboxes() -> void:
	if _sb_hover_compat != null:
		return
	_sb_hover_compat = _make_stylebox(Color(0.12, 0.42, 0.18, 0.9), Color(0.3, 1.0, 0.5, 1.0), 2)
	_sb_hover_incompat = _make_stylebox(Color(0.42, 0.12, 0.12, 0.9), Color(1.0, 0.3, 0.3, 1.0), 2)
	_sb_guide_compat = _make_stylebox(Color(0.08, 0.24, 0.14, 0.65), Color(0.2, 0.85, 0.4, 0.85), 2)
	_sb_guide_default = _make_stylebox(Color(0.14, 0.15, 0.18, 0.5), Color(0.25, 0.28, 0.32, 0.4), 1)

static func _make_stylebox(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.corner_radius_top_left = 0
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.corner_detail = 1
	sb.anti_aliasing = false
	return sb

static func is_slot_compatible(item_id: String, slot_name: String) -> bool:
	var idata = ItemDatabase.get_item_data(item_id)
	var cat = idata.get("category", -1)
	var e_slot = ItemDatabase.get_item_equip_slot(item_id)
	
	if slot_name == "helmet":
		return e_slot == "helmet" or item_id.contains("헬멧") or item_id.contains("방독면")
	elif slot_name == "vest":
		return e_slot == "vest" or item_id.contains("방탄") or item_id.contains("조끼")
	elif slot_name == "backpack":
		return e_slot == "backpack" or item_id.contains("가방") or item_id.contains("배낭")
	elif slot_name == "bottom":
		return e_slot == "bottom" or item_id.contains("운동화") or item_id.contains("신발")
	elif slot_name.begins_with("primary"):
		return cat == ItemDatabase.ItemCategory.WEAPON or idata.get("type", "") == "receiver" or e_slot == "primary" or item_id.contains("소총") or item_id.contains("M4") or item_id.contains("AK") or item_id.contains("산탄총") or item_id.contains("SV98") or item_id.contains("리시버")
	elif slot_name == "sidearm":
		return idata.get("type", "") == "melee" or item_id.contains("권총") or item_id.begins_with("M9") or item_id.contains("리볼버") or e_slot == "sidearm" or e_slot == "melee"
	elif slot_name == "throwable":
		return item_id.contains("수류탄") or item_id.contains("연막") or item_id.contains("화염") or e_slot == "throwable"
	elif slot_name == "pouch":
		return false
	return false

static func _draw_pixel_corner_brackets(ctrl: Control, rect: Rect2, col: Color, arm_len: float = 4.0, thick: float = 1.0) -> void:
	var x0 := floorf(rect.position.x)
	var y0 := floorf(rect.position.y)
	var x1 := floorf(rect.position.x + rect.size.x)
	var y1 := floorf(rect.position.y + rect.size.y)
	# Top-Left
	ctrl.draw_rect(Rect2(x0, y0, arm_len, thick), col, true)
	ctrl.draw_rect(Rect2(x0, y0, thick, arm_len), col, true)
	# Top-Right
	ctrl.draw_rect(Rect2(x1 - arm_len, y0, arm_len, thick), col, true)
	ctrl.draw_rect(Rect2(x1 - thick, y0, thick, arm_len), col, true)
	# Bottom-Left
	ctrl.draw_rect(Rect2(x0, y1 - thick, arm_len, thick), col, true)
	ctrl.draw_rect(Rect2(x0, y1 - arm_len, thick, arm_len), col, true)
	# Bottom-Right
	ctrl.draw_rect(Rect2(x1 - arm_len, y1 - thick, arm_len, thick), col, true)
	ctrl.draw_rect(Rect2(x1 - thick, y1 - arm_len, thick, arm_len), col, true)

static func draw_2d_grid(ctrl: Control, grid_mgr: InventoryGrid, hovered_cell: Vector2i, is_player_grid: bool, is_dragging: bool = false, drag_data: Dictionary = {}, cell_size: float = CELL_SIZE) -> void:
	if not ctrl or not grid_mgr: return
	
	var w: int = grid_mgr.grid_width
	var h: int = grid_mgr.grid_height
	var font: Font = ThemeDB.fallback_font
	
	# 0. 전체 그리드 베이스 배경 (다크 택티컬 스틸 웰)
	var full_rect := Rect2(0.0, 0.0, float(w) * cell_size, float(h) * cell_size)
	ctrl.draw_rect(full_rect, Color(0.035, 0.045, 0.062, 0.96), true)
	
	# 각 셀 내부의 리세스(오목) 도트 슬롯 디테일
	var cell_well_col := Color(0.055, 0.068, 0.092, 0.94)
	var cell_shadow_col := Color(0.02, 0.025, 0.038, 0.95)
	for cy in range(h):
		for cx in range(w):
			var c_rect := Rect2(float(cx) * cell_size + 2.0, float(cy) * cell_size + 2.0, cell_size - 4.0, cell_size - 4.0)
			ctrl.draw_rect(c_rect, cell_well_col, true)
			ctrl.draw_rect(Rect2(c_rect.position.x, c_rect.position.y, c_rect.size.x, 1.0), cell_shadow_col, true)
			ctrl.draw_rect(Rect2(c_rect.position.x, c_rect.position.y, 1.0, c_rect.size.y), cell_shadow_col, true)
	
	# 1. 배경 격자선 및 플레이어 배낭 좌상단 2x2 안전 컨테이너(Secure Pouch) 구역 표시
	if is_player_grid and w >= 2 and h >= 2:
		var pouch_rect := Rect2(0.0, 0.0, 2.0 * cell_size, 2.0 * cell_size)
		ctrl.draw_rect(pouch_rect, Color(0.92, 0.68, 0.22, 0.08), true)
		# 상단 해저드 도트 스트라이프 틱
		for hx in range(0, int(2.0 * cell_size) - 4, 8):
			ctrl.draw_rect(Rect2(float(hx) + 2.0, 2.0, 4.0, 2.0), Color(0.92, 0.68, 0.22, 0.38), true)
		ctrl.draw_rect(pouch_rect, Color(0.92, 0.68, 0.22, 0.62), false, 1.0)
		_draw_pixel_corner_brackets(ctrl, Rect2(1.0, 1.0, 2.0 * cell_size - 2.0, 2.0 * cell_size - 2.0), Color(1.0, 0.78, 0.28, 0.9), 6.0, 2.0)
		ctrl.draw_string(font, Vector2(5.0, 2.0 * cell_size - 5.0), "SECURE", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.95, 0.72, 0.24, 0.55))
		
	var line_col := Color(0.16, 0.20, 0.26, 0.9)
	for x in range(w + 1):
		ctrl.draw_line(Vector2(float(x) * cell_size, 0.0), Vector2(float(x) * cell_size, float(h) * cell_size), line_col, 1.0)
	for y in range(h + 1):
		ctrl.draw_line(Vector2(0.0, float(y) * cell_size), Vector2(float(w) * cell_size, float(y) * cell_size), line_col, 1.0)
	
	# 격자 교차점 도트 크로스헤어(+) 리벳 포인트
	var cross_col := Color(0.24, 0.30, 0.38, 0.85)
	for cy in range(1, h):
		for cx in range(1, w):
			var px: float = floorf(float(cx) * cell_size)
			var py: float = floorf(float(cy) * cell_size)
			ctrl.draw_rect(Rect2(px - 1.0, py, 3.0, 1.0), cross_col, true)
			ctrl.draw_rect(Rect2(px, py - 1.0, 1.0, 3.0), cross_col, true)
		
	# 마우스 호버 셀 미세 하이라이트 + 픽셀 코너 브래킷 (비드래그 상태)
	if not is_dragging and hovered_cell.x >= 0 and hovered_cell.x < w and hovered_cell.y >= 0 and hovered_cell.y < h:
		var hover_cell_rect := Rect2(float(hovered_cell.x) * cell_size + 1.0, float(hovered_cell.y) * cell_size + 1.0, cell_size - 2.0, cell_size - 2.0)
		ctrl.draw_rect(hover_cell_rect, Color(0.92, 0.65, 0.20, 0.10), true)
		_draw_pixel_corner_brackets(ctrl, hover_cell_rect, Color(0.95, 0.68, 0.22, 0.75), 5.0, 1.0)
		
	# 2. 배치된 아이템 렌더링 (픽셀 베벨 카드 + 희귀도 LED 바 + 코너 브래킷)
	for item in grid_mgr.items:
		if item.is_empty(): continue
		if is_dragging and (drag_data.get("source") == "grid" or drag_data.get("source") == "player_grid") and drag_data.get("item", {}).get("uid") == item.get("uid"):
			continue # 드래그 중인 원본은 투명하게 숨김
			
		var cur_w: int = int(item.get("h", 1)) if bool(item.get("rotated", false)) else int(item.get("w", 1))
		var cur_h: int = int(item.get("w", 1)) if bool(item.get("rotated", false)) else int(item.get("h", 1))
		var item_rect := Rect2(float(item.get("x", 0)) * cell_size + 2.0, float(item.get("y", 0)) * cell_size + 2.0, float(cur_w) * cell_size - 4.0, float(cur_h) * cell_size - 4.0)
		
		var d: Dictionary = ItemDatabase.get_item_data(str(item.get("id", "")))
		var rarity: float = float(d.get("rarity", 0.5))
		var rarity_accent := Color(0.45, 0.55, 0.68, 0.9)
		if rarity <= 0.05:
			rarity_accent = Color(0.96, 0.74, 0.22, 0.95)
		elif rarity <= 0.15:
			rarity_accent = Color(0.75, 0.42, 0.95, 0.95)
		elif rarity <= 0.35:
			rarity_accent = Color(0.35, 0.72, 0.98, 0.95)
			
		var item_bg := Color(0.11, 0.135, 0.175, 0.96) if is_player_grid else Color(0.10, 0.12, 0.155, 0.96)
		# 외곽 1px 암색 림 + 내부 스텝 베벨
		ctrl.draw_rect(Rect2(item_rect.position.x - 1.0, item_rect.position.y - 1.0, item_rect.size.x + 2.0, item_rect.size.y + 2.0), Color(0.02, 0.03, 0.04, 0.95), false, 1.0)
		ctrl.draw_rect(item_rect, item_bg, true)
		# 상단/좌측 밝은 베벨, 하단/우측 어두운 베벨
		ctrl.draw_rect(Rect2(item_rect.position.x, item_rect.position.y, item_rect.size.x, 1.0), Color(0.28, 0.35, 0.45, 0.95), true)
		ctrl.draw_rect(Rect2(item_rect.position.x, item_rect.position.y + item_rect.size.y - 1.0, item_rect.size.x, 1.0), Color(0.16, 0.20, 0.27, 0.95), true)
		ctrl.draw_rect(Rect2(item_rect.position.x + item_rect.size.x - 1.0, item_rect.position.y, 1.0, item_rect.size.y), Color(0.16, 0.20, 0.27, 0.95), true)
		# 좌측 희귀도 LED 액센트 바 + 상단 스페큘러 픽셀 도트
		ctrl.draw_rect(Rect2(item_rect.position.x, item_rect.position.y, 3.0, item_rect.size.y), rarity_accent, true)
		ctrl.draw_rect(Rect2(item_rect.position.x + 1.0, item_rect.position.y + 1.0, 1.0, 2.0), Color(1.0, 0.98, 0.92, 0.9), true)
		# 우상단/우하단 희귀도 도트 코너 브래킷
		var rx1: float = item_rect.position.x + item_rect.size.x
		var ry0: float = item_rect.position.y
		var ry1: float = item_rect.position.y + item_rect.size.y
		ctrl.draw_rect(Rect2(rx1 - 4.0, ry0, 4.0, 1.0), rarity_accent, true)
		ctrl.draw_rect(Rect2(rx1 - 1.0, ry0, 1.0, 4.0), rarity_accent, true)
		ctrl.draw_rect(Rect2(rx1 - 4.0, ry1 - 1.0, 4.0, 1.0), rarity_accent, true)
		ctrl.draw_rect(Rect2(rx1 - 1.0, ry1 - 4.0, 1.0, 4.0), rarity_accent, true)
		
		# 아이콘
		var icon_tex: Texture2D = ItemIconManager.get_icon(str(item.get("id", ""))) if ItemIconManager else null
		if icon_tex:
			var min_sz: float = floorf(minf(item_rect.size.x, item_rect.size.y) * 0.72)
			var icon_size := Vector2(min_sz, min_sz)
			var icon_pos: Vector2 = (item_rect.position + (item_rect.size - icon_size) / 2.0).floor()
			ctrl.draw_texture_rect(icon_tex, Rect2(icon_pos, icon_size), false)
			
		# 수량
		var amt: int = int(item.get("amount", 1))
		if amt > 1:
			ctrl.draw_string(font, item_rect.position + Vector2(6.0, item_rect.size.y - 4.0), "x%d" % amt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.98, 0.82, 0.32))
			
		# 이름
		ctrl.draw_string(font, item_rect.position + Vector2(6.0, 12.0), str(d.get("name", item.get("id", ""))), HORIZONTAL_ALIGNMENT_LEFT, item_rect.size.x - 10.0, 10, Color(0.88, 0.91, 0.95, 0.9))

		# 총기류 탄약 표기 (우하단: cur/max, 잔탄 0: 적색, 잔탄 보유: 연녹색)
		var item_id_str: String = str(item.get("id", ""))
		var cat: int = int(d.get("category", -1))
		var item_type_str: String = str(d.get("type", item.get("type", "")))
		var is_non_gun: bool = bool(d.get("stackable", false)) or item_type_str in ["melee", "ammo", "throwable", "part"] or item_id_str in ["나이프", "파이프", "도끼", "야구방망이", "탄약", "수류탄", "연막탄", "화염병"] or WeaponPartsDatabase.AMMO_TYPES.has(item_id_str) or WeaponPartsDatabase.PARTS.has(item_id_str)
		var is_gun: bool = not is_non_gun and (WeaponPartsDatabase.is_modifiable_weapon(item) or item.has("parts") or item_type_str in ["receiver", "assembled_weapon", "ranged"] or item.has("current_magazine_ammo"))
		if is_gun:
			var max_ammo: int = 30
			if item.has("computed_stats") and item["computed_stats"].has("magazine_size"):
				max_ammo = int(item["computed_stats"]["magazine_size"])
			elif item.has("parts"):
				var stats: Dictionary = WeaponPartsDatabase.compute_weapon_stats(item_id_str, item.get("parts", {}))
				max_ammo = int(stats.get("magazine_size", 30))
			elif d.has("magazine_size"):
				max_ammo = int(d["magazine_size"])
			elif d.has("ammo"):
				max_ammo = 30
			var cur_ammo: int = int(item.get("current_magazine_ammo", max_ammo))
			var ammo_str: String = "%d/%d" % [cur_ammo, max_ammo]
			var ammo_col := Color(0.4, 1.0, 0.6) if cur_ammo > 0 else Color(1.0, 0.25, 0.25)
			var font_sz: int = 9
			var text_w: float = 42.0
			ctrl.draw_string(font, item_rect.position + Vector2(item_rect.size.x - text_w - 4.0, item_rect.size.y - 4.0), ammo_str, HORIZONTAL_ALIGNMENT_RIGHT, text_w, font_sz, ammo_col)

		# 방어구/헬멧 내구도 바 표기 (셀 하단 세그먼트 픽셀 LED 바)
		var is_armor: bool = cat == ItemDatabase.ItemCategory.EQUIPMENT and (d.get("equip_slot") in ["vest", "helmet"] or item_id_str.contains("방탄") or item_id_str.contains("헬멧") or item_id_str.contains("조끼") or item_id_str.contains("방독면"))
		if is_armor:
			var max_dur: float = float(item.get("max_durability", d.get("max_durability", 100.0)))
			if max_dur > 0.0:
				var cur_dur: float = float(item.get("durability", max_dur))
				var ratio: float = clampf(cur_dur / max_dur, 0.0, 1.0)
				var bar_w: float = item_rect.size.x - 8.0
				var bar_h: float = 3.0
				var bar_rect := Rect2(item_rect.position.x + 4.0, item_rect.position.y + item_rect.size.y - bar_h - 2.0, bar_w, bar_h)
				ctrl.draw_rect(bar_rect, Color(0.05, 0.07, 0.09, 0.92), true)
				var dur_col := Color(0.25, 0.85, 0.4, 0.95)
				if ratio < 0.25:
					dur_col = Color(0.95, 0.25, 0.25, 0.95)
				elif ratio < 0.6:
					dur_col = Color(0.95, 0.75, 0.2, 0.95)
				if ratio > 0.0:
					var filled_w: float = floorf(bar_w * ratio)
					var seg_x: float = 0.0
					while seg_x < filled_w:
						var seg_w: float = minf(3.0, filled_w - seg_x)
						ctrl.draw_rect(Rect2(bar_rect.position.x + seg_x, bar_rect.position.y, seg_w, bar_h), dur_col, true)
						seg_x += 4.0

	# 3. 드래그 중 고스트 프리뷰 (초록 / 빨강 픽셀 타겟 브래킷)
	if is_dragging and hovered_cell.x >= 0 and hovered_cell.y >= 0:
		var item: Dictionary = drag_data.get("item", {})
		var base_size: Vector2i = ItemDatabase.get_item_grid_size(str(item.get("id", "")))
		var base_w: int = int(item.get("w", base_size.x))
		var base_h: int = int(item.get("h", base_size.y))
		var is_rot: bool = bool(drag_data.get("rotated", false))
		var place_w: int = base_h if is_rot else base_w
		var place_h: int = base_w if is_rot else base_h
		
		var src: String = str(drag_data.get("source", ""))
		var uid: String = str(item.get("uid", ""))
		var ignore_uid: String = uid if (src == "grid" or src == ("player_grid" if is_player_grid else "stash_grid")) else ""
		var can_place: bool = grid_mgr.can_place_item(place_w, place_h, hovered_cell.x, hovered_cell.y, ignore_uid, str(item.get("id", "")))
		var ghost_rect := Rect2(float(hovered_cell.x) * cell_size, float(hovered_cell.y) * cell_size, float(place_w) * cell_size, float(place_h) * cell_size)
		
		var col := Color(0.16, 0.72, 0.28, 0.35) if can_place else Color(0.85, 0.18, 0.18, 0.35)
		var border_col := Color(0.32, 1.0, 0.45, 0.95) if can_place else Color(1.0, 0.32, 0.32, 0.95)
		
		ctrl.draw_rect(ghost_rect, col, true)
		ctrl.draw_rect(ghost_rect, border_col, false, 1.0)
		_draw_pixel_corner_brackets(ctrl, Rect2(ghost_rect.position.x + 1.0, ghost_rect.position.y + 1.0, ghost_rect.size.x - 2.0, ghost_rect.size.y - 2.0), border_col, 6.0, 2.0)

static func highlight_compatible_slots(drop_targets: Array, item: Dictionary, hovered_ctrl: Control = null) -> void:
	init_cached_styleboxes()
	var item_id = item.get("id", "")
	for target in drop_targets:
		var ctrl: Control = target.get("control")
		if not is_instance_valid(ctrl) or not ctrl.is_visible_in_tree(): continue
		
		var t_type = target.get("type", "equipment")
		var is_compat = false
		
		if t_type == "equipment":
			is_compat = is_slot_compatible(item_id, target.get("slot_name", ""))
		elif t_type == "weapon":
			var slot_key = target.get("slot_key", "")
			var eq_slot = ItemDatabase.get_item_equip_slot(item_id)
			var idata = ItemDatabase.get_item_data(item_id)
			var is_ammo = (idata.get("type", "") == "ammo" or ItemDatabase.is_ammo_item(item_id))
			if is_ammo:
				is_compat = false
			elif slot_key.begins_with("primary"):
				is_compat = (eq_slot == "primary" or idata.get("type", "") == "receiver")
			elif slot_key == "sidearm":
				is_compat = (idata.get("type", "") == "melee" or item_id.contains("권총") or item_id.begins_with("M9") or eq_slot == "sidearm" or eq_slot == "melee")
			elif slot_key == "throwable":
				is_compat = (item_id.contains("수류탄") or item_id.contains("연막") or item_id.contains("화염") or eq_slot == "throwable")
		elif t_type == "attachment":
			var attach_type = target.get("attach_type", "")
			var p_data = WeaponPartsDatabase.PARTS.get(item_id, {})
			is_compat = (p_data.get("slot", "") == attach_type)
			
		var sb: StyleBox = null
		if PixelAssetManager:
			var t_margin: int = 3 if ctrl.custom_minimum_size.y > 0 and ctrl.custom_minimum_size.y <= 30.0 else 4
			if ctrl == hovered_ctrl:
				sb = PixelAssetManager.get_ui_stylebox("slot_compat_green" if is_compat else "slot_incompat_red", 6, 3, 6, 3, t_margin)
			else:
				sb = PixelAssetManager.get_ui_stylebox("slot_guide_compat" if is_compat else "slot_guide_default", 6, 3, 6, 3, t_margin)
		if sb == null:
			if ctrl == hovered_ctrl:
				sb = _sb_hover_compat if is_compat else _sb_hover_incompat
			else:
				sb = _sb_guide_compat if is_compat else _sb_guide_default
				
		ctrl.add_theme_stylebox_override("normal", sb)
		ctrl.add_theme_stylebox_override("hover", sb)

static func clear_slot_highlights(drop_targets: Array) -> void:
	for target in drop_targets:
		var ctrl: Control = target.get("control")
		if is_instance_valid(ctrl):
			ctrl.remove_theme_stylebox_override("normal")
			ctrl.remove_theme_stylebox_override("hover")

static func render_equip_slot_button(btn: Button, slot_name: String, default_text: String, equipment_data: Dictionary) -> void:
	if not btn: return
	btn.clip_text = true
	var equipped = equipment_data.get(slot_name, {})
	var dur_bar: ProgressBar = btn.get_node_or_null("SlotDurabilityBar") as ProgressBar
	var eq_overlay: Control = btn.get_node_or_null("EquippedVisualOverlay") as Control
	var is_tall_slot := btn.custom_minimum_size.y >= 64.0 or btn.size.y >= 64.0

	if equipped.is_empty():
		btn.text = default_text
		btn.icon = null
		if eq_overlay:
			eq_overlay.visible = false
		if dur_bar:
			dur_bar.visible = false
		btn.remove_theme_stylebox_override("normal")
	else:
		var item_id = str(equipped.get("id", ""))
		var d = ItemDatabase.get_item_data(item_id)
		var disp_name = str(equipped.get("name", ""))
		if disp_name == "" or disp_name == item_id:
			var d_name = str(d.get("name", item_id))
			if d_name == item_id and WeaponPartsDatabase.RECEIVERS.has(item_id):
				d_name = str(WeaponPartsDatabase.RECEIVERS[item_id].get("name", item_id))
			disp_name = d_name

		var w_data: Dictionary = GameManager.current_world_data if (GameManager and GameManager.current_world_data is Dictionary) else {}
		var is_gold_master := false
		if slot_name in ["primary1", "primary2", "sidearm"]:
			var m_info := HideoutProgression.get_weapon_mastery_bonus(w_data, item_id)
			is_gold_master = bool(m_info.get("gold_border", false))

		var eq_sb: StyleBox = null
		if PixelAssetManager:
			eq_sb = PixelAssetManager.get_ui_stylebox("equip_gold" if is_gold_master else "equip_filled", 6, 4, 6, 4, 4)
		if eq_sb == null:
			var flat_sb := StyleBoxFlat.new()
			flat_sb.bg_color = Color(0.16, 0.13, 0.06, 0.94) if is_gold_master else Color(0.11, 0.17, 0.22, 0.94)
			flat_sb.border_width_left = 2
			flat_sb.border_width_top = 2
			flat_sb.border_width_right = 2
			flat_sb.border_width_bottom = 2
			flat_sb.border_color = Color(1.0, 0.84, 0.22, 0.98) if is_gold_master else Color(0.32, 0.82, 0.55, 0.92)
			flat_sb.corner_radius_top_left = 0
			flat_sb.corner_radius_top_right = 0
			flat_sb.corner_radius_bottom_left = 0
			flat_sb.corner_radius_bottom_right = 0
			flat_sb.corner_detail = 1
			flat_sb.anti_aliasing = false
			eq_sb = flat_sb
		btn.add_theme_stylebox_override("normal", eq_sb)

		if is_tall_slot:
			btn.text = ""
			btn.icon = null
			if eq_overlay == null:
				eq_overlay = Control.new()
				eq_overlay.name = "EquippedVisualOverlay"
				eq_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
				eq_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
				btn.add_child(eq_overlay)

				var icon_rect := TextureRect.new()
				icon_rect.name = "EquippedIcon"
				icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				icon_rect.set_anchors_preset(Control.PRESET_CENTER_TOP)
				icon_rect.offset_left = -20.0
				icon_rect.offset_top = 6.0
				icon_rect.offset_right = 20.0
				icon_rect.offset_bottom = 46.0
				eq_overlay.add_child(icon_rect)

				var name_lbl := Label.new()
				name_lbl.name = "EquippedName"
				name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				name_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
				name_lbl.offset_left = 3.0
				name_lbl.offset_top = -32.0
				name_lbl.offset_right = -3.0
				name_lbl.offset_bottom = -7.0
				name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				name_lbl.clip_text = true
				name_lbl.add_theme_font_size_override("font_size", 10)
				name_lbl.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
				eq_overlay.add_child(name_lbl)

			eq_overlay.visible = true
			var ic_node: TextureRect = eq_overlay.get_node_or_null("EquippedIcon") as TextureRect
			if ic_node and ItemIconManager:
				ic_node.texture = ItemIconManager.get_icon(item_id)
			var nm_node: Label = eq_overlay.get_node_or_null("EquippedName") as Label
			if nm_node:
				nm_node.text = disp_name
		else:
			if eq_overlay:
				eq_overlay.visible = false
			btn.text = disp_name
			if ItemIconManager:
				btn.icon = ItemIconManager.get_icon(item_id)
				btn.expand_icon = true
		var max_dur: float = float(equipped.get("max_durability", d.get("max_durability", 0.0)))
		if (slot_name in ["helmet", "vest"] or equipped.has("durability")) and max_dur > 0.0:
			var cur_dur: float = clampf(float(equipped.get("durability", max_dur)), 0.0, max_dur)
			if dur_bar == null:
				dur_bar = ProgressBar.new()
				dur_bar.name = "SlotDurabilityBar"
				dur_bar.show_percentage = false
				dur_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
				dur_bar.custom_minimum_size = Vector2(0, 4)
				dur_bar.anchor_left = 0.0
				dur_bar.anchor_right = 1.0
				dur_bar.anchor_top = 1.0
				dur_bar.anchor_bottom = 1.0
				dur_bar.offset_left = 4.0
				dur_bar.offset_right = -4.0
				dur_bar.offset_top = -6.0
				dur_bar.offset_bottom = -2.0
				var bg_style := StyleBoxFlat.new()
				bg_style.bg_color = Color(0.05, 0.06, 0.08, 0.85)
				bg_style.anti_aliasing = false
				dur_bar.add_theme_stylebox_override("background", bg_style)
				btn.add_child(dur_bar)
			dur_bar.max_value = max_dur
			dur_bar.value = cur_dur
			var ratio: float = cur_dur / max_dur
			var dur_col := Color(0.2, 0.85, 0.3) if ratio > 0.5 else (Color(0.9, 0.7, 0.1) if ratio > 0.25 else Color(0.9, 0.2, 0.2))
			apply_dynamic_tint(dur_bar, "fill", dur_col)
			dur_bar.visible = true
		elif dur_bar:
			dur_bar.visible = false
