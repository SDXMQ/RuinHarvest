# res://scenes/world/objects/airdrop_crate.gd
extends StaticBody2D

signal crate_landed(drop_pos: Vector2)

enum DropState { FLARE_PHASE, CHUTE_FALL, LANDED_IMPACT, LOOTABLE }

var current_state: DropState = DropState.FLARE_PHASE
var state_timer: float = 0.0
var flare_timer: float = 0.0
var is_looted: bool = false
var interactable_type: Vector2i = Vector2i(-1, -1)

var col: CollisionShape2D = null

const FLARE_DURATION: float = 2.5
const FALL_DURATION: float = 3.0
const IMPACT_DURATION: float = 0.25

var fall_altitude: float = -450.0
var chute_sway: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(36, 36)
	col.shape = rect
	col.disabled = true
	add_child(col)

	current_state = DropState.FLARE_PHASE
	state_timer = 0.0
	interactable_type = Vector2i(-1, -1)

	# 1단계(FLARE_PHASE): 지면 적색 신호탄 연막 파티클/사운드
	if SoundManager:
		SoundManager.play("explosion_distant")
	var ps = get_tree().current_scene.get_node_or_null("ParticleSystem")
	if ps:
		ps.emit("smoke", global_position.x, global_position.y, 10)

func _process(delta: float) -> void:
	flare_timer += delta
	state_timer += delta

	match current_state:
		DropState.FLARE_PHASE:
			if state_timer >= FLARE_DURATION:
				current_state = DropState.CHUTE_FALL
				state_timer = 0.0
				fall_altitude = -450.0
		DropState.CHUTE_FALL:
			var t = clamp(state_timer / FALL_DURATION, 0.0, 1.0)
			fall_altitude = lerp(-450.0, 0.0, t)
			chute_sway = sin(state_timer * 3.5) * 12.0 * (1.0 - t * 0.4)
			if state_timer >= FALL_DURATION:
				current_state = DropState.LANDED_IMPACT
				state_timer = 0.0
				fall_altitude = 0.0
				chute_sway = 0.0
				crate_landed.emit(global_position)

				# 3단계(LANDED_IMPACT): 지면 충돌 사운드, 착지 먼지 파티클, 카메라 쉐이크
				if SoundManager:
					SoundManager.play("hit_melee")
				var ps = get_tree().current_scene.get_node_or_null("ParticleSystem")
				if ps:
					ps.emit("dust", global_position.x, global_position.y, 14)
				if EventBus.has_signal("camera_shake_requested"):
					EventBus.camera_shake_requested.emit(6.0, 0.4)
		DropState.LANDED_IMPACT:
			if state_timer >= IMPACT_DURATION:
				# 4단계(LOOTABLE): 낙하산 쓰러짐, 충돌체/상호작용 프롬프트 활성화
				current_state = DropState.LOOTABLE
				state_timer = 0.0
				if col:
					col.disabled = false
				collision_layer = 1
				interactable_type = Vector2i(7, 2)
		DropState.LOOTABLE:
			pass

	queue_redraw()

