extends Node2D
class_name PlayerVisuals

var hit_flash_tween: Tween
@onready var player = get_parent()

func _ready() -> void:
	if EventBus.has_signal("player_damaged"):
		EventBus.player_damaged.connect(_on_player_damaged)

func _process(delta: float) -> void:
	queue_redraw()

func _on_player_damaged(amount: float, source: String) -> void:
	if hit_flash_tween: hit_flash_tween.kill()
	hit_flash_tween = create_tween()
	if material:
		material.set_shader_parameter("flash_color", Color(1, 0, 0, 1))
		material.set_shader_parameter("flash_modifier", 1.0)
		hit_flash_tween.tween_property(material, "shader_parameter/flash_modifier", 0.0, 0.2)
	if player and player.has_node("PlayerCamera"):
		player.get_node("PlayerCamera").request_shake(8.0, 0.3)

func _draw() -> void:
	var bob_y = 0.0
	var bob_rot = 0.0
	var recoil_offset = 0.0
	var muzzle_flash_timer = 0.0
	var vault_timer = 0.0
	var equipped_weapon_data = {}
	
	if player.has_node("PlayerCamera"):
		bob_y = sin(player.get_node("PlayerCamera").walk_bob * 2.0) * 2.0
		bob_rot = sin(player.get_node("PlayerCamera").walk_bob) * 0.1
	if player.has_node("WeaponHandler"):
		recoil_offset = player.get_node("WeaponHandler").recoil_offset
		equipped_weapon_data = player.get_node("WeaponHandler").equipped_weapon_data
	if player.has_node("PlayerLighting"):
		muzzle_flash_timer = player.get_node("PlayerLighting").muzzle_flash_timer
	if player.has_node("InteractionDetector"):
		vault_timer = player.get_node("InteractionDetector").vault_timer
		
	position = Vector2(0, bob_y)
	rotation = bob_rot
	
	var skin_color = Color(0.9, 0.8, 0.7)
	
	var vest_points = PackedVector2Array([
		Vector2(-10, -12), Vector2(-10, 12),
		Vector2(2, 14), Vector2(12, 8),
		Vector2(12, -8), Vector2(2, -14)
	])
	
	var vest_colors = PackedColorArray()
	var vest_outline = PackedColorArray()
	for p in vest_points:
		vest_colors.append(Color(0.2, 0.3, 0.2))
		vest_outline.append(Color(0.1, 0.1, 0.1))
		
	var vest_outline_pts = PackedVector2Array()
	for p in vest_points:
		vest_outline_pts.append(p * 1.15)
		
	draw_polygon(vest_outline_pts, vest_outline)
	draw_polygon(vest_points, vest_colors)
	
	draw_rect(Rect2(Vector2(2, 3), Vector2(6, 4)), Color(0.15, 0.25, 0.15))
	draw_rect(Rect2(Vector2(2, -7), Vector2(6, 4)), Color(0.15, 0.25, 0.15))
	
	var head_radius = 8.0
	draw_circle(Vector2(2, 0), head_radius + 1.5, Color.BLACK)
	draw_circle(Vector2(2, 0), head_radius, skin_color)
	
	var hat_pts = PackedVector2Array([Vector2(2, -7), Vector2(2, 7), Vector2(12, 5), Vector2(12, -5)])
	draw_polygon(hat_pts, PackedColorArray([Color(0.15, 0.15, 0.15), Color(0.15, 0.15, 0.15), Color(0.15, 0.15, 0.15), Color(0.15, 0.15, 0.15)]))

	var weapon_recoil_pos = Vector2(-recoil_offset, 0)
	var right_shoulder = Vector2(0, 10)
	var right_hand = Vector2(12, 6) + weapon_recoil_pos
	draw_line(right_shoulder, right_hand, Color(0.25, 0.35, 0.25), 5.0)
	draw_circle(right_hand, 3.5, skin_color)
	
	var left_shoulder = Vector2(2, -10)
	var left_hand = Vector2(18, 0) + weapon_recoil_pos
	draw_line(left_shoulder, left_hand, Color(0.25, 0.35, 0.25), 5.0)
	draw_circle(left_hand, 3.5, skin_color)
	
	draw_rect(Rect2(right_hand + Vector2(-2, -2), Vector2(4, 6)), Color(0.1, 0.1, 0.1))
	var barrel_rect = Rect2(right_hand + Vector2(2, -3), Vector2(14, 4))
	draw_rect(barrel_rect, Color(0.15, 0.15, 0.15))
	
	if muzzle_flash_timer > 0.0:
		var flash_tip = right_hand + Vector2(16, -1)
		var flash_poly = PackedVector2Array([
			flash_tip + Vector2(0, -3), flash_tip + Vector2(8, 0),
			flash_tip + Vector2(0, 3), flash_tip + Vector2(12, 0)
		])
		draw_polygon(flash_poly, PackedColorArray([
			Color(1.0, 0.9, 0.3, 0.9), Color(1.0, 0.7, 0.1, 0.8), 
			Color(1.0, 0.9, 0.3, 0.9), Color(1.0, 0.5, 0.1, 0.8)
		]))

	if not equipped_weapon_data.is_empty():
		var stats = equipped_weapon_data.get("computed_stats", {})
		if stats.get("laser_sight", false):
			var laser_start = right_hand + Vector2(16, -1)
			var laser_end = laser_start + Vector2(350, 0)
			draw_line(laser_start, laser_end, Color(1.0, 0.15, 0.15, 0.65), 1.2)
			draw_circle(laser_end, 2.5, Color(1.0, 0.25, 0.25, 0.9))

	if vault_timer > 0.0:
		var ratio = clamp(vault_timer / 1.0, 0.0, 1.0)
		var bar_w = 36.0; var bar_h = 5.0
		var bar_pos = Vector2(-bar_w / 2.0, -26.0)
		draw_rect(Rect2(bar_pos + Vector2(-1, -1), Vector2(bar_w + 2, bar_h + 2)), Color(0, 0, 0, 0.8))
		var fill_color = Color(1.0, 0.8, 0.2).lerp(Color(0.2, 0.9, 0.3), ratio)
		draw_rect(Rect2(bar_pos, Vector2(bar_w * ratio, bar_h)), fill_color)
