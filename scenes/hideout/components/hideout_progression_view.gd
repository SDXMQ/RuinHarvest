# res://scenes/hideout/components/hideout_progression_view.gd
extends RefCounted

## 은신처 시설 업그레이드 · 상인 의뢰 · 전술 기록실 UI 뷰 헬퍼

static func setup_progression_tab(_hideout: Control, tab_container: TabContainer) -> Control:
	var tab_root := HBoxContainer.new()
	tab_root.name = " 시설 & 의뢰 "
	tab_root.add_theme_constant_override("separation", 18)
	tab_container.add_child(tab_root)
	if UiIconManager:
		UiIconManager.set_tab_icon_by_control(tab_container, tab_root, "facility")

	# 좌측: 은신처 시설 업그레이드
	var fac_panel := PanelContainer.new()
	fac_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fac_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var fac_vbox_outer := VBoxContainer.new()
	fac_vbox_outer.add_theme_constant_override("separation", 10)
	fac_panel.add_child(fac_vbox_outer)

	var fac_title := Label.new()
	fac_title.text = "은신처 핵심 시설 업그레이드 (Facilities)"
	fac_title.add_theme_font_size_override("font_size", 16)
	fac_title.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	fac_vbox_outer.add_child(fac_title)
	if UiIconManager:
		UiIconManager.set_label_icon(fac_title, "facility", "", 18, 6)

	var fac_scroll := ScrollContainer.new()
	fac_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var fac_list := VBoxContainer.new()
	fac_list.name = "FacilitiesList"
	fac_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fac_list.add_theme_constant_override("separation", 10)
	fac_scroll.add_child(fac_list)
	fac_vbox_outer.add_child(fac_scroll)
	tab_root.add_child(fac_panel)

	# 우측: 상인 특별 의뢰 (퀘스트)
	var q_panel := PanelContainer.new()
	q_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var q_vbox_outer := VBoxContainer.new()
	q_vbox_outer.add_theme_constant_override("separation", 10)
	q_panel.add_child(q_vbox_outer)

	var q_title := Label.new()
	q_title.text = "상인 계약 의뢰 & 임무 (Trader Quests)"
	q_title.add_theme_font_size_override("font_size", 16)
	q_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	q_vbox_outer.add_child(q_title)
	if UiIconManager:
		UiIconManager.set_label_icon(q_title, "clipboard", "", 18, 6)

	var q_scroll := ScrollContainer.new()
	q_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var q_list := VBoxContainer.new()
	q_list.name = "QuestsList"
	q_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_list.add_theme_constant_override("separation", 10)
	q_scroll.add_child(q_list)
	q_vbox_outer.add_child(q_scroll)
	tab_root.add_child(q_panel)

	return tab_root


