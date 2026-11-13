extends GameplayEffect
class_name GE_SpawnMagicField

## 生成魔法阵效果

@export_group("Magic Field Config")
## 魔法阵数据（包含场景、持续时间、周期等配置）
@export var magic_field_data: MagicFieldData = null
@export var position_key: String = "projectile_impact"
## 是否挂载到目标身上（true：作为目标的子节点；false：添加到场景根节点）
@export var attach_to_target: bool = false
@export var target_key: String = "targets"

func _apply(target: Node, instigator: Node, context: Dictionary)  -> void:
	if not is_instance_valid(magic_field_data):
		push_warning("AbilityNodeSpawnMagicField: magic_field_data is not set!")
		return
	# 检查魔法阵场景
	if not is_instance_valid(magic_field_data.magic_field_scene):
		push_warning("AbilityNodeSpawnMagicField: magic_field_scene is not set in magic_field_data!")
		return
	
	# 获取生成位置
	var spawn_position = _get_spawn_position(context)
	if spawn_position == Vector3.INF:
		push_warning("AbilityNodeSpawnMagicField: Cannot determine spawn position!")
		return
	
	# 生成魔法阵
	_spawn_magic_field(instigator, target, spawn_position, magic_field_data, context)

## 生成魔法阵
func _spawn_magic_field(
		instigator: Node,
		target: Node,
		spawn_position: Vector3,
		data: MagicFieldData,
		context: Dictionary) -> void:
	var magic_field = data.magic_field_scene.instantiate()

	# 类型检查
	if not magic_field is MagicFieldBase:
		push_error("AbilityNodeSpawnMagicField: magic_field_scene must be a MagicFieldBase, got: %s" % magic_field.get_class())
		magic_field.queue_free()
		return

	var magic_field_base = magic_field as MagicFieldBase

	# 注入运行时依赖
	magic_field_base.instigator = instigator
	# 应用魔法阵数据
	data.apply_to_magic_field(magic_field_base)

	# 添加到场景或目标
	if attach_to_target:
		# 挂载到目标身上（作为子节点）
		target.add_child(magic_field_base)
		# 设置本地位置（相对于目标）
		magic_field_base.position = Vector3.ZERO  # 魔法阵在目标位置
	else:
		# 添加到场景根节点
		var level_root = instigator.get_tree().current_scene
		if not is_instance_valid(level_root):
			push_error("AbilityNodeSpawnMagicField: Cannot find current scene root")
			magic_field_base.queue_free()
			return
		level_root.add_child(magic_field_base)
		# 设置世界位置
		magic_field_base.global_position = spawn_position

## 获取生成位置
func _get_spawn_position(context: Dictionary) -> Vector3:
	if context.has(position_key) and context[position_key] is Vector3:
		var hit_pos = context[position_key] as Vector3
		return hit_pos
	return Vector3.INF
