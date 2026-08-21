# res://autoload/event_bus.gd
@warning_ignore("unused_signal")
extends Node

## 게임 전역 시그널 버스

# 플레이어 관련
signal player_damaged(amount: float, source: String)
signal player_healed(amount: float)
signal player_died()
signal stat_changed(stat_name: String, current_value: float, max_value: float)
signal item_picked_up(item_name: String, count: int)
signal inventory_changed()

# 레이드 및 탈출 관련
signal raid_started()
signal raid_ended(result: String, details: Dictionary) # result: "survived", "kia", "mia"
signal extraction_started(point_name: String, duration: float)
signal extraction_cancelled()
signal extraction_completed()

# 엔티티 및 전투 관련
signal enemy_damaged(enemy: Node, amount: float, is_critical: bool)
signal enemy_killed(enemy_type: String, faction: String, position: Vector2)
signal projectile_fired(start_pos: Vector2, target_pos: Vector2, weapon_name: String)
signal combat_effect_requested(effect_type: String, params: Dictionary)
signal camera_shake_requested(intensity: float, duration: float)

# 월드 및 환경 관련
signal time_tick(hour: int, minute: int, total_minutes: float)
signal day_changed(new_day: int)
signal weather_changed(new_weather: String)
signal event_logged(msg: String)
signal noise_created(position: Vector2, radius: float, source_type: String)
signal door_toggled(tile_pos: Vector2i, is_open: bool)
signal window_broken(tile_pos: Vector2i)
signal building_entered(building_data: Dictionary, floor_num: int)
signal building_exited()
signal chunk_loaded(chunk_pos: Vector2i)
signal chunk_unloaded(chunk_pos: Vector2i)

# UI 및 시스템 관련
signal popup_message(text: String, color: Color)
signal dialogue_started(npc_data: Dictionary)
signal dialogue_ended()
signal radio_scan_requested(target_type: String)
signal ui_state_changed(ui_name: String, is_open: bool)
