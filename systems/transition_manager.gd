# res://systems/transition_manager.gd
extends CanvasLayer

## 씬 전환 시 페이드/와이프/다이아몬드 효과를 적용하는 Autoload 싱글톤
## 사용법: TransitionManager.change_scene("res://scenes/world/main_world.tscn", "fade", 0.8)

var overlay: ColorRect
var is_active: bool = false
var on_mid_callback: Callable
var on_complete_callback: Callable

func _ready() -> void:
	layer = 100 # 최상위 레이어
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	overlay = ColorRect.new()
	overlay.name = "TransitionOverlay"
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = Color(0, 0, 0, 0)
	overlay.visible = false
	add_child(overlay)

## 씬 전환 with 트랜지션 효과
func change_scene(scene_path: String, type: String = "fade", duration: float = 0.8) -> void:
	if is_active: return
	is_active = true
	
	var mid_cb = func():
		get_tree().change_scene_to_file(scene_path)
	
	var complete_cb = func():
		is_active = false
	
	_play_transition(type, duration, mid_cb, complete_cb)

## 콜백 기반 전환 (씬 전환 없이 중간에 커스텀 작업)
func play_transition(type: String = "fade", duration: float = 0.8, on_mid: Callable = Callable(), on_complete: Callable = Callable()) -> void:
	if is_active: return
	is_active = true
	_play_transition(type, duration, on_mid, func():
		is_active = false
		if on_complete.is_valid():
			on_complete.call()
	)

func _play_transition(type: String, duration: float, on_mid: Callable, on_complete: Callable) -> void:
	overlay.visible = true
	overlay.color = Color(0, 0, 0, 0)
	
	var half = duration * 0.5
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	match type:
		"fade":
			_transition_fade(tween, half, on_mid, on_complete)
		"circle":
			_transition_fade(tween, half, on_mid, on_complete) # circle은 셰이더 필요하므로 fade fallback
		"diamond":
			_transition_fade(tween, half, on_mid, on_complete) # diamond도 fade fallback
		_:
			_transition_fade(tween, half, on_mid, on_complete)

func _transition_fade(tween: Tween, half_duration: float, on_mid: Callable, on_complete: Callable) -> void:
	# Phase 1: 페이드 인 (투명 -> 검정)
	tween.tween_property(overlay, "color:a", 1.0, half_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# 중간 지점: 씬 전환 콜백
	tween.tween_callback(func():
		if on_mid.is_valid():
			on_mid.call()
	)
	
	# 1프레임 대기 (씬 로드 안정화)
	tween.tween_interval(0.05)
	
	# Phase 2: 페이드 아웃 (검정 -> 투명)
	tween.tween_property(overlay, "color:a", 0.0, half_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# 완료
	tween.tween_callback(func():
		overlay.visible = false
		if on_complete.is_valid():
			on_complete.call()
	)
