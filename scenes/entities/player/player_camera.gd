extends Node
class_name PlayerCamera

var base_camera_pos: Vector2 = Vector2.ZERO
var target_cam_offset: Vector2 = Vector2.ZERO
var shake_intensity: float = 0.0
var shake_timer: float = 0.0
var walk_bob: float = 0.0
var is_aiming_ads: bool = false

@onready var player = get_parent()
@onready var camera = player.get_node_or_null("Camera2D")

func _ready() -> void:
	if camera: base_camera_pos = camera.position
	if EventBus.has_signal("camera_shake_requested"):
		EventBus.camera_shake_requested.connect(request_shake)

func _process(delta: float) -> void:
	if not camera: return
	
	if player.velocity.length() > 10.0:
		walk_bob += delta * 12.0
	else:
		walk_bob = lerp(walk_bob, 0.0, delta * 10.0)
		
	if shake_timer > 0:
		shake_timer -= delta
		camera.position = base_camera_pos + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_intensity * (shake_timer / 0.5)
	else:
		if not is_aiming_ads: camera.position = base_camera_pos

	_update_zoom(delta)

func request_shake(intensity: float, duration: float) -> void:
	shake_intensity = intensity
	shake_timer = duration

func _update_zoom(delta: float) -> void:
	if not camera: return
	
	var zoom_factor = 1.0
	var has_telescope = false
	var telescope_mult = 1.0
	
	var inv = player.get_node_or_null("InventoryGrid")
	if inv:
		for it in inv.items:
			if it and it.get("id") == "고배율_망원경":
				has_telescope = true
				telescope_mult = 10.0
				break
			elif it and it.get("id") == "망원경":
				has_telescope = true
				telescope_mult = 5.0
				
	var scope_zoom = 1.0
	if player.has_node("WeaponHandler"):
		var w_data = player.get_node("WeaponHandler").equipped_weapon_data
		if not w_data.is_empty():
			scope_zoom = w_data.get("computed_stats", {}).get("zoom", 1.0)
			
	if is_aiming_ads:
		zoom_factor = max(scope_zoom, telescope_mult if has_telescope else 1.0)
		
	var target_zoom_val = 1.0 / sqrt(zoom_factor)
	var target_zoom = Vector2(target_zoom_val, target_zoom_val)
	
	if is_aiming_ads and zoom_factor > 1.0:
		var mouse_offset = player.get_global_mouse_position() - player.global_position
		target_cam_offset = mouse_offset.limit_length(180.0 * (zoom_factor / 2.0))
	else:
		target_cam_offset = Vector2.ZERO
		
	camera.zoom = camera.zoom.lerp(target_zoom, delta * 6.0)
	camera.position = camera.position.lerp(base_camera_pos + target_cam_offset, delta * 6.0)
