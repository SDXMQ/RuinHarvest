# res://autoload/pixel_asset_manager.gd
extends Node

## 픽셀 아트 디스크 리소스(*_d.png, *_n.png)를 로드하고 CanvasTexture로 결합·캐싱하는 싱글톤

const PIXEL_ROOT := "res://assets/pixel/"
const PixelEntityShader = preload("res://graphics/shaders/pixel_entity.gdshader")
const FONT_PATH_REGULAR := "res://assets/fonts/Galmuri11.ttf"
const FONT_PATH_BOLD := "res://assets/fonts/Galmuri11-Bold.ttf"
const FONT_PATH_MICRO := "res://assets/fonts/Galmuri9.ttf"

var _canvas_cache: Dictionary = {}
var _diffuse_cache: Dictionary = {}
var _normal_cache: Dictionary = {}
var _slice_cache: Dictionary = {}
var _ui_stylebox_cache: Dictionary = {}
var _font_cache: Dictionary = {}
var _radial_light_tex: GradientTexture2D = null

const UI_CELL_SIZE := 24
const UI_SLICE_COORDS := {
	"panel_main": Vector2i(0, 0),
	"panel_header": Vector2i(1, 0),
	"panel_grid_surface": Vector2i(2, 0),
	"panel_tooltip": Vector2i(3, 0),
	"panel_line_edit": Vector2i(4, 0),
	"tab_selected": Vector2i(5, 0),
	"tab_unselected": Vector2i(6, 0),
	"panel_bounty": Vector2i(7, 0),
	"btn_normal": Vector2i(0, 1),
	"btn_hover": Vector2i(1, 1),
	"btn_pressed": Vector2i(2, 1),
	"btn_disabled": Vector2i(3, 1),
	"btn_primary_normal": Vector2i(4, 1),
	"btn_primary_hover": Vector2i(5, 1),
	"btn_danger_normal": Vector2i(6, 1),
	"btn_danger_hover": Vector2i(7, 1),
	"equip_normal": Vector2i(0, 2),
	"equip_hover": Vector2i(1, 2),
	"equip_filled": Vector2i(2, 2),
	"equip_gold": Vector2i(3, 2),
	"quickslot_normal": Vector2i(4, 2),
	"quickslot_active": Vector2i(5, 2),
	"quickslot_unavailable": Vector2i(6, 2),
	"slot_compat_green": Vector2i(7, 2),
	"progress_bg": Vector2i(0, 3),
	"progress_fill_amber": Vector2i(1, 3),
	"scroll_bg": Vector2i(2, 3),
	"scroll_grabber": Vector2i(3, 3),
	"badge_frame": Vector2i(4, 3),
	"slot_incompat_red": Vector2i(5, 3),
	"slot_guide_compat": Vector2i(6, 3),
	"slot_guide_default": Vector2i(7, 3),
	"btn_primary_pressed": Vector2i(0, 4),
	"btn_danger_pressed": Vector2i(1, 4),
	"equip_pressed": Vector2i(2, 4),
}

func _ready() -> void:
	# 핵심 월드 시트 선행 워밍업 (게임/테스트 진입 시 즉시 사용 가능)
	for key in [
		"tiles/world_tileset",
		"entities/player_parts",
		"weapons/weapon_parts",
		"entities/enemies",
		"props/world_props"
	]:
		get_canvas_texture(key)
	# UI 테마 아틀라스는 별도 CanvasLayer에서 렌더링되므로 불필요한 노말맵(_n.png) 없이 디퓨즈만 로드
	get_diffuse_texture("ui/ui_theme_atlas")
	apply_pixel_ui_theme()

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
	var base_path := _resolve_base_path(key)
	var d_path := base_path + "_d.png"
	var diff_tex := load_texture_2d(d_path)
	if diff_tex != null:
		_diffuse_cache[key] = diff_tex
		return diff_tex
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

func get_cell_rect(col: int, row: int, cell_w: int = 32, cell_h: int = 32) -> Rect2:
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
			var top_r := heights[ym1 * w + xp1]
			var ml := heights[y * w + xm1]
			var mr := heights[y * w + xp1]
			var bl := heights[yp1 * w + xm1]
			var bc := heights[yp1 * w + x]
			var br := heights[yp1 * w + xp1]

			var gx := ((top_r + 2.0 * mr + br) - (tl + 2.0 * ml + bl)) * 0.25
			var gy := ((bl + 2.0 * bc + br) - (tl + 2.0 * tc + top_r)) * 0.25

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

