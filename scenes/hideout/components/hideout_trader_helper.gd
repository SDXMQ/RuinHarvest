# res://scenes/hideout/components/hideout_trader_helper.gd
extends RefCounted

## 은신처 상인 탭(구매 목록, 우호도 바, 2D 일괄 판매 선택·마키 드래그·영수증 정산) 헬퍼

static func setup_traders_bulk_ui(ho: Control) -> void:
	var t_vbox: VBoxContainer = ho.get_node_or_null("CenterArea/TabContainer/TradersTab/VBox") as VBoxContainer
	if not t_vbox:
		return

	# 상인 헤더 하단에 우호도(Loyalty Level) 정보 바 추가
	var loyalty_panel := PanelContainer.new()
	loyalty_panel.name = "TraderLoyaltyPanel"
	loyalty_panel.theme_type_variation = &"HeaderPanel"
	var l_hbox := HBoxContainer.new()
	l_hbox.add_theme_constant_override("separation", 14)
	loyalty_panel.add_child(l_hbox)

	ho.trader_loyalty_label = Label.new()
	ho.trader_loyalty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ho.trader_loyalty_label.clip_text = true
	ho.trader_loyalty_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ho.trader_loyalty_label.add_theme_font_size_override("font_size", 12)
	ho.trader_loyalty_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.38))
	l_hbox.add_child(ho.trader_loyalty_label)
	if UiIconManager:
		UiIconManager.set_label_icon(ho.trader_loyalty_label, "star", "", 14, 5)

	ho.trader_loyalty_bar = ProgressBar.new()
	ho.trader_loyalty_bar.custom_minimum_size = Vector2(210, 16)
	ho.trader_loyalty_bar.show_percentage = true
	l_hbox.add_child(ho.trader_loyalty_bar)

	t_vbox.add_child(loyalty_panel)
	t_vbox.move_child(loyalty_panel, 2)

	# 기존 스크롤(상점)과 판매 영역을 구매/판매 서브 탭으로 분리 (기존 @onready 참조 유지)
	var old_shop_scroll: Control = t_vbox.get_node_or_null("Scroll") as Control
	var old_sell_area: Control = t_vbox.get_node_or_null("SellArea") as Control
	if old_sell_area:
		old_sell_area.hide()

	ho.trader_mode_tabs = TabContainer.new()
	ho.trader_mode_tabs.name = "TraderModeTabs"
	ho.trader_mode_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ho.trader_mode_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ho.trader_mode_tabs.tab_changed.connect(func(_t: int): ho.call_deferred("_update_all_hideout_grid_sizes"))
	t_vbox.add_child(ho.trader_mode_tabs)

	# [서브 탭 0] 상인 공급 품목 구매
	var buy_tab := VBoxContainer.new()
	buy_tab.name = "물품 구매"
	buy_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	buy_tab.add_theme_constant_override("separation", 6)
	ho.trader_mode_tabs.add_child(buy_tab)
	if UiIconManager:
		UiIconManager.set_tab_icon_by_control(ho.trader_mode_tabs, buy_tab, "cart")

	var shop_hdr := Label.new()
	shop_hdr.text = "상인 공급 품목 (안정 공급 · 등급별 해금)"
	shop_hdr.add_theme_font_size_override("font_size", 12)
	shop_hdr.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	buy_tab.add_child(shop_hdr)
	if UiIconManager:
		UiIconManager.set_label_icon(shop_hdr, "cart", "", 14, 5)

	if old_shop_scroll:
		t_vbox.remove_child(old_shop_scroll)
		old_shop_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		old_shop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if old_shop_scroll is ScrollContainer:
			(old_shop_scroll as ScrollContainer).horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		if ho.trader_items_vbox:
			ho.trader_items_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buy_tab.add_child(old_shop_scroll)

	# [서브 탭 1] 아이템 일괄 판매 (2D 다중 선택 + 영수증 정산)
	var sell_tab := HBoxContainer.new()
	sell_tab.name = "아이템 판매"
	sell_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sell_tab.add_theme_constant_override("separation", 12)
	ho.trader_mode_tabs.add_child(sell_tab)
	if UiIconManager:
		UiIconManager.set_tab_icon_by_control(ho.trader_mode_tabs, sell_tab, "money")

	# [판매 좌측 컬럼] 자동 담기 토글 + 배낭/창고 2D 다중 선택 & Marquee 드래그 영역
	var center_col := VBoxContainer.new()
	center_col.name = "BulkSelectCol"
	center_col.custom_minimum_size = Vector2(360, 0)
	center_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_col.size_flags_stretch_ratio = 1.25
	center_col.add_theme_constant_override("separation", 6)
	sell_tab.add_child(center_col)

	var btn_bar := HBoxContainer.new()
	btn_bar.add_theme_constant_override("separation", 6)
	center_col.add_child(btn_bar)

	ho.trader_btn_valuables = Button.new()
	ho.trader_btn_valuables.theme_type_variation = &"SmallButton"
	if UiIconManager:
		UiIconManager.set_button(ho.trader_btn_valuables, "broom", "환금템 모두 담기", 14)
	else:
		ho.trader_btn_valuables.text = "환금템 모두 담기"
	ho.trader_btn_valuables.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ho.trader_btn_valuables.add_theme_font_size_override("font_size", 11)
	ho.trader_btn_valuables.pressed.connect(func(): ho._auto_select_bulk_sell("valuables"))
	btn_bar.add_child(ho.trader_btn_valuables)

	ho.trader_btn_non_gear = Button.new()
	ho.trader_btn_non_gear.theme_type_variation = &"SmallButton"
	if UiIconManager:
		UiIconManager.set_button(ho.trader_btn_non_gear, "box", "장비/무기 제외 모두 담기", 14)
	else:
		ho.trader_btn_non_gear.text = "장비/무기 제외 모두 담기"
	ho.trader_btn_non_gear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ho.trader_btn_non_gear.add_theme_font_size_override("font_size", 11)
	ho.trader_btn_non_gear.pressed.connect(func(): ho._auto_select_bulk_sell("non_gear"))
	btn_bar.add_child(ho.trader_btn_non_gear)

	var btn_clear := Button.new()
	btn_clear.theme_type_variation = &"DangerButton"
	if UiIconManager:
		UiIconManager.set_button(btn_clear, "close", "해제", 13)
	else:
		btn_clear.text = "해제"
	btn_clear.custom_minimum_size = Vector2(72, 0)
	btn_clear.add_theme_font_size_override("font_size", 11)
	btn_clear.pressed.connect(func():
		ho.selected_sell_uids.clear()
		ho._refresh_trader_sell_ui()
	)
	btn_bar.add_child(btn_clear)

	ho.sell_grid_header_lbl = Label.new()
	ho.sell_grid_header_lbl.text = "Alt+좌클릭 / 우클릭: 담기 토글 | 빈 공간 드래그: 범위(Marquee) 선택 | [L]: 잠금"
	ho.sell_grid_header_lbl.add_theme_font_size_override("font_size", 10)
	ho.sell_grid_header_lbl.add_theme_color_override("font_color", Color(0.76, 0.84, 0.92))
	center_col.add_child(ho.sell_grid_header_lbl)
	if UiIconManager:
		UiIconManager.set_label_icon(ho.sell_grid_header_lbl, "tip", "", 13, 5)

	ho.sell_grids_scroll = ScrollContainer.new()
	ho.sell_grids_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ho.sell_grids_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ho.sell_grids_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ho.sell_grids_scroll.resized.connect(Callable(ho, "_update_all_hideout_grid_sizes"))
	center_col.add_child(ho.sell_grids_scroll)

	var grids_vbox := VBoxContainer.new()
	grids_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grids_vbox.add_theme_constant_override("separation", 8)
	ho.sell_grids_scroll.add_child(grids_vbox)

	var p_hdr := Label.new()
	p_hdr.text = "내 배낭 (좌상단 2x2 SECURE & 잠금 자동 보호)"
	p_hdr.add_theme_font_size_override("font_size", 11)
	p_hdr.add_theme_color_override("font_color", Color(0.95, 0.80, 0.35))
	grids_vbox.add_child(p_hdr)
	if UiIconManager:
		UiIconManager.set_label_icon(p_hdr, "backpack", "", 14, 5)

	var p_panel := PanelContainer.new()
	p_panel.theme_type_variation = &"GridSurfacePanel"
	grids_vbox.add_child(p_panel)

	ho.sell_player_grid_ctrl = Control.new()
	ho.sell_player_grid_ctrl.name = "SellPlayerGridControl"
	ho.sell_player_grid_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	ho.sell_player_grid_ctrl.draw.connect(func():
		if ho.sell_player_grid_ctrl and ho.player_grid_mgr:
			InventoryUIHelper.draw_2d_grid(ho.sell_player_grid_ctrl, ho.player_grid_mgr, ho.hovered_sell_player_cell, true, false, {}, ho.sell_player_cell_size)
	)
	ho.sell_player_grid_ctrl.gui_input.connect(func(ev: InputEvent):
		ho._handle_sell_grid_input(ev, ho.sell_player_grid_ctrl, ho.player_grid_mgr, false)
	)
	ho.sell_player_grid_ctrl.mouse_exited.connect(func():
		ho.hovered_sell_player_cell = Vector2i(-1, -1)
		if ho.tooltip: ho.tooltip.hide()
		if ho.sell_player_grid_ctrl: ho.sell_player_grid_ctrl.queue_redraw()
	)
	p_panel.add_child(ho.sell_player_grid_ctrl)

	var s_hdr := Label.new()
	s_hdr.text = "은신처 창고 (잠금 아이템 제외)"
	s_hdr.add_theme_font_size_override("font_size", 11)
	s_hdr.add_theme_color_override("font_color", Color(0.55, 0.90, 1.0))
	grids_vbox.add_child(s_hdr)
	if UiIconManager:
		UiIconManager.set_label_icon(s_hdr, "stash", "", 14, 5)

	var s_panel := PanelContainer.new()
	s_panel.theme_type_variation = &"GridSurfacePanel"
	grids_vbox.add_child(s_panel)

	ho.sell_stash_grid_ctrl = Control.new()
	ho.sell_stash_grid_ctrl.name = "SellStashGridControl"
	ho.sell_stash_grid_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	ho.sell_stash_grid_ctrl.draw.connect(func():
		if ho.sell_stash_grid_ctrl and ho.stash_grid_mgr:
			InventoryUIHelper.draw_2d_grid(ho.sell_stash_grid_ctrl, ho.stash_grid_mgr, ho.hovered_sell_stash_cell, false, false, {}, ho.sell_stash_cell_size)
	)
	ho.sell_stash_grid_ctrl.gui_input.connect(func(ev: InputEvent):
		ho._handle_sell_grid_input(ev, ho.sell_stash_grid_ctrl, ho.stash_grid_mgr, true)
	)
	ho.sell_stash_grid_ctrl.mouse_exited.connect(func():
		ho.hovered_sell_stash_cell = Vector2i(-1, -1)
		if ho.tooltip: ho.tooltip.hide()
		if ho.sell_stash_grid_ctrl: ho.sell_stash_grid_ctrl.queue_redraw()
	)
	s_panel.add_child(ho.sell_stash_grid_ctrl)

	# [판매 우측 컬럼] 판매 트레이 영수증 & 일괄 정산 패널
	var right_panel := PanelContainer.new()
	right_panel.name = "ReceiptCol"
	right_panel.custom_minimum_size = Vector2(280, 0)
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 0.85
	if PixelAssetManager:
		var r_sb: StyleBox = PixelAssetManager.get_pixel_stylebox("receipt_panel", 8.0, 8.0, 8.0, 8.0, 4)
		if r_sb != null:
			right_panel.add_theme_stylebox_override("panel", r_sb)
	sell_tab.add_child(right_panel)

	var r_vbox := VBoxContainer.new()
	r_vbox.add_theme_constant_override("separation", 8)
	right_panel.add_child(r_vbox)

	var r_title := Label.new()
	r_title.text = "일괄 판매 정산 영수증"
	if PixelAssetManager:
		r_title.add_theme_font_override("font", PixelAssetManager.get_pixel_font_bold())
	r_title.add_theme_font_size_override("font_size", 12)
	r_title.add_theme_color_override("font_color", Color(0.38, 0.98, 0.72))
	r_vbox.add_child(r_title)
	if UiIconManager:
		UiIconManager.set_label_icon(r_title, "receipt", "", 14, 5)

	var r_scroll := ScrollContainer.new()
	r_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r_vbox.add_child(r_scroll)

	ho.sell_receipt_list_vbox = VBoxContainer.new()
	ho.sell_receipt_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ho.sell_receipt_list_vbox.add_theme_constant_override("separation", 4)
	r_scroll.add_child(ho.sell_receipt_list_vbox)

	ho.sell_receipt_summary_lbl = RichTextLabel.new()
	ho.sell_receipt_summary_lbl.bbcode_enabled = true
	ho.sell_receipt_summary_lbl.fit_content = true
	ho.sell_receipt_summary_lbl.scroll_active = false
	ho.sell_receipt_summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ho.sell_receipt_summary_lbl.add_theme_font_size_override("normal_font_size", 12)
	ho.sell_receipt_summary_lbl.add_theme_color_override("default_color", Color(0.92, 0.95, 0.98))
	r_vbox.add_child(ho.sell_receipt_summary_lbl)

	ho.sell_bulk_btn = Button.new()
	ho.sell_bulk_btn.theme_type_variation = &"PrimaryButton"
	ho.sell_bulk_btn.custom_minimum_size = Vector2(0, 38)
	if UiIconManager:
		UiIconManager.set_button(ho.sell_bulk_btn, "money", "일괄 판매 정산 (Space)", 15)
	else:
		ho.sell_bulk_btn.text = "일괄 판매 정산 (Space)"
	ho.sell_bulk_btn.pressed.connect(Callable(ho, "_execute_bulk_sell"))
	r_vbox.add_child(ho.sell_bulk_btn)

