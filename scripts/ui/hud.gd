class_name GameHUD
extends Control

var game: Node2D
var state: GameState
var menu: String = ""
var backdrop: ColorRect
var panel: PanelContainer
var content: VBoxContainer
var chart: NavigationChart
var toast_text: String = ""
var toast_time: float = 0.0
var interaction_text: String = ""
var progress: float = 0.0
var progress_text: String = ""
var tick: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = 19
	theme.set_color("font_color", "Label", Color("c1cecd"))
	theme.set_color("font_color", "Button", Color("bcdddb"))
	theme.set_color("font_disabled_color", "Button", Color("62737c"))
	for type in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("192d38") if type != "disabled" else Color("111c24")
		if type == "hover": style.bg_color = Color("284751")
		style.border_color = Color("425f67")
		style.set_border_width_all(1)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 9
		style.content_margin_bottom = 9
		theme.set_stylebox(type, "Button", style)
	self.theme = theme
	backdrop = ColorRect.new()
	backdrop.color = Color(0.015, 0.025, 0.04, 0.7)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	backdrop.hide()

func _process(delta: float) -> void:
	tick += delta
	toast_time = maxf(0, toast_time - delta)
	queue_redraw()

func notify(text: String) -> void:
	toast_text = text
	toast_time = 8 if text.contains("COMPLETE") or text.contains("UNLOCKED") else 5

func label(text: String, size: int = 19, color: Color = Color("b9c8c9")) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node

func button(text: String, callback: Callable, disabled: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.disabled = disabled
	node.pressed.connect(callback)
	return node

func close() -> void:
	menu = ""
	backdrop.hide()
	if is_instance_valid(panel): panel.queue_free()
	panel = null
	chart = null
	game.player.enabled = true
	game.simulation_paused = false

func open(name: String) -> void:
	if menu == name:
		close()
		return
	if is_instance_valid(panel):
		remove_child(panel)
		panel.queue_free()
	menu = name
	game.simulation_paused = true
	game.player.enabled = false
	backdrop.show()
	panel = PanelContainer.new()
	var wide := name == "map"
	panel.size = Vector2(900 if wide else 850, 850)
	panel.position = (get_viewport_rect().size - panel.size) / 2
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0d1923")
	style.border_color = Color("4b6d73")
	style.set_border_width_all(1)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 16)
	panel.add_child(outer)
	var titles := {"intro": "POD 07 / EMERGENCY DIAGNOSTIC", "fabricator": "ONBOARD FABRICATOR", "inventory": "SUIT / INVENTORY", "build": "HABITAT BUILDER / CONSTRUCTION", "research": "TECHNOLOGY / BLUEPRINT LIBRARY", "map": "NAVIGATION / LOCAL BATTLEFIELD", "logs": "MISSION / ARCHIVE", "pause": "GRAVEYARD / SYSTEMS", "settings": "SUIT / SETTINGS"}
	outer.add_child(label(titles.get(name, name), 25, IndustrialArt.CYAN))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 15)
	scroll.add_child(content)
	match name:
		"intro": intro_menu()
		"fabricator", "build", "research": recipes_menu(name)
		"inventory": inventory_menu()
		"map": map_menu()
		"logs": logs_menu()
		"pause": pause_menu()
		"settings": settings_menu()
	outer.add_child(button("BEGIN EVA" if name == "intro" else "CLOSE / ESC", close))

func refresh_menu() -> void:
	var previous := menu
	menu = ""
	open(previous)

