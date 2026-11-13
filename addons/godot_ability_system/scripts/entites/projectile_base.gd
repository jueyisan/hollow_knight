extends Area3D
class_name ProjectileBase

## 投射物基类
## 职责：运动控制、碰撞检测、弹头传递
##
## 设计原则（载具-弹头模式）：
## - 投射物是"载具"（Carrier），负责运输"弹头"（Payload：Status/Effect）
## - 投射物不包含能力逻辑（如伤害计算），只负责将弹头传递给目标
## - 在碰撞时，投射物将携带的弹头应用给目标
## - 通过信号系统通知外部系统（如技能系统），用于处理穿透、销毁等逻辑

# ========== 运行时配置（由 ProjectileData 注入）==========
## 飞行速度（单位/秒）
var speed: float = 0.0
## 最大生命周期（秒）
var max_lifetime: float = 5.0
## 追踪加速度（0 为直线，>0 为追踪）
## 值越大，转向越快
var homing_acceleration: float = 0.0

## 是否穿透（穿透时不会在撞击后销毁）
var piercing: bool = false
## 最大穿透次数（-1 为无限）
var max_pierce_count: int = -1

## 移动策略实例（由 ProjectileData 注入）
var movement_strategy: ProjectileMovementStrategy = null
## 撞击策略实例（由 ProjectileData 注入，控制命中时的行为，如链式传导等）
var impact_strategy: ProjectileImpactStrategy = null

# ========== 弹头舱（Payload Bay）==========
## 携带的状态列表（弹头）
## 当投射物击中目标时，会将此列表中的状态应用给目标
var payload_statuses: Dictionary[GameplayStatusData, int] = {}

# ========== 运行时数据（由 Ability 注入）==========
## 施法者（用于过滤碰撞，避免击中自己，以及作为弹头的施加者）
var instigator: Node = null
## 追踪目标（如果设置了，会追踪此目标）
var target_reference: Node3D = null

# ========== 内部状态 ==========
## 当前速度向量（策略类需要访问）
var velocity: Vector3 = Vector3.ZERO
## 穿透次数（由外部系统管理，投射物只提供访问接口）
var pierce_count: int = 0
var _timer: float = 0.0
## 保存技能执行时候的原始context
var _source_context: Dictionary = {}

# ========== 信号系统 ==========
## 投射物撞击时触发
## [param] hit_position: Vector3 撞击位置
## [param] direct_hit_target: Node 直接命中的目标（可选）
## [param] context: Dictionary 上下文信息
signal impact_triggered(hit_position: Vector3, direct_hit_target: Node, context: Dictionary)

## 投射物超时时触发
## [param] position: Vector3 超时位置
## [param] context: Dictionary 上下文信息
signal timeout_triggered(position: Vector3, context: Dictionary)

func _ready() -> void:
	# 设置碰撞层（投射物本身不在任何层，只检测其他层）
	collision_layer = 0
	# 注意：collision_mask 应该在场景中配置，或在子类中通过 @export 设置

	# 碰撞监听
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	# 1. 生命周期检查
	_timer += delta
	if _timer >= max_lifetime:
		timeout_triggered.emit(global_position, {"projectile": self})
		destroy()
		return
		
	# 2. 运动逻辑（策略模式）
	# 如果有策略，使用策略计算速度；否则保持初始速度（直线移动）
	if is_instance_valid(movement_strategy):
		var old_velocity = velocity
		velocity = movement_strategy.process_movement(self, delta)
		# 调试：如果速度异常，输出警告
		if velocity.length_squared() < 0.01 and old_velocity.length_squared() > 0.01:
			push_warning("ProjectileBase: Movement strategy returned zero velocity!")
	# 注意：如果没有策略，velocity 保持 initialize_velocity() 设置的初始值
	# 3. 应用位移
	global_position += velocity * delta
	# 4. 更新朝向（可选，让箭矢始终头朝前）
	if velocity.length_squared() > 0.01:
		look_at(global_position + velocity, Vector3.UP)

