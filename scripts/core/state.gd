class_name GameState
extends RefCounted
## Authoritative model. No rendering or live physics dependencies.
signal changed
signal message(text: String)

var recipes: Dictionary = GameData.recipes()
var inventory: Dictionary = {}
var equipment: Array = ["scanner"]
var scans: Dictionary = {}
var scan_progress: Dictionary = {}
var depleted: Array = []
var modules: Array = []
var discoveries: Array = ["pod"]
var explored: Dictionary = {}
var logs: Array = []
var milestones: Array = []
var waypoint := Vector2.ZERO
var waypoint_active: bool = false
var position := Vector2(0, 65)
var recovery := Vector2.ZERO
var health: float = 100.0
var oxygen: float = 100.0
var power: float = 100.0
var completed: bool = false
var network: Dictionary = {}
var elapsed: float = 0.0
var settings := {"volume": 0.65, "look_ahead": true}
var save_path: String = "user://graveyard_save.json"

func count(id: String) -> int:
	return int(inventory.get(id, 0))

func used_capacity() -> int:
	var total: int = 0
	for value in inventory.values():
		total += int(value)
	return total

func add_loot(table: String, object_id: String) -> bool:
	if object_id in depleted or not GameData.LOOT.has(table):
		return false
	var loot: Dictionary = GameData.LOOT[table]
	var sum: int = 0
	for amount in loot.values():
		sum += int(amount)
	if used_capacity() + sum > GameData.SUIT.inventory_capacity:
		message.emit("Inventory full. Fabricate, build or discard a stack with Tab.")
		return false
	for id in loot:
		inventory[id] = count(id) + int(loot[id])
	depleted.append(object_id)
	mark("salvage")
	message.emit("SALVAGE RECOVERED / " + loot_text(loot))
	changed.emit()
	return true

func loot_text(loot: Dictionary) -> String:
	var parts := PackedStringArray()
	for id in loot:
		parts.append("%s +%d" % [GameData.ITEMS[id][0], loot[id]])
	return ", ".join(parts)

func scan_count(blueprint: String) -> int:
	var total: int = 0
	for id in scans:
		if scans[id] == blueprint:
			total += 1
	return total

func unlocked(id: String) -> bool:
	if not recipes.has(id):
		return false
	var recipe: RecipeDefinition = recipes[id]
	if scan_count(id) < recipe.scans_required:
		return false
	for prerequisite in recipe.prerequisites:
		if not unlocked(prerequisite):
			return false
	return true

func complete_scan(object_id: String, blueprint: String) -> bool:
	if scans.has(object_id) or not recipes.has(blueprint):
		return false
	# Check identity against authored content, rather than trusting callers/save IDs.
	var valid: bool = false
	for object in GameData.objects():
		if object.id == object_id and object.kind == "fragment" and object.payload == blueprint:
			valid = true
			break
	if not valid:
		return false
	var before := unlocked(blueprint)
	scans[object_id] = blueprint
	scan_progress.erase(object_id)
	var recipe: RecipeDefinition = recipes[blueprint]
	if not before and unlocked(blueprint):
		message.emit("BLUEPRINT UNLOCKED: " + recipe.title.to_upper())
	else:
		message.emit("RESEARCH / %s / %d of %d unique fragments" % [recipe.title, scan_count(blueprint), recipe.scans_required])
	changed.emit()
	return true

func can_afford(id: String) -> bool:
	if not recipes.has(id):
		return false
	for item in recipes[id].cost:
		if count(item) < int(recipes[id].cost[item]):
			return false
	return true

func pay(id: String) -> bool:
	if not can_afford(id):
		return false
	for item in recipes[id].cost:
		inventory[item] = count(item) - int(recipes[id].cost[item])
	return true

