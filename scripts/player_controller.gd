class_name PlayerController
extends Node
## Local player input: selection, orders, building placement, control groups.

var game: Game
var sel: Array = []
var dragging := false
var drag_start := Vector2.ZERO
var drag_now := Vector2.ZERO
var placing := ""
var ghost: MeshInstance3D
var ghost_rot := 0.0
var ghost_ok := false
var wall_start = null
var wall_ghosts: Array = []
var amove_pending := false
var groups := {}
var last_click_t := 0.0
var last_group_t := 0.0
var last_group := -1
var idle_cycle := 0
var hover_ground := Vector3.ZERO
var cast_pending := -1
var cast_ring: MeshInstance3D
var last_champ_t := 0.0
var touch_multi := false
var garrison_pending := false
var ghost_world = null
var wall_end = null


func _cam() -> RTSCamera:
	return game.cam


# ---------------------------------------------------------------- selection
func set_selection(list: Array) -> void:
	for e in sel:
		if is_instance_valid(e) and e.has_method("set_selected"):
			e.set_selected(false)
	sel = []
	for e in list:
		if is_instance_valid(e):
			sel.append(e)
			if e.has_method("set_selected"):
				e.set_selected(true)
	if game.hud:
		game.hud.selection_changed()
	if not sel.is_empty() and is_instance_valid(sel[0]) and sel[0] is Entity and sel[0].pid == game.human:
		Sfx.play("select", -8.0)


func on_entity_removed(e) -> void:
	if e in sel:
		sel.erase(e)
		if game.hud:
			game.hud.selection_changed()
	for k in groups:
		groups[k].erase(e)


func own_units() -> Array:
	return sel.filter(func(e): return is_instance_valid(e) and e is Unit and e.alive and e.pid == game.human)


func own_workers() -> Array:
	return own_units().filter(func(e): return e.cls == "worker")


func selected_building() -> Building:
	if sel.size() == 1 and is_instance_valid(sel[0]) and sel[0] is Building and sel[0].alive:
		return sel[0]
	return null


func _screen_of(p: Vector3):
	var c := _cam().cam
	if c.is_position_behind(p):
		return null
	return c.unproject_position(p)


func pick(screen: Vector2, include_res: bool = true):
	var best = null
	var bd := 1e9
	var c := _cam().cam
	var cands: Array = []
	for u in game.units:
		if u.alive and u.visible:
			cands.append(u)
	for b in game.buildings:
		if b.alive and b.visible:
			cands.append(b)
	for s in game.shrines:
		cands.append(s)
	for mc in game.camps:
		if game.fog_explored(mc.pos2()):
			cands.append(mc)
	if include_res:
		cands.append_array(game.resources)
	for e in cands:
		var r: float
		var h: float
		if e is Entity:
			r = e.radius if not e.is_building else e.size * 0.55
			h = e.height * 0.5
		elif e is Shrine or e is MercCamp:
			r = 2.4
			h = 1.0
		else:
			r = maxf(e.radius, 0.6)
			h = 1.0 if e.kind == "tree" else 0.5
			if not game.fog_explored(e.pos2()):
				continue
		var wp: Vector3 = e.position + Vector3.UP * h
		if c.is_position_behind(wp):
			continue
		var sp := c.unproject_position(wp)
		var edge := c.unproject_position(wp + c.global_transform.basis.x * r)
		var pr := maxf(sp.distance_to(edge) * 1.15, 12.0)
		var d := sp.distance_to(screen)
		# units get priority over large objects behind them
		var score := d - (6.0 if e is Unit else 0.0)
		if d <= pr and score < bd:
			bd = score
			best = e
	return best


func _box_select(a: Vector2, b: Vector2, add: bool) -> void:
	var r := Rect2(a, Vector2.ZERO).expand(b)
	var list: Array = sel.duplicate() if add else []
	for u in game.units:
		if u.alive and u.pid == game.human:
			var sp = _screen_of(u.position + Vector3.UP * 0.6)
			if sp != null and r.has_point(sp) and not (u in list):
				list.append(u)
	# prefer military when both are boxed
	var mil := list.filter(func(e): return e is Unit and e.cls != "worker")
	if not add and mil.size() > 0 and mil.size() < list.size():
		var wk := list.size() - mil.size()
		if wk <= mil.size():
			list = mil
	if list.is_empty() and not add:
		var e = pick((a + b) * 0.5, false)
		if e:
			list = [e]
	set_selection(list)