static func refresh_trader_ui(ho: Control) -> void:
	var t_data: Dictionary = ItemDatabase.traders.get(ho.current_trader_id, {})
	if t_data.is_empty():
		return

	ho.trader_desc_label.text = "[%s] %s" % [t_data["name"], t_data["desc"]]

	var w_data: Dictionary = GameManager.current_world_data if GameManager else {}
	if ho.trader_loyalty_label and ho.trader_loyalty_bar:
		var l_info: Dictionary = HideoutProgression.get_trader_loyalty_info(w_data, ho.current_trader_id)
		var cur_lv: int = int(l_info.get("level", 1))
		var q_cnt: int = int(l_info.get("quests", 0))
		var spent: int = int(l_info.get("spent", 0))
		var spec_hint: String = "잡화/기타 매입 55%"
		if ho.current_trader_id == "therapist":
			spec_hint = "특화 매입: 의료·식량·식수 75% (기타 50%)"
		elif ho.current_trader_id == "prapor":
			spec_hint = "특화 매입: 무기·탄약·장비·부품 70% (기타 48%)"
		if cur_lv >= 4:
			ho.trader_loyalty_label.text = "우호도 Lv.4 (최고 등급)  |  완료 의뢰 %d건  |  누적 거래 %d RUB  |  %s" % [q_cnt, spent, spec_hint]
			ho.trader_loyalty_bar.max_value = 100.0
			ho.trader_loyalty_bar.value = 100.0
		else:
			var nq: int = int(l_info.get("next_quests", 1))
			var ns: int = maxi(1, int(l_info.get("next_spent", 15000)))
			ho.trader_loyalty_label.text = "우호도 Lv.%d → 다음 Lv.%d (의뢰 %d/%d건 · 누적 거래 %d/%d RUB)  |  %s" % [cur_lv, cur_lv + 1, q_cnt, nq, spent, ns, spec_hint]
			ho.trader_loyalty_bar.max_value = float(ns)
			ho.trader_loyalty_bar.value = float(mini(spent, ns))
		ho.trader_loyalty_label.tooltip_text = ho.trader_loyalty_label.text

	for child in ho.trader_items_vbox.get_children():
		child.queue_free()

	var user_rubles: int = int(w_data.get("player", {}).get("rubles", 0))
	var discount: float = HideoutProgression.get_trader_discount(w_data) if GameManager else 0.0

	for stock_item in t_data.get("stock", []):
		var item_id: String = str(stock_item["id"])
		var price: int = max(1, int(float(stock_item["price"]) * (1.0 - discount)))
		var amount: int = int(stock_item.get("amount", 1))
		var req_lv: int = maxi(1, int(stock_item.get("min_level", 1)))
		var is_unlocked: bool = HideoutProgression.is_trader_item_unlocked(w_data, ho.current_trader_id, stock_item)
		var item_meta: Dictionary = ItemDatabase.get_item_data(item_id)

		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_theme_constant_override("separation", 10)
		panel.add_child(hbox)

		if ItemIconManager:
			var icon_rect := TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(30, 30)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.texture = ItemIconManager.get_icon(item_id)
			if not is_unlocked:
				icon_rect.modulate = Color(0.5, 0.5, 0.5, 0.75)
			hbox.add_child(icon_rect)

		var name_lbl := Label.new()
		var lv_tag: String = "[Lv.%d] " % req_lv if req_lv > 1 else ""
		name_lbl.text = "%s%s (x%d)" % [lv_tag, item_meta.get("name", item_id), amount]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.custom_minimum_size = Vector2(0, 0)
		name_lbl.clip_text = true
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_lbl.tooltip_text = name_lbl.text
		name_lbl.add_theme_font_size_override("font_size", 12)
		if not is_unlocked:
			name_lbl.add_theme_color_override("font_color", Color(0.58, 0.62, 0.68))
		hbox.add_child(name_lbl)

		var price_lbl := Label.new()
		price_lbl.text = "%d RUB" % price
		price_lbl.add_theme_font_size_override("font_size", 12)
		price_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if is_unlocked else Color(0.6, 0.55, 0.45))
		hbox.add_child(price_lbl)

		var buy_btn := Button.new()
		buy_btn.theme_type_variation = &"SmallButton"
		if is_unlocked:
			if UiIconManager:
				UiIconManager.set_button(buy_btn, "", "구매", 13)
			else:
				buy_btn.text = "구매"
		else:
			if UiIconManager:
				UiIconManager.set_button(buy_btn, "lock", "Lv.%d" % req_lv, 13)
			else:
				buy_btn.text = "Lv.%d" % req_lv
		buy_btn.custom_minimum_size = Vector2(76, 30)
		buy_btn.disabled = (not is_unlocked) or (user_rubles < price)
		if not is_unlocked:
			buy_btn.tooltip_text = "우호도 Lv.%d 달성 시 해금됩니다." % req_lv
		buy_btn.pressed.connect(func(): ho._buy_item(item_id, amount, price))
		hbox.add_child(buy_btn)

		ho.trader_items_vbox.add_child(panel)

	refresh_trader_sell_ui(ho)

