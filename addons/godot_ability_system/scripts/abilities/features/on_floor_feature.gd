extends GameplayAbilityFeature
class_name OnFloorFeature

func _init() -> void:
	super("OnFloorFeature")


func can_activate(ability_instance: GameplayAbilityInstance, context: Dictionary) -> bool:
	var instigator : CharacterBody3D = context.get("instigator", null)

	if not is_instance_valid(instigator):
		push_warning("can not found instigator")
		return false
		
	if instigator.is_on_floor() == false:
		return false	

	return true
