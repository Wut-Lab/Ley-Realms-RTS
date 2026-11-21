class_name Minimap
extends Control
## Minimap with fog, units, buildings, camera frustum and alert pings. Click to move the camera.

var game: Game
var base_bytes := PackedByteArray()
var res := 64
var tex: ImageTexture
var t := 0.0
var pings: Array = []
var dragging := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	res = game.fog_res
	var img := MapGenerator.preview_image(game.md, res, false)
	base_bytes = img.get_data()
	tex = ImageTexture.create_from_image(img)
	_redraw_image()


func ping(p: Vector2) -> void:
	pings.append({"p": p, "t": 0.0})


func _process(delta: float) -> void:
	t -= delta
	if t <= 0.0:
		t = 0.35
		_redraw_image()
	for pg in pings:
		pg["t"] += delta
	pings = pings.filter(func(pg): return pg["t"] < 3.0)
	queue_redraw()


func _put(bytes: PackedByteArray, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= res or y >= res:
		return
	var i := (y * res + x) * 3
	bytes[i] = int(c.r * 255)
	bytes[i + 1] = int(c.g * 255)
	bytes[i + 2] = int(c.b * 255)


func _redraw_image() -> void:
	var b := base_bytes.duplicate()
	var fog_on := game.fog_on
	if fog_on:
		for i in res * res:
			if game.fog_exp[i] == 0:
				b[i * 3] = 0
				b[i * 3 + 1] = 0
				b[i * 3 + 2] = 0
			elif game.fog_vis[i] == 0:
				b[i * 3] = b[i * 3] >> 1
				b[i * 3 + 1] = b[i * 3 + 1] >> 1
				b[i * 3 + 2] = b[i * 3 + 2] >> 1
	var sc := float(res) / game.size
	for n in game.resources:
		if n.kind == "tree" or n.kind == "berry":
			continue
		if fog_on and not game.fog_explored(n.pos2()):
			continue
		var c := Color(1, 0.85, 0.2) if n.kind == "gold_mine" else Color(0.65, 0.5, 1.0)
		var x := int(n.position.x * sc)
		var y := int(n.position.z * sc)
		_put(b, x, y, c)
		_put(b, x + 1, y, c)
	for s in game.shrines:
		var c: Color = Color(0.5, 1.0, 1.0) if s.owner_id < 0 else game.players[s.owner_id].color.lightened(0.3)
		var x := int(s.position.x * sc)
		var y := int(s.position.z * sc)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if absi(dx) + absi(dy) <= 1:
					_put(b, x + dx, y + dy, c)
	for bl in game.buildings:
		if not bl.visible:
			continue
		var c: Color = game.players[bl.pid].color
		var r: Rect2i = bl.cells
		for y in range(int(r.position.y * sc), int(r.end.y * sc) + 1):
			for x in range(int(r.position.x * sc), int(r.end.x * sc) + 1):
				_put(b, x, y, c)
	for u in game.units:
		if not u.visible or not u.alive:
			continue
		var c: Color = game.players[u.pid].color.lightened(0.2)
		var x := int(u.position.x * sc)
		var y := int(u.position.z * sc)
		_put(b, x, y, c)
		_put(b, x + 1, y, c)
		_put(b, x, y + 1, c)
		_put(b, x + 1, y + 1, c)
	tex.update(Image.create_from_data(res, res, false, Image.FORMAT_RGB8, b))


func _to_mini(p: Vector2) -> Vector2:
	return p / game.size * size


func _draw() -> void:
	draw_rect(Rect2(Vector2(-2, -2), size + Vector2(4, 4)), Color(0.6, 0.48, 0.26))
	draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
	# camera frustum
	var vp := get_viewport().get_visible_rect().size
	var pts := PackedVector2Array()
	for corner in [Vector2(0, 40), Vector2(vp.x, 40), Vector2(vp.x, vp.y - 214), Vector2(0, vp.y - 214)]:
		var g = game.cam.ground_at(corner)
		if g == null:
			return
		var mp := _to_mini(Vector2(g.x, g.z))
		mp = mp.clamp(Vector2.ZERO, size)
		pts.append(mp)
	pts.append(pts[0])
	draw_polyline(pts, Color(1, 1, 1, 0.9), 1.2)
	for pg in pings:
		var k: float = pg["t"]
		var mp := _to_mini(pg["p"])
		draw_arc(mp, 4.0 + fmod(k, 1.0) * 14.0, 0, TAU, 20, Color(1, 0.25, 0.2, 1.0 - fmod(k, 1.0)), 2.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var wp: Vector2 = event.position / size * game.size
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if event.pressed:
				game.cam.center_on(wp)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var us := game.ctl.own_units()
			if not us.is_empty():
				game.cmd_move(us, wp)
			else:
				var b := game.ctl.selected_building()
				if b and b.pid == game.human and b.def.has("trains"):
					b.set_rally(wp)
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		game.cam.center_on((event.position / size * game.size).clamp(Vector2.ZERO, Vector2(game.size, game.size)))
		accept_event()
