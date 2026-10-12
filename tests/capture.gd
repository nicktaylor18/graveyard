extends SceneTree
## Deterministic visual review images; run with a graphical rendering driver.
var game

func _initialize() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://tests/" + name + ".png")
	print("CAPTURE / " + name)

func move_to(pos: Vector2, zoom: float) -> void:
	game.player.global_position = pos
	game.state.position = pos
	game.player.camera.position = Vector2.ZERO
	game.player.camera.zoom = Vector2.ONE * zoom
	game.player.target_zoom = zoom
	game.player.camera.reset_smoothing()
	game.player.enabled = false
	game.simulation_paused = true
	game.state.reveal(pos)
	await process_frame

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.state.save_path = "res://tests/_capture_save.json"
	await create_timer(0.4).timeout
	await shot("intro")
	game.hud.close()
	await move_to(Vector2(40, 60), 1.5)
	await shot("quiet_drift")
	await move_to(GameData.pixels(Vector2(92, 32)), 1.0)
	await shot("cargo")
	await move_to(GameData.pixels(Vector2(210, -105)), 0.375)
	await shot("survey")
	game.state.equipment = ["scanner", "cutter", "builder", "navigator"]
	game.state.inventory = {"scrap": 40, "alloy": 50, "electronics": 30, "copper": 30, "polymer": 20, "cells": 12, "reactor": 4}
	for object in GameData.objects():
		if object.kind == "fragment": game.state.complete_scan(object.id, object.payload)
	game.state.place("habitat", Vector2i(1, 0))
	game.state.place("solar", Vector2i(1, 1))
	game.state.place("oxygen", Vector2i(2, 1))
	game.state.place("array", Vector2i(2, 0))
	game.battlefield.sync_modules(true)
	await move_to(Vector2(260, 140), 1.0)
	await shot("station")
	game.state.discoveries = ["pod", "fighter", "cargo", "frigate", "signal"]
	game.state.logs = ["cargo_recorder", "frigate_log"]
	game.hud.open("map")
	await shot("map")
	game.hud.open("fabricator")
	await shot("fabricator")
	game.queue_free()
	await process_frame
	print("VISUAL CAPTURE COMPLETE")
	quit()
