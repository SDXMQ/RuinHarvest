# res://systems/inventory_ui_helper.gd
class_name InventoryUIHelper
extends RefCounted

## 타르코프식 2D 인벤토리 및 슬롯 상호작용 공통 UI 헬퍼
## 2D 그리드 셀 렌더링, 고스트 프리뷰, 슬롯 호환성 검사 및 스타일박스 하이라이트 공통 처리

const CELL_SIZE: float = 50.0

# 캐시된 StyleBoxFlat (마우스 이동 시 반복 생성 방지)
static var _sb_hover_compat: StyleBoxFlat = null
static var _sb_hover_incompat: StyleBoxFlat = null
static var _sb_guide_compat: StyleBoxFlat = null
static var _sb_guide_default: StyleBoxFlat = null

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
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	return sb

static func is_slot_compatible(item_id: String, slot_name: String) -> bool:
	var idata = ItemDatabase.get_item_data(item_id)
	var cat = idata.get("category", -1)
	var e_slot = ItemDatabase.get_item_equip_slot(item_id)
	
	if slot_name == "helmet":
		return e_slot == "helmet" or cat == ItemDatabase.ItemCategory.HELMET or item_id.contains("헬멧") or item_id.contains("방독면")
	elif slot_name == "vest":
		return e_slot == "vest" or cat == ItemDatabase.ItemCategory.VEST or item_id.contains("방탄") or item_id.contains("조끼")
	elif slot_name == "backpack":
		return e_slot == "backpack" or cat == ItemDatabase.ItemCategory.BACKPACK or item_id.contains("가방") or item_id.contains("배낭")
	elif slot_name == "bottom":
		return e_slot == "bottom" or item_id.contains("운동화") or item_id.contains("신발")
	elif slot_name.begins_with("primary"):
		return cat == ItemDatabase.ItemCategory.WEAPON or idata.get("type", "") == "receiver" or e_slot == "primary" or item_id.contains("소총") or item_id.contains("M4") or item_id.contains("AK") or item_id.contains("산탄총") or item_id.contains("SV98") or item_id.contains("리시버")
	elif slot_name == "sidearm":
		return idata.get("type", "") == "melee" or item_id.contains("권총") or item_id.begins_with("M9") or item_id.contains("리볼버") or e_slot == "sidearm" or e_slot == "melee"
	elif slot_name == "throwable":
		return cat == ItemDatabase.ItemCategory.THROWABLE or item_id.contains("수류탄") or item_id.contains("연막") or item_id.contains("화염") or e_slot == "throwable"
	elif slot_name == "pouch":
		return false
	return false

