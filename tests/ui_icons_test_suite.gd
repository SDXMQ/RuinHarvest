# res://tests/ui_icons_test_suite.gd
extends Node

var _passed: int = 0
var _failed: int = 0

func _assert(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("[PASS] %s" % label)
	else:
		_failed += 1
		printerr("[FAIL] %s" % label)

func run_all() -> void:
	await get_tree().process_frame
	_test_catalog_and_textures()
	_test_semantic_color_folders()
	_test_tag_parser_and_toast_colors()
	_test_ui_helpers()
	_test_zero_emoji_and_valid_tags()
	await _test_scene_smoke_instantiation()

	print("=== UI Icon Regression Summary: %d passed, %d failed ===" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)

func _test_catalog_and_textures() -> void:
	print("-- [UI Icons 1] Catalog & Texture Resolution --")
	_assert(UiIconManager != null, "UiIconManager autoload is active")
	var report: Dictionary = UiIconManager.validate_all_icons()
	var missing: Array = report.get("missing", [])
	_assert(missing.is_empty(), "validate_all_icons() reports 0 missing SVGs (missing=%s)" % str(missing))
	_assert(int(report.get("total", 0)) >= 120, "ICON_CATALOG registers >= 120 semantic icon keys (total=%d)" % int(report.get("total", 0)))

	var invalid_tex_keys: Array[String] = []
	for k in UiIconManager.ICON_CATALOG.keys():
		var tex: Texture2D = UiIconManager.get_icon(str(k))
		if tex == null or tex.get_width() <= 0 or tex.get_height() <= 0:
			invalid_tex_keys.append(str(k))
	_assert(invalid_tex_keys.is_empty(), "Every ICON_CATALOG key loads a valid Texture2D (invalid=%s)" % str(invalid_tex_keys))

	var invalid_slots: Array[String] = []
	for slot_k in UiIconManager.EQUIP_SLOT_ICON_MAP.keys():
		var stex: Texture2D = UiIconManager.get_equip_slot_icon(str(slot_k))
		if stex == null or stex.get_width() <= 0:
			invalid_slots.append(str(slot_k))
	_assert(invalid_slots.is_empty(), "Every EQUIP_SLOT_ICON_MAP slot resolves a valid Texture2D (invalid=%s)" % str(invalid_slots))

	var bb: String = UiIconManager.bbcode_icon("star", 14)
	_assert(bb == "[img=14x14]res://addons/at-icons/mesh/star.svg[/img]", "bbcode_icon('star', 14) emits expected BBCode img tag")

func _test_semantic_color_folders() -> void:
	print("-- [UI Icons 2] Contextual Semantic Color Folders --")
	_assert(UiIconManager.get_icon_path("warn").contains("/node3d/"), "Danger/warn maps to red node3d folder")
	_assert(UiIconManager.get_icon_path("skull").contains("/node3d/"), "Boss/skull maps to red node3d folder")
	_assert(UiIconManager.get_icon_path("lock").contains("/node3d/"), "Lock maps to red node3d folder")
	_assert(UiIconManager.get_icon_path("ok").contains("/control/"), "Success/ok maps to green control folder")
	_assert(UiIconManager.get_icon_path("medkit").contains("/control/"), "Medkit maps to green control folder")
	_assert(UiIconManager.get_icon_path("diff_casual").contains("/control/"), "Casual preset maps to green control folder")
	_assert(UiIconManager.get_icon_path("star").contains("/mesh/"), "Wishlist/star maps to gold mesh folder")
	_assert(UiIconManager.get_icon_path("money").contains("/mesh/"), "Currency/money maps to gold mesh folder")
	_assert(UiIconManager.get_icon_path("diff_standard").contains("/mesh/"), "Standard preset maps to gold mesh folder")
	_assert(UiIconManager.get_icon_path("radio").contains("/node2d/"), "Radio maps to blue node2d folder")
	_assert(UiIconManager.get_icon_path("map").contains("/node2d/"), "Tactical map maps to blue node2d folder")
	_assert(UiIconManager.get_icon_path("biohazard").contains("/animation/"), "Biohazard maps to purple animation folder")
	_assert(UiIconManager.get_icon_path("sandbox").contains("/animation/"), "Sandbox maps to purple animation folder")
	_assert(UiIconManager.get_icon_path("gun").contains("/node/"), "Neutral gun icon maps to white node folder")
	_assert(UiIconManager.get_icon_path("settings").contains("/node/"), "Neutral settings icon maps to white node folder")

func _test_tag_parser_and_toast_colors() -> void:
	print("-- [UI Icons 3] Tag Parser & Semantic Toast Colors --")
	var p1: Dictionary = UiIconManager.parse_tagged_message("[icon:warn] 가방 공간이 부족합니다.")
	_assert(p1["icon_key"] == "warn", "Single leading tag parses icon_key='warn'")
	_assert(p1["clean_text"] == "가방 공간이 부족합니다.", "Single leading tag strips prefix cleanly")
	_assert((p1["accent_color"] as Color).r > 0.8 and (p1["accent_color"] as Color).g < 0.4, "Warn tag resolves red toast accent color")

	var p2: Dictionary = UiIconManager.parse_tagged_message("[icon:star][icon:drone] 군용 항공 보급 투하!")
	var p2_keys: Array = p2["icon_keys"]
	_assert(p2_keys.size() == 2 and p2_keys[0] == "star" and p2_keys[1] == "drone", "Dual leading tags parse both keys in order")
	_assert(p2["clean_text"] == "군용 항공 보급 투하!", "Dual leading tags strip cleanly")
	_assert((p2["accent_color"] as Color).r > 0.9 and (p2["accent_color"] as Color).g > 0.7, "Star tag resolves gold toast accent color")

	var p3: Dictionary = UiIconManager.parse_tagged_message("[icon:airdrop] 보급품 [icon:skull] 보스 출현", 13)
	_assert(p3["icon_key"] == "airdrop", "Inline message parses leading icon_key='airdrop'")
	_assert(bool(p3["has_inline_icons"]), "Inline message sets has_inline_icons=true")
	_assert(String(p3["body_bbcode"]).contains("[img=13x13]res://addons/at-icons/node3d/skull.svg[/img]"), "Inline message converts embedded tag to BBCode img")
	_assert(not String(p3["clean_text"]).contains("[icon:"), "Inline message clean_text strips all [icon:...] tags")

	var p4: Dictionary = UiIconManager.parse_tagged_message("일반 알림 텍스트")
	_assert(p4["icon_key"] == "" and (p4["icon_keys"] as Array).is_empty(), "Plain message has empty icon_key and icon_keys")
	_assert(p4["clean_text"] == "일반 알림 텍스트", "Plain message preserves text unchanged")

	var replaced: String = UiIconManager.replace_tags_with_bbcode("[icon:check] 완료 / [icon:lock] 잠금", 12)
	_assert(replaced.contains("control/checkmark.svg") and replaced.contains("node3d/lock.svg"), "replace_tags_with_bbcode expands multiple tags")

func _test_ui_helpers() -> void:
	print("-- [UI Icons 4] UI Helper Wrapping & Reuse --")
	var host := VBoxContainer.new()
	add_child(host)
	var lbl := Label.new()
	lbl.name = "TestTitle"
	lbl.text = "초기 텍스트"
	host.add_child(lbl)

	var row1: HBoxContainer = UiIconManager.set_label_icon(lbl, "radio", "무전 연결", 16, 5, true)
	_assert(row1 != null and lbl.get_parent() == row1 and row1.get_parent() == host, "set_label_icon wraps Label in HBoxContainer under original parent")
	_assert(lbl.text == "무전 연결", "set_label_icon updates text when update_text=true")

	var row2: HBoxContainer = UiIconManager.set_label_icon(lbl, "check", "연결 성공", 16, 5, true)
	_assert(row2 == row1, "Repeated set_label_icon reuses existing HBoxContainer without double-wrapping")
	_assert(host.get_child_count() == 1, "Parent child count remains 1 after repeated set_label_icon")

	lbl.visible = false
	_assert(not row1.visible, "Hiding wrapped Label automatically hides its IconRow")
	lbl.visible = true
	_assert(row1.visible, "Showing wrapped Label automatically shows its IconRow")

	var btn := Button.new()
	host.add_child(btn)
	UiIconManager.set_button(btn, "rocket", "출격", 16)
	_assert(btn.icon == UiIconManager.get_icon("rocket") and btn.text == "출격", "set_button assigns SVG texture and label text")

	var rect: TextureRect = UiIconManager.create_icon_rect("star", 14)
	_assert(rect.texture == UiIconManager.get_icon("star") and rect.custom_minimum_size == Vector2(14, 14), "create_icon_rect builds sized TextureRect")
	rect.free()
	host.queue_free()

func _strip_gd_comment(line: String) -> String:
	var in_s := false
	var in_d := false
	var esc := false
	for i in range(line.length()):
		var ch := line.substr(i, 1)
		if esc:
			esc = false
			continue
		if ch == "\\":
			esc = true
			continue
		if ch == "\"" and not in_s:
			in_d = not in_d
		elif ch == "'" and not in_d:
			in_s = not in_s
		elif ch == "#" and not in_s and not in_d:
			return line.substr(0, i)
	return line

func _has_emoji_char(text: String) -> bool:
	for i in range(text.length()):
		var cp: int = text.unicode_at(i)
		if (cp >= 0x1F300 and cp <= 0x1FAFF) \
			or (cp >= 0x2600 and cp <= 0x27BF) \
			or cp == 0x2B50 or cp == 0x2B55 \
			or (cp >= 0x231A and cp <= 0x23FA) \
			or cp == 0xFE0F \
			or cp == 0x2605 or cp == 0x2606 \
			or cp == 0x2713 or cp == 0x2714 or cp == 0x2715 or cp == 0x2716:
			return true
	return false

func _collect_files(dir_path: String, out: Array[String]) -> void:
	var da := DirAccess.open(dir_path)
	if da == null:
		return
	da.list_dir_begin()
	var fname := da.get_next()
	while fname != "":
		if not fname.begins_with("."):
			var full := dir_path.path_join(fname)
			if da.current_is_dir():
				_collect_files(full, out)
			elif fname.ends_with(".gd") or fname.ends_with(".tscn"):
				out.append(full)
		fname = da.get_next()
	da.list_dir_end()

func _test_zero_emoji_and_valid_tags() -> void:
	print("-- [UI Icons 5] Zero-Emoji & Valid Tag Audit --")
	var files: Array[String] = []
	for root_dir in ["res://autoload", "res://scenes", "res://systems", "res://world"]:
		_collect_files(root_dir, files)
	_assert(files.size() >= 40, "Scanned >= 40 project source/scene files (scanned=%d)" % files.size())

	var tag_re := RegEx.new()
	tag_re.compile("\\[icon:([a-z0-9_]+)\\]")

	var emoji_hits: Array[String] = []
	var bad_tag_hits: Array[String] = []

	for path in files:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var is_gd := path.ends_with(".gd")
		var line_no := 0
		while not f.eof_reached():
			line_no += 1
			var line := f.get_line()
			var code := _strip_gd_comment(line) if is_gd else line
			if _has_emoji_char(code):
				emoji_hits.append("%s:%d" % [path, line_no])
			if is_gd and code.contains("[icon:"):
				for m in tag_re.search_all(code):
					var k := m.get_string(1)
					if not UiIconManager.has_icon(k):
						bad_tag_hits.append("%s:%d (%s)" % [path, line_no, k])
		f.close()

	_assert(emoji_hits.is_empty(), "Zero non-comment emojis remain across autoload/scenes/systems/world (hits=%s)" % str(emoji_hits))
	_assert(bad_tag_hits.is_empty(), "Zero invalid [icon:...] keys exist in project code (bad=%s)" % str(bad_tag_hits))

func _make_smoke_world_data() -> Dictionary:
	var m4: Dictionary = WeaponPartsDatabase.create_default_weapon("M4_리시버")
	return {
		"world_name": "IconSmokeWorld",
		"current_day": 2,
		"difficulty": "normal",
		"world_settings": {"mode": "sandbox", "sandbox_mode": true, "raid_duration_minutes": 30.0},
		"player": {
			"rubles": 50000,
			"inventory": [],
			"equipment": {
				"helmet": {},
				"vest": {},
				"backpack": {},
				"bottom": {},
				"primary1": m4,
				"primary2": {},
				"sidearm": {},
				"throwable": {},
			},
			"equipment_initialized": true,
			"insured": false,
		},
		"hideout": {
			"stash": [],
			"upgrades": {"stash_expansion": 0, "med_station": 0, "bitcoin_farm": 0, "intel_center": 0},
			"completed_quests": [],
			"trader_stats": {},
		},
	}

func _test_scene_smoke_instantiation() -> void:
	print("-- [UI Icons 6] Scene Instantiation Smoke Checks --")
	GameManager.current_world_data = _make_smoke_world_data()
	GameManager.current_state = GameManager.GameState.HIDEOUT

	var packed_paths := [
		"res://scenes/main_menu/main_menu.tscn",
		"res://scenes/main_menu/new_game_custom_window.tscn",
		"res://scenes/main_menu/sandbox_menu.tscn",
		"res://scenes/ui/save_slots_window.tscn",
		"res://scenes/ui/radio_window.tscn",
		"res://scenes/ui/item_spawner_window.tscn",
		"res://scenes/ui/map_window.tscn",
		"res://scenes/ui/crafting_window.tscn",
		"res://scenes/ui/item_tooltip.tscn",
		"res://scenes/ui/inventory_window.tscn",
		"res://scenes/hideout/hideout.tscn",
		"res://scenes/world/main_world.tscn",
		"res://scenes/interior/building_interior_scene.tscn",
	]

	for spath in packed_paths:
		var ps: PackedScene = load(spath) as PackedScene
		var inst: Node = ps.instantiate() if ps != null else null
		var ok := inst != null
		if ok:
			add_child(inst)
			await get_tree().process_frame
			await get_tree().process_frame
			inst.queue_free()
			await get_tree().process_frame
		_assert(ok, "Instantiated and ran _ready() cleanly: %s" % spath)

	var cp := ContainerPopupWindow.new()
	add_child(cp)
	await get_tree().process_frame
	_assert(is_instance_valid(cp), "ContainerPopupWindow instantiates cleanly")
	cp.queue_free()

	var wmw_script: GDScript = load("res://scenes/ui/weapon_modding_window.gd") as GDScript
	var wmw: Node = wmw_script.new() if wmw_script != null else null
	if wmw != null:
		add_child(wmw)
		await get_tree().process_frame
		wmw.queue_free()
	_assert(wmw != null, "WeaponModdingWindow instantiates cleanly")

	var srw_script: GDScript = load("res://scenes/ui/shooting_range_window.gd") as GDScript
	var srw: Node = srw_script.new() if srw_script != null else null
	if srw != null:
		add_child(srw)
		await get_tree().process_frame
		srw.queue_free()
	_assert(srw != null, "ShootingRangeWindow instantiates cleanly")
	await get_tree().process_frame
