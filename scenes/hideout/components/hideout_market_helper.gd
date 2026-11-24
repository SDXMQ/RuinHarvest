# res://scenes/hideout/components/hideout_market_helper.gd
extends RefCounted

## 은신처 플리마켓 탭(매물/긴급수배 목록, 2D 등록 그리드, 검색·필터, 위탁 등록/구매) 헬퍼

static func setup_market_controls(ho: Control) -> void:
	var m_vbox: VBoxContainer = ho.get_node_or_null("CenterArea/TabContainer/MarketTab/VBox") as VBoxContainer
	if not m_vbox:
		return
	var old_market_scroll: Control = m_vbox.get_node_or_null("Scroll") as Control
	var old_reg_area: Control = m_vbox.get_node_or_null("RegisterArea") as Control
	if old_reg_area:
		old_reg_area.hide()

	var market_main_hbox := HBoxContainer.new()
	market_main_hbox.name = "MarketMainHBox"
	market_main_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	market_main_hbox.add_theme_constant_override("separation", 12)
	m_vbox.add_child(market_main_hbox)

	# [좌측 컬럼] 긴급 수배 및 암시장 매물 목록
	var listings_col := VBoxContainer.new()
	listings_col.name = "MarketListingsCol"
	listings_col.custom_minimum_size = Vector2(360, 0)
	listings_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	listings_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	listings_col.size_flags_stretch_ratio = 1.0
	listings_col.add_theme_constant_override("separation", 6)
	market_main_hbox.add_child(listings_col)

	var listings_hdr := Label.new()
	listings_hdr.text = "오늘의 2.5x 긴급 수배 & 암시장 매물"
	listings_hdr.add_theme_font_size_override("font_size", 12)
	listings_hdr.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	listings_col.add_child(listings_hdr)
	if UiIconManager:
		UiIconManager.set_label_icon(listings_hdr, "shop", "", 14, 5)

	if old_market_scroll:
		m_vbox.remove_child(old_market_scroll)
		old_market_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		old_market_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if old_market_scroll is ScrollContainer:
			(old_market_scroll as ScrollContainer).horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		if ho.market_items_vbox:
			ho.market_items_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		listings_col.add_child(old_market_scroll)

	# [우측 컬럼] 검색/필터 + 배낭·창고 2D 그리드 + 선택 등록 확인 패널
	var reg_col := VBoxContainer.new()
	reg_col.name = "MarketRegisterCol"
	reg_col.custom_minimum_size = Vector2(360, 0)
	reg_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reg_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reg_col.size_flags_stretch_ratio = 1.05
	reg_col.add_theme_constant_override("separation", 6)
	market_main_hbox.add_child(reg_col)

	ho.market_slot_label = Label.new()
	ho.market_slot_label.clip_text = true
	ho.market_slot_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ho.market_slot_label.add_theme_font_size_override("font_size", 12)
	ho.market_slot_label.add_theme_color_override("font_color", Color(0.45, 0.90, 1.0))
	reg_col.add_child(ho.market_slot_label)
	if UiIconManager:
		UiIconManager.set_label_icon(ho.market_slot_label, "money", "", 14, 5)

	var guide_panel := PanelContainer.new()
	guide_panel.name = "MarketGuidePanel"
	var guide_sb := StyleBoxFlat.new()
	guide_sb.bg_color = Color(0.08, 0.12, 0.18, 0.90)
	guide_sb.set_border_width_all(1)
	guide_sb.border_color = Color(0.24, 0.42, 0.58, 0.75)
	guide_sb.set_corner_radius_all(4)
	guide_sb.content_margin_left = 8
	guide_sb.content_margin_right = 8
	guide_sb.content_margin_top = 5
	guide_sb.content_margin_bottom = 5
	guide_panel.add_theme_stylebox_override("panel", guide_sb)
	var guide_lbl := Label.new()
	guide_lbl.text = "위탁 판매 안내: 아이템 선택 → 희망 배율(x0.9~x2.0) 설정 → 등록 시 선불 수수료(5~35%) 차감\n레이드 귀환(출격 1회) 후 자동 판매·정산되며, 미판매/만료 품목은 은신처 창고로 자동 반환됩니다."
	guide_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_lbl.add_theme_font_size_override("font_size", 10)
	guide_lbl.add_theme_color_override("font_color", Color(0.76, 0.88, 0.96))
	guide_panel.add_child(guide_lbl)
	if UiIconManager:
		UiIconManager.set_label_icon(guide_lbl, "book", "", 14, 6)
	reg_col.add_child(guide_panel)

	# 1. 이름 검색창 + 초기화 + 매칭 개수 표시
	var search_row := HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 6)
	reg_col.add_child(search_row)

	if UiIconManager:
		search_row.add_child(UiIconManager.create_icon_rect("search", 15))

	ho.market_search_input = LineEdit.new()
	ho.market_search_input.name = "MarketSearchInput"
	ho.market_search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ho.market_search_input.placeholder_text = "아이템 이름 검색 (예: 그래픽카드, 열쇠, SSD...)"
	ho.market_search_input.clear_button_enabled = true
	ho.market_search_input.text_changed.connect(func(new_txt: String):
		ho.market_search_text = new_txt.strip_edges()
		ho._refresh_market_register_ui()
	)
	search_row.add_child(ho.market_search_input)

	var clr_btn := Button.new()
	clr_btn.theme_type_variation = &"SmallButton"
	clr_btn.text = "초기화"
	clr_btn.custom_minimum_size = Vector2(56, 0)
	clr_btn.focus_mode = Control.FOCUS_NONE
	clr_btn.pressed.connect(func():
		ho.market_search_text = ""
		ho.market_filter_category = "all"
		if ho.market_search_input:
			ho.market_search_input.text = ""
		ho._refresh_market_register_ui()
	)
	search_row.add_child(clr_btn)

	ho.market_result_count_lbl = Label.new()
	ho.market_result_count_lbl.add_theme_font_size_override("font_size", 11)
	ho.market_result_count_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	search_row.add_child(ho.market_result_count_lbl)

	# 2. 카테고리 필터 버튼
	var cat_row := HBoxContainer.new()
	cat_row.add_theme_constant_override("separation", 4)
	reg_col.add_child(cat_row)

	ho.market_filter_buttons.clear()
	var cat_defs: Array = [
		["all", "전체"],
		["valuables", "고가/잡화"],
		["combat", "무기/부품/방어"],
		["medical_supply", "의료/식량"],
		["key_case", "열쇠/케이스"]
	]
	for c_def in cat_defs:
		var cid: String = str(c_def[0])
		var cname: String = str(c_def[1])
		var f_btn := Button.new()
		f_btn.theme_type_variation = &"SmallButton"
		f_btn.text = cname
		f_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		f_btn.add_theme_font_size_override("font_size", 10)
		f_btn.focus_mode = Control.FOCUS_NONE
		var cap_cid: String = cid
		f_btn.pressed.connect(func():
			ho.market_filter_category = cap_cid
			ho._refresh_market_register_ui()
		)
		cat_row.add_child(f_btn)
		ho.market_filter_buttons[cid] = f_btn

	# 3. 등록 가격 배율 프리셋
	var ratio_row := HBoxContainer.new()
	ratio_row.add_theme_constant_override("separation", 6)
	reg_col.add_child(ratio_row)

	var ratio_lbl := Label.new()
	ratio_lbl.text = "등록 가격 배율:"
	ratio_lbl.add_theme_font_size_override("font_size", 11)
	ratio_row.add_child(ratio_lbl)

	ho.market_ratio_buttons.clear()
	for r_val in [0.9, 1.0, 1.2, 1.5, 2.0]:
		var r_btn := Button.new()
		r_btn.theme_type_variation = &"SmallButton"
		r_btn.text = "x%.1f" % float(r_val)
		r_btn.custom_minimum_size = Vector2(46, 24)
		r_btn.add_theme_font_size_override("font_size", 10)
		r_btn.focus_mode = Control.FOCUS_NONE
		var cap_r: float = float(r_val)
		r_btn.pressed.connect(func():
			ho.market_price_ratio = cap_r
			ho._refresh_market_register_ui()
		)
		ratio_row.add_child(r_btn)
		ho.market_ratio_buttons[str(r_val)] = r_btn

	# 4. 배낭 & 창고 2D 그리드
	ho.market_grids_scroll = ScrollContainer.new()
	ho.market_grids_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ho.market_grids_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ho.market_grids_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ho.market_grids_scroll.resized.connect(Callable(ho, "_update_all_hideout_grid_sizes"))
	reg_col.add_child(ho.market_grids_scroll)

	var grids_vbox := VBoxContainer.new()
	grids_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grids_vbox.add_theme_constant_override("separation", 8)
	ho.market_grids_scroll.add_child(grids_vbox)

	var mp_hdr := Label.new()
	mp_hdr.text = "내 배낭 (클릭: 선택 | 더블클릭·Ctrl+클릭: 즉시 등록 | [L]: 잠금)"
	mp_hdr.add_theme_font_size_override("font_size", 11)
	mp_hdr.add_theme_color_override("font_color", Color(0.95, 0.82, 0.36))
	grids_vbox.add_child(mp_hdr)
	if UiIconManager:
		UiIconManager.set_label_icon(mp_hdr, "backpack", "", 14, 5)

	var mp_panel := PanelContainer.new()
	mp_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_panel.theme_type_variation = &"GridSurfacePanel"
	grids_vbox.add_child(mp_panel)

	ho.market_player_grid_ctrl = Control.new()
	ho.market_player_grid_ctrl.name = "MarketPlayerGridControl"
	ho.market_player_grid_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	ho.market_player_grid_ctrl.draw.connect(func():
		if ho.market_player_grid_ctrl and ho.player_grid_mgr:
			InventoryUIHelper.draw_2d_grid(ho.market_player_grid_ctrl, ho.player_grid_mgr, ho.hovered_market_player_cell, true, false, {}, ho.market_player_cell_size)
	)
	ho.market_player_grid_ctrl.gui_input.connect(func(ev: InputEvent):
		ho._handle_market_grid_input(ev, ho.market_player_grid_ctrl, ho.player_grid_mgr, false)
	)
	ho.market_player_grid_ctrl.mouse_exited.connect(func():
		ho.hovered_market_player_cell = Vector2i(-1, -1)
		if ho.tooltip: ho.tooltip.hide()
		if ho.market_player_grid_ctrl: ho.market_player_grid_ctrl.queue_redraw()
	)
	mp_panel.add_child(ho.market_player_grid_ctrl)

	var ms_hdr := Label.new()
	ms_hdr.text = "은신처 창고 (검색/필터 미일치 및 등록 불가 품목은 어둡게 표시됨)"
	ms_hdr.add_theme_font_size_override("font_size", 11)
	ms_hdr.add_theme_color_override("font_color", Color(0.55, 0.90, 1.0))
	grids_vbox.add_child(ms_hdr)
	if UiIconManager:
		UiIconManager.set_label_icon(ms_hdr, "stash", "", 14, 5)

	var ms_panel := PanelContainer.new()
	ms_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ms_panel.theme_type_variation = &"GridSurfacePanel"
	grids_vbox.add_child(ms_panel)

	ho.market_stash_grid_ctrl = Control.new()
	ho.market_stash_grid_ctrl.name = "MarketStashGridControl"
	ho.market_stash_grid_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	ho.market_stash_grid_ctrl.draw.connect(func():
		if ho.market_stash_grid_ctrl and ho.stash_grid_mgr:
			InventoryUIHelper.draw_2d_grid(ho.market_stash_grid_ctrl, ho.stash_grid_mgr, ho.hovered_market_stash_cell, false, false, {}, ho.market_stash_cell_size)
	)
	ho.market_stash_grid_ctrl.gui_input.connect(func(ev: InputEvent):
		ho._handle_market_grid_input(ev, ho.market_stash_grid_ctrl, ho.stash_grid_mgr, true)
	)
	ho.market_stash_grid_ctrl.mouse_exited.connect(func():
		ho.hovered_market_stash_cell = Vector2i(-1, -1)
		if ho.tooltip: ho.tooltip.hide()
		if ho.market_stash_grid_ctrl: ho.market_stash_grid_ctrl.queue_redraw()
	)
	ms_panel.add_child(ho.market_stash_grid_ctrl)

	# 5. 하단 선택 아이템 등록 확인 패널
	var confirm_panel := PanelContainer.new()
	confirm_panel.name = "MarketConfirmPanel"
	if PixelAssetManager:
		var c_sb: StyleBox = PixelAssetManager.get_pixel_stylebox("market_confirm_panel", 8.0, 6.0, 8.0, 6.0, 4)
		if c_sb != null:
			confirm_panel.add_theme_stylebox_override("panel", c_sb)
	reg_col.add_child(confirm_panel)

	var c_hbox := HBoxContainer.new()
	c_hbox.add_theme_constant_override("separation", 10)
	confirm_panel.add_child(c_hbox)

	ho.market_preview_lbl = Label.new()
	ho.market_preview_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ho.market_preview_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ho.market_preview_lbl.add_theme_font_size_override("font_size", 11)
	ho.market_preview_lbl.text = "2D 그리드에서 암시장에 등록할 아이템을 클릭하세요."
	c_hbox.add_child(ho.market_preview_lbl)
	if UiIconManager:
		UiIconManager.set_label_icon(ho.market_preview_lbl, "tip", "", 14, 6)

	ho.market_confirm_btn = Button.new()
	ho.market_confirm_btn.theme_type_variation = &"PrimaryButton"
	ho.market_confirm_btn.custom_minimum_size = Vector2(148, 36)
	if UiIconManager:
		UiIconManager.set_button(ho.market_confirm_btn, "chart_up", "암시장 등록", 15)
	else:
		ho.market_confirm_btn.text = "암시장 등록"
	ho.market_confirm_btn.disabled = true
	ho.market_confirm_btn.focus_mode = Control.FOCUS_NONE
	ho.market_confirm_btn.pressed.connect(Callable(ho, "_try_register_selected_market_item"))
	c_hbox.add_child(ho.market_confirm_btn)

