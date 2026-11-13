# res://autoload/pixel_asset_manager.gd
extends Node

## 픽셀 아트 디스크 리소스(*_d.png, *_n.png)를 로드하고 CanvasTexture로 결합·캐싱하는 싱글톤

const PIXEL_ROOT := "res://assets/pixel/"
const PixelEntityShader = preload("res://graphics/shaders/pixel_entity.gdshader")

var _canvas_cache: Dictionary = {}
var _diffuse_cache: Dictionary = {}
var _normal_cache: Dictionary = {}
var _slice_cache: Dictionary = {}
var _radial_light_tex: GradientTexture2D = null

func _ready() -> void:
	# 핵심 시트 선행 워밍업 (게임/테스트 진입 시 즉시 사용 가능)
	for key in [
		"tiles/world_tileset",
		"entities/player_parts",
		"weapons/weapon_parts",
		"entities/enemies",
		"props/world_props"
	]:
		get_canvas_texture(key)

func create_pixel_entity_material(rim: float = 0.22, local_to_scene: bool = false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.resource_local_to_scene = local_to_scene
	mat.shader = PixelEntityShader
	mat.set_shader_parameter("flash_modifier", 0.0)
	mat.set_shader_parameter("flash_color", Color(1.0, 1.0, 1.0, 1.0))
	mat.set_shader_parameter("stealth_dissolve", 0.0)
	mat.set_shader_parameter("rim_strength", rim)
	return mat

func get_radial_light_texture() -> GradientTexture2D:
	if _radial_light_tex != null:
		return _radial_light_tex
	var grad := Gradient.new()
	grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(0.58, 0.58, 0.58, 0.55),
		Color(0.0, 0.0, 0.0, 0.0)
	])
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	_radial_light_tex = tex
	return _radial_light_tex

func get_canvas_texture(key: String) -> CanvasTexture:
	if _canvas_cache.has(key):
		return _canvas_cache[key]

	var base_path := _resolve_base_path(key)
	var d_path := base_path + "_d.png"
	var n_path := base_path + "_n.png"

	var diff_tex := load_texture_2d(d_path)
	if diff_tex == null:
		return null

	var norm_tex := load_texture_2d(n_path)
	if norm_tex == null:
		var d_img := diff_tex.get_image()
		if d_img != null:
			var n_img := generate_normal_map_from_image(d_img, 2.4)
			norm_tex = ImageTexture.create_from_image(n_img)

	var ct := CanvasTexture.new()
	ct.diffuse_texture = diff_tex
	ct.normal_texture = norm_tex
	ct.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ct.specular_shininess = 0.35

	_canvas_cache[key] = ct
	_diffuse_cache[key] = diff_tex
	if norm_tex:
		_normal_cache[key] = norm_tex
	return ct

func get_diffuse_texture(key: String) -> Texture2D:
	if _diffuse_cache.has(key):
		return _diffuse_cache[key]
	var ct := get_canvas_texture(key)
	if ct != null:
		return ct.diffuse_texture
	return null

func get_normal_texture(key: String) -> Texture2D:
	if _normal_cache.has(key):
		return _normal_cache[key]
	var ct := get_canvas_texture(key)
	if ct != null:
		return ct.normal_texture
	return null

func get_atlas_slice(key: String, region: Rect2i) -> CanvasTexture:
	var slice_key := "%s:%d,%d,%d,%d" % [key, region.position.x, region.position.y, region.size.x, region.size.y]
	if _slice_cache.has(slice_key):
		return _slice_cache[slice_key]

	var base_ct := get_canvas_texture(key)
	if base_ct == null or base_ct.diffuse_texture == null:
		return null

	var d_src := base_ct.diffuse_texture.get_image()
	if d_src == null:
		return null
	var d_sub := d_src.get_region(region)
	var d_tex := ImageTexture.create_from_image(d_sub)

	var n_tex: Texture2D = null
	if base_ct.normal_texture != null:
		var n_src := base_ct.normal_texture.get_image()
		if n_src != null:
			var n_sub := n_src.get_region(region)
			n_tex = ImageTexture.create_from_image(n_sub)
	if n_tex == null:
		n_tex = ImageTexture.create_from_image(generate_normal_map_from_image(d_sub, 2.4))

	var ct := CanvasTexture.new()
	ct.diffuse_texture = d_tex
	ct.normal_texture = n_tex
	ct.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ct.specular_shininess = 0.35
	_slice_cache[slice_key] = ct
	return ct

