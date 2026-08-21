# res://scenes/hideout/hideout.gd
extends Control

@onready var day_label: Label = $TopBar/DayLabel
@onready var money_label: Label = $TopBar/MoneyLabel
@onready var tab_container: TabContainer = $CenterArea/TabContainer

# 창고 탭
@onready var player_grid: GridContainer = $CenterArea/TabContainer/StashTab/HBox/PlayerPanel/Grid
@onready var stash_grid: GridContainer = $CenterArea/TabContainer/StashTab/HBox/StashPanel/Scroll/Grid

# 상인 탭
@onready var trader_desc_label: Label = $CenterArea/TabContainer/TradersTab/VBox/Header/DescLabel
@onready var trader_items_vbox: VBoxContainer = $CenterArea/TabContainer/TradersTab/VBox/Scroll/ItemsVBox
@onready var trader_sell_grid: HBoxContainer = $CenterArea/TabContainer/TradersTab/VBox/SellArea/Scroll/SellGrid

# 플리마켓 탭
@onready var market_items_vbox: VBoxContainer = $CenterArea/TabContainer/MarketTab/VBox/Scroll/MarketItemsVBox
@onready var market_register_grid: HBoxContainer = $CenterArea/TabContainer/MarketTab/VBox/RegisterArea/Scroll/RegisterGrid

# 하단 바
@onready var raid_button: Button = $BottomBar/RaidButton
@onready var menu_button: Button = $BottomBar/MenuButton

# 결과 팝업
@onready var result_dialog: Panel = $ResultDialog
@onready var result_title: Label = $ResultDialog/VBox/Title
@onready var result_desc: Label = $ResultDialog/VBox/Desc
@onready var result_close_btn: Button = $ResultDialog/VBox/CloseBtn

const TooltipScene = preload("res://scenes/ui/item_tooltip.tscn")
var tooltip: PanelContainer

var player_inv: Inventory
var stash_inv: Inventory
var current_trader_id: String = "prapor"

