extends Node
class_name PlayerCamera

var base_camera_pos: Vector2 = Vector2.ZERO
var base_zoom: Vector2 = Vector2(2.0, 2.0)
var target_cam_offset: Vector2 = Vector2.ZERO
var recoil_punch_offset: Vector2 = Vector2.ZERO
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
	if not camera:
		return

	if player.velocity.length() > 10.0:
		walk_bob += delta * 12.0
	else:
		walk_bob = lerpf(walk_bob, 0.0, clampf(delta * 10.0, 0.0, 1.0))

	recoil_punch_offset = recoil_punch_offset.lerp(Vector2.ZERO, clampf(delta * 16.0, 0.0, 1.0))
	_update_zoom(delta)

	if shake_timer > 0.0:
		shake_timer -= delta
		var shake_vec := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_intensity * clampf(shake_timer / 0.25, 0.0, 1.0)
		camera.position = camera.position + shake_vec

func request_shake(intensity: float, duration: float) -> void:
	shake_intensity = maxf(shake_intensity, intensity)
	shake_timer = maxf(shake_timer, duration)

func apply_recoil_punch(shot_dir: Vector2, recoil_amount: float = 20.0) -> void:
	var kick_px := clampf(recoil_amount * 0.16, 2.0, 4.5)
	recoil_punch_offset = (recoil_punch_offset - shot_dir.normalized() * kick_px).limit_length(8.0)
	if camera:
		camera.position += -shot_dir.normalized() * kick_px

func _update_zoom(delta: float) -> void:
	if not camera:
		return

	var zoom_factor := 1.0
	var has_telescope := false
	var telescope_mult := 1.0

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

	var scope_zoom := 1.0
	if player.has_node("WeaponHandler"):
		var w_data: Dictionary = player.get_node("WeaponHandler").equipped_weapon_data
		if not w_data.is_empty():
			scope_zoom = float(w_data.get("computed_stats", {}).get("zoom", 1.0))

	if is_aiming_ads:
		zoom_factor = maxf(scope_zoom, telescope_mult if has_telescope else 1.15)

	var target_zoom: Vector2 = base_zoom / sqrt(maxf(1.0, zoom_factor))

	if is_aiming_ads:
		var mouse_offset: Vector2 = player.get_global_mouse_position() - player.global_position
		var max_pan := 80.0 * maxf(1.0, zoom_factor * 0.75)
		target_cam_offset = mouse_offset.limit_length(max_pan)
	else:
		target_cam_offset = Vector2.ZERO

	camera.zoom = camera.zoom.lerp(target_zoom, clampf(delta * 6.0, 0.0, 1.0))
	camera.position = camera.position.lerp(base_camera_pos + target_cam_offset + recoil_punch_offset, clampf(delta * 7.5, 0.0, 1.0))
