extends GameplayAbilityFeature
class_name CheckVariableFeature

@export var var_list: Dictionary = {}

##判断指定变量是否等于设置的值

func _init() -> void:
	super("CheckVariableFeature")


func can_activate(ability_instance: GameplayAbilityInstance, context: Dictionary) -> bool:
	var instigator : CharacterBody3D = context.get("instigator", null)

	if not is_instance_valid(instigator):
		push_warning("can not found instigator")
		return false
		
	if instigator.is_on_floor() == false:
		return false	

	for key in var_list:
		if instigator.get(key) != var_list[key]:
			return false

	return true
