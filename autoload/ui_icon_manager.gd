# res://autoload/ui_icon_manager.gd
extends Node

## 중앙 UI SVG 아이콘 매니저 (addons/at-icons 기반, 상황별 시맨틱 컬러 적용)
##
## 색상 폴더 규칙:
## - node3d    (#fc7f7f 빨강): 경고, 오류, 사망, 보스, 잠금, 출혈, 폭발, 삭제, 하드코어
## - control   (#8eef97 초록): 성공, 확인, 해제, 의료/회복, 생환, 탈출, 캐주얼, 구매
## - mesh      (#ffca5f 노랑): 자금, 별/위시리스트/숙련, 중요 알림, 전력, 보급, 골절, 시간
## - node2d    (#8da5f3 파랑): 통신/무전/스캔, 지도/나침반, 날씨, 정보, 방어/보험, 저장, 정렬
## - animation (#c38ef1 보라): 감염/생체, 샌드박스/치트, 풀턴/특수, 커스텀/모딩
## - node      (#e0e0e0 흰색): 일반 장비/무기, 도구, 건물, 설정, 중립 아이콘

const BASE_DIR: String = "res://addons/at-icons/"

const ICON_CATALOG: Dictionary = {
	# Warnings / Status / Feedback
	"warn": "node3d/danger",
	"error": "node3d/cross_in_circle",
	"close": "node3d/cross",
	"ok": "control/checkmark_in_square",
	"check": "control/checkmark",
	"info": "node2d/info",
	"tip": "mesh/lightbulb",
	"star": "mesh/star",
	"stars": "animation/stars",
	"trophy": "mesh/trophy",
	"medal": "mesh/medal",
	"medal_1st": "mesh/medal_1st",
	"celebrate": "control/trophy",

	# Security / Lock / Door
	"lock": "node3d/lock",
	"lock_gold": "mesh/lock",
	"unlock": "control/unlock",
	"key": "mesh/key",
	"door": "node/door",
	"door_exit": "control/doorway_exit",

	# Combat / Weapons / Danger
	"gun": "node/gun",
	"gun_gold": "mesh/gun",
	"ammo": "mesh/ammunition",
	"melee": "node/dagger",
	"swords": "node3d/swords",
	"fist": "node/fist",
	"bomb": "node3d/bomb",
	"grenade": "node3d/grenade",
	"explosion": "node3d/explosion",
	"fire": "node3d/fire",
	"target": "node3d/target",
	"target_blue": "node2d/target",
	"reticle": "node2d/reticle",
	"bullseye": "mesh/bullseye",
	"skull": "node3d/skull",
	"death": "node3d/skull_and_crossbones",
	"siren": "node3d/siren",
	"stealth": "animation/speaker_mute",
	"muted": "node2d/speaker_mute",
	"sound": "mesh/speaker",
	"laser": "node3d/laser",
	"flashlight": "mesh/torch",

	# Armor / Gear / Equipment
	"helmet": "node/armor_helmet",
	"vest": "node/armor_chestplate",
	"backpack": "node2d/backpack",
	"backpack_neutral": "node/backpack",
	"boots": "node/armor_boots",
	"shield": "node2d/shield",
	"shield_green": "control/shield",
	"shield_red": "node3d/shield",
	"nvg": "control/vr_headset",
	"scope": "node2d/telescope",
	"zoom": "node2d/magnifying_glass",
	"search": "node2d/magnifying_glass",
	"person": "control/person",
	"run": "control/person_run",

	# Medical / Survival Status
	"heart": "control/heart",
	"medkit": "control/medkit",
	"bandage": "control/bandages",
	"pill": "control/pill",
	"syringe": "control/syringe",
	"bleed": "node3d/droplet",
	"fracture": "mesh/bone_fracture",
	"biohazard": "animation/radioactive_symbol",
	"dna": "animation/dna",

	# Loot / Storage / Inventory Actions
	"box": "mesh/box",
	"loot": "control/box",
	"stash": "mesh/storage",
	"folder": "node2d/folder_open",
	"export_out": "node2d/arrow_up_from_bracket",
	"deposit_all": "node2d/fast_forward",
	"refresh": "node2d/arrows_clockwise",
	"reload": "node2d/arrow_clockwise",
	"split": "node/scissors",
	"trash": "node3d/trash_can",
	"broom": "mesh/eraser",
	"gift": "mesh/gift",
	"airdrop": "mesh/delivery_box",
	"drone": "node2d/airplane",
	"fulton": "animation/balloon",
	"extract": "control/airplane",
	"vehicle": "mesh/car",

	# Economy / Traders / Market
	"money": "mesh/coins",
	"money_green": "control/coin",
	"shop": "mesh/shop",
	"cart": "control/shopping_cart",
	"receipt": "node/file_document",
	"chart_up": "control/line_graph",
	"chart_down": "node3d/line_graph",
	"stats": "node2d/bar_graph",
	"tag": "node2d/tag",

	# Tools / Crafting / Modding / Facilities
	"settings": "node/cog",
	"wrench": "node/wrench",
	"wrench_blue": "node2d/wrench",
	"tools": "animation/wrench",
	"hammer": "mesh/hammer",
	"bolt": "node/nut_and_bolt",
	"toolbox": "node/briefcase",
	"preset": "node2d/set_square",
	"save": "control/floppy_disk",
	"facility": "mesh/crane",
	"upgrade": "control/arrow_up",
	"weight": "node/scales",

	# Radio / Map / World / Weather / Time
	"radio": "node2d/signal_wave",
	"signal": "node2d/satellite",
	"power": "mesh/lightning_bolt",
	"weather": "node2d/sun_cloud",
	"sunrise": "mesh/sun",
	"moon": "animation/moon",
	"map": "node2d/map",
	"globe": "node2d/globe",
	"clock": "node/clock",
	"stopwatch": "node2d/stopwatch",
	"hourglass": "mesh/hourglass",
	"bunker": "node2d/hexagon",

	# Buildings / Documents
	"house": "node/house",
	"building": "node/building",
	"hospital": "control/medkit",
	"military": "node3d/armor_helmet",
	"clipboard": "node2d/clipboard",
	"book": "node2d/book_open",

	# Difficulty / Launch
	"rocket": "control/rocketship",
	"diff_casual": "control/circle",
	"diff_standard": "mesh/circle",
	"diff_hardcore": "node3d/circle",
	"diff_custom": "animation/sliders",
	"sandbox": "animation/sliders",
}