static func refresh_trader_sell_ui(ho: Control) -> void:
	var to_erase: Array[String] = []
	for uid_key in ho.selected_sell_uids.keys():
		var uid_s: String = str(uid_key)
		var entry: Dictionary = ho.selected_sell_uids[uid_key]
		var src_grid: InventoryGrid = ho.player_grid_mgr
		if bool(entry.get("is_stash", false)):
			src_grid = ho.stash_grid_mgr
		var it: Dictionary = src_grid.get_item_by_uid(uid_s) if src_grid else {}
		if it.is_empty() or bool(it.get("locked", false)) or (src_grid and src_grid.is_item_in_secure_zone(it)):
			to_erase.append(uid_s)
	for ek in to_erase:
		ho.selected_sell_uids.erase(ek)

	if ho.sell_player_grid_ctrl and ho.player_grid_mgr:
		ho.sell_player_cell_size = ho._compute_fit_cell_size(ho.sell_grids_scroll, ho.player_grid_mgr.grid_width, ho.CELL_SIZE, 54.0)
		ho.sell_player_grid_ctrl.custom_minimum_size = Vector2(float(ho.player_grid_mgr.grid_width) * ho.sell_player_cell_size, float(ho.player_grid_mgr.grid_height) * ho.sell_player_cell_size)
		ho.sell_player_grid_ctrl.set_meta("selected_sell_uids", ho.selected_sell_uids)
		ho.sell_player_grid_ctrl.queue_redraw()
	if ho.sell_stash_grid_ctrl and ho.stash_grid_mgr:
		ho.sell_stash_cell_size = ho._compute_fit_cell_size(ho.sell_grids_scroll, ho.stash_grid_mgr.grid_width, ho.CELL_SIZE, 54.0)
		ho.sell_stash_grid_ctrl.custom_minimum_size = Vector2(float(ho.stash_grid_mgr.grid_width) * ho.sell_stash_cell_size, float(ho.stash_grid_mgr.grid_height) * ho.sell_stash_cell_size)
		ho.sell_stash_grid_ctrl.set_meta("selected_sell_uids", ho.selected_sell_uids)
		ho.sell_stash_grid_ctrl.queue_redraw()

	_update_bulk_sell_toggle_buttons(ho)
	_refresh_sell_receipt_panel(ho)

