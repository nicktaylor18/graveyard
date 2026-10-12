class_name Battlefield
extends Node2D

var state: GameState
var camera: Camera2D
var player: CharacterBody2D
var objects: Array[Dictionary] = GameData.objects()
var wrecks: Array[Dictionary] = GameData.wrecks()
var wall_rects: Array[Rect2] = []
var debris: Array[Dictionary] = []
var hazards: Array[Dictionary] = [
	{"position": GameData.pixels(Vector2(97, 31)), "radius": 51.0, "phase": 0.0},
	{"position": GameData.pixels(Vector2(217, -105)), "radius": 77.0, "phase": 1.1},
]
var selected: Dictionary = {}
var time: float = 0.0
var beam: Vector2 = Vector2.INF
var beam_color := IndustrialArt.CYAN
var module_nodes: Dictionary = {}
var preview_id: String = ""
var preview_cell := Vector2i.ZERO
var preview_valid: bool = false
var preview_rotation: int = 0

func _ready() -> void:
	for wreck in wrecks:
		create_hull(wreck)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91173
	for i in range(440):
		var pos := Vector2(rng.randf_range(-8200, 8200), rng.randf_range(-5500, 5500))
		if i < 100:
			var anchor: Dictionary = wrecks[i % 3]
			pos = anchor.position + Vector2(rng.randf_range(-900, 900), rng.randf_range(-700, 700))
		debris.append({"position": pos, "size": rng.randf_range(9, 42), "angle": rng.randf_range(0, TAU), "spin": rng.randf_range(-0.04, 0.04), "shade": rng.randf_range(0.12, 0.28)})
	sync_modules(true)

func create_hull(wreck: Dictionary) -> void:
	var center: Vector2 = wreck.position
	var size: Vector2 = wreck.size
	var left: float = center.x - size.x / 2
	var top: float = center.y - size.y / 2
	var bottom: float = top + size.y
	add_wall(Rect2(left, top, size.x, 20))
	add_wall(Rect2(left, top, 20, size.y))
	add_wall(Rect2(left + size.x - 20, top, 20, size.y))
	# Southern breach is wide enough for EVA and marked with amber edge lights.
	var breach_x: float = center.x - size.x * 0.24
	add_wall(Rect2(left, bottom - 20, breach_x - left - 85, 20))
	add_wall(Rect2(breach_x + 85, bottom - 20, left + size.x - breach_x - 85, 20))
	if wreck.id != "fighter":
		for ratio in [0.34, 0.66]:
			var x: float = left + size.x * ratio
			add_wall(Rect2(x, top, 16, size.y * 0.5 - 66))
			add_wall(Rect2(x, center.y + 66, 16, size.y * 0.5 - 66))

func add_wall(rect: Rect2) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	wall_rects.append(rect)
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = 1
	body.collision_mask = 2
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	add_child(body)

func sync_modules(instant: bool = false) -> void:
	for child in module_nodes.values():
		child.queue_free()
	module_nodes.clear()
	for data in state.modules:
		var recipe: RecipeDefinition = state.recipes[data.recipe]
		var node: StationModule = recipe.result_scene.instantiate()
		node.data = data
		node.state = state
		node.position = Vector2(float(data.x), float(data.y)) * GameData.GRID
		node.assembly = 1.0 if instant else 0.0
		add_child(node)
		module_nodes[data.id] = node

func add_latest_module() -> void:
	var data: Dictionary = state.modules.back()
	var node: StationModule = state.recipes[data.recipe].result_scene.instantiate()
	node.data = data
	node.state = state
	node.position = Vector2(float(data.x), float(data.y)) * GameData.GRID
	add_child(node)
	module_nodes[data.id] = node

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func on_surface(pos: Vector2) -> bool:
	for wreck in wrecks:
		if Rect2(wreck.position - wreck.size / 2, wreck.size).grow(-20).has_point(pos):
			return true
	if pos.length() < 95:
		return true
	for module in state.modules:
		var center := Vector2(float(module.x), float(module.y)) * GameData.GRID
		if Rect2(center - Vector2(108, 108), Vector2(216, 216)).has_point(pos):
			return true
	return false

