extends Resource
class_name GameplayAttributeSet

## 属性集合配置
## 格式：{ GameplayAttribute资源 : 初始值 float }

## 属性集合配置（固定值）
## 格式：{ GameplayAttribute资源 : 初始值 float }
@export var attributes: Dictionary[GameplayAttribute, float] = {}

## 属性集合配置（可扩展值）
## 格式：{ GameplayAttribute资源 : ScalableValue资源 }
## 如果属性在此字典中，则使用 ScalableValue 计算数值，忽略 attributes 中的固定值
@export var scalable_attributes: Dictionary[GameplayAttribute, ScalableValue] = {}

## 实例化属性
## 将资源配置转换为运行时实例
## [return] Dictionary[StringName, GameplayAttributeInstance] 属性实例字典
func instantiate_attributes() -> Dictionary[StringName, GameplayAttributeInstance]:
	var instances : Dictionary[StringName, GameplayAttributeInstance] = {}
	
	# 优先使用 scalable_attributes（如果存在）
	for attr_res in scalable_attributes:
		var scalable_val = scalable_attributes[attr_res]
		instances[attr_res.attribute_id] = GameplayAttributeInstance.new(attr_res, 0.0, scalable_val)

	# 处理固定值属性（如果不在 scalable_attributes 中）
	for attr_res in attributes:
		# 如果已经在 scalable_attributes 中处理过，跳过
		if scalable_attributes.has(attr_res):
			continue

		var init_val = attributes[attr_res]
		instances[attr_res.attribute_id] = GameplayAttributeInstance.new(attr_res, init_val, attr_res.scalable_value)
		
	return instances

## [钩子] 当组件初始化完毕，所有属性都创建好之后调用
## 用于计算初始的衍生属性（在后续章节中实现）
## [param] comp: GameplayAttributeComponent 属性组件
func resolve_dependencies(comp: GameplayAttributeComponent) -> void: pass

## [钩子] 当任何属性值发生变化时调用
## 用于实时更新衍生属性（在后续章节中实现）
## [param] comp: GameplayAttributeComponent 属性组件
## [param] attr_id: StringName 变化的属性ID
## [param] new_val: float 新值
func on_attribute_changed(comp: GameplayAttributeComponent, attr_id: StringName, new_val: float) -> void:pass
