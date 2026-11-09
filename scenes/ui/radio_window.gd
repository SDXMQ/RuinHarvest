# res://scenes/ui/radio_window.gd
extends Control

@onready var close_btn: Button = $Panel/VBox/Header/CloseBtn
@onready var scan_container: VBoxContainer = $Panel/VBox/ScanContainer

signal window_closed

const SUPPLY_DROP_COST: int = 2500
const FULTON_EXTRACT_COST: int = 2000

var player: Node = null
var main_world: Node = null
var funds_label: Label = null
var drone_section_vbox: VBoxContainer = null
var fulton_option_btn: OptionButton = null
var fulton_uid_list: Array[String] = []
var supply_drop_btn: Button = null
var fulton_extract_btn: Button = null
var status_feedback_lbl: Label = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var panel: PanelContainer = get_node_or_null("Panel") as PanelContainer
	if panel:
		panel.custom_minimum_size = Vector2(540, 490)
		panel.offset_left = -270.0
		panel.offset_top = -245.0
		panel.offset_right = 270.0
		panel.offset_bottom = 245.0
	var title_lbl: Label = get_node_or_null("Panel/VBox/Header/Title") as Label
	if title_lbl:
		title_lbl.text = "📻 전술 무전기 & 암시장 드론 통신망"

	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)

	_build_radio_content()

func setup(p_player: Node, p_world: Node = null) -> void:
	player = p_player
	main_world = p_world
	_refresh_drone_ops_ui()

func _build_radio_content() -> void:
	if not scan_container:
		return
	for c in scan_container.get_children():
		c.queue_free()
	scan_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	scan_container.add_theme_constant_override("separation", 8)

	funds_label = Label.new()
	funds_label.name = "FundsLabel"
	funds_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	funds_label.add_theme_font_size_override("font_size", 13)
	funds_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.32))
	scan_container.add_child(funds_label)

	var scan_header := Label.new()
	scan_header.text = "📡 주파수 신호 스캔 (Tactical Recon)"
	scan_header.add_theme_font_size_override("font_size", 13)
	scan_header.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	scan_container.add_child(scan_header)

	var targets = [
		{"name": "인근 생존자 / 적 신호 스캔", "type": "survivor", "cost": 50},
		{"name": "물자 투하 위치 스캔", "type": "supply", "cost": 100},
		{"name": "군사 기지 / 보스 신호 스캔", "type": "military", "cost": 200}
	]
	for t in targets:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 32)
		btn.text = "%s (전력/배터리 %d 소모)" % [t["name"], t["cost"]]
		btn.pressed.connect(func(): _scan_target(t["type"]))
		scan_container.add_child(btn)

	scan_container.add_child(HSeparator.new())

	drone_section_vbox = VBoxContainer.new()
	drone_section_vbox.name = "DroneOpsSection"
	drone_section_vbox.add_theme_constant_override("separation", 8)
	scan_container.add_child(drone_section_vbox)

	var drone_header := Label.new()
	drone_header.text = "🚁 암시장 긴급 드론 지원 (Black-Market Drone Ops)"
	drone_header.add_theme_font_size_override("font_size", 13)
	drone_header.add_theme_color_override("font_color", Color(1.0, 0.72, 0.28))
	drone_section_vbox.add_child(drone_header)

	supply_drop_btn = Button.new()
	supply_drop_btn.name = "EmergencySupplyBtn"
	supply_drop_btn.custom_minimum_size = Vector2(0, 38)
	supply_drop_btn.text = "🚁 긴급 탄약·의료 드론 투하 호출 (%d RUB)" % SUPPLY_DROP_COST
	supply_drop_btn.pressed.connect(func():
		request_emergency_supply_drop()
	)
	drone_section_vbox.add_child(supply_drop_btn)

	var fulton_lbl := Label.new()
	fulton_lbl.text = "🎈 풀턴 회수 드론 — 선택한 가방 아이템 1점을 은신처 창고로 즉시 안전 이송:"
	fulton_lbl.add_theme_font_size_override("font_size", 11)
	fulton_lbl.add_theme_color_override("font_color", Color(0.78, 0.84, 0.9))
	drone_section_vbox.add_child(fulton_lbl)

	fulton_option_btn = OptionButton.new()
	fulton_option_btn.name = "FultonItemOption"
	fulton_option_btn.custom_minimum_size = Vector2(0, 32)
	drone_section_vbox.add_child(fulton_option_btn)

	fulton_extract_btn = Button.new()
	fulton_extract_btn.name = "FultonExtractBtn"
	fulton_extract_btn.custom_minimum_size = Vector2(0, 38)
	fulton_extract_btn.text = "🎈 선택 아이템 은신처 즉시 회수 (%d RUB)" % FULTON_EXTRACT_COST
	fulton_extract_btn.pressed.connect(func():
		if fulton_option_btn and fulton_option_btn.selected >= 0 and fulton_option_btn.selected < fulton_uid_list.size():
			request_fulton_extract_item(fulton_uid_list[fulton_option_btn.selected])
	)
	drone_section_vbox.add_child(fulton_extract_btn)

	status_feedback_lbl = Label.new()
	status_feedback_lbl.name = "StatusFeedbackLabel"
	status_feedback_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_feedback_lbl.add_theme_font_size_override("font_size", 11)
	status_feedback_lbl.add_theme_color_override("font_color", Color(0.45, 0.95, 0.6))
	drone_section_vbox.add_child(status_feedback_lbl)

	_refresh_drone_ops_ui()

