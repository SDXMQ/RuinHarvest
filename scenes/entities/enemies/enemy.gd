# res://scenes/entities/enemies/enemy.gd
extends CharacterBody2D

enum EnemyType { ZOMBIE, RUNNER, TANK }
enum State { IDLE, WANDER, CHASE, ATTACK, HURT, DEAD }

@export var enemy_type: EnemyType = EnemyType.ZOMBIE

var max_hp: float = 40.0
var hp: float = 40.0
var speed: float = 75.0
var damage: float = 12.0
var attack_cooldown: float = 1.0
var attack_timer: float = 0.0

var current_state: State = State.IDLE
var target_player: CharacterBody2D = null
var detection_radius: float = 240.0
var attack_radius: float = 28.0

var wander_dir: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("enemies")
	_setup_stats_by_type()

func _setup_stats_by_type() -> void:
	match enemy_type:
		EnemyType.ZOMBIE:
			max_hp = 40.0
			speed = 70.0
			damage = 12.0
		EnemyType.RUNNER:
			max_hp = 25.0
			speed = 135.0
			damage = 8.0
		EnemyType.TANK:
			max_hp = 120.0
			speed = 45.0
			damage = 25.0
	hp = max_hp

func _physics_process(delta: float) -> void:
	if hp <= 0:
		return
		
	# 플레이어 탐색
	if not is_instance_valid(target_player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target_player = players[0]
			
	attack_timer -= delta
	
	# 넉백 감쇠
	if knockback_velocity.length() > 5.0:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 500.0 * delta)
		velocity = knockback_velocity
		move_and_slide()
		return
		
	if is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		
		# 감지 범위 내 진입 시 추적
		if dist <= detection_radius:
			current_state = State.CHASE
		elif current_state == State.CHASE and dist > detection_radius * 1.5:
			current_state = State.IDLE
			
		match current_state:
			State.IDLE:
				velocity = Vector2.ZERO
				wander_timer -= delta
				if wander_timer <= 0:
					wander_timer = randf_range(2.0, 5.0)
					if randf() > 0.5:
						current_state = State.WANDER
						wander_dir = Vector2.RIGHT.rotated(randf() * TAU)
			State.WANDER:
				wander_timer -= delta
				velocity = wander_dir * (speed * 0.4)
				rotation = wander_dir.angle()
				if wander_timer <= 0:
					current_state = State.IDLE
					wander_timer = randf_range(1.0, 3.0)
			State.CHASE:
				var dir = global_position.direction_to(target_player.global_position)
				rotation = dir.angle()
				
				if dist <= attack_radius:
					velocity = Vector2.ZERO
					_try_attack()
				else:
					velocity = dir * speed
					
		move_and_slide()

func _try_attack() -> void:
	if attack_timer <= 0:
		attack_timer = attack_cooldown
		if is_instance_valid(target_player):
			EventBus.player_damaged.emit(damage, "zombie")
			if SoundManager:
				SoundManager.play("hit_melee")

func take_damage(amount: float, hit_dir: Vector2) -> void:
	hp -= amount
	current_state = State.CHASE # 피격 시 즉시 추적 모드
	knockback_velocity = hit_dir.normalized() * 180.0
	queue_redraw()
	
	# 피격 파티클 (피 + 타격 이펙트)
	var ps = get_tree().current_scene.get_node_or_null("ParticleSystem")
	if ps:
		ps.emit("blood", global_position.x, global_position.y, 6)
		ps.emit("hit", global_position.x, global_position.y, 3)
	
	if SoundManager:
		SoundManager.play("hit_melee")
		
	if hp <= 0:
		_die()

func _die() -> void:
	current_state = State.DEAD
	EventBus.enemy_killed.emit("zombie", "scav")
	
	# 드롭 아이템 (확률적 탄약, 붕대, 고철)
	# 향후 바닥 아이템 엔티티로 스폰 가능
	queue_free()

func _draw() -> void:
	var radius = 13.0
	if enemy_type == EnemyType.TANK: radius = 18.0
	elif enemy_type == EnemyType.RUNNER: radius = 11.0
	
	# 몸통 색상 (좀비 피부: 암녹색/회색)
	var body_color = Color(0.3, 0.45, 0.3)
	if enemy_type == EnemyType.RUNNER: body_color = Color(0.4, 0.3, 0.3)
	elif enemy_type == EnemyType.TANK: body_color = Color(0.2, 0.35, 0.25)
	
	# 외곽선
	draw_circle(Vector2.ZERO, radius + 2, Color(0.1, 0.1, 0.1))
	# 몸체
	draw_circle(Vector2.ZERO, radius, body_color)
	
	# 붉은 눈 (시선 방향)
	var eye_offset = Vector2(radius * 0.6, 0)
	draw_circle(eye_offset + Vector2(0, -4), 2.5, Color.RED)
	draw_circle(eye_offset + Vector2(0, 4), 2.5, Color.RED)
	
	# HP 바 (피격 시 표시)
	if hp < max_hp and hp > 0:
		var bar_w = 26.0
		var bar_h = 4.0
		var bar_pos = Vector2(-bar_w/2.0, -radius - 10)
		draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.2, 0.2, 0.2))
		var fill_w = (hp / max_hp) * bar_w
		draw_rect(Rect2(bar_pos, Vector2(fill_w, bar_h)), Color(0.9, 0.2, 0.2))
