# res://systems/responsive_manager.gd
extends Node

## 반응형 화면 및 UI 브레이크포인트 매니저
## 창 크기(Window Size) 및 화면비(Aspect Ratio)를 실시간 감지하여 반응형 레이아웃 시그널을 발행합니다.

enum Breakpoint {
	COMPACT,   # < 1000px (작은 창, 모바일/세로 뷰, 넷북)
	STANDARD,  # 1000px ~ 1500px (기본 720p ~ 1080p 데스크톱 창)
	WIDE       # > 1500px (1440p, 4K, 21:9 울트라와이드 등)
}

enum AspectType {
	PORTRAIT,    # < 1.0 (세로형)
	STANDARD,    # 1.0 ~ 1.55 (4:3, 5:4, 3:2 등)
	WIDE,        # 1.55 ~ 2.0 (16:9, 16:10 등)
	ULTRAWIDE    # > 2.0 (21:9, 32:9 등)
}

signal breakpoint_changed(new_breakpoint: Breakpoint, viewport_size: Vector2)
signal aspect_changed(new_aspect: AspectType, aspect_ratio: float)
signal window_resized(viewport_size: Vector2)

const COMPACT_MAX_WIDTH: float = 1000.0
const STANDARD_MAX_WIDTH: float = 1500.0

var current_breakpoint: Breakpoint = Breakpoint.STANDARD
var current_aspect: AspectType = AspectType.WIDE
var current_viewport_size: Vector2 = Vector2(1280, 720)
var current_aspect_ratio: float = 16.0 / 9.0

func _ready() -> void:
	# 창 크기 변경 시그널 연결
	get_tree().root.size_changed.connect(_on_window_size_changed)
	# 초기 상태 계산
	_update_responsive_state(false)

func _on_window_size_changed() -> void:
	_update_responsive_state(true)

func _update_responsive_state(emit_signals: bool = true) -> void:
	var vp = get_viewport()
	if not vp:
		return
		
	var vp_size = vp.get_visible_rect().size
	if vp_size.x <= 0 or vp_size.y <= 0:
		return
		
	current_viewport_size = vp_size
	current_aspect_ratio = vp_size.x / vp_size.y
	
	# 1. 브레이크포인트 계산
	var new_bp = Breakpoint.STANDARD
	if vp_size.x < COMPACT_MAX_WIDTH:
		new_bp = Breakpoint.COMPACT
	elif vp_size.x > STANDARD_MAX_WIDTH:
		new_bp = Breakpoint.WIDE
	else:
		new_bp = Breakpoint.STANDARD
		
	# 2. 화면비 계산
	var new_aspect = AspectType.WIDE
	if current_aspect_ratio < 1.0:
		new_aspect = AspectType.PORTRAIT
	elif current_aspect_ratio < 1.55:
		new_aspect = AspectType.STANDARD
	elif current_aspect_ratio <= 2.05:
		new_aspect = AspectType.WIDE
	else:
		new_aspect = AspectType.ULTRAWIDE
		
	var bp_changed = (new_bp != current_breakpoint)
	var aspect_changed_flag = (new_aspect != current_aspect)
	
	current_breakpoint = new_bp
	current_aspect = new_aspect
	
	if emit_signals:
		window_resized.emit(current_viewport_size)
		if bp_changed:
			breakpoint_changed.emit(current_breakpoint, current_viewport_size)
		if aspect_changed_flag:
			aspect_changed.emit(current_aspect, current_aspect_ratio)

# 편의 헬퍼 메서드들
func is_compact() -> bool:
	return current_breakpoint == Breakpoint.COMPACT

func is_standard() -> bool:
	return current_breakpoint == Breakpoint.STANDARD

func is_wide() -> bool:
	return current_breakpoint == Breakpoint.WIDE

func is_ultrawide() -> bool:
	return current_aspect == AspectType.ULTRAWIDE

func is_portrait() -> bool:
	return current_aspect == AspectType.PORTRAIT

## 기준 해상도(1280x720) 대비 UI 스케일 팩터 반환 (0.8 ~ 1.5 클램프)
func get_ui_scale() -> float:
	var scale_factor = minf(current_viewport_size.x / 1280.0, current_viewport_size.y / 720.0)
	return clampf(scale_factor, 0.75, 1.5)