static func refresh_market_ui(ho: Control) -> void:
	if not FleaMarket:
		return

	for child in ho.market_items_vbox.get_children():
		child.queue_free()

	var user_rubles: int = int(GameManager.current_world_data.get("player", {}).get("rubles", 0))
	var cur_day: int = int(GameManager.current_world_data.get("current_day", FleaMarket.current_day)) if GameManager else FleaMarket.current_day
	var bounties: Array = FleaMarket.get_daily_bounties(cur_day)
	if not bounties.is_empty():
		var bounty_panel := PanelContainer.new()
		bounty_panel.name = "BountyOrderPanel"
		bounty_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if PixelAssetManager:
			var bounty_sb: StyleBox = PixelAssetManager.get_pixel_stylebox("bounty_panel", 12.0, 10.0, 12.0, 10.0, 4)
			if bounty_sb != null:
				bounty_panel.add_theme_stylebox_override("panel", bounty_sb)

		var b_vbox := VBoxContainer.new()
		b_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_vbox.add_theme_constant_override("separation", 8)
		bounty_panel.add_child(b_vbox)

		var b_title := Label.new()
		b_title.text = "[오늘의 2.5x 긴급 수배] 암시장 특수 상인 고가 매입 품목"
		b_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if PixelAssetManager:
			b_title.add_theme_font_override("font", PixelAssetManager.get_pixel_font_bold())
		b_title.add_theme_font_size_override("font_size", 12)
		b_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.28))
		b_vbox.add_child(b_title)
		if UiIconManager:
			UiIconManager.set_label_icon(b_title, "fire", "", 15, 5)

		for b_entry in bounties:
			var b_id: String = String(b_entry.get("item_id", ""))
			var b_name: String = String(b_entry.get("name", b_id))
			var b_price: int = int(b_entry.get("bounty_price", 0))
			var m_price: int = int(b_entry.get("market_price", 0))
			var owned_cnt: int = HideoutProgression.count_total_item(b_id, ho.player_grid_mgr, ho.stash_grid_mgr)

			var b_row := HBoxContainer.new()
			b_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b_row.add_theme_constant_override("separation", 8)
			if ItemIconManager:
				var b_icon := TextureRect.new()
				b_icon.custom_minimum_size = Vector2(28, 28)
				b_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				b_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				b_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				b_icon.texture = ItemIconManager.get_icon(b_id)
				b_row.add_child(b_icon)

			var b_info_vbox := VBoxContainer.new()
			b_info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b_info_vbox.add_theme_constant_override("separation", 2)

			var b_name_lbl := Label.new()
			b_name_lbl.text = "%s  (보유: %d개)" % [b_name, owned_cnt]
			b_name_lbl.clip_text = true
			b_name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			b_name_lbl.add_theme_font_size_override("font_size", 12)
			b_name_lbl.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55) if owned_cnt > 0 else Color(0.92, 0.88, 0.76))
			b_info_vbox.add_child(b_name_lbl)
			if UiIconManager:
				UiIconManager.set_label_icon(b_name_lbl, "star", "", 13, 4)

			var b_price_lbl := Label.new()
			b_price_lbl.text = "시세 %d → 수배 매입가 %d RUB (x2.5)" % [m_price, b_price]
			b_price_lbl.clip_text = true
			b_price_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			b_price_lbl.add_theme_font_size_override("font_size", 10)
			b_price_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.42))
			b_info_vbox.add_child(b_price_lbl)
			b_row.add_child(b_info_vbox)

			var sell_b_btn := Button.new()
			sell_b_btn.theme_type_variation = &"SmallButton"
			if UiIconManager:
				UiIconManager.set_button(sell_b_btn, "fire", "납품", 14)
			else:
				sell_b_btn.text = "납품"
			sell_b_btn.custom_minimum_size = Vector2(82, 30)
			sell_b_btn.tooltip_text = "즉시 납품 (+%d RUB)" % b_price
			sell_b_btn.disabled = (owned_cnt <= 0)
			var cap_id: String = b_id
			sell_b_btn.pressed.connect(func():
				var res: Dictionary = FleaMarket.fulfill_bounty_order(cap_id, 1, GameManager.current_world_data, ho.player_grid_mgr, ho.stash_grid_mgr)
				if bool(res.get("success", false)):
					if SoundManager: SoundManager.play("level_up")
					ho._update_money_label()
					ho._refresh_stash_ui()
					ho._refresh_market_ui()
					ho._sync_save_data()
			)
			b_row.add_child(sell_b_btn)
			b_vbox.add_child(b_row)
		ho.market_items_vbox.add_child(bounty_panel)

	for listing in FleaMarket.listings:
		var item_id: String = str(listing["item_name"])
		var price: int = int(listing["price"])
		var amount: int = int(listing["count"])
		var is_player_listing: bool = bool(listing.get("is_player", false))
		var stock_rem: int = int(listing.get("stock_remaining", 1))
		var is_sold_out: bool = bool(listing.get("sold_out", false)) or stock_rem <= 0
		var item_meta: Dictionary = ItemDatabase.get_item_data(item_id)

		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_theme_constant_override("separation", 8)
		panel.add_child(hbox)

		if ItemIconManager:
			var icon_rect := TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(32, 32)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.texture = ItemIconManager.get_icon(item_id)
			if is_sold_out:
				icon_rect.modulate = Color(0.45, 0.45, 0.45, 0.65)
			hbox.add_child(icon_rect)

		var name_lbl := Label.new()
		var stock_txt: String = "[내 등록 매물 · 대기 중]" if is_player_listing else ("[품절]" if is_sold_out else "재고 %d개" % stock_rem)
		name_lbl.text = "%s (x%d)  [%s]" % [item_meta.get("name", item_id), amount, stock_txt]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.custom_minimum_size = Vector2(0, 0)
		name_lbl.clip_text = true
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_lbl.tooltip_text = name_lbl.text
		if is_sold_out:
			name_lbl.add_theme_color_override("font_color", Color(0.55, 0.58, 0.62))
		elif is_player_listing:
			name_lbl.add_theme_color_override("font_color", Color(0.45, 0.88, 1.0))
		hbox.add_child(name_lbl)

		var price_lbl := Label.new()
		price_lbl.text = "%d RUB" % (price * amount)
		price_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2) if not is_sold_out else Color(0.5, 0.48, 0.45))
		hbox.add_child(price_lbl)

		var buy_btn := Button.new()
		buy_btn.text = "품절" if is_sold_out else ("등록중" if is_player_listing else "구매")
		buy_btn.custom_minimum_size = Vector2(68, 32)
		buy_btn.disabled = is_sold_out or is_player_listing or (user_rubles < price * amount)
		var cap_listing: Dictionary = listing
		buy_btn.pressed.connect(func(): ho._buy_market_item(cap_listing, price * amount))
		hbox.add_child(buy_btn)

		ho.market_items_vbox.add_child(panel)

	refresh_market_register_ui(ho)