func intro_menu() -> void:
	content.add_child(label("GRAVEYARD", 42, Color("ded9c8")))
	content.add_child(label("Q U I E T   D R I F T", 16, IndustrialArt.CYAN))
	content.add_child(label("CONFIRMED SURVIVORS: 01\nHULL INTEGRITY: CRITICAL\nLIFE SUPPORT: LOCAL RESERVE ONLY", 22, IndustrialArt.AMBER))
	content.add_child(label("You woke to silence. The fleet is gone. Your damaged pod can replenish suit oxygen and power, but it cannot take you home.\n\nRecover nearby emergency cases, fabricate a cutter, and scan equipment in the derelicts. Assemble a refuge. Restore long-range navigation.", 23))
	content.add_child(label("WASD thrust   •   Shift boost   •   Space brake\nMouse aims   •   Wheel zooms   •   F interacts\n1 scanner / 2 cutter / 3 builder   •   Hold LMB to use\nTab inventory   •   B build   •   J objectives\nE magnetic boots   •   T flashlight   •   Esc systems", 20))
	content.add_child(label("Pod coordinates: X 0m / Y 0m. North is −Y.\nKestrel fighter: 22m east, 12m north.\nMnemosyne cargo wreck: 92m east, 32m south.\nLook for amber hull-breach lights on the southern edge of each ship.", 19, IndustrialArt.CYAN))
	if FileAccess.file_exists("user://graveyard_save.json"):
		content.add_child(button("RESUME SAVED EXPEDITION", game.load_game))

func recipes_menu(mode: String) -> void:
	if mode == "build":
		content.add_child(label("Select a researched module. Attach its grid cell to the pod or another module. One solar collector supports a room, recycler and array. All cells have four docking connections.", 18))
	elif mode == "research":
		content.add_child(label("Distinct equipment fragments unlock recipes. Completed fragments never award research twice.", 18))
	var last_category: String = ""
	for id in state.recipes:
		var recipe: RecipeDefinition = state.recipes[id]
		if mode == "fabricator" and recipe.build_type == "structure": continue
		if mode in ["build", "research"] and recipe.build_type != "structure": continue
		if recipe.category != last_category:
			last_category = recipe.category
			content.add_child(label(last_category.to_upper(), 15, IndustrialArt.AMBER))
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 5)
		content.add_child(block)
		var unlocked := state.unlocked(id)
		var scan_text := ""
		if recipe.scans_required > 0:
			scan_text = "  /  %d of %d fragments" % [state.scan_count(id), recipe.scans_required]
		block.add_child(label(recipe.title + scan_text, 21, IndustrialArt.CYAN if unlocked else Color("7b8b93")))
		block.add_child(label(recipe.description, 17))
		var cost := PackedStringArray()
		for item in recipe.cost:
			cost.append("%s %d/%d%s" % [GameData.ITEMS[item][0], state.count(item), recipe.cost[item], " !" if state.count(item) < int(recipe.cost[item]) else ""])
		block.add_child(label("  •  ".join(cost), 16, IndustrialArt.AMBER if not state.can_afford(id) else Color("8caba4")))
		if mode == "fabricator":
			var owned: bool = id in state.equipment
			block.add_child(button("FABRICATED" if owned else "FABRICATE", func(): game.fabricate(id), owned or not unlocked or not state.can_afford(id)))
		elif mode == "build":
			block.add_child(button("SELECT PLACEMENT" if unlocked else "RESEARCH REQUIRED", func(): game.select_build(id), not unlocked or not state.can_afford(id) or not "builder" in state.equipment))
		else:
			block.add_child(label("AVAILABLE" if unlocked else "RESEARCH INCOMPLETE", 15, IndustrialArt.CYAN if unlocked else IndustrialArt.AMBER))

func inventory_menu() -> void:
	content.add_child(label("CARGO %d / %d units   |   TOOLS: %s" % [state.used_capacity(), GameData.SUIT.inventory_capacity, ", ".join(state.equipment)], 19, IndustrialArt.AMBER))
	for id in GameData.ITEMS:
		var item: Array = GameData.ITEMS[id]
		var row := HBoxContainer.new()
		content.add_child(row)
		var text := label("[%s]  %s ×%d\n%s" % [item[2], item[0], state.count(id), item[1]], 17, item[3])
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		if id in ["canister", "repair"]:
			row.add_child(button("USE", func():
				state.use_item(id)
				refresh_menu(), state.count(id) == 0))
		else:
			row.add_child(button("DROP 5", func():
				state.inventory[id] = maxi(0, state.count(id) - 5)
				refresh_menu(), state.count(id) == 0))
	content.add_child(button("OPEN BLUEPRINT LIBRARY", func(): open("research")))