func _load_crisp_pixel_font(res_path: String) -> Font:
	if _font_cache.has(res_path):
		return _font_cache[res_path]
	if ResourceLoader.exists(res_path):
		var loaded := load(res_path)
		if loaded is FontFile:
			var ff: FontFile = loaded as FontFile
			ff.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
			ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
			ff.multichannel_signed_distance_field = false
			ff.allow_system_fallback = false
			ff.hinting = TextServer.HINTING_LIGHT
			ff.generate_mipmaps = false
			ff.oversampling = 0.0
			_font_cache[res_path] = ff
			return ff
		elif loaded is Font:
			_font_cache[res_path] = loaded
			return loaded
	return ThemeDB.fallback_font

func get_pixel_font_regular() -> Font:
	return _load_crisp_pixel_font(FONT_PATH_REGULAR)

func get_pixel_font_bold() -> Font:
	return _load_crisp_pixel_font(FONT_PATH_BOLD)

func get_pixel_font_micro() -> Font:
	return _load_crisp_pixel_font(FONT_PATH_MICRO)

const UI_PRESET_MAP := {
	"popup_frame": {"slice": "panel_tooltip", "cm": [6.0, 6.0, 6.0, 6.0], "tm": 4},
	"context_menu": {"slice": "panel_tooltip", "cm": [8.0, 6.0, 8.0, 6.0], "tm": 4},
	"tooltip": {"slice": "panel_tooltip", "cm": [12.0, 10.0, 12.0, 10.0], "tm": 4},
	"receipt_panel": {"slice": "panel_main", "cm": [8.0, 8.0, 8.0, 8.0], "tm": 4, "tint": Color(0.85, 1.0, 0.94, 1.0)},
	"market_confirm_panel": {"slice": "panel_main", "cm": [8.0, 6.0, 8.0, 6.0], "tm": 4, "tint": Color(0.86, 0.94, 1.0, 1.0)},
	"bounty_panel": {"slice": "panel_bounty", "cm": [12.0, 10.0, 12.0, 10.0], "tm": 4},
	"barter_card": {"slice": "panel_bounty", "cm": [8.0, 6.0, 8.0, 6.0], "tm": 4, "tint": Color(0.95, 0.90, 0.78, 1.0)},
	"mastery_gold": {"slice": "panel_bounty", "cm": [8.0, 6.0, 8.0, 6.0], "tm": 4},
	"weapon_card": {"slice": "panel_main", "cm": [8.0, 6.0, 8.0, 6.0], "tm": 4},
	"weapon_card_gold": {"slice": "equip_gold", "cm": [8.0, 6.0, 8.0, 6.0], "tm": 4},
	"icon_frame": {"slice": "equip_filled", "cm": [2.0, 2.0, 2.0, 2.0], "tm": 3},
	"icon_frame_gold": {"slice": "equip_gold", "cm": [2.0, 2.0, 2.0, 2.0], "tm": 3},
	"workbench_slot": {"slice": "equip_normal", "cm": [8.0, 4.0, 8.0, 4.0], "tm": 4},
	"workbench_slot_active": {"slice": "equip_filled", "cm": [8.0, 4.0, 8.0, 4.0], "tm": 4},
	"workbench_selected_btn": {"slice": "equip_filled", "cm": [8.0, 4.0, 8.0, 4.0], "tm": 4},
	"toast": {"slice": "badge_frame", "cm": [10.0, 6.0, 10.0, 6.0], "tm": 4},
	"progress_bg": {"slice": "progress_bg", "cm": [2.0, 2.0, 2.0, 2.0], "tm": 3},
	"progress_fill": {"slice": "progress_fill_amber", "cm": [2.0, 1.0, 2.0, 1.0], "tm": 2},
	"save_slot_card": {"slice": "panel_main", "cm": [12.0, 8.0, 12.0, 8.0], "tm": 4, "tint": Color(0.88, 0.94, 1.0, 1.0)},
	"header_bar": {"slice": "panel_header", "cm": [10.0, 5.0, 10.0, 5.0], "tm": 4},
	"footer_bar": {"slice": "panel_main", "cm": [10.0, 6.0, 10.0, 6.0], "tm": 4},
	"drag_preview": {"slice": "equip_gold", "cm": [4.0, 4.0, 4.0, 4.0], "tm": 4},
	"hover_compat": {"slice": "slot_compat_green", "cm": [6.0, 3.0, 6.0, 3.0], "tm": 4},
	"hover_incompat": {"slice": "slot_incompat_red", "cm": [6.0, 3.0, 6.0, 3.0], "tm": 4},
	"guide_compat": {"slice": "slot_guide_compat", "cm": [6.0, 3.0, 6.0, 3.0], "tm": 4},
	"guide_default": {"slice": "slot_guide_default", "cm": [6.0, 3.0, 6.0, 3.0], "tm": 4},
}

