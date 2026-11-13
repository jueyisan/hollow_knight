extends GameplayAttributeSet
class_name SecondaryAttributeSet

@export var attribute_mappings: Dictionary[StringName,Dictionary] = {}

var _dependency_cache : Dictionary[StringName,Array] = {}

func instantiate_attributes() -> Dictionary:
	_init_cache()
	return super()
	
func _init_cache() -> void:
	_dependency_cache.clear()
	for sec_id in attribute_mappings:
		var primaries : Dictionary = attribute_mappings[sec_id]
		for prim_id in primaries:
			if not _dependency_cache.has(prim_id):
				_dependency_cache[prim_id] = []
			_dependency_cache[prim_id].append(sec_id)

func resolve_dependencies(comp: GameplayAttributeComponent) -> void:
	for sec_id in attribute_mappings:
		_recalculate_derived_attribute(comp, sec_id)


func on_attribute_changed(comp: GameplayAttributeComponent, attr_id: StringName, new_val: float) -> void:
	if not _dependency_cache.has(attr_id):
		return
	
	var affected_secondaries = _dependency_cache[attr_id]
	
	for sec_id in affected_secondaries:
		_recalculate_derived_attribute(comp, sec_id)


func _recalculate_derived_attribute(comp: GameplayAttributeComponent, sec_id: StringName) -> void:
	var initial_base := 0.0
	for attr_res in attributes:
		if attr_res.attribute_id == sec_id:
			initial_base = attributes[attr_res]
			break
			
	var bonus := 0.0
	var mapping : Dictionary = attribute_mappings[sec_id]
	
	for prim_id in mapping:
		var multiplier = mapping[prim_id]
		var prim_val = comp.get_value(prim_id)
		bonus += prim_val * multiplier
		
	comp.set_base_value(sec_id, initial_base + bonus)