func fabricate(id: String) -> bool:
	if not unlocked(id) or recipes[id].build_type == "structure":
		return false
	if id in equipment:
		message.emit("Equipment already fabricated.")
		return false
	if not pay(id):
		message.emit("Fabrication blocked / missing resources.")
		return false
	if recipes[id].build_type == "consumable":
		inventory[id] = count(id) + 1
	else:
		equipment.append(id)
	mark(id)
	message.emit("FABRICATION COMPLETE / " + recipes[id].title)
	changed.emit()
	return true

func use_item(id: String) -> bool:
	if count(id) < 1 or id not in ["canister", "repair"]:
		return false
	if id == "canister":
		oxygen = minf(100.0, oxygen + 50.0)
	else:
		health = minf(100.0, health + 45.0)
	inventory[id] = count(id) - 1
	message.emit("Used " + GameData.ITEMS[id][0])
	changed.emit()
	return true

func mark(id: String) -> void:
	if id not in milestones:
		milestones.append(id)

func module_at(cell: Vector2i) -> Dictionary:
	for module in modules:
		if Vector2i(int(module.x), int(module.y)) == cell:
			return module
	return {}

func connected_cell(cell: Vector2i) -> bool:
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor: Vector2i = cell + offset
		if neighbor == Vector2i.ZERO or not module_at(neighbor).is_empty():
			return true
	return false

func place(id: String, cell: Vector2i, orientation: int = 0) -> bool:
	if not "builder" in equipment or not unlocked(id) or recipes[id].build_type != "structure":
		return false
	if cell == Vector2i.ZERO or not module_at(cell).is_empty() or not connected_cell(cell):
		return false
	if not pay(id):
		return false
	modules.append({"id": "module_%d" % modules.size(), "recipe": id, "x": cell.x, "y": cell.y, "rotation": orientation})
	message.emit("ASSEMBLY INITIATED / " + recipes[id].title)
	recalculate_network()
	changed.emit()
	return true

func recalculate_network() -> void:
	# Evaluate separate connected components. A disconnected room never borrows life support.
	network.clear()
	var remaining: Array = []
	for module in modules:
		remaining.append(module)
	while not remaining.is_empty():
		var component: Array = [remaining.pop_back()]
		var cursor: int = 0
		while cursor < component.size():
			var current: Dictionary = component[cursor]
			for i in range(remaining.size() - 1, -1, -1):
				var other: Dictionary = remaining[i]
				var direct: bool = absi(int(current.x) - int(other.x)) + absi(int(current.y) - int(other.y)) == 1
				var through_pod: bool = absi(int(current.x)) + absi(int(current.y)) == 1 and absi(int(other.x)) + absi(int(other.y)) == 1
				if direct or through_pod:
					component.append(other)
					remaining.remove_at(i)
			cursor += 1
		var generation: float = 0.0
		var demand: float = 0.0
		var has_oxygen: bool = false
		var has_room: bool = false
		for module in component:
			var recipe: RecipeDefinition = recipes[module.recipe]
			generation += recipe.production
			demand += recipe.demand
			has_oxygen = has_oxygen or module.recipe == "oxygen"
			has_room = has_room or module.recipe == "habitat"
		var powered := generation > 0.0 and generation >= demand
		for module in component:
			network[module.id] = {"powered": powered, "oxygen": powered and has_oxygen,
				"generation": generation, "demand": demand, "habitable": powered and has_oxygen and has_room}
			if module.recipe == "habitat" and powered and has_oxygen:
				mark("station")
			if module.recipe == "array" and powered and has_oxygen and has_room and not completed:
				completed = true
				mark("complete")
				message.emit("PROTOTYPE MILESTONE COMPLETE\nArray online. 14 distant wreck signatures acquired.\nHigh-energy transit echo detected beyond the battlefield.\nA way home may still exist.")

func safe_at(pos: Vector2) -> bool:
	if pos.distance_to(Vector2.ZERO) < 100.0:
		recovery = Vector2.ZERO
		return true
	for module in modules:
		if module.recipe != "habitat":
			continue
		var center := Vector2(float(module.x), float(module.y)) * GameData.GRID
		if Rect2(center - Vector2(105, 105), Vector2(210, 210)).has_point(pos):
			if network.get(module.id, {}).get("habitable", false):
				recovery = center
				return true
	return false