func get_pixel_stylebox(
	preset_name: String,
	cm_l: float = -1.0,
	cm_t: float = -1.0,
	cm_r: float = -1.0,
	cm_b: float = -1.0,
	tex_margin: int = -1,
	modulate_col: Color = Color.WHITE
) -> StyleBox:
	var slice_name: String = preset_name
	var def_cm: Array = [10.0, 4.0, 10.0, 4.0]
	var def_tm: int = 4
	var preset_tint: Color = Color.WHITE

	if UI_PRESET_MAP.has(preset_name):
		var cfg: Dictionary = UI_PRESET_MAP[preset_name]
		slice_name = str(cfg.get("slice", "panel_main"))
		def_cm = cfg.get("cm", def_cm)
		def_tm = int(cfg.get("tm", 4))
		preset_tint = cfg.get("tint", Color.WHITE)
	elif not UI_SLICE_COORDS.has(slice_name):
		slice_name = "panel_main"

	var resolved_l: float = cm_l if cm_l >= 0.0 else float(def_cm[0])
	var resolved_t: float = cm_t if cm_t >= 0.0 else float(def_cm[1])
	var resolved_r: float = cm_r if cm_r >= 0.0 else float(def_cm[2])
	var resolved_b: float = cm_b if cm_b >= 0.0 else float(def_cm[3])
	var resolved_tm: int = tex_margin if tex_margin >= 0 else def_tm
	var effective_tint: Color = modulate_col if not modulate_col.is_equal_approx(Color.WHITE) else preset_tint

	var base_sb: StyleBox = get_ui_stylebox(slice_name, resolved_l, resolved_t, resolved_r, resolved_b, resolved_tm)
	if not effective_tint.is_equal_approx(Color.WHITE) and base_sb is StyleBoxTexture:
		var tinted := base_sb.duplicate() as StyleBoxTexture
		tinted.modulate_color = effective_tint
		return tinted
	return base_sb

func make_pixel_stylebox_flat(
	_bg: Color,
	border: Color,
	_bw_left: int = 2,
	_bw_top: int = 2,
	_bw_right: int = 2,
	_bw_bottom: int = 2,
	cm_h: float = 8.0,
	cm_v: float = 6.0,
	_with_shadow: bool = false
) -> StyleBox:
	return get_pixel_stylebox("panel_main", cm_h, cm_v, cm_h, cm_v, 4, border.lerp(Color.WHITE, 0.35))