static func _are_all_bulk_candidates_selected(ho: Control, cands: Array) -> bool:
	if cands.is_empty():
		return false
	for c in cands:
		var uid: String = str(c.get("uid", ""))
		if uid != "" and not ho.selected_sell_uids.has(uid):
			return false
	return true

static func _update_bulk_sell_toggle_buttons(ho: Control) -> void:
	if ho.trader_btn_valuables:
		var v_cands: Array = HideoutProgression.collect_bulk_sell_candidates("valuables", ho.player_grid_mgr, ho.stash_grid_mgr)
		var v_all: bool = _are_all_bulk_candidates_selected(ho, v_cands)
		if UiIconManager:
			UiIconManager.set_button(ho.trader_btn_valuables, "check" if v_all else "broom", "환금템 모두 해제" if v_all else "환금템 모두 담기", 14)
		else:
			ho.trader_btn_valuables.text = "환금템 모두 해제" if v_all else "환금템 모두 담기"
		ho.trader_btn_valuables.add_theme_color_override("font_color", Color(0.45, 1.0, 0.72) if v_all else Color(0.92, 0.94, 0.96))
	if ho.trader_btn_non_gear:
		var ng_cands: Array = HideoutProgression.collect_bulk_sell_candidates("non_gear", ho.player_grid_mgr, ho.stash_grid_mgr)
		var ng_all: bool = _are_all_bulk_candidates_selected(ho, ng_cands)
		if UiIconManager:
			UiIconManager.set_button(ho.trader_btn_non_gear, "check" if ng_all else "box", "장비/무기 제외 해제" if ng_all else "장비/무기 제외 모두 담기", 14)
		else:
			ho.trader_btn_non_gear.text = "장비/무기 제외 해제" if ng_all else "장비/무기 제외 모두 담기"
		ho.trader_btn_non_gear.add_theme_color_override("font_color", Color(0.45, 1.0, 0.72) if ng_all else Color(0.92, 0.94, 0.96))

