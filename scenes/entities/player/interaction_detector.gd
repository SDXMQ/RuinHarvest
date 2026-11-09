extends Node
class_name InteractionDetector

signal interact_prompt(show: bool, text: String)
signal object_interacted(world_pos: Vector2, tile_pos: Vector2i, type: Vector2i)

var interactable_tile_pos: Vector2i = Vector2i(-1, -1)
var interactable_type: Vector2i = Vector2i(-1, -1)
var interact_cooldown: float = 0.0
var vault_timer: float = 0.0
const VAULT_DURATION: float = 1.0
var objective_hold_timer: float = 0.0
const OBJECTIVE_HOLD_DURATION: float = 3.0
var active_objective_node: Node = null

@onready var player = get_parent()

func _ready() -> void:
	if EventBus and EventBus.has_signal("player_damaged"):
		EventBus.player_damaged.connect(_on_player_damaged_interrupt)

func _on_player_damaged_interrupt(_amount: float, _source: String) -> void:
	if objective_hold_timer > 0.0:
		objective_hold_timer = 0.0
		if is_instance_valid(active_objective_node) and active_objective_node.has_method("set_hold_progress"):
			active_objective_node.set_hold_progress(0.0)
		if EventBus and EventBus.has_signal("event_logged"):
			EventBus.event_logged.emit("⚠️ 피격으로 인해 단말기 해킹 작업이 중단되었습니다!")

func _process(delta: float) -> void:
	if interact_cooldown > 0:
		interact_cooldown -= delta
	_update_interaction(delta)

