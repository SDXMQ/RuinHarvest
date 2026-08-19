# res://scenes/ui/loot_window.gd
extends Control

@onready var player_grid: GridContainer = $Center/HBox/PlayerPanel/Grid
@onready var loot_grid: GridContainer = $Center/HBox/LootPanel/Grid
@onready var title_label: Label = $Center/HBox/LootPanel/Title

var player_inv: Inventory
var loot_inv: Inventory

signal window_closed

func setup(p_inv: Inventory, l_inv: Inventory, loot_title: String) -> void:
	player_inv = p_inv
	loot_inv = l_inv
	title_label.text = loot_title
	
	player_inv.inventory_changed.connect(_refresh_ui)
	loot_inv.inventory_changed.connect(_refresh_ui)
	
	_refresh_ui()

func _refresh_ui() -> void:
	_populate_grid(player_grid, player_inv, true)
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
	
	if src_inv.items[index] == null:
		return
		
	# 대상 인벤토리의 첫 빈칸이나 스택 가능한 칸 찾기
	var item_id = src_inv.items[index]["id"]
	var data = ItemDatabase.get_item_data(item_id)
	var max_stack = data.get("max_stack", 1)
	
	var target_index = -1
	# 1. 먼저 스택 가능한 칸 찾기
	for i in range(dest_inv.max_slots):
		var slot = dest_inv.items[i]
		if slot and slot["id"] == item_id and slot["amount"] < max_stack:
			target_index = i
			break
			
	# 2. 없으면 빈칸 찾기
	if target_index == -1:
		for i in range(dest_inv.max_slots):
			if dest_inv.items[i] == null:
				target_index = i
				break
				
	if target_index != -1:
		src_inv.move_item(index, target_index, dest_inv)

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