## 初始化速度向量
## 应该在 apply_to_projectile() 之后调用，确保 speed 已正确设置
func initialize_velocity() -> void:
	# 初始化方向（使用 -Z 轴作为前进方向，Godot 默认）
	var forward = global_transform.basis.z
	velocity = forward * speed
	if speed <= 0.0:
		push_warning("ProjectileBase: speed is %f, projectile may not move" % speed)

## 设置原始 context（由 AbilityNodeSpawnProjectile 调用）
func set_source_context(context: Dictionary) -> void:
	_source_context = context.duplicate()

## 销毁投射物（公共方法，由外部系统调用）
## 投射物不自动销毁，必须由外部系统（如 ProjectileAbility）调用此方法
## [param] on_hit: bool 是否因撞击而销毁（用于判断是否生成撞击魔法场）
func destroy() -> void:
	# 清理引用
	instigator = null
	target_reference = null
	movement_strategy = null
	payload_statuses.clear()

	# 销毁节点
	queue_free()
	
## 【核心】撞击结算
func _handle_impact(target: Node) -> void:
	# 1. 过滤检查
	if not _should_impact(target):
		return
	
	if not has_status_comp(target):
		destroy()
		return
		
	# 3. 获取撞击位置和方向
	var hit_pos = global_position  # 或者更精确的碰撞点
	var hit_dir = velocity.normalized() if velocity.length_squared() > 0.01 else Vector3.ZERO

	var should_consume: bool = true

	# 4. 如果配置了撞击策略，则交由策略处理
	if is_instance_valid(impact_strategy):
		should_consume = impact_strategy.on_impact(self, target, hit_pos, hit_dir)
	else:
		# 默认行为：传递 Payload，然后根据穿透配置决定是否销毁
		_deliver_payload(target, hit_pos, hit_dir)
		should_consume = _apply_piercing_logic()

	# 5. 发射撞击信号，通知外部系统（如技能系统）
	# 注意：投射物已经自己处理了穿透逻辑和销毁决策
	impact_triggered.emit(hit_pos, target, {
		"hit_direction": hit_dir,
		"projectile": self,
		"consumed": should_consume  # 告知外部系统是否已销毁
	})

	# 6. 如果应该消耗，销毁投射物
	if should_consume:
		destroy()

## 默认穿透逻辑（供默认撞击行为和自定义策略复用）
func _apply_piercing_logic() -> bool:
	var should_consume := true
	if piercing:
		if max_pierce_count < 0 or pierce_count < max_pierce_count:
			should_consume = false
			pierce_count += 1
	return should_consume

## 传递弹头（Payload）：将携带的状态和效果应用给目标
## [param] target: Node 目标实体（直接命中的目标）
## [param] hit_position: Vector3 撞击位置
## [param] hit_direction: Vector3 撞击方向
func _deliver_payload(target: Node, hit_position: Vector3, hit_direction: Vector3) -> void:
	if not is_instance_valid(target):
		return
	
	# 准备上下文信息
	var context = _source_context.duplicate()
	context.merge({
		"hit_position": hit_position,
		"hit_direction": hit_direction,
		"projectile": self,
		"input_target": target  # 直接命中的目标
	})
	# 应用状态（弹头）
	# 注意：状态会应用到目标，不处理目标检测（Status 只应用到自己）
	for status_data in payload_statuses:
		if not is_instance_valid(status_data):
			continue
		print("应用弹头状态： ", status_data.status_display_name)
		# 获取目标的状态组件
		var status_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayStatusComponent")
		if is_instance_valid(status_comp):
			# 应用状态（状态只应用到自己）
			status_comp.apply_status(status_data, instigator, payload_statuses[status_data], context)
		else:
			push_warning("ProjectileBase: Target %s has no GameplayStatusComponent, cannot apply status %s" % [target.name, status_data.status_id])

## 检查是否应该撞击此目标
func _should_impact(target: Node) -> bool:
	if not is_instance_valid(target):
		return false
	# 忽略施法者
	if is_instance_valid(instigator):
		# 直接比较
		if target == instigator:
			return false
	return true

func has_status_comp(target: Node) -> bool:
	var status_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayStatusComponent")
	if not is_instance_valid(status_comp):
		return false
	return true

func _on_body_entered(body: Node3D) -> void:
	_handle_impact(body)
