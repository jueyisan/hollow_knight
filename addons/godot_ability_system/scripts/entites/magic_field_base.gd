extends Area3D
class_name MagicFieldBase

## 魔法场基类（区域效果载具）
## 职责：区域检测、弹头传递、生命周期管理
##
## 设计原则（载具-弹头模式）：
## - 魔法场是"载具"（Carrier），负责在指定位置持续检测目标
## - 魔法场不包含能力逻辑（如伤害计算），只负责将弹头传递给目标
## - 使用 Area3D 的事件驱动机制（body_entered/body_exited）维护目标列表
## - 周期性或事件触发时，将携带的弹头应用给目标

# ========== 运行时数据（由 Ability 注入）==========
## 施法者（用于过滤碰撞，避免击中自己，以及作为弹头的施加者）
var instigator: Node = null

# ========== 弹头舱（Payload Bay）==========
## 携带的状态列表（弹头）
## 当目标进入区域或周期性触发时，会将此列表中的状态应用给目标
var payload_statuses: Dictionary[GameplayStatusData, int] = {}

# ========== 内部状态 ==========
## 当前区域内的目标列表（维护状态句柄映射）
## 格式：{target: [status_id, ...]}
var _targets_in_area: Dictionary[Node, Array] = {}

# ========== 配置（由 MagicFieldData 注入）==========
## 持续时间（秒，-1 为永久）
var duration: float = 5.0
## 周期性触发间隔（秒）
## - 如果 > 0：魔法场会周期性触发，每次触发时对范围内的所有目标应用 payload_statuses
## - 如果 <= 0：单位进入范围时立即应用 payload_statuses，退出时移除
var periodic_trigger_interval: float = 0.0
## 目标选择模式（适用于所有触发模式）
var target_selection_mode: int = 2  # TargetSelectionMode.ALL
## 目标数量（-1 为全部，仅在 RANDOM 和 NEAREST 模式下有效）
var target_count: int = -1
## 目标获取策略（可选）
var targeting_strategy: TargetingStrategy = null

# ========== 内部定时器 ==========
var _periodic_timer: Timer = null

func _ready() -> void:
	# 连接 Area3D 信号（事件驱动）
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# 如果配置了持续时间，启动销毁计时器
	if duration > 0.0:
		var timer = get_tree().create_timer(duration)
		timer.timeout.connect(_on_duration_timeout)

	# 如果配置了周期性触发间隔，启动周期性触发定时器
	if periodic_trigger_interval > 0.0:
		_create_periodic_timer()

## 销毁魔法场（公共方法）
func destroy() -> void:
	# 移除所有目标身上的状态
	for target in _targets_in_area.keys():
		if is_instance_valid(target):
			_remove_payload_from_target(target)

	_targets_in_area.clear()

	# 停止周期性触发定时器
	if is_instance_valid(_periodic_timer):
		_periodic_timer.queue_free()
		_periodic_timer = null

	# 清理引用
	instigator = null
	payload_statuses.clear()
	_targets_in_area.clear()
	
	# 销毁节点
	queue_free()

## 创建周期性触发定时器
func _create_periodic_timer() -> void:
	if periodic_trigger_interval <= 0.0:
		return

	_periodic_timer = Timer.new()
	_periodic_timer.name = "PeriodicTriggerTimer"
	_periodic_timer.wait_time = periodic_trigger_interval
	_periodic_timer.one_shot = false
	_periodic_timer.timeout.connect(_on_periodic_trigger)
	add_child(_periodic_timer)
	_periodic_timer.start()

## 应用弹头（Payload）到目标
func _apply_payload_to_target(target: Node) -> void:
	if not is_instance_valid(target):
		push_warning("MagicFieldBase: Target is not valid, cannot apply payload to target %s" % target.name)
		return

	if not is_instance_valid(instigator):
		push_warning("MagicFieldBase: Instigator is not valid, cannot apply payload to target %s" % target.name)

	# 准备上下文信息
	var context = {
		"field_position": global_position,
		"field": self
	}
	
	var status_handles: Array[StringName] = []
	# 应用状态
	for status_data in payload_statuses:
		if not is_instance_valid(status_data):
			push_warning("MagicFieldBase: Status data is not valid, cannot apply status %s" % status_data.status_id)
			continue

		# 获取目标的状态组件
		var status_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayStatusComponent")
		if is_instance_valid(status_comp):
			# 应用状态（状态系统会处理目标筛选和应用效果）
			var status_instance = status_comp.apply_status(status_data, instigator, payload_statuses[status_data], context)
			if is_instance_valid(status_instance):
				status_handles.append(status_data.status_id)
		else:
			push_warning("MagicFieldBase: Target %s has no GameplayStatusComponent, cannot apply status %s" % [target.name, status_data.status_id])

	# 记录状态句柄（用于离开时移除）
	if _targets_in_area.has(target):
		_targets_in_area[target] = status_handles

## 移除目标身上的弹头（Payload）
func _remove_payload_from_target(target: Node) -> void:
	if not is_instance_valid(target):
		return

	# 获取状态句柄
	var status_handles = _targets_in_area.get(target, [])

	# 获取目标的状态组件
	var status_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayStatusComponent")
	if not is_instance_valid(status_comp):
		push_error("MagicFieldBase: status component is not valid!")
		return
	# 移除所有记录的状态
	for status_id in status_handles:
		status_comp.remove_status(status_id)

## 检查是否应该影响此目标
func _should_affect(target: Node) -> bool:
	if not is_instance_valid(target):
		return false

	# 只检查目标是否有状态组件（魔法场需要应用状态）
	var status_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayStatusComponent")
	if not is_instance_valid(status_comp):
		return false

	return true

