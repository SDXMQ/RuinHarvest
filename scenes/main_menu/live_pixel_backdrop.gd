# res://scenes/main_menu/live_pixel_backdrop.gd
extends Control
class_name LivePixelBackdrop

## 메인 메뉴 전용 4px 도트 그리드 라이브 아포칼립스 배경 (폐허·안개·빗줄기·불씨·탐조등·번개)

const PX: float = 4.0

var elapsed: float = 0.0
var lightning_timer: float = 4.2
var lightning_flash: float = 0.0
var lightning_x_ratio: float = 0.24

var raindrops: Array[Dictionary] = []
var embers: Array[Dictionary] = []
var puddles: Array[Dictionary] = []
var fog_strips: Array[Dictionary] = []
var skyline_blocks: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_init_backdrop_state()

func _init_backdrop_state() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261113

	# 1. 원경 폐허 빌딩 실루엣 (결정론적 생성)
	skyline_blocks.clear()
	var x_cur: int = 0
	while x_cur < 340:
		var bw: int = rng.randi_range(10, 22)
		var near_center: bool = (x_cur > 100 and x_cur < 220)
		var bh: int = rng.randi_range(26, 46) if near_center else rng.randi_range(38, 86)
		var roof_style: int = rng.randi_range(0, 2)
		var lit_windows: Array[Vector2i] = []
		var win_cols: int = maxi(1, (bw - 4) / 4)
		var win_rows: int = maxi(1, (bh - 10) / 6)
		for wr in range(win_rows):
			for wc in range(win_cols):
				if rng.randf() < 0.14:
					lit_windows.append(Vector2i(2 + wc * 4, 6 + wr * 6))
		skyline_blocks.append({
			"x": x_cur,
			"w": bw,
			"h": bh,
			"roof": roof_style,
			"has_spire": rng.randf() < 0.35,
			"wins": lit_windows,
			"phase": rng.randf() * TAU
		})
		x_cur += bw + rng.randi_range(-2, 3)

	# 2. 안개 띠 초기화
	fog_strips.clear()
	for i in range(6):
		fog_strips.append({
			"x": rng.randf_range(0.0, 320.0),
			"y": float(108 + i * 7 + rng.randi_range(-2, 2)),
			"w": float(rng.randi_range(44, 96)),
			"h": float(rng.randi_range(2, 4)),
			"spd": rng.randf_range(2.4, 5.8),
			"alpha": rng.randf_range(0.055, 0.11)
		})

	# 3. 빗줄기 풀 초기화 (320x180 가상 도트 좌표계)
	raindrops.clear()
	for _i in range(72):
		raindrops.append({
			"x": rng.randf_range(0.0, 360.0),
			"y": rng.randf_range(-20.0, 178.0),
			"spd": rng.randf_range(95.0, 145.0),
			"len": rng.randi_range(3, 5),
			"alpha": rng.randf_range(0.30, 0.55)
		})

	# 4. 드럼통 모닥불 불씨 풀 초기화 (좌측 전경 gx~80 근방)
	embers.clear()
	for _i in range(28):
		embers.append(_spawn_ember(rng, true))

	puddles.clear()

func _spawn_ember(rng: RandomNumberGenerator, random_height: bool = false) -> Dictionary:
	var life: float = rng.randf_range(2.0, 4.2)
	var age: float = rng.randf_range(0.0, life * 0.85) if random_height else 0.0
	return {
		"x": 80.0 + rng.randf_range(-4.0, 4.0) - age * rng.randf_range(-2.0, 5.0),
		"y": 135.0 - age * rng.randf_range(12.0, 22.0),
		"vx": rng.randf_range(-3.5, 4.5),
		"vy": -rng.randf_range(12.0, 22.0),
		"life": life - age,
		"max_life": life,
		"phase": rng.randf() * TAU
	}

