extends Node2D
## Orchestrates independent model, physics, rendering, tools and screen-space UI.
var state: GameState
var player: EVAPlayer
var battlefield: Battlefield
var environment: ParallaxEnvironment
var hud: GameHUD
var sound: SuitAudio
var tool: String = "scanner"
var simulation_paused: bool = false
var target: Dictionary = {}
var tool_target: Dictionary = {}
var salvage_progress: Dictionary = {}
var autosave_clock: float = 0.0
var tool_sound_clock: float = 0.0
var low_oxygen_warned: bool = false
var completion_sequence: float = -1.0

func _ready() -> void:
	state = GameState.new()
	var background := CanvasLayer.new()
	background.layer = -10
	add_child(background)
	environment = ParallaxEnvironment.new()
	background.add_child(environment)
	battlefield = Battlefield.new()
	battlefield.state = state
	add_child(battlefield)
	player = EVAPlayer.new()
	player.state = state
	player.battlefield = battlefield
	player.position = state.position
	player.z_index = 10
	add_child(player)
	battlefield.camera = player.camera
	battlefield.player = player
	environment.camera = player.camera
	var screen := CanvasLayer.new()
	screen.layer = 10
	add_child(screen)
	hud = GameHUD.new()
	hud.state = state
	hud.game = self
	screen.add_child(hud)
	sound = SuitAudio.new()
	add_child(sound)
	connect_state()
	AudioServer.set_bus_volume_db(0, linear_to_db(state.settings.volume))
	hud.open("intro")

func connect_state() -> void:
	state.message.connect(func(text: String):
		hud.notify(text)
		sound.cue("unlock" if text.contains("UNLOCKED") or text.contains("MILESTONE") else "confirm")
		if text.contains("MILESTONE"):
			completion_sequence = 0)

func _process(delta: float) -> void:
	if player == null or simulation_paused:
		return
	autosave_clock += delta
	if autosave_clock > 90:
		state.save_game()
		autosave_clock = 0
	if state.oxygen < 25 and not low_oxygen_warned:
		state.message.emit("SUIT WARNING / Oxygen below 25%. Return home or use a canister [Tab].")
		low_oxygen_warned = true
	if state.oxygen > 30:
		low_oxygen_warned = false
	if completion_sequence >= 0:
		completion_sequence += delta
		if completion_sequence > 3 and completion_sequence < 3 + delta:
			state.message.emit("LONG-RANGE UPLINK / 14 signatures resolved.\nTransit echo: source outside known space.\nFuture objective: reconstruct a warp gate.")
		if completion_sequence > 10:
			completion_sequence = -1
	discover_contacts()
	target = battlefield.nearest(player.global_position, 145, Vector2.INF, ["pod", "container", "log", "signal"])
	tool_target = battlefield.nearest(player.global_position, GameData.SUIT.scan_range if tool == "scanner" else GameData.SUIT.tool_range, get_global_mouse_position())
	battlefield.selected = tool_target if not tool_target.is_empty() else target
	battlefield.beam = Vector2.INF
	hud.progress_text = ""
	if not battlefield.preview_id.is_empty():
		var pos := get_global_mouse_position()
		battlefield.preview_cell = Vector2i(roundi(pos.x / GameData.GRID), roundi(pos.y / GameData.GRID))
		var reason := battlefield.placement_reason(battlefield.preview_cell, battlefield.preview_id, player.global_position)
		battlefield.preview_valid = reason.begins_with("VALID")
		hud.interaction_text = state.recipes[battlefield.preview_id].title + " / " + reason
		return
	hud.interaction_text = context_text()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		use_tool(delta)

func discover_contacts() -> void:
	for wreck in battlefield.wrecks:
		if wreck.id in state.discoveries: continue
		var bounds := Rect2(wreck.position - wreck.size / 2, wreck.size).grow(250)
		if bounds.has_point(player.global_position):
			state.discoveries.append(wreck.id)
			state.message.emit("WRECK IDENTIFIED / " + wreck.name)
			state.save_game()
	for object in battlefield.objects:
		if object.kind in ["signal", "container"] and object.id not in state.discoveries and player.global_position.distance_to(object.position) < 350:
			state.discoveries.append(object.id)