func _get_player_rubles() -> int:
	if GameManager and GameManager.current_world_data:
		var p_data = GameManager.current_world_data.get("player", {})
		if p_data.has("rubles"):
			return int(p_data["rubles"])
		if GameManager.current_world_data.has("rubles"):
			return int(GameManager.current_world_data["rubles"])
	return 0

func _deduct_player_rubles(cost: int) -> bool:
	if GameManager and GameManager.current_world_data:
		if not GameManager.current_world_data.has("player"):
			GameManager.current_world_data["player"] = {}
		var p_data = GameManager.current_world_data["player"]
		var cur = _get_player_rubles()
		if cur >= cost:
			p_data["rubles"] = cur - cost
			if GameManager.current_world_data.has("rubles"):
				GameManager.current_world_data["rubles"] = cur - cost
			return true
	return false

func _determine_preferred_ammo() -> String:
	if player != null and "equipped_weapon_data" in player:
		var w_data: Dictionary = player.equipped_weapon_data
		if not w_data.is_empty():
			var loaded = String(w_data.get("loaded_ammo", ""))
			if loaded != "" and loaded != "탄약":
				return loaded
			var raw_rec = String(w_data.get("receiver", w_data.get("id", "")))
			var rec_id = WeaponPartsDatabase.resolve_receiver_id(raw_rec)
			var rec_info = WeaponPartsDatabase.RECEIVERS.get(rec_id, {})
			var def_ammo = String(rec_info.get("default_ammo", ""))
			if def_ammo != "":
				return def_ammo
	return "5.56mm"

func _refresh_drone_ops_ui() -> void:
	var cur_rub := _get_player_rubles()
	if funds_label:
		funds_label.text = "💰 보유 자금: %d RUB" % cur_rub

	if supply_drop_btn:
		supply_drop_btn.disabled = (player == null or cur_rub < SUPPLY_DROP_COST)
		supply_drop_btn.text = "🚁 긴급 탄약·의료 드론 투하 호출 (%d RUB)%s" % [
			SUPPLY_DROP_COST,
			" [잔액 부족]" if cur_rub < SUPPLY_DROP_COST else ""
		]

	fulton_uid_list.clear()
	if fulton_option_btn:
		fulton_option_btn.clear()
		if player != null and "inventory_grid" in player and player.inventory_grid != null:
			var sorted_items: Array = player.inventory_grid.items.duplicate()
			sorted_items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				var a_is_radio = String(a.get("id", "")).contains("무전기")
				var b_is_radio = String(b.get("id", "")).contains("무전기")
				if a_is_radio != b_is_radio:
					return not a_is_radio
				var va = int(ItemDatabase.get_item_data(String(a.get("id", ""))).get("value", 0))
				var vb = int(ItemDatabase.get_item_data(String(b.get("id", ""))).get("value", 0))
				return va > vb
			)
			for it in sorted_items:
				var uid = String(it.get("uid", ""))
				var id = String(it.get("id", ""))
				if uid == "" or id == "":
					continue
				var d = ItemDatabase.get_item_data(id)
				var disp_name = String(it.get("name", d.get("name", id)))
				var amt = int(it.get("amount", 1))
				var tags: Array[String] = []
				if amt > 1:
					tags.append("x%d" % amt)
				var parts_d: Dictionary = it.get("parts", it.get("attachments", {}))
				if not parts_d.is_empty():
					tags.append("개조 %d파츠" % parts_d.size())
				if it.has("durability"):
					tags.append("내구 %.0f" % float(it["durability"]))
				var suffix = (" [" + " | ".join(tags) + "]") if not tags.is_empty() else ""
				fulton_option_btn.add_item(disp_name + suffix)
				fulton_uid_list.append(uid)

		if fulton_uid_list.is_empty():
			fulton_option_btn.add_item("(회수 가능한 가방 아이템 없음)")
			fulton_option_btn.disabled = true
		else:
			fulton_option_btn.disabled = false
			fulton_option_btn.selected = 0

	if fulton_extract_btn:
		fulton_extract_btn.disabled = (fulton_uid_list.is_empty() or cur_rub < FULTON_EXTRACT_COST)
		fulton_extract_btn.text = "🎈 선택 아이템 은신처 즉시 회수 (%d RUB)%s" % [
			FULTON_EXTRACT_COST,
			" [잔액 부족]" if cur_rub < FULTON_EXTRACT_COST else ""
		]