func _ready() -> void:
	tooltip = TooltipScene.instantiate()
	add_child(tooltip)
	
	raid_button.pressed.connect(_on_raid_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	result_close_btn.pressed.connect(_on_result_close_pressed)
	
	# 상인 버튼 연결
	var prapor_btn: Button = $CenterArea/TabContainer/TradersTab/VBox/TraderButtons/PraporBtn
	var therapist_btn: Button = $CenterArea/TabContainer/TradersTab/VBox/TraderButtons/TherapistBtn
	var fence_btn: Button = $CenterArea/TabContainer/TradersTab/VBox/TraderButtons/FenceBtn
	
	prapor_btn.pressed.connect(func(): _select_trader("prapor"))
	therapist_btn.pressed.connect(func(): _select_trader("therapist"))
	fence_btn.pressed.connect(func(): _select_trader("fence"))
	
	# 인벤토리 초기화
	player_inv = Inventory.new()
	player_inv.max_slots = 12
	add_child(player_inv)
	
	stash_inv = Inventory.new()
	stash_inv.max_slots = 48
	add_child(stash_inv)
	
	player_inv.inventory_changed.connect(_on_inventory_changed)
	stash_inv.inventory_changed.connect(_on_inventory_changed)
	
	tab_container.tab_changed.connect(_on_tab_changed)
	
	_load_data()
	_check_last_raid_result()
	_refresh_stash_ui()
	_refresh_trader_ui()
	_refresh_market_ui()

func _process(_delta: float) -> void:
	if tooltip and tooltip.visible:
		tooltip.update_position(get_global_mouse_position())

func _on_tab_changed(tab: int) -> void:
	if tooltip: tooltip.hide()
	if tab == 0:
		_refresh_stash_ui()
	elif tab == 1:
		_refresh_trader_ui()
	elif tab == 2:
		_refresh_market_ui()

func _load_data() -> void:
	if GameManager and not GameManager.current_world_data.is_empty():
		var w_data = GameManager.current_world_data
		var day = w_data.get("current_day", 1)
		day_label.text = "생존 %d일차 (DAY %d)" % [day, day]
		_update_money_label()
		
		# 배낭 데이터 로드
		var p_inv_data = w_data.get("player", {}).get("inventory", [])
		player_inv.load_items(p_inv_data)
		
		# 창고 데이터 로드
		var stash_data = w_data.get("hideout", {}).get("stash", [])
		stash_inv.load_items(stash_data)

func _update_money_label() -> void:
	if GameManager and not GameManager.current_world_data.is_empty():
		var rubles = GameManager.current_world_data.get("player", {}).get("rubles", 5000)
		money_label.text = "자금: %d RUB" % rubles

func _on_inventory_changed() -> void:
	if tooltip: tooltip.hide()
	_refresh_stash_ui()
	_refresh_trader_sell_ui()
	_sync_save_data()

func _sync_save_data() -> void:
	if GameManager and not GameManager.current_world_data.is_empty():
		var saved_player_items = []
		for item in player_inv.items:
			if item:
				saved_player_items.append(item.duplicate())
		if not GameManager.current_world_data.has("player"):
			GameManager.current_world_data["player"] = {}
		GameManager.current_world_data["player"]["inventory"] = saved_player_items
		
		var saved_stash_items = []
		for item in stash_inv.items:
			if item:
				saved_stash_items.append(item.duplicate())
		if not GameManager.current_world_data.has("hideout"):
			GameManager.current_world_data["hideout"] = {}
		GameManager.current_world_data["hideout"]["stash"] = saved_stash_items
		
		if GameManager.current_save_slot != "":
			SaveManager.save_game(GameManager.current_world_data, GameManager.current_save_slot)

# ============================================================
# 창고 UI 로직
# ============================================================
func _refresh_stash_ui() -> void:
	_populate_grid(player_grid, player_inv, true)
	_populate_grid(stash_grid, stash_inv, false)

func _populate_grid(grid: GridContainer, inv: Inventory, is_player: bool) -> void:
	for child in grid.get_children():
		child.queue_free()
		
	for i in range(inv.max_slots):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(56, 56)
		btn.clip_contents = true
		var item = inv.items[i]
		
		if item:
			var data = ItemDatabase.get_item_data(item["id"])
			if ItemIconManager:
				btn.icon = ItemIconManager.get_icon(item["id"])
				btn.expand_icon = true
				btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
				
			btn.mouse_entered.connect(func():
				if tooltip and item:
					tooltip.display_item(item, data)
					tooltip.update_position(get_global_mouse_position())
			)
			btn.mouse_exited.connect(func():
				if tooltip: tooltip.hide()
			)
			
			if item["amount"] > 1:
				var amt_lbl = Label.new()
				amt_lbl.text = "x%d" % item["amount"]
				amt_lbl.add_theme_font_size_override("font_size", 12)
				amt_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
				amt_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
				amt_lbl.add_theme_constant_override("shadow_offset_x", 1)
				amt_lbl.add_theme_constant_override("shadow_offset_y", 1)
				amt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				amt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				amt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
				amt_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
				amt_lbl.offset_right = -4
				amt_lbl.offset_bottom = -2
				btn.add_child(amt_lbl)
				
			# 내구도 바 (슬롯 하단 미니 게이지)
			var max_dur = data.get("max_durability", 0)
			if max_dur > 0:
				var cur_dur = item.get("durability", max_dur)
				var dur_mini_bar = ProgressBar.new()
				dur_mini_bar.show_percentage = false
				dur_mini_bar.custom_minimum_size = Vector2(46, 4)
				dur_mini_bar.max_value = max_dur
				dur_mini_bar.value = cur_dur
				dur_mini_bar.position = Vector2(5, 48)
				dur_mini_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
				
				var fill_style = StyleBoxFlat.new()
				var ratio = float(cur_dur) / float(max_dur)
				if ratio > 0.6: fill_style.bg_color = Color(0.2, 0.8, 0.3)
				elif ratio > 0.3: fill_style.bg_color = Color(0.9, 0.7, 0.1)
				else: fill_style.bg_color = Color(0.9, 0.2, 0.2)
				dur_mini_bar.add_theme_stylebox_override("fill", fill_style)
				
				var bg_style = StyleBoxFlat.new()
				bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
				dur_mini_bar.add_theme_stylebox_override("background", bg_style)
				btn.add_child(dur_mini_bar)
		else:
			btn.text = ""
			
		btn.pressed.connect(func(): _on_slot_clicked(i, is_player))
		grid.add_child(btn)

func _on_slot_clicked(index: int, is_player: bool) -> void:
	var src = player_inv if is_player else stash_inv
	var dest = stash_inv if is_player else player_inv
	
	if src.items[index] == null: return
	
	var item_id = src.items[index]["id"]
	var data = ItemDatabase.get_item_data(item_id)
	var max_stack = data.get("max_stack", 1)
	
	var target_index = -1
	for i in range(dest.max_slots):
		var slot = dest.items[i]
		if slot and slot["id"] == item_id and slot["amount"] < max_stack:
			target_index = i
			break
	if target_index == -1:
		for i in range(dest.max_slots):
			if dest.items[i] == null:
				target_index = i
				break
				
	if target_index != -1:
		src.move_item(index, target_index, dest)

# ============================================================
# 상인 거래소 UI 로직
# ============================================================
func _select_trader(trader_id: String) -> void:
	current_trader_id = trader_id
	_refresh_trader_ui()

func _refresh_trader_ui() -> void:
	var t_data = ItemDatabase.traders.get(current_trader_id, {})
	if t_data.is_empty(): return
	
	trader_desc_label.text = "[%s] %s" % [t_data["name"], t_data["desc"]]
	
	# 상품 목록 생성
	for child in trader_items_vbox.get_children():
		child.queue_free()
		
	var user_rubles = GameManager.current_world_data.get("player", {}).get("rubles", 0)
	
	for stock_item in t_data.get("stock", []):
		var item_id = stock_item["id"]
		var price = stock_item["price"]
		var amount = stock_item.get("amount", 1)
		var item_meta = ItemDatabase.get_item_data(item_id)
		
		var panel = PanelContainer.new()
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		panel.add_child(hbox)
		
		# 아이템 아이콘
		if ItemIconManager:
			var icon_rect = TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(32, 32)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.texture = ItemIconManager.get_icon(item_id)
			hbox.add_child(icon_rect)
		
		var name_lbl = Label.new()
		name_lbl.text = "%s (x%d)" % [item_meta.get("name", item_id), amount]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)
		
		var price_lbl = Label.new()
		price_lbl.text = "%d RUB" % price
		price_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		hbox.add_child(price_lbl)
		
		var buy_btn = Button.new()
		buy_btn.text = "구매"
		buy_btn.custom_minimum_size = Vector2(60, 32)
		buy_btn.disabled = (user_rubles < price)
		buy_btn.pressed.connect(func(): _buy_item(item_id, amount, price))
		hbox.add_child(buy_btn)
		
		trader_items_vbox.add_child(panel)
		
	_refresh_trader_sell_ui()

