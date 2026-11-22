# res://tests/test_ui_icons.gd
extends SceneTree

func _initialize() -> void:
	print("=== RuinHarvest UI Icon & Zero-Emoji Regression Tests ===")
	var suite_script: GDScript = load("res://tests/ui_icons_test_suite.gd")
	var suite: Node = suite_script.new()
	get_root().add_child(suite)
	suite.call_deferred("run_all")