static func _refresh_sell_receipt_panel(ho: Control) -> void:
	if not ho.sell_receipt_list_vbox or not ho.sell_receipt_summary_lbl or not ho.sell_bulk_btn:
		return
	for ch in ho.sell_receipt_list_vbox.get_children():
		ch.queue_free()

	var w_data: Dictionary = GameManager.current_world_data if GameManager else {}
	var preview: Dictionary = HideoutProgression.preview_bulk_sell_receipt(ho.current_trader_id, ho.selected_sell_uids.values(), w_data, ho.player_grid_mgr, ho.stash_grid_mgr)
	var line_items: Array = preview.get("line_items", [])

	if line_items.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "판매 트레이가 비어 있습니다.\n\n좌측 배낭/창고 그리드에서\nAlt+좌클릭 / 우클릭 또는 드래그로\n아이템을 담아 주세요."
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color(0.62, 0.68, 0.76))
		ho.sell_receipt_list_vbox.add_child(empty_lbl)
	else:
		for ln in line_items:
			var it_id: String = str(ln.get("id", ""))
			var idata: Dictionary = ItemDatabase.get_item_data(it_id)
			var disp_name: String = str(idata.get("name", it_id))
			var amt: int = int(ln.get("amount", 1))
			var fin: int = int(ln.get("final_total", 0))
			var drop_amt: int = int(ln.get("drop_amount", 0))

			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			var name_l := Label.new()
			name_l.text = "%s%s" % [disp_name, (" x%d" % amt if amt > 1 else "")]
			name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_l.clip_text = true
			name_l.add_theme_font_size_override("font_size", 11)
			row.add_child(name_l)

			var price_l := Label.new()
			price_l.text = "+%d RUB" % fin if drop_amt <= 0 else "+%d (-%d)" % [fin, drop_amt]
			price_l.add_theme_font_size_override("font_size", 11)
			price_l.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55) if drop_amt <= 0 else Color(1.0, 0.80, 0.35))
			row.add_child(price_l)

			ho.sell_receipt_list_vbox.add_child(row)

	var valid_cnt: int = int(preview.get("valid_count", 0))
	var total_units: int = int(preview.get("total_units", 0))
	var final_rubles: int = int(preview.get("total_final_rubles", 0))
	var loss_rubles: int = int(preview.get("elasticity_loss_rubles", 0))
	var loss_pct: float = float(preview.get("elasticity_loss_pct", 0.0))

	var ic_box: String = (UiIconManager.bbcode_icon("box", 13) + " ") if UiIconManager else ""
	var ic_down: String = (UiIconManager.bbcode_icon("chart_down", 13) + " ") if UiIconManager else ""
	var ic_money: String = (UiIconManager.bbcode_icon("money_green", 13) + " ") if UiIconManager else ""
	var sum_lines: Array[String] = []
	sum_lines.append("──────────────────────────")
	sum_lines.append("%s선택 품목: %d슬롯 (총 %d개)" % [ic_box, valid_cnt, total_units])
	if loss_rubles > 0:
		sum_lines.append("%s대량 매각 시세 하락: -%d RUB (-%.1f%%)" % [ic_down, loss_rubles, loss_pct])
	sum_lines.append("%s예상 정산 금액: %d RUB" % [ic_money, final_rubles])
	ho.sell_receipt_summary_lbl.text = "\n".join(sum_lines)
	ho.sell_receipt_summary_lbl.add_theme_color_override("default_color", Color(1.0, 0.85, 0.35) if loss_rubles > 0 else Color(0.88, 0.96, 0.92))
	ho.sell_bulk_btn.disabled = (valid_cnt <= 0)