func get_ui_stylebox(
	style_name: String,
	cm_l: float = 10.0,
	cm_t: float = 4.0,
	cm_r: float = 10.0,
	cm_b: float = 4.0,
	tex_margin: int = 4
) -> StyleBox:
	var cache_key := "%s:%d,%d,%d,%d:%d" % [style_name, int(cm_l), int(cm_t), int(cm_r), int(cm_b), tex_margin]
	if _ui_stylebox_cache.has(cache_key):
		return _ui_stylebox_cache[cache_key]

	if UI_SLICE_COORDS.has(style_name):
		var diff_tex := get_diffuse_texture("ui/ui_theme_atlas")
		if diff_tex != null:
			var d_img := diff_tex.get_image()
			if d_img != null:
				var cell: Vector2i = UI_SLICE_COORDS[style_name]
				var sub_img := d_img.get_region(Rect2i(cell.x * UI_CELL_SIZE, cell.y * UI_CELL_SIZE, UI_CELL_SIZE, UI_CELL_SIZE))
				var default_modulate := Color(1.0, 1.0, 1.0, 1.0)
				if style_name == "progress_fill_amber":
					# 동적 틴트(초록/노랑/빨강/청록) 시 색상이 탁해지지 않도록 화이트 픽셀 베벨로 정규화 후 기본 앰버 틴트 부여
					for py in range(sub_img.get_height()):
						for px in range(sub_img.get_width()):
							var c := sub_img.get_pixel(px, py)
							var v := maxf(c.r, maxf(c.g, c.b))
							var boost := clampf(v * 1.12, 0.0, 1.0)
							sub_img.set_pixel(px, py, Color(boost, boost, boost, c.a))
					default_modulate = Color(0.92, 0.68, 0.22, 1.0)
				var sub_tex := ImageTexture.create_from_image(sub_img)
				var ui_ct := CanvasTexture.new()
				ui_ct.diffuse_texture = sub_tex
				ui_ct.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				var sbt := StyleBoxTexture.new()
				sbt.texture = ui_ct
				sbt.region_rect = Rect2(0.0, 0.0, float(UI_CELL_SIZE), float(UI_CELL_SIZE))
				sbt.modulate_color = default_modulate
				sbt.texture_margin_left = float(tex_margin)
				sbt.texture_margin_top = float(tex_margin)
				sbt.texture_margin_right = float(tex_margin)
				sbt.texture_margin_bottom = float(tex_margin)
				sbt.content_margin_left = cm_l
				sbt.content_margin_top = cm_t
				sbt.content_margin_right = cm_r
				sbt.content_margin_bottom = cm_b
				_ui_stylebox_cache[cache_key] = sbt
				return sbt

	# 아틀라스 미로드 시에도 StyleBoxFlat 대신 1x1 근접 필터링 StyleBoxTexture 폴백 반환
	var fb_img := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	fb_img.fill(Color(0.08, 0.10, 0.13, 0.96))
	var fb_ct := CanvasTexture.new()
	fb_ct.diffuse_texture = ImageTexture.create_from_image(fb_img)
	fb_ct.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var fb_sb := StyleBoxTexture.new()
	fb_sb.texture = fb_ct
	fb_sb.texture_margin_left = 2.0
	fb_sb.texture_margin_top = 2.0
	fb_sb.texture_margin_right = 2.0
	fb_sb.texture_margin_bottom = 2.0
	fb_sb.content_margin_left = cm_l
	fb_sb.content_margin_top = cm_t
	fb_sb.content_margin_right = cm_r
	fb_sb.content_margin_bottom = cm_b
	_ui_stylebox_cache[cache_key] = fb_sb
	return fb_sb

