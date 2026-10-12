extends SceneTree
## Run: godot --headless --path . --script tests/run_tests.gd --log-file tests.log
var failures: int = 0
var checks: int = 0

func check(condition: bool, title: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL / " + title)
	else:
		print("PASS / " + title)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state := GameState.new()
	check(GameData.meters(GameData.pixels(Vector2(210, -105))).is_equal_approx(Vector2(210, -105)), "Central meter/pixel round trip")
	check(is_equal_approx(GameData.heading(Vector2.UP), 0) and is_equal_approx(GameData.heading(Vector2.RIGHT), 90), "North / clockwise compass convention")
	check(not state.fabricate("cutter") and state.inventory.is_empty(), "Fabrication rejects missing materials atomically")
	check(state.add_loot("starter", "supply_0"), "Guaranteed initial supplies")
	var before := state.inventory.duplicate()
	check(not state.add_loot("starter", "supply_0") and state.inventory == before, "Stable salvage ID prevents repeat loot")
	check(state.fabricate("cutter") and state.count("scrap") == 12 and "cutter" in state.equipment, "Cutter delivery and exact resource costs")
	before = state.inventory.duplicate()
	check(not state.fabricate("cutter") and state.inventory == before, "Already owned tools cannot consume materials")
	check(state.fabricate("builder"), "Builder fabrication from initial supplies")
	check(not state.unlocked("solar") and not state.place("solar", Vector2i(1, 0)), "Research gates construction")
	var solar_ids: Array[String] = []
	for object in GameData.objects():
		if object.kind == "fragment" and object.payload == "solar": solar_ids.append(object.id)
	check(state.complete_scan(solar_ids[0], "solar") and state.scan_count("solar") == 1, "First unique fragment awards research")
	check(not state.complete_scan(solar_ids[0], "solar") and state.scan_count("solar") == 1, "Duplicate scan cannot award research")
	check(not state.complete_scan("invented_fragment", "solar"), "Reject unknown fragment identities")
	check(state.complete_scan(solar_ids[1], "solar") and state.unlocked("solar"), "Two solar fragments unlock blueprint")
	check(state.add_loot("starter", "supply_1"), "Second initial supply stack")
	check(state.fabricate("navigator"), "Navigation instrument fabrication")
	for object in GameData.objects():
		if object.kind == "fragment" and object.payload in ["habitat", "oxygen"]:
			check(state.complete_scan(object.id, object.payload), "Scan " + object.id)
	check(state.unlocked("habitat") and state.unlocked("oxygen"), "All cargo technologies researched")
	check(state.add_loot("fighter", "fighter_salvage_0") and state.add_loot("fighter", "fighter_salvage_1"), "Fighter dismantling yields")
	check(state.add_loot("cargo", "cargo_case_0") and state.add_loot("cargo", "cargo_case_1"), "Cargo yields fit capacity on intended path")
	before = state.inventory.duplicate()
	check(not state.place("habitat", Vector2i(7, 7)) and state.inventory == before, "Unconnected placement rejects without charging")
	check(state.place("habitat", Vector2i(1, 0)), "Room attaches to pod anchor")
	check(not state.safe_at(Vector2(GameData.GRID, 0)), "Unpowered habitat supplies no oxygen")
	check(state.place("solar", Vector2i(1, 1)), "Solar connects to room")
	check(not state.safe_at(Vector2(GameData.GRID, 0)), "Powered room without recycler remains uninhabitable")
	check(state.place("oxygen", Vector2i(2, 1)), "Recycler shares connected network")
	check(state.safe_at(Vector2(GameData.GRID, 0)) and "station" in state.milestones, "Connected powered habitat provides recovery and oxygen")
	before = state.inventory.duplicate()
	check(not state.place("solar", Vector2i(1, 1)) and state.inventory == before, "Overlap blocked without charging")
	for object in GameData.objects():
		if object.kind == "fragment" and object.payload == "array":
			state.complete_scan(object.id, object.payload)
	check(state.unlocked("array"), "Three navigation fragments unlock array")
	check(state.add_loot("frigate", "frigate_salvage_0") and state.add_loot("frigate", "frigate_salvage_1"), "Rare reactor components recoverable within capacity")
	check(state.count("reactor") >= 3 and state.place("array", Vector2i(2, 0)), "Late array cost and placement")
	check(state.completed and "complete" in state.milestones, "Beginning-to-end authored loot/research path reaches completion")
	var isolated := GameState.new()
	isolated.modules = [{"id": "far_room", "recipe": "habitat", "x": 8, "y": 8, "rotation": 0}, {"id": "solar", "recipe": "solar", "x": 1, "y": 0, "rotation": 0}, {"id": "oxy", "recipe": "oxygen", "x": 2, "y": 0, "rotation": 0}]
	isolated.recalculate_network()
	check(not isolated.network.far_room.powered and not isolated.network.far_room.oxygen, "Disconnected station components remain isolated")
	isolated.modules.append({"id": "hungry_array", "recipe": "array", "x": 3, "y": 0, "rotation": 0})
	isolated.modules.append({"id": "hungry_array_2", "recipe": "array", "x": 4, "y": 0, "rotation": 0})
	isolated.recalculate_network()
	check(not isolated.network.solar.powered, "Power deficit disables connected equipment")
	var anchored := GameState.new()
	anchored.modules = [{"id": "room", "recipe": "habitat", "x": 1, "y": 0, "rotation": 0}, {"id": "panel", "recipe": "solar", "x": -1, "y": 0, "rotation": 0}, {"id": "recycler", "recipe": "oxygen", "x": 0, "y": 1, "rotation": 0}]
	anchored.recalculate_network()
	check(anchored.network.room.habitable, "Pod docking anchor bridges its four passive bus connections")
	var full := GameState.new()
	full.inventory = {"scrap": GameData.SUIT.inventory_capacity}
	check(not full.add_loot("cargo", "cargo_case_0") and not "cargo_case_0" in full.depleted, "Full inventory leaves container recoverable")
	state.position = GameData.pixels(Vector2(210, -105))
	state.oxygen = 42
	state.power = 57
	state.health = 68
	state.reveal(state.position)
	state.waypoint = GameData.pixels(Vector2(92, 32))
	state.waypoint_active = true
	state.logs.append("cargo_recorder")
	state.discoveries.append("frigate")
	state.scan_progress["fighter_fragment_0"] = 0.5
	var path := "res://tests/_test_save.json"
	check(state.save_game(path), "Atomic JSON save writes successfully")
	var restored := GameState.new()
	check(restored.load_game(path), "Validated JSON load succeeds")
	check(restored.position.is_equal_approx(state.position) and restored.health == 68 and restored.oxygen == 42 and restored.power == 57, "Restore coordinates and suit reserves")
	check(restored.inventory == state.inventory and restored.equipment == state.equipment and restored.scans == state.scans, "Restore items, tools and blueprint availability")
	check(restored.modules == state.modules and restored.completed and restored.network.size() == 4, "Restore structures, recomputed graph and milestone")
	check(restored.depleted == state.depleted and restored.explored == state.explored and restored.logs == state.logs and restored.waypoint == state.waypoint, "Restore salvage, fog, archive and waypoint")
	check(restored.scan_progress == state.scan_progress and restored.milestones == state.milestones and restored.waypoint_active, "Restore partial scans, objectives and waypoint selection")
	if "--user-data" in OS.get_cmdline_user_args():
		var user_path := "user://graveyard_integration_test.json"
		check(state.save_game(user_path), "Actual Godot user-data save location is writable")
		check(restored.load_game(user_path), "Actual user-data file restores progress")
		DirAccess.remove_absolute(user_path)
	var corrupt := state.serialize().duplicate(true)
	corrupt.inventory = {"scrap": -999}
	check(not restored.validate_save(corrupt), "Negative inventory save rejected")
	corrupt = state.serialize().duplicate(true)
	corrupt.modules[0].x = "corrupt"
	check(not restored.validate_save(corrupt), "Malformed module save rejected")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	before = restored.serialize().duplicate(true)
	check(not restored.load_game(path) and restored.serialize() == before, "Corrupt file leaves live state unchanged")
	DirAccess.remove_absolute(path)
	state.oxygen = 20
	state.inventory.canister = 1
	check(state.use_item("canister") and state.oxygen == 70 and state.count("canister") == 0, "Portable oxygen consumption")
	var equipment_before := state.equipment.duplicate()
	state.inventory.scrap = 20
	state.respawn()
	check(state.count("scrap") == 18 and state.equipment == equipment_before and state.oxygen == 100, "Death penalty preserves equipment and restores suit")

	# Instantiate actual main scene, collision world, UI and runtime tools.
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.state.save_path = "res://tests/_runtime_save.json"
	await process_frame
	await physics_frame
	check(game.player != null and game.battlefield.wall_rects.size() > 15, "Main scene and physical wreck walls launch")
	game.hud.close()
	game.player.enabled = false
	game.simulation_paused = true
	check(game.battlefield.on_surface(GameData.pixels(Vector2(92, 32))) and not game.battlefield.on_surface(GameData.pixels(Vector2(-100, 100))), "Magnetic boots surface detection")
	var cargo: Dictionary = GameData.wrecks()[1]
	var breach: Vector2 = cargo.position + Vector2(-cargo.size.x * 0.24, cargo.size.y / 2)
	check(game.battlefield.line_of_sight(breach + Vector2(0, 70), breach - Vector2(0, 70)), "Actual hull breach is traversable")
	var solid: Vector2 = cargo.position + Vector2(100, -cargo.size.y / 2)
	check(not game.battlefield.line_of_sight(solid - Vector2(0, 70), solid + Vector2(0, 70)), "Solid hull blocks scanner line of sight")
	var movement_player: EVAPlayer = game.player
	movement_player.global_position = solid - Vector2(0, 70)
	movement_player.velocity = Vector2(0, 200)
	movement_player.move_and_collide(Vector2(0, 130))
	check(movement_player.global_position.y < solid.y, "Character collision stops passage through intact wall")
	movement_player.global_position = breach + Vector2(0, 70)
	movement_player.move_and_collide(Vector2(0, -140))
	check(movement_player.global_position.y < breach.y, "Character traverses breach from space into wreck")
	movement_player.global_position = Vector2(-600, -400)
	movement_player.velocity = Vector2.ZERO
	movement_player.enabled = true
	game.simulation_paused = false
	var initial_position := movement_player.global_position
	var input := InputEventKey.new()
	input.physical_keycode = KEY_D
	input.pressed = true
	Input.parse_input_event(input)
	for i in range(15): await physics_frame
	check(movement_player.velocity.x > 10 and movement_player.global_position.x > initial_position.x, "Actual WASD input accelerates EVA character")
	input.pressed = false
	Input.parse_input_event(input)
	var speed_before := movement_player.velocity.length()
	for i in range(10): await physics_frame
	check(movement_player.velocity.length() > speed_before * 0.5, "Momentum persists after releasing thrust")
	input = InputEventKey.new()
	input.physical_keycode = KEY_SPACE
	input.pressed = true
	Input.parse_input_event(input)
	for i in range(20): await physics_frame
	check(movement_player.velocity.length() < 1, "Active counter-thrust brakes movement")
	input.pressed = false
	Input.parse_input_event(input)
	check(game.state.oxygen < 100 and game.state.power < 100, "EVA simulation consumes finite suit reserves")
	movement_player.toggle_boots()
	check(not movement_player.boots, "Boots reject open-space activation")
	movement_player.global_position = Vector2(0, 60)
	game.state.oxygen = 40
	game.state.power = 40
	for i in range(10): await physics_frame
	check(game.state.oxygen > 40 and game.state.power > 40, "Actual pod refuge recharges oxygen and suit power")
	movement_player.global_position = game.battlefield.hazards[0].position
	game.battlefield.time = 3.2
	game.state.health = 100
	for i in range(10): await physics_frame
	check(game.state.health < 100, "Cyclic electrical arc inflicts localized damage")
	movement_player.global_position = Vector2(-600, -400)
	var health_after: float = game.state.health
	for i in range(10): await physics_frame
	check(game.state.health == health_after, "Leaving electrical arc stops damage")
	movement_player.enabled = false
	game.simulation_paused = true
	movement_player.global_position = GameData.pixels(Vector2(22, -12))
	game.state.position = movement_player.global_position
	game.tool = "scanner"
	for object in game.battlefield.objects:
		if object.id == "fighter_fragment_0": game.tool_target = object
	game.use_tool(1.2)
	check(is_equal_approx(game.state.scan_progress.get("fighter_fragment_0", 0), 0.5), "Actual scanner accumulates per-fragment progress")
	game.use_tool(1.2)
	check(game.state.scans.has("fighter_fragment_0"), "Actual tool completes research")
	movement_player.target_zoom = 1.5
	for i in range(60): movement_player.change_zoom(0.8)
	check(is_equal_approx(movement_player.target_zoom, 0.375), "Maximum survey zoom bound")
	for i in range(60): movement_player.change_zoom(1.2)
	check(is_equal_approx(movement_player.target_zoom, 2.25), "Close inspection zoom bound")
	game.state.inventory = {"scrap": 20, "alloy": 20}
	game.state.equipment.append("builder")
	check(game.battlefield.placement_reason(Vector2i(2, -1), "corridor", Vector2(256, -256)).contains("Attach"), "Disconnected cell rejected by world placement")
	game.state.place("corridor", Vector2i(1, 0))
	check(game.battlefield.placement_reason(Vector2i(2, -1), "corridor", Vector2(256, -256)).contains("Attach"), "Diagonal cells do not connect")
	game.state.place("corridor", Vector2i(1, -1))
	check(game.battlefield.placement_reason(Vector2i(2, -1), "corridor", Vector2(256, -256)).contains("Wreck"), "World placement blocks actual fighter geometry")
	check(game.battlefield.placement_reason(Vector2i(-1, 0), "corridor", Vector2.ZERO).begins_with("VALID"), "Clear connected station placement allowed")
	check(game.battlefield.placement_reason(Vector2i(-1, 0), "corridor", Vector2(-256, 0)).contains("footprint"), "Player cannot be trapped in assembly footprint")
	game.battlefield.sync_modules(true)
	await physics_frame
	check(not game.battlefield.line_of_sight(Vector2(333, -160), Vector2(333, -60)), "Constructed module has solid armored walls")
	check(game.battlefield.line_of_sight(Vector2(256, -160), Vector2(256, -60)), "Constructed module docking opening remains accessible")
	movement_player.global_position = Vector2(0, 60)
	game.state.position = movement_player.global_position
	game.interact()
	check(game.hud.menu == "fabricator", "Actual pod interaction opens fabricator")
	game.state.inventory.electronics = 8
	game.state.inventory.copper = 8
	game.fabricate("cutter")
	check("cutter" in game.state.equipment and game.state.count("electronics") == 6, "Actual fabricator action delivers equipment and pays costs")
	game.hud.close()
	game.simulation_paused = true
	movement_player.enabled = false
	movement_player.global_position = GameData.pixels(Vector2(106, 32))
	game.state.position = movement_player.global_position
	game.interact()
	check("cargo_recorder" in game.state.logs and game.state.waypoint == GameData.pixels(Vector2(210, -105)), "Actual recorder interaction reveals precise frigate waypoint")
	check(game.hud.menu == "logs", "Recovered recorder is readable in archive")
	game.hud.close()
	game.simulation_paused = true
	movement_player.enabled = false
	for menu in ["inventory", "fabricator", "research", "build", "logs", "pause", "settings"]:
		game.hud.menu = ""
		game.hud.open(menu)
		await process_frame
		check(game.hud.panel != null, "Runtime UI / " + menu)
	game.state.equipment.append("navigator")
	game.hud.open("map")
	await process_frame
	check(game.hud.chart != null, "Runtime navigation chart launches")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("res://tests/_runtime_save.json")
	print("\nRESULT / %d checks / %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