static func refresh_progression_tab(hideout: Control, tab_root: Control) -> void:
	if not tab_root or not GameManager:
		return
	var fac_list: VBoxContainer = tab_root.find_child("FacilitiesList", true, false) as VBoxContainer
	var q_list: VBoxContainer = tab_root.find_child("QuestsList", true, false) as VBoxContainer
	if not fac_list or not q_list:
		return

	for c in fac_list.get_children():
		c.queue_free()
	for c in q_list.get_children():
		c.queue_free()

	var w_data: Dictionary = GameManager.current_world_data
	if not w_data.has("player"):
		w_data["player"] = {}
	if not w_data.has("hideout"):
		w_data["hideout"] = {"stash": [], "upgrades": {}, "completed_quests": []}
	if not w_data["hideout"].has("upgrades"):
		w_data["hideout"]["upgrades"] = {}
	if not w_data["hideout"].has("completed_quests"):
		w_data["hideout"]["completed_quests"] = []

	var rubles: int = int(w_data["player"].get("rubles", 0))
	var p_grid: InventoryGrid = hideout.get("player_grid_mgr") as InventoryGrid
	var s_grid: InventoryGrid = hideout.get("stash_grid_mgr") as InventoryGrid

	# 1. 시설 목록 렌더링
	for fac_id in HideoutProgression.FACILITIES.keys():
		var f_data: Dictionary = HideoutProgression.FACILITIES[fac_id]
		var cur_lv: int = HideoutProgression.get_facility_level(w_data, fac_id)
		var max_lv: int = int(f_data["max_level"])

		var card := PanelContainer.new()
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)

		var header := Label.new()
		header.text = "%s  [Lv.%d / %d]" % [f_data["name"], cur_lv, max_lv]
		header.add_theme_font_size_override("font_size", 14)
		header.add_theme_color_override("font_color", Color(0.5, 0.95, 0.6) if cur_lv > 0 else Color(0.9, 0.9, 0.95))
		vbox.add_child(header)
		if UiIconManager:
			UiIconManager.set_label_icon(header, String(f_data.get("icon", "facility")), "", 16, 6)

		var desc := Label.new()
		desc.text = String(f_data["desc"])
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
		vbox.add_child(desc)

		if cur_lv < max_lv:
			var next_req: Dictionary = f_data["levels"][cur_lv]
			var req_rub: int = int(next_req["rubles"])
			var req_items: Dictionary = next_req["items"]
			var can_upgrade: bool = (rubles >= req_rub)
			var req_parts: Array = ["%d RUB" % req_rub]

			for it_id in req_items.keys():
				var need_c: int = int(req_items[it_id])
				var have_c: int = HideoutProgression.count_total_item(String(it_id), p_grid, s_grid)
				if have_c < need_c:
					can_upgrade = false
				req_parts.append("%s (%d/%d)" % [it_id, have_c, need_c])

			var req_lbl := Label.new()
			req_lbl.text = "필요 조건: " + ", ".join(req_parts)
			req_lbl.add_theme_font_size_override("font_size", 11)
			req_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5) if can_upgrade else Color(1.0, 0.55, 0.45))
			vbox.add_child(req_lbl)

			var up_btn := Button.new()
			if UiIconManager:
				UiIconManager.set_button(up_btn, "upgrade", "Lv.%d 업그레이드 시공" % (cur_lv + 1), 15)
			else:
				up_btn.text = "Lv.%d 업그레이드 시공" % (cur_lv + 1)
			up_btn.disabled = not can_upgrade
			var fid_cap: String = String(fac_id)
			up_btn.pressed.connect(func():
				if HideoutProgression.try_upgrade_facility(fid_cap, w_data, p_grid, s_grid):
					if SoundManager:
						SoundManager.play("menu_select")
					HideoutProgression._notify_hideout_state_changed(hideout, true)
					HideoutProgression.refresh_progression_tab(hideout, tab_root)
			)
			vbox.add_child(up_btn)
		else:
			var max_lbl := Label.new()
			max_lbl.text = "최고 단계 업그레이드 완료 (MAX)"
			max_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			vbox.add_child(max_lbl)
			if UiIconManager:
				UiIconManager.set_label_icon(max_lbl, "star", "", 15, 5)

		fac_list.add_child(card)

	# 2. 퀘스트 목록 렌더링
	var completed_list: Array = w_data["hideout"]["completed_quests"]
	var total_kills: int = int(w_data["player"].get("kills_total", 0))
	var human_kills: int = int(w_data["player"].get("human_kills", 0))

	for q in HideoutProgression.QUESTS:
		var q_id: String = String(q["id"])
		var is_done: bool = q_id in completed_list

		var card := PanelContainer.new()
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)

		var header := Label.new()
		header.text = "[%s] %s%s" % [q["trader"], q["title"], " (완료)" if is_done else ""]
		header.add_theme_font_size_override("font_size", 14)
		header.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5) if is_done else Color(1.0, 0.88, 0.4))
		vbox.add_child(header)
		if UiIconManager:
			UiIconManager.set_label_icon(header, "ok" if is_done else "clipboard", "", 15, 5)

		var desc := Label.new()
		desc.text = String(q["desc"])
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", Color(0.78, 0.8, 0.86))
		vbox.add_child(desc)

		if not is_done:
			var can_complete: bool = true
			var cond_strs: Array = []
			var req_items: Dictionary = q.get("req_items", {})
			for it_id in req_items.keys():
				var need_c: int = int(req_items[it_id])
				var have_c: int = HideoutProgression.count_total_item(String(it_id), p_grid, s_grid)
				if have_c < need_c:
					can_complete = false
				cond_strs.append("%s (%d/%d)" % [it_id, have_c, need_c])

			var req_k: int = int(q.get("req_kills", 0))
			if req_k > 0:
				if total_kills < req_k:
					can_complete = false
				cond_strs.append("적 처치 (%d/%d)" % [total_kills, req_k])

			var req_hk: int = int(q.get("req_human_kills", 0))
			if req_hk > 0:
				if human_kills < req_hk:
					can_complete = false
				cond_strs.append("무장 적 처치 (%d/%d)" % [human_kills, req_hk])

			var req_fo: int = int(q.get("req_field_objectives", 0))
			if req_fo > 0:
				var fo_cnt: int = int(w_data["player"].get("field_objectives_completed", 0))
				if fo_cnt < req_fo:
					can_complete = false
				cond_strs.append("현장 단말기 해킹 (%d/%d)" % [fo_cnt, req_fo])

			var rew_strs: Array = ["+%d RUB" % int(q["reward_rubles"])]
			for r_it in q.get("reward_items", []):
				rew_strs.append("%s x%d" % [r_it["id"], int(r_it["amount"])])

			var prog_lbl := Label.new()
			prog_lbl.text = "진행도: %s  |  보상: %s" % [", ".join(cond_strs), ", ".join(rew_strs)]
			prog_lbl.add_theme_font_size_override("font_size", 11)
			prog_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5) if can_complete else Color(0.85, 0.7, 0.45))
			vbox.add_child(prog_lbl)

			var comp_btn := Button.new()
			if UiIconManager:
				UiIconManager.set_button(comp_btn, "gift", "의뢰 완수 및 보상 수령", 15)
			else:
				comp_btn.text = "의뢰 완수 및 보상 수령"
			comp_btn.disabled = not can_complete
			var q_cap: Dictionary = q
			comp_btn.pressed.connect(func():
				if not HideoutProgression.try_complete_quest(q_cap, w_data, p_grid, s_grid):
					if EventBus.has_signal("event_logged"):
						EventBus.event_logged.emit("[icon:warn] 창고와 배낭 공간이 부족하여 의뢰 보상을 수령할 수 없습니다.")
					if SoundManager:
						SoundManager.play("hit_melee")
					return
				if SoundManager:
					SoundManager.play("level_up")
				HideoutProgression._notify_hideout_state_changed(hideout, false)
				HideoutProgression.refresh_progression_tab(hideout, tab_root)
			)
			vbox.add_child(comp_btn)

		q_list.add_child(card)