func _refresh_trader_sell_ui() -> void:
	for child in trader_sell_grid.get_children():
		child.queue_free()
		
	# 배낭의 아이템들을 판매 가능 목록으로 표시
	for i in range(player_inv.max_slots):
		var item = player_inv.items[i]
		if item:
			var data = ItemDatabase.get_item_data(item["id"])
			var sell_price = int(data.get("value", 500) * 0.6) # 기본가의 60%에 매입
			
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(100, 50)
			if ItemIconManager:
				btn.icon = ItemIconManager.get_icon(item["id"])
				btn.expand_icon = true
			btn.text = "%s\n+%d RUB" % [data["name"], sell_price * item["amount"]]
			btn.add_theme_font_size_override("font_size", 10)
			btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
			btn.pressed.connect(func(): _sell_item(i, item["id"], item["amount"], sell_price))
			trader_sell_grid.add_child(btn)

func _buy_item(item_id: String, amount: int, price: int) -> void:
	var user_rubles = GameManager.current_world_data.get("player", {}).get("rubles", 0)
	if user_rubles < price: return
	
	# 자금 차감
	GameManager.current_world_data["player"]["rubles"] -= price
	_update_money_label()
	
	# 배낭 또는 창고에 아이템 지급
	var remaining = player_inv.add_item(item_id, amount)
	if remaining > 0:
		stash_inv.add_item(item_id, remaining)
		
	if SoundManager: SoundManager.play("menu_select")
	_refresh_trader_ui()
	_sync_save_data()

func _sell_item(slot_idx: int, item_id: String, amount: int, unit_price: int) -> void:
	var total_gain = unit_price * amount
	GameManager.current_world_data["player"]["rubles"] += total_gain
	_update_money_label()
	
	player_inv.items[slot_idx] = null
	player_inv.inventory_changed.emit()
	
	if SoundManager: SoundManager.play("menu_select")
	_refresh_trader_ui()
	_sync_save_data()

# ============================================================
# 플리마켓 UI 로직
# ============================================================
func _refresh_market_ui() -> void:
	if not FleaMarket: return
	
	for child in market_items_vbox.get_children():
		child.queue_free()
		
	var user_rubles = GameManager.current_world_data.get("player", {}).get("rubles", 0)
	
	for listing in FleaMarket.listings:
		var item_id = listing["item_name"]
		var price = listing["price"]
		var amount = listing["count"]
		var item_meta = ItemDatabase.get_item_data(item_id)
		
		var panel = PanelContainer.new()
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		panel.add_child(hbox)
		
		if ItemIconManager:
			var icon_rect = TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(32, 32)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.texture = ItemIconManager.get_icon(item_id)
			hbox.add_child(icon_rect)
		
		var name_lbl = Label.new()
		name_lbl.text = "%s (x%d)" % [item_meta.get("name", item_id), amount]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)
		
		var price_lbl = Label.new()
		price_lbl.text = "%d RUB" % (price * amount)
		price_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		hbox.add_child(price_lbl)
		
		var buy_btn = Button.new()
		buy_btn.text = "구매"
		buy_btn.custom_minimum_size = Vector2(60, 32)
		buy_btn.disabled = (user_rubles < price * amount)
		buy_btn.pressed.connect(func(): _buy_market_item(listing, price * amount))
		hbox.add_child(buy_btn)
		
		market_items_vbox.add_child(panel)
		
	_refresh_market_register_ui()

