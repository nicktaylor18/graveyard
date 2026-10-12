class_name StationModule
extends Node2D

var data: Dictionary = {}
var state: GameState
var assembly: float = 0.0
var time: float = 0.0

func _ready() -> void:
	# Four open docking ports/airlocks; solid armored corner sections.
	for side in range(4):
		for offset in [-77.0, 77.0]:
			var body := StaticBody2D.new()
			body.position = Vector2(offset, -108).rotated(side * PI / 2)
			body.rotation = side * PI / 2
			body.collision_layer = 1
			body.collision_mask = 2
			var collision := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = Vector2(62, 10)
			collision.shape = shape
			body.add_child(collision)
			add_child(body)

func _process(delta: float) -> void:
	assembly = minf(1.0, assembly + delta / 1.8)
	time += delta
	modulate.a = 0.25 + 0.75 * assembly
	queue_redraw()

func _draw() -> void:
	if data.is_empty():
		return
	var status: Dictionary = state.network.get(data.id, {})
	draw_set_transform(Vector2.ZERO, int(data.rotation) * PI / 2)
	IndustrialArt.station(self, data.recipe, status.get("powered", false), status.get("habitable", false), time)
	if assembly < 1.0:
		draw_rect(Rect2(-112, -112 + assembly * 224, 224, 3), IndustrialArt.CYAN)
