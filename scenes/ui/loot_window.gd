# res://scenes/ui/loot_window.gd
extends Control

@onready var player_grid: GridContainer = $Center/HBox/PlayerPanel/Grid
@onready var loot_grid: GridContainer = $Center/HBox/LootPanel/Grid
@onready var loot_panel: Panel = $Center/HBox/LootPanel
@onready var title_label: Label = $Center/HBox/LootPanel/Title

var player_inv: Inventory
var loot_inv: Inventory

signal window_closed

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
		slot_btn.custom_minimum_size = Vector2(48, 48)
		var item = inv.items[i]
		
		if item:
			var data = ItemDatabase.get_item_data(item["id"])
			# 임시 텍스처(단색) 대신 텍스트로 표시
			slot_btn.text = "%s\nx%d" % [data["name"], item["amount"]]
			slot_btn.add_theme_color_override("font_color", data.get("color", Color.WHITE))
			slot_btn.add_theme_font_size_override("font_size", 10)
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

func _use_item(index: int, item_id: String, data: Dictionary) -> void:
	var main_world = get_node_or_null("/root/MainWorld")
	var player = main_world.player if main_world else null
	
	var effects = data.get("effects", {})
	var used = false
	
	if player:
		if effects.has("hunger"):
			player.hunger = min(player.max_hunger, player.hunger + effects["hunger"])
			used = true
		if effects.has("thirst"):
			player.thirst = min(player.max_thirst, player.thirst + effects["thirst"])
			used = true
		if effects.has("hp"):
			player.hp = min(player.max_hp, player.hp + effects["hp"])
			used = true
		if effects.get("cures_bleeding", false):
			player.is_bleeding = false
			used = true
		if effects.get("cures_fracture", false):
			player.is_fractured = false
			used = true
		if effects.has("stamina"):
			player.stamina = min(player.max_stamina, player.stamina + effects["stamina"])
			used = true
			
		if used:
			player_inv.remove_item_at(index, 1)
			if SoundManager:
				SoundManager.play("menu_select")
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