func map_menu() -> void:
	chart = NavigationChart.new()
	chart.state = state
	content.add_child(chart)
	var pos := GameData.meters(state.position)
	content.add_child(label("SUIT POSITION / X %+0.1fm   Y %+0.1fm" % [pos.x, pos.y], 18))
	var row := HBoxContainer.new()
	content.add_child(row)
	row.add_child(button("WAYPOINT: POD", func():
		state.waypoint = Vector2.ZERO
		state.waypoint_active = true
		chart.queue_redraw()))
	if "cargo_recorder" in state.logs:
		row.add_child(button("WAYPOINT: EURYDICE", func():
			state.waypoint = GameData.pixels(Vector2(210, -105))
			state.waypoint_active = true
			chart.queue_redraw()))
	row.add_child(button("CLEAR", func():
		state.waypoint_active = false
		chart.queue_redraw()))

func logs_menu() -> void:
	content.add_child(label("CURRENT PRIORITY", 16, IndustrialArt.AMBER))
	content.add_child(label(state.objective(), 23))
	var steps := [
		["salvage", "Recover emergency supplies"], ["cutter", "Fabricate the Salvage Cutter"],
		["builder", "Fabricate the Habitat Builder"], ["station", "Establish connected power and life support"],
		["navigator", "Fabricate the Navigation Instrument"], ["complete", "Activate the long-range Navigation Array"],
	]
	for step in steps:
		content.add_child(label(("✓  " if step[0] in state.milestones else "○  ") + step[1], 18))
	content.add_child(label("ARCHIVE / POD DIAGNOSTIC", 16, IndustrialArt.CYAN))
	content.add_child(label("Only one suit transponder remains. Kestrel is northeast. Mnemosyne is southeast. Ships are depressurized. Enter through southern hull breaches; E engages magnetic boots on intact floors. Orange arc circles cycle: wait for the discharge to end.", 18))
	if "cargo_recorder" in state.logs:
		content.add_child(label("MNEMOSYNE / FLIGHT RECORDER", 16, IndustrialArt.CYAN))
		content.add_child(label("Last known navigation telemetry:\nX +210m / Y −105m\nSignal origin: Military Frigate EURYDICE\n\nThey were trying to protect something. All three navigation assemblies survived the initial impact. Shielded reactor housings contain the components your array will need.", 18))
		content.add_child(button("TRACK RECORDED COORDINATES", func():
			state.waypoint = GameData.pixels(Vector2(210, -105))
			state.waypoint_active = true
			close()))
	if "frigate_log" in state.logs:
		content.add_child(label("EURYDICE / FINAL COMMAND", 16, IndustrialArt.CYAN))
		content.add_child(label("No jump signature matches our own. The gate did not close. It turned inside out. If anyone receives this: listen beyond the debris field. Something is still transmitting.", 18))
	if "signal" in state.logs:
		content.add_child(label("UNKNOWN CARRIER / 7.4 Hz", 16, IndustrialArt.AMBER))
		content.add_child(label("A survey buoy repeats an impossible time stamp. Signal contact recorded. Future arrays may resolve its origin.", 18))

func pause_menu() -> void:
	content.add_child(label("Expedition time / %02d:%02d" % [int(state.elapsed) / 60, int(state.elapsed) % 60], 20))
	content.add_child(button("SAVE GAME", func():
		if state.save_game(): notify("Game saved to local user data.")
		close()))
	content.add_child(button("LOAD GAME", game.load_game))
	content.add_child(button("NEW GAME / RESTART EXPEDITION", game.new_game))
	content.add_child(button("SETTINGS", func(): open("settings")))
	content.add_child(button("BLUEPRINT LIBRARY", func(): open("research")))
	content.add_child(label("WASD thrust / opposite thrust brakes / Space active brake\nShift boost / Mouse aim / Wheel zoom / C recenter\nF interact / Hold LMB tool / 1 scanner / 2 cutter / 3 builder\nE magnetic boots / T flashlight / Tab inventory\nB construction / R rotate preview / RMB cancel\nM navigation (requires instrument) / J logs / Esc systems\nF5 quick save / F9 quick load", 19))
	content.add_child(label("Death: return to last refuge with full suit reserves. Lose 10% of material stacks; keep equipment, research and station.\nAutosaves occur every 90s and after research, construction or logs.", 17, IndustrialArt.AMBER))
	content.add_child(button("SAVE & QUIT", func():
		if state.save_game(): get_tree().quit()))

