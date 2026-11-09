# res://systems/particle_system.gd
extends Node2D

## 경량 CPU 파티클 시스템 (원본 particles.py 직접 포팅)
## 14종 프리셋 지원, _draw() 기반 렌더링

const MAX_PARTICLES: int = 500
var quality: float = 1.0 # 0.0=끄기, 0.3=저, 0.7=중, 1.0=고
var particles: Array = []
var _pool: Array = []

func _acquire_particle() -> P:
	if not _pool.is_empty():
		return _pool.pop_back()
	return P.new()

func _release_particle(p: P) -> void:
	if p and _pool.size() < MAX_PARTICLES:
		_pool.append(p)

# 색상 상수
const C_BLOOD = Color(0.71, 0.10, 0.10)
const C_FIRE_1 = Color(1.0, 0.78, 0.20)
const C_FIRE_2 = Color(1.0, 0.51, 0.12)
const C_FIRE_3 = Color(1.0, 0.31, 0.08)
const C_EMBER = Color(1.0, 0.51, 0.16)
const C_RAIN = Color(0.59, 0.71, 0.86, 0.71)
const C_SNOW = Color(0.90, 0.92, 0.96, 0.78)
const C_FOG = Color(0.71, 0.73, 0.76, 0.31)

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
			return clamp(life / max_life, 0.0, 1.0)
		return 1.0
	
	func get_size() -> float:
		if shrink:
			return max(0.5, size * (life / max_life))
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

func _process(delta: float) -> void:
	var i: int = particles.size() - 1
	while i >= 0:
		var p: P = particles[i]
		if not p.update(delta):
			_release_particle(p)
			var last_idx: int = particles.size() - 1
			if i != last_idx:
				particles[i] = particles[last_idx]
			particles.pop_back()
		i -= 1
		
	var di: int = decals.size() - 1
	while di >= 0:
		decals[di]["life"] -= delta
		if decals[di]["life"] <= 0.0:
			var last_d: int = decals.size() - 1
			if di != last_d:
				decals[di] = decals[last_d]
			decals.pop_back()
		di -= 1
	
	if particles.size() > 0 or decals.size() > 0:
		queue_redraw()

func _draw() -> void:
	# 1. 바닥 지속성 데칼 (혈흔 / 탄피)
	for d in decals:
		var d_alpha = clamp(float(d["life"]) / 8.0, 0.0, 1.0) * d["color"].a
		var d_col = Color(d["color"].r, d["color"].g, d["color"].b, d_alpha)
		var d_pos = Vector2(d["x"], d["y"])
		if d.get("is_shell", false):
			var dir = Vector2.RIGHT.rotated(d.get("rot", 0.0)) * 2.2
			draw_line(d_pos - dir, d_pos + dir, d_col, 1.8)
		else:
			draw_circle(d_pos, d["size"], d_col)

	# 2. 활성 파티클
	for p in particles:
		var alpha = p.get_alpha()
		var sz = p.get_size()
		var c = Color(p.color.r, p.color.g, p.color.b, p.color.a * alpha)
		var pos = Vector2(p.x, p.y)
		
		# 글로우 효과
		if p.glow and sz > 2.0:
			var glow_c = Color(c.r, c.g, c.b, c.a * 0.33)
			draw_circle(pos, sz * 3.0, glow_c)
		
		draw_circle(pos, sz, c)

func emit(preset: String, x: float, y: float, count: int = 1, angle: float = 0.0, extra: Dictionary = {}) -> void:
	if quality <= 0.0: return
	var actual_count = int(count * quality)
	if actual_count <= 0: actual_count = 1
	
	if preset == "blood":
		add_decal(x + randf_range(-8.0, 8.0), y + randf_range(-8.0, 8.0), randf_range(3.0, 6.5), Color(0.48, 0.05, 0.05, 0.65), false)
	elif preset == "bullet_shell":
		var eject_a = angle + PI * 0.5 + randf_range(-0.35, 0.35)
		var drop_dist = randf_range(10.0, 22.0)
		add_decal(x + cos(eject_a) * drop_dist, y + sin(eject_a) * drop_dist, 2.0, Color(0.88, 0.72, 0.22, 0.85), true, randf() * TAU)
	
	for _i in range(actual_count):
		if particles.size() >= MAX_PARTICLES: break
		var p = _create_particle(preset, x, y, angle, extra)
		if p:
			particles.append(p)
	queue_redraw()

