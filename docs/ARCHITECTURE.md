# Technical architecture

`scenes/main.tscn` creates the game from `scripts/core/game.gd`. It assembles a background CanvasLayer, Battlefield, EVAPlayer/Camera2D, screen-space HUD and suit audio. There are no autoload singletons or third-party libraries.

## Model and content

**GameState** is a RefCounted authoritative model. Inventory, equipment, completed/partial scans, depletion IDs, station descriptors, exploration cells, logs and milestones are serializable data. `message` and `changed` signals report model events. Fabrication and construction check affordability before subtracting costs; failed actions leave inventory unchanged. Distinct authored fragment IDs are checked against the content registry before awarding research.

**GameData** defines world coordinates, unit conversions, survival tuning, item definitions, deterministic loot tables and handcrafted wreck/object descriptors. The ten `.tres` resources in `resources/recipes/` instantiate **RecipeDefinition**. Definitions share ID, title, description, category, fragment requirement, costs, prerequisites, result type/scene and production/demand. All constructible recipes instantiate the reusable module scene. Equipment uses the player's shared scanner/cutter/builder systems; its ID is delivered to the equipment collection. Consumables are delivered to inventory.

The coordinate system is X east/right, Y south/down. World north is **−Y**; heading is clockwise from north. **28.24 world pixels = 1 meter**. Displayed navigation always goes through `GameData.meters()`; authored meter locations use `GameData.pixels()`. The pod is the world origin. World extents are ±300m X and ±200m Y.

## Physics and tools

**EVAPlayer** is a CharacterBody2D with capsule collision, acceleration, exponentially damped inertia, capped speed, boost and active brake. Magnetic boots switch to precise walking only on pod/wreck/module floors. Hull StaticBody2D walls occupy collision layer 1; player occupies layer 2. Scanner rays query layer 1, so walls also block research and cargo interaction. Local generated cone lighting follows suit orientation.

**Battlefield** creates static hull segments, leaving southern breaches and internal room doorways. It owns authored interactable descriptors, tool highlight selection, cyclic hazards, placement queries and station visual nodes. One nearest-target/raycast query runs for interaction and another for aimed tool use. `game.gd` drives continuous scanning/cutting progress and pays suit power. Scan progress belongs to stable fragment IDs and is resumable; salvage cutting progress is session-local, while depletion is persistent. Completed research and fabrication save at the point of success.

Tools are separate orchestration methods rather than a deep scene hierarchy. Future weapons/tools can add a definition and their own handler without changing the persistence model. To add content, create a recipe resource, add its ID to the recipe catalog, then place fragment descriptors with unique IDs and the matching recipe payload. To add wrecks, add a position/size/tone descriptor and authored equipment positions. Do not change existing stable IDs without a migration.

## Construction and station graph

The builder snaps to a **256px square grid**, about 9.07m. World placement rejects excessive range, missing research/materials, occupied cells, diagonal/unconnected attachments, world bounds, wreck overlap and placement over the player. Only the orchestration layer commits placement after these physical checks. `GameState.place()` independently checks ownership, research, resources and graph adjacency, then records a descriptor with stable ID, cell, recipe and orientation.

**StationModule** instances build over 1.8s, draw from the common procedural art library and supply static collision around four open ports. Rotation affects art only because footprints and ports are rotationally symmetric. Power status becomes authoritative on placement; the animation is presentation rather than a delayed network transaction.

GameState performs a connected-component traversal when modules change or load. Orthogonal cells are neighbors; modules docked to any of the pod's four orthogonal ports also share its passive bus. Each component sums generation and demand. It is operational only if generation is positive and covers total demand. Recyclers supply oxygen only to their own powered component. Rooms in that component become habitable and can replenish suit reserves/set the recovery point. Arrays require a component containing a powered recycler and habitat to trigger completion. There is no per-frame full graph calculation, pressure solver, cable simulation or partial brownout priority scheme.

## Rendering and navigation

**IndustrialArt** draws original hull plates, scratches, seams, fasteners, equipment, consoles, habitat furniture and module hardware. **Battlefield** culls distant wreck/debris/object drawing against the current camera bounds and reduces deck detail below zoom 0.6. Decoration has no physics. Three main wrecks and built modules provide a small static collision set; no thousands of active rigid bodies are spawned.

**ParallaxEnvironment** uses camera-relative screen-space offsets with different factors for stars/haze, celestial limb and enormous decorative wrecks. Foreground dust is drawn in the HUD layer at a factor above the gameplay plane. The canvas world is the fifth, playable layer. Background geometry remains decorative and unbounded at every zoom; there are no world-sized textures or texture edges. Star positions wrap across an area larger than the logical viewport. Background hulks have muted silhouettes and no interaction markers.

**NavigationChart** projects meter coordinates into a 600×400m chart. It shows only explored 12m cells and confirmed discoveries, plus recorder telemetry as an unconfirmed marker. A crafted Navigation Instrument enables chart/coordinate/heading UI. Home bearing is always available. User clicks set a waypoint back in the same world-space pixel coordinate system. Signal descriptors and confirmed/unconfirmed state are extension points for future triangulation.

## UI, audio and persistence

**GameHUD** is a screen-space Control on a CanvasLayer. It renders compact telemetry and opens scrollable modal menus for inventory, fabrication, research, construction, chart, archive, pause and settings. Modal menus disable the player and suit progression; world decorative light/particle animation continues. Settings control audio and look-ahead. **SuitAudio** synthesizes short mono WAV ambience and interface tones entirely in memory, skipping playback for headless testing.

Saves use versioned JSON in Godot's user data directory, writing a temporary file and then renaming it. Validation checks required shapes/types, numeric finiteness, legal items/equipment, capacity, authored fragment identities, legal module recipes/coordinates and duplicate module IDs/cells. Loading canonicalizes integer quantities/cells after JSON decoding, then derives research availability and recomputes station components. Network dictionaries and visual node instances are never persisted. A malformed save does not mutate the session. The `save_path` model field lets automated tests isolate persistence from the player's save slot.

The test runner exercises the authored progression economically, model invariants, live main-scene physics and input, hazard/survival behavior, tool integration and all menu constructors. Visual captures use the real graphics driver. Extension work should continue to test both the pure model and actual scene boundaries.
