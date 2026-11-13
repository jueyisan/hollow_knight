extends DamageLogicStrategy
class_name SpellAttackDamageLogic

## ARPG 伤害计算策略
## 公式：(攻击力 - 防御力) * (1 + 暴击倍数 * 暴击率)

@export var attack_attribute: StringName = &"phy_attack"  ## 攻击力属性

func calculate(target: Node, instigator: Node, context: Dictionary) -> float:
	var attacker_comp = GameplayAbilitySystem.get_component_by_interface(instigator, "GameplayVitalAttributeComponent")
	if not is_instance_valid(attacker_comp):
		return 0.0
	
	var base_attack = attacker_comp.get_value(attack_attribute)
	var defense_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayVitalAttributeComponent")
	
	# 计算基础伤害
	var base_damage = max(1, base_attack)
	base_damage *= context.get("damage_multiplier", 1.0)
	base_damage *= context.get("damage_multiplier_modifier", 1.0)
	
	return base_damage