static func is_market_item_registerable(item: Dictionary) -> Dictionary:
	if item.is_empty():
		return {"ok": false, "reason": "아이템을 선택하세요."}
	if bool(item.get("locked", false)):
		return {"ok": false, "reason": "[icon:lock] 잠금된 아이템은 등록할 수 없습니다. ([L] 키로 해제)"}
	var inner: Variant = item.get("inner_items", [])
	if inner is Array and not inner.is_empty():
		return {"ok": false, "reason": "[icon:warn] 내부에 아이템이 든 컨테이너는 비운 뒤 등록할 수 있습니다."}
	var item_id: String = str(item.get("id", ""))
	if item_id in ["Scav 식별줄(Dogtag)", "Scav 인식표"]:
		return {"ok": false, "reason": "[icon:warn] Scav 인식표는 암시장에 등록할 수 없습니다."}
	return {"ok": true, "reason": ""}

static func does_market_item_match_filter(ho: Control, item: Dictionary) -> bool:
	if item.is_empty():
		return false
	var item_id: String = str(item.get("id", ""))
	var resolved: String = ItemDatabase.resolve_item_id(item_id) if (ItemDatabase and ItemDatabase.has_method("resolve_item_id")) else item_id
	var data: Dictionary = ItemDatabase.get_item_data(resolved) if ItemDatabase else {}
	if ho.market_search_text != "":
		var disp_name: String = str(data.get("name", item_id))
		if not disp_name.containsn(ho.market_search_text) and not item_id.containsn(ho.market_search_text) and not resolved.containsn(ho.market_search_text):
			return false
	if ho.market_filter_category == "all":
		return true
	var cat: int = int(data.get("category", -1))
	var itype: String = str(data.get("type", item.get("type", "")))
	match ho.market_filter_category:
		"valuables":
			return cat == ItemDatabase.ItemCategory.MISC or cat == ItemDatabase.ItemCategory.MATERIAL
		"combat":
			if itype == "storage_case":
				return false
			return (
				cat == ItemDatabase.ItemCategory.WEAPON
				or cat == ItemDatabase.ItemCategory.EQUIPMENT
				or itype in ["receiver", "assembled_weapon", "part", "ammo"]
				or (ItemDatabase and ItemDatabase.is_ammo_item(resolved))
				or (WeaponPartsDatabase and (WeaponPartsDatabase.PARTS.has(resolved) or WeaponPartsDatabase.RECEIVERS.has(resolved)))
			)
		"medical_supply":
			return cat in [ItemDatabase.ItemCategory.MEDICAL, ItemDatabase.ItemCategory.FOOD, ItemDatabase.ItemCategory.WATER]
		"key_case":
			return (
				itype in ["key", "keycard", "storage_case", "dogtag"]
				or resolved.contains("열쇠")
				or resolved.contains("키카드")
				or resolved.contains("케이스")
				or resolved.contains("상자")
				or resolved.contains("지갑")
				or resolved.contains("인식표")
			)
	return true

