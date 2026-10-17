extends Node
class_name PlayerCamera

var base_camera_pos: Vector2 = Vector2.ZERO
var base_zoom: Vector2 = Vector2(1.5, 1.5)
var target_cam_offset: Vector2 = Vector2.ZERO
var shake_intensity: float = 0.0
var shake_timer: float = 0.0
var walk_bob: float = 0.0
var is_aiming_ads: bool = false

@onready var player = get_parent()
@onready var camera = player.get_node_or_null("Camera2D")

func _ready() -> void:
	if camera:
		base_camera_pos = camera.position
		base_zoom = camera.zoom
	if EventBus.has_signal("camera_shake_requested"):
		EventBus.camera_shake_requested.connect(request_shake)

func _process(delta: float) -> void:
	if not camera: return
	
	if player.velocity.length() > 10.0:
		walk_bob += delta * 12.0
	else:
		walk_bob = lerp(walk_bob, 0.0, delta * 10.0)
		
	_update_zoom(delta)
	
	if shake_timer > 0:
		shake_timer -= delta
		var shake_vec = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_intensity * clamp(shake_timer / 0.25, 0.0, 1.0)
		camera.position = camera.position + shake_vec

func request_shake(intensity: float, duration: float) -> void:
	shake_intensity = max(shake_intensity, intensity)
	shake_timer = max(shake_timer, duration)

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
				telescope_mult = 2.5
				break
			elif it and it.get("id") == "망원경":
				has_telescope = true
				telescope_mult = 1.6
				
	var scope_zoom = 1.0
	if player.has_node("WeaponHandler"):
		var w_data = player.get_node("WeaponHandler").equipped_weapon_data
		if not w_data.is_empty():
			scope_zoom = w_data.get("computed_stats", {}).get("zoom", 1.0)
			
	if is_aiming_ads:
		zoom_factor = max(scope_zoom, telescope_mult if has_telescope else 1.15)
		
	var target_zoom = base_zoom / sqrt(max(1.0, zoom_factor))
	
	if is_aiming_ads:
		var mouse_offset = player.get_global_mouse_position() - player.global_position
		var max_pan = 100.0 * max(1.0, zoom_factor * 0.85)
		target_cam_offset = mouse_offset.limit_length(max_pan)
	else:
		target_cam_offset = Vector2.ZERO
		
	camera.zoom = camera.zoom.lerp(target_zoom, delta * 6.0)
	camera.position = camera.position.lerp(base_camera_pos + target_cam_offset, delta * 7.5)