func _click_select(p: Vector2, add: bool, double: bool) -> void:
	var e = pick(p)
	if e == null:
		if not add:
			set_selection([])
		return
	if double and e is Unit and e.pid == game.human:
		var list: Array = []
		var vs := get_viewport().get_visible_rect()
		for u in game.units:
			if u.alive and u.pid == game.human and u.kind == e.kind:
				var sp = _screen_of(u.position)
				if sp != null and vs.has_point(sp):
					list.append(u)
		set_selection(list)
		return
	if add and e is Unit and e.pid == game.human:
		var list: Array = own_units()
		if e in list:
			list.erase(e)
		else:
			list.append(e)
		set_selection(list)
		return
	set_selection([e])


func my_champion() -> Champion:
	var c = game.players[game.human].champ
	if c != null and is_instance_valid(c) and c.alive:
		return c
	return null


func selected_champion() -> Champion:
	for e in sel:
		if is_instance_valid(e) and e is Champion and e.alive and e.pid == game.human:
			return e
	return null


func select_champion() -> void:
	var c := my_champion()
	if c == null:
		var p: PlayerData = game.players[game.human]
		if p.champ_class != "" and p.champ_respawn >= 0.0:
			game.hud.message("Your champion returns in %ds." % ceili(p.champ_respawn - game.elapsed), Color(0.9, 0.8, 0.6))
		return
	var now := Time.get_ticks_msec() / 1000.0
	if sel.size() == 1 and sel[0] == c and now - last_champ_t < 0.5:
		_cam().center_on(c.pos2())
	set_selection([c])
	last_champ_t = now


func begin_cast(i: int) -> void:
	var c := selected_champion()
	if c == null:
		return
	var reason := c.cast_check(i)
	if reason != "":
		game.hud.message(reason, Color(1, 0.6, 0.4))
		return
	var a: Dictionary = c.abilities()[i]
	if a["target"] == "self":
		c.request_cast(i, c.pos2())
		return
	cancel_cast()
	cancel_place()
	cast_pending = i
	cast_ring = MeshInstance3D.new()
	cast_ring.mesh = Models.mesh("area_ring", Color(1.0, 0.8, 0.3))
	cast_ring.scale = Vector3(a["radius"], 1, a["radius"])
	cast_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child(cast_ring)
	if GameSettings.touch_active:
		cast_ring.visible = false
		game.hud.message("%s: tap a target." % a["name"], Color(0.9, 0.9, 0.6))
	else:
		_update_cast_ring(get_viewport().get_mouse_position())
		game.hud.message("%s: click a target (right-click to cancel)." % a["name"], Color(0.9, 0.9, 0.6))


func cancel_cast() -> void:
	cast_pending = -1
	if cast_ring:
		cast_ring.queue_free()
		cast_ring = null


func _update_cast_ring(screen: Vector2) -> void:
	if cast_ring == null:
		return
	var gp = _cam().ground_at(screen)
	if gp != null:
		cast_ring.position = gp + Vector3.UP * 0.1


# ---------------------------------------------------------------- placement
func begin_place(k: String) -> void:
	cancel_place()
	var d: Dictionary = Defs.BUILDINGS[k]
	var p: PlayerData = game.players[game.human]
	if p.age < d["age"]:
		game.hud.message("Requires " + Defs.AGE_NAMES[d["age"]], Color(1, 0.6, 0.4))
		return
	if not p.can_afford(d["cost"]):
		game.hud.message(p.missing_text(d["cost"]), Color(1, 0.6, 0.4))
		return
	placing = k
	ghost = MeshInstance3D.new()
	ghost.mesh = Models.mesh(k, p.color)
	ghost.material_override = Models.ghost_ok
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child(ghost)
	ghost.rotation.y = ghost_rot
	if GameSettings.touch_active:
		_update_ghost(get_viewport().get_visible_rect().size * Vector2(0.5, 0.4))
		game.hud.message("Tap the map to position the %s, then press Place." % d["name"], Color(0.9, 0.9, 0.6))
	else:
		_update_ghost(get_viewport().get_mouse_position())


