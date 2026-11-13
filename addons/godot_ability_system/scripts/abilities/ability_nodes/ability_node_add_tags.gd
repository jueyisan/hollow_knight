extends AbilityNodeBase
class_name AbilityNodeAddTags

enum CastTargetType{
	INSTIGATOR,			## 施法者
	TARGET,				## 目标
}

@export var cast_target_type : CastTargetType = CastTargetType.INSTIGATOR
@export var tag_list: Array[StringName]

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
		
		TagManager.add_tags(target,tag_list)

func _tick(instance: GAS_BTInstance, delta: float) -> int:
	return Status.SUCCESS