static func refresh_market_register_ui(ho: Control) -> void:
	if ho.market_register_grid:
		for child in ho.market_register_grid.get_children():
			child.queue_free()

	var used_slots: int = FleaMarket.player_listings.size() if FleaMarket else 0
	var max_slots: int = FleaMarket.MAX_PLAYER_LISTINGS if FleaMarket else 3
	var can_reg: bool = FleaMarket.can_register_more_listings() if FleaMarket else false
	if ho.market_slot_label:
		ho.market_slot_label.text = "암시장 위탁 판매 등록  |  보유 슬롯: %d / %d  |  누진 수수료 5%%~35%%" % [used_slots, max_slots]
		ho.market_slot_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45) if not can_reg else Color(0.45, 0.90, 1.0))

	for cid in ho.market_filter_buttons.keys():
		var b: Button = ho.market_filter_buttons[cid] as Button
		if is_instance_valid(b):
			var is_on: bool = (str(cid) == ho.market_filter_category)
			b.add_theme_color_override("font_color", Color(0.35, 1.0, 0.72) if is_on else Color(0.84, 0.88, 0.92))
			b.modulate = Color(1.15, 1.15, 1.15) if is_on else Color(0.88, 0.88, 0.88)
	for r_key in ho.market_ratio_buttons.keys():
		var rb: Button = ho.market_ratio_buttons[r_key] as Button
		if is_instance_valid(rb):
			var is_r_on: bool = absf(float(r_key) - ho.market_price_ratio) < 0.01
			rb.add_theme_color_override("font_color", Color(1.0, 0.86, 0.30) if is_r_on else Color(0.84, 0.88, 0.92))
			rb.modulate = Color(1.15, 1.15, 1.15) if is_r_on else Color(0.88, 0.88, 0.88)

	var filter_active: bool = (ho.market_search_text != "" or ho.market_filter_category != "all")
	var total_matched: int = 0
	var selected_still_exists: bool = false

	var pairs: Array = [
		{"ctrl": ho.market_player_grid_ctrl, "mgr": ho.player_grid_mgr, "is_stash": false},
		{"ctrl": ho.market_stash_grid_ctrl, "mgr": ho.stash_grid_mgr, "is_stash": true}
	]
	for p in pairs:
		var ctrl: Control = p["ctrl"] as Control
		var mgr: InventoryGrid = p["mgr"] as InventoryGrid
		if not mgr:
			continue
		var matched_uids: Dictionary = {}
		var unavail_uids: Dictionary = {}
		for it in mgr.items:
			if it.is_empty():
				continue
			var uid: String = str(it.get("uid", ""))
			if uid == "":
				continue
			if uid == ho.market_selected_uid and bool(p["is_stash"]) == ho.market_selected_is_stash:
				selected_still_exists = true
			var reg_chk: Dictionary = ho._is_market_item_registerable(it)
			if not bool(reg_chk["ok"]):
				unavail_uids[uid] = true
			elif ho._does_market_item_match_filter(it):
				matched_uids[uid] = true
				total_matched += 1
		if ctrl:
			var csz: float = ho._compute_fit_cell_size(ho.market_grids_scroll, mgr.grid_width, ho.CELL_SIZE, 54.0)
			if bool(p["is_stash"]):
				ho.market_stash_cell_size = csz
			else:
				ho.market_player_cell_size = csz
			ctrl.custom_minimum_size = Vector2(float(mgr.grid_width) * csz, float(mgr.grid_height) * csz)
			ctrl.set_meta("filter_active", filter_active)
			ctrl.set_meta("matched_uids", matched_uids)
			ctrl.set_meta("unavailable_uids", unavail_uids)
			ctrl.set_meta("active_focus_uid", ho.market_selected_uid)
			ctrl.queue_redraw()

	if not selected_still_exists:
		ho.market_selected_uid = ""
		if ho.market_player_grid_ctrl:
			ho.market_player_grid_ctrl.set_meta("active_focus_uid", "")
			ho.market_player_grid_ctrl.queue_redraw()
		if ho.market_stash_grid_ctrl:
			ho.market_stash_grid_ctrl.set_meta("active_focus_uid", "")
			ho.market_stash_grid_ctrl.queue_redraw()

	if ho.market_result_count_lbl:
		ho.market_result_count_lbl.text = "가능 %d개" % total_matched

	refresh_market_selection_preview(ho)

