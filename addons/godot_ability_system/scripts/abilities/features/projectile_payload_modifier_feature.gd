extends GameplayAbilityFeature
class_name ProjectilePayloadModifierFeature

## 天赋投射物弹头修改器 Feature
## 在技能激活时，将弹头状态替换信息写入 context
## AbilityNodeSpawnProjectile 会从 context 读取并应用替换

## 弹头状态替换映射 {原状态ID: 新状态数据}
var payload_status_replacements: Dictionary[StringName, GameplayStatusData] = {}

## 技能激活时调用func on_activate(ability: GameplayAbilityInstance, context: Dictionary) -> void:
func on_activate(ability: GameplayAbilityInstance, context: Dictionary) -> void:
	if not is_instance_valid(ability):
		return

	# 将替换信息写入 context
	if not payload_status_replacements.is_empty():
		if not context.has("projectile_payload_replacements"):
			context["projectile_payload_replacements"] = {}
		var replacements = context["projectile_payload_replacements"] as Dictionary
		for old_status_id in payload_status_replacements:
			var new_status = payload_status_replacements[old_status_id]
			if is_instance_valid(new_status):
				replacements[old_status_id] = new_status
				context["projectile_payload_replacements"] = replacements
		print("TalentProjectilePayloadModifierFeature: Applied payload replacements for %d statuses" % replacements.size())
