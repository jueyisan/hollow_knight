extends GameplayAbilityFeature
class_name ToggleFeature

## 检查是否可以激活（允许在技能已激活时重新激活）
func can_activate(ability: GameplayAbilityInstance, context: Dictionary) -> bool:
	# 如果技能已激活，说明这是关闭操作
	# 关闭操作应该跳过 cost 和 cooldown 检查
	if ability.is_active:
		context["skip_cost"] = true
		context["skip_cooldown"] = true
		return true
	# 如果技能未激活，这是正常的开启操作
	return true

## 在技能激活时处理切换逻辑
func on_activate(ability: GameplayAbilityInstance, context: Dictionary) -> void:
	var blackboard = ability.get_blackboard()
	if not is_instance_valid(blackboard):
		return
	# 检查是否是首次激活（开启操作）
	var is_first_activation = blackboard.get_var("is_first_activation", false)
	if is_first_activation:
		# 首次激活（开启操作），设置"开启"标记
		blackboard.set_var("toggle_action", "turn_on")
		# 清除标志，避免影响后续判断
		blackboard.erase_var("is_first_activation")
	else:
		# 关闭操作（技能已激活时再次激活）
		blackboard.set_var("toggle_action", "turn_off")
		# 重置行为树，准备执行关闭逻辑
		var bt_instance = ability.get_bt_instance()
		if is_instance_valid(bt_instance):
			bt_instance.reset_tree()