func context_text() -> String:
	if not tool_target.is_empty():
		if tool_target.kind == "fragment":
			if state.scans.has(tool_target.id):
				return tool_target.title + " / ALREADY RESEARCHED"
			var recipe: RecipeDefinition = state.recipes[tool_target.payload]
			if tool == "scanner":
				return "HOLD LMB / " + recipe.title + " / " + recipe.category + " / %d of %d fragments" % [state.scan_count(recipe.id), recipe.scans_required]
			return "[1] SCANNER / " + recipe.title
		if tool_target.kind == "salvage":
			return ("HOLD LMB / CUT / " if tool == "cutter" else "[2] CUTTER REQUIRED / ") + tool_target.title
	if not target.is_empty():
		match target.kind:
			"pod": return "[F] FABRICATOR / POD LIFE SUPPORT ACTIVE"
			"container": return "[F] RECOVER / " + target.title
			"log", "signal": return "[F] READ / " + target.title
			"salvage": return "[2] HOLD LMB / " + target.title
	if state.safe_at(player.global_position):
		return "REFUGE / REPLENISHING OXYGEN & SUIT POWER"
	for module in state.modules:
		var center := Vector2(float(module.x), float(module.y)) * GameData.GRID
		if center.distance_to(player.global_position) < 135:
			var status: Dictionary = state.network.get(module.id, {})
			return "%s / NETWORK %.0f / %.0f kW / %s" % [state.recipes[module.recipe].title, status.get("generation", 0), status.get("demand", 0), "POWERED" if status.get("powered", false) else "OFFLINE"]
	return ""

func use_tool(delta: float) -> void:
	if tool_target.is_empty() or state.power <= 0:
		return
	var object := tool_target
	if tool == "scanner" and object.kind == "fragment" and not state.scans.has(object.id):
		var progress: float = minf(1, float(state.scan_progress.get(object.id, 0.0)) + delta / 2.4)
		state.scan_progress[object.id] = progress
		hud.progress = progress
		hud.progress_text = "SCANNING / " + state.recipes[object.payload].title + " / %d%%" % int(progress * 100)
		battlefield.beam = object.position
		battlefield.beam_color = IndustrialArt.CYAN
		state.power = maxf(0, state.power - GameData.SUIT.power_tool * delta)
		if progress >= 1:
			state.complete_scan(object.id, object.payload)
			state.save_game()
	elif tool == "cutter" and object.kind == "salvage":
		var progress: float = minf(1, float(salvage_progress.get(object.id, 0.0)) + delta / 1.8)
		salvage_progress[object.id] = progress
		hud.progress = progress
		hud.progress_text = "CUTTING / " + object.title + " / %d%%" % int(progress * 100)
		battlefield.beam = object.position
		battlefield.beam_color = IndustrialArt.AMBER
		state.power = maxf(0, state.power - GameData.SUIT.power_tool * delta * 2)
		if progress >= 1:
			if state.add_loot(object.payload, object.id):
				salvage_progress.erase(object.id)
			else:
				salvage_progress[object.id] = 0
	tool_sound_clock += delta
	if tool_sound_clock > 0.7:
		sound.cue("scan")
		tool_sound_clock = 0

func interact() -> void:
	var object := battlefield.nearest(player.global_position, 145, Vector2.INF, ["pod", "container", "log", "signal"])
	if object.is_empty():
		return
	match object.kind:
		"pod":
			hud.open("fabricator")
		"container":
			state.add_loot(object.payload, object.id)
		"log", "signal":
			if object.id not in state.logs:
				state.logs.append(object.id)
				if object.payload == "frigate":
					state.waypoint = GameData.pixels(Vector2(210, -105))
					state.waypoint_active = true
					state.message.emit("FLIGHT RECORDER / Eurydice telemetry recovered: X +210m / Y −105m")
				state.save_game()
			hud.open("logs")

