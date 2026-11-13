# res://systems/particle_system.gd
extends Node2D

## 경량 CPU 픽셀 파티클 시스템 (풀링 유지 + 도트 스냅 사각형·빗줄기/물파문·HDR 발광·고디테일 데칼)

const MAX_PARTICLES: int = 500
const MAX_SPLASHES: int = 48
var quality: float = 1.0 # 0.0=끄기, 0.3=저, 0.7=중, 1.0=고
var particles: Array = []
var _pool: Array = []
var splash_rings: Array = [] # {"x": float, "y": float, "life": float, "max_life": float}
var _glow_layer: Node2D = null

func _ready() -> void:
	_glow_layer = Node2D.new()
	_glow_layer.name = "GlowLayer"
	_glow_layer.z_index = 2
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_glow_layer.material = unshaded
	_glow_layer.draw.connect(_on_glow_layer_draw)
	add_child(_glow_layer)

func _acquire_particle() -> P:
	if not _pool.is_empty():
		return _pool.pop_back()
	return P.new()

func _release_particle(p: P) -> void:
	if p and _pool.size() < MAX_PARTICLES:
		_pool.append(p)

# 색상 상수 (HDR > 1.0 값은 GlowLayer에서 WorldEnvironment 블룸과 연동)
const C_BLOOD = Color(0.71, 0.10, 0.10)
const C_FIRE_1 = Color(2.4, 1.85, 0.45)
const C_FIRE_2 = Color(2.5, 1.15, 0.25)
const C_FIRE_3 = Color(2.4, 0.65, 0.18)
const C_EMBER = Color(2.3, 1.10, 0.28)
const C_RAIN = Color(0.62, 0.78, 0.94, 0.68)
const C_SNOW = Color(0.90, 0.92, 0.96, 0.78)
const C_FOG = Color(0.65, 0.69, 0.74, 0.26)

class P:
	var x: float
	var y: float
	var vx: float
	var vy: float
	var life: float
	var max_life: float
	var size: float
	var color: Color
	var gravity: float
	var friction: float
	var fade: bool
	var shrink: bool
	var glow: bool
	var is_rain: bool = false

	func update(dt: float) -> bool:
		x += vx * dt * 60.0
		y += vy * dt * 60.0
		vy += gravity * dt * 60.0
		vx *= friction
		vy *= friction
		life -= dt
		return life > 0.0

	func get_alpha() -> float:
		if fade:
			return clampf(life / maxf(max_life, 0.001), 0.0, 1.0)
		return 1.0

	func get_size() -> float:
		if shrink:
			return maxf(1.0, size * (life / maxf(max_life, 0.001)))
		return size

const MAX_DECALS: int = 180
var decals: Array = [] # { "x": float, "y": float, "size": float, "color": Color, "life": float, "is_shell": bool, "rot": float }

func add_decal(x: float, y: float, sz: float, col: Color, is_shell: bool = false, rot: float = 0.0) -> void:
	if decals.size() >= MAX_DECALS:
		decals.pop_front()
	decals.append({
		"x": x,
		"y": y,
		"size": sz,
		"color": col,
		"life": 45.0,
		"is_shell": is_shell,
		"rot": rot
	})

func _add_rain_splash(x: float, y: float) -> void:
	if splash_rings.size() >= MAX_SPLASHES:
		splash_rings.pop_front()
	splash_rings.append({
		"x": x,
		"y": y,
		"life": 0.24,
		"max_life": 0.24
	})

