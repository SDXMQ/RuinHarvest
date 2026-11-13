# res://scenes/world/extraction_zone.gd
extends Area2D

enum ExtractionType { DEFAULT = 0, VEHICLE = 1, BUNKER = 2 }

@export var extraction_type: int = ExtractionType.DEFAULT
@export var zone_name: String = "탈출 지점 A"
@export var extract_time: float = 7.0
@export var required_rubles: int = 3000

var current_timer: float = 0.0
var player_inside: bool = false
var player_ref: Node2D = null
var pulse_timer: float = 0.0

signal extract_progress(current: float, max_time: float)
signal extract_cancelled

var _primary_spr: Sprite2D = null
var _barricade_l: Sprite2D = null
var _barricade_r: Sprite2D = null
var _zone_light: PointLight2D = null
var _last_synced_type: int = -1

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_setup_pixel_visuals()

func _setup_pixel_visuals() -> void:
	var props_tex: CanvasTexture = PixelAssetManager.get_canvas_texture("props/world_props") if PixelAssetManager else null

	_primary_spr = Sprite2D.new()
	_primary_spr.name = "ExtractPrimarySprite"
	_primary_spr.centered = true
	_primary_spr.region_enabled = true
	_primary_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if props_tex:
		_primary_spr.texture = props_tex
	if PixelAssetManager:
		_primary_spr.material = PixelAssetManager.create_pixel_entity_material(0.22)
	add_child(_primary_spr)

	_barricade_l = Sprite2D.new()
	_barricade_l.name = "BarricadeLeft"
	_barricade_l.centered = true
	_barricade_l.region_enabled = true
	_barricade_l.region_rect = Rect2(208, 96, 48, 48)
	_barricade_l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_barricade_l.position = Vector2(-44, 18)
	_barricade_l.z_index = -3
	_barricade_l.visible = false
	if props_tex:
		_barricade_l.texture = props_tex
	if PixelAssetManager:
		_barricade_l.material = PixelAssetManager.create_pixel_entity_material(0.20)
	add_child(_barricade_l)

	_barricade_r = Sprite2D.new()
	_barricade_r.name = "BarricadeRight"
	_barricade_r.centered = true
	_barricade_r.region_enabled = true
	_barricade_r.region_rect = Rect2(208, 96, 48, 48)
	_barricade_r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_barricade_r.position = Vector2(44, 18)
	_barricade_r.z_index = -3
	_barricade_r.visible = false
	if props_tex:
		_barricade_r.texture = props_tex
	if PixelAssetManager:
		_barricade_r.material = PixelAssetManager.create_pixel_entity_material(0.20)
	add_child(_barricade_r)

	_zone_light = PointLight2D.new()
	_zone_light.name = "ZoneLight"
	_zone_light.height = 42.0
	_zone_light.energy = 0.9
	_zone_light.texture_scale = 2.4
	if PixelAssetManager:
		_zone_light.texture = PixelAssetManager.get_radial_light_texture()
	add_child(_zone_light)

	_sync_zone_visuals()

func _get_zone_color() -> Color:
	if extraction_type == ExtractionType.VEHICLE:
		return Color(1.0, 0.82, 0.15)
	elif extraction_type == ExtractionType.BUNKER:
		return Color(0.2, 0.85, 1.0)
	return Color(0.2, 1.0, 0.35)

func _sync_zone_visuals() -> void:
	_last_synced_type = extraction_type
	if _zone_light:
		_zone_light.color = _get_zone_color()
	if not _primary_spr:
		return

	_barricade_l.visible = false
	_barricade_r.visible = false
	match extraction_type:
		ExtractionType.VEHICLE:
			_primary_spr.region_rect = Rect2(192, 0, 48, 96)
			_primary_spr.position = Vector2(0, -14)
			_primary_spr.scale = Vector2.ONE
			_primary_spr.z_index = -3
			_barricade_l.visible = true
			_barricade_r.visible = true
		ExtractionType.BUNKER:
			_primary_spr.region_rect = Rect2(192, 144, 48, 48)
			_primary_spr.position = Vector2.ZERO
			_primary_spr.scale = Vector2(1.5, 1.5)
			_primary_spr.z_index = -4
		_:
			_primary_spr.region_rect = Rect2(144, 144, 48, 48)
			_primary_spr.position = Vector2.ZERO
			_primary_spr.scale = Vector2(2.0, 2.0)
			_primary_spr.z_index = -5