static func toggle_sell_selection(ho: Control, item: Dictionary, mgr: InventoryGrid, is_stash: bool) -> void:
	if item.is_empty() or not mgr:
		return
	var uid: String = str(item.get("uid", ""))
	if uid == "":
		return
	if ho.selected_sell_uids.has(uid):
		ho.selected_sell_uids.erase(uid)
		ho._refresh_trader_sell_ui()
		if SoundManager: SoundManager.play("menu_move")
		return
	if bool(item.get("locked", false)):
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:lock] 잠금된 아이템은 판매 트레이에 담을 수 없습니다. ([L] 키로 해제)")
		if SoundManager: SoundManager.play("hit_melee")
		return
	if mgr.is_item_in_secure_zone(item):
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:lock] 2x2 안전 컨테이너 내 아이템은 일괄 판매에서 보호됩니다.")
		if SoundManager: SoundManager.play("hit_melee")
		return
	var inner: Variant = item.get("inner_items", [])
	if inner is Array and not inner.is_empty():
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:warn] 내부에 아이템이 든 컨테이너는 먼저 비워 주세요.")
		if SoundManager: SoundManager.play("hit_melee")
		return
	ho.selected_sell_uids[uid] = {
		"uid": uid,
		"is_stash": is_stash,
		"source_grid": mgr
	}
	ho._refresh_trader_sell_ui()
	if SoundManager: SoundManager.play("menu_select")