func _process(delta: float) -> void:
	elapsed += delta

	# 간헐적 원경 번개 타이머
	lightning_timer -= delta
	if lightning_timer <= 0.0:
		lightning_flash = 1.0
		lightning_timer = randf_range(6.5, 13.5)
		lightning_x_ratio = 0.18 if randf() < 0.5 else 0.82
	elif lightning_flash > 0.0:
		lightning_flash = maxf(0.0, lightning_flash - delta * 2.8)

	# 안개 이동
	for f in fog_strips:
		f["x"] = float(f["x"]) + float(f["spd"]) * delta
		if float(f["x"]) > 340.0:
			f["x"] = -float(f["w"]) - 8.0

	# 사선 빗줄기 낙하 및 물웅덩이 파문 생성
	for r in raindrops:
		var spd: float = float(r["spd"])
		r["x"] = float(r["x"]) - spd * 0.16 * delta
		r["y"] = float(r["y"]) + spd * delta
		if float(r["y"]) > 176.0 or float(r["x"]) < -12.0:
			if float(r["y"]) >= 152.0 and puddles.size() < 16 and randf() < 0.25:
				puddles.append({
					"x": float(r["x"]),
					"y": randf_range(153.0, 174.0),
					"life": 0.36,
					"max_life": 0.36
				})
			r["x"] = randf_range(0.0, 355.0)
			r["y"] = randf_range(-18.0, -2.0)

	# 빗물 파문 감소
	var pi: int = puddles.size() - 1
	while pi >= 0:
		puddles[pi]["life"] = float(puddles[pi]["life"]) - delta
		if float(puddles[pi]["life"]) <= 0.0:
			puddles.remove_at(pi)
		pi -= 1

	# 드럼통 불씨 상승
	for e in embers:
		e["life"] = float(e["life"]) - delta
		var wave := sin(elapsed * 3.5 + float(e["phase"])) * 4.5
		e["x"] = float(e["x"]) + (float(e["vx"]) + wave) * delta
		e["y"] = float(e["y"]) + float(e["vy"]) * delta
		if float(e["life"]) <= 0.0 or float(e["y"]) < 12.0:
			var max_l := randf_range(2.2, 4.4)
			e["x"] = 80.0 + randf_range(-3.0, 3.0)
			e["y"] = 135.0
			e["vx"] = randf_range(-3.5, 4.0)
			e["vy"] = -randf_range(12.0, 22.0)
			e["life"] = max_l
			e["max_life"] = max_l

	queue_redraw()

func _prect(gx: float, gy: float, gw_cell: float, gh_cell: float, col: Color) -> void:
	draw_rect(Rect2(floorf(gx) * PX, floorf(gy) * PX, floorf(gw_cell) * PX, floorf(gh_cell) * PX), col)

func _pline(gx1: float, gy1: float, gx2: float, gy2: float, col: Color, thick_cells: float = 1.0) -> void:
	var steps := int(maxf(absf(gx2 - gx1), absf(gy2 - gy1)))
	if steps <= 0:
		_prect(gx1, gy1, thick_cells, thick_cells, col)
		return
	for s in range(steps + 1):
		var t := float(s) / float(steps)
		var cx := lerpf(gx1, gx2, t)
		var cy := lerpf(gy1, gy2, t)
		_prect(cx, cy, thick_cells, thick_cells, col)