## 根据目标选择模式获取目标列表
func _select_targets_by_mode() -> Array[Node3D]:
	var selected_targets: Array[Node3D] = []
	match target_selection_mode:
		0:  # RANDOM
			selected_targets = _get_random_targets(target_count)
		1:  # NEAREST
			selected_targets = _get_nearest_targets(target_count)
		2:  # ALL
			selected_targets = _get_all_targets()
		_:
			push_warning("MagicFieldBase: Unknown target_selection_mode: %d, using ALL" % target_selection_mode)
			selected_targets = _get_all_targets()
	
	return selected_targets

## 【传感器接口】获取当前区域内的所有目标
func _get_all_targets() -> Array[Node3D]:
	var final_targets : Array[Node3D] = []
	# 如果配置了 targeting_strategy，使用策略获取目标（支持筛选器）
	if is_instance_valid(targeting_strategy):
		return _get_targets_via_strategy()

	# 默认逻辑：使用 Area3D 的 overlapping 方法（事件驱动，更高效）
	var bodies = get_overlapping_bodies()

	# 如果检测到目标，使用事件驱动方法
	if not bodies.is_empty():
		final_targets = _get_targets_from_overlapping(bodies)

	return final_targets

## 通过 TargetingStrategy 获取目标
func _get_targets_via_strategy() -> Array[Node3D]:
	var final_targets : Array[Node3D] = []
	if not is_instance_valid(targeting_strategy):
		return final_targets
	
	if not is_instance_valid(instigator):
		push_warning("MagicFieldBase: Cannot use targeting_strategy, instigator is not valid")

	# 构建上下文信息
	var context = {
		"field_position": global_position,
		"detection_position": global_position,
		"field": self,
		"instigator": instigator,
	}

	# 使用策略解析目标（策略会自动应用筛选器）
	var targets = targeting_strategy.resolve_targets(instigator, null, context)
	# 转换为 Node3D 数组（过滤掉非 Node3D 的目标）
	var valid_targets: Array[Node3D] = []
	for target in targets:
		if not is_instance_valid(target):
			continue
		if target is Node3D:
			valid_targets.append(target as Node3D)

	return valid_targets

## 从 overlapping 列表获取目标（事件驱动方法）
func _get_targets_from_overlapping(bodies: Array) -> Array[Node3D]:
	var all_colliders: Array[Node3D] = []
	# 收集所有碰撞体
	for body : Node3D in bodies:
		if is_instance_valid(body) and body.is_in_group("Entities"):
			all_colliders.append(body)

	return all_colliders

## 【传感器接口】获取随机目标
func _get_random_targets(count: int = -1) -> Array[Node3D]:
	var all_targets = _get_all_targets()
	if all_targets.is_empty():
		return all_targets
	
	# 如果 count < 0 或 count >= 总数，返回所有目标
	if count < 0 or count >= all_targets.size():
		return all_targets

	# 随机选择指定数量的目标
	var selected: Array[Node3D] = []
	var available = all_targets.duplicate()

	for i in range(count):
		if available.is_empty():
			break
		var random_index = randi() % available.size()
		selected.append(available[random_index])
		available.remove_at(random_index)
	return selected

## 【传感器接口】获取指定数量的目标（按距离排序，最近的优先）
func _get_nearest_targets(count: int = -1) -> Array[Node3D]:
	var all_targets = _get_all_targets()
	if all_targets.is_empty():
		return all_targets
	
	# 计算每个目标的距离
	var targets_with_distance: Array[Dictionary] = []
	for target in all_targets:
		if not target is Node3D:
			continue

		var target_3d = target as Node3D
		var distance = global_position.distance_to(target_3d.global_position)
		targets_with_distance.append({
			"target": target,
			"distance": distance
		})

	# 按距离排序
	targets_with_distance.sort_custom(func(a, b): return a["distance"] < b["distance"])

	# 提取目标列表
	var sorted_targets: Array[Node3D] = []
	for item in targets_with_distance:
		sorted_targets.append(item["target"])

	# 如果 count < 0 或 count >= 总数，返回所有目标
	if count < 0 or count >= sorted_targets.size():
		return sorted_targets

	# 返回前 count 个
	return sorted_targets.slice(0, count)

## 目标进入区域
func _on_body_entered(body: Node3D) -> void:
	var target = body
	if not is_instance_valid(target):
		return
		
	# 过滤检查
	if not _should_affect(target):
		return
	
	# 根据触发模式决定是否立即应用状态
	if periodic_trigger_interval > 0.0:
		# 周期性触发模式：只维护目标列表，不立即应用状态
		# 状态会在周期性触发时应用
		_targets_in_area[target] = []
	else:
		# 立即触发模式：进入时立即应用状态
		_apply_payload_to_target(target)

## 目标离开区域
func _on_body_exited(body: Node3D) -> void:
	var target = body
	if not is_instance_valid(target):
		return

	if _targets_in_area.has(target):
		_remove_payload_from_target(target)
		_targets_in_area.erase(target)

## 周期性触发
func _on_periodic_trigger() -> void:
	if not is_instance_valid(instigator):
		push_warning("MagicFieldBase: Instigator is not valid, cannot apply periodic effects.")

	# 根据目标选择模式获取目标
	var selected_targets = _select_targets_by_mode()
	if selected_targets.is_empty():
		return

	# 对每个目标应用 payload_statuses
	for target in selected_targets:
		if not is_instance_valid(target):
			continue

		# 过滤检查
		if not _should_affect(target):
			continue

		# 应用弹头（Payload）
		_apply_payload_to_target(target)

## 持续时间到期
func _on_duration_timeout() -> void:
	# 移除所有目标身上的状态
	for target in _targets_in_area.keys():
		if is_instance_valid(target):
			_remove_payload_from_target(target)

	_targets_in_area.clear()

	# 销毁魔法场
	destroy()