func settings_menu() -> void:
	content.add_child(label("Suit audio volume", 19))
	var volume := HSlider.new()
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.05
	volume.value = state.settings.volume
	volume.value_changed.connect(func(value: float):
		state.settings.volume = value
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, value))))
	content.add_child(volume)
	var look := CheckButton.new()
	look.text = "Directional camera look-ahead"
	look.button_pressed = state.settings.look_ahead
	look.toggled.connect(func(value: bool): state.settings.look_ahead = value)
	content.add_child(look)
	content.add_child(label("Zoom range 0.375–2.25. HUD remains in screen space.\nMenu interfaces pause the suit simulation.\nChanges are stored with the next save.", 18))

func text(pos: Vector2, value: String, size: int = 18, color: Color = Color("c0cece")) -> void:
	draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func pane(rect: Rect2) -> void:
	draw_rect(rect, Color(0.035, 0.06, 0.085, 0.85))
	draw_rect(rect, Color(0.34, 0.48, 0.51, 0.45), false, 1)

func gauge(pos: Vector2, title: String, value: float, color: Color) -> void:
	text(pos, title, 14, Color("849ba1"))
	text(pos + Vector2(239, 0), "%03d" % int(value), 17, color)
	draw_rect(Rect2(pos + Vector2(0, 11), Vector2(270, 6)), Color("273741"))
	draw_rect(Rect2(pos + Vector2(0, 11), Vector2(270 * value / 100, 6)), color)