func _process(delta: float) -> void:
	pulse_timer += delta
	if _last_synced_type != extraction_type:
		_sync_zone_visuals()
	if _zone_light:
		_zone_light.energy = 0.72 + 0.25 * sin(pulse_timer * 3.5)
	queue_redraw()
	
	if player_inside and not get_tree().paused:
		current_timer += delta
		extract_progress.emit(current_timer, extract_time)
		
		if current_timer >= extract_time:
			player_inside = false
			_trigger_extraction()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_ref = body
		
		if extraction_type == ExtractionType.VEHICLE:
			var rubles = 0
			if GameManager and GameManager.current_world_data.has("player"):
				rubles = int(GameManager.current_world_data["player"].get("rubles", 0))
			if rubles < required_rubles:
				if player_ref.has_method("show_floating_text"):
					player_ref.show_floating_text("[%d RUB 필요]" % required_rubles, Color(1.0, 0.8, 0.2))
				if EventBus.has_signal("event_logged"):
					EventBus.event_logged.emit("🚕 탈출 차량 이용 불가: 탑승 비용 %d RUB가 필요합니다! (현재: %d RUB)" % [required_rubles, rubles])
				if SoundManager: SoundManager.play("hit_melee")
				return
		elif extraction_type == ExtractionType.BUNKER:
			var obj_done = false
			if GameManager:
				if GameManager.raid_landmark_completed or GameManager.raid_power_restored:
					obj_done = true
				elif bool(GameManager.current_world_data.get("raid_power_restored", false)):
					obj_done = true
				elif GameManager.current_world_data.has("player") and GameManager.current_world_data["player"].get("field_objectives_completed", 0) >= 1:
					obj_done = true
			if not obj_done:
				if player_ref.has_method("show_floating_text"):
					player_ref.show_floating_text("[벙커 격벽 폐쇄: 필드 목표 완료 필요]", Color(0.2, 0.85, 1.0))
				if EventBus.has_signal("event_logged"):
					EventBus.event_logged.emit("🔒 지하 벙커 탈출구 폐쇄됨: 필드 목표 단말기 1개 이상 가동/해킹 필요!")
				if SoundManager: SoundManager.play("hit_melee")
				return

		player_inside = true
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
	if extraction_type == ExtractionType.VEHICLE:
		if GameManager and GameManager.current_world_data.has("player"):
			var cur_rub = int(GameManager.current_world_data["player"].get("rubles", 0))
			if cur_rub < required_rubles:
				if EventBus.has_signal("event_logged"):
					EventBus.event_logged.emit("🚕 탈출 차량 이용 불가: 탑승 비용 %d RUB가 부족합니다! (현재: %d RUB)" % [required_rubles, cur_rub])
				extract_cancelled.emit()
				return
			GameManager.current_world_data["player"]["rubles"] = max(0, cur_rub - required_rubles)
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("🚕 탈출 차량 탑승료 %d RUB 결제 완료." % required_rubles)
	elif extraction_type == ExtractionType.BUNKER:
		var obj_done = false
		if GameManager:
			if GameManager.raid_landmark_completed or GameManager.raid_power_restored:
				obj_done = true
			elif bool(GameManager.current_world_data.get("raid_power_restored", false)):
				obj_done = true
			elif GameManager.current_world_data.has("player") and GameManager.current_world_data["player"].get("field_objectives_completed", 0) >= 1:
				obj_done = true
		if not obj_done:
			if EventBus.has_signal("event_logged"):
				EventBus.event_logged.emit("🔒 지하 벙커 탈출구 폐쇄됨: 필드 목표 단말기 1개 이상 가동/해킹 필요!")
			extract_cancelled.emit()
			return
				
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
	var radius = 64.0
	var col := _get_zone_color()
	var hdr_col := Color(col.r * 1.45, col.g * 1.45, col.b * 1.45, 0.90)
	var pulse = 0.8 + 0.2 * sin(pulse_timer * 3.5)

	draw_circle(Vector2.ZERO, radius, Color(col.r, col.g, col.b, 0.10 * pulse))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 36, hdr_col, 2.2)

	var cycle: float = fmod(pulse_timer * 0.45, 1.0)
	var inner_r: float = lerpf(24.0, radius, cycle)
	var inner_a: float = (1.0 - cycle) * 0.45
	draw_arc(Vector2.ZERO, inner_r, 0, TAU, 28, Color(col.r * 1.3, col.g * 1.3, col.b * 1.3, inner_a), 1.4)
