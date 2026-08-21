# res://scenes/ui/loot_window.gd
extends Control

@onready var player_grid: GridContainer = $Center/HBox/PlayerPanel/Grid
@onready var loot_grid: GridContainer = $Center/HBox/LootPanel/Grid
@onready var loot_panel: Panel = $Center/HBox/LootPanel
@onready var title_label: Label = $Center/HBox/LootPanel/Title

const TooltipScene = preload("res://scenes/ui/item_tooltip.tscn")
var tooltip: PanelContainer

var player_inv: Inventory
var loot_inv: Inventory

signal window_closed

func _ready() -> void:
	tooltip = TooltipScene.instantiate()
	add_child(tooltip)

func _process(_delta: float) -> void:
	if tooltip and tooltip.visible:
		tooltip.update_position(get_global_mouse_position())

func setup(p_inv: Inventory, l_inv: Inventory = null, loot_title: String = "") -> void:
	player_inv = p_inv
	loot_inv = l_inv
	
	if player_inv:
		player_inv.inventory_changed.connect(_refresh_ui)
		
	if loot_inv != null and loot_inv != player_inv:
		loot_panel.visible = true
		title_label.text = loot_title
		loot_inv.inventory_changed.connect(_refresh_ui)
	else:
		loot_panel.visible = false
		loot_inv = null
	
	_refresh_ui()

func _refresh_ui() -> void:
	if tooltip: tooltip.hide()
	_populate_grid(player_grid, player_inv, true)
	if loot_inv:
		_populate_grid(loot_grid, loot_inv, false)

func _populate_grid(grid: GridContainer, inv: Inventory, is_player: bool) -> void:
	# 기존 슬롯 비우기
	for child in grid.get_children():
		child.queue_free()
		
	# 슬롯 생성
	for i in range(inv.max_slots):
		var slot_btn = Button.new()
		slot_btn.custom_minimum_size = Vector2(56, 56)
		slot_btn.clip_contents = true
		var item = inv.items[i]
		
		if item:
			var data = ItemDatabase.get_item_data(item["id"])
			# 아이템 픽셀 아이콘 적용
			if ItemIconManager:
				slot_btn.icon = ItemIconManager.get_icon(item["id"])
				slot_btn.expand_icon = true
				slot_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				slot_btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
			
			# 마우스 호버 시 플로팅 툴팁 표시
			slot_btn.mouse_entered.connect(func():
				if tooltip and item:
					tooltip.display_item(item, data)
					tooltip.update_position(get_global_mouse_position())
			)
			slot_btn.mouse_exited.connect(func():
				if tooltip: tooltip.hide()
			)
			
			# 수량 표시 (2개 이상일 때 우측 하단 라벨)
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
				slot_btn.add_child(amt_lbl)
				
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
				slot_btn.add_child(dur_mini_bar)
		else:
			slot_btn.text = ""
			
		slot_btn.pressed.connect(func(): _on_slot_clicked(i, is_player))
		grid.add_child(slot_btn)

func _on_slot_clicked(index: int, is_player: bool) -> void:
	var src_inv = player_inv if is_player else loot_inv
	var dest_inv = loot_inv if is_player else player_inv
	
	if src_inv == null or src_inv.items[index] == null:
		return
		
	var item_id = src_inv.items[index]["id"]
	var data = ItemDatabase.get_item_data(item_id)
	
	# 상자가 없는 단일 인벤토리 모드인 경우: 아이템 사용(먹기/치료)
	if dest_inv == null:
		_use_item(index, item_id, data)
		return
		
	# 상자가 있는 루팅 모드인 경우: 상자/가방 간 아이템 이동
	var max_stack = data.get("max_stack", 1)
	var target_index = -1
	for i in range(dest_inv.max_slots):
		var slot = dest_inv.items[i]
		if slot and slot["id"] == item_id and slot["amount"] < max_stack:
			target_index = i
			break
			
	if target_index == -1:
		for i in range(dest_inv.max_slots):
			if dest_inv.items[i] == null:
				target_index = i
				break
				
	if target_index != -1:
		src_inv.move_item(index, target_index, dest_inv)
		if not is_player and EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("📦 획득: %s" % data.get("name", item_id))

func _use_item(index: int, item_id: String, data: Dictionary) -> void:
	var player = null
	var cur_scene = get_tree().current_scene
	if cur_scene and "player" in cur_scene and cur_scene.player:
		player = cur_scene.player
	elif get_node_or_null("/root/MainWorld") and get_node("/root/MainWorld").player:
		player = get_node("/root/MainWorld").player
	else:
		player = get_tree().get_first_node_in_group("player")
	
	var effects = data.get("effects", {})
	var used = false
	var effect_descriptions: Array = []
	
	if player:
		if effects.has("hunger"):
			player.hunger = min(player.max_hunger, player.hunger + effects["hunger"])
			used = true
			effect_descriptions.append("허기 +%d" % effects["hunger"])
		if effects.has("thirst"):
			player.thirst = min(player.max_thirst, player.thirst + effects["thirst"])
			used = true
			effect_descriptions.append("갈증 +%d" % effects["thirst"])
		if effects.has("hp"):
			player.hp = min(player.max_hp, player.hp + effects["hp"])
			used = true
			effect_descriptions.append("체력 +%d" % effects["hp"])
		if effects.get("cures_bleeding", false):
			player.is_bleeding = false
			used = true
			effect_descriptions.append("출혈 치료")
		if effects.get("cures_fracture", false):
			player.is_fractured = false
			used = true
			effect_descriptions.append("골절 치료")
		if effects.has("stamina"):
			player.stamina = min(player.max_stamina, player.stamina + effects["stamina"])
			used = true
			effect_descriptions.append("스태미너 +%d" % effects["stamina"])
			
		if used:
			player.stats_changed.emit()
			player_inv.remove_item_at(index, 1)
			if SoundManager:
				SoundManager.play("menu_select")
				
			var item_name = data.get("name", item_id)
			var desc_str = ", ".join(effect_descriptions)
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("💊 [%s] 사용 (%s)" % [item_name, desc_str])
				
			_refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("inventory") or event.is_action_pressed("pause") or event.is_action_pressed("interact")):
		get_tree().paused = false
		queue_free()
		window_closed.emit()
		get_viewport().set_input_as_handled()

func _on_close_button_pressed() -> void:
	get_tree().paused = false
	queue_free()
	window_closed.emit()