func _refresh_market_register_ui() -> void:
	for child in market_register_grid.get_children():
		child.queue_free()
		
	for i in range(player_inv.max_slots):
		var item = player_inv.items[i]
		if item:
			var data = ItemDatabase.get_item_data(item["id"])
			if item["id"] == "Scav 식별줄(Dogtag)":
				continue
				
			var current_price = FleaMarket.get_current_price(item["id"])
			
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(100, 50)
			if ItemIconManager:
				btn.icon = ItemIconManager.get_icon(item["id"])
				btn.expand_icon = true
			btn.text = "%s\n시장가 %d RUB" % [data["name"], current_price]
			btn.add_theme_font_size_override("font_size", 10)
			btn.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
			btn.pressed.connect(func(): _register_market_item(i, item["id"], item["amount"], current_price))
			market_register_grid.add_child(btn)

func _buy_market_item(listing: Dictionary, total_price: int) -> void:
	var user_rubles = GameManager.current_world_data.get("player", {}).get("rubles", 0)
	if user_rubles < total_price: return
	
	GameManager.current_world_data["player"]["rubles"] -= total_price
	_update_money_label()
	
	var remaining = player_inv.add_item(listing["item_name"], listing["count"])
	if remaining > 0:
		stash_inv.add_item(listing["item_name"], remaining)
		
	FleaMarket.listings.erase(listing)
	if SoundManager: SoundManager.play("menu_select")
	
	_refresh_market_ui()
	_sync_save_data()

func _register_market_item(slot_idx: int, item_id: String, amount: int, current_price: int) -> void:
	# 5% 수수료 (선불)
	var fee = max(1, int(current_price * amount * 0.05))
	var user_rubles = GameManager.current_world_data.get("player", {}).get("rubles", 0)
	
	if user_rubles < fee:
		EventBus.popup_message.emit("등록 수수료(%d RUB)가 부족합니다." % fee, Color.RED)
		return
		
	GameManager.current_world_data["player"]["rubles"] -= fee
	_update_money_label()
	
	FleaMarket.register_item(item_id, amount, current_price)
	
	player_inv.items[slot_idx] = null
	player_inv.inventory_changed.emit()
	
	EventBus.popup_message.emit("플리마켓에 매물이 등록되었습니다.", Color.GREEN)
	if SoundManager: SoundManager.play("menu_select")
	
	_refresh_market_ui()
	_sync_save_data()

# ============================================================
# 결과 팝업 및 네비게이션
# ============================================================
func _check_last_raid_result() -> void:
	if GameManager and not GameManager.last_raid_result.is_empty():
		var res = GameManager.last_raid_result
		result_dialog.visible = true
		if res["result"] == "survived":
			result_title.text = "🎉 탈출 성공! (SURVIVED)"
			result_title.add_theme_color_override("font_color", Color.GREEN)
			result_desc.text = "안전하게 은신처로 복귀했습니다.\n획득한 전리품이 창고로 안전하게 이관되었습니다."
		elif res["result"] == "kia":
			result_title.text = "💀 작전 중 사망 (KIA)"
			result_title.add_theme_color_override("font_color", Color.RED)
			result_desc.text = "레이드 도중 사망했습니다.\n소지하고 있던 모든 배낭 아이템을 잃었습니다."
		elif res["result"] == "mia":
			result_title.text = "⏳ 작전 시간 초과 (MIA)"
			result_title.add_theme_color_override("font_color", Color.ORANGE)
			result_desc.text = "제한 시간 내에 탈출하지 못해 실종되었습니다."
			
		GameManager.last_raid_result.clear()
	else:
		result_dialog.visible = false

func _on_result_close_pressed() -> void:
	result_dialog.visible = false

func _on_raid_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	if GameManager: GameManager.start_raid()

func _on_menu_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	if GameManager:
		if GameManager.current_save_slot != "":
			SaveManager.save_game(GameManager.current_world_data, GameManager.current_save_slot)
		GameManager.change_state(GameManager.GameState.MAIN_MENU)
