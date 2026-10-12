class_name ParallaxEnvironment
extends Node2D
## Screen-space camera-relative layers, unbounded at every zoom; decorative only.
var camera: Camera2D
var time: float = 0.0
var stars: Array[Dictionary] = []
var dust: Array[Dictionary] = []
var farships: Array[Dictionary] = []

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4771
	for i in range(850):
		stars.append({"p": Vector2(rng.randf_range(0, 2600), rng.randf_range(0, 1600)), "r": rng.randf_range(0.6, 1.8), "a": rng.randf_range(0.12, 0.65), "d": rng.randf_range(0.005, 0.035)})
	for i in range(20):
		dust.append({"p": Vector2(rng.randf_range(0, 2400), rng.randf_range(0, 1400)), "size": rng.randf_range(2, 8), "phase": rng.randf_range(0, TAU)})
	farships = [{"p": Vector2(540, 610), "size": 0.8, "angle": -0.6}, {"p": Vector2(1620, 180), "size": 1.6, "angle": 0.3}, {"p": Vector2(970, 1080), "size": 0.5, "angle": 1.1}]

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func wrap_point(p: Vector2, area: Vector2) -> Vector2:
	return Vector2(fposmod(p.x, area.x), fposmod(p.y, area.y))

func _draw() -> void:
	var viewport := get_viewport_rect().size
	var offset := camera.get_screen_center_position() if camera != null else Vector2.ZERO
	# Deep-space haze: layered broad transparent circles create soft color falloff.
	draw_rect(Rect2(Vector2.ZERO, viewport), Color("070e18"))
	for i in range(18, 0, -1):
		draw_circle(Vector2(viewport.x * 0.72, viewport.y * 0.44) - offset * 0.008, i * 72, Color(0.07, 0.16, 0.2, 0.018))
	# Celestial limb remains decorative with extremely slow motion.
	var planet := Vector2(viewport.x * 1.12, viewport.y * 0.16) - offset * 0.012
	draw_circle(planet, 335, Color("172932"))
	for i in range(18):
		draw_circle(planet + Vector2(14 + i * 8, 5 + i * 2), 321 - i * 3, Color(0.025, 0.045, 0.061, 0.075))
	draw_arc(planet, 337, PI * 0.58, PI * 1.5, 80, Color(0.2, 0.36, 0.4, 0.23), 3)
	for star in stars:
		var point := wrap_point(star.p - offset * star.d, Vector2(2600, 1600))
		if point.x < viewport.x and point.y < viewport.y:
			draw_circle(point, star.r, Color(0.64, 0.72, 0.77, star.a))
	# Enormous distant military hulks with broken spines and structural ribs.
	for ship in farships:
		var p: Vector2 = wrap_point(ship.p - offset * 0.085 + Vector2(400, 200), Vector2(3200, 2200)) - Vector2(400, 200)
		draw_set_transform(p, ship.angle, Vector2.ONE * ship.size)
		draw_colored_polygon(PackedVector2Array([Vector2(-270, -42), Vector2(180, -35), Vector2(260, 0), Vector2(180, 32), Vector2(-180, 48), Vector2(-245, 30)]), Color("14232e"))
		for x in range(-235, 180, 35):
			draw_rect(Rect2(x, -48, 13, 90), Color("20303a"))
			draw_line(Vector2(x, -48), Vector2(x + 12, -48), Color("2b3942"), 1)
		draw_rect(Rect2(-15, -60, 46, 140), Color("070e18"))
		draw_line(Vector2(-245, 0), Vector2(-40, 0), Color("33404a"), 3)
		draw_rect(Rect2(-190, -72, 220, 19), Color("192c36"))
		draw_line(Vector2(190, -20), Vector2(245, 0), Color("35414a"), 2)
	draw_set_transform(Vector2.ZERO)

func draw_foreground(canvas: CanvasItem) -> void:
	if camera == null:
		return
	var offset := camera.get_screen_center_position()
	var viewport := get_viewport_rect().size
	for particle in dust:
		var point := wrap_point(particle.p - offset * 1.18 * camera.zoom.x + Vector2(time * 2, time), viewport + Vector2(120, 120)) - Vector2(60, 60)
		canvas.draw_set_transform(point, particle.phase + time * 0.03)
		canvas.draw_rect(Rect2(-particle.size, -2, particle.size * 2, 4), Color(0.3, 0.36, 0.39, 0.25))
	canvas.draw_set_transform(Vector2.ZERO)
