extends CharacterBody2D

# ---- 水平移动 ----
## 最大水平移动速度（px/s）。对应空洞骑士约 8.3 格/秒的奔跑速度。
@export var max_speed: float = 156.0
## 地面加速度（px/s²）。高值使地面几乎瞬间达到最大速度，无滑动惯性。
@export var acceleration: float = 2400.0
## 地面摩擦减速度（px/s²）。松键后迅速停下。
@export var friction: float = 2400.0
## 空中加速度（px/s²）。略低于地面，空中仍灵活可快速转向。
@export var air_acceleration: float = 2100.0
## 空中摩擦减速度（px/s²）。空中松键后的减速速率。
@export var air_friction: float = 2100.0

# ---- 跳跃与重力 ----
## 起跳初速度（px/s，向上为负）。与 gravity 共同决定顶点时间和跳跃高度。
@export var jump_velocity: float = -300.0
## 二段跳初速度（px/s，向上为负）。通常略弱于第一跳。
@export var double_jump_velocity: float = -280.0
## 基础重力（px/s²）。参考空洞骑士测算值缩放。
@export var gravity: float = 1080.0
## 下落重力倍率（无量纲）。1.6 为空洞骑士上升/下落重力比，下落更干脆。
@export var fall_gravity_multiplier: float = 1.6
## 松键时上升速度保留比例（0~1）。0.40 即削减 60%，实现可变跳跃高度。
@export var jump_cut_multiplier: float = 0.40

# ---- 手感辅助（时间参数，不随尺度缩放） ----
## 土狼时间（秒）。离开平台后仍可起跳的宽限窗口，约 6 帧 @60fps。
@export var coyote_time: float = 0.10
## 跳跃缓冲时间（秒）。落地前按跳，落地瞬间自动起跳的窗口。
@export var jump_buffer_time: float = 0.10

# ---- 下落限速 ----
## 最大下落速度（px/s）。防止高处坠落速度失控。
@export var max_fall_speed: float = 720.0

# ---- 冲刺 ----
## 冲刺水平速度（px/s）。冲刺距离 = dash_speed × 冲刺动画时长（0.4s）。
## 250 × 0.4 = 100px。想更短就继续降低该值。
@export var dash_speed: float = 350.0
## 冲刺冷却时间（秒）。冲刺结束后经过该时长才能再次冲刺。
@export var dash_cooldown: float = 0.20

@onready var hit_box: Node2D = $HitBox
@onready var sprite_node: Node2D = $SpriteNode
@onready var anim: AnimationPlayer = $AnimationPlayer

enum State{ NORMAL, DASH, ATTACK, ATTACK_UP, ATTACK_DOWN, ATTACK_JUMP,
			HURT, DIE_1, DIE_2, HEAL, HEIBO, SHANGHOU, XIAZA_XULI, 
			XIAZA_GUOCHENG, XIAZA_LUODI, SCARED }

# ---- 动画名称 ----
const ANIM_IDLE := "站立"
const ANIM_MOVE := "移动"
const ANIM_JUMP := "跳跃"
const ANIM_FALL := "下落"
const ANIM_DOUBLE_JUMP := "二段跳"
const ANIM_DASH := "冲刺"
const ANIM_ATTACK_SLASH1 := "横劈1"
const ANIM_ATTACK_SLASH2 := "横劈2"
const ANIM_ATTACK_UP := "上劈"
const ANIM_ATTACK_DOWN := "下劈"

# 判定“正在移动”的最小水平速度阈值
const MOVE_THRESHOLD := 1.0

# ---- 攻击命中框 ----
## 所有攻击命中框的节点路径，统一管理以避免动画被打断后判定残留。
const HITBOX_PATHS := [
	"HitBox/Attack1/CollisionPolygon2D",
	"HitBox/Attack2/CollisionPolygon2D",
	"HitBox/AttackUp/CollisionPolygon2D",
	"HitBox/AttackDown/CollisionPolygon2D",
]

var _attack_hitboxes: Array[CollisionPolygon2D] = []

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _current_anim: String = ""

# ---- 二段跳状态 ----
var _has_double_jumped: bool = false
var _is_double_jumping: bool = false

# ---- 冲刺状态 ----
var _is_dashing: bool = false
var _dash_cooldown_timer: float = 0.0
var _dash_direction: float = 1.0

# ---- 攻击状态 ----
## 横劈交替标记：false 下一次为横劈1，true 下一次为横劈2。
var _next_slash_is_second: bool = false

var currentState = State.NORMAL
var isStateNew = true

func _ready() -> void:
	anim.animation_finished.connect(_on_animation_finished)
	_attack_hitboxes.clear()
	for path in HITBOX_PATHS:
		var hitbox := get_node_or_null(path) as CollisionPolygon2D
		if hitbox != null:
			_attack_hitboxes.append(hitbox)
	_disable_all_hitboxes()

func _physics_process(delta: float) -> void:
	_dash_cooldown_timer = max(_dash_cooldown_timer - delta, 0.0)
	
	match currentState:
		State.NORMAL:
			process_normal(delta)
		State.DASH:
			process_dash(delta)
		State.ATTACK, State.ATTACK_UP, State.ATTACK_DOWN:
			process_attack(delta)
	isStateNew = false

func change_state(newState):
	# 离开攻击状态时统一关闭命中框，防止动画中断导致判定残留
	if _is_attack_state(currentState) and not _is_attack_state(newState):
		_disable_all_hitboxes()
	currentState = newState
	isStateNew = true

func _is_attack_state(state) -> bool:
	return state in [State.ATTACK, State.ATTACK_UP, State.ATTACK_DOWN]

## 关闭所有攻击命中框。攻击动画会在各自的判定帧重新开启。
func _disable_all_hitboxes() -> void:
	for hitbox in _attack_hitboxes:
		hitbox.disabled = true