func _process(delta: float) -> void:
	var i: int = particles.size() - 1
	while i >= 0:
		var p: P = particles[i]
		if not p.update(delta):
			if p.is_rain:
				_add_rain_splash(p.x, p.y)
			_release_particle(p)
			var last_idx: int = particles.size() - 1
			if i != last_idx:
				particles[i] = particles[last_idx]
			particles.pop_back()
		i -= 1

	var di: int = decals.size() - 1
	while di >= 0:
		decals[di]["life"] = float(decals[di]["life"]) - delta
		if float(decals[di]["life"]) <= 0.0:
			var last_d: int = decals.size() - 1
			if di != last_d:
				decals[di] = decals[last_d]
			decals.pop_back()
		di -= 1

	var si: int = splash_rings.size() - 1
	while si >= 0:
		splash_rings[si]["life"] = float(splash_rings[si]["life"]) - delta
		if float(splash_rings[si]["life"]) <= 0.0:
			var last_s: int = splash_rings.size() - 1
			if si != last_s:
				splash_rings[si] = splash_rings[last_s]
			splash_rings.pop_back()
		si -= 1

	if particles.size() > 0 or decals.size() > 0 or splash_rings.size() > 0:
		queue_redraw()
		if _glow_layer:
			_glow_layer.queue_redraw()

func _draw() -> void:
	# 1. 바닥 지속성 픽셀 데칼 (혈흔 다중 도트 클러스터 / 황동 2x4 탄피)
	for d in decals:
		var d_alpha := clampf(float(d["life"]) / 8.0, 0.0, 1.0) * float(d["color"].a)
		var base_col: Color = d["color"]
		var d_col := Color(base_col.r, base_col.g, base_col.b, d_alpha)
		var dx := roundf(float(d["x"]))
		var dy := roundf(float(d["y"]))
		var d_pos := Vector2(dx, dy)
		if bool(d.get("is_shell", false)):
			var d_rot := float(d.get("rot", 0.0))
			draw_set_transform(d_pos, d_rot, Vector2.ONE)
			draw_rect(Rect2(-2.0, -1.0, 4.0, 2.0), Color(0.08, 0.07, 0.05, d_alpha * 0.95))
			draw_rect(Rect2(-1.5, -0.5, 3.0, 1.0), d_col)
			draw_rect(Rect2(-1.0, -0.5, 1.0, 1.0), Color(1.0, 0.92, 0.55, d_alpha))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			var sz := maxf(2.0, roundf(float(d["size"])))
			draw_rect(Rect2(dx - sz * 0.5, dy - sz * 0.5, sz, sz), d_col)
			var dark_c := Color(base_col.r * 0.6, base_col.g * 0.6, base_col.b * 0.6, d_alpha * 0.85)
			var h := absf(sin(dx * 0.73 + dy * 1.19))
			var ox1 := 2.0 + floorf(h * 3.0)
			var oy1 := -2.0 + floorf(absf(cos(dx * 1.1 + dy * 0.5)) * 4.0)
			draw_rect(Rect2(dx + ox1, dy + oy1, 2.0, 2.0), d_col)
			draw_rect(Rect2(dx - ox1, dy - oy1 * 0.7, 2.0, 1.0), dark_c)
			draw_rect(Rect2(dx - 1.0, dy + sz * 0.4, 1.0, 1.0), dark_c)

	# 2. 빗물 바닥 물보라 픽셀 파문 (Splash Rings)
	for sp in splash_rings:
		var sp_t := 1.0 - clampf(float(sp["life"]) / maxf(float(sp["max_life"]), 0.01), 0.0, 1.0)
		var sp_a := (1.0 - sp_t) * 0.75
		var half := roundf(1.5 + sp_t * 3.5)
		var sx := roundf(float(sp["x"]))
		var sy := roundf(float(sp["y"]))
		var sp_col := Color(0.68, 0.84, 0.98, sp_a)
		draw_rect(Rect2(sx - half, sy - half * 0.65, half * 2.0, half * 1.3), sp_col, false, 1.0)

	# 3. 일반 파티클 (픽셀 스냅 Rect + 사선 빗줄기)
	for p in particles:
		if p.glow:
			continue
		var alpha: float = p.get_alpha()
		var sz := maxf(1.0, roundf(p.get_size()))
		var c := Color(p.color.r, p.color.g, p.color.b, p.color.a * alpha)
		var px := roundf(p.x)
		var py := roundf(p.y)
		if p.is_rain:
			var vel_vec := Vector2(p.vx, p.vy)
			var streak := vel_vec.normalized() * clampf(p.size * 5.0, 5.0, 11.0)
			var p2 := Vector2(px, py)
			var p1 := p2 - streak
			draw_line(p1, p2, c, 1.0)
			draw_rect(Rect2(px, py, 1.0, 2.0), Color(0.82, 0.92, 1.0, c.a))
		else:
			draw_rect(Rect2(px - floorf(sz * 0.5), py - floorf(sz * 0.5), sz, sz), c)

