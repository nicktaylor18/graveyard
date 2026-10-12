class_name GameData
extends RefCounted

const PPM: float = 28.24
const WORLD_METERS := Vector2(600, 400)
const GRID: float = 256.0
const SUIT := {"oxygen_rate": 0.18, "power_idle": 0.015, "power_thrust": 0.075,
	"power_tool": 0.16, "inventory_capacity": 280, "scan_range": 175.0, "tool_range": 145.0}
const ITEMS := {
	"scrap": ["Scrap Metal", "Recoverable ferrous structural material.", "Fe", Color("9aa8ad")],
	"alloy": ["Alloy Plates", "Vacuum-rated hull and habitat plating.", "Al", Color("bcc5cb")],
	"electronics": ["Electronic Components", "Resilient control circuits.", "IC", Color("71b5b5")],
	"copper": ["Copper Wiring", "High-current power conduits.", "Cu", Color("d39a69")],
	"polymer": ["Polymer", "Seals, insulation and suit materials.", "Po", Color("b3a995")],
	"cells": ["Power Cells", "Stable rechargeable energy packs.", "Pw", Color("8cb3aa")],
	"reactor": ["Rare Reactor Components", "Shielded military field components.", "Rx", Color("dda85e")],
	"canister": ["Oxygen Canister", "Use from inventory to restore 50 oxygen.", "O2", Color("72c4c9")],
	"repair": ["Repair Kit", "Use from inventory to restore 45 health.", "+", Color("bcce99")],
}
const LOOT := {
	"starter": {"scrap": 16, "electronics": 5, "copper": 6, "polymer": 6, "alloy": 6, "cells": 2},
	"fighter": {"scrap": 10, "alloy": 6, "electronics": 5, "copper": 4, "cells": 2},
	"cargo": {"scrap": 14, "alloy": 10, "electronics": 6, "copper": 8, "polymer": 8, "cells": 3},
	"frigate": {"scrap": 10, "alloy": 12, "electronics": 8, "copper": 5, "cells": 3, "reactor": 2},
	"cache": {"alloy": 8, "polymer": 5, "cells": 3},
}

static func meters(pixel_position: Vector2) -> Vector2:
	return pixel_position / PPM

static func pixels(meter_position: Vector2) -> Vector2:
	return meter_position * PPM

static func heading(direction: Vector2) -> float:
	return fposmod(rad_to_deg(atan2(direction.x, -direction.y)), 360.0)

static func recipes() -> Dictionary:
	var result: Dictionary = {}
	for id in ["cutter", "builder", "navigator", "canister", "repair", "corridor", "habitat", "solar", "oxygen", "array"]:
		var recipe: RecipeDefinition = load("res://resources/recipes/" + id + ".tres")
		result[recipe.id] = recipe
	return result

static func wrecks() -> Array[Dictionary]:
	return [
		{"id": "fighter", "name": "KESTREL / 09", "position": pixels(Vector2(22, -12)), "size": pixels(Vector2(12, 7)), "tone": Color("464b4c")},
		{"id": "cargo", "name": "CARGO / MNEMOSYNE", "position": pixels(Vector2(92, 32)), "size": pixels(Vector2(36, 15)), "tone": Color("4d4b43")},
		{"id": "frigate", "name": "FRIGATE / EURYDICE", "position": pixels(Vector2(210, -105)), "size": pixels(Vector2(72, 24)), "tone": Color("424b52")},
	]

static func objects() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(3):
		result.append(object("supply_%d" % i, "container", "Emergency supply case", Vector2(4 + i * 3, 3 + i * 2), "starter"))
	result.append(object("pod", "pod", "Escape pod / fabricator", Vector2.ZERO))
	var locations := {
		"fighter": [["solar", Vector2(21, -13)], ["habitat", Vector2(25, -11)]],
		"cargo": [["solar", Vector2(83, 29)], ["habitat", Vector2(94, 29)], ["habitat", Vector2(103, 35)], ["oxygen", Vector2(91, 36)], ["oxygen", Vector2(101, 29)]],
		"frigate": [["array", Vector2(188, -110)], ["array", Vector2(212, -110)], ["array", Vector2(234, -102)]],
	}
	for wreck in locations:
		var index: int = 0
		for entry in locations[wreck]:
			result.append(object("%s_fragment_%d" % [wreck, index], "fragment", "Damaged " + str(entry[0]).capitalize() + " assembly", entry[1], entry[0]))
			index += 1
	for i in range(2):
		result.append(object("fighter_salvage_%d" % i, "salvage", "Kestrel engine housing", Vector2(18 + i * 6, -12), "fighter"))
	for i in range(4):
		result.append(object("cargo_case_%d" % i, "container", "Transport cargo locker", Vector2(79 + i * 7, 33), "cargo"))
		result.append(object("cargo_salvage_%d" % i, "salvage", "Damaged cargo machinery", Vector2(81 + i * 7, 28), "cargo"))
	for i in range(4):
		result.append(object("frigate_salvage_%d" % i, "salvage", "Shielded reactor equipment", Vector2(186 + i * 15, -105), "frigate"))
	result.append(object("cargo_recorder", "log", "Mnemosyne flight recorder", Vector2(106, 32), "frigate"))
	result.append(object("frigate_log", "log", "Eurydice command archive", Vector2(238, -112), "archive"))
	result.append(object("cache", "container", "Drifting survey cache", Vector2(-32, 38), "cache"))
	result.append(object("signal", "signal", "Unidentified carrier pulse", Vector2(-65, -45), "signal"))
	return result

static func object(id: String, kind: String, title: String, pos: Vector2, payload: String = "") -> Dictionary:
	return {"id": id, "kind": kind, "title": title, "position": pixels(pos), "payload": payload}
