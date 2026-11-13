extends AbilityCostBase
class_name VitalCost

## Vital 消耗器
## 消耗指定的 Vital（如魔法值、怒气、能量、生命值等）

@export_group("Vital Cost")
## 要消耗的 Vital ID（如 "mana", "rage", "energy", "health"）
@export var vital_id: StringName = &"mana"
## 消耗数量
@export var amount: float = 10.0
## 是否允许透支（如果为 false，必须完全满足才能消耗）
@export var allow_overdraft: bool = false
## vital组件的称
@export var vital_comp_name : StringName = "GameplayVitalAttributeComponent"

var _vital_comp: GameplayAttributeComponent = null

func _can_pay(ability_comp: Node, instigator: Node) -> bool:
	if not is_instance_valid(instigator):
		push_warning("VitalCost: Cannot find instigator")
		return false

	if not is_instance_valid(_vital_comp):
		_vital_comp = GameplayAbilitySystem.get_component_by_interface(instigator, vital_comp_name)
		if not is_instance_valid(_vital_comp):
			push_warning("VitalCost: Cannot find VitalComponent on instigator")
			return false

	# 检查是否有足够的 Vital
	if allow_overdraft:
		# 允许透支，只要有 Vital 就可以（即使不足）
		return _vital_comp.has_vital(vital_id) and _vital_comp.get_vital_value(vital_id) > 0.0
	else:
		# 不允许透支，必须完全满足
		return _vital_comp.has_sufficient_vital(vital_id, amount)

func _try_pay(ability_comp: Node, instigator: Node) -> bool:
	if not is_instance_valid(instigator):
		push_warning("VitalCost: Cannot find instigator")
		return false

	# 获取 Vital 组件
	if not is_instance_valid(_vital_comp):
		_vital_comp = GameplayAbilitySystem.get_component_by_interface(instigator, vital_comp_name)
		if not is_instance_valid(_vital_comp):
			push_warning("VitalCost: Cannot find VitalComponent on instigator")
			return false
	
	# 使用通用方法
	if allow_overdraft:
		# 允许透支，直接消耗（可能变成负数）
		_vital_comp.modify_vital(vital_id, -amount)
		return true
	else:
		# 不允许透支，使用 modify_vital（会自动检查）
		return _vital_comp.modify_vital(vital_id, -amount)

func _get_cost_description() -> String:
	var vital_name = vital_id

	if not is_instance_valid(_vital_comp):
		# 不在运行时调用时，不输出警告（可能是资源编辑时的正常调用）
		return "消耗 %s: %.0f" % [vital_name, amount]

	if not _vital_comp.has_vital(vital_id):
		return "消耗 %s: %.0f" % [vital_name, amount]

	# 尝试获取更友好的名称
	var vital : GameplayVital = _vital_comp.get_vital(vital_id)
	if not is_instance_valid(vital):
		return "消耗 %s: %.0f" % [vital_name, amount]
	vital_name = vital.display_name

	return "消耗 %s: %.0f" % [vital_name, amount]