func cancel_place() -> void:
	placing = ""
	wall_start = null
	wall_end = null
	ghost_world = null
	if ghost:
		ghost.queue_free()
		ghost = null
	_clear_wall_ghosts()


func _clear_wall_ghosts() -> void:
	for g in wall_ghosts:
		g.queue_free()
	wall_ghosts.clear()


func _update_ghost(screen: Vector2) -> void:
	if ghost == null:
		return
	var gp = _cam().ground_at(screen)
	if gp == null:
		return
	var s: float = Defs.BUILDINGS[placing]["size"]
	var p := Game.snap_pos(s, Vector2(gp.x, gp.z))
	ghost_ok = game.can_place(placing, p, game.human)
	ghost_world = p
	ghost.material_override = Models.ghost_ok if ghost_ok else Models.ghost_bad
	ghost.position = Vector3(p.x, game.height_at(p.x, p.y), p.y)
	if placing == "wall" and wall_start != null:
		_preview_wall(wall_start, p)


func _wall_cells(a: Vector2, b: Vector2) -> Array:
	var out: Array = []
	var ca := Vector2i(int(floor(a.x)), int(floor(a.y)))
	var cb := Vector2i(int(floor(b.x)), int(floor(b.y)))
	var n := maxi(absi(cb.x - ca.x), absi(cb.y - ca.y))
	for i in range(n + 1):
		var t := 0.0 if n == 0 else float(i) / n
		var c := Vector2i(roundi(lerpf(ca.x, cb.x, t)), roundi(lerpf(ca.y, cb.y, t)))
		var p := Vector2(c.x + 0.5, c.y + 0.5)
		if out.is_empty() or out[out.size() - 1] != p:
			out.append(p)
	return out


func _preview_wall(a: Vector2, b: Vector2) -> void:
	_clear_wall_ghosts()
	var cells := _wall_cells(a, b)
	for p in cells.slice(0, 80):
		var g := MeshInstance3D.new()
		g.mesh = Models.mesh("wall", game.players[game.human].color)
		g.material_override = Models.ghost_ok if game.can_place("wall", p, game.human) else Models.ghost_bad
		g.position = Vector3(p.x, game.height_at(p.x, p.y), p.y)
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		game.add_child(g)
		wall_ghosts.append(g)


func _try_place(screen: Vector2, shift: bool) -> void:
	var gp = _cam().ground_at(screen)
	if gp == null:
		return
	_place_at(Vector2(gp.x, gp.z), shift)


func _place_at(p: Vector2, shift: bool) -> void:
	var b := game.place_building(game.human, placing, p, own_workers(), ghost_rot)
	if b == null:
		var pl: PlayerData = game.players[game.human]
		Sfx.play("error", -6.0)
		if not pl.can_afford(Defs.BUILDINGS[placing]["cost"]):
			game.hud.message(pl.missing_text(Defs.BUILDINGS[placing]["cost"]), Color(1, 0.6, 0.4))
		else:
			game.hud.message("Cannot build there.", Color(1, 0.6, 0.4))
		return
	game.spawn_fx("marker", b.position + Vector3.UP * 0.2, b.size * 0.8, Color.WHITE)
	if not shift:
		cancel_place()


# ---- touch helpers
func touch_place_tap(screen: Vector2) -> void:
	var gp = _cam().ground_at(screen)
	if gp == null:
		return
	if placing == "wall":
		var p := Game.snap_pos(1.0, Vector2(gp.x, gp.z))
		if wall_start == null or wall_end != null:
			wall_start = p
			wall_end = null
			_clear_wall_ghosts()
			_update_ghost(screen)
			game.hud.message("Tap where the wall should end, then press Place.", Color(0.9, 0.9, 0.6))
		else:
			wall_end = p
			_preview_wall(wall_start, wall_end)
		return
	_update_ghost(screen)


func touch_place_confirm() -> void:
	if placing == "":
		return
	if placing == "wall":
		if wall_start != null:
			_place_wall_line(wall_start, wall_end if wall_end != null else wall_start)
		cancel_place()
		return
	if ghost_world != null:
		_place_at(ghost_world, false)


func touch_rotate() -> void:
	ghost_rot += PI / 2
	if ghost:
		ghost.rotation.y = ghost_rot


