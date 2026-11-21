class_name RTSCamera
extends Node3D
## Strategy camera: arrow keys / screen-edge pan, wheel zoom, middle-drag rotate.

var game: Game
var cam: Camera3D
var focus := Vector3.ZERO
var yaw := 0.0
var dist := 34.0
var target_dist := 34.0
var pitch := deg_to_rad(56.0)
var rotating := false
var edge_scroll := true


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 45.0
	cam.far = 600.0
	add_child(cam)
	cam.current = true
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_dist = maxf(14.0, target_dist * 0.88)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_dist = minf(90.0, target_dist * 1.12)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			rotating = event.pressed
	elif event is InputEventMouseMotion and rotating:
		yaw -= event.relative.x * 0.006
		pitch = clampf(pitch + event.relative.y * 0.004, deg_to_rad(30), deg_to_rad(80))
	elif event is InputEventKey and event.pressed and event.keycode == KEY_HOME:
		yaw = 0.0
		pitch = deg_to_rad(56.0)


func _process(delta: float) -> void:
	var real_dt := delta / maxf(Engine.time_scale, 0.01)
	var mv := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		mv.x -= 1
	if Input.is_key_pressed(KEY_RIGHT):
		mv.x += 1
	if Input.is_key_pressed(KEY_UP):
		mv.y -= 1
	if Input.is_key_pressed(KEY_DOWN):
		mv.y += 1
	if Input.is_key_pressed(KEY_PAGEUP):
		yaw += real_dt * 1.5
	if Input.is_key_pressed(KEY_PAGEDOWN):
		yaw -= real_dt * 1.5
	if edge_scroll and not GameSettings.touch_active and DisplayServer.window_is_focused() and not GameSettings.autotest:
		var vp := get_viewport()
		var mp := vp.get_mouse_position()
		var vs := vp.get_visible_rect().size
		if mp.x >= 0 and mp.y >= 0 and mp.x <= vs.x and mp.y <= vs.y:
			if mp.x < 6:
				mv.x -= 1
			elif mp.x > vs.x - 6:
				mv.x += 1
			if mp.y < 6:
				mv.y -= 1
			elif mp.y > vs.y - 6:
				mv.y += 1
	if mv != Vector2.ZERO:
		var sp := dist * 1.1 * real_dt
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		focus += (right * mv.x - fwd * mv.y) * sp
	focus.x = clampf(focus.x, 0, game.size)
	focus.z = clampf(focus.z, 0, game.size)
	focus.y = lerpf(focus.y, game.height_at(focus.x, focus.z), 0.1)
	dist = lerpf(dist, target_dist, minf(1.0, real_dt * 10.0))
	_apply()


func _apply() -> void:
	position = focus
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.position = off
	cam.look_at(focus, Vector3.UP)


## Touch: drag the map so the ground under `from` ends up under `to`.
func drag_screen(from: Vector2, to: Vector2) -> void:
	var a = ground_at(from)
	var b = ground_at(to)
	if a == null or b == null:
		return
	var d: Vector3 = a - b
	focus.x += d.x
	focus.z += d.z
	focus.x = clampf(focus.x, 0, game.size)
	focus.z = clampf(focus.z, 0, game.size)
	_apply()


func pinch(scale_factor: float) -> void:
	target_dist = clampf(target_dist / scale_factor, 14.0, 90.0)
	dist = target_dist
	_apply()


func twist(angle: float) -> void:
	yaw -= angle
	_apply()


func center_on(p: Vector2) -> void:
	focus = Vector3(p.x, game.height_at(p.x, p.y), p.y)


## Raymarch the heightfield to find the ground point under a screen position.
func ground_at(screen: Vector2):
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	var t := 0.0
	var prev := o
	for i in 400:
		t += 0.5
		var p := o + d * t
		if p.x >= -2 and p.z >= -2 and p.x <= game.size + 2 and p.z <= game.size + 2:
			var h := game.height_at(p.x, p.z)
			if p.y <= h:
				# refine
				var a := prev
				var b := p
				for k in 8:
					var m := (a + b) * 0.5
					if m.y <= game.height_at(m.x, m.z):
						b = m
					else:
						a = m
				return b
		elif p.y < -10:
			break
		prev = p
	# fall back to the y=0 plane
	if absf(d.y) > 0.001:
		var tt := -o.y / d.y
		if tt > 0:
			return o + d * tt
	return null
