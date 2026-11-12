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
## 二段跳初速度（px/s，向上为负）。通常略弱于第一跳，可按需调整。
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
## 冲刺水平速度（px/s）。通常远大于 max_speed，体现冲刺的爆发感。
@export var dash_speed: float = 250.0
## 冲刺冷却时间（秒）。冲刺结束后经过该时长才能再次冲刺。
@export var dash_cooldown: float = 0.40

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim: AnimationPlayer = $AnimationPlayer

# 判定“正在移动”的最小水平速度阈值，避免摩擦残留微小速度时误判
const MOVE_THRESHOLD := 1.0

# ---- 动画名称（与 AnimationPlayer 中的动画名保持一致） ----
const ANIM_IDLE := "站立"
const ANIM_MOVE := "移动"
const ANIM_JUMP := "跳跃"
const ANIM_FALL := "下落"
const ANIM_DOUBLE_JUMP := "二段跳"
const ANIM_DASH := "冲刺"

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _current_anim: String = ""

# ---- 二段跳状态 ----
var _has_double_jumped: bool = false   # 本次腾空是否已用掉二段跳
var _is_double_jumping: bool = false   # 二段跳动画播放中，锁住动画状态机

# ---- 冲刺状态 ----
var _is_dashing: bool = false
var _dash_cooldown_timer: float = 0.0
var _dash_direction: float = 1.0

func _ready() -> void:
	anim.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	_dash_cooldown_timer = max(_dash_cooldown_timer - delta, 0.0)

	if _is_dashing:
		_update_dash(delta)
	else:
		_handle_dash_input()
		if _is_dashing:
			# 本帧刚触发冲刺，直接按冲刺逻辑移动，不做重力/跳跃处理
			_update_dash(delta)
		else:
			_apply_gravity(delta)
			_handle_jump_input(delta)
			_handle_horizontal_movement(delta)
	move_and_slide()
	_update_timers_after_move(delta)
	_update_animation()

# ---------------- 重力 ----------------
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var g := gravity
		if velocity.y > 0.0:  # 下落阶段加重重力
			g *= fall_gravity_multiplier
		velocity.y += g * delta
		velocity.y = min(velocity.y, max_fall_speed)   # 新增这行

# ---------------- 跳跃输入与执行 ----------------
func _handle_jump_input(delta: float) -> void:
	# 记录跳跃缓冲
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time

	# 可变跳跃高度：上升中松开跳跃键，立刻削减向上速度
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier

	# 1) 地面跳 / 土狼跳 / 缓冲跳：优先级最高
	var can_ground_jump := is_on_floor() or _coyote_timer > 0.0
	if _jump_buffer_timer > 0.0 and can_ground_jump:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_has_double_jumped = false
		return

	# 2) 二段跳：空中、土狼时间已过、尚未使用过二段跳
	if Input.is_action_just_pressed("jump") \
			and not is_on_floor() \
			and _coyote_timer <= 0.0 \
			and not _has_double_jumped:
		velocity.y = double_jump_velocity
		velocity.x *= 0.5   # 重置水平运动 或 = 0.0，视手感而定
		_has_double_jumped = true
		_is_double_jumping = true
		_jump_buffer_timer = 0.0          # 二段跳不应产生落地缓冲
		_current_anim = ANIM_DOUBLE_JUMP
		anim.play(ANIM_DOUBLE_JUMP)


# ---------------- 水平移动（带加速/摩擦） ----------------
func _handle_horizontal_movement(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	var target_speed := direction * max_speed

	var accel := acceleration if is_on_floor() else air_acceleration
	var fric := friction if is_on_floor() else air_friction

	if direction != 0.0:
		velocity.x = move_toward(velocity.x, target_speed, accel * delta)
		# 仅在存在输入方向时翻转，松键后保持最后朝向
		sprite.flip_h = direction < 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)

# ---------------- 冲刺 ----------------
func _handle_dash_input() -> void:
	if not Input.is_action_just_pressed("dash"):
		return
	if _dash_cooldown_timer > 0.0:
		return

	# 冲刺方向：优先取输入方向，无输入时沿当前面朝方向
	var direction := Input.get_axis("move_left", "move_right")
	if direction == 0.0:
		_dash_direction = -1.0 if sprite.flip_h else 1.0
	else:
		_dash_direction = direction
		sprite.flip_h = direction < 0.0

	_is_dashing = true
	_current_anim = ANIM_DASH
	anim.play(ANIM_DASH)

func _update_dash(delta: float) -> void:
	velocity.x = _dash_direction * dash_speed
	velocity.y = 0.0

func _end_dash() -> void:
	_is_dashing = false
	_dash_cooldown_timer = dash_cooldown
	_current_anim = ""  # 交还给动画状态机
	
	
# ---------------- 计时器更新（放在 move_and_slide 之后） ----------------
func _update_timers_after_move(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
		_has_double_jumped = false
		_is_double_jumping = false
	else:
		_coyote_timer = max(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)


# ---------------- 动画状态机 ----------------
func _update_animation() -> void:
	if _is_dashing:
		return
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

# ---------------- 二段跳动画结束回调 ----------------
func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == ANIM_DOUBLE_JUMP:
		_is_double_jumping = false
	elif anim_name == ANIM_DASH and _is_dashing:
		_end_dash()
