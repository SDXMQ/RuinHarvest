# res://scenes/ui/crafting_window.gd
extends Control

@onready var recipe_list_container: VBoxContainer = $Center/Panel/Scroll/VBox
@onready var close_btn: Button = $Center/Panel/CloseBtn

var player_inv: Inventory
signal window_closed

# 조합 레시피 DB: [결과 아이템] -> { "requirements": { "재료": 개수 }, "amount": 수량 }
var recipes: Dictionary = {
	"붕대": {
		"requirements": {"천": 2},
		"amount": 1,
		"desc": "찢어진 천을 엮어 만드는 기본 치료용 붕대."
	},
	"고급 치료킷": {
		"requirements": {"약초": 2, "생수": 1, "붕대": 1},
		"amount": 1,
		"desc": "출혈과 골절을 모두 치료하고 높은 체력을 회복하는 의료 키트."
	},
	"수류탄": {
		"requirements": {"화약": 2, "고철": 1},
		"amount": 1,
		"desc": "폭발성 살상 무기."
	},
	"함정": {
		"requirements": {"고철": 2, "못": 4},
		"amount": 1,
		"desc": "접근하는 적을 저지하는 트랩 장치."
	},
	"파이프": {
		"requirements": {"고철": 3},
		"amount": 1,
		"desc": "휘두르기 좋은 묵직한 쇠파이프."
	}
}

func setup(inv: Inventory) -> void:
	player_inv = inv
	if player_inv:
		player_inv.inventory_changed.connect(_refresh_ui)
	_refresh_ui()

func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)

func _refresh_ui() -> void:
	for child in recipe_list_container.get_children():
		child.queue_free()
		
	for result_id in recipes.keys():
		var recipe = recipes[result_id]
		var item_data = ItemDatabase.get_item_data(result_id)
		
		var entry_panel = PanelContainer.new()
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		entry_panel.add_child(hbox)
		
		# 아이템 이름 및 설명
		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var title = Label.new()
		title.text = "%s (x%d)" % [item_data.get("name", result_id), recipe["amount"]]
		title.add_theme_font_size_override("font_size", 14)
		title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		info_vbox.add_child(title)
		
		# 요구 재료 텍스트
		var req_texts = []
		var can_craft = true
		for mat_id in recipe["requirements"].keys():
			var req_cnt = recipe["requirements"][mat_id]
			var cur_cnt = _count_material(mat_id)
			req_texts.append("%s (%d/%d)" % [mat_id, cur_cnt, req_cnt])
			if cur_cnt < req_cnt:
				can_craft = false
				
		var req_label = Label.new()
		req_label.text = "재료: " + ", ".join(req_texts)
		req_label.add_theme_font_size_override("font_size", 11)
		if can_craft:
			req_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		else:
			req_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		info_vbox.add_child(req_label)
		hbox.add_child(info_vbox)
		
		# 제작 버튼
		var craft_btn = Button.new()
		craft_btn.text = "제작"
		craft_btn.custom_minimum_size = Vector2(70, 36)
		craft_btn.disabled = not can_craft
		craft_btn.pressed.connect(func(): _craft_item(result_id, recipe))
		hbox.add_child(craft_btn)
		
		recipe_list_container.add_child(entry_panel)

func _count_material(mat_id: String) -> int:
	if not player_inv: return 0
	var total = 0
	for item in player_inv.items:
		if item and item["id"] == mat_id:
			total += item["amount"]
	return total

func _craft_item(result_id: String, recipe: Dictionary) -> void:
	if not player_inv: return
	
	# 재료 차감
	for mat_id in recipe["requirements"].keys():
		var req_cnt = recipe["requirements"][mat_id]
		var remaining_to_remove = req_cnt
		for i in range(player_inv.max_slots):
			var item = player_inv.items[i]
			if item and item["id"] == mat_id:
				if item["amount"] <= remaining_to_remove:
					remaining_to_remove -= item["amount"]
					player_inv.items[i] = null
				else:
					item["amount"] -= remaining_to_remove
					remaining_to_remove = 0
				if remaining_to_remove <= 0:
					break
					
	# 완성품 지급
	player_inv.add_item(result_id, recipe["amount"])
	player_inv.inventory_changed.emit()
	
	if SoundManager:
		SoundManager.play("menu_select")
		
	_refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("crafting") or event.is_action_pressed("pause") or (event is InputEventKey and event.physical_keycode == KEY_C and event.pressed)):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func _on_close_pressed() -> void:
	get_tree().paused = false
	queue_free()
	window_closed.emit()