func _create_particle(preset: String, x: float, y: float, angle: float, extra: Dictionary) -> P:
	var p: P = _acquire_particle()
	p.fade = true
	p.shrink = true
	p.glow = false
	
	match preset:
		"blood":
			var a = randf() * TAU
			var spd = randf_range(1.0, 4.0)
			p.x = x; p.y = y
			p.vx = cos(a) * spd; p.vy = sin(a) * spd
			p.life = randf_range(0.3, 0.8); p.max_life = p.life
			p.size = randf_range(1.0, 3.0)
			p.color = C_BLOOD; p.gravity = 0.2; p.friction = 0.95
		
		"dust":
			p.x = x + randf_range(-5, 5); p.y = y + randf_range(-2, 2)
			p.vx = randf_range(-0.5, 0.5); p.vy = randf_range(-1.0, -0.3)
			p.life = randf_range(0.5, 1.2); p.max_life = p.life
			p.size = randf_range(1.0, 3.0)
			p.color = Color(0.71, 0.67, 0.59, 0.47); p.gravity = -0.02; p.friction = 0.98
		
		"spark":
			var a = randf() * TAU
			var spd = randf_range(2.0, 6.0)
			p.x = x; p.y = y
			p.vx = cos(a) * spd; p.vy = sin(a) * spd
			p.life = randf_range(0.2, 0.5); p.max_life = p.life
			p.size = randf_range(1.0, 2.0)
			p.color = [C_FIRE_1, C_FIRE_2, C_FIRE_3].pick_random()
			p.gravity = 0.1; p.friction = 0.90; p.glow = true
		
		"smoke":
			p.x = x + randf_range(-3, 3); p.y = y
			p.vx = randf_range(-0.3, 0.3); p.vy = randf_range(-1.5, -0.5)
			p.life = randf_range(1.0, 3.0); p.max_life = p.life
			p.size = randf_range(3.0, 8.0)
			p.color = Color(0.39, 0.39, 0.43, 0.39); p.gravity = -0.01; p.friction = 0.99
			p.shrink = false
		
		"ember":
			var screen_w = extra.get("screen_w", 1280.0)
			var screen_h = extra.get("screen_h", 720.0)
			p.x = randf() * screen_w; p.y = screen_h + 10.0
			p.vx = randf_range(-0.3, 0.3); p.vy = randf_range(-2.0, -0.5)
			p.life = randf_range(3.0, 7.0); p.max_life = p.life
			p.size = randf_range(1.0, 3.0)
			p.color = [C_EMBER, C_FIRE_1, Color(1.0, 0.31, 0.12)].pick_random()
			p.gravity = -0.005; p.friction = 0.999; p.glow = true
		
		"rain":
			var wind = extra.get("wind", 0.0)
			var span_w = extra.get("screen_w", 960.0)
			var span_h = extra.get("screen_h", 540.0)
			p.x = x + randf_range(-span_w * 0.65, span_w * 0.65)
			p.y = y + randf_range(-span_h * 0.65, span_h * 0.25)
			p.vx = wind * 0.5 + randf_range(-0.8, 0.2); p.vy = randf_range(8.0, 14.0)
			p.life = randf_range(0.4, 0.9); p.max_life = p.life
			p.size = randf_range(1.2, 2.2)
			p.color = C_RAIN; p.gravity = 0.1; p.friction = 1.0
			p.shrink = false
		
		"snow":
			var span_w = extra.get("screen_w", 960.0)
			var span_h = extra.get("screen_h", 540.0)
			p.x = x + randf_range(-span_w * 0.6, span_w * 0.6)
			p.y = y - span_h * 0.55
			p.vx = randf_range(-1.0, 1.0); p.vy = randf_range(1.0, 3.0)
			p.life = randf_range(4.0, 8.0); p.max_life = p.life
			p.size = randf_range(1.0, 3.0)
			p.color = C_SNOW; p.gravity = 0.0; p.friction = 0.99
			p.shrink = false
		
		"fog":
			var span_w = extra.get("screen_w", 960.0)
			var span_h = extra.get("screen_h", 540.0)
			p.x = x + randf_range(-span_w * 0.6, span_w * 0.6)
			p.y = y + randf_range(-span_h * 0.6, span_h * 0.6)
			p.vx = randf_range(-0.2, 0.2); p.vy = randf_range(-0.1, 0.1)
			p.life = randf_range(2.5, 5.0); p.max_life = p.life
			p.size = randf_range(18.0, 42.0)
			p.color = C_FOG; p.gravity = 0.0; p.friction = 0.999
			p.shrink = false
		
		"hit":
			var a = randf() * TAU
			var spd = randf_range(1.0, 3.0)
			p.x = x; p.y = y
			p.vx = cos(a) * spd; p.vy = sin(a) * spd
			p.life = randf_range(0.1, 0.3); p.max_life = p.life
			p.size = randf_range(2.0, 4.0)
			p.color = Color(1.0, 1.0, 0.78); p.gravity = 0.0; p.friction = 0.80
			p.glow = true
		
		"pickup":
			var a = randf() * TAU
			var spd = randf_range(0.5, 2.0)
			p.x = x; p.y = y
			p.vx = cos(a) * spd; p.vy = sin(a) * spd - 1.0
			p.life = randf_range(0.3, 0.8); p.max_life = p.life
			p.size = randf_range(1.0, 3.0)
			p.color = [Color(1.0, 0.9, 0.2), Color(0.2, 0.9, 0.8), Color(1.0, 0.6, 0.1)].pick_random()
			p.gravity = -0.05; p.friction = 0.95; p.glow = true
		
		"footstep":
			p.x = x + randf_range(-3, 3); p.y = y + randf_range(-1, 1)
			p.vx = randf_range(-0.3, 0.3); p.vy = randf_range(-0.5, -0.1)
			p.life = randf_range(0.3, 0.6); p.max_life = p.life
			p.size = randf_range(1.0, 2.0)
			p.color = Color(0.63, 0.59, 0.51, 0.31); p.gravity = -0.01; p.friction = 0.95
		
		"extraction":
			var a = randf_range(1.2 * PI, 1.8 * PI)
			var spd = randf_range(1.0, 3.0)
			p.x = x + randf_range(-10, 10); p.y = y + randf_range(-10, 10)
			p.vx = cos(a) * spd; p.vy = sin(a) * spd - 1.5
			p.life = randf_range(1.0, 2.0); p.max_life = p.life
			p.size = randf_range(2.0, 4.0)
			p.color = Color(0.20, 0.86, 0.78); p.gravity = -0.05; p.friction = 0.95
			p.glow = true
		
		"bullet_shell":
			var eject_a = angle + PI * 0.5 + randf_range(-0.35, 0.35)
			var spd = randf_range(1.5, 3.5)
			p.x = x; p.y = y
			p.vx = cos(eject_a) * spd; p.vy = sin(eject_a) * spd + randf_range(-0.5, 1.5)
			p.life = randf_range(0.4, 0.7); p.max_life = p.life
			p.size = randf_range(1.5, 2.5)
			p.color = Color(0.92, 0.76, 0.29); p.gravity = 0.15; p.friction = 0.92
			p.shrink = false
		
		"muzzle":
			var spread = angle + randf_range(-0.35, 0.35)
			var spd = randf_range(3.0, 7.0)
			p.x = x; p.y = y
			p.vx = cos(spread) * spd; p.vy = sin(spread) * spd
			p.life = randf_range(0.08, 0.2); p.max_life = p.life
			p.size = randf_range(1.0, 2.5)
			p.color = [C_FIRE_1, Color(1.0, 0.6, 0.1)].pick_random()
			p.gravity = 0.02; p.friction = 0.88; p.glow = true
		
		"slash":
			var spread = angle + randf_range(-0.52, 0.52)
			var spd = randf_range(2.0, 4.5)
			p.x = x; p.y = y
			p.vx = cos(spread) * spd; p.vy = sin(spread) * spd
			p.life = randf_range(0.12, 0.25); p.max_life = p.life
			p.size = randf_range(2.0, 4.0)
			p.color = [Color(0.6, 0.8, 1.0, 0.6), Color(0.9, 0.95, 1.0, 0.5)].pick_random()
			p.gravity = 0.0; p.friction = 0.85; p.glow = true
		
		_:
			_release_particle(p)
			return null
	
	return p

func clear() -> void:
	for p in particles:
		_release_particle(p)
	particles.clear()
	queue_redraw()