static func get_cell_rect(col: int, row: int, cell_w: int = 32, cell_h: int = 32) -> Rect2:
	return Rect2(float(col * cell_w), float(row * cell_h), float(cell_w), float(cell_h))

func create_canvas_texture_from_images(diff_img: Image, norm_img: Image = null, strength: float = 2.4) -> CanvasTexture:
	var d_tex := ImageTexture.create_from_image(diff_img)
	var n_img := norm_img if norm_img != null else generate_normal_map_from_image(diff_img, strength)
	var n_tex := ImageTexture.create_from_image(n_img)
	var ct := CanvasTexture.new()
	ct.diffuse_texture = d_tex
	ct.normal_texture = n_tex
	ct.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ct.specular_shininess = 0.35
	return ct

func load_texture_2d(res_path: String) -> Texture2D:
	# 1. 소스 체크아웃/에셋 리베이크 환경에서는 디스크 PNG를 우선 로드 (구버전 .ctex 캐시 무시)
	var abs_path := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		var img := Image.new()
		var err := img.load(abs_path)
		if err == OK and not img.is_empty():
			if img.get_format() != Image.FORMAT_RGBA8:
				img.convert(Image.FORMAT_RGBA8)
			return ImageTexture.create_from_image(img)
	# 2. 익스포트(.pck) 환경 폴백: ResourceLoader(.ctex) 사용
	if ResourceLoader.exists(res_path):
		var loaded := load(res_path)
		if loaded is Texture2D:
			return loaded
	return null

func generate_normal_map_from_image(img: Image, strength: float = 2.4) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var norm_img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	if w <= 0 or h <= 0:
		return norm_img

	# 스칼라 높이 버퍼 계산 (밝기 + 알파 실루엣)
	var heights := PackedFloat32Array()
	heights.resize(w * h)
	for y in range(h):
		for x in range(w):
			var c := img.get_pixel(x, y)
			var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			heights[y * w + x] = (lum * 0.6 + c.a * 0.4) * c.a

	for y in range(h):
		var ym1 := maxi(0, y - 1)
		var yp1 := mini(h - 1, y + 1)
		for x in range(w):
			var xm1 := maxi(0, x - 1)
			var xp1 := mini(w - 1, x + 1)

			var tl := heights[ym1 * w + xm1]
			var tc := heights[ym1 * w + x]
			var tr := heights[ym1 * w + xp1]
			var ml := heights[y * w + xm1]
			var mr := heights[y * w + xp1]
			var bl := heights[yp1 * w + xm1]
			var bc := heights[yp1 * w + x]
			var br := heights[yp1 * w + xp1]

			var gx := ((tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl)) * 0.25
			var gy := ((bl + 2.0 * bc + br) - (tl + 2.0 * tc + tr)) * 0.25

			# Verified Godot 4.7 OpenGL normal convention: nx = -gx, ny = +gy
			var nx := -gx * strength
			var ny := gy * strength
			var nvec := Vector3(nx, ny, 1.0).normalized()
			norm_img.set_pixel(x, y, Color(nvec.x * 0.5 + 0.5, nvec.y * 0.5 + 0.5, nvec.z * 0.5 + 0.5, 1.0))
	return norm_img

func _resolve_base_path(key: String) -> String:
	var k := key
	if k.ends_with("_d.png"):
		k = k.substr(0, k.length() - 6)
	elif k.ends_with("_n.png"):
		k = k.substr(0, k.length() - 6)
	elif k.ends_with(".png"):
		k = k.substr(0, k.length() - 4)
	if k.begins_with("res://"):
		return k
	return PIXEL_ROOT + k