static func auto_select_bulk_sell(ho: Control, mode: String) -> void:
	var cands: Array = HideoutProgression.collect_bulk_sell_candidates(mode, ho.player_grid_mgr, ho.stash_grid_mgr)
	if _are_all_bulk_candidates_selected(ho, cands):
		for c in cands:
			var uid: String = str(c.get("uid", ""))
			if uid != "":
				ho.selected_sell_uids.erase(uid)
	else:
		for c in cands:
			var uid: String = str(c.get("uid", ""))
			if uid != "":
				ho.selected_sell_uids[uid] = c
	ho._refresh_trader_sell_ui()
	if SoundManager:
		SoundManager.play("menu_select" if not cands.is_empty() else "menu_move")

static func execute_bulk_sell(ho: Control) -> void:
	if ho.selected_sell_uids.is_empty() or not GameManager:
		return
	var entries: Array = ho.selected_sell_uids.values()
	var res: Dictionary = HideoutProgression.execute_bulk_sell(ho.current_trader_id, entries, GameManager.current_world_data, ho.player_grid_mgr, ho.stash_grid_mgr)
	if bool(res.get("success", false)):
		ho.selected_sell_uids.clear()
		if SoundManager: SoundManager.play("level_up")
		ho._update_money_label()
		ho._refresh_stash_ui()
		ho._refresh_trader_ui()
		ho._sync_save_data()

static func handle_sell_grid_input(ho: Control, event: InputEvent, ctrl: Control, mgr: InventoryGrid, is_stash: bool) -> void:
	if not ctrl or not mgr:
		return
	var csz: float = ho._get_grid_cell_size(ctrl)
	var local_pos: Vector2 = ctrl.get_local_mouse_position()
	var cx: int = int(floor(local_pos.x / csz))
	var cy: int = int(floor(local_pos.y / csz))

	if event is InputEventMouseMotion:
		var in_bounds: bool = (cx >= 0 and cx < mgr.grid_width and cy >= 0 and cy < mgr.grid_height)
		if is_stash:
			ho.hovered_sell_stash_cell = Vector2i(cx, cy) if in_bounds else Vector2i(-1, -1)
		else:
			ho.hovered_sell_player_cell = Vector2i(cx, cy) if in_bounds else Vector2i(-1, -1)

		if ho._is_marquee_selecting and ho._marquee_ctrl == ctrl:
			var x0: float = minf(ho._marquee_start_local.x, local_pos.x)
			var y0: float = minf(ho._marquee_start_local.y, local_pos.y)
			var x1: float = maxf(ho._marquee_start_local.x, local_pos.x)
			var y1: float = maxf(ho._marquee_start_local.y, local_pos.y)
			ctrl.set_meta("marquee_rect", Rect2(x0, y0, x1 - x0, y1 - y0))
			if ho.tooltip: ho.tooltip.hide()
		elif in_bounds:
			var h_item: Dictionary = mgr.get_item_at(cx, cy)
			if not h_item.is_empty() and ho.tooltip:
				var idata: Dictionary = ItemDatabase.get_item_data(str(h_item.get("id", "")))
				ho.tooltip.display_item(h_item, idata)
				ho.tooltip.update_position(ho.get_global_mouse_position())
			elif ho.tooltip:
				ho.tooltip.hide()
		elif ho.tooltip:
			ho.tooltip.hide()
		ctrl.queue_redraw()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var r_item: Dictionary = mgr.get_item_at(cx, cy)
			if not r_item.is_empty():
				ho._toggle_sell_selection(r_item, mgr, is_stash)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var l_item: Dictionary = mgr.get_item_at(cx, cy)
				if (event.alt_pressed or Input.is_key_pressed(KEY_ALT)) and not l_item.is_empty():
					ho._toggle_sell_selection(l_item, mgr, is_stash)
				else:
					ho._is_marquee_selecting = true
					ho._marquee_ctrl = ctrl
					ho._marquee_grid = mgr
					ho._marquee_is_stash = is_stash
					ho._marquee_start_local = local_pos
					ctrl.set_meta("marquee_rect", Rect2(local_pos, Vector2.ZERO))
					ctrl.queue_redraw()
			elif ho._is_marquee_selecting and ho._marquee_ctrl == ctrl:
				var raw_rect: Variant = ctrl.get_meta("marquee_rect", Rect2())
				var m_rect: Rect2 = raw_rect if raw_rect is Rect2 else Rect2()
				ctrl.remove_meta("marquee_rect")
				ho._is_marquee_selecting = false
				ho._marquee_ctrl = null
				ho._marquee_grid = null
				if m_rect.size.x < 6.0 and m_rect.size.y < 6.0:
					var click_item: Dictionary = mgr.get_item_at(cx, cy)
					if not click_item.is_empty():
						ho._toggle_sell_selection(click_item, mgr, is_stash)
				else:
					apply_marquee_selection(ho, m_rect, mgr, is_stash, ctrl)
				ctrl.queue_redraw()