func apply_pixel_ui_theme() -> void:
	var themes_to_patch: Array[Theme] = []
	if ResourceLoader.exists("res://ui/theme/tactical_theme.tres"):
		var custom_t = load("res://ui/theme/tactical_theme.tres")
		if custom_t is Theme:
			themes_to_patch.append(custom_t)
	var proj_t := ThemeDB.get_project_theme()
	if proj_t != null and not (proj_t in themes_to_patch):
		themes_to_patch.append(proj_t)

	var font_reg: Font = get_pixel_font_regular()
	var font_bold: Font = get_pixel_font_bold()

	for t in themes_to_patch:
		if font_reg:
			t.default_font = font_reg
			t.default_font_size = 12
		if font_bold:
			t.set_font("font", "TabContainer", font_bold)
			t.set_font("font", "PrimaryButton", font_bold)
			t.set_font("font", "DangerButton", font_bold)
			t.set_type_variation("HeaderLabel", "Label")
			t.set_font("font", "HeaderLabel", font_bold)
			t.set_font_size("font_size", "HeaderLabel", 12)

		t.set_stylebox("panel", "Panel", get_ui_stylebox("panel_main", 10, 8, 10, 8, 5))
		t.set_stylebox("panel", "PanelContainer", get_ui_stylebox("panel_main", 10, 8, 10, 8, 5))
		t.set_stylebox("panel", "PopupMenu", get_ui_stylebox("panel_tooltip", 8, 6, 8, 6, 4))
		t.set_stylebox("panel", "HeaderPanel", get_ui_stylebox("panel_header", 10, 5, 10, 5, 4))
		t.set_stylebox("panel", "GridSurfacePanel", get_ui_stylebox("panel_grid_surface", 6, 6, 6, 6, 4))

		# 소형 버튼(22~28px)에서도 9-Patch 중앙 영역이 음수가 되지 않도록 상하 texture_margin을 4px(합 8px)로 제한
		# Pressed 상태는 content_margin_top +1 / content_margin_bottom -1로 물리적 1px 눌림 연출
		var sb_btn_normal := get_ui_stylebox("btn_normal", 10, 4, 10, 4, 4)
		var sb_btn_hover := get_ui_stylebox("btn_hover", 10, 4, 10, 4, 4)
		var sb_btn_pressed := get_ui_stylebox("btn_pressed", 10, 5, 10, 3, 4)
		var sb_btn_disabled := get_ui_stylebox("btn_disabled", 10, 4, 10, 4, 4)
		t.set_stylebox("normal", "Button", sb_btn_normal)
		t.set_stylebox("hover", "Button", sb_btn_hover)
		t.set_stylebox("pressed", "Button", sb_btn_pressed)
		t.set_stylebox("disabled", "Button", sb_btn_disabled)
		t.set_stylebox("normal", "OptionButton", sb_btn_normal)
		t.set_stylebox("hover", "OptionButton", sb_btn_hover)
		t.set_stylebox("pressed", "OptionButton", sb_btn_pressed)

		# 22~28px 초소형 전술 버튼 전용 타입 변형 (SmallButton: texture_margin 3px, 상하 합 6px)
		t.set_type_variation("SmallButton", "Button")
		t.set_stylebox("normal", "SmallButton", get_ui_stylebox("btn_normal", 6, 2, 6, 2, 3))
		t.set_stylebox("hover", "SmallButton", get_ui_stylebox("btn_hover", 6, 2, 6, 2, 3))
		t.set_stylebox("pressed", "SmallButton", get_ui_stylebox("btn_pressed", 6, 3, 6, 1, 3))
		t.set_stylebox("disabled", "SmallButton", get_ui_stylebox("btn_disabled", 6, 2, 6, 2, 3))

		var sb_pri_normal := get_ui_stylebox("btn_primary_normal", 12, 4, 12, 4, 4)
		var sb_pri_hover := get_ui_stylebox("btn_primary_hover", 12, 4, 12, 4, 4)
		var sb_pri_pressed := get_ui_stylebox("btn_primary_pressed", 12, 5, 12, 3, 4)
		t.set_stylebox("normal", "PrimaryButton", sb_pri_normal)
		t.set_stylebox("hover", "PrimaryButton", sb_pri_hover)
		t.set_stylebox("pressed", "PrimaryButton", sb_pri_pressed)

		var sb_dng_normal := get_ui_stylebox("btn_danger_normal", 10, 4, 10, 4, 4)
		var sb_dng_hover := get_ui_stylebox("btn_danger_hover", 10, 4, 10, 4, 4)
		var sb_dng_pressed := get_ui_stylebox("btn_danger_pressed", 10, 5, 10, 3, 4)
		t.set_stylebox("normal", "DangerButton", sb_dng_normal)
		t.set_stylebox("hover", "DangerButton", sb_dng_hover)
		t.set_stylebox("pressed", "DangerButton", sb_dng_pressed)

		var sb_eq_normal := get_ui_stylebox("equip_normal", 6, 4, 6, 4, 4)
		var sb_eq_hover := get_ui_stylebox("equip_hover", 6, 4, 6, 4, 4)
		var sb_eq_pressed := get_ui_stylebox("equip_pressed", 6, 5, 6, 3, 4)
		t.set_stylebox("normal", "EquipSlotButton", sb_eq_normal)
		t.set_stylebox("hover", "EquipSlotButton", sb_eq_hover)
		t.set_stylebox("pressed", "EquipSlotButton", sb_eq_pressed)

		var sb_line_edit := get_ui_stylebox("panel_line_edit", 8, 4, 8, 4, 4)
		t.set_stylebox("normal", "LineEdit", sb_line_edit)
		t.set_stylebox("focus", "LineEdit", sb_line_edit)

		t.set_stylebox("panel", "TabContainer", get_ui_stylebox("panel_main", 10, 8, 10, 8, 5))
		t.set_stylebox("tab_selected", "TabContainer", get_ui_stylebox("tab_selected", 12, 5, 12, 5, 4))
		t.set_stylebox("tab_unselected", "TabContainer", get_ui_stylebox("tab_unselected", 12, 5, 12, 5, 4))

		t.set_stylebox("background", "ProgressBar", get_ui_stylebox("progress_bg", 2, 2, 2, 2, 3))
		t.set_stylebox("fill", "ProgressBar", get_ui_stylebox("progress_fill_amber", 2, 1, 2, 1, 2))
		t.set_stylebox("scroll", "VScrollBar", get_ui_stylebox("scroll_bg", 4, 2, 4, 2, 3))
		t.set_stylebox("grabber", "VScrollBar", get_ui_stylebox("scroll_grabber", 2, 2, 2, 2, 3))
