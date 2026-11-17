extends Camera2D

@export var 初始坐标 : Vector2 = Vector2(-64,-72)
@export var player : Player

var playerPosition = Vector2.ZERO

func _ready():
	self.global_position = 初始坐标

func match_player_position():
	if player == null:
		return
	playerPosition = player.global_position

		
func _process(delta):
	match_player_position()
	if playerPosition.x > -240 and playerPosition.x < -64:
		global_position.x = lerp(playerPosition.x, global_position.x, pow(2, -7 * delta))
	if playerPosition.x < -240:
		global_position.x = lerp(-410.0, global_position.x, pow(2, -7 * delta))
	if playerPosition.x > -64:
		global_position.x = lerp(-64.0, global_position.x, pow(2, -7 * delta))
