extends Node3D

# Presentation time is accelerated; press T for sidereal real-time rotation.
const SIDEREAL_DAY := 86164.0905
const DEMO_DAY := 240.0
var realistic_speed := false
var rotating := true
var dragging := false
var yaw := 0.0
var pitch := 0.16
var target_yaw := 0.0
var target_pitch := 0.16
var distance := 3.8
var target_distance := 3.8
var spin: Node3D
var cloud_sphere: MeshInstance3D
var camera: Camera3D
var surface_material: ShaderMaterial
var status: Label
var interface: CanvasLayer
var elapsed := 0.0
var cloud_angle := 0.0
var capture_path := ""
var self_test := false
var frames := 0
var flare_material: ShaderMaterial
var solar_capture := false
var eclipse_capture := false
var flare_disabled_for_capture := false
var sunlight: DirectionalLight3D
var sun_sky_material: ShaderMaterial
var atmosphere_material: ShaderMaterial

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
		if arg == "--sun-view":
			solar_capture = true
		if arg == "--eclipse-view":
			eclipse_capture = true
		if arg == "--no-flare":
			flare_disabled_for_capture = true
		if arg == "--self-test":
			self_test = true
	if not capture_path.is_empty():
		rotating = false
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1600, 900))
	_build_environment()
	_build_earth()
	_build_camera()
	_build_sun_flare()
	_build_interface()
	if solar_capture:
		_solar_view()
		yaw = target_yaw
		pitch = target_pitch
		_position_camera()
	if eclipse_capture:
		var sun: Vector3 = get_meta("sun_direction")
		yaw = atan2(-sun.x, -sun.z)
		pitch = asin(-sun.y)
		target_yaw = yaw
		target_pitch = pitch
		_position_camera()
	_update_status()

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var panorama := ShaderMaterial.new()
	panorama.shader = load("res://shaders/space_sun.gdshader")
	sun_sky_material = panorama
	panorama.set_shader_parameter("space_map", load("res://assets/space.jpg"))
	var sky := Sky.new()
	sky.sky_material = panorama
	env.sky = sky
	env.sky_rotation = Vector3.ZERO
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.ambient_light_color = Color(0.08, 0.11, 0.18)
	env.ambient_light_energy = 0.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	sunlight = DirectionalLight3D.new()
	sunlight.name = "InvisibleSunlight"
	sunlight.light_color = Color(1.0, 0.98, 0.95)
	sunlight.light_energy = 1.15
	sunlight.rotation_degrees = Vector3(-18.0, -20.0, 0.0)
	sunlight.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sunlight)
	# A directional light shines along local -Z. +Z points toward the Sun.
	var direction := sunlight.global_basis.z.normalized()
	set_meta("sun_direction", direction)
	panorama.set_shader_parameter("sun_direction", direction)

func _sphere(radius: float, material: Material, parent: Node3D, node_name: String) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 256
	mesh.rings = 128
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _build_earth() -> void:
	var axis := Node3D.new()
	axis.name = "AxialTilt"
	axis.rotation.z = deg_to_rad(-23.44)
	add_child(axis)
	spin = Node3D.new()
	spin.name = "EarthRotation"
	spin.rotation.y = deg_to_rad(155.0)
	axis.add_child(spin)
	surface_material = ShaderMaterial.new()
	surface_material.shader = load("res://shaders/surface.gdshader")
	surface_material.set_shader_parameter("day_map", load("res://assets/earth_day.jpg"))
	surface_material.set_shader_parameter("night_map", load("res://assets/earth_night.jpg"))
	surface_material.set_shader_parameter("ocean_map", load("res://assets/earth_specular.png"))
	surface_material.set_shader_parameter("cloud_map", load("res://assets/earth_clouds.jpg"))
	surface_material.set_shader_parameter("sun_direction", get_meta("sun_direction"))
	var earth := _sphere(1.0, surface_material, spin, "EarthSurface")
	earth.scale.y = 0.99665
	var clouds := ShaderMaterial.new()
	clouds.shader = load("res://shaders/clouds.gdshader")
	clouds.set_shader_parameter("cloud_map", load("res://assets/earth_clouds.jpg"))
	cloud_sphere = _sphere(1.002, clouds, spin, "CloudLayer")
	cloud_sphere.scale.y = 0.99665
	var atmosphere := ShaderMaterial.new()
	atmosphere.shader = load("res://shaders/atmosphere.gdshader")
	atmosphere_material = atmosphere
	atmosphere.set_shader_parameter("sun_direction", get_meta("sun_direction"))
	_sphere(1.025, atmosphere, self, "Atmosphere")

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "OrbitCamera"
	camera.fov = 42.0
	camera.near = 0.01
	camera.far = 100.0
	camera.current = true
	add_child(camera)
	_position_camera()

