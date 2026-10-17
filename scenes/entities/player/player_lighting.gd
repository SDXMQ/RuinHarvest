extends Node2D
class_name PlayerLighting

static var _cached_ambient_tex: ImageTexture = null
static var _cached_flashlight_tex: ImageTexture = null
static var _cached_muzzle_tex: ImageTexture = null

var flashlight: PointLight2D
var ambient_light: PointLight2D
var muzzle_light: PointLight2D
var flashlight_enabled: bool = true
var nvg_enabled: bool = false
var muzzle_flash_timer: float = 0.0

func _ready() -> void:
	if not _cached_ambient_tex:
		_cached_ambient_tex = _create_directional_ambient_texture(96, 0.65, 0.08)
	if not _cached_flashlight_tex:
		_cached_flashlight_tex = _create_flashlight_cone_texture(180, 130, 62.0)
	if not _cached_muzzle_tex:
		_cached_muzzle_tex = _create_flashlight_cone_texture(120, 90, 100.0)

	ambient_light = PointLight2D.new()
	ambient_light.texture = _cached_ambient_tex
	ambient_light.texture_scale = 1.75
	ambient_light.color = Color(1.0, 0.95, 0.8)
	ambient_light.energy = 0.85
	add_child(ambient_light)
	
	flashlight = PointLight2D.new()
	flashlight.texture = _cached_flashlight_tex
	flashlight.texture_scale = 2.0
	flashlight.offset = Vector2(180, 0)
	flashlight.color = Color(1.0, 0.98, 0.9)
	flashlight.energy = 1.6
	flashlight.shadow_enabled = true
	flashlight.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	add_child(flashlight)
	
	muzzle_light = PointLight2D.new()
	muzzle_light.texture = _cached_muzzle_tex
	muzzle_light.texture_scale = 2.0
	muzzle_light.offset = Vector2(120, 0)
	muzzle_light.color = Color(1.0, 0.85, 0.4)
	muzzle_light.energy = 0.0
	muzzle_light.enabled = false
	add_child(muzzle_light)
	
	set_flashlight(flashlight_enabled)

func _process(delta: float) -> void:
	if muzzle_flash_timer > 0.0:
		muzzle_flash_timer -= delta
		if muzzle_flash_timer <= 0.0 and muzzle_light:
			muzzle_light.enabled = false
			muzzle_light.energy = 0.0

func trigger_muzzle_flash() -> void:
	muzzle_flash_timer = 0.06
	if muzzle_light:
		muzzle_light.enabled = true
		muzzle_light.energy = 1.4

func toggle_flashlight() -> void:
	set_flashlight(not flashlight_enabled)

func toggle_nvg() -> void:
	nvg_enabled = not nvg_enabled
	set_flashlight(flashlight_enabled)
	if EventBus.has_signal("event_logged"):
		EventBus.event_logged.emit("🥽 전술 야간투시경(NVG): %s" % ("ON" if nvg_enabled else "OFF"))

func set_flashlight(enabled: bool) -> void:
	flashlight_enabled = enabled
	if flashlight:
		flashlight.enabled = flashlight_enabled
		flashlight.color = Color(0.35, 1.0, 0.45) if nvg_enabled else Color(1.0, 0.98, 0.9)
	if ambient_light:
		if nvg_enabled:
			ambient_light.color = Color(0.3, 1.0, 0.4)
			ambient_light.energy = 1.65
			ambient_light.texture_scale = 3.2
		else:
			ambient_light.color = Color(1.0, 0.95, 0.8)
			ambient_light.energy = 0.85 if flashlight_enabled else 0.18
			ambient_light.texture_scale = 1.75

static func _create_directional_ambient_texture(size: int, front_alpha: float, back_alpha: float) -> ImageTexture:
	var img = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center = size / 2.0
	for y in range(size):
		for x in range(size):
			var dx = x - center; var dy = y - center; var dist = sqrt(dx * dx + dy * dy)
			if dist > center: continue
			var dist_factor = pow(1.0 - (dist / center), 1.4)
			var angle = atan2(dy, dx)
			var forward_bias = (cos(angle) + 1.0) / 2.0
			var alpha_target = lerp(back_alpha, front_alpha, forward_bias)
			var alpha = clamp(dist_factor * alpha_target, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)

static func _create_flashlight_cone_texture(width: int, height: int, cone_angle_deg: float) -> ImageTexture:
	var img = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	var start_x = 0.0; var start_y = height / 2.0
	var half_angle_rad = deg_to_rad(cone_angle_deg / 2.0)
	var max_dist = float(width)
	for y in range(height):
		for x in range(width):
			var dx = x - start_x; var dy = y - start_y; var dist = sqrt(dx * dx + dy * dy)
			if dist <= 0.0 or dist > max_dist: continue
			var angle = abs(atan2(dy, dx))
			if angle > half_angle_rad: continue
			var dist_factor = pow(1.0 - (dist / max_dist), 1.5)
			var angle_factor = cos((angle / half_angle_rad) * (PI / 2.0))
			var alpha = clamp(dist_factor * angle_factor, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)
