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
		velocity = Vector2.ZERO
		anim.play("挥砍准备")

func process_shangtiao(delta):
	if isStateNew:
		velocity.x = -80 if sprite_node.scale.x == 1 else 80
		velocity.y = -400
		anim.play("上挑")
	velocity.y += gravity * delta
	move_and_slide()	

func process_shangtiao_zhunbei(delta):
	if isStateNew:
		velocity = Vector2.ZERO
		anim.play("上挑准备")	

func process_huikan(delta):
	if isStateNew:
		velocity.x = -300 if sprite_node.scale.x == 1 else 300
		velocity.y = 0
		anim.play("挥砍")
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
		call_deferred("change_state", State.HUIKAN_ZHUNBEI)
		#if randf() < 0.3:
			#if abs(playerPosition.x - global_position.x) < 80:
				#call_deferred("change_state", State.HUIKAN_ZHUNBEI)
			#else:
				#if randf() > 0.5:
					#call_deferred("change_state", State.MOVE)
				#else:
					#call_deferred("change_state", State.JUMP)
		#else:
			#if randf() > 0.5:
				#call_deferred("change_state", State.JUMP_2)
			#else:
				#call_deferred("change_state", State.BACK_JUMP)
	elif anim_name == "挥砍准备":
		call_deferred("change_state", State.HUIKAN)
	elif anim_name == "挥砍":
		call_deferred("change_state", State.SHANGTIAO_ZHUNBEI)
	elif anim_name == "上挑准备":
		call_deferred("change_state", State.SHANGTIAO)
	elif anim_name == "上挑":
		pass
		#call_deferred("change_state", State.SHANGTIAO_ZHUNBEI)
