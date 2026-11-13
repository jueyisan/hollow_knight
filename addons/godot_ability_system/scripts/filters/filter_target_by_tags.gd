extends GameplayFilterData
class_name FilterTargetByTags

## 过滤器：通过标签筛选目标
## 用于筛选敌我、阵营、类型等

@export_group("Required Tags")
## 目标必须拥有的标签（所有标签都必须拥有）
@export var required_tags: Array[StringName] = []

@export_group("Blocked Tags")
## 目标不能拥有的标签（任意一个标签存在就会被过滤掉）
@export var blocked_tags: Array[StringName] = []

@export_group("Options")
## 是否包含继承的标签（默认 true）
@export var include_inherited: bool = true

func _check(target: Node, instigator: Node, context: Dictionary) -> bool:
	if not is_instance_valid(target):
		return false

	# 1. 检查必须标签（所有标签都必须拥有）
	if not required_tags.is_empty():
		if not TagManager.has_all_tags(target, required_tags, include_inherited):
			return false

	# 2. 检查阻止标签（任意一个标签存在就会被过滤）
	if not blocked_tags.is_empty():
		if TagManager.has_any_tag(target, blocked_tags, include_inherited):
			return false

	return true
