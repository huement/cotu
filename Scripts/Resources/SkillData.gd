# res://Scripts/Resources/SkillData.gd
extends Resource
class_name SkillData

enum SkillCategory { COMBAT, SUBTERFUGE, ACADEMIC, GENERAL }

@export var skill_id: StringName
@export var skill_name: String
@export var category: SkillCategory = SkillCategory.GENERAL
@export var description: String
@export var icon: Texture2D

@export_group("Progression")
@export var base_percentage: int = 5
@export var max_percentage: int = 95
