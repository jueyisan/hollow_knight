extends GameplayAbilityFeature
class_name CheckTagFeature

@export var tag_list: Array[StringName]

func _init() -> void:
	super("CheckTagFeature")


func can_activate(ability_instance: GameplayAbilityInstance, context: Dictionary) -> bool:
	var instigator : CharacterBody3D = context.get("instigator", null)

	if not is_instance_valid(instigator):
		push_warning("can not found instigator")
		return false
		
	if instigator.is_on_floor() == false:
		return false	

	if TagManager.has_any_tag(instigator, tag_list) == true:
		return false

	return true