func line_of_sight(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func nearest(pos: Vector2, radius: float, aim: Vector2 = Vector2.INF, kinds: Array = []) -> Dictionary:
	var best: Dictionary = {}
	var score: float = INF
	for object in objects:
		if not kinds.is_empty() and object.kind not in kinds:
			continue
		if object.id in state.depleted:
			continue
		var distance: float = pos.distance_to(object.position)
		if distance > radius or not line_of_sight(pos, object.position):
			continue
		var ranking: float = distance
		if aim != Vector2.INF:
			ranking = aim.distance_to(object.position)
			if ranking > 90:
				continue
		if ranking < score:
			score = ranking
			best = object
	return best

func placement_reason(cell: Vector2i, id: String, pos: Vector2) -> String:
	var center := Vector2(cell) * GameData.GRID
	if pos.distance_to(center) > 650:
		return "Outside builder range / 23m"
	if not state.unlocked(id):
		return "Blueprint not researched"
	if not state.can_afford(id):
		return "Insufficient materials"
	if cell == Vector2i.ZERO or not state.module_at(cell).is_empty():
		return "Occupied grid cell"
	if not state.connected_cell(cell):
		return "Attach to pod or a station module"
	var bounds := Rect2(center - Vector2(120, 120), Vector2(240, 240))
	if bounds.has_point(pos):
		return "Step outside the assembly footprint"
	for wreck in wrecks:
		if bounds.intersects(Rect2(wreck.position - wreck.size / 2, wreck.size).grow(35)):
			return "Wreck geometry blocks construction"
	if absf(center.x) > 8400 or absf(center.y) > 5600:
		return "Outside battlefield"
	return "VALID / LMB assembles / R rotates / RMB cancels"

func hazard_active(hazard: Dictionary) -> bool:
	return fmod(time + float(hazard.phase), 4.8) > 3.0

func _draw() -> void:
	if camera == null:
		return
	var visible_size := get_viewport_rect().size / camera.zoom
	var bounds := Rect2(camera.global_position - visible_size / 2, visible_size).grow(350)
	var detailed := camera.zoom.x > 0.6
	for fragment in debris:
		if not bounds.has_point(fragment.position):
			continue
		draw_set_transform(fragment.position, fragment.angle + time * fragment.spin)
		var size: float = fragment.size
		IndustrialArt.plate(self, Rect2(-size / 2, -size / 3, size, size * 0.6), Color(fragment.shade, fragment.shade * 1.09, fragment.shade * 1.15), detailed)
		if detailed:
			draw_line(Vector2(-size / 3, 0), Vector2(size / 3, 0), Color("626762"), 2)
	draw_set_transform(Vector2.ZERO)
	for wreck in wrecks:
		if bounds.intersects(Rect2(wreck.position - wreck.size / 2, wreck.size).grow(130)):
			draw_wreck(wreck, detailed)
	draw_pod()
	for object in objects:
		if object.id == "pod" or object.id in state.depleted or not bounds.has_point(object.position):
			continue
		draw_set_transform(object.position)
		match object.kind:
			"fragment":
				IndustrialArt.machinery(self, object.payload, state.scans.has(object.id), time)
			"container":
				IndustrialArt.plate(self, Rect2(-23, -17, 46, 34), Color("68624f"))
				draw_rect(Rect2(-15, -13, 30, 26), Color("343d40"), false, 3)
				draw_rect(Rect2(-5, -18, 10, 36), Color("ad9665"))
			"salvage":
				IndustrialArt.plate(self, Rect2(-35, -27, 70, 54), Color("494f50"))
				draw_circle(Vector2(-10, 0), 18, Color("1c252e"))
				draw_arc(Vector2(-10, 0), 13, 0, TAU, 18, Color("828275"), 5)
				for y in range(-17, 18, 7):
					draw_line(Vector2(15, y), Vector2(29, y), Color("151c23"), 3)
			"log", "signal":
				IndustrialArt.plate(self, Rect2(-20, -16, 40, 32), Color("3f5157"))
				draw_rect(Rect2(-14, -11, 23, 17), IndustrialArt.CYAN.darkened(0.2))
				draw_circle(Vector2(15, 8), 3, IndustrialArt.AMBER)
		if object.kind == "fragment" and not state.scans.has(object.id):
			draw_arc(Vector2.ZERO, 53, time * 0.2, time * 0.2 + PI * 0.75, 20, Color(0.68, 0.72, 0.62, 0.4), 1)
		if selected.get("id", "") == object.id:
			var color := IndustrialArt.CYAN
			for corner in [Vector2(-54, -43), Vector2(54, -43), Vector2(-54, 43), Vector2(54, 43)]:
				draw_line(corner, corner + Vector2(-signf(corner.x) * 12, 0), color, 2)
				draw_line(corner, corner + Vector2(0, -signf(corner.y) * 12), color, 2)
		draw_set_transform(Vector2.ZERO)
	for hazard in hazards:
		if not bounds.has_point(hazard.position):
			continue
		draw_set_transform(hazard.position)
		draw_circle(Vector2.ZERO, hazard.radius, Color(0.55, 0.28, 0.08, 0.10))
		draw_arc(Vector2.ZERO, hazard.radius, 0, TAU, 32, Color(0.8, 0.5, 0.24, 0.5), 2)
		if hazard_active(hazard):
			var points := PackedVector2Array()
			for i in range(10):
				points.append(Vector2(-hazard.radius + i * hazard.radius * 2 / 9, sin(time * 47 + i * 3) * 22))
			draw_polyline(points, Color(0.6, 0.8, 0.92, 0.25), 10)
			draw_polyline(points, Color("d2eef1"), 2)
		else:
			IndustrialArt.text(self, Vector2(-48, -hazard.radius - 7), "ARC / CYCLING", 12, IndustrialArt.AMBER)
	draw_set_transform(Vector2.ZERO)
	if beam != Vector2.INF and player != null:
		draw_line(player.global_position, beam, Color(beam_color, 0.13), 14)
		draw_line(player.global_position, beam, Color(beam_color, 0.7), 2)
		for i in range(9):
			var angle := time * 7 + i * 2.399
			var offset := Vector2.from_angle(angle) * fmod(time * 32 + i * 7, 45)
			draw_circle(beam + offset, 1.5, Color(beam_color, 0.8))
	if not preview_id.is_empty():
		draw_set_transform(Vector2(preview_cell) * GameData.GRID, preview_rotation * PI / 2)
		var tint := Color(0.3, 0.8, 0.6, 0.3) if preview_valid else Color(0.85, 0.28, 0.23, 0.3)
		draw_rect(Rect2(-120, -120, 240, 240), tint)
		draw_rect(Rect2(-120, -120, 240, 240), Color(tint, 0.8), false, 3)
		IndustrialArt.station(self, preview_id, preview_valid, false, time)
	draw_set_transform(Vector2.ZERO)

func draw_wreck(wreck: Dictionary, detailed: bool) -> void:
	var size: Vector2 = wreck.size
	var half := size / 2
	draw_set_transform(wreck.position)
	# Armored spine, exposed ribs, engine bells and a pointed bow give a real ship silhouette.
	draw_colored_polygon(PackedVector2Array([Vector2(-half.x - 55, -half.y * 0.6), Vector2(-half.x + 70, -half.y - 28), Vector2(half.x - 50, -half.y - 16), Vector2(half.x + 100, 0), Vector2(half.x - 45, half.y + 18), Vector2(-half.x - 55, half.y * 0.6)]), wreck.tone.darkened(0.23))
	for y in [-half.y * 0.55, half.y * 0.55]:
		IndustrialArt.plate(self, Rect2(-half.x - 100, y - 33, 115, 66), Color("2b333b"))
		for x in range(7):
			draw_line(Vector2(-half.x - 90 + x * 12, y - 24), Vector2(-half.x - 90 + x * 12, y + 24), Color("697072"), 3)
	draw_rect(Rect2(-half, size), Color("151e27"))
	var step: int = 48 if detailed else 96
	for x in range(int(-half.x + 24), int(half.x - 24), step):
		for y in range(int(-half.y + 24), int(half.y - 24), step):
			var shade: float = 0.135 + (sin(x * 5.12 + y * 7.82) + 1) * 0.018
			draw_rect(Rect2(x, y, step - 2, step - 2), Color(shade, shade * 1.16, shade * 1.3))
			if detailed:
				draw_line(Vector2(x + 5, y + 5), Vector2(x + 17, y + 5), Color("4b5357"), 1)
	# Scorched deck stains and exposed cables.
	for i in range(7):
		var crack_start := Vector2(half.x * sin(i * 7.17) * 0.85, half.y * cos(i * 3.7) * 0.8)
		var crack := PackedVector2Array([crack_start, crack_start + Vector2(17, 7), crack_start + Vector2(20, 24), crack_start + Vector2(39, 28)])
		draw_polyline(crack, Color("0f1720"), 3)
		draw_line(crack_start + Vector2(2, 3), crack_start + Vector2(14, 7), Color("5b5e5b"), 1)
	for i in range(12):
		var p := Vector2(sin(i * 2.1) * half.x * 0.8, cos(i * 4.1) * half.y * 0.6)
		draw_circle(p, 16 + (i % 3) * 10, Color(0.025, 0.032, 0.04, 0.45))
	for y in [-half.y + 27, half.y - 27]:
		draw_line(Vector2(-half.x + 15, y), Vector2(half.x - 18, y), Color("716a58"), 4)
		for x in range(int(-half.x + 50), int(half.x), 110):
			draw_circle(Vector2(x, y), 14, Color(0.65, 0.3, 0.14, 0.07))
			draw_rect(Rect2(x - 7, y - 3, 14, 6), Color("bc7954") * (0.85 + sin(time * 1.8 + x) * 0.15))
	IndustrialArt.text(self, Vector2(-half.x + 36, -half.y + 63), wreck.name, 22, Color("858781"))
	IndustrialArt.text(self, Vector2(-half.x + 38, -half.y + 85), "NO PRESSURE / HULL COMPROMISED", 12, Color("796b59"))
	if detailed:
		for x in range(int(-half.x + 130), int(half.x - 50), 200):
			IndustrialArt.plate(self, Rect2(x, -half.y + 45, 44, 63), Color("334048"))
			draw_rect(Rect2(x + 7, -half.y + 52, 30, 24), Color("304e54"))
			for row in range(4):
				draw_line(Vector2(x + 8, -half.y + 82 + row * 5), Vector2(x + 28, -half.y + 82 + row * 5), Color("616b65"), 1)
	draw_set_transform(Vector2.ZERO)
	for wall in wall_rects:
		if Rect2(wreck.position - half - Vector2(5, 5), size + Vector2(10, 10)).intersects(wall):
			IndustrialArt.plate(self, wall, wreck.tone, detailed)
	var entrance: Vector2 = wreck.position + Vector2(-size.x * 0.24, half.y)
	for side in [-1, 1]:
		draw_line(entrance + Vector2(side * 84, -16), entrance + Vector2(side * 84, 28), IndustrialArt.AMBER, 4)
	IndustrialArt.text(self, entrance + Vector2(-50, 50), "HULL BREACH", 13, IndustrialArt.AMBER)

func draw_pod() -> void:
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(PackedVector2Array([Vector2(-85, -62), Vector2(35, -77), Vector2(90, -40), Vector2(90, 48), Vector2(34, 78), Vector2(-85, 63)]), Color("687174"))
	IndustrialArt.plate(self, Rect2(-69, -49, 128, 99), Color("242f38"))
	IndustrialArt.plate(self, Rect2(-54, -36, 40, 72), Color("848d81"))
	draw_rect(Rect2(-47, -30, 25, 58), Color("b0b8a3"))
	IndustrialArt.plate(self, Rect2(10, -38, 38, 40), Color("4d6469"))
	draw_rect(Rect2(16, -32, 26, 18), IndustrialArt.CYAN)
	draw_arc(Vector2(29, 25), 13, 0, TAU, 20, Color("8d9a8e"), 4)
	draw_circle(Vector2(-70, 43), 4, IndustrialArt.AMBER)
	draw_line(Vector2(77, -8), Vector2(77, 27), IndustrialArt.CYAN, 4)
	draw_arc(Vector2.ZERO, 111 + sin(time) * 4, 0, TAU, 48, Color(0.4, 0.8, 0.8, 0.10), 1)
	IndustrialArt.text(self, Vector2(-76, 112), "POD 07 / REFUGE", 16, IndustrialArt.CYAN)
	draw_set_transform(Vector2.ZERO)