# ---------------- 动画状态机 ----------------
func _update_animation() -> void:
	if _is_double_jumping:
		return

	var next_anim: String
	if not is_on_floor():
		next_anim = ANIM_JUMP if velocity.y < 0.0 else ANIM_FALL
	elif absf(velocity.x) > MOVE_THRESHOLD:
		next_anim = ANIM_MOVE
	else:
		next_anim = ANIM_IDLE

	if next_anim != _current_anim:
		_current_anim = next_anim
		anim.play(next_anim)

# ---------------- 重力 ----------------
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var g := gravity
		if velocity.y > 0.0:
			g *= fall_gravity_multiplier
		velocity.y += g * delta
		velocity.y = min(velocity.y, max_fall_speed)

# ---------------- 跳跃输入与执行 ----------------
func _handle_jump_input() -> void:
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier

	var can_ground_jump := is_on_floor() or _coyote_timer > 0.0
	if _jump_buffer_timer > 0.0 and can_ground_jump:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_has_double_jumped = false
		return

	if Input.is_action_just_pressed("jump") \
			and not is_on_floor() \
			and _coyote_timer <= 0.0 \
			and not _has_double_jumped:
		velocity.y = double_jump_velocity
		_has_double_jumped = true
		_is_double_jumping = true
		_jump_buffer_timer = 0.0
		_current_anim = ANIM_DOUBLE_JUMP
		anim.play(ANIM_DOUBLE_JUMP)

# ---------------- 水平移动 ----------------
func _handle_horizontal_movement(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	var target_speed := direction * max_speed

	var accel := acceleration if is_on_floor() else air_acceleration
	var fric := friction if is_on_floor() else air_friction

	if direction != 0.0:
		velocity.x = move_toward(velocity.x, target_speed, accel * delta)
		turn_direction(direction)
	else:
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)
				
func process_normal(delta):
	_apply_gravity(delta)
	_handle_jump_input()
	_handle_horizontal_movement(delta)
	
	move_and_slide()
	_update_timers_after_move(delta)
	_update_animation()
	
	if _try_start_attack():
		return
	if Input.is_action_just_pressed("dash") and _dash_cooldown_timer <= 0:
		call_deferred("change_state", State.DASH)

func turn_direction(dir : float):
	sprite_node.scale.x = -1 if dir < 0.0 else 1
	hit_box.scale.x = -1 if dir < 0.0 else 1
		
func process_dash(delta):
	if isStateNew:
		var direction := Input.get_axis("move_left", "move_right")
		if direction == 0.0:
			_dash_direction = sprite_node.scale.x
		else:
			_dash_direction = direction
			turn_direction(direction)
		
		_is_double_jumping = false
		_is_dashing = true
		_current_anim = ANIM_DASH
		anim.play(_current_anim)
		
	velocity.x = _dash_direction * dash_speed
	velocity.y = 0.0
	move_and_slide()

# ---------------- 攻击 ----------------
## 检测攻击输入并切换到对应攻击状态。
## 上劈：按住 W + J；下劈：空中按住 S + J；其余情况为横劈（1/2 交替）。
func _try_start_attack() -> bool:
	if not Input.is_action_just_pressed("attack"):
		return false

	if Input.is_action_pressed("move_up"):
		call_deferred("change_state", State.ATTACK_UP)
	elif Input.is_action_pressed("move_down") and not is_on_floor():
		call_deferred("change_state", State.ATTACK_DOWN)
	else:
		call_deferred("change_state", State.ATTACK)
	return true

func process_attack(delta: float) -> void:
	if isStateNew:
		_begin_attack()
	elif Input.is_action_just_pressed("dash") and _dash_cooldown_timer <= 0:
		call_deferred("change_state", State.DASH)
		return

	_apply_gravity(delta)
	move_and_slide()

## 根据当前攻击状态播放对应动画。
func _begin_attack() -> void:
	_is_double_jumping = false
	_disable_all_hitboxes()

	var anim_name: String
	match currentState:
		State.ATTACK_UP:
			anim_name = ANIM_ATTACK_UP
		State.ATTACK_DOWN:
			anim_name = ANIM_ATTACK_DOWN
		_:
			if _next_slash_is_second:
				anim_name = ANIM_ATTACK_SLASH2
			else:
				anim_name = ANIM_ATTACK_SLASH1
			_next_slash_is_second = not _next_slash_is_second

	_current_anim = anim_name
	anim.play(anim_name)

## 攻击动画结束，回到普通状态。
func _end_attack() -> void:
	_current_anim = ""
	call_deferred("change_state", State.NORMAL)

# ---------------- 计时器与落地重置 ----------------
func _update_timers_after_move(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
		_has_double_jumped = false
		_is_double_jumping = false
	else:
		_coyote_timer = max(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)

func _end_dash() -> void:
	_is_dashing = false
	_dash_cooldown_timer = dash_cooldown
	# 不人为衰减速度，交给 _handle_horizontal_movement 统一处理
	_current_anim = ""
	
	# === 修复：冲刺结束时立刻按当前输入接管水平速度 ===
	# 避免残余冲刺速度在 NORMAL 状态下被慢慢衰减，造成反向漂移
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		velocity.x = dir * max_speed
	else:
		velocity.x = 0.0
	call_deferred("change_state", State.NORMAL)

# ---------------- 动画结束回调 ----------------
func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == ANIM_DOUBLE_JUMP:
		_is_double_jumping = false
	elif anim_name == ANIM_DASH and _is_dashing:
		_end_dash()
	elif anim_name in [ANIM_ATTACK_SLASH1, ANIM_ATTACK_SLASH2, ANIM_ATTACK_UP, ANIM_ATTACK_DOWN]:
		_end_attack()
		
