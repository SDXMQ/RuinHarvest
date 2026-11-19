# res://tests/test_p0_regressions.gd
extends SceneTree

func _initialize() -> void:
	print("=== RuinHarvest P0 Regression Tests ===")
	var suite_script: GDScript = load("res://tests/p0_regression_suite.gd")
	var suite: Node = suite_script.new()
	get_root().add_child(suite)
	suite.call_deferred("run_all")
