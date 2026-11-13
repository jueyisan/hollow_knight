extends DamageLogicStrategy
class_name SimpleDamageLogic

## ARPG 伤害计算策略
## 公式：(攻击力 - 防御力) * (1 + 暴击倍数 * 暴击率)

@export var attack_attribute: StringName = &"phy_attack"  ## 攻击力属性
@export var defense_attribute: StringName = &"defense"   ## 防御力属性
@export var crit_rate_attribute: StringName = &"crit_rate"  ## 暴击率属性
@export var crit_multiplier: float = 2.0  ## 暴击倍数

func calculate(target: Node, instigator: Node, context: Dictionary) -> float:
	var attacker_comp = GameplayAbilitySystem.get_component_by_interface(instigator, "GameplayVitalAttributeComponent")
	if not is_instance_valid(attacker_comp):
		return 0.0
	
	var base_attack = attacker_comp.get_value(attack_attribute)
	var defense_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayVitalAttributeComponent")
	var defense = defense_comp.get_value(defense_attribute)
	
	# 计算基础伤害
	var base_damage = max(1, base_attack - defense)
	base_damage *= context.get("damage_multiplier", 1.0)
	base_damage *= context.get("damage_multiplier_modifier", 1.0)
	
	return base_damage