func request_emergency_supply_drop() -> bool:
	if player == null:
		return false
	if not _deduct_player_rubles(SUPPLY_DROP_COST):
		if status_feedback_lbl:
			status_feedback_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			status_feedback_lbl.text = "⚠️ 잔액이 부족합니다. (필요: %d RUB)" % SUPPLY_DROP_COST
		return false

	var pref_ammo := _determine_preferred_ammo()
	var drop_pos: Vector2 = player.global_position + Vector2(64.0, 0.0)
	if main_world != null and main_world.has_method("spawn_emergency_drone_crate"):
		main_world.spawn_emergency_drone_crate(drop_pos, pref_ammo)
	else:
		# 단독 테스트/폴백 환경에서도 바닥 보급 아이템 즉시 투하
		var GroundItemScene = preload("res://scenes/entities/items/ground_item.tscn")
		var parent_node: Node = player.get_parent() if player.get_parent() else self
		var bundle = [
			{"id": pref_ammo, "amount": 60},
			{"id": "고급 치료킷", "amount": 1},
			{"id": "구급상자", "amount": 1},
			{"id": "붕대", "amount": 2}
		]
		for entry in bundle:
			var g_item = GroundItemScene.instantiate()
			g_item.global_position = drop_pos + Vector2(randf_range(-12, 12), randf_range(-12, 12))
			parent_node.add_child(g_item)
			g_item.setup(entry["id"], entry["amount"], {})

	if SoundManager:
		SoundManager.play("craft_complete")
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("★ 🚁 [긴급 드론 보급] %d RUB 결제 완료! %s 탄약 및 응급 의료품 보급함이 투하됩니다!" % [SUPPLY_DROP_COST, pref_ammo])
	if status_feedback_lbl:
		status_feedback_lbl.add_theme_color_override("font_color", Color(0.45, 0.95, 0.6))
		status_feedback_lbl.text = "✓ 긴급 보급 드론 호출 완료! (%s x60 + 의료품 투하)" % pref_ammo
	_refresh_drone_ops_ui()
	return true

func request_fulton_extract_item(item_uid: String) -> bool:
	if player == null or not ("inventory_grid" in player) or player.inventory_grid == null:
		return false
	var grid: InventoryGrid = player.inventory_grid
	var target_item: Dictionary = grid.get_item_by_uid(item_uid)
	if target_item.is_empty():
		return false
	if not _deduct_player_rubles(FULTON_EXTRACT_COST):
		if status_feedback_lbl:
			status_feedback_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			status_feedback_lbl.text = "⚠️ 잔액이 부족합니다. (필요: %d RUB)" % FULTON_EXTRACT_COST
		return false

	var stash_entry: Dictionary = target_item.duplicate(true)
	for coord_k in ["x", "y", "rotated"]:
		stash_entry.erase(coord_k)

	grid.remove_item_by_uid(item_uid)

	if GameManager:
		if not GameManager.current_world_data.has("hideout"):
			GameManager.current_world_data["hideout"] = {"stash": [], "upgrades": {}}
		elif not GameManager.current_world_data["hideout"].has("stash"):
			GameManager.current_world_data["hideout"]["stash"] = []
		GameManager.current_world_data["hideout"]["stash"].append(stash_entry)
		if GameManager.current_save_slot != "":
			SaveManager.save_game(GameManager.current_world_data, GameManager.current_save_slot)

	var idata = ItemDatabase.get_item_data(String(stash_entry.get("id", "")))
	var disp_name = String(stash_entry.get("name", idata.get("name", stash_entry.get("id", ""))))
	if main_world != null and main_world.has_method("spawn_fulton_balloon_effect") and player != null:
		main_world.spawn_fulton_balloon_effect(player.global_position, disp_name)
	if SoundManager:
		SoundManager.play("craft_complete")
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("★ 🎈 [풀턴 회수 완료] [%s]을(를) 은신처 창고로 즉시 안전 이송했습니다! (사망 시에도 100%% 보존)" % disp_name)
	if status_feedback_lbl:
		status_feedback_lbl.add_theme_color_override("font_color", Color(0.45, 0.95, 0.6))
		status_feedback_lbl.text = "✓ [%s] 은신처 창고 이송 완료!" % disp_name
	_refresh_drone_ops_ui()
	return true

func _scan_target(type: String) -> void:
	if GameManager and GameManager.current_world_data is Dictionary:
		GameManager.current_world_data["raid_radio_scanned"] = true
	if SoundManager: SoundManager.play("menu_select")
	if EventBus.has_signal("radio_scan_requested"):
		EventBus.radio_scan_requested.emit(type)
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("📻 무전기 스캔 시작: " + type)
	_on_close_pressed()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func _on_close_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	queue_free()
	window_closed.emit()
