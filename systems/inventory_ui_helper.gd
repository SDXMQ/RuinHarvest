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

static func draw_2d_grid(ctrl: Control, grid_mgr: InventoryGrid, hovered_cell: Vector2i, is_player_grid: bool, is_dragging: bool = false, drag_data: Dictionary = {}, cell_size: float = CELL_SIZE) -> void:
	if not ctrl or not grid_mgr: return
	
	var w = grid_mgr.grid_width
	var h = grid_mgr.grid_height
	var font = ThemeDB.fallback_font
	
	# 0. 전체 그리드 베이스 배경
	var full_rect = Rect2(0, 0, w * cell_size, h * cell_size)
	ctrl.draw_rect(full_rect, Color(0.055, 0.065, 0.085, 0.92), true)
	
	# 1. 배경 격자선 및 플레이어 배낭 좌상단 2x2 안전 컨테이너(Secure Pouch) 구역 표시
	if is_player_grid and w >= 2 and h >= 2:
		var pouch_rect = Rect2(0, 0, 2 * cell_size, 2 * cell_size)
		ctrl.draw_rect(pouch_rect, Color(0.92, 0.68, 0.22, 0.07), true)
		ctrl.draw_rect(pouch_rect, Color(0.92, 0.68, 0.22, 0.55), false, 1.5)
		ctrl.draw_string(font, Vector2(4, 2 * cell_size - 5), "SECURE", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.92, 0.68, 0.22, 0.35))
		
	var line_col = Color(0.19, 0.23, 0.29, 0.85)
	for x in range(w + 1):
		ctrl.draw_line(Vector2(x * cell_size, 0), Vector2(x * cell_size, h * cell_size), line_col, 1.0)
	for y in range(h + 1):
		ctrl.draw_line(Vector2(0, y * cell_size), Vector2(w * cell_size, y * cell_size), line_col, 1.0)
		
	# 마우스 호버 셀 미세 하이라이트 (비드래그 상태)
	if not is_dragging and hovered_cell.x >= 0 and hovered_cell.x < w and hovered_cell.y >= 0 and hovered_cell.y < h:
		var hover_cell_rect = Rect2(hovered_cell.x * cell_size + 1, hovered_cell.y * cell_size + 1, cell_size - 2, cell_size - 2)
		ctrl.draw_rect(hover_cell_rect, Color(0.88, 0.65, 0.22, 0.08), true)
		
	# 2. 배치된 아이템 렌더링
	for item in grid_mgr.items:
		if item.is_empty(): continue
		if is_dragging and (drag_data.get("source") == "grid" or drag_data.get("source") == "player_grid") and drag_data.get("item", {}).get("uid") == item.get("uid"):
			continue # 드래그 중인 원본은 투명하게 숨김
			
		var cur_w = item.get("h", 1) if item.get("rotated", false) else item.get("w", 1)
		var cur_h = item.get("w", 1) if item.get("rotated", false) else item.get("h", 1)
		var item_rect = Rect2(item.get("x", 0) * cell_size + 2, item.get("y", 0) * cell_size + 2, cur_w * cell_size - 4, cur_h * cell_size - 4)
		
		var d = ItemDatabase.get_item_data(item.get("id", ""))
		var rarity = d.get("rarity", 0.5)
		var rarity_accent = Color(0.45, 0.55, 0.68, 0.9)
		if rarity <= 0.05:
			rarity_accent = Color(0.96, 0.74, 0.22, 0.95)
		elif rarity <= 0.15:
			rarity_accent = Color(0.75, 0.42, 0.95, 0.95)
		elif rarity <= 0.35:
			rarity_accent = Color(0.35, 0.72, 0.98, 0.95)
			
		var item_bg = Color(0.12, 0.145, 0.185, 0.96) if is_player_grid else Color(0.11, 0.13, 0.165, 0.96)
		var item_border = Color(0.28, 0.35, 0.44, 0.95)
		ctrl.draw_rect(item_rect, item_bg, true)
		ctrl.draw_rect(item_rect, item_border, false, 1.0)
		# 좌측 상단 희귀도 액센트 바
		ctrl.draw_rect(Rect2(item_rect.position.x, item_rect.position.y, 3.0, item_rect.size.y), rarity_accent, true)
		
		# 아이콘
		var icon_tex = ItemIconManager.get_icon(item.get("id", "")) if ItemIconManager else null
		if icon_tex:
			var icon_size = Vector2(min(item_rect.size.x, item_rect.size.y) * 0.72, min(item_rect.size.x, item_rect.size.y) * 0.72)
			var icon_pos = item_rect.position + (item_rect.size - icon_size) / 2.0
			ctrl.draw_texture_rect(icon_tex, Rect2(icon_pos, icon_size), false)
			
		# 수량
		var amt = item.get("amount", 1)
		if amt > 1:
			ctrl.draw_string(font, item_rect.position + Vector2(6, item_rect.size.y - 4), "x%d" % amt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.98, 0.82, 0.32))
			
		# 이름
		ctrl.draw_string(font, item_rect.position + Vector2(6, 12), d.get("name", item.get("id", "")), HORIZONTAL_ALIGNMENT_LEFT, item_rect.size.x - 10, 10, Color(0.88, 0.91, 0.95, 0.9))

		# 총기류 탄약 표기 (우하단: cur/max, 잔탄 0: 적색, 잔탄 보유: 연녹색)
		var item_id_str = str(item.get("id", ""))
		var cat = d.get("category", -1)
		var item_type_str = str(d.get("type", item.get("type", "")))
		var is_non_gun = d.get("stackable", false) or item_type_str in ["melee", "ammo", "throwable", "part"] or item_id_str in ["나이프", "파이프", "도끼", "야구방망이", "탄약", "수류탄", "연막탄", "화염병"] or WeaponPartsDatabase.AMMO_TYPES.has(item_id_str) or WeaponPartsDatabase.PARTS.has(item_id_str)
		var is_gun = not is_non_gun and (WeaponPartsDatabase.is_modifiable_weapon(item) or item.has("parts") or item_type_str in ["receiver", "assembled_weapon", "ranged"] or item.has("current_magazine_ammo"))
		if is_gun:
			var max_ammo = 30
			if item.has("computed_stats") and item["computed_stats"].has("magazine_size"):
				max_ammo = int(item["computed_stats"]["magazine_size"])
			elif item.has("parts"):
				var stats = WeaponPartsDatabase.compute_weapon_stats(item_id_str, item.get("parts", {}))
				max_ammo = int(stats.get("magazine_size", 30))
			elif d.has("magazine_size"):
				max_ammo = int(d["magazine_size"])
			elif d.has("ammo"):
				max_ammo = 30
			var cur_ammo = int(item.get("current_magazine_ammo", max_ammo))
			var ammo_str = "%d/%d" % [cur_ammo, max_ammo]
			var ammo_col = Color(0.4, 1.0, 0.6) if cur_ammo > 0 else Color(1.0, 0.25, 0.25)
			var font_sz = 9
			var text_w = 42.0
			ctrl.draw_string(font, item_rect.position + Vector2(item_rect.size.x - text_w - 4, item_rect.size.y - 4), ammo_str, HORIZONTAL_ALIGNMENT_RIGHT, text_w, font_sz, ammo_col)

		# 방어구/헬멧 내구도 바 표기 (셀 하단)
		var is_armor = cat == ItemDatabase.ItemCategory.EQUIPMENT and (d.get("equip_slot") in ["vest", "helmet"] or item_id_str.contains("방탄") or item_id_str.contains("헬멧") or item_id_str.contains("조끼") or item_id_str.contains("방독면"))
		if is_armor:
			var max_dur = float(item.get("max_durability", d.get("max_durability", 100.0)))
			if max_dur > 0.0:
				var cur_dur = float(item.get("durability", max_dur))
				var ratio = clamp(cur_dur / max_dur, 0.0, 1.0)
				var bar_w = item_rect.size.x - 6.0
				var bar_h = 3.0
				var bar_rect = Rect2(item_rect.position.x + 3.0, item_rect.position.y + item_rect.size.y - bar_h - 2.0, bar_w, bar_h)
				ctrl.draw_rect(bar_rect, Color(0.1, 0.12, 0.15, 0.85), true)
				var dur_col = Color(0.25, 0.85, 0.4, 0.95)
				if ratio < 0.25:
					dur_col = Color(0.95, 0.25, 0.25, 0.95)
				elif ratio < 0.6:
					dur_col = Color(0.95, 0.75, 0.2, 0.95)
				if ratio > 0.0:
					ctrl.draw_rect(Rect2(bar_rect.position.x, bar_rect.position.y, bar_w * ratio, bar_h), dur_col, true)

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
		var can_place = grid_mgr.can_place_item(place_w, place_h, hovered_cell.x, hovered_cell.y, ignore_uid, item.get("id", ""))
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
	var dur_bar: ProgressBar = btn.get_node_or_null("SlotDurabilityBar") as ProgressBar
	if equipped.is_empty():
		btn.text = default_text
		btn.icon = null
		if dur_bar:
			dur_bar.visible = false
	else:
		var item_id = str(equipped.get("id", ""))
		var d = ItemDatabase.get_item_data(item_id)
		var disp_name = str(equipped.get("name", ""))
		if disp_name == "" or disp_name == item_id:
			var d_name = str(d.get("name", item_id))
			if d_name == item_id and WeaponPartsDatabase.RECEIVERS.has(item_id):
				d_name = str(WeaponPartsDatabase.RECEIVERS[item_id].get("name", item_id))
			disp_name = d_name
		btn.text = disp_name
		if ItemIconManager:
			btn.icon = ItemIconManager.get_icon(item_id)
			btn.expand_icon = true
		var max_dur = float(equipped.get("max_durability", d.get("max_durability", 0.0)))
		if (slot_name in ["helmet", "vest"] or equipped.has("durability")) and max_dur > 0.0:
			var cur_dur = clamp(float(equipped.get("durability", max_dur)), 0.0, max_dur)
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
				var bg_style = StyleBoxFlat.new()
				bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.65)
				dur_bar.add_theme_stylebox_override("background", bg_style)
				btn.add_child(dur_bar)
			dur_bar.max_value = max_dur
			dur_bar.value = cur_dur
			var ratio = cur_dur / max_dur
			var fill_style = StyleBoxFlat.new()
			fill_style.bg_color = Color(0.2, 0.85, 0.3) if ratio > 0.5 else (Color(0.9, 0.7, 0.1) if ratio > 0.25 else Color(0.9, 0.2, 0.2))
			dur_bar.add_theme_stylebox_override("fill", fill_style)
			dur_bar.visible = true
		elif dur_bar:
			dur_bar.visible = false
