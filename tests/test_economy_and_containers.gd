# res://tests/test_economy_and_containers.gd
extends SceneTree

func _initialize() -> void:
	print("=== RuinHarvest Economy, Nested Containers & UI Integration Tests ===")
	var suite_script: GDScript = load("res://tests/economy_and_containers_suite.gd")
	var suite: Node = suite_script.new()
	get_root().add_child(suite)
	suite.call_deferred("run_all")