func _draw() -> void:
	if game == null or game.player == null: return
	var viewport := get_viewport_rect().size
	var player: EVAPlayer = game.player
	game.environment.draw_foreground(self)
	# Soft edge shading for quiet contrast, independent of camera scale.
	for i in range(12):
		draw_rect(Rect2(i * 5, i * 5, viewport.x - i * 10, viewport.y - i * 10), Color(0.01, 0.02, 0.03, 0.023), false, 10)
	pane(Rect2(32, 30, 316, 219))
	text(Vector2(55, 63), "POD 07 / SUIT TELEMETRY", 17, IndustrialArt.CYAN)
	gauge(Vector2(55, 101), "OXYGEN", state.oxygen, IndustrialArt.CYAN if state.oxygen > 25 else IndustrialArt.AMBER)
	gauge(Vector2(55, 148), "SUIT POWER", state.power, Color("a7b6a1"))
	gauge(Vector2(55, 195), "INTEGRITY", state.health, IndustrialArt.AMBER)
	text(Vector2(55, 236), "MAG CONTACT" if player.boots else "EVA / FREE DRIFT", 13, Color("7c9199"))
	pane(Rect2(viewport.x - 590, 30, 558, 122))
	text(Vector2(viewport.x - 570, 61), "CURRENT PRIORITY / J ARCHIVE", 15, IndustrialArt.AMBER)
	var objective := state.objective()
	# Font word-wrap is handled manually for two short HUD lines.
	var words := objective.split(" ")
	var line: String = ""
	var y: float = 91
	for word in words:
		if ThemeDB.fallback_font.get_string_size(line + " " + word, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x > 510:
			text(Vector2(viewport.x - 570, y), line, 18)
			line = ""
			y += 23
		line += (" " if not line.is_empty() else "") + word
	text(Vector2(viewport.x - 570, y), line, 18)
	var center_x: float = viewport.x / 2
	var home := -state.position
	var home_bearing := GameData.heading(home)
	text(Vector2(center_x - 120, 48), "HOME %03d° / %dm" % [int(home_bearing), int(home.length() / GameData.PPM)], 18, IndustrialArt.CYAN)
	if "navigator" in state.equipment:
		var coords := GameData.meters(state.position)
		text(Vector2(center_x - 180, 78), "X %+0.1fm  Y %+0.1fm  /  HDG %03d°" % [coords.x, coords.y, int(GameData.heading(Vector2.UP.rotated(player.facing)))], 16)
		if state.waypoint_active:
			var direction := state.waypoint - state.position
			text(Vector2(center_x - 155, 104), "WAYPOINT %03d° / %dm" % [int(GameData.heading(direction)), int(direction.length() / GameData.PPM)], 17, IndustrialArt.AMBER)
	else:
		text(Vector2(center_x - 111, 78), "NAVIGATION OFFLINE", 13, Color("6b828e"))
	# Home / waypoint edge markers remain useful at the widest zoom.
	var target := state.waypoint if state.waypoint_active and "navigator" in state.equipment else Vector2.ZERO
	var screen_target: Vector2 = game.get_viewport().get_canvas_transform() * target
	if not Rect2(Vector2(100, 180), viewport - Vector2(200, 330)).has_point(screen_target):
		var direction := (screen_target - viewport / 2).normalized()
		var radius: float = minf((viewport.x / 2 - 110) / maxf(absf(direction.x), 0.01), (viewport.y / 2 - 180) / maxf(absf(direction.y), 0.01))
		var arrow := viewport / 2 + direction * radius
		draw_colored_polygon(PackedVector2Array([arrow + direction * 10, arrow + direction.rotated(2.4) * 9, arrow + direction.rotated(-2.4) * 9]), IndustrialArt.CYAN)
		text(arrow + Vector2(14, 5), "HOME" if target == Vector2.ZERO else "WP", 12, IndustrialArt.CYAN)
	var bottom: float = viewport.y - 102
	pane(Rect2(32, bottom, 460, 70))
	text(Vector2(53, bottom + 27), "[1] SCAN   [2] CUT   [3] BUILD", 17, Color("8ba2a7"))
	text(Vector2(53, bottom + 53), "ACTIVE / " + game.tool.to_upper() + "     •     TAB CARGO", 15, IndustrialArt.CYAN)
	text(Vector2(viewport.x - 435, viewport.y - 38), "F INTERACT   •   WHEEL ZOOM   •   ESC SYSTEMS", 15, Color("81969e"))
	if not interaction_text.is_empty() and menu.is_empty():
		var width := minf(960, ThemeDB.fallback_font.get_string_size(interaction_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 44)
		pane(Rect2(center_x - width / 2, viewport.y - 138, width, 45))
		text(Vector2(center_x - width / 2 + 22, viewport.y - 108), interaction_text, 19, IndustrialArt.CYAN)
	if not progress_text.is_empty() and menu.is_empty():
		pane(Rect2(center_x - 240, viewport.y - 225, 480, 67))
		text(Vector2(center_x - 220, viewport.y - 196), progress_text, 17)
		draw_rect(Rect2(center_x - 220, viewport.y - 180, 440, 5), Color("334b56"))
		draw_rect(Rect2(center_x - 220, viewport.y - 180, 440 * progress, 5), IndustrialArt.CYAN)
	if state.oxygen < 25:
		text(Vector2(55, 280), "LOW OXYGEN / RETURN TO REFUGE", 17, IndustrialArt.AMBER * (0.85 + sin(tick * 4) * 0.15))
	if toast_time > 0 and menu.is_empty():
		var lines := toast_text.split("\n")
		var width: float = 650
		for toast_line in lines:
			width = maxf(width, minf(1350, ThemeDB.fallback_font.get_string_size(toast_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 50))
		pane(Rect2(center_x - width / 2, 173, width, 44 + (lines.size() - 1) * 27))
		for i in range(lines.size()):
			text(Vector2(center_x - width / 2 + 25, 202 + i * 27), lines[i], 20, IndustrialArt.AMBER if toast_text.contains("UNLOCKED") or toast_text.contains("COMPLETE") else IndustrialArt.CYAN)
