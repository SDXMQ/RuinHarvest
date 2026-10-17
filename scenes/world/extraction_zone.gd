# res://scenes/world/extraction_zone.gd
extends Area2D

@export var zone_name: String = "탈출 지점 A"
@export var extract_time: float = 5.0

var current_timer: float = 0.0
var player_inside: bool = false
var player_ref: Node2D = null

signal extract_progress(current: float, max_time: float)
signal extract_cancelled

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if player_inside and not get_tree().paused:
		current_timer += delta
		extract_progress.emit(current_timer, extract_time)
		
		if current_timer >= extract_time:
			player_inside = false
			_trigger_extraction()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = true
		player_ref = body
		current_timer = 0.0
		if SoundManager:
			SoundManager.play("menu_select")

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false
		player_ref = null
		current_timer = 0.0
		extract_cancelled.emit()

func _trigger_extraction() -> void:
	EventBus.extraction_started.emit(zone_name, extract_time)
	if GameManager:
		var items_to_keep = []
		var main_world = get_node_or_null("/root/MainWorld")
		if main_world:
			if main_world.has_method("get_backpack_items"):
				items_to_keep = main_world.get_backpack_items()
			elif main_world.player and main_world.player.inventory_grid:
				for item in main_world.player.inventory_grid.items:
					if item and not item.is_empty():
						items_to_keep.append(item.duplicate(true))
			
			if main_world.player and not main_world.player.equipment.is_empty():
				if not GameManager.current_world_data.has("player"):
					GameManager.current_world_data["player"] = {}
				GameManager.current_world_data["player"]["equipment"] = main_world.player.equipment.duplicate(true)
		elif player_ref and "inventory_grid" in player_ref and player_ref.inventory_grid:
			for item in player_ref.inventory_grid.items:
				if item and not item.is_empty():
					items_to_keep.append(item.duplicate(true))
					
		GameManager.end_raid("survived", items_to_keep)

func _draw() -> void:
	# 초록색 발광 탈출 존
	var radius = 60.0
	draw_circle(Vector2.ZERO, radius, Color(0.1, 0.8, 0.2, 0.25))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(0.2, 1.0, 0.3, 0.8), 3.0)
	
	# 중앙 깃발/마커
	draw_circle(Vector2.ZERO, 6.0, Color(0.2, 1.0, 0.3))