static func refresh_market_selection_preview(ho: Control) -> void:
	if not ho.market_preview_lbl or not ho.market_confirm_btn:
		return
	var mgr: InventoryGrid = ho.stash_grid_mgr if ho.market_selected_is_stash else ho.player_grid_mgr
	var item: Dictionary = mgr.get_item_by_uid(ho.market_selected_uid) if (mgr and ho.market_selected_uid != "") else {}
	if item.is_empty():
		var empty_txt: String = "2D 그리드에서 암시장에 등록할 아이템을 클릭하세요. (검색/카테고리 필터 지원 · 더블클릭 시 즉시 등록)"
		if UiIconManager:
			UiIconManager.set_label_icon(ho.market_preview_lbl, "tip", empty_txt, 14, 6, true)
		else:
			ho.market_preview_lbl.text = empty_txt
		ho.market_preview_lbl.add_theme_color_override("font_color", Color(0.75, 0.82, 0.90))
		ho.market_confirm_btn.disabled = true
		return

	var item_id: String = str(item.get("id", ""))
	var amt: int = maxi(1, int(item.get("amount", 1)))
	var data: Dictionary = ItemDatabase.get_item_data(item_id)
	var disp_name: String = str(data.get("name", item_id))
	var reg_chk: Dictionary = ho._is_market_item_registerable(item)
	if not bool(reg_chk["ok"]):
		var reason_raw: String = str(reg_chk["reason"])
		var parsed: Dictionary = UiIconManager.parse_tagged_message(reason_raw) if UiIconManager else {"icon_key": "warn", "clean_text": reason_raw}
		var err_icon: String = String(parsed.get("icon_key", ""))
		if err_icon == "": err_icon = "warn"
		var err_txt: String = "[%s x%d]  %s" % [disp_name, amt, String(parsed.get("clean_text", reason_raw))]
		if UiIconManager:
			UiIconManager.set_label_icon(ho.market_preview_lbl, err_icon, err_txt, 14, 6, true)
		else:
			ho.market_preview_lbl.text = err_txt
		ho.market_preview_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
		ho.market_confirm_btn.disabled = true
		return

	var ref_price: int = FleaMarket.get_current_price(item_id) if FleaMarket else 100
	var ask_unit: int = maxi(10, int(round(float(ref_price) * ho.market_price_ratio)))
	var total_ask: int = ask_unit * amt
	var fee: int = FleaMarket.calculate_listing_fee(item_id, amt, ask_unit) if FleaMarket else 1
	var fee_pct: int = int(round((FleaMarket.calculate_listing_fee_rate(item_id, ask_unit) if FleaMarket else 0.05) * 100.0))
	var user_rubles: int = int(GameManager.current_world_data.get("player", {}).get("rubles", 0)) if GameManager else 0
	var can_reg: bool = FleaMarket.can_register_more_listings() if FleaMarket else false
	var src_tag: String = "창고" if ho.market_selected_is_stash else "배낭"
	var src_icon: String = "stash" if ho.market_selected_is_stash else "backpack"

	if not can_reg:
		var full_txt: String = "[%s] %s x%d  |  판매 슬롯(3/3)이 가득 찼습니다." % [src_tag, disp_name, amt]
		if UiIconManager:
			UiIconManager.set_label_icon(ho.market_preview_lbl, "warn", full_txt, 14, 6, true)
		else:
			ho.market_preview_lbl.text = full_txt
		ho.market_preview_lbl.add_theme_color_override("font_color", Color(1.0, 0.48, 0.48))
		ho.market_confirm_btn.disabled = true
	elif user_rubles < fee:
		var fee_txt: String = "[%s] %s x%d  |  희망가: %d RUB (x%.1f)  |  수수료 %d RUB 부족" % [src_tag, disp_name, amt, total_ask, ho.market_price_ratio, fee]
		if UiIconManager:
			UiIconManager.set_label_icon(ho.market_preview_lbl, "warn", fee_txt, 14, 6, true)
		else:
			ho.market_preview_lbl.text = fee_txt
		ho.market_preview_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
		ho.market_confirm_btn.disabled = true
	else:
		var ok_txt: String = "[%s] %s x%d\n희망 판매가: %d RUB (시세 x%.1f)  |  선불 수수료: %d RUB (%d%%)  |  판매 순이익: +%d RUB" % [
			src_tag, disp_name, amt, total_ask, ho.market_price_ratio, fee, fee_pct, total_ask - fee
		]
		if UiIconManager:
			UiIconManager.set_label_icon(ho.market_preview_lbl, src_icon, ok_txt, 14, 6, true)
		else:
			ho.market_preview_lbl.text = ok_txt
		ho.market_preview_lbl.add_theme_color_override("font_color", Color(0.45, 0.98, 0.72))
		ho.market_confirm_btn.disabled = false

