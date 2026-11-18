extends Node2D

var direction = 1
var velocity = Vector2.ZERO

func _ready() -> void:
	if direction == 1:
		velocity.x = -400
	else:
		velocity.x = 400

func _on_hit_box_area_entered(area: Area2D) -> void:
	var player : Player = area.get_parent()
	player.hurt(self)

func _physics_process(delta: float) -> void:
	self.global_position += velocity * delta