func fabricate(id: String) -> void:
	if player.global_position.length() > 145:
		state.message.emit("Return to the pod fabricator.")
		return
	if state.fabricate(id):
		state.save_game()
		hud.refresh_menu()

func select_build(id: String) -> void:
	if "builder" not in state.equipment:
		state.message.emit("Fabricate a Habitat Builder first.")
		return
	tool = "builder"
	hud.close()
	battlefield.preview_id = id
	battlefield.preview_rotation = 0

func confirm_build() -> void:
	var id := battlefield.preview_id
	var reason := battlefield.placement_reason(battlefield.preview_cell, id, player.global_position)
	if not reason.begins_with("VALID"):
		state.message.emit(reason)
		return
	if state.place(id, battlefield.preview_cell, battlefield.preview_rotation):
		battlefield.add_latest_module()
		battlefield.preview_id = ""
		state.save_game()

func equip(id: String) -> void:
	if id not in state.equipment:
		state.message.emit("Fabricate the " + id.capitalize() + " at the pod.")
		return
	tool = id
	battlefield.preview_id = ""
	sound.cue()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and hud.menu.is_empty():
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP: player.change_zoom(1.12)
			MOUSE_BUTTON_WHEEL_DOWN: player.change_zoom(1 / 1.12)
			MOUSE_BUTTON_RIGHT: battlefield.preview_id = ""
			MOUSE_BUTTON_LEFT:
				if not battlefield.preview_id.is_empty(): confirm_build()
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if key == 0: key = event.keycode
	if key == KEY_ESCAPE:
		if not battlefield.preview_id.is_empty(): battlefield.preview_id = ""
		elif hud.menu.is_empty(): hud.open("pause")
		else: hud.close()
		return
	if key == KEY_F5:
		if state.save_game(): state.message.emit("Game saved.")
		return
	if key == KEY_F9:
		load_game()
		return
	if not hud.menu.is_empty():
		if (key == KEY_TAB and hud.menu == "inventory") or (key == KEY_M and hud.menu == "map") or (key == KEY_J and hud.menu == "logs") or (key == KEY_B and hud.menu == "build"):
			hud.close()
		return
	match key:
		KEY_1: equip("scanner")
		KEY_2: equip("cutter")
		KEY_3: equip("builder")
		KEY_F: interact()
		KEY_E:
			player.toggle_boots()
			sound.cue()
		KEY_T: player.flashlight = not player.flashlight
		KEY_TAB: hud.open("inventory")
		KEY_B:
			if "builder" in state.equipment:
				tool = "builder"
				hud.open("build")
			else: state.message.emit("Fabricate a Habitat Builder at the pod first.")
		KEY_M:
			if "navigator" in state.equipment: hud.open("map")
			else: state.message.emit("Navigation offline / fabricate a Navigation Instrument.")
		KEY_J: hud.open("logs")
		KEY_R: battlefield.preview_rotation = (battlefield.preview_rotation + 1) % 4
		KEY_C:
			player.camera.position = Vector2.ZERO
			player.camera.reset_smoothing()

func restore_view() -> void:
	player.global_position = state.position
	player.velocity = Vector2.ZERO
	player.boots = false
	player.camera.reset_smoothing()
	battlefield.preview_id = ""
	battlefield.selected = {}
	battlefield.beam = Vector2.INF
	salvage_progress.clear()
	tool = "scanner"
	battlefield.sync_modules(true)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, state.settings.volume)))
	hud.close()

func load_game() -> void:
	if state.load_game():
		restore_view()

func new_game() -> void:
	state = GameState.new()
	player.state = state
	battlefield.state = state
	hud.state = state
	connect_state()
	autosave_clock = 0
	low_oxygen_warned = false
	restore_view()
	hud.open("intro")