func touch_cast(screen: Vector2) -> void:
	var gp = _cam().ground_at(screen)
	var c := selected_champion()
	if gp != null and c != null:
		c.request_cast(cast_pending, Vector2(gp.x, gp.z))
	cancel_cast()


func try_garrison_at(screen: Vector2) -> void:
	garrison_pending = false
	var e = pick(screen, false)
	if e is Building and e.pid == game.human and e.alive and e.complete and e.capacity() > 0:
		var n := game.send_to_shelter(own_units(), game.human, e)
		if n == 0:
			game.hud.message("No room inside.", Color(1, 0.6, 0.4))
			Sfx.play("error", -6.0)
		else:
			Sfx.play("order", -8.0)
	else:
		game.hud.message("Choose your Town Hall or a Watch Tower.", Color(1, 0.6, 0.4))
		Sfx.play("error", -6.0)


func select_army() -> void:
	var army: Array = game.units.filter(func(u): return u.alive and u.pid == game.human and u.cls != "worker")
	if army.is_empty():
		game.hud.message("You have no army.", Color(0.8, 0.8, 0.8))
		return
	set_selection(army)


func select_idle_worker() -> void:
	var idle: Array = game.units.filter(func(u): return u.alive and u.pid == game.human and u.cls == "worker" and u.state == Unit.IDLE)
	if idle.is_empty():
		game.hud.message("No idle peasants.", Color(0.8, 0.8, 0.8))
		return
	idle_cycle = (idle_cycle + 1) % idle.size()
	set_selection([idle[idle_cycle]])
	_cam().center_on(idle[idle_cycle].pos2())


func select_town_hall() -> void:
	for b in game.buildings:
		if b.pid == game.human and b.kind == "town_hall" and b.alive:
			set_selection([b])
			_cam().center_on(b.pos2())
			return


func _place_wall_line(a: Vector2, b: Vector2) -> void:
	var cells := _wall_cells(a, b)
	var placed: Array = []
	var workers := own_workers()
	for p in cells.slice(0, 80):
		var w := game.place_building(game.human, "wall", p, [], 0.0)
		if w:
			placed.append(w)
		elif not game.players[game.human].can_afford(Defs.BUILDINGS["wall"]["cost"]):
			game.hud.message("Not enough resources for the whole wall.", Color(1, 0.6, 0.4))
			break
	if placed.size() > 0:
		# split builders along the wall
		for i in workers.size():
			workers[i].order_build(placed[int(float(i) / workers.size() * placed.size())])


# ---------------------------------------------------------------- input
func _unhandled_input(event: InputEvent) -> void:
	if game.over:
		return
	# on touch devices, real touch events are handled by TouchInput; ignore their mouse emulation
	if GameSettings.touch_active and event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseMotion:
		drag_now = event.position
		if placing != "":
			_update_ghost(event.position)
		if cast_pending >= 0:
			_update_cast_ring(event.position)
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if cast_pending >= 0:
					var gp = _cam().ground_at(mb.position)
					var c := selected_champion()
					if gp != null and c != null:
						c.request_cast(cast_pending, Vector2(gp.x, gp.z))
					cancel_cast()
					return
				if placing != "":
					if placing == "wall":
						var gp = _cam().ground_at(mb.position)
						if gp != null:
							wall_start = Game.snap_pos(1.0, Vector2(gp.x, gp.z))
					else:
						_try_place(mb.position, mb.shift_pressed)
					return
				if garrison_pending:
					try_garrison_at(mb.position)
					return
				if amove_pending:
					amove_pending = false
					var gp = _cam().ground_at(mb.position)
					if gp != null:
						game.cmd_move(own_units(), Vector2(gp.x, gp.z), true)
						game.spawn_fx("marker", gp + Vector3.UP * 0.1, 1.0, Color.WHITE)
					return
				dragging = true
				drag_start = mb.position
				drag_now = mb.position
			else:
				if placing == "wall" and wall_start != null:
					var gp = _cam().ground_at(mb.position)
					if gp != null:
						_place_wall_line(wall_start, Game.snap_pos(1.0, Vector2(gp.x, gp.z)))
					wall_start = null
					_clear_wall_ghosts()
					if not mb.shift_pressed:
						cancel_place()
					return
				if dragging:
					dragging = false
					if drag_start.distance_to(mb.position) > 8.0:
						_box_select(drag_start, mb.position, mb.shift_pressed)
					else:
						var now := Time.get_ticks_msec() / 1000.0
						_click_select(mb.position, mb.shift_pressed, now - last_click_t < 0.35)
						last_click_t = now
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if cast_pending >= 0:
				cancel_cast()
				return
			if placing != "":
				cancel_place()
				return
			if amove_pending or garrison_pending:
				amove_pending = false
				garrison_pending = false
				return
			_right_click(mb.position)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_key(event)