static func handle_market_grid_input(ho: Control, event: InputEvent, ctrl: Control, mgr: InventoryGrid, is_stash: bool) -> void:
	if not ctrl or not mgr:
		return
	var csz: float = ho._get_grid_cell_size(ctrl)
	var local_pos: Vector2 = ctrl.get_local_mouse_position()
	var cx: int = int(floor(local_pos.x / csz))
	var cy: int = int(floor(local_pos.y / csz))
	var in_bounds: bool = (cx >= 0 and cx < mgr.grid_width and cy >= 0 and cy < mgr.grid_height)

	if event is InputEventMouseMotion:
		if is_stash:
			ho.hovered_market_stash_cell = Vector2i(cx, cy) if in_bounds else Vector2i(-1, -1)
		else:
			ho.hovered_market_player_cell = Vector2i(cx, cy) if in_bounds else Vector2i(-1, -1)
		if in_bounds:
			var h_item: Dictionary = mgr.get_item_at(cx, cy)
			if not h_item.is_empty() and ho.tooltip:
				ho.tooltip.display_item(h_item, ItemDatabase.get_item_data(str(h_item.get("id", ""))))
				ho.tooltip.update_position(ho.get_global_mouse_position())
			elif ho.tooltip:
				ho.tooltip.hide()
		elif ho.tooltip:
			ho.tooltip.hide()
		ctrl.queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var item: Dictionary = mgr.get_item_at(cx, cy)
			if item.is_empty():
				ho.market_selected_uid = ""
				ho._refresh_market_register_ui()
				return
			ho.market_selected_uid = str(item.get("uid", ""))
			ho.market_selected_is_stash = is_stash
			ho._refresh_market_register_ui()
			if SoundManager: SoundManager.play("menu_move")
			if event.double_click or Input.is_key_pressed(KEY_CTRL):
				ho._try_register_selected_market_item()

