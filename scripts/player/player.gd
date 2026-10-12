class_name EVAPlayer
extends CharacterBody2D

@export var acceleration: float = 230.0
@export var max_speed: float = 260.0
@export var damping: float = 0.26
@export var boost_multiplier: float = 1.75
var state: GameState
var battlefield: Battlefield
var camera: Camera2D
var enabled: bool = true
var boots: bool = false
var flashlight: bool = true
var thrust := Vector2.ZERO
var facing: float = 0.0
var time: float = 0.0
var target_zoom: float = 1.5
var suit_light: PointLight2D

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 12
	capsule.height = 42
	shape.shape = capsule
	add_child(shape)
	camera = Camera2D.new()
	camera.zoom = Vector2.ONE * 1.5
	camera.position_smoothing_enabled = false
	camera.position_smoothing_speed = 5
	camera.limit_left = -8800
	camera.limit_right = 8800
	camera.limit_top = -5900
	camera.limit_bottom = 5900
	add_child(camera)
	# A locally generated cone texture; no downloaded assets.
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for y in range(256):
		for x in range(256):
			var p := Vector2(x - 128, y - 128) / 128.0
			var distance := p.length()
			var cone := clampf((-p.y - absf(p.x) * 1.8) * 4, 0, 1)
			var alpha := clampf(1 - distance, 0, 1) * cone
			image.set_pixel(x, y, Color(0.77, 0.88, 0.85, alpha))
	suit_light = PointLight2D.new()
	suit_light.texture = ImageTexture.create_from_image(image)
	suit_light.texture_scale = 3.0
	suit_light.energy = 0.85
	suit_light.blend_mode = Light2D.BLEND_MODE_ADD
	add_child(suit_light)

func axis() -> Vector2:
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): input.y -= 1
	if Input.is_physical_key_pressed(KEY_S): input.y += 1
	if Input.is_physical_key_pressed(KEY_A): input.x -= 1
	if Input.is_physical_key_pressed(KEY_D): input.x += 1
	return input.normalized()

func _physics_process(delta: float) -> void:
	time += delta
	if not enabled:
		thrust = Vector2.ZERO
		queue_redraw()
		return
	thrust = axis()
	var mouse := get_global_mouse_position()
	if mouse.distance_to(global_position) > 12:
		facing = lerp_angle(facing, (mouse - global_position).angle() + PI / 2, 1 - exp(-delta * 13))
	if boots and not battlefield.on_surface(global_position):
		boots = false
		state.message.emit("Magnetic contact lost / EVA thrusters active.")
	if boots:
		velocity = velocity.move_toward(thrust * 110, delta * 1100)
	else:
		var boost := Input.is_physical_key_pressed(KEY_SHIFT) and state.power > 0
		var multiplier := boost_multiplier if boost else 1.0
		var efficiency := 1.0 if state.power > 0 else 0.3
		velocity += thrust * acceleration * delta * multiplier * efficiency
		velocity *= exp(-damping * delta)
		if Input.is_physical_key_pressed(KEY_SPACE):
			velocity = velocity.move_toward(Vector2.ZERO, acceleration * 1.6 * delta)
		velocity = velocity.limit_length(max_speed * multiplier * efficiency)
		if thrust.length_squared() > 0:
			state.power = maxf(0, state.power - GameData.SUIT.power_thrust * multiplier * delta)
	move_and_slide()
	global_position.x = clampf(global_position.x, -GameData.WORLD_METERS.x * GameData.PPM / 2, GameData.WORLD_METERS.x * GameData.PPM / 2)
	global_position.y = clampf(global_position.y, -GameData.WORLD_METERS.y * GameData.PPM / 2, GameData.WORLD_METERS.y * GameData.PPM / 2)
	state.position = global_position
	state.elapsed += delta
	var safe := state.safe_at(global_position)
	if safe:
		state.oxygen = minf(100, state.oxygen + delta * 14)
		state.power = minf(100, state.power + delta * 16)
	else:
		state.oxygen = maxf(0, state.oxygen - GameData.SUIT.oxygen_rate * delta)
		state.power = maxf(0, state.power - (GameData.SUIT.power_idle + (0.035 if flashlight else 0.0)) * delta)
	if state.oxygen <= 0:
		state.health = maxf(0, state.health - delta * 14)
	for hazard in battlefield.hazards:
		if battlefield.hazard_active(hazard) and global_position.distance_to(hazard.position) < hazard.radius:
			state.health = maxf(0, state.health - delta * 23)
	if state.health <= 0:
		state.respawn()
		global_position = state.position
		velocity = Vector2.ZERO
		camera.reset_smoothing()
	state.reveal(global_position)
	var look := velocity * 0.26 if state.settings.look_ahead else Vector2.ZERO
	camera.position = camera.position.lerp(look, 1 - exp(-delta * 3))
	camera.zoom = camera.zoom.lerp(Vector2.ONE * target_zoom, 1 - exp(-delta * 8))
	suit_light.rotation = facing
	suit_light.visible = flashlight and state.power > 0
	queue_redraw()

func change_zoom(factor: float) -> void:
	target_zoom = clampf(target_zoom * factor, 0.375, 2.25)

func toggle_boots() -> void:
	if boots:
		boots = false
	elif battlefield.on_surface(global_position):
		boots = true
	else:
		state.message.emit("No magnetic surface / enter a wreck or station.")
		return
	state.message.emit("Magnetic boots " + ("ENGAGED" if boots else "RELEASED"))

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, facing)
	if thrust.length_squared() > 0 and not boots and enabled:
		for x in [-12, 12]:
			var length := 12 + sin(time * 52 + x) * 4
			draw_colored_polygon(PackedVector2Array([Vector2(x - 3, 13), Vector2(x + 3, 13), Vector2(x, 13 + length)]), Color(0.44, 0.69, 0.81, 0.65))
			draw_line(Vector2(x, 13), Vector2(x, 18), Color("d3e8dc"), 2)
	# Backpack, asymmetric tool arm, suit padding and a dark overhead visor.
	IndustrialArt.plate(self, Rect2(-12, -4, 24, 29), Color("586360"))
	draw_rect(Rect2(-8, 15, 16, 7), Color("38434b"))
	draw_line(Vector2(-8, 10), Vector2(-10, 22), Color("c3c4ad"), 8)
	draw_line(Vector2(8, 10), Vector2(10, 22), Color("c3c4ad"), 8)
	draw_circle(Vector2(-10, 22), 4, Color("2c3742"))
	draw_circle(Vector2(10, 22), 4, Color("2c3742"))
	draw_line(Vector2(-12, -9), Vector2(-17, 3), Color("b6b6a1"), 8)
	draw_line(Vector2(12, -9), Vector2(16, -16), Color("b6b6a1"), 8)
	draw_rect(Rect2(13, -27, 6, 16), Color("607c83"))
	draw_circle(Vector2(0, -14), 12, Color("c5c7ae"))
	draw_circle(Vector2(0, -17), 9, Color("233741"))
	draw_arc(Vector2(0, -17), 7, PI * 1.05, PI * 1.8, 12, Color("8fc2c5"), 2)
	draw_line(Vector2(-4, 0), Vector2(4, 0), IndustrialArt.AMBER, 3)
	draw_circle(Vector2(12, -5), 2, IndustrialArt.CYAN)
	draw_set_transform(Vector2.ZERO)
	if boots:
		draw_arc(Vector2.ZERO, 31, 0, TAU, 24, Color(0.5, 0.8, 0.65, 0.55), 1)