func _draw() -> void:
	var flare_pos = Vector2(22, 14)
	_draw_flare_and_smoke(flare_pos)

	match current_state:
		DropState.FLARE_PHASE:
			# 1단계: 지면 착지 지점 적색 신호탄 표식 및 연막
			draw_line(Vector2(-14, 0), Vector2(14, 0), Color(0.9, 0.2, 0.1, 0.7), 1.5)
			draw_line(Vector2(0, -14), Vector2(0, 14), Color(0.9, 0.2, 0.1, 0.7), 1.5)
			draw_arc(Vector2.ZERO, 18.0, 0, TAU, 16, Color(1.0, 0.25, 0.15, 0.45), 1.2)

		DropState.CHUTE_FALL:
			# 2단계: 지면 원형 그림자 확대 및 상공 Y:-450px 낙하산 전개 강하
			var t = clamp(state_timer / FALL_DURATION, 0.0, 1.0)
			var shadow_radius = lerp(4.0, 24.0, t)
			var shadow_alpha = lerp(0.2, 0.6, t)
			draw_circle(Vector2.ZERO, shadow_radius, Color(0, 0, 0, shadow_alpha))

			var crate_center = Vector2(chute_sway, fall_altitude)

			# 낙하산 줄
			var chute_apex = crate_center + Vector2(0, -60)
			draw_line(crate_center + Vector2(-16, -16), chute_apex + Vector2(-36, 12), Color(0.8, 0.8, 0.75, 0.7), 1.2)
			draw_line(crate_center + Vector2(16, -16), chute_apex + Vector2(36, 12), Color(0.8, 0.8, 0.75, 0.7), 1.2)
			draw_line(crate_center + Vector2(-8, -16), chute_apex + Vector2(-12, 10), Color(0.8, 0.8, 0.75, 0.7), 1.0)
			draw_line(crate_center + Vector2(8, -16), chute_apex + Vector2(12, 10), Color(0.8, 0.8, 0.75, 0.7), 1.0)

			# 전개된 낙하산 돔
			var dome_pts = PackedVector2Array([
				chute_apex + Vector2(-42, 12),
				chute_apex + Vector2(-34, -16),
				chute_apex + Vector2(-16, -30),
				chute_apex + Vector2(16, -30),
				chute_apex + Vector2(34, -16),
				chute_apex + Vector2(42, 12),
				chute_apex + Vector2(24, 6),
				chute_apex + Vector2(0, 8),
				chute_apex + Vector2(-24, 6)
			])
			draw_colored_polygon(dome_pts, Color(0.32, 0.38, 0.26, 0.95))
			draw_line(chute_apex + Vector2(-16, -30), chute_apex + Vector2(-12, 10), Color(0.45, 0.52, 0.36), 2.0)
			draw_line(chute_apex + Vector2(16, -30), chute_apex + Vector2(12, 10), Color(0.45, 0.52, 0.36), 2.0)

			_draw_crate_body(crate_center)

		DropState.LANDED_IMPACT:
			# 3단계: 지면 충돌 순간
			draw_rect(Rect2(-24, -20, 48, 40), Color(0, 0, 0, 0.6))
			var impact_chute = PackedVector2Array([
				Vector2(-18, -14), Vector2(-36, -24), Vector2(-12, -32),
				Vector2(14, -28), Vector2(32, -18), Vector2(18, -14)
			])
			draw_colored_polygon(impact_chute, Color(0.32, 0.38, 0.26, 0.9))
			_draw_crate_body(Vector2.ZERO)

		DropState.LOOTABLE:
			# 4단계: 낙하산 쓰러짐, 지면 박스 루팅 가능
			var chute_pts = PackedVector2Array([
				Vector2(-18, -14), Vector2(-36, -34), Vector2(-12, -42),
				Vector2(14, -38), Vector2(32, -26), Vector2(18, -14)
			])
			draw_colored_polygon(chute_pts, Color(0.32, 0.38, 0.26, 0.85))
			draw_line(Vector2(-14, -14), Vector2(-28, -32), Color(0.7, 0.7, 0.6, 0.6), 1.0)
			draw_line(Vector2(14, -14), Vector2(24, -26), Color(0.7, 0.7, 0.6, 0.6), 1.0)

			# 지면 그림자
			draw_rect(Rect2(-20, -16, 40, 36), Color(0, 0, 0, 0.5))

			_draw_crate_body(Vector2.ZERO)

func _draw_crate_body(offset: Vector2) -> void:
	# 군용 컨테이너 본체
	draw_rect(Rect2(offset.x - 18, offset.y - 18, 36, 36), Color(0.12, 0.14, 0.10))
	draw_rect(Rect2(offset.x - 16, offset.y - 16, 32, 32), Color(0.24, 0.32, 0.20))

	# 철제 보강 프레임 및 노란색 UN/군수 마킹
	draw_rect(Rect2(offset.x - 16, offset.y - 4, 32, 8), Color(0.18, 0.22, 0.15))
	draw_rect(Rect2(offset.x - 4, offset.y - 16, 8, 32), Color(0.18, 0.22, 0.15))
	draw_rect(Rect2(offset.x - 8, offset.y - 8, 16, 16), Color(0.85, 0.68, 0.15), false, 2.0)

func _draw_flare_and_smoke(flare_pos: Vector2) -> void:
	# 붉은색 신호탄 플레어 및 연기 애니메이션
	var pulse = 0.6 + 0.4 * sin(flare_timer * 6.0)
	draw_circle(flare_pos, 4.0, Color(0.9, 0.2, 0.1))
	draw_circle(flare_pos, 10.0 * pulse, Color(1.0, 0.25, 0.15, 0.45 * pulse))
	draw_circle(flare_pos, 20.0 * pulse, Color(1.0, 0.15, 0.1, 0.2 * pulse))

	# 피어오르는 붉은 연막 원들
	for i in range(3):
		var t = fmod(flare_timer * 0.8 + float(i) * 0.33, 1.0)
		var smoke_pos = flare_pos + Vector2(sin(flare_timer * 2.0 + i) * 8.0 * t, -t * 32.0)
		var smoke_alpha = (1.0 - t) * 0.45
		draw_circle(smoke_pos, 5.0 + t * 10.0, Color(0.95, 0.25, 0.2, smoke_alpha))