const EQUIP_SLOT_ICON_MAP: Dictionary = {
	"helmet": "helmet",
	"vest": "vest",
	"backpack": "backpack",
	"bottom": "boots",
	"primary1": "gun",
	"primary2": "gun",
	"sidearm": "melee",
	"throwable": "bomb",
}

var _texture_cache: Dictionary = {}
var _tag_regex: RegEx = null


func _ready() -> void:
	_ensure_regex()


func _ensure_regex() -> void:
	if _tag_regex == null:
		_tag_regex = RegEx.new()
		_tag_regex.compile("\\[icon:([a-z0-9_]+)\\]")


func has_icon(key: String) -> bool:
	return ICON_CATALOG.has(key)


func get_icon_path(key: String) -> String:
	if key == "":
		return ""
	if ICON_CATALOG.has(key):
		return BASE_DIR + String(ICON_CATALOG[key]) + ".svg"
	if key.contains("/"):
		var direct := BASE_DIR + key + ("" if key.ends_with(".svg") else ".svg")
		if ResourceLoader.exists(direct):
			return direct
	return ""


func get_icon(key: String) -> Texture2D:
	if key == "":
		return null
	if _texture_cache.has(key):
		return _texture_cache[key]
	var path := get_icon_path(key)
	if path == "" or not ResourceLoader.exists(path):
		push_warning("UiIconManager: missing icon key '%s' (%s)" % [key, path])
		return null
	var tex: Texture2D = load(path) as Texture2D
	if tex != null:
		_texture_cache[key] = tex
	return tex


func get_equip_slot_icon_key(slot_name: String) -> String:
	return String(EQUIP_SLOT_ICON_MAP.get(slot_name, "box"))


func get_equip_slot_icon(slot_name: String) -> Texture2D:
	return get_icon(get_equip_slot_icon_key(slot_name))


func bbcode_icon(key: String, icon_size: int = 14) -> String:
	var path := get_icon_path(key)
	if path == "":
		return ""
	return "[img=%dx%d]%s[/img]" % [icon_size, icon_size, path]