static func notify_hideout_state_changed(hideout: Node, stash_resized: bool = false) -> void:
	if not hideout:
		return
	if hideout.has_method("on_progression_state_changed"):
		hideout.on_progression_state_changed(stash_resized)
		return
	if stash_resized and hideout.has_method("_apply_stash_upgrade_size"):
		hideout._apply_stash_upgrade_size()
	if hideout.has_method("_refresh_stash_ui"):
		hideout._refresh_stash_ui()
	if hideout.has_method("_update_money_label"):
		hideout._update_money_label()
	if hideout.has_method("_on_grid_changed"):
		hideout._on_grid_changed()
	elif hideout.has_method("_sync_save_data"):
		hideout._sync_save_data()


static func setup_service_record_tab(_hideout: Control, tab_container: TabContainer) -> Control:
	var tab_root := HBoxContainer.new()
	tab_root.name = " 전술 기록실 "
	tab_root.add_theme_constant_override("separation", 18)
	tab_container.add_child(tab_root)
	if UiIconManager:
		UiIconManager.set_tab_icon_by_control(tab_container, tab_root, "medal")

	# 좌측: 레이드 전적 아카이브 & 인식표 휘장
	var rec_panel := PanelContainer.new()
	rec_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rec_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rec_vbox := VBoxContainer.new()
	rec_vbox.name = "ServiceStatsVBox"
	rec_vbox.add_theme_constant_override("separation", 10)
	rec_panel.add_child(rec_vbox)
	tab_root.add_child(rec_panel)

	# 우측: 총기별 킬 카운트 & 총기 숙련도(Weapon Mastery)
	var mas_panel := PanelContainer.new()
	mas_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mas_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var mas_vbox_outer := VBoxContainer.new()
	mas_vbox_outer.add_theme_constant_override("separation", 10)
	mas_panel.add_child(mas_vbox_outer)

	var mas_title := Label.new()
	mas_title.text = "총기 숙련도 3단계 (Lv.1 15킬 · Lv.2 35킬 · Lv.3 70킬 Мастер)"
	mas_title.add_theme_font_size_override("font_size", 16)
	mas_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	mas_vbox_outer.add_child(mas_title)
	if UiIconManager:
		UiIconManager.set_label_icon(mas_title, "gun_gold", "", 18, 6)

	var mas_scroll := ScrollContainer.new()
	mas_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var mas_list := VBoxContainer.new()
	mas_list.name = "WeaponMasteryList"
	mas_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mas_list.add_theme_constant_override("separation", 8)
	mas_scroll.add_child(mas_list)
	mas_vbox_outer.add_child(mas_scroll)
	tab_root.add_child(mas_panel)

	return tab_root