func _right_click(screen: Vector2) -> void:
	var gp = _cam().ground_at(screen)
	var target = pick(screen)
	var b := selected_building()
	if b and b.pid == game.human:
		if b.def.has("trains") and gp != null:
			var rn = null
			if target is ResourceNode or (target is Building and target.kind == "farm" and target.pid == game.human):
				rn = target
			b.set_rally(Vector2(gp.x, gp.z), rn)
			game.spawn_fx("marker", gp + Vector3.UP * 0.1, 1.0, Color.WHITE)
		return
	var us := own_units()
	if us.is_empty() or gp == null:
		return
	if target is Entity and not target.visible:
		target = null
	game.cmd_smart(us, Vector2(gp.x, gp.z), target)
	Sfx.play("order", -8.0)
	game.spawn_fx("marker", gp + Vector3.UP * 0.1, 0.9, Color.WHITE)


func _key(e: InputEventKey) -> void:
	var k := e.keycode
	if k == KEY_ESCAPE:
		if cast_pending >= 0:
			cancel_cast()
		elif placing != "":
			cancel_place()
		elif amove_pending or garrison_pending:
			amove_pending = false
			garrison_pending = false
		elif not sel.is_empty():
			set_selection([])
		else:
			game.hud.toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if placing != "" and k == KEY_R:
		ghost_rot += PI / 2
		if ghost:
			ghost.rotation.y = ghost_rot
		return
	if k >= KEY_0 and k <= KEY_9:
		var n := k - KEY_0
		if e.ctrl_pressed:
			groups[n] = own_units() if not own_units().is_empty() else sel.duplicate()
			game.hud.message("Control group %d set." % n, Color(0.8, 0.8, 0.8))
		elif groups.has(n):
			var list: Array = groups[n].filter(func(x): return is_instance_valid(x) and x.alive)
			set_selection(list)
			var now := Time.get_ticks_msec() / 1000.0
			if last_group == n and now - last_group_t < 0.4 and not list.is_empty():
				_cam().center_on(list[0].pos2())
			last_group = n
			last_group_t = now
		return
	match k:
		KEY_QUOTELEFT, KEY_F2:
			select_champion()
			return
		KEY_H:
			for b in game.buildings:
				if b.pid == game.human and b.kind == "town_hall" and b.alive:
					set_selection([b])
					_cam().center_on(b.pos2())
					break
			return
		KEY_PERIOD:
			var idle: Array = game.units.filter(func(u): return u.alive and u.pid == game.human and u.cls == "worker" and u.state == Unit.IDLE)
			if idle.is_empty():
				game.hud.message("No idle peasants.", Color(0.8, 0.8, 0.8))
			else:
				idle_cycle = (idle_cycle + 1) % idle.size()
				set_selection([idle[idle_cycle]])
				_cam().center_on(idle[idle_cycle].pos2())
			return
		KEY_SPACE:
			if not sel.is_empty() and is_instance_valid(sel[0]):
				_cam().center_on(sel[0].pos2())
			return
		KEY_DELETE:
			for x in sel.duplicate():
				if is_instance_valid(x) and x is Entity and x.pid == game.human and x.alive:
					x.die(null)
			return
		KEY_EQUAL, KEY_KP_ADD:
			Engine.time_scale = minf(3.0, Engine.time_scale + 0.5)
			game.hud.message("Game speed x%.1f" % Engine.time_scale, Color(0.8, 0.8, 0.8))
			return
		KEY_MINUS, KEY_KP_SUBTRACT:
			Engine.time_scale = maxf(0.5, Engine.time_scale - 0.5)
			game.hud.message("Game speed x%.1f" % Engine.time_scale, Color(0.8, 0.8, 0.8))
			return
		KEY_F1:
			game.hud.toggle_help()
			return
	game.hud.hotkey(k)
