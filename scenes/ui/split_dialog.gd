# res://scenes/ui/split_dialog.gd
extends Control

signal split_confirmed(amount: int)
signal split_cancelled

@onready var slider: HSlider = $Center/Panel/VBox/HBox/Slider
@onready var spin: SpinBox = $Center/Panel/VBox/HBox/Spin

var max_total_amount: int = 1

func setup(total_amt: int) -> void:
	max_total_amount = total_amt
	var max_split = max(1, total_amt - 1)
	var default_split = int(total_amt / 2)
	if default_split <= 0: default_split = 1
	
	slider.min_value = 1
	slider.max_value = max_split
	slider.value = default_split
	
	spin.min_value = 1
	spin.max_value = max_split
	spin.value = default_split
	
	slider.value_changed.connect(func(v): spin.value = v)
	spin.value_changed.connect(func(v): slider.value = v)

func _on_confirm_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	split_confirmed.emit(int(spin.value))
	queue_free()

func _on_cancel_pressed() -> void:
	if SoundManager: SoundManager.play("menu_select")
	split_cancelled.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()