static func try_register_selected_market_item(ho: Control) -> void:
	var mgr: InventoryGrid = ho.stash_grid_mgr if ho.market_selected_is_stash else ho.player_grid_mgr
	var item: Dictionary = mgr.get_item_by_uid(ho.market_selected_uid) if (mgr and ho.market_selected_uid != "") else {}
	if item.is_empty():
		return
	var reg_chk: Dictionary = ho._is_market_item_registerable(item)
	if not bool(reg_chk["ok"]):
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit(str(reg_chk["reason"]))
		if SoundManager: SoundManager.play("hit_melee")
		return
	var item_id: String = str(item.get("id", ""))
	var amt: int = maxi(1, int(item.get("amount", 1)))
	var ref_price: int = FleaMarket.get_current_price(item_id) if FleaMarket else 100
	var ask_price: int = maxi(10, int(round(float(ref_price) * ho.market_price_ratio)))
	ho._register_market_item(ho.market_selected_uid, ho.market_selected_is_stash, item_id, amt, ask_price)

static func buy_market_item(ho: Control, listing: Dictionary, total_price: int) -> void:
	var user_rubles: int = int(GameManager.current_world_data.get("player", {}).get("rubles", 0))
	if user_rubles < total_price:
		return
	var preview_item: String = str(listing.get("item_name", ""))
	var preview_amt: int = maxi(1, int(listing.get("count", 1)))
	var preview_cd: Dictionary = listing.get("custom_data", {}) if (listing.get("custom_data") is Dictionary) else {}
	var can_fit_p: bool = ho.player_grid_mgr != null and ho.player_grid_mgr.can_fit_item(preview_item, preview_amt, preview_cd)
	var can_fit_s: bool = ho.stash_grid_mgr != null and ho.stash_grid_mgr.can_fit_item(preview_item, preview_amt, preview_cd)
	if not can_fit_p and not can_fit_s:
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:warn] 배낭과 창고 공간이 모두 부족하여 플리마켓 물품을 구매할 수 없습니다.")
		if SoundManager: SoundManager.play("hit_melee")
		return
	var res: Dictionary = FleaMarket.purchase_listing(listing, 1)
	if not bool(res.get("success", false)):
		ho._refresh_market_ui()
		return
	var actual_cost: int = int(res.get("total_price", total_price))
	GameManager.current_world_data["player"]["rubles"] -= actual_cost
	ho._update_money_label()

	var b_item: String = str(res.get("item_name", preview_item))
	var b_amt: int = int(res.get("amount", preview_amt))
	var remaining: int = ho.player_grid_mgr.auto_add_item(b_item, b_amt, preview_cd) if ho.player_grid_mgr else b_amt
	if remaining > 0 and ho.stash_grid_mgr:
		ho.stash_grid_mgr.auto_add_item(b_item, remaining, preview_cd)

	if SoundManager: SoundManager.play("menu_select")

	ho._refresh_market_ui()
	ho._sync_save_data()