static func apply_marquee_selection(ho: Control, m_rect: Rect2, mgr: InventoryGrid, is_stash: bool, ctrl: Control = null) -> void:
	if not mgr:
		return
	var csz: float = ho._get_grid_cell_size(ctrl)
	var added_cnt: int = 0
	for it in mgr.items:
		if it.is_empty():
			continue
		if bool(it.get("locked", false)) or mgr.is_item_in_secure_zone(it):
			continue
		var inner: Variant = it.get("inner_items", [])
		if inner is Array and not inner.is_empty():
			continue
		var is_rot: bool = bool(it.get("rotated", false))
		var cw: int = int(it.get("h", 1)) if is_rot else int(it.get("w", 1))
		var ch: int = int(it.get("w", 1)) if is_rot else int(it.get("h", 1))
		var item_rect := Rect2(float(it.get("x", 0)) * csz, float(it.get("y", 0)) * csz, float(cw) * csz, float(ch) * csz)
		if m_rect.intersects(item_rect):
			var uid: String = str(it.get("uid", ""))
			if uid != "" and not ho.selected_sell_uids.has(uid):
				ho.selected_sell_uids[uid] = {
					"uid": uid,
					"is_stash": is_stash,
					"source_grid": mgr
				}
				added_cnt += 1
	ho._refresh_trader_sell_ui()
	if SoundManager:
		SoundManager.play("menu_select" if added_cnt > 0 else "menu_move")

static func buy_item(ho: Control, item_id: String, amount: int, price: int) -> void:
	var user_rubles: int = int(GameManager.current_world_data.get("player", {}).get("rubles", 0))
	if user_rubles < price or amount <= 0:
		return

	var remaining: int = ho.player_grid_mgr.auto_add_item(item_id, amount) if ho.player_grid_mgr else amount
	if remaining > 0 and ho.stash_grid_mgr:
		remaining = ho.stash_grid_mgr.auto_add_item(item_id, remaining)
	var added: int = amount - remaining
	if added <= 0:
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:warn] 배낭과 창고 공간이 모두 부족하여 구매할 수 없습니다.")
		if SoundManager: SoundManager.play("hit_melee")
		return

	var actual_cost: int = price if added >= amount else maxi(1, int(ceil(float(price) * float(added) / float(amount))))
	GameManager.current_world_data["player"]["rubles"] -= actual_cost
	HideoutProgression.record_trader_transaction(GameManager.current_world_data, ho.current_trader_id, actual_cost)
	if FleaMarket:
		FleaMarket.record_player_purchase(item_id, added)
	if remaining > 0 and EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("[icon:warn] 공간이 부족하여 %d/%d개만 구매했습니다. (%d RUB 결제)" % [added, amount, actual_cost])
	ho._update_money_label()

	if SoundManager: SoundManager.play("menu_select")
	ho._refresh_trader_ui()
	ho._sync_save_data()

static func sell_item(ho: Control, uid: String, is_stash: bool, item_id: String, amount: int, unit_price: int) -> void:
	var total_gain: int = unit_price * amount
	GameManager.current_world_data["player"]["rubles"] += total_gain
	HideoutProgression.record_trader_transaction(GameManager.current_world_data, ho.current_trader_id, total_gain)
	if FleaMarket:
		FleaMarket.record_player_sale(item_id, amount)
	ho._update_money_label()

	if is_stash:
		ho.stash_grid_mgr.remove_item_by_uid(uid)
		ho._refresh_stash_ui()
	else:
		ho.player_grid_mgr.remove_item_by_uid(uid)

	if SoundManager: SoundManager.play("menu_select")
	ho._refresh_trader_ui()
	ho._sync_save_data()