static func draw_2d_grid(ctrl: Control, grid_mgr: InventoryGrid, hovered_cell: Vector2i, is_player_grid: bool, is_dragging: bool = false, drag_data: Dictionary = {}, cell_size: float = CELL_SIZE) -> void:
	if not ctrl or not grid_mgr: return
	
	var w = grid_mgr.grid_width
	var h = grid_mgr.grid_height
	
	# 1. 배경 격자선 및 플레이어 배낭 좌상단 2x2 안전 컨테이너(Secure Pouch) 구역 표시
	if is_player_grid and w >= 2 and h >= 2:
		var pouch_rect = Rect2(0, 0, 2 * cell_size, 2 * cell_size)
		ctrl.draw_rect(pouch_rect, Color(0.95, 0.78, 0.2, 0.08), true)
		ctrl.draw_rect(pouch_rect, Color(0.95, 0.78, 0.2, 0.65), false, 1.5)
		
	var line_col = Color(0.24, 0.28, 0.35, 0.7)
	for x in range(w + 1):
		ctrl.draw_line(Vector2(x * cell_size, 0), Vector2(x * cell_size, h * cell_size), line_col, 1.0)
	for y in range(h + 1):
		ctrl.draw_line(Vector2(0, y * cell_size), Vector2(w * cell_size, y * cell_size), line_col, 1.0)
		
	# 2. 배치된 아이템 렌더링
	for item in grid_mgr.items:
		if item.is_empty(): continue
		if is_dragging and (drag_data.get("source") == "grid" or drag_data.get("source") == "player_grid") and drag_data.get("item", {}).get("uid") == item.get("uid"):
			continue # 드래그 중인 원본은 투명하게 숨김
			
		var cur_w = item.get("h", 1) if item.get("rotated", false) else item.get("w", 1)
		var cur_h = item.get("w", 1) if item.get("rotated", false) else item.get("h", 1)
		var item_rect = Rect2(item.get("x", 0) * cell_size + 2, item.get("y", 0) * cell_size + 2, cur_w * cell_size - 4, cur_h * cell_size - 4)
		
		var item_bg = Color(0.18, 0.22, 0.28, 0.95) if is_player_grid else Color(0.16, 0.20, 0.24, 0.95)
		var item_border = Color(0.35, 0.65, 0.95, 0.9) if is_player_grid else Color(0.9, 0.7, 0.3, 0.9)
		ctrl.draw_rect(item_rect, item_bg, true)
		ctrl.draw_rect(item_rect, item_border, false, 1.5)
		
		# 아이콘
		var icon_tex = ItemIconManager.get_icon(item.get("id", "")) if ItemIconManager else null
		if icon_tex:
			var icon_size = Vector2(min(item_rect.size.x, item_rect.size.y) * 0.75, min(item_rect.size.x, item_rect.size.y) * 0.75)
			var icon_pos = item_rect.position + (item_rect.size - icon_size) / 2.0
			ctrl.draw_texture_rect(icon_tex, Rect2(icon_pos, icon_size), false)
			
		var font = ThemeDB.fallback_font
		# 수량
		var amt = item.get("amount", 1)
		if amt > 1:
			ctrl.draw_string(font, item_rect.position + Vector2(4, item_rect.size.y - 4), "x%d" % amt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 0.4))
			
		# 이름
		var d = ItemDatabase.get_item_data(item.get("id", ""))
		ctrl.draw_string(font, item_rect.position + Vector2(4, 12), d.get("name", item.get("id", "")), HORIZONTAL_ALIGNMENT_LEFT, item_rect.size.x - 8, 10, Color(0.9, 0.9, 0.9, 0.8))

	# 3. 드래그 중 고스트 프리뷰 (초록 / 빨강)
	if is_dragging and hovered_cell.x >= 0 and hovered_cell.y >= 0:
		var item = drag_data.get("item", {})
		var base_size = ItemDatabase.get_item_grid_size(item.get("id", ""))
		var base_w = item.get("w", base_size.x)
		var base_h = item.get("h", base_size.y)
		var is_rot = drag_data.get("rotated", false)
		var place_w = base_h if is_rot else base_w
		var place_h = base_w if is_rot else base_h
		
		var src = drag_data.get("source", "")
		var uid = item.get("uid", "")
		var ignore_uid = uid if (src == "grid" or src == ("player_grid" if is_player_grid else "stash_grid")) else ""
		var can_place = grid_mgr.can_place_item(place_w, place_h, hovered_cell.x, hovered_cell.y, ignore_uid)
		var ghost_rect = Rect2(hovered_cell.x * cell_size, hovered_cell.y * cell_size, place_w * cell_size, place_h * cell_size)
		
		var col = Color(0.2, 0.8, 0.3, 0.4) if can_place else Color(0.9, 0.2, 0.2, 0.4)
		var border_col = Color(0.3, 1.0, 0.4, 0.9) if can_place else Color(1.0, 0.3, 0.3, 0.9)
		
		ctrl.draw_rect(ghost_rect, col, true)
		ctrl.draw_rect(ghost_rect, border_col, false, 2.0)

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
			var cat = idata.get("category", -1)
			if slot_key.begins_with("primary"):
				is_compat = (cat == ItemDatabase.ItemCategory.WEAPON or idata.get("type", "") == "receiver" or eq_slot == "primary" or eq_slot == "")
			elif slot_key == "sidearm":
				is_compat = (idata.get("type", "") == "melee" or item_id.contains("권총") or item_id.begins_with("M9") or eq_slot == "sidearm" or eq_slot == "melee")
			elif slot_key == "throwable":
				is_compat = (item_id.contains("수류탄") or item_id.contains("연막") or item_id.contains("화염") or eq_slot == "throwable")
		elif t_type == "attachment":
			var attach_type = target.get("attach_type", "")
			var p_data = WeaponPartsDatabase.PARTS.get(item_id, {})
			is_compat = (p_data.get("slot", "") == attach_type)
			
		var sb: StyleBoxFlat
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
	var equipped = equipment_data.get(slot_name, {})
	if equipped.is_empty():
		btn.text = default_text
		btn.icon = null
	else:
		var item_id = equipped.get("id", "")
		var d = ItemDatabase.get_item_data(item_id)
		btn.text = d.get("name", item_id)
		if ItemIconManager:
			btn.icon = ItemIconManager.get_icon(item_id)
			btn.expand_icon = true
