class_name IndustrialArt
extends RefCounted
## Original procedural overhead artwork. All dimensions are world pixels.
const STEEL := Color("657078")
const CYAN := Color("78bfc2")
const AMBER := Color("d4a46a")

static func text(canvas: CanvasItem, pos: Vector2, label: String, size: int = 14, color: Color = STEEL) -> void:
	canvas.draw_string(ThemeDB.fallback_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

static func plate(canvas: CanvasItem, rect: Rect2, color: Color, detail: bool = true) -> void:
	canvas.draw_rect(Rect2(rect.position + Vector2(4, 6), rect.size), Color(0, 0, 0, 0.45))
	canvas.draw_rect(rect, color)
	canvas.draw_rect(rect.grow(-2), color.lightened(0.055), false, 2)
	canvas.draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), color.lightened(0.23), 2)
	if detail:
		# Deterministic weathering: etched scratches and inset seams, no bitmap atlas.
		if rect.size.x > 28 and rect.size.y > 25:
			for i in range(4):
				var seed_value: float = sin(rect.position.x * 0.73 + rect.position.y * 0.93 + i * 27.1)
				var p := rect.position + Vector2(0.15 + absf(seed_value) * 0.65, 0.2 + fmod(absf(seed_value * 8), 0.6)) * rect.size
				canvas.draw_line(p, p + Vector2(4 + i * 2, -2), Color(0.72, 0.72, 0.65, 0.15), 1)
		for corner in [rect.position + Vector2(6, 6), rect.position + Vector2(rect.size.x - 6, 6), rect.end - Vector2(6, 6), rect.position + Vector2(6, rect.size.y - 6)]:
			canvas.draw_circle(corner, 2, Color("151b21"))

static func machinery(canvas: CanvasItem, kind: String, researched: bool, time: float) -> void:
	var glow := CYAN if researched else AMBER
	if kind == "solar":
		plate(canvas, Rect2(-59, -27, 118, 54), Color("252f3a"))
		for x in range(-50, 51, 16):
			for y in [-17, 2]:
				canvas.draw_rect(Rect2(x, y, 12, 15), Color("3e5766"))
		canvas.draw_line(Vector2(-20, -29), Vector2(34, 24), Color("141a22"), 7)
		plate(canvas, Rect2(-14, -13, 28, 26), Color("6a6d62"))
	elif kind == "habitat":
		plate(canvas, Rect2(-42, -34, 84, 68), Color("484e50"))
		canvas.draw_arc(Vector2(-9, 0), 22, 0.3, 5.8, 24, Color("929787"), 8)
		canvas.draw_arc(Vector2(-9, 0), 14, 0, TAU, 24, Color("242d35"), 5)
		for y in range(-26, 30, 8):
			canvas.draw_line(Vector2(20, y), Vector2(35, y), Color("232a2e"), 3)
	elif kind == "oxygen":
		plate(canvas, Rect2(-36, -29, 72, 58), Color("3b4b4d"))
		for x in [-21, 0, 21]:
			canvas.draw_style_box(capsule_style(), Rect2(x - 8, -21, 16, 42))
		canvas.draw_line(Vector2(-32, 19), Vector2(32, 19), Color("af9574"), 4)
	elif kind == "array":
		plate(canvas, Rect2(-44, -29, 88, 58), Color("3b424c"))
		canvas.draw_arc(Vector2(0, -1), 26, PI * 0.12, PI * 0.94, 24, Color("98a7a8"), 7)
		canvas.draw_line(Vector2.ZERO, Vector2(0, -43), STEEL, 4)
		canvas.draw_circle(Vector2(0, -42), 5, glow)
		for x in [-32, 25]:
			canvas.draw_rect(Rect2(x, -22, 7, 40), Color("202b33"))
	canvas.draw_circle(Vector2(27, 20), 3.5, glow * (0.8 + 0.2 * sin(time * 2)))

static func capsule_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("81908b")
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	return style

static func station(canvas: CanvasItem, kind: String, powered: bool, habitable: bool, time: float) -> void:
	var color := Color("313b43")
	plate(canvas, Rect2(-112, -112, 224, 224), color)
	canvas.draw_rect(Rect2(-99, -99, 198, 198), Color("1b242b"))
	for x in range(-96, 97, 32):
		for y in range(-96, 97, 32):
			canvas.draw_rect(Rect2(x, y, 30, 30), Color("293238"), false, 1)
	for angle in range(4):
		var direction := Vector2.RIGHT.rotated(angle * PI / 2)
		canvas.draw_line(direction * 95, direction * 128, Color("829091"), 30)
		canvas.draw_line(direction * 96, direction * 128, Color("29333c"), 19)
	var lamp := CYAN if powered else Color("88644d")
	for corner in [Vector2(-94, -94), Vector2(94, -94), Vector2(-94, 94), Vector2(94, 94)]:
		canvas.draw_circle(corner, 4, lamp)
	if kind == "habitat":
		plate(canvas, Rect2(-78, -72, 47, 92), Color("555b59"))
		canvas.draw_rect(Rect2(-73, -66, 37, 77), Color("89968f") if habitable else Color("4c5454"))
		plate(canvas, Rect2(35, -75, 39, 64), Color("455558"))
		canvas.draw_rect(Rect2(41, -66, 27, 24), lamp.darkened(0.25))
		for x in [-72, -20, 32]:
			canvas.draw_line(Vector2(x, 69), Vector2(x + 30, 69), Color("606c6d"), 4)
		text(canvas, Vector2(-75, 42), "O2 / NOMINAL" if habitable else "NO LIFE SUPPORT", 11, lamp)
	elif kind == "corridor":
		for y in range(-80, 81, 16):
			canvas.draw_line(Vector2(-70, y), Vector2(70, y), Color("48535a"), 3)
	else:
		machinery(canvas, kind, powered, time)
		if kind == "solar":
			for side in [-1, 1]:
				plate(canvas, Rect2(side * 56 - 24, -81, 48, 160), Color("2b3e51"))
				for y in range(-73, 74, 12):
					canvas.draw_line(Vector2(side * 56 - 20, y), Vector2(side * 56 + 20, y), Color("627b89"), 1)
		if kind == "array" and powered:
			canvas.draw_arc(Vector2.ZERO, 80 + fmod(time * 20, 25), PI * 1.15, PI * 1.85, 32, Color(0.45, 0.8, 0.8, 0.3), 2)
	text(canvas, Vector2(-88, 96), kind.to_upper(), 12, STEEL)
