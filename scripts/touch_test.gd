extends Node
## Scripted touch-screen exercise (developer tool, used with --touch --touchtest).

var game: Game


func _ready() -> void:
	_run()


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _touch(pos: Vector2, pressed: bool, idx: int = 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = _win(pos)
	e.pressed = pressed
	Input.parse_input_event(e)
	await _wait(2)


func _drag(idx: int, from: Vector2, to: Vector2, steps: int = 6) -> void:
	var prev := from
	for k in range(1, steps + 1):
		var p := from.lerp(to, float(k) / steps)
		var e := InputEventScreenDrag.new()
		e.index = idx
		e.position = _win(p)
		e.relative = _win(p) - _win(prev)
		Input.parse_input_event(e)
		prev = p
		await _wait(1)


func _win(p: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * p


func _tap(pos: Vector2) -> void:
	await _touch(pos, true)
	await _touch(pos, false)
	await _wait(2)


func _scr(p: Vector2) -> Vector2:
	return game.cam.cam.unproject_position(Vector3(p.x, game.height_at(p.x, p.y) + 0.6, p.y))


func _run() -> void:
	await _wait(10)
	var ctl := game.ctl
	var vs := get_viewport().get_visible_rect().size
	print("TOUCH viewport ", vs, " touch_active ", GameSettings.touch_active)
	var th: Building = game.buildings_of(game.human)[0]
	# tap a peasant
	var pe: Unit = game.units_of(game.human).filter(func(u): return u.cls == "worker")[0]
	pe.order_stop()
	await _tap(_scr(pe.pos2()))
	print("TOUCH tap select: ", ctl.sel.map(func(x): return x.kind))
	# tap ground -> move command
	var dest := pe.pos2() + Vector2(5, 3)
	await _tap(_scr(dest))
	await _wait(5)
	print("TOUCH tap ground -> state ", pe.state, " goal ", pe.goal)
	# pan with one finger
	var f0 := game.cam.focus
	await _touch(vs * 0.5, true)
	await _drag(0, vs * 0.5, vs * 0.5 + Vector2(200, 0))
	await _touch(vs * 0.5 + Vector2(200, 0), false)
	print("TOUCH pan moved camera by ", (game.cam.focus - f0).length(), " selection kept ", ctl.sel.size())
	game.cam.center_on(th.pos2())
	await _wait(3)
	# pinch zoom
	var d0 := game.cam.target_dist
	await _touch(vs * 0.5 - Vector2(100, 0), true, 0)
	await _touch(vs * 0.5 + Vector2(100, 0), true, 1)
	await _drag(1, vs * 0.5 + Vector2(100, 0), vs * 0.5 + Vector2(250, 0))
	await _touch(vs * 0.5 - Vector2(100, 0), false, 0)
	await _touch(vs * 0.5 + Vector2(250, 0), false, 1)
	print("TOUCH pinch zoom dist ", d0, " -> ", game.cam.target_dist)
	game.cam.target_dist = 34.0
	game.cam.dist = 34.0
	game.cam.center_on(th.pos2())
	await _wait(3)
	# long-press box select over the whole view
	var a := Vector2(20, 60)
	var b := vs - Vector2(140, 240)
	await _touch(a, true)
	await get_tree().create_timer(0.6).timeout
	await _drag(0, a, b)
	print("TOUCH box mode dragging=", ctl.dragging)
	await _touch(b, false)
	print("TOUCH long-press box selected ", ctl.sel.size(), " units")
	# build a house via the command card + Place
	game.hud._refresh_commands()
	game.hud._on_cmd_pressed(0)
	print("TOUCH placing=", ctl.placing)
	await _tap(_scr(th.pos2() + Vector2(8, 2)))
	print("TOUCH ghost at ", ctl.ghost_world, " ok=", ctl.ghost_ok, " context bar visible=", game.hud.context_bar.visible)
	game.hud.context_buttons["Rotate"].emit_signal("pressed")
	game.hud.context_buttons["Place"].emit_signal("pressed")
	await _wait(3)
	print("TOUCH houses: ", game.buildings_of(game.human).filter(func(x): return x.kind == "house").size(), " placing=", ctl.placing)
	# walls: two taps then place
	game.players[game.human].res["wood"] += 300
	game.players[game.human].res["gold"] += 300
	ctl.set_selection(game.units_of(game.human).filter(func(u): return u.cls == "worker"))
	ctl.begin_place("wall")
	await _tap(_scr(th.pos2() + Vector2(-6, -8)))
	await _tap(_scr(th.pos2() + Vector2(1, -9)))
	print("TOUCH wall preview ", ctl.wall_ghosts.size())
	game.hud.context_buttons["Place"].emit_signal("pressed")
	await _wait(3)
	print("TOUCH walls: ", game.buildings_of(game.human).filter(func(x): return x.kind == "wall").size())
	# tapping on the HUD must not reach the world
	ctl.set_selection([pe])
	var st := pe.state
	await _tap(Vector2(vs.x * 0.5, vs.y - 60))
	print("TOUCH tap on HUD kept selection ", ctl.sel.size(), " state unchanged ", pe.state == st)
	# toolbar buttons
	game.hud.touch_bar.get_child(0).emit_signal("pressed")
	print("TOUCH Army -> ", ctl.sel.map(func(x): return x.kind))
	game.hud.touch_bar.get_child(2).emit_signal("pressed")
	print("TOUCH Hero -> ", ctl.sel.map(func(x): return x.kind))
	# champion targeted ability via tap
	var ch: Champion = ctl.selected_champion()
	if ch:
		game.players[game.human].champ_points = 2
		game.players[game.human].champ_level = 3
		for i in 2:
			ch.learn(i)
		var tgt := 0 if ch.abilities()[0]["target"] == "point" else 1
		game.cam.center_on(ch.pos2())
		await _wait(3)
		ctl.begin_cast(tgt)
		var tp := _scr(ch.pos2() + Vector2(3, 0))
		print("TOUCH cast target screen ", tp, " over ui ", game.hud.is_over_ui(tp), " pending ", ctl.cast_pending, " rank ", ch.rank(tgt), " check ", ch.cast_check(tgt))
		await _tap(tp)
		await _wait(20)
		print("TOUCH cast via tap cd ", ch.cds[tgt], " pending ", ctl.cast_pending)
	# doctrine panel
	game.players[game.human].champ_level = 4
	await _wait(3)
	print("TOUCH doctrine panel visible ", game.hud.doctrine_panel.visible)
	game.hud._on_doctrine(1)
	await _wait(3)
	print("TOUCH second doctrine panel (level 4 unlocks 2 tiers) ", game.hud.doctrine_panel.visible)
	print("TOUCH passives ", game.players[game.human].passives, " panel ", game.hud.doctrine_panel.visible)
	game.hud._on_doctrine(0)
	print("TOUCH passives ", game.players[game.human].passives)
	# back button pauses
	game.hud.back_pressed()
	print("TOUCH back -> paused ", get_tree().paused)
	game.hud.back_pressed()
	print("TOUCH back -> paused ", get_tree().paused)
	print("TOUCH DONE")
	get_tree().quit()
