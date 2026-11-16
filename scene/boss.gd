extends CharacterBody2D
class_name Enemy

@onready var sprite_2d: Sprite2D = $SpriteNode/Sprite2D

func _on_body_hit_area_entered(area: Area2D) -> void:
	var player : Player = area.get_parent()
	player.hurt(self)


func hurt(player : Player):
	if player == null:
		return
	hurt_effect()
	
	
func hurt_effect():
	var tween : Tween = create_tween()
	tween.tween_property(sprite_2d,"use_parent_material",false,0.2).from(true)
