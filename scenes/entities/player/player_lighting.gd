extends Node2D
class_name PlayerLighting

var flashlight: PointLight2D
var ambient_light: PointLight2D
var muzzle_light: PointLight2D
var flashlight_enabled: bool = true
var muzzle_flash_timer: float = 0.0

func _ready() -> void:
	ambient_light = PointLight2D.new()
	ambient_light.texture = _create_directional_ambient_texture(160, 0.6, 0.05)
	ambient_light.color = Color(1.0, 0.95, 0.8)
	ambient_light.energy = 0.85
	add_child(ambient_light)
	
	flashlight = PointLight2D.new()
	flashlight.texture = _create_flashlight_cone_texture(360, 260, 60.0)
	flashlight.offset = Vector2(180, 0)
	flashlight.color = Color(1.0, 0.98, 0.9)
	flashlight.energy = 1.6
	flashlight.shadow_enabled = true
	flashlight.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	add_child(flashlight)
	
	muzzle_light = PointLight2D.new()
	muzzle_light.texture = _create_flashlight_cone_texture(240, 180, 100.0)
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

func set_flashlight(enabled: bool) -> void:
	flashlight_enabled = enabled
	if flashlight: flashlight.enabled = flashlight_enabled
	if ambient_light: ambient_light.energy = 0.85 if flashlight_enabled else 0.15

func _create_directional_ambient_texture(size: int, front_alpha: float, back_alpha: float) -> ImageTexture:
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

func _create_flashlight_cone_texture(width: int, height: int, cone_angle_deg: float) -> ImageTexture:
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