func _update_interaction(delta: float) -> void:
	var interact_dist = 32.0
	var check_pos = player.global_position + Vector2.RIGHT.rotated(player.rotation) * interact_dist
	
	var object_layer: TileMapLayer = null
	var chunk_manager = player.get_node_or_null("/root/MainWorld/ChunkManager")
	if chunk_manager and chunk_manager.object_layer:
		object_layer = chunk_manager.object_layer
	else:
		var cur_scene = get_tree().current_scene
		if cur_scene and cur_scene.has_node("ObjectsLayer"):
			object_layer = cur_scene.get_node("ObjectsLayer")
		elif player.get_parent() and player.get_parent().get_parent() and player.get_parent().get_parent().has_node("ObjectsLayer"):
			object_layer = player.get_parent().get_parent().get_node("ObjectsLayer")
	
	interactable_type = Vector2i(-1, -1)
	interactable_tile_pos = Vector2i(-1, -1)
	var can_interact = false
	var prompt_text = ""
	
	# 바닥 아이템
	var nearby_ground_items = get_tree().get_nodes_in_group("ground_items")
	var closest_ground_item = null
	var min_ground_dist = 45.0
	
	for g in nearby_ground_items:
		if is_instance_valid(g):
			var dist = player.global_position.distance_to(g.global_position)
			if dist < min_ground_dist:
				min_ground_dist = dist
				closest_ground_item = g
				
	if closest_ground_item:
		can_interact = true
		var idata = ItemDatabase.get_item_data(closest_ground_item.item_id)
		prompt_text = "[E] %s 줍기" % idata.get("name", closest_ground_item.item_id)
		if Input.is_action_just_pressed("interact") or (Input.is_physical_key_pressed(KEY_E) and interact_cooldown <= 0.0):
			interact_cooldown = 0.3
			var rem = 0
			var orig_amt = closest_ground_item.amount
			if player and player.inventory_grid:
				rem = player.inventory_grid.auto_add_item(closest_ground_item.item_id, closest_ground_item.amount, closest_ground_item.custom_data)
			elif player and player.inventory:
				rem = player.inventory.add_item(closest_ground_item.item_id, closest_ground_item.amount)
				
			if rem <= 0:
				closest_ground_item.queue_free()
				if SoundManager: SoundManager.play("menu_select")
				EventBus.event_logged.emit("📦 %s x%d 획득!" % [idata.get("name", closest_ground_item.item_id), orig_amt])
			else:
				var picked = orig_amt - rem
				closest_ground_item.amount = rem
				closest_ground_item.update_visuals()
				if picked > 0:
					if SoundManager: SoundManager.play("menu_select")
					EventBus.event_logged.emit("📦 %s x%d 획득! (바닥에 %d개 남음)" % [idata.get("name", closest_ground_item.item_id), picked, rem])
				else:
					EventBus.event_logged.emit("⚠️ 가방 공간이 부족합니다.")
		interact_prompt.emit(true, prompt_text)
		return

	# 엔티티 상호작용
	var space_state = player.get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = check_pos
	query.collision_mask = 1 | 2
	query.collide_with_bodies = true
	query.collide_with_areas = true
	
	var results = space_state.intersect_point(query)
	var found_entity = false
	
	for res in results:
		var collider = res["collider"]
		if collider and collider.get("interactable_type") != null:
			var i_type = collider.get("interactable_type")
			if typeof(i_type) == TYPE_VECTOR2I and (i_type == Vector2i(5, 1) or i_type == Vector2i(7, 2) or i_type == Vector2i(8, 2)):
				can_interact = true
				if i_type == Vector2i(5, 1):
					prompt_text = "[E] 폐차 트렁크 열기"
				elif i_type == Vector2i(7, 2):
					prompt_text = "[E] 🪂 항공 보급품 상자 열기"
				else:
					prompt_text = collider.get_prompt_text() if collider.has_method("get_prompt_text") else "[E 3초 홀드] 📡 랜드마크 기밀 단말기 해킹"
					active_objective_node = collider
				interactable_type = i_type
				if object_layer:
					interactable_tile_pos = object_layer.local_to_map(collider.global_position)
				else:
					interactable_tile_pos = Vector2i(int(collider.global_position.x / 32), int(collider.global_position.y / 32))
				found_entity = true
				break
				
	# 타일맵 상호작용
	if not found_entity and object_layer:
		var t_pos = object_layer.local_to_map(check_pos)
		var tile_coords = object_layer.get_cell_atlas_coords(t_pos)
		
		var texts = {
			Vector2i(3,1): "[E] 수색하기", Vector2i(4,1): "[E] 드럼통 수색하기",
			Vector2i(5,1): "[E] 잔해물 뒤지기", Vector2i(6,1): "[E] 문 열기",
			Vector2i(7,1): "[E] 문 닫기", Vector2i(0,2): "[E] 냉장고 수색하기",
			Vector2i(1,2): "[E] 창문 깨기", Vector2i(2,2): "[E 꾹 누르기] 창문 넘어가기",
			Vector2i(5,2): "[E] ⚡ 주 발전기 / 조명 스위치 가동 (전력 및 벙커 개방)",
			Vector2i(0,3): "[E] 침대 수색하기",
			Vector2i(1,3): "[E] 책상 서랍 수색하기",
			Vector2i(2,3): "[E] 선반장 수색하기",
			Vector2i(3,3): "[E] 🔒 보안 잠금문 해제 (열쇠 / 보안 키카드)"
		}
		if texts.has(tile_coords):
			can_interact = true
			prompt_text = texts[tile_coords]
			interactable_tile_pos = t_pos
			interactable_type = tile_coords
	
	# 창문 넘어가기 홀드 처리
	if can_interact and interactable_type == Vector2i(2, 2):
		if Input.is_physical_key_pressed(KEY_E) or Input.is_action_pressed("interact"):
			vault_timer += delta
			if player and player.has_node("Visuals"): player.get_node("Visuals").queue_redraw()
			if vault_timer >= VAULT_DURATION:
				player.global_position += Vector2.RIGHT.rotated(player.rotation) * 44.0
				vault_timer = 0.0
				interact_cooldown = 0.4
				EventBus.noise_created.emit(player.global_position, 120.0, "vault")
				EventBus.event_logged.emit("🏃 창문을 뛰어넘었습니다.")
				if SoundManager: SoundManager.play("footstep")
				return
		else:
			if vault_timer > 0:
				vault_timer = 0.0
				if player and player.has_node("Visuals"): player.get_node("Visuals").queue_redraw()
	else:
		if vault_timer > 0:
			vault_timer = 0.0
			if player and player.has_node("Visuals"): player.get_node("Visuals").queue_redraw()
	
	interact_prompt.emit(can_interact, prompt_text)
	
	# 현장 퀘스트 단말기 3.0초 홀드 처리
	if can_interact and interactable_type == Vector2i(8, 2) and is_instance_valid(active_objective_node):
		if Input.is_physical_key_pressed(KEY_E) or Input.is_action_pressed("interact"):
			objective_hold_timer += delta
			if active_objective_node.has_method("set_hold_progress"):
				active_objective_node.set_hold_progress(objective_hold_timer / OBJECTIVE_HOLD_DURATION)
			if objective_hold_timer >= OBJECTIVE_HOLD_DURATION:
				objective_hold_timer = 0.0
				interact_cooldown = 0.5
				if active_objective_node.has_method("complete_objective"):
					active_objective_node.complete_objective(player)
				return
		else:
			if objective_hold_timer > 0.0:
				objective_hold_timer = 0.0
				if active_objective_node.has_method("set_hold_progress"):
					active_objective_node.set_hold_progress(0.0)
		return
	elif objective_hold_timer > 0.0:
		objective_hold_timer = 0.0
		if is_instance_valid(active_objective_node) and active_objective_node.has_method("set_hold_progress"):
			active_objective_node.set_hold_progress(0.0)
	
	if can_interact and interact_cooldown <= 0.0 and interactable_type != Vector2i(2, 2) and interactable_type != Vector2i(8, 2):
		if Input.is_physical_key_pressed(KEY_E) or Input.is_action_just_pressed("interact"):
			interact_cooldown = 0.35
			object_interacted.emit(check_pos, interactable_tile_pos, interactable_type)
