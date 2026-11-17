extends Node2D

const guci_scene = preload("res://scene/Guci.tscn")

func spawn_guci():
	var boss = get_node("/root/MainScene/Enemy/Boss")
	for i in range(10):
		var guci_node_right = guci_scene.instantiate()
		guci_node_right.position.x = boss.position.x + 40 + 40 * i
		guci_node_right.position.y = 0
		if guci_node_right.position.x > -548 and guci_node_right.position.x < -284:
			add_child(guci_node_right)
		var guci_node_left = guci_scene.instantiate()
		guci_node_left.position.x = boss.position.x - 40 - 40 * i
		guci_node_left.position.y = 0
		if guci_node_left.position.x > -548 and guci_node_left.position.x < -284:
			add_child(guci_node_left)
		await get_tree().create_timer(0.2).timeout