func objective() -> String:
	if completed:
		return "Array online. Explore remaining contacts. Your station is a foothold in the dark."
	if position.distance_to(Vector2.ZERO) < 150 and not "salvage" in milestones:
		return "Leave the pod. Recover emergency cases nearby [F]."
	if not "salvage" in milestones:
		return "Recover emergency supplies [F]. Amber cases drift southeast."
	if not "cutter" in equipment:
		return "Return to pod [F]. Fabricate the Salvage Cutter."
	if scan_count("solar") == 0:
		return "Investigate Kestrel, northeast. Hold LMB to scan damaged equipment [1]."
	if not "builder" in equipment:
		return "Fabricate a Habitat Builder at the pod."
	if not unlocked("habitat") or not unlocked("oxygen") or not unlocked("solar"):
		return "Explore Mnemosyne cargo wreck: +92m, +32m. Scan its damaged systems."
	if not "station" in milestones:
		return "Build connected Habitat + Solar Collector + Oxygen Recycler near the pod [3 / B]."
	if not "cargo_recorder" in logs:
		return "Recover the flight recorder in Mnemosyne's eastern compartment [F]."
	if not "navigator" in equipment:
		return "Fabricate the Navigation Instrument at the pod."
	if not unlocked("array"):
		return "Follow recorder telemetry to Eurydice. Scan 3 navigation assemblies."
	if count("reactor") < 3 and not completed:
		return "Cut shielded reactor equipment in Eurydice [2 / hold LMB]."
	if not completed:
		return "Return home. Connect a Navigation Array to your functioning station."
	return "Array online. Explore remaining contacts. Your station is a foothold in the dark."

func reveal(pos: Vector2) -> void:
	var cell := Vector2i(floori(pos.x / GameData.pixels(Vector2(12, 0)).x), floori(pos.y / (12.0 * GameData.PPM)))
	for x in range(-2, 3):
		for y in range(-2, 3):
			if x * x + y * y <= 5:
				explored["%d,%d" % [cell.x + x, cell.y + y]] = true

func respawn() -> void:
	for item in inventory:
		if item not in ["canister", "repair"]:
			inventory[item] = maxi(0, count(item) - ceili(count(item) * 0.1))
	position = recovery + Vector2(0, 50)
	health = 100
	oxygen = 100
	power = 100
	message.emit("EMERGENCY RECOVERY / Returned to last refuge. Lost 10% of each material stack.")
	changed.emit()

func serialize() -> Dictionary:
	return {"version": 1, "position": [position.x, position.y], "recovery": [recovery.x, recovery.y],
		"health": health, "oxygen": oxygen, "power": power, "inventory": inventory,
		"equipment": equipment, "scans": scans, "scan_progress": scan_progress, "depleted": depleted,
		"modules": modules, "discoveries": discoveries, "explored": explored, "logs": logs,
		"milestones": milestones, "waypoint": [waypoint.x, waypoint.y], "waypoint_active": waypoint_active,
		"completed": completed, "elapsed": elapsed, "settings": settings}

func save_game(path: String = "") -> bool:
	if path.is_empty(): path = save_path
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		message.emit("Save failed / " + error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(serialize(), "\t"))
	file.close()
	var error := DirAccess.rename_absolute(temporary, path)
	if error != OK:
		message.emit("Save failed / " + error_string(error))
		return false
	return true