static func refresh_service_record_tab(hideout: Control, tab_root: Control) -> void:
	if not tab_root or not GameManager:
		return
	var rec_vbox: VBoxContainer = tab_root.find_child("ServiceStatsVBox", true, false) as VBoxContainer
	var mas_list: VBoxContainer = tab_root.find_child("WeaponMasteryList", true, false) as VBoxContainer
	if not rec_vbox or not mas_list:
		return
	for c in rec_vbox.get_children():
		c.queue_free()
	for c in mas_list.get_children():
		c.queue_free()

	var w_data: Dictionary = GameManager.current_world_data
	var p_grid: InventoryGrid = hideout.get("player_grid_mgr") as InventoryGrid
	var s_grid: InventoryGrid = hideout.get("stash_grid_mgr") as InventoryGrid
	var summary: Dictionary = HideoutProgression.get_service_record_data(w_data, p_grid, s_grid)

	var title := Label.new()
	title.text = "전술 기록실 (Service Record & Dogtag Archive)"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	rec_vbox.add_child(title)
	if UiIconManager:
		UiIconManager.set_label_icon(title, "medal", "", 18, 6)

	var stat_lines: Array = [
		["extract", "누적 레이드 생환 횟수", "%d 회" % int(summary["raids_survived"]), Color(0.45, 1.0, 0.55)],
		["swords", "누적 전체 적 사살 수", "%d 명" % int(summary["kills_total"]), Color(0.92, 0.94, 0.98)],
		["target", "무장 세력(Scav/Raider) 사살", "%d 명" % int(summary["human_kills"]), Color(1.0, 0.82, 0.4)],
		["skull", "구역 지휘관(Boss) 사살", "%d 회" % int(summary["boss_kills"]), Color(1.0, 0.45, 0.45)],
		["tag", "보유 중인 Scav 인식표 (Dogtag)", "%d 개" % int(summary["dogtag_count"]), Color(0.4, 0.92, 1.0)],
		["star", "마스터 달성 총기 수", "%d / %d 종" % [summary["mastered_weapons"].size(), HideoutProgression.TRACKED_MASTERY_WEAPONS.size()], Color(1.0, 0.88, 0.3)]
	]

	for row in stat_lines:
		var card := PanelContainer.new()
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		card.add_child(hbox)
		if UiIconManager:
			hbox.add_child(UiIconManager.create_icon_rect(String(row[0]), 15))
		var k_lbl := Label.new()
		k_lbl.text = String(row[1])
		k_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		k_lbl.add_theme_font_size_override("font_size", 13)
		hbox.add_child(k_lbl)
		var v_lbl := Label.new()
		v_lbl.text = String(row[2])
		v_lbl.add_theme_font_size_override("font_size", 14)
		v_lbl.add_theme_color_override("font_color", row[3])
		hbox.add_child(v_lbl)
		rec_vbox.add_child(card)

	# === Scav 인식표 전용 암시장 물물교환소 (Dogtag Barter Shop) ===
	var barter_header := Label.new()
	barter_header.text = "Scav 인식표 암시장 물물교환소 (보유 인식표: %d개)" % int(summary["dogtag_count"])
	barter_header.add_theme_font_size_override("font_size", 15)
	barter_header.add_theme_color_override("font_color", Color(1.0, 0.84, 0.28))
	rec_vbox.add_child(barter_header)
	if UiIconManager:
		UiIconManager.set_label_icon(barter_header, "tag", "", 16, 6)

	for b_trade in HideoutProgression.DOGTAG_BARTER_TRADES:
		var b_card := PanelContainer.new()
		if PixelAssetManager:
			var b_sb := PixelAssetManager.get_pixel_stylebox("barter_card", 8.0, 6.0, 8.0, 6.0, 4)
			if b_sb != null:
				b_card.add_theme_stylebox_override("panel", b_sb)

		var b_hbox := HBoxContainer.new()
		b_hbox.add_theme_constant_override("separation", 10)
		b_card.add_child(b_hbox)

		var r_id: String = String(b_trade["reward_id"])
		if ItemIconManager:
			var b_icon := TextureRect.new()
			b_icon.custom_minimum_size = Vector2(32, 32)
			b_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			b_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			b_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			b_icon.texture = ItemIconManager.get_icon(r_id)
			b_hbox.add_child(b_icon)

		var b_info_v := VBoxContainer.new()
		b_info_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b_name_lbl := Label.new()
		b_name_lbl.text = "%s (인식표 %d개 교환)" % [String(b_trade["title"]), int(b_trade["cost_tags"])]
		b_name_lbl.add_theme_font_size_override("font_size", 13)
		b_name_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.78))
		b_info_v.add_child(b_name_lbl)

		var b_desc_lbl := Label.new()
		b_desc_lbl.text = String(b_trade["desc"])
		b_desc_lbl.add_theme_font_size_override("font_size", 11)
		b_desc_lbl.add_theme_color_override("font_color", Color(0.72, 0.76, 0.84))
		b_info_v.add_child(b_desc_lbl)
		b_hbox.add_child(b_info_v)

		var cost_c: int = int(b_trade["cost_tags"])
		var can_barter: bool = int(summary["dogtag_count"]) >= cost_c
		var b_btn := Button.new()
		if UiIconManager:
			UiIconManager.set_button(b_btn, "tag", "%d개 교환" % cost_c, 14)
		else:
			b_btn.text = "%d개 교환" % cost_c
		b_btn.disabled = not can_barter
		var cap_tid: String = String(b_trade["id"])
		b_btn.pressed.connect(func():
			var res: Dictionary = HideoutProgression.execute_dogtag_barter(cap_tid, w_data, p_grid, s_grid)
			if bool(res.get("success", false)):
				if SoundManager:
					SoundManager.play("level_up")
				HideoutProgression._notify_hideout_state_changed(hideout, false)
				HideoutProgression.refresh_service_record_tab(hideout, tab_root)
		)
		b_hbox.add_child(b_btn)
		rec_vbox.add_child(b_card)

	for w_id in HideoutProgression.TRACKED_MASTERY_WEAPONS:
		var m_info: Dictionary = HideoutProgression.get_weapon_mastery_bonus(w_data, w_id)
		var kills: int = int(m_info["kills"])
		var lv: int = int(m_info.get("level", 0))
		var is_gm: bool = bool(m_info.get("gold_border", false))
		var idata: Dictionary = ItemDatabase.get_item_data(w_id) if ItemDatabase else {}
		var w_name: String = String(idata.get("name", w_id))

		var card := PanelContainer.new()
		if is_gm and PixelAssetManager:
			var gm_sb := PixelAssetManager.get_pixel_stylebox("mastery_gold", 8.0, 6.0, 8.0, 6.0, 4)
			if gm_sb != null:
				card.add_theme_stylebox_override("panel", gm_sb)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)

		var h_row := HBoxContainer.new()
		h_row.add_theme_constant_override("separation", 8)
		vbox.add_child(h_row)

		if ItemIconManager:
			var icon_frame := PanelContainer.new()
			if PixelAssetManager:
				var ic_preset: String = "icon_frame_gold" if is_gm else ("workbench_slot_active" if lv >= 1 else "icon_frame")
				var ic_sb := PixelAssetManager.get_pixel_stylebox(ic_preset, 2.0, 2.0, 2.0, 2.0, 3)
				if ic_sb != null:
					icon_frame.add_theme_stylebox_override("panel", ic_sb)
			var w_icon := TextureRect.new()
			w_icon.custom_minimum_size = Vector2(28, 28)
			w_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			w_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			w_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			w_icon.texture = ItemIconManager.get_icon(w_id)
			icon_frame.add_child(w_icon)
			h_row.add_child(icon_frame)

		var header := Label.new()
		var badge_str: String = " [Lv.3 Мастер]" if lv >= 3 else (" [Lv.%d]" % lv if lv >= 1 else "")
		header.text = "%s  —  처치: %d / %d 킬%s" % [
			w_name,
			kills,
			HideoutProgression.WEAPON_MASTERY_LV3_KILLS,
			badge_str
		]
		header.add_theme_font_size_override("font_size", 13)
		header.add_theme_color_override("font_color", Color(1.0, 0.86, 0.25) if lv >= 3 else (Color(0.45, 0.95, 0.65) if lv >= 1 else Color(0.88, 0.9, 0.95)))
		if UiIconManager and lv >= 1:
			h_row.add_child(UiIconManager.create_icon_rect("trophy" if lv >= 3 else "star", 15))
		h_row.add_child(header)

		var bar := ProgressBar.new()
		bar.max_value = float(HideoutProgression.WEAPON_MASTERY_LV3_KILLS)
		bar.value = float(min(kills, HideoutProgression.WEAPON_MASTERY_LV3_KILLS))
		bar.custom_minimum_size = Vector2(0, 14)
		vbox.add_child(bar)

		var bonus_lbl := Label.new()
		var bonus_icon: String = ""
		if lv >= 3:
			bonus_icon = "trophy"
			bonus_lbl.text = "Lv.3 Мастер 달성: 재장전 +5% · 반동 제어 +5% · 기능고장(Jam) 확률 -50% · 황금 총기 테두리"
			bonus_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.28))
		elif lv == 2:
			bonus_icon = "ok"
			bonus_lbl.text = "Lv.2 활성화: 재장전 +3% & 반동 제어 +5%  |  다음 목표: 70킬 (Lv.3 Мастер: 기능고장 -50% & 황금 테두리)"
			bonus_lbl.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55))
		elif lv == 1:
			bonus_icon = "ok"
			bonus_lbl.text = "Lv.1 활성화: 재장전 속도 +3%  |  다음 목표: 35킬 (Lv.2: 반동 제어 +5%)"
			bonus_lbl.add_theme_color_override("font_color", Color(0.45, 0.92, 1.0))
		else:
			bonus_lbl.text = "단계별 보너스: Lv.1(15킬: 재장전+3%) → Lv.2(35킬: 반동+5%) → Lv.3 Мастер(70킬: 잼-50% & 황금 테두리)"
			bonus_lbl.add_theme_color_override("font_color", Color(0.7, 0.74, 0.82))
		bonus_lbl.add_theme_font_size_override("font_size", 11)
		vbox.add_child(bonus_lbl)
		if UiIconManager and bonus_icon != "":
			UiIconManager.set_label_icon(bonus_lbl, bonus_icon, "", 14, 5)

		mas_list.add_child(card)