func _build_sun_flare() -> void:
	var layer := CanvasLayer.new()
	layer.name = "SunGlare"
	layer.layer = 0
	add_child(layer)
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flare_material = ShaderMaterial.new()
	flare_material.shader = load("res://shaders/sun_flare.gdshader")
	overlay.material = flare_material
	layer.add_child(overlay)

func _solar_view() -> void:
	var sun: Vector3 = get_meta("sun_direction")
	target_yaw = atan2(-sun.x, -sun.z) + 0.48
	target_pitch = asin(-sun.y)
	target_distance = 3.8

func _sync_sun_direction() -> void:
	# One world-space source of truth: the light's +Z points toward the Sun.
	var direction := sunlight.global_basis.z.normalized()
	var old_direction: Vector3 = get_meta("sun_direction")
	if old_direction.is_equal_approx(direction): return
	set_meta("sun_direction", direction)
	sun_sky_material.set_shader_parameter("sun_direction", direction)
	surface_material.set_shader_parameter("sun_direction", direction)
	atmosphere_material.set_shader_parameter("sun_direction", direction)

func _update_sun_flare() -> void:
	var sun: Vector3 = get_meta("sun_direction")
	var point := camera.global_position + sun * 50.0
	var size := get_viewport().get_visible_rect().size
	var visibility := 0.0
	var uv := Vector2(-2, -2)
	if not camera.is_position_behind(point):
		uv = camera.unproject_position(point) / size
		var angular_separation := acos(clampf(sun.dot(-camera.global_position.normalized()), -1.0, 1.0))
		var earth_radius := asin(1.025 / camera.global_position.length())
		visibility = smoothstep(earth_radius - 0.005, earth_radius + 0.005, angular_separation)
		var margin := minf(minf(uv.x + 0.2, 1.2 - uv.x), minf(uv.y + 0.2, 1.2 - uv.y))
		visibility *= smoothstep(0.0, 0.15, margin)
	flare_material.set_shader_parameter("camera_position", camera.global_position)
	flare_material.set_shader_parameter("camera_basis", camera.global_basis)
	flare_material.set_shader_parameter("tan_half_fov", tan(deg_to_rad(camera.fov * 0.5)))
	flare_material.set_shader_parameter("sun_uv", uv)
	flare_material.set_shader_parameter("resolution", size)
	flare_material.set_shader_parameter("visibility", 0.0 if flare_disabled_for_capture else visibility)
	flare_material.set_shader_parameter("angular_pixel_radius", size.y * 0.00465*3.0 / (2.0 * tan(deg_to_rad(camera.fov * 0.5))))

func _build_interface() -> void:
	interface = CanvasLayer.new()
	interface.layer = 1
	add_child(interface)
	var box := VBoxContainer.new()
	box.position = Vector2(30, 28)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interface.add_child(box)
	var title := Label.new()
	title.text = "EARTH  /  地球"
	title.add_theme_font_size_override("font_size", 22)
	title.modulate = Color(0.82, 0.9, 1.0, 0.85)
	box.add_child(title)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 14)
	status.modulate = Color(0.75, 0.83, 0.92, 0.7)
	box.add_child(status)
	var controls := Label.new()
	controls.text = "拖动鼠标：环绕视角   滚轮：缩放\n空格：暂停自转   T：真实速度   R：复位\nS：朝向太阳   H：隐藏文字   F11：全屏切换   Esc：退出"
	controls.add_theme_font_size_override("font_size", 15)
	controls.add_theme_color_override("font_shadow_color", Color.BLACK)
	controls.add_theme_constant_override("shadow_offset_x", 1)
	controls.add_theme_constant_override("shadow_offset_y", 1)
	controls.modulate = Color(0.75, 0.83, 0.92, 0.75)
	controls.position = Vector2(30, get_viewport().get_visible_rect().size.y - 100)
	interface.add_child(controls)
	get_viewport().size_changed.connect(func(): controls.position.y = get_viewport().get_visible_rect().size.y - 100)

func _update_status() -> void:
	status.text = ("恒星日：23小时56分 · 真实速度" if realistic_speed else "演示自转：240秒 / 圈") + ("  ·  已暂停" if not rotating else "")

func _position_camera() -> void:
	camera.position = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(Vector3.ZERO, Vector3.UP)