func create_icon_rect(key: String, icon_size: int = 16) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = "UiIcon"
	rect.texture = get_icon(key)
	rect.custom_minimum_size = Vector2(icon_size, icon_size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func apply_button_icon(btn: Button, key: String, text_str: String = "", icon_size: int = 16, update_text: bool = false) -> void:
	if not is_instance_valid(btn):
		return
	btn.icon = get_icon(key) if key != "" else null
	btn.expand_icon = false
	btn.add_theme_constant_override("icon_max_width", icon_size)
	btn.add_theme_constant_override("h_separation", 6)
	if update_text or text_str != "":
		btn.text = text_str


func set_button(btn: Button, key: String, text_str: String, icon_size: int = 16) -> void:
	apply_button_icon(btn, key, text_str, icon_size, true)


func set_tab_icon(tab_container: TabContainer, tab_idx: int, key: String) -> void:
	if not is_instance_valid(tab_container):
		return
	if tab_idx < 0 or tab_idx >= tab_container.get_tab_count():
		return
	tab_container.set_tab_icon(tab_idx, get_icon(key))


func set_tab_icon_by_control(tab_container: TabContainer, tab_ctrl: Control, key: String) -> void:
	if not is_instance_valid(tab_container) or not is_instance_valid(tab_ctrl):
		return
	var idx := tab_container.get_tab_idx_from_control(tab_ctrl)
	if idx >= 0:
		tab_container.set_tab_icon(idx, get_icon(key))


func create_icon_label(
	key: String,
	text_str: String,
	font_size: int = 12,
	font_color: Color = Color(0.92, 0.94, 0.96),
	icon_size: int = 16,
	gap: int = 5
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", gap)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_rect := create_icon_rect(key, icon_size)
	icon_rect.visible = (key != "")
	row.add_child(icon_rect)

	var lbl := Label.new()
	lbl.name = "Label"
	lbl.text = text_str
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", font_color)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	lbl.set_meta(&"_ui_icon_rect", icon_rect)
	lbl.set_meta(&"_ui_icon_row", row)
	return row


func set_label_icon(
	label: Label,
	key: String,
	text_str: String = "",
	icon_size: int = 16,
	gap: int = 5,
	update_text: bool = false
) -> HBoxContainer:
	if not is_instance_valid(label):
		return null

	if label.has_meta(&"_ui_icon_rect") and label.has_meta(&"_ui_icon_row"):
		var existing_rect: TextureRect = label.get_meta(&"_ui_icon_rect") as TextureRect
		var existing_row: HBoxContainer = label.get_meta(&"_ui_icon_row") as HBoxContainer
		if is_instance_valid(existing_rect) and is_instance_valid(existing_row):
			if key == "":
				existing_rect.visible = false
				existing_rect.texture = null
			else:
				existing_rect.texture = get_icon(key)
				existing_rect.custom_minimum_size = Vector2(icon_size, icon_size)
				existing_rect.visible = true
			if update_text or text_str != "":
				label.text = text_str
			if existing_row.visible != label.visible:
				existing_row.visible = label.visible
			return existing_row

	var parent := label.get_parent()
	if parent == null:
		if update_text or text_str != "":
			label.text = text_str
		return null

	var row := HBoxContainer.new()
	row.name = label.name + "_IconRow"
	row.add_theme_constant_override("separation", gap)
	row.mouse_filter = label.mouse_filter
	row.visible = label.visible
	row.z_index = label.z_index

	var uses_bounded_width := label.clip_text or label.autowrap_mode != TextServer.AUTOWRAP_OFF
	if parent is Container:
		row.size_flags_horizontal = label.size_flags_horizontal
		row.size_flags_vertical = label.size_flags_vertical
		row.size_flags_stretch_ratio = label.size_flags_stretch_ratio
		if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if uses_bounded_width else Control.SIZE_SHRINK_CENTER
		elif label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
			row.alignment = BoxContainer.ALIGNMENT_END
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if uses_bounded_width else Control.SIZE_SHRINK_END
		else:
			row.alignment = BoxContainer.ALIGNMENT_BEGIN
			if uses_bounded_width or (label.size_flags_horizontal & Control.SIZE_EXPAND) != 0:
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			else:
				label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	else:
		row.anchor_left = label.anchor_left
		row.anchor_top = label.anchor_top
		row.anchor_right = label.anchor_right
		row.anchor_bottom = label.anchor_bottom
		row.offset_left = label.offset_left
		row.offset_top = label.offset_top
		row.offset_right = label.offset_right
		row.offset_bottom = label.offset_bottom
		row.grow_horizontal = label.grow_horizontal
		row.grow_vertical = label.grow_vertical
		if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
			row.alignment = BoxContainer.ALIGNMENT_CENTER
		elif label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
			row.alignment = BoxContainer.ALIGNMENT_END
		else:
			row.alignment = BoxContainer.ALIGNMENT_BEGIN
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL if uses_bounded_width else Control.SIZE_SHRINK_CENTER
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var orig_idx := label.get_index()
	parent.add_child(row)
	parent.move_child(row, orig_idx)

	var icon_rect := create_icon_rect(key, icon_size)
	icon_rect.visible = (key != "")
	row.add_child(icon_rect)

	label.reparent(row, false)
	if label.vertical_alignment == VERTICAL_ALIGNMENT_TOP:
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	label.set_meta(&"_ui_icon_rect", icon_rect)
	label.set_meta(&"_ui_icon_row", row)
	label.visibility_changed.connect(func():
		if is_instance_valid(row) and is_instance_valid(label):
			if row.visible != label.visible:
				row.visible = label.visible
	)

	if update_text or text_str != "":
		label.text = text_str
	return row


func sync_label_row_visibility(label: Label, vis: bool) -> void:
	if not is_instance_valid(label):
		return
	label.visible = vis
	if label.has_meta(&"_ui_icon_row"):
		var row: Control = label.get_meta(&"_ui_icon_row") as Control
		if is_instance_valid(row):
			row.visible = vis


func get_toast_colors(icon_key: String) -> Dictionary:
	var accent := Color(1.0, 0.80, 0.22)
	var font := Color(0.92, 0.94, 0.96)
	match icon_key:
		"star", "trophy", "medal", "medal_1st", "celebrate", "money", "money_green", "airdrop", "drone", "fulton", "gift", "power", "fire", "vehicle", "sunrise":
			accent = Color(1.0, 0.82, 0.24)
			font = Color(1.0, 0.91, 0.45)
		"ok", "check", "loot", "box", "pill", "medkit", "bandage", "heart", "unlock", "shield_green", "extract", "run", "save", "upgrade":
			accent = Color(0.30, 0.90, 0.45)
			font = Color(0.64, 1.0, 0.68)
		"warn", "error", "close", "skull", "death", "lock", "bomb", "grenade", "explosion", "siren", "bleed", "shield_red", "trash", "biohazard":
			accent = Color(0.92, 0.30, 0.30)
			font = Color(1.0, 0.55, 0.55)
		"info", "radio", "signal", "weather", "moon", "tip", "nvg", "refresh", "reload", "wrench", "wrench_blue", "bolt", "hammer", "tools", "sandbox", "stars", "gun", "helmet", "door", "hourglass":
			accent = Color(0.35, 0.72, 1.0)
			font = Color(0.66, 0.88, 1.0)
	return {"accent": accent, "font": font}


func parse_tagged_message(msg: String, inline_icon_size: int = 13) -> Dictionary:
	_ensure_regex()
	var work := msg.strip_edges()
	var leading_keys: Array[String] = []

	while work.begins_with("[icon:"):
		var close_idx := work.find("]")
		if close_idx <= 6:
			break
		var key := work.substr(6, close_idx - 6).strip_edges()
		if key != "":
			leading_keys.append(key)
		work = work.substr(close_idx + 1).strip_edges()

	var primary_key: String = leading_keys[0] if not leading_keys.is_empty() else ""
	var has_inline: bool = _tag_regex.search(work) != null
	var clean_text := work
	var body_bbcode := work

	if has_inline:
		clean_text = _tag_regex.sub(work, "", true).strip_edges()
		var out_bb := ""
		var cursor := 0
		for m in _tag_regex.search_all(work):
			out_bb += work.substr(cursor, m.get_start() - cursor)
			var inline_key := m.get_string(1)
			var bb := bbcode_icon(inline_key, inline_icon_size)
			out_bb += bb if bb != "" else ""
			cursor = m.get_end()
		out_bb += work.substr(cursor)
		body_bbcode = out_bb

	var cols := get_toast_colors(primary_key)
	return {
		"icon_key": primary_key,
		"icon_keys": leading_keys,
		"clean_text": clean_text,
		"body_bbcode": body_bbcode,
		"has_inline_icons": has_inline,
		"accent_color": cols["accent"],
		"font_color": cols["font"],
	}


func replace_tags_with_bbcode(text_str: String, icon_size: int = 14) -> String:
	_ensure_regex()
	var out := ""
	var cursor := 0
	for m in _tag_regex.search_all(text_str):
		out += text_str.substr(cursor, m.get_start() - cursor)
		var key := m.get_string(1)
		out += bbcode_icon(key, icon_size)
		cursor = m.get_end()
	out += text_str.substr(cursor)
	return out


func validate_all_icons() -> Dictionary:
	var missing: Array[String] = []
	for key in ICON_CATALOG.keys():
		var path := get_icon_path(String(key))
		if path == "" or not ResourceLoader.exists(path):
			missing.append("%s -> %s" % [String(key), path])
	return {
		"total": ICON_CATALOG.size(),
		"missing": missing,
	}
