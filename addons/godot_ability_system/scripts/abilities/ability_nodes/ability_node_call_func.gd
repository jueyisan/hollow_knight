extends AbilityNodeBase
class_name AbilityNodeCallFunc

enum CastTargetType{
	INSTIGATOR,			## 施法者
	TARGET,				## 目标
}

@export var cast_target_type : CastTargetType = CastTargetType.INSTIGATOR
@export var func_name: StringName = ""
@export var func_arg: Array = []

## [生命周期] 节点激活时调用（只跑一次）
func _enter(instance: GAS_BTInstance) -> void:
	# 1. 获取上下文和施法者
	var context = _get_context(instance)
	var final_targets : Array[Node] = []
	if cast_target_type == CastTargetType.INSTIGATOR:
		final_targets.append(context.get("instigator"))
	elif cast_target_type == CastTargetType.TARGET:
		final_targets.append_array(_get_target_list(instance, false))
	
	if final_targets.is_empty():
		return
	
	for target in final_targets:
		if not is_instance_valid(target):
			continue
		
		if not target.has_method(func_name):
			push_warning("AbilityNodeCallFunc: 方法 '%s' 在 AbilityInstance 上不存在。" % [func_name])
			continue

		if func_arg.is_empty():
			target.call(func_name)
		else:
			target.callv(func_name, func_arg)

func _tick(instance: GAS_BTInstance, delta: float) -> int:
	return Status.SUCCESS