func _on_glow_layer_draw() -> void:
	if not _glow_layer:
		return
	for p in particles:
		if not p.glow:
			continue
		var alpha: float = p.get_alpha()
		var sz := maxf(1.0, roundf(p.get_size()))
		var c := Color(p.color.r, p.color.g, p.color.b, p.color.a * alpha)
		var px := roundf(p.x)
		var py := roundf(p.y)
		if sz >= 2.0:
			var halo_sz := sz * 2.0 + 2.0
			_glow_layer.draw_rect(Rect2(px - floorf(halo_sz * 0.5), py - floorf(halo_sz * 0.5), halo_sz, halo_sz), Color(c.r, c.g, c.b, alpha * 0.24))
		_glow_layer.draw_rect(Rect2(px - floorf(sz * 0.5), py - floorf(sz * 0.5), sz, sz), c)

func emit(preset: String, x: float, y: float, count: int = 1, angle: float = 0.0, extra: Dictionary = {}) -> void:
	if quality <= 0.0: return
	var actual_count := int(float(count) * quality)
	if actual_count <= 0: actual_count = 1

	if preset == "blood":
		add_decal(x + randf_range(-8.0, 8.0), y + randf_range(-8.0, 8.0), randf_range(3.0, 6.0), Color(0.48, 0.05, 0.05, 0.68), false)
	elif preset == "bullet_shell":
		var eject_a := angle + PI * 0.5 + randf_range(-0.35, 0.35)
		var drop_dist := randf_range(10.0, 22.0)
		add_decal(x + cos(eject_a) * drop_dist, y + sin(eject_a) * drop_dist, 2.0, Color(0.88, 0.72, 0.22, 0.88), true, randf() * TAU)

	for _i in range(actual_count):
		if particles.size() >= MAX_PARTICLES: break
		var p := _create_particle(preset, x, y, angle, extra)
		if p:
			particles.append(p)
	queue_redraw()
	if _glow_layer:
		_glow_layer.queue_redraw()