func _draw() -> void:
	var view_size := size
	var gw: int = maxi(160, int(ceilf(view_size.x / PX)))
	var gh: int = maxi(90, int(ceilf(view_size.y / PX)))
	var gscale_x: float = float(gw) / 320.0
	var gscale_y: float = float(gh) / 180.0

	# === 1. 밤·폭풍 밴드 스카이 + 디더링 ===
	var sky_bands: Array[Color] = [
		Color(0.024, 0.030, 0.048),
		Color(0.036, 0.047, 0.072),
		Color(0.052, 0.066, 0.098),
		Color(0.074, 0.084, 0.114),
		Color(0.096, 0.088, 0.104)
	]
	var flash_add := lightning_flash * 0.18
	for b in range(5):
		var y0 := int(float(b) * 26.0 * gscale_y)
		var bh := int(28.0 * gscale_y) + 2
		var sc: Color = sky_bands[b] + Color(flash_add * 0.7, flash_add * 0.85, flash_add * 1.15, 0.0)
		_prect(0.0, float(y0), float(gw + 2), float(bh), sc)
		if b > 0:
			# 1px 픽셀 체커보드 디더링 경계
			for dx in range(0, gw, 2):
				_prect(float(dx), float(y0), 1.0, 1.0, sky_bands[b - 1])

	# 상단 별빛 점멸
	for st in range(14):
		var sx := float((st * 37 + 19) % gw)
		var sy := float(3 + ((st * 13 + 7) % 18))
		var tw := 0.25 + 0.35 * sin(elapsed * 1.8 + float(st))
		if tw > 0.35:
			_prect(sx, sy, 1.0, 1.0, Color(0.75, 0.84, 0.96, tw * (1.0 - lightning_flash * 0.7)))

	# 번개 섬광 볼트 & 먹구름
	if lightning_flash > 0.52:
		var lx := float(int(float(gw) * lightning_x_ratio))
		var ly: int = 2
		while ly < int(76.0 * gscale_y):
			var next_lx := lx + float(((ly * 7) % 5) - 2)
			_pline(lx, float(ly), next_lx, float(ly + 6), Color(0.78, 0.90, 1.0, lightning_flash * 0.92), 1.0)
			lx = next_lx
			ly += 6

	for c_idx in range(5):
		var cx := fposmod(float(c_idx * 74) + elapsed * (1.2 + float(c_idx) * 0.25), float(gw + 80)) - 60.0
		var cy := float(10 + (c_idx % 3) * 9)
		var cw := float(36 + (c_idx % 2) * 14)
		var cloud_base := Color(0.068, 0.086, 0.122, 0.94)
		var cloud_rim := Color(0.115, 0.145, 0.205, 0.85)
		_prect(cx, cy, cw, 6.0, cloud_base)
		_prect(cx + 6.0, cy - 3.0, cw - 12.0, 3.0, cloud_base)
		_prect(cx + 8.0, cy - 3.0, cw - 16.0, 1.0, cloud_rim)
		if lightning_flash > 0.05:
			_prect(cx + 4.0, cy + 5.0, cw - 8.0, 1.0, Color(0.55, 0.74, 0.98, lightning_flash * 0.65))

	# === 2. 원경 감시탑 탐조등(Searchlight) 스윕 ===
	var origin_gx := 248.0 * gscale_x
	var origin_gy := 66.0 * gscale_y
	var sweep_ang := -2.18 + sin(elapsed * 0.38) * 0.36
	var beam_dir := Vector2(cos(sweep_ang), sin(sweep_ang))
	var step_count: int = 48
	for s in range(1, step_count):
		var t := float(s) / float(step_count)
		var bx := origin_gx + beam_dir.x * t * 92.0 * gscale_x
		var by := origin_gy + beam_dir.y * t * 92.0 * gscale_y
		var rad := 2.0 + t * 8.0
		var ba := (1.0 - t * 0.85) * 0.055
		_prect(bx - rad * 0.5, by - rad * 0.5, rad, rad, Color(0.62, 0.76, 0.86, ba))

	# === 3. 원경 폐허 빌딩 실루엣 + 라디오 송전탑 + 창문 불빛 ===
	var base_horizon_y := floorf(148.0 * gscale_y)
	var bldg_col := Color(0.032, 0.038, 0.052).lerp(Color(0.09, 0.11, 0.15), lightning_flash * 0.45)
	var bldg_rim := Color(0.06, 0.07, 0.095).lerp(Color(0.28, 0.36, 0.48), lightning_flash * 0.6)
	for blk in skyline_blocks:
		var bx := float(blk["x"]) * gscale_x
		var bw := float(blk["w"]) * gscale_x
		var bh := float(blk["h"]) * gscale_y
		var by := base_horizon_y - bh
		_prect(bx, by, bw, bh, bldg_col)
		_prect(bx, by, bw, 1.0, bldg_rim)
		if int(blk["roof"]) == 1:
			_prect(bx + 2.0, by - 4.0, bw * 0.5, 4.0, bldg_col)
		elif int(blk["roof"]) == 2:
			_prect(bx + bw * 0.25, by - 5.0, 2.0, 5.0, bldg_col)
		if bool(blk["has_spire"]):
			_prect(bx + bw * 0.7, by - 7.0, 1.0, 7.0, bldg_rim)
		var wins: Array = blk["wins"]
		var flk := 0.65 + 0.35 * sin(elapsed * 2.4 + float(blk["phase"]))
		for wv in wins:
			var win_pos: Vector2i = wv
			if flk > 0.42:
				_prect(bx + float(win_pos.x), by + float(win_pos.y), 2.0, 2.0, Color(0.88, 0.52, 0.18, 0.42 * flk))

	# 좌측 폐허 라디오 송전탑 + 점멸 적색 항공 비콘
	var twr_x := floorf(66.0 * gscale_x)
	var twr_top := floorf(20.0 * gscale_y)
	var twr_bot := floorf(108.0 * gscale_y)
	_pline(twr_x - 3.0, twr_bot, twr_x, twr_top + 6.0, Color(0.055, 0.065, 0.085), 1.0)
	_pline(twr_x + 3.0, twr_bot, twr_x, twr_top + 6.0, Color(0.055, 0.065, 0.085), 1.0)
	for cross_y in range(int(twr_top + 14.0), int(twr_bot), 10):
		var spread := lerpf(1.0, 3.0, float(cross_y - twr_top) / maxf(1.0, twr_bot - twr_top))
		_prect(twr_x - spread, float(cross_y), spread * 2.0 + 1.0, 1.0, Color(0.06, 0.072, 0.095))
	_prect(twr_x, twr_top, 1.0, 7.0, Color(0.10, 0.12, 0.15))
	var beacon_pulse := clampf(sin(elapsed * 2.2) * 0.7 + 0.5, 0.1, 1.0)
	_prect(twr_x - 1.0, twr_top - 2.0, 3.0, 3.0, Color(0.95, 0.22, 0.16, 0.26 * beacon_pulse))
	_prect(twr_x, twr_top - 1.0, 1.0, 1.0, Color(1.0, 0.32, 0.22, beacon_pulse))

	# === 4. 전신주 & 늘어진 전선 케이블 ===
	var pole_l_x := floorf(38.0 * gscale_x)
	var pole_l_y := floorf(70.0 * gscale_y)
	var pole_r_x := floorf(280.0 * gscale_x)
	var pole_r_y := floorf(66.0 * gscale_y)
	var pole_col := Color(0.045, 0.052, 0.068)
	_prect(pole_l_x, pole_l_y, 2.0, 82.0 * gscale_y, pole_col)
	_prect(pole_l_x - 5.0, pole_l_y + 4.0, 12.0, 2.0, pole_col)
	_prect(pole_l_x - 4.0, pole_l_y + 10.0, 10.0, 1.0, pole_col)
	_prect(pole_r_x, pole_r_y, 2.0, 86.0 * gscale_y, pole_col)
	_prect(pole_r_x - 5.0, pole_r_y + 4.0, 12.0, 2.0, pole_col)
	_prect(pole_r_x - 4.0, pole_r_y + 10.0, 10.0, 1.0, pole_col)

	_draw_catenary_wire(-2.0, pole_l_y + 6.0, pole_l_x - 4.0, pole_l_y + 4.0, 5.0, pole_col)
	_draw_catenary_wire(pole_l_x + 6.0, pole_l_y + 4.0, pole_r_x - 4.0, pole_r_y + 4.0, 14.0, pole_col)
	_draw_catenary_wire(pole_l_x + 5.0, pole_l_y + 10.0, pole_r_x - 3.0, pole_r_y + 10.0, 16.0, pole_col)
	_draw_catenary_wire(pole_r_x + 6.0, pole_r_y + 4.0, float(gw + 2), pole_r_y - 2.0, 4.0, pole_col)
	# 바람에 흔들리는 끊어진 전선
	var sway := sin(elapsed * 2.1) * 2.5
	_draw_catenary_wire(pole_l_x - 4.0, pole_l_y + 10.0, pole_l_x - 9.0 + sway, pole_l_y + 34.0, 3.0, Color(0.07, 0.08, 0.10))

	# === 5. 천천히 흐르는 픽셀 안개띠 ===
	for f in fog_strips:
		var fx := float(f["x"]) * gscale_x
		var fy := float(f["y"]) * gscale_y
		var fw := float(f["w"]) * gscale_x
		var fh := float(f["h"])
		var fa := float(f["alpha"])
		_prect(fx, fy, fw, fh, Color(0.38, 0.48, 0.58, fa))
		_prect(fx + 8.0, fy - 1.0, fw * 0.6, 1.0, Color(0.42, 0.52, 0.62, fa * 0.55))

	# === 6. 좌측 전경 폐허 검문소 벽체 & 드럼통 모닥불 ===
	var fire_flicker := 0.80 + 0.20 * sin(elapsed * 11.3) * cos(elapsed * 7.1)
	# 좌측 무너진 벽돌담
	var wall_col := Color(0.055, 0.048, 0.054)
	var wall_hi := Color(0.11, 0.09, 0.085)
	_prect(0.0, 102.0 * gscale_y, 34.0 * gscale_x, 52.0 * gscale_y, wall_col)
	_prect(34.0 * gscale_x, 120.0 * gscale_y, 20.0 * gscale_x, 34.0 * gscale_y, wall_col)
	# 벽체 파손 상단 요철 및 모닥불 주황빛 반사 하이라이트
	_prect(0.0, 99.0 * gscale_y, 18.0 * gscale_x, 3.0, wall_col)
	_prect(22.0 * gscale_x, 100.0 * gscale_y, 8.0 * gscale_x, 2.0, wall_col)
	for br_y in range(106, 150, 4):
		for br_x in range(4, 50, 6):
			if br_x >= 34 and br_y < 122:
				continue
			var fire_dist := absf(float(br_x) - 78.0)
			var warm_w := clampf(1.0 - fire_dist / 58.0, 0.0, 1.0) * fire_flicker
			var brick_c := wall_hi.lerp(Color(0.58, 0.28, 0.12), warm_w * 0.45)
			_prect(float(br_x + ((br_y / 4) % 2) * 3) * gscale_x, float(br_y) * gscale_y, 4.0, 2.0, brick_c)
	# 모래주머니 바리케이드
	for sb in range(4):
		_prect((46.0 + float(sb) * 6.0) * gscale_x, 144.0 * gscale_y, 5.0, 4.0, Color(0.18, 0.14, 0.11))
		if sb < 3:
			_prect((49.0 + float(sb) * 6.0) * gscale_x, 140.0 * gscale_y, 5.0, 4.0, Color(0.22, 0.16, 0.12))

	# 드럼통 화톳불 (gx = 76..84, gy = 136..152)
	var b_x := floorf(76.0 * gscale_x)
	var b_y := floorf(137.0 * gscale_y)
	# 불빛 헤일로 (부드러운 도트 다단 발광)
	_prect(b_x - 14.0, b_y - 16.0, 36.0, 34.0, Color(0.95, 0.42, 0.12, 0.06 * fire_flicker))
	_prect(b_x - 7.0, b_y - 10.0, 22.0, 22.0, Color(1.0, 0.55, 0.16, 0.11 * fire_flicker))
	# 모닥불 불꽃 (외부 적주황 -> 내부 금황색)
	var f_h := 4.0 + roundf(sin(elapsed * 14.0) * 1.5 + 1.5)
	_prect(b_x + 1.0, b_y - f_h, 6.0, f_h, Color(0.92, 0.34, 0.08))
	_prect(b_x + 2.0, b_y - f_h + 1.0, 4.0, f_h - 1.0, Color(0.98, 0.65, 0.16))
	_prect(b_x + 3.0, b_y - 2.0, 2.0, 2.0, Color(1.0, 0.92, 0.52))
	# 드럼통 본체
	_prect(b_x, b_y, 8.0, 15.0, Color(0.16, 0.11, 0.10))
	_prect(b_x + 1.0, b_y + 1.0, 2.0, 13.0, Color(0.32, 0.18, 0.13))
	_prect(b_x, b_y + 5.0, 8.0, 1.0, Color(0.08, 0.06, 0.06))
	_prect(b_x, b_y + 10.0, 8.0, 1.0, Color(0.08, 0.06, 0.06))

	# === 7. 우측 전경 붕괴 건물 코너 + 나트륨 가로등 & 차단봉 ===
	var rw_x := floorf(248.0 * gscale_x)
	var rw_y := floorf(84.0 * gscale_y)
	_prect(rw_x, rw_y, float(gw) - rw_x + 2.0, base_horizon_y - rw_y + 4.0, Color(0.048, 0.052, 0.068))
	_prect(rw_x, rw_y, 2.0, base_horizon_y - rw_y, Color(0.09, 0.10, 0.125))
	# 깨진 창문 프레임 2개
	for row_w in range(2):
		var wy := rw_y + 12.0 + float(row_w) * 20.0
		_prect(rw_x + 10.0, wy, 12.0, 14.0, Color(0.02, 0.025, 0.035))
		_prect(rw_x + 10.0, wy, 12.0, 1.0, Color(0.11, 0.13, 0.16))
		_prect(rw_x + 11.0, wy + 13.0, 4.0, 1.0, Color(0.35, 0.45, 0.55, 0.45)) # 깨진 유리 조각
	# 경고 차단 바리케이드 (gx = 226..244)
	var bar_x := floorf(226.0 * gscale_x)
	var bar_y := floorf(145.0 * gscale_y)
	_prect(bar_x, bar_y, 18.0, 4.0, Color(0.16, 0.17, 0.20))
	for chv in range(3):
		_prect(bar_x + 2.0 + float(chv) * 6.0, bar_y + 1.0, 3.0, 2.0, Color(0.84, 0.60, 0.16))
	_prect(bar_x + 2.0, bar_y + 4.0, 2.0, 4.0, Color(0.09, 0.10, 0.12))
	_prect(bar_x + 14.0, bar_y + 4.0, 2.0, 4.0, Color(0.09, 0.10, 0.12))

	# 우측 점멸 나트륨 가로등
	var lamp_x := rw_x - 8.0
	var lamp_y := rw_y + 6.0
	_prect(rw_x - 8.0, lamp_y, 9.0, 2.0, Color(0.12, 0.14, 0.18))
	var lamp_on := 1.0 if sin(elapsed * 8.7) > -0.82 else 0.25
	_prect(lamp_x, lamp_y + 2.0, 3.0, 2.0, Color(0.96, 0.72, 0.28, lamp_on))
	for cone in range(1, 7):
		var cy := lamp_y + 4.0 + float(cone) * 9.0
		var cw := 4.0 + float(cone) * 5.0
		_prect(lamp_x + 1.0 - cw * 0.5, cy, cw, 9.0, Color(0.92, 0.66, 0.24, 0.045 * lamp_on * (1.0 - float(cone) / 8.0)))

	# === 8. 하단 젖은 아스팔트 도로 + 웅덩이 빛 반사 + 빗물 파문 ===
	var road_y := base_horizon_y
	var road_h := float(gh) - road_y + 2.0
	_prect(0.0, road_y, float(gw + 2), road_h, Color(0.025, 0.030, 0.040))
	_prect(0.0, road_y, float(gw + 2), 2.0, Color(0.055, 0.064, 0.080)) # 연석
	for dash_x in range(8, gw, 26):
		_prect(float(dash_x), road_y + 14.0 * gscale_y, 12.0, 2.0, Color(0.28, 0.24, 0.12, 0.45))

	# 모닥불 & 가로등 젖은 노면 픽셀 반사띠
	for ref_i in range(6):
		var ry := road_y + 4.0 + float(ref_i) * 3.0
		var rx_jit := roundf(sin(elapsed * 5.0 + float(ref_i)) * 1.5)
		_prect(b_x + 1.0 + rx_jit, ry, 6.0 - float(ref_i) * 0.4, 1.0, Color(0.95, 0.48, 0.14, 0.22 * fire_flicker * (1.0 - float(ref_i) * 0.14)))
		_prect(lamp_x - 3.0 - rx_jit, ry, 8.0 - float(ref_i) * 0.5, 1.0, Color(0.92, 0.68, 0.26, 0.14 * lamp_on * (1.0 - float(ref_i) * 0.14)))

	# 웅덩이 빗물 파문
	for p in puddles:
		var t := 1.0 - clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0)
		var pa := (1.0 - t) * 0.48
		var rx := floorf(float(p["x"]) * gscale_x)
		var ry := floorf(float(p["y"]) * gscale_y)
		var w_r := 1.0 + floorf(t * 3.0)
		_prect(rx - w_r, ry, w_r * 2.0 + 1.0, 1.0, Color(0.55, 0.75, 0.92, pa))

	# === 9. 좌/우 하단 철조망 실루엣 ===
	var wire_col := Color(0.02, 0.025, 0.032, 0.92)
	var side_ends: Array[int] = [58, gw - 58]
	for side_end in side_ends:
		var x_start: int = 0 if side_end == 58 else side_end
		var x_stop: int = 58 if side_end == 58 else gw
		var post_step: int = 18
		for px_i in range(x_start + 8, x_stop, post_step):
			_prect(float(px_i), float(gh) - 20.0, 1.0, 20.0, wire_col)
		_draw_catenary_wire(float(x_start), float(gh) - 16.0, float(x_stop), float(gh) - 16.0, 2.0, wire_col)
		_draw_catenary_wire(float(x_start), float(gh) - 9.0, float(x_stop), float(gh) - 9.0, 2.0, wire_col)
		for barb_x in range(x_start + 4, x_stop, 9):
			_prect(float(barb_x), float(gh) - 15.0, 2.0, 1.0, wire_col)
			_prect(float(barb_x + 3), float(gh) - 9.0, 2.0, 1.0, wire_col)

	# === 10. 불씨 & 사선 빗줄기 전경 ===
	for e in embers:
		var life_t := clampf(float(e["life"]) / maxf(0.1, float(e["max_life"])), 0.0, 1.0)
		var ex := floorf(float(e["x"]) * gscale_x)
		var ey := floorf(float(e["y"]) * gscale_y)
		var ecol := Color(1.0, 0.85, 0.35, life_t) if life_t > 0.55 else Color(0.96, 0.38, 0.10, life_t * 0.9)
		_prect(ex, ey, 1.0, 1.0, ecol)

	for r in raindrops:
		var rx := floorf(float(r["x"]) * gscale_x)
		var ry := floorf(float(r["y"]) * gscale_y)
		var rlen := int(r["len"])
		var ra := float(r["alpha"])
		for seg in range(rlen):
			var sx := rx + floorf(float(seg) * 0.35)
			var sy := ry - float(seg)
			_prect(sx, sy, 1.0, 1.0, Color(0.62, 0.78, 0.94, ra * (1.0 - float(seg) / float(rlen + 1))))

func _draw_catenary_wire(x1: float, y1: float, x2: float, y2: float, sag: float, col: Color) -> void:
	var steps := int(maxf(8.0, absf(x2 - x1) * 0.5))
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var wx := lerpf(x1, x2, t)
		var wy := lerpf(y1, y2, t) + 4.0 * t * (1.0 - t) * sag
		_prect(wx, wy, 1.0, 1.0, col)
