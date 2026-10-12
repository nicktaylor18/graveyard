class_name RecipeDefinition
extends Resource
## Shared fabrication and research/building definition. IDs are save-file keys.
@export var id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export var category: String = "Equipment"
@export var scans_required: int = 0
@export var cost: Dictionary = {}
@export var prerequisites: Array[String] = []
@export var build_type: String = "equipment"
@export var result_scene: PackedScene
@export var production: float = 0.0
@export var demand: float = 0.0
