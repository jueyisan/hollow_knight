extends Node2D


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	queue_free()
	
func _on_hit_box_area_entered(area: Area2D) -> void:
	var player : Player = area.get_parent()
	player.hurt(self)
