extends CharacterBody2D


func _on_body_hit_area_entered(area: Area2D) -> void:
	print("玩家受伤")