func load_game(path: String = "") -> bool:
	if path.is_empty(): path = save_path
	if not FileAccess.file_exists(path):
		message.emit("No save found. Your current game is unchanged.")
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	var raw: Variant = parser.data if parse_error == OK else null
	if not validate_save(raw):
		message.emit("Save is corrupt or incompatible. Your current game is unchanged.")
		return false
	var data: Dictionary = raw
	position = Vector2(float(data.position[0]), float(data.position[1]))
	recovery = Vector2(float(data.recovery[0]), float(data.recovery[1]))
	health = clampf(float(data.health), 0, 100)
	oxygen = clampf(float(data.oxygen), 0, 100)
	power = clampf(float(data.power), 0, 100)
	inventory = data.inventory.duplicate(true)
	for item in inventory:
		inventory[item] = int(inventory[item])
	equipment = data.equipment.duplicate()
	scans = data.scans.duplicate()
	scan_progress = data.scan_progress.duplicate()
	depleted = data.depleted.duplicate()
	modules = data.modules.duplicate(true)
	for module in modules:
		module.x = int(module.x)
		module.y = int(module.y)
		module.rotation = int(module.rotation)
	discoveries = data.discoveries.duplicate()
	explored = data.explored.duplicate()
	logs = data.logs.duplicate()
	milestones = data.milestones.duplicate()
	waypoint = Vector2(float(data.waypoint[0]), float(data.waypoint[1]))
	waypoint_active = data.waypoint_active
	completed = data.completed
	elapsed = float(data.elapsed)
	settings = data.settings.duplicate()
	recalculate_network()
	changed.emit()
	message.emit("Save restored / all systems synchronized.")
	return true

func validate_save(raw: Variant) -> bool:
	if not raw is Dictionary or raw.get("version") != 1:
		return false
	for key in ["position", "recovery", "waypoint"]:
		if not raw.get(key) is Array or raw[key].size() != 2:
			return false
		for value in raw[key]:
			if not numeric(value) or not is_finite(float(value)) or absf(float(value)) > 20000:
				return false
	for key in ["health", "oxygen", "power", "elapsed"]:
		if not numeric(raw.get(key)) or not is_finite(float(raw[key])):
			return false
	for key in ["equipment", "depleted", "modules", "discoveries", "logs", "milestones"]:
		if not raw.get(key) is Array:
			return false
	for key in ["inventory", "scans", "scan_progress", "explored", "settings"]:
		if not raw.get(key) is Dictionary:
			return false
	if not raw.get("completed") is bool or not raw.get("waypoint_active") is bool:
		return false
	var total: int = 0
	for item in raw.inventory:
		if not GameData.ITEMS.has(item) or not numeric(raw.inventory[item]) or float(raw.inventory[item]) < 0:
			return false
		total += int(raw.inventory[item])
	if total > GameData.SUIT.inventory_capacity:
		return false
	for tool in raw.equipment:
		if tool not in ["scanner", "cutter", "builder", "navigator"]:
			return false
	var content: Dictionary = {}
	for object in GameData.objects():
		content[object.id] = object
	for id in raw.scans:
		if not content.has(id) or content[id].kind != "fragment" or raw.scans[id] != content[id].payload:
			return false
	for id in raw.scan_progress:
		if not content.has(id) or not numeric(raw.scan_progress[id]) or float(raw.scan_progress[id]) < 0 or float(raw.scan_progress[id]) > 1:
			return false
	var cells: Dictionary = {}
	var ids: Dictionary = {}
	for module in raw.modules:
		if not module is Dictionary or not recipes.has(module.get("recipe", "")):
			return false
		if recipes[module.recipe].build_type != "structure" or not module.get("id") is String:
			return false
		for key in ["x", "y", "rotation"]:
			if not numeric(module.get(key)) or absf(float(module[key])) > 100:
				return false
		var cell := "%d,%d" % [int(module.x), int(module.y)]
		if cell == "0,0" or cells.has(cell) or ids.has(module.id):
			return false
		cells[cell] = true
		ids[module.id] = true
	if not numeric(raw.settings.get("volume")) or not raw.settings.get("look_ahead") is bool:
		return false
	return true

func numeric(value: Variant) -> bool:
	return value is float or value is int
