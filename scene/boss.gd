extends CharacterBody2D
class_name Enemy

@export var player : Player

@onready var sprite_node: Node2D = $SpriteNode
@onready var hit_box: Node2D = $HitBox
@onready var anim: AnimationPlayer = $AnimationPlayer


enum State{ READY, READY_2, IDLE, HUIKAN, HUIKAN_ZHUNBEI, SHANGTIAO, SHANGTIAO_ZHUNBEI,
			MOVE, JUMP, FALL, JUMP_2, XIACHUO_ZHUNBEI, XIACHUO, XIACHUO_JIESHU,
			BACK_JUMP, BACK_FALL, BAIBO, CHONGCI_ZHUNBEI, CHONGCI, CHONGCI_TINGXIA,
			HURT, DIE_1, DIE_2, ZHANHOU_ZHUNBEI, ZHANHOU }

var currentState = State.READY
var isStateNew = true

var playerPosition = Vector2.ZERO


var gravity = 1000
var BossHealth = 1000

func _ready() -> void:
	player = get_node_or_null("/root/MainScene/Player")
	anim.animation_finished.connect(_on_animation_finished)

func match_player_position():
	if player == null:
		return
	playerPosition = player.global_position

func turn_direction():
	sprite_node.scale.x = 1 if playerPosition.x < global_position.x else -1
	hit_box.scale.x = 1 if playerPosition.x < global_position.x else -1

func change_state(newState):
	# 离开攻击状态时统一关闭命中框，防止动画中断导致判定残留
	if _is_attack_state(currentState) and not _is_attack_state(newState):
		_disable_all_hitboxes()
	currentState = newState
	isStateNew = true

func _disable_all_hitboxes() -> void:
	for hitbox in hit_box.get_children():
		hitbox.monitoring = false
		hitbox.monitorable = false
		
func _is_attack_state(state) -> bool:
	return state in [State.HUIKAN, State.SHANGTIAO, State.XIACHUO, State.CHONGCI]

func _physics_process(delta: float) -> void:
	match_player_position()
	
	match currentState:
		State.READY:
			process_ready(delta)
		State.IDLE:
			process_idle(delta)
		State.HUIKAN_ZHUNBEI:
			process_huikan_zhunbei(delta)
		State.HUIKAN:
			process_huikan(delta)
		State.SHANGTIAO:
			process_shangtiao(delta)
		State.SHANGTIAO_ZHUNBEI:
			process_shangtiao_zhunbei(delta)
		State.FALL:
			process_fall(delta)
		State.MOVE:
			process_move(delta)
		State.JUMP:
			process_jump(delta)
		State.JUMP_2:
			process_jump_2(delta)
		State.XIACHUO_ZHUNBEI:
			process_xiachuo_zhunbei(delta)
		State.XIACHUO:
			process_xiachuo(delta)
		State.XIACHUO_JIESHU:
			process_xiachuo_jieshu(delta)
		State.BACK_JUMP:
			process_back_jump(delta)
		State.BACK_FALL:
			process_back_fall(delta)
		State.BAIBO:
			process_baibo(delta)
		State.CHONGCI_ZHUNBEI:
			process_chongci_zhunbei(delta)
		State.CHONGCI:
			process_chongci(delta)
		State.CHONGCI_TINGXIA:
			process_chongci_tingxia(delta)
	isStateNew = false

func process_ready(delta):
	if isStateNew:
		turn_direction()
	if playerPosition.x < -320:
		var door = get_node("/root/MainScene/Doors/Door")
		door.close()
		call_deferred("change_state", State.IDLE)

func process_idle(delta):
	turn_direction()
	if isStateNew:
		velocity = Vector2.ZERO
		anim.play("站立")
	velocity.y += gravity * delta
	move_and_slide()	

func process_huikan_zhunbei(delta):
	if isStateNew:
		turn_direction()
		velocity = Vector2.ZERO
		anim.play("挥砍准备")

func process_huikan(delta):
	if isStateNew:
		velocity.x = -300 if sprite_node.scale.x == 1 else 300
		velocity.y = 0
		anim.play("挥砍")
	velocity.y += gravity * delta
	move_and_slide()


func process_shangtiao_zhunbei(delta):
	if isStateNew:
		velocity = Vector2.ZERO
		anim.play("上挑准备")	

func process_shangtiao(delta):
	if isStateNew:
		turn_direction()
		velocity.x = -80 if sprite_node.scale.x == 1 else 80
		velocity.y = -400
		anim.play("上挑")
	velocity.y += gravity * delta
	move_and_slide()	

func process_fall(delta):
	if isStateNew:
		anim.play("下落")
	velocity.y += gravity * delta
	move_and_slide()
	if is_on_floor():
		velocity = Vector2.ZERO
		call_deferred("change_state", State.IDLE)

func process_move(delta):
	turn_direction()
	if isStateNew:
		if playerPosition.x > global_position.x:
			velocity.x = 80
		else:
			velocity.x = -80
		velocity.y = 0
		anim.play("移动")
	velocity.y += gravity * delta
	move_and_slide()
	if abs(playerPosition.x - global_position.x) < 80:
		call_deferred("change_state", State.HUIKAN_ZHUNBEI)

func process_jump(delta):
	if isStateNew:
		velocity.x = playerPosition.x - global_position.x
		velocity.y = -400
		anim.play("跳跃")
	velocity.y += gravity * delta
	move_and_slide()
	if velocity.y > 0:
		call_deferred("change_state", State.FALL)