static func register_market_item(ho: Control, uid: String, is_stash: bool, item_id: String, amount: int, ask_unit_price: int) -> void:
	if not FleaMarket or not FleaMarket.can_register_more_listings():
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:warn] 암시장 동시 판매 슬롯(최대 %d개)이 가득 찼습니다." % (FleaMarket.MAX_PLAYER_LISTINGS if FleaMarket else 3))
		return
	var fee: int = FleaMarket.calculate_listing_fee(item_id, amount, ask_unit_price)
	var user_rubles: int = int(GameManager.current_world_data.get("player", {}).get("rubles", 0))

	if user_rubles < fee:
		if EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("[icon:warn] 등록 수수료(%d RUB)가 부족합니다." % fee)
		return

	var src_mgr: InventoryGrid = ho.stash_grid_mgr if is_stash else ho.player_grid_mgr
	var item_dict: Dictionary = src_mgr.get_item_by_uid(uid) if (src_mgr and uid != "") else {}
	if not FleaMarket.register_item(item_id, amount, ask_unit_price, true, item_dict):
		return

	GameManager.current_world_data["player"]["rubles"] -= fee
	ho._update_money_label()

	if is_stash:
		ho.stash_grid_mgr.remove_item_by_uid(uid)
		ho._refresh_stash_ui()
	else:
		ho.player_grid_mgr.remove_item_by_uid(uid)

	if SoundManager: SoundManager.play("menu_select")
	ho._refresh_market_ui()
	ho._sync_save_data()
