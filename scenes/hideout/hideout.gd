# res://scenes/hideout/hideout.gd
extends Control

@onready var raid_button: Button = $BottomBar/RaidButton
@onready var menu_button: Button = $BottomBar/MenuButton
@onready var day_label: Label = $TopBar/DayLabel
@onready var money_label: Label = $TopBar/MoneyLabel
@onready var player_grid: GridContainer = $CenterArea/HBox/PlayerPanel/Grid
@onready var stash_grid: GridContainer = $CenterArea/HBox/StashPanel/Scroll/Grid
@onready var result_dialog: Panel = $ResultDialog
@onready var result_title: Label = $ResultDialog/VBox/Title
@onready var result_desc: Label = $ResultDialog/VBox/Desc
@onready var result_close_btn: Button = $ResultDialog/VBox/CloseBtn

var player_inv: Inventory
var stash_inv: Inventory

func _ready() -> void:
	raid_button.pressed.connect(_on_raid_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	result_close_btn.pressed.connect(_on_result_close_pressed)
	
	# 인벤토리 초기화
	player_inv = Inventory.new()
	player_inv.max_slots = 12
	add_child(player_inv)
	
	stash_inv = Inventory.new()
	stash_inv.max_slots = 48 # 48칸 보관함
	add_child(stash_inv)
	
	player_inv.inventory_changed.connect(_on_player_inv_changed)
	stash_inv.inventory_changed.connect(_on_stash_changed)
	
	_load_data()
	_check_last_raid_result()
	_refresh_ui()

func _load_data() -> void:
	if GameManager and not GameManager.current_world_data.is_empty():
		var w_data = GameManager.current_world_data
		var day = w_data.get("current_day", 1)
		day_label.text = "생존 %d일차 (DAY %d)" % [day, day]
		
		var rubles = w_data.get("player", {}).get("rubles", 5000)
		money_label.text = "자금: %d RUB" % rubles
		
		# 배낭 데이터 로드
		var p_inv_data = w_data.get("player", {}).get("inventory", [])
		for item in p_inv_data:
			if item:
				player_inv.add_item(item["id"], item["amount"])
		
		# 창고 데이터 로드
		var stash_data = w_data.get("hideout", {}).get("stash", [])
		for item in stash_data:
			if item:
				stash_inv.add_item(item["id"], item["amount"])

func _on_player_inv_changed() -> void:
	_refresh_ui()
	_sync_save_data()

func _on_stash_changed() -> void:
	_refresh_ui()
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

func _refresh_ui() -> void:
	_populate_grid(player_grid, player_inv, true)
	_populate_grid(stash_grid, stash_inv, false)

func _populate_grid(grid: GridContainer, inv: Inventory, is_player: bool) -> void:
	for child in grid.get_children():
		child.queue_free()
		
	for i in range(inv.max_slots):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(52, 52)
		var item = inv.items[i]
		
		if item:
			var data = ItemDatabase.get_item_data(item["id"])
			btn.text = "%s\nx%d" % [data["name"], item["amount"]]
			btn.add_theme_font_size_override("font_size", 10)
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