func process_jump_2(delta):
	if isStateNew:
		velocity.x = (playerPosition.x - global_position.x) * 2
		velocity.y = -400
		anim.play("跳跃")
	velocity.y += gravity * delta
	move_and_slide()
	if velocity.y > 0:
		call_deferred("change_state", State.XIACHUO_ZHUNBEI)

func process_xiachuo_zhunbei(delta):
	if isStateNew:
		velocity = Vector2.ZERO
		anim.play("下戳准备")
		

func process_xiachuo(delta):
	if isStateNew:
		anim.play("下戳")
	velocity.y += 100
	move_and_slide()
	if is_on_floor():
		#$"/root/MainScene/GameCamera".camera_shake_small()
		var guci_spawner = get_node("/root/MainScene/Enemy/GuciSpawner")
		guci_spawner.spawn_guci()
		call_deferred("change_state", State.XIACHUO_JIESHU)

func process_xiachuo_jieshu(delta):
	if isStateNew:
		velocity = Vector2.ZERO
		anim.play("下戳结束")

func process_back_jump(delta):
	if isStateNew:
		velocity.x = -548 - global_position.x if playerPosition.x > -416 else -284 - global_position.x
		velocity.y = -400
		if velocity.x < 0 and sprite_node.scale.x == 1:
			anim.play("跳跃")
		if velocity.x < 0 and sprite_node.scale.x == -1:
			anim.play("后跳")
		if velocity.x > 0 and sprite_node.scale.x == 1:
			anim.play("后跳")
		if velocity.x > 0 and sprite_node.scale.x == -1:
			anim.play("跳跃")
	velocity.y += gravity * delta
	move_and_slide()
	if velocity.y > 0:
		call_deferred("change_state", State.BACK_FALL)

func process_back_fall(delta):
	if isStateNew:
		if velocity.x < 0 and sprite_node.scale.x == 1:
			anim.play("下落")
		if velocity.x < 0 and sprite_node.scale.x == -1:
			anim.play("后跳下落")
		if velocity.x > 0 and sprite_node.scale.x == 1:
			anim.play("后跳下落")
		if velocity.x > 0 and sprite_node.scale.x == -1:
			anim.play("下落")
	velocity.y += gravity * delta
	move_and_slide()
	if is_on_floor():
		#$AudioStreamPlayer_Fall.play()
		velocity = Vector2.ZERO
		if randf() > 0.5:
			call_deferred("change_state", State.BAIBO)
		else:
			call_deferred("change_state", State.CHONGCI_ZHUNBEI)

func process_baibo(delta):
	if isStateNew:
		turn_direction()
		velocity = Vector2.ZERO
		anim.play("白波")

func spawn_baibo():
	#$"/root/MainScene/GameCamera".camera_shake_small()
	var baibo_spawner = get_node("/root/MainScene/Enemy/BaiboSpawner")
	if sprite_node.scale.x == 1:
		baibo_spawner.spawn_baibo_left()
		position.x += 5
	else:
		baibo_spawner.spawn_baibo_right()
		position.x -= 5

func process_chongci_zhunbei(delta):
	if isStateNew:
		turn_direction()
		velocity = Vector2.ZERO
		anim.play("冲刺准备")

func process_chongci(delta):
	if isStateNew:
		#$"/root/MainScene/GameCamera".camera_shake_small()
		velocity.x = -400 if sprite_node.scale.x == 1 else 400
		velocity.y = 0
		anim.play("冲刺")
	velocity.y += gravity * delta
	move_and_slide()
	if sprite_node.scale.x == 1 and global_position.x < -500:
		call_deferred("change_state", State.CHONGCI_TINGXIA)
	if sprite_node.scale.x == -1 and global_position.x > -310:
		call_deferred("change_state", State.CHONGCI_TINGXIA)

func process_chongci_tingxia(delta):
	if isStateNew:
		anim.play("冲刺停下")
	velocity.x = lerp(0.0, velocity.x, pow(2, -10 * delta))
	velocity.y += gravity * delta
	move_and_slide()

func _on_body_hit_area_entered(area: Area2D) -> void:
	var player : Player = area.get_parent()
	player.hurt(self)


func hurt(player : Player):
	if player == null:
		return
	hurt_effect()
	
	
func hurt_effect():
	var tween : Tween = create_tween()
	tween.tween_property(sprite_node.get_child(0),"use_parent_material",false,0.2).from(true)

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "站立":
		if randf() < 0.3:
			if abs(playerPosition.x - global_position.x) < 80:
				call_deferred("change_state", State.HUIKAN_ZHUNBEI)
			else:
				if randf() > 0.5:
					call_deferred("change_state", State.MOVE)
				else:
					call_deferred("change_state", State.JUMP)
		else:
			if randf() > 0.5:
				call_deferred("change_state", State.JUMP_2)
			else:
				call_deferred("change_state", State.BACK_JUMP)
	elif anim_name == "挥砍准备":
		call_deferred("change_state", State.HUIKAN)
	elif anim_name == "挥砍":
		call_deferred("change_state", State.SHANGTIAO_ZHUNBEI)
	elif anim_name == "上挑准备":
		call_deferred("change_state", State.SHANGTIAO)
	elif anim_name == "上挑":
		call_deferred("change_state", State.FALL)
	elif anim_name == "下戳准备":
		call_deferred("change_state", State.XIACHUO)
	elif anim_name == "下戳结束" or anim_name == "白波" or anim_name == "冲刺停下":
		call_deferred("change_state", State.IDLE)
	elif anim_name == "冲刺准备":
		call_deferred("change_state", State.CHONGCI)