func _process(delta: float) -> void:
	elapsed += delta
	frames += 1
	var smoothing := 1.0 - exp(-12.0 * delta)
	yaw = lerpf(yaw, target_yaw, smoothing)
	pitch = lerpf(pitch, target_pitch, smoothing)
	distance = lerpf(distance, target_distance, smoothing)
	if rotating:
		var rate := TAU / (SIDEREAL_DAY if realistic_speed else DEMO_DAY)
		spin.rotation.y += rate * delta
		cloud_angle += rate * delta * 0.015
		cloud_sphere.rotation.y = cloud_angle
		surface_material.set_shader_parameter("cloud_offset", -cloud_angle / TAU)
	_position_camera()
	_sync_sun_direction()
	_update_sun_flare()
	if self_test and frames == 5:
		_run_self_test()
	if not capture_path.is_empty() and frames == 90:
		interface.visible = false
		_capture.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if not capture_path.is_empty(): return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_distance = maxf(1.35, target_distance * 0.88)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_distance = minf(12.0, target_distance / 0.88)
	elif event is InputEventMouseMotion and dragging:
		target_yaw -= event.relative.x * 0.005
		target_pitch = clampf(target_pitch + event.relative.y * 0.005, -1.48, 1.48)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE: get_tree().quit()
			KEY_SPACE:
				rotating = not rotating
				_update_status()
			KEY_T:
				realistic_speed = not realistic_speed
				_update_status()
			KEY_S: _solar_view()
			KEY_H: interface.visible = not interface.visible
			KEY_R:
				target_yaw = 0.0
				target_pitch = 0.16
				target_distance = 3.8
			KEY_F11:
				var mode := DisplayServer.window_get_mode()
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(capture_path)
	print("CAPTURE_RESULT=", result)
	get_tree().quit()

func _run_self_test() -> void:
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	for i in range(100): _unhandled_input(wheel)
	assert(is_equal_approx(target_distance, 1.35), "Zoom-in bound")
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	for i in range(100): _unhandled_input(wheel)
	assert(is_equal_approx(target_distance, 12.0), "Zoom-out bound")
	dragging = true
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100, 10000)
	_unhandled_input(motion)
	assert(target_yaw < 0 and target_pitch <= 1.48, "Orbit and pole clamp")
	dragging = false
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_SPACE
	_unhandled_input(key)
	assert(not rotating, "Pause")
	var previous := spin.rotation.y
	_process(1.0)
	assert(is_equal_approx(previous, spin.rotation.y), "Paused rotation")
	_unhandled_input(key)
	_process(1.0)
	assert(spin.rotation.y > previous, "Resume rotation")
	key.keycode = KEY_R
	_unhandled_input(key)
	assert(is_equal_approx(target_distance, 3.8) and is_zero_approx(target_yaw), "Reset")
	key.keycode = KEY_T
	_unhandled_input(key)
	assert(realistic_speed, "Real-time rotation")
	assert(camera.position.is_finite(), "Finite camera")
	_test_sun_alignment()
	print("SELF_TEST_PASS: zoom bounds, orbit, pause/resume, reset, real-time mode")
	get_tree().quit()


func _test_sun_alignment() -> void:
	var original_rotation := sunlight.rotation
	sunlight.rotation.y += 0.2
	_sync_sun_direction()
	var sun := sunlight.global_basis.z.normalized()
	for material in [sun_sky_material, surface_material, atmosphere_material]:
		var direction: Vector3 = material.get_shader_parameter("sun_direction")
		assert(direction.is_equal_approx(sun), "Sun shader/light alignment")
	assert(sun.dot(sun) > 0.999 and (-sun).dot(sun) < -0.999, "Day/night normal convention")
	sunlight.rotation = original_rotation
	_sync_sun_direction()
	sun = sunlight.global_basis.z.normalized()
	yaw = atan2(-sun.x, -sun.z)
	pitch = asin(-sun.y)
	distance = 3.8
	_position_camera()
	_update_sun_flare()
	assert(is_zero_approx(float(flare_material.get_shader_parameter("visibility"))), "Earth eclipses sun")
	_solar_view()
	yaw = target_yaw
	pitch = target_pitch
	_position_camera()
	_update_sun_flare()
	# Headless viewports may be square: use an in-frame, non-eclipsed direction.
	yaw = atan2(-sun.x, -sun.z) + 0.36
	_position_camera()
	_update_sun_flare()
	assert(float(flare_material.get_shader_parameter("visibility")) > 0.99, "Unobscured sun visible")
	var uv: Vector2 = flare_material.get_shader_parameter("sun_uv")
	var size := get_viewport().get_visible_rect().size
	var projected_ray := camera.project_ray_normal(uv * size)
	assert(projected_ray.dot(sun) > 0.99999, "Screen flare follows actual sun direction")
	print("SUN_TEST_PASS: shared light direction, night convention, eclipse, projection alignment")
