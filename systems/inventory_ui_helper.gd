# res://systems/inventory_ui_helper.gd
class_name InventoryUIHelper
extends RefCounted

## 타르코프식 2D 인벤토리 및 슬롯 상호작용 공통 UI 헬퍼
## 2D 그리드 셀 렌더링, 고스트 프리뷰, 슬롯 호환성 검사 및 스타일박스 하이라이트 공통 처리

const CELL_SIZE: float = 36.0
const POPUP_CELL_SIZE: float = 32.0

# 캐시된 StyleBox (마우스 이동 시 반복 생성 방지)
static var _sb_hover_compat: StyleBox = null
static var _sb_hover_incompat: StyleBox = null
static var _sb_guide_compat: StyleBox = null
static var _sb_guide_default: StyleBox = null

# StyleBoxTexture 겸용 안전 색상 오버라이드 헬퍼
static func apply_dynamic_tint(ctrl: Control, style_name: String, tint: Color) -> void:
	if not is_instance_valid(ctrl):
		return
	var base_sb: StyleBox = ctrl.get_theme_stylebox(style_name)
	if base_sb == null and PixelAssetManager:
		base_sb = PixelAssetManager.get_pixel_stylebox("progress_fill" if style_name == "fill" else "panel_main")
	if base_sb == null:
		return
	var dup_sb: StyleBox = base_sb.duplicate()
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

	var sb: StyleBox = PixelAssetManager.get_pixel_stylebox("drag_preview", 4.0, 4.0, 4.0, 4.0, 4) if PixelAssetManager else null
	if sb != null:
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
		if PixelAssetManager:
			amt_lbl.add_theme_font_override("font", PixelAssetManager.get_pixel_font_micro())
		amt_lbl.add_theme_font_size_override("font_size", 10)
		amt_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		amt_lbl.position = Vector2(6.0, total_h - 18.0)
		amt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.add_child(amt_lbl)
	return preview

static func calc_drag_drop_cell(grid_ctrl: Control, m_global_pos: Vector2, grid_mgr: InventoryGrid, drag_data: Dictionary, cell_size: float = CELL_SIZE) -> Vector2i:
	if not is_instance_valid(grid_ctrl) or grid_mgr == null:
		return Vector2i(-1, -1)
	if not grid_ctrl.get_global_rect().has_point(m_global_pos):
		return Vector2i(-1, -1)
	var item: Dictionary = drag_data.get("item", {})
	var is_rot: bool = bool(drag_data.get("rotated", false))
	var base_size: Vector2i = ItemDatabase.get_item_grid_size(str(item.get("id", "")))
	var base_w: int = int(item.get("w", base_size.x))
	var base_h: int = int(item.get("h", base_size.y))
	var cur_w: int = base_h if is_rot else base_w
	var cur_h: int = base_w if is_rot else base_h
	var local_pos: Vector2 = m_global_pos - grid_ctrl.get_global_rect().position
	var cx: int = roundi((local_pos.x - float(cur_w) * cell_size * 0.5) / cell_size)
	var cy: int = roundi((local_pos.y - float(cur_h) * cell_size * 0.5) / cell_size)
	# 그리드 경계 바로 안쪽 가장자리에서 -1로 벗어나는 경우 보정
	if cx < 0 and local_pos.x >= 0.0 and local_pos.x < cell_size:
		cx = 0
	if cy < 0 and local_pos.y >= 0.0 and local_pos.y < cell_size:
		cy = 0
	return Vector2i(cx, cy)

static func init_cached_styleboxes() -> void:
	if _sb_hover_compat != null:
		return
	if PixelAssetManager:
		_sb_hover_compat = PixelAssetManager.get_pixel_stylebox("hover_compat")
		_sb_hover_incompat = PixelAssetManager.get_pixel_stylebox("hover_incompat")
		_sb_guide_compat = PixelAssetManager.get_pixel_stylebox("guide_compat")
		_sb_guide_default = PixelAssetManager.get_pixel_stylebox("guide_default")

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

static func _draw_pixel_padlock(ctrl: Control, pos: Vector2, col: Color) -> void:
	var x0 := floorf(pos.x)
	var y0 := floorf(pos.y)
	# 자물쇠 아치
	ctrl.draw_rect(Rect2(x0 + 1.0, y0, 4.0, 1.0), col, true)
	ctrl.draw_rect(Rect2(x0 + 1.0, y0 + 1.0, 1.0, 2.0), col, true)
	ctrl.draw_rect(Rect2(x0 + 4.0, y0 + 1.0, 1.0, 2.0), col, true)
	# 자물쇠 몸체
	ctrl.draw_rect(Rect2(x0, y0 + 3.0, 6.0, 4.0), col, true)
	ctrl.draw_rect(Rect2(x0 + 2.0, y0 + 4.0, 2.0, 2.0), Color(0.08, 0.10, 0.14, 0.95), true)

