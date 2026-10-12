class_name NavigationChart
extends Control
var state: GameState
var origin := Vector2(35, 35)
var chart_size := Vector2(760, 475)

func _ready() -> void:
	custom_minimum_size = Vector2(830, 565)
	mouse_filter = Control.MOUSE_FILTER_STOP

func project(pos: Vector2) -> Vector2:
	var meters := GameData.meters(pos)
	return origin + (meters + GameData.WORLD_METERS / 2) / GameData.WORLD_METERS * chart_size

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Rect2(origin, chart_size).has_point(event.position):
			state.waypoint = GameData.pixels((event.position - origin) / chart_size * GameData.WORLD_METERS - GameData.WORLD_METERS / 2)
			state.waypoint_active = true
			state.message.emit("Waypoint set / X %+dm Y %+dm" % [GameData.meters(state.waypoint).x, GameData.meters(state.waypoint).y])
			queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(origin, chart_size), Color("071019"))
	var tile := Vector2(12, 12) / GameData.WORLD_METERS * chart_size
	for key in state.explored:
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() != 2: continue
		var meters := Vector2(float(parts[0]), float(parts[1])) * 12
		var pos := project(GameData.pixels(meters))
		var rect := Rect2(pos, tile).intersection(Rect2(origin, chart_size))
		if rect.has_area(): draw_rect(rect, Color("1a303b"))
	for x in range(13):
		var px: float = origin.x + x * chart_size.x / 12
		draw_line(Vector2(px, origin.y), Vector2(px, origin.y + chart_size.y), Color(0.38, 0.57, 0.63, 0.1), 1)
	for y in range(9):
		var py: float = origin.y + y * chart_size.y / 8
		draw_line(Vector2(origin.x, py), Vector2(origin.x + chart_size.x, py), Color(0.38, 0.57, 0.63, 0.1), 1)
	for wreck in GameData.wrecks():
		var p := project(wreck.position)
		if wreck.id in state.discoveries:
			var size: Vector2 = wreck.size / GameData.PPM / GameData.WORLD_METERS * chart_size
			draw_rect(Rect2(p - size / 2, size), Color("819a9c"), false, 2)
			IndustrialArt.text(self, p + Vector2(12, -14), wreck.name, 12, IndustrialArt.CYAN)
		elif wreck.id == "frigate" and "cargo_recorder" in state.logs:
			draw_arc(p, 11, 0, TAU, 24, IndustrialArt.AMBER, 1)
			IndustrialArt.text(self, p + Vector2(16, 4), "EURYDICE / UNCONFIRMED", 12, IndustrialArt.AMBER)
	var pod := project(Vector2.ZERO)
	draw_rect(Rect2(pod - Vector2(4, 4), Vector2(8, 8)), IndustrialArt.CYAN)
	IndustrialArt.text(self, pod + Vector2(10, 4), "POD 07", 12, IndustrialArt.CYAN)
	var player := project(state.position)
	draw_circle(player, 5, Color("e6ddd0"))
	draw_arc(player, 9, 0, TAU, 20, Color("a7b6ad"), 1)
	if state.waypoint_active:
		var point := project(state.waypoint)
		draw_line(player, point, Color(0.78, 0.63, 0.4, 0.35), 1)
		draw_line(point - Vector2(7, 0), point + Vector2(7, 0), IndustrialArt.AMBER, 2)
		draw_line(point - Vector2(0, 7), point + Vector2(0, 7), IndustrialArt.AMBER, 2)
	if "signal" in state.discoveries:
		var signal_pos := project(GameData.pixels(Vector2(-65, -45)))
		draw_arc(signal_pos, 10, 0, TAU, 16, IndustrialArt.AMBER, 1)
		IndustrialArt.text(self, signal_pos + Vector2(-40, -16), "UNKNOWN CARRIER", 12, IndustrialArt.AMBER)
	if state.completed:
		IndustrialArt.text(self, Vector2(45, 535), "LONG-RANGE: 14 CONTACTS / TRANSIT ECHO BEYOND CHART", 13, IndustrialArt.AMBER)
	draw_rect(Rect2(origin, chart_size), Color("3e626d"), false, 1)
	IndustrialArt.text(self, Vector2(35, 23), "X −300m", 12)
	IndustrialArt.text(self, Vector2(705, 23), "+300m / N ↑", 12)
	IndustrialArt.text(self, Vector2(35, 553), "CLICK TO SET WAYPOINT  /  SHADED = EXPLORED  /  AMBER = UNCONFIRMED", 12)
