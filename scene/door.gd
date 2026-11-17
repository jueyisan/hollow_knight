extends StaticBody2D

@onready var anim: AnimationPlayer = $AnimationPlayer


func open():
	anim.play("开门")
	
func close():
	anim.play("关门")