static func draw_2d_grid(ctrl: Control, grid_mgr: InventoryGrid, hovered_cell: Vector2i, is_player_grid: bool, is_dragging: bool = false, drag_data: Dictionary = {}, cell_size: float = CELL_SIZE) -> void:
	if not ctrl or not grid_mgr: return
	
	var w: int = grid_mgr.grid_width
	var h: int = grid_mgr.grid_height
	var font_micro: Font = PixelAssetManager.get_pixel_font_micro() if PixelAssetManager else ThemeDB.fallback_font
	var selected_uids: Dictionary = ctrl.get_meta("selected_sell_uids", {}) if ctrl.has_meta("selected_sell_uids") else {}
	var filter_active: bool = bool(ctrl.get_meta("filter_active", false)) if ctrl.has_meta("filter_active") else false
	var matched_uids: Dictionary = ctrl.get_meta("matched_uids", {}) if ctrl.has_meta("matched_uids") else {}
	var unavailable_uids: Dictionary = ctrl.get_meta("unavailable_uids", {}) if ctrl.has_meta("unavailable_uids") else {}
	var active_focus_uid: String = str(ctrl.get_meta("active_focus_uid", "")) if ctrl.has_meta("active_focus_uid") else ""
	var lbl_font_sz: int = 11 if cell_size >= 48.0 else 10
	
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
	if is_player_grid and grid_mgr.has_secure_container and w >= 2 and h >= 2:
		var pouch_rect := Rect2(0.0, 0.0, 2.0 * cell_size, 2.0 * cell_size)
		ctrl.draw_rect(pouch_rect, Color(0.92, 0.68, 0.22, 0.08), true)
		# 상단 해저드 도트 스트라이프 틱
		for hx in range(0, int(2.0 * cell_size) - 4, 8):
			ctrl.draw_rect(Rect2(float(hx) + 2.0, 2.0, 4.0, 2.0), Color(0.92, 0.68, 0.22, 0.38), true)
		ctrl.draw_rect(pouch_rect, Color(0.92, 0.68, 0.22, 0.62), false, 1.0)
		_draw_pixel_corner_brackets(ctrl, Rect2(1.0, 1.0, 2.0 * cell_size - 2.0, 2.0 * cell_size - 2.0), Color(1.0, 0.78, 0.28, 0.9), 5.0, 2.0)
		ctrl.draw_string(font_micro, Vector2(4.0, 2.0 * cell_size - 4.0), "SECURE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.72, 0.24, 0.55))
		
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
		
	# 2. 배치된 아이템 렌더링 (픽셀 베벨 카드 + 희귀도 LED 바 + 코너 브래킷 + 잠금/위시리스트/선택)
	var drag_src_grid = drag_data.get("source_grid", null)
	var drag_src_name := str(drag_data.get("source", ""))
	var drag_uid := str(drag_data.get("item", {}).get("uid", ""))
	for item in grid_mgr.items:
		if item.is_empty(): continue
		var item_uid := str(item.get("uid", ""))
		if is_dragging and drag_uid != "" and drag_uid == item_uid:
			if drag_src_grid == grid_mgr or (drag_src_grid == null and (drag_src_name == "grid" or drag_src_name == "player_grid" or drag_src_name == "stash_grid")):
				continue # 드래그 중인 원본은 투명하게 숨김
			
		var cur_w: int = int(item.get("h", 1)) if bool(item.get("rotated", false)) else int(item.get("w", 1))
		var cur_h: int = int(item.get("w", 1)) if bool(item.get("rotated", false)) else int(item.get("h", 1))
		var item_rect := Rect2(float(item.get("x", 0)) * cell_size + 2.0, float(item.get("y", 0)) * cell_size + 2.0, float(cur_w) * cell_size - 4.0, float(cur_h) * cell_size - 4.0)
		
		var item_id_str: String = str(item.get("id", ""))
		var d: Dictionary = ItemDatabase.get_item_data(item_id_str)
		var rarity: float = float(d.get("rarity", 0.5))
		var rarity_accent := Color(0.45, 0.55, 0.68, 0.9)
		if rarity <= 0.05:
			rarity_accent = Color(0.96, 0.74, 0.22, 0.95)
		elif rarity <= 0.15:
			rarity_accent = Color(0.75, 0.42, 0.95, 0.95)
		elif rarity <= 0.35:
			rarity_accent = Color(0.35, 0.72, 0.98, 0.95)
			
		var is_selected_sell := selected_uids.has(item_uid)
		var item_bg := Color(0.11, 0.135, 0.175, 0.96) if is_player_grid else Color(0.10, 0.12, 0.155, 0.96)
		if is_selected_sell:
			item_bg = Color(0.10, 0.24, 0.22, 0.98)
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
		var icon_tex: Texture2D = ItemIconManager.get_icon(item_id_str) if ItemIconManager else null
		if icon_tex:
			var min_sz: float = floorf(minf(item_rect.size.x, item_rect.size.y) * 0.66)
			var icon_size := Vector2(min_sz, min_sz)
			var icon_pos: Vector2 = (item_rect.position + (item_rect.size - icon_size) / 2.0).floor()
			ctrl.draw_texture_rect(icon_tex, Rect2(icon_pos, icon_size), false)
			
		# 이름 (좌측 여백 5px, 우상단 배지 공간 확보를 위해 폭 제한)
		var is_locked := bool(item.get("locked", false))
		var is_wish := HideoutProgression.is_wishlist_item(item_id_str)
		var right_badge_pad: float = 8.0
		if is_locked:
			right_badge_pad += 8.0
		if is_wish:
			right_badge_pad += 10.0
		ctrl.draw_string(font_micro, item_rect.position + Vector2(5.0, 10.0), str(d.get("name", item_id_str)), HORIZONTAL_ALIGNMENT_LEFT, maxf(10.0, item_rect.size.x - right_badge_pad), lbl_font_sz, Color(0.88, 0.91, 0.95, 0.92))

		# 우상단 상태 배지: 잠금(자물쇠) & 위시리스트(★)
		var badge_cursor_x: float = rx1 - 2.0
		if is_locked:
			badge_cursor_x -= 7.0
			_draw_pixel_padlock(ctrl, Vector2(badge_cursor_x, ry0 + 2.0), Color(1.0, 0.72, 0.20, 0.98))
		if is_wish:
			badge_cursor_x -= 10.0
			ctrl.draw_string(font_micro, Vector2(badge_cursor_x, ry0 + 10.0), "★", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.88, 0.22, 0.98))

		# 방어구/헬멧 내구도 바 표기 (최하단 2px, 텍스트와 비겹침)
		var cat: int = int(d.get("category", -1))
		var is_armor: bool = cat == ItemDatabase.ItemCategory.EQUIPMENT and (d.get("equip_slot") in ["vest", "helmet"] or item_id_str.contains("방탄") or item_id_str.contains("헬멧") or item_id_str.contains("조끼") or item_id_str.contains("방독면"))
		var bottom_text_offset: float = 5.0 if is_armor else 4.0

		# 수량 or 중첩 컨테이너 보관 수량 표기
		var amt: int = int(item.get("amount", 1))
		if amt > 1:
			ctrl.draw_string(font_micro, item_rect.position + Vector2(5.0, item_rect.size.y - bottom_text_offset), "x%d" % amt, HORIZONTAL_ALIGNMENT_LEFT, -1, lbl_font_sz, Color(0.98, 0.82, 0.32))
		elif InventoryGrid.is_container_item(item):
			var inner_arr = item.get("inner_items", [])
			var inner_cnt: int = inner_arr.size() if inner_arr is Array else 0
			var c_col := Color(0.45, 0.92, 1.0, 0.92) if inner_cnt > 0 else Color(0.58, 0.66, 0.74, 0.75)
			ctrl.draw_string(font_micro, item_rect.position + Vector2(5.0, item_rect.size.y - bottom_text_offset), "[%d]" % inner_cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, c_col)

		# 총기류 탄약 표기 (우하단: cur/max, 잔탄 0: 적색, 잔탄 보유: 연녹색)
		var item_type_str: String = str(d.get("type", item.get("type", "")))
		var is_non_gun: bool = bool(d.get("stackable", false)) or item_type_str in ["melee", "ammo", "throwable", "part", "storage_case"] or item_id_str in ["나이프", "파이프", "도끼", "야구방망이", "탄약", "수류탄", "연막탄", "화염병"] or WeaponPartsDatabase.AMMO_TYPES.has(item_id_str) or WeaponPartsDatabase.PARTS.has(item_id_str)
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
			var text_w: float = 36.0
			ctrl.draw_string(font_micro, item_rect.position + Vector2(item_rect.size.x - text_w - 3.0, item_rect.size.y - bottom_text_offset), ammo_str, HORIZONTAL_ALIGNMENT_RIGHT, text_w, 10, ammo_col)

		if is_armor:
			var max_dur: float = float(item.get("max_durability", d.get("max_durability", 100.0)))
			if max_dur > 0.0:
				var cur_dur: float = float(item.get("durability", max_dur))
				var ratio: float = clampf(cur_dur / max_dur, 0.0, 1.0)
				var bar_w: float = item_rect.size.x - 6.0
				var bar_h: float = 2.0
				var bar_rect := Rect2(item_rect.position.x + 3.0, item_rect.position.y + item_rect.size.y - bar_h - 1.0, bar_w, bar_h)
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

		# 판매 장바구니 & 검색/필터 하이라이트 및 비매칭 디밍 처리
		var is_unavail := unavailable_uids.has(item_uid)
		var is_dimmed := is_unavail or (filter_active and not matched_uids.has(item_uid))
		if is_dimmed:
			ctrl.draw_rect(item_rect, Color(0.02, 0.03, 0.045, 0.68), true)
		elif filter_active and matched_uids.has(item_uid):
			ctrl.draw_rect(item_rect, Color(0.28, 0.88, 1.0, 0.92), false, 1.5)

		if active_focus_uid != "" and active_focus_uid == item_uid:
			ctrl.draw_rect(item_rect, Color(1.0, 0.85, 0.24, 1.0), false, 2.0)
			_draw_pixel_corner_brackets(ctrl, item_rect, Color(1.0, 0.92, 0.45, 1.0), 5.0, 2.0)

		if is_selected_sell:
			ctrl.draw_rect(item_rect, Color(0.25, 0.98, 0.72, 0.98), false, 2.0)
			ctrl.draw_string(font_micro, Vector2(rx1 - 11.0, ry1 - 4.0), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.32, 1.0, 0.68, 1.0))

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
		var same_grid: bool = (drag_src_grid == grid_mgr) or (drag_src_grid == null and (src == "grid" or src == ("player_grid" if is_player_grid else "stash_grid")))
		var ignore_uid: String = uid if same_grid else ""
		var can_place: bool = grid_mgr.can_place_item(place_w, place_h, hovered_cell.x, hovered_cell.y, ignore_uid, str(item.get("id", "")), item)
		var ghost_rect := Rect2(float(hovered_cell.x) * cell_size, float(hovered_cell.y) * cell_size, float(place_w) * cell_size, float(place_h) * cell_size)
		
		var col := Color(0.16, 0.72, 0.28, 0.35) if can_place else Color(0.85, 0.18, 0.18, 0.35)
		var border_col := Color(0.32, 1.0, 0.45, 0.95) if can_place else Color(1.0, 0.32, 0.32, 0.95)
		
		ctrl.draw_rect(ghost_rect, col, true)
		ctrl.draw_rect(ghost_rect, border_col, false, 1.0)
		_draw_pixel_corner_brackets(ctrl, Rect2(ghost_rect.position.x + 1.0, ghost_rect.position.y + 1.0, ghost_rect.size.x - 2.0, ghost_rect.size.y - 2.0), border_col, 6.0, 2.0)

	# 4. Marquee 영역 다중 선택 박스 렌더링
	if ctrl.has_meta("marquee_rect"):
		var m_rect = ctrl.get_meta("marquee_rect")
		if m_rect is Rect2 and m_rect.size.x > 2.0 and m_rect.size.y > 2.0:
			ctrl.draw_rect(m_rect, Color(0.22, 0.85, 0.96, 0.20), true)
			ctrl.draw_rect(m_rect, Color(0.35, 0.94, 1.0, 0.95), false, 1.5)

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
				sb = PixelAssetManager.get_pixel_stylebox("hover_compat" if is_compat else "hover_incompat", 6.0, 3.0, 6.0, 3.0, t_margin)
			else:
				sb = PixelAssetManager.get_pixel_stylebox("guide_compat" if is_compat else "guide_default", 6.0, 3.0, 6.0, 3.0, t_margin)
		if sb == null:
			if ctrl == hovered_ctrl:
				sb = _sb_hover_compat if is_compat else _sb_hover_incompat
			else:
				sb = _sb_guide_compat if is_compat else _sb_guide_default
				
		if sb != null:
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

		var eq_sb: StyleBox = PixelAssetManager.get_pixel_stylebox("equip_gold" if is_gold_master else "equip_filled", 6.0, 4.0, 6.0, 4.0, 4) if PixelAssetManager else null
		if eq_sb != null:
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
				if PixelAssetManager:
					name_lbl.add_theme_font_override("font", PixelAssetManager.get_pixel_font_micro())
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
				if PixelAssetManager:
					dur_bar.add_theme_stylebox_override("background", PixelAssetManager.get_pixel_stylebox("progress_bg", 1.0, 1.0, 1.0, 1.0, 2))
				btn.add_child(dur_bar)
			dur_bar.max_value = max_dur
			dur_bar.value = cur_dur
			var ratio: float = cur_dur / max_dur
			var dur_col := Color(0.2, 0.85, 0.3) if ratio > 0.5 else (Color(0.9, 0.7, 0.1) if ratio > 0.25 else Color(0.9, 0.2, 0.2))
			apply_dynamic_tint(dur_bar, "fill", dur_col)
			dur_bar.visible = true
		elif dur_bar:
			dur_bar.visible = false