func _create_particle(preset: String, x: float, y: float, angle: float, extra: Dictionary) -> P:
	var p: P = _acquire_particle()
	p.fade = true
	p.shrink = true
	p.glow = false
	p.is_rain = false

	match preset:
		"blood":
			var a := randf() * TAU
			var spd := randf_range(1.0, 4.0)
			p.x = x; p.y = y
			p.vx = cos(a) * spd; p.vy = sin(a) * spd
			p.life = randf_range(0.3, 0.8); p.max_life = p.life
			p.size = randf_range(1.5, 3.0)
			p.color = C_BLOOD; p.gravity = 0.2; p.friction = 0.95

		"dust":
			p.x = x + randf_range(-5.0, 5.0); p.y = y + randf_range(-2.0, 2.0)
			p.vx = randf_range(-0.5, 0.5); p.vy = randf_range(-1.0, -0.3)
			p.life = randf_range(0.5, 1.2); p.max_life = p.life
			p.size = randf_range(1.5, 3.0)
			p.color = Color(0.71, 0.67, 0.59, 0.47); p.gravity = -0.02; p.friction = 0.98

		"spark":
			var a := randf() * TAU
			var spd := randf_range(2.0, 6.0)
			p.x = x; p.y = y
			p.vx = cos(a) * spd; p.vy = sin(a) * spd
			p.life = randf_range(0.2, 0.5); p.max_life = p.life
			p.size = randf_range(1.0, 2.0)
			p.color = [C_FIRE_1, C_FIRE_2, C_FIRE_3].pick_random()
			p.gravity = 0.1; p.friction = 0.90; p.glow = true

		"explosion":
			var a := randf() * TAU
			var spd := randf_range(1.5, 6.5)
			p.x = x + randf_range(-4.0, 4.0); p.y = y + randf_range(-4.0, 4.0)
			p.vx = cos(a) * spd; p.vy = sin(a) * spd
			p.life = randf_range(0.25, 0.55); p.max_life = p.life
			p.size = randf_range(3.0, 6.0)
			p.color = [C_FIRE_1, C_FIRE_2, C_FIRE_3].pick_random()
			p.gravity = 0.04; p.friction = 0.88; p.glow = true

		"smoke":
			p.x = x + randf_range(-3.0, 3.0); p.y = y
			p.vx = randf_range(-0.3, 0.3); p.vy = randf_range(-1.5, -0.5)
			p.life = randf_range(1.0, 3.0); p.max_life = p.life
			p.size = randf_range(3.0, 7.0)
			p.color = Color(0.39, 0.39, 0.43, 0.39); p.gravity = -0.01; p.friction = 0.99
			p.shrink = false

		"ember":
			var screen_w := float(extra.get("screen_w", 1280.0))
			var screen_h := float(extra.get("screen_h", 720.0))
			p.x = randf() * screen_w; p.y = screen_h + 10.0
			p.vx = randf_range(-0.3, 0.3); p.vy = randf_range(-2.0, -0.5)
			p.life = randf_range(3.0, 7.0); p.max_life = p.life
			p.size = randf_range(1.0, 3.0)
			p.color = [C_EMBER, C_FIRE_1, C_FIRE_3].pick_random()
			p.gravity = -0.005; p.friction = 0.999; p.glow = true

		"rain":
			var wind := float(extra.get("wind", 0.0))
			var span_w := float(extra.get("screen_w", 760.0))
			var span_h := float(extra.get("screen_h", 440.0))
			p.x = x + randf_range(-span_w * 0.65, span_w * 0.65)
			p.y = y + randf_range(-span_h * 0.65, span_h * 0.25)
			p.vx = wind * 0.5 + randf_range(-0.8, 0.2); p.vy = randf_range(8.0, 14.0)
			p.life = randf_range(0.35, 0.75); p.max_life = p.life
			p.size = randf_range(1.2, 2.2)
			p.color = C_RAIN; p.gravity = 0.1; p.friction = 1.0
			p.shrink = false
			p.is_rain = true

		"snow":
			var span_w := float(extra.get("screen_w", 960.0))
			var span_h := float(extra.get("screen_h", 540.0))
			p.x = x + randf_range(-span_w * 0.6, span_w * 0.6)
			p.y = y - span_h * 0.55
			p.vx = randf_range(-1.0, 1.0); p.vy = randf_range(1.0, 3.0)
			p.life = randf_range(4.0, 8.0); p.max_life = p.life
			p.size = randf_range(1.5, 3.0)
			p.color = C_SNOW; p.gravity = 0.0; p.friction = 0.99
			p.shrink = false

		"fog":
			var span_w := float(extra.get("screen_w", 960.0))
			var span_h := float(extra.get("screen_h", 540.0))
			p.x = x + randf_range(-span_w * 0.6, span_w * 0.6)
			p.y = y + randf_range(-span_h * 0.6, span_h * 0.6)
			p.vx = randf_range(-0.2, 0.2); p.vy = randf_range(-0.1, 0.1)
			p.life = randf_range(2.5, 5.0); p.max_life = p.life
			p.size = randf_range(16.0, 36.0)
			p.color = C_FOG; p.gravity = 0.0; p.friction = 0.999
			p.shrink = false

		"hit":
			var a := randf() * TAU
			var spd := randf_range(1.0, 3.0)
			p.x = x; p.y = y
			p.vx = cos(a) * spd; p.vy = sin(a) * spd
			p.life = randf_range(0.1, 0.3); p.max_life = p.life
			p.size = randf_range(2.0, 3.5)
			p.color = Color(2.4, 2.3, 1.6); p.gravity = 0.0; p.friction = 0.80
			p.glow = true

		"pickup":
			var a := randf() * TAU
			var spd := randf_range(0.5, 2.0)
			p.x = x; p.y = y
			p.vx = cos(a) * spd; p.vy = sin(a) * spd - 1.0
			p.life = randf_range(0.3, 0.8); p.max_life = p.life
			p.size = randf_range(1.5, 3.0)
			p.color = [Color(2.2, 1.9, 0.4), Color(0.4, 2.1, 1.8), Color(2.3, 1.3, 0.2)].pick_random()
			p.gravity = -0.05; p.friction = 0.95; p.glow = true

		"footstep":
			p.x = x + randf_range(-3.0, 3.0); p.y = y + randf_range(-1.0, 1.0)
			p.vx = randf_range(-0.3, 0.3); p.vy = randf_range(-0.5, -0.1)
			p.life = randf_range(0.3, 0.6); p.max_life = p.life
			p.size = randf_range(1.0, 2.0)
			p.color = Color(0.63, 0.59, 0.51, 0.31); p.gravity = -0.01; p.friction = 0.95

		"extraction":
			var a := randf_range(1.2 * PI, 1.8 * PI)
			var spd := randf_range(1.0, 3.0)
			p.x = x + randf_range(-10.0, 10.0); p.y = y + randf_range(-10.0, 10.0)
			p.vx = cos(a) * spd; p.vy = sin(a) * spd - 1.5
			p.life = randf_range(1.0, 2.0); p.max_life = p.life
			p.size = randf_range(2.0, 3.5)
			p.color = Color(0.38, 2.25, 1.95); p.gravity = -0.05; p.friction = 0.95
			p.glow = true

		"bullet_shell":
			var eject_a := angle + PI * 0.5 + randf_range(-0.35, 0.35)
			var spd := randf_range(1.5, 3.5)
			p.x = x; p.y = y
			p.vx = cos(eject_a) * spd; p.vy = sin(eject_a) * spd + randf_range(-0.5, 1.5)
			p.life = randf_range(0.4, 0.7); p.max_life = p.life
			p.size = randf_range(1.5, 2.5)
			p.color = Color(0.92, 0.76, 0.29); p.gravity = 0.15; p.friction = 0.92
			p.shrink = false

		"muzzle":
			var spread := angle + randf_range(-0.35, 0.35)
			var spd := randf_range(3.0, 7.0)
			p.x = x; p.y = y
			p.vx = cos(spread) * spd; p.vy = sin(spread) * spd
			p.life = randf_range(0.08, 0.2); p.max_life = p.life
			p.size = randf_range(1.5, 2.5)
			p.color = [Color(2.6, 2.1, 0.65), Color(2.5, 1.45, 0.25)].pick_random()
			p.gravity = 0.02; p.friction = 0.88; p.glow = true

		"slash":
			var spread := angle + randf_range(-0.52, 0.52)
			var spd := randf_range(2.0, 4.5)
			p.x = x; p.y = y
			p.vx = cos(spread) * spd; p.vy = sin(spread) * spd
			p.life = randf_range(0.12, 0.25); p.max_life = p.life
			p.size = randf_range(2.0, 3.5)
			p.color = [Color(1.4, 1.9, 2.4, 0.75), Color(2.1, 2.2, 2.5, 0.65)].pick_random()
			p.gravity = 0.0; p.friction = 0.85; p.glow = true

		_:
			_release_particle(p)
			return null

	return p

func clear() -> void:
	for p in particles:
		_release_particle(p)
	particles.clear()
	splash_rings.clear()
	queue_redraw()
	if _glow_layer:
		_glow_layer.queue_redraw()
