extends Node
## Scripted exercise of the human input paths (only used with --uitest).

var game: Game


func _ready() -> void:
	_run()


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _click(pos: Vector2, button: int = MOUSE_BUTTON_LEFT, shift: bool = false) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		e.shift_pressed = shift
		Input.parse_input_event(e)
		await _wait(2)


func _key(k: int, ctrl: bool = false) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.pressed = true
	e.ctrl_pressed = ctrl
	Input.parse_input_event(e)
	await _wait(2)
	var r := InputEventKey.new()
	r.keycode = k
	r.pressed = false
	Input.parse_input_event(r)
	await _wait(1)


func _screen(p: Vector2) -> Vector2:
	return game.cam.cam.unproject_position(Vector3(p.x, game.height_at(p.x, p.y) + 0.5, p.y))


func _run() -> void:
	await _wait(10)
	var ctl := game.ctl
	var vs := get_viewport().get_visible_rect().size
	print("UITEST viewport ", vs)
	# box select everything
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = Vector2(5, 45)
	Input.parse_input_event(e)
	await _wait(2)
	var m := InputEventMouseMotion.new()
	m.position = vs - Vector2(5, 220)
	Input.parse_input_event(m)
	await _wait(2)
	e = e.duplicate()
	e.pressed = false
	e.position = vs - Vector2(5, 220)
	Input.parse_input_event(e)
	await _wait(3)
	print("UITEST box selected ", ctl.sel.size(), " workers ", ctl.own_workers().size())
	# command card: build a house via hotkey Q then click near the town hall
	var th: Building = game.buildings_of(game.human)[0]
	await _key(KEY_Q)
	print("UITEST placing=", ctl.placing)
	var spot := th.pos2() + Vector2(7, 0)
	var mm := InputEventMouseMotion.new()
	mm.position = _screen(spot)
	Input.parse_input_event(mm)
	await _wait(2)
	print("UITEST ghost ok=", ctl.ghost_ok)
	await _click(_screen(spot))
	var houses := game.buildings_of(game.human).filter(func(b): return b.kind == "house")
	print("UITEST houses after placement: ", houses.size(), " placing=", ctl.placing)
	# wall line drag
	game.players[game.human].res["wood"] += 500
	game.players[game.human].res["gold"] += 500
	await _key(KEY_S)
	print("UITEST placing=", ctl.placing)
	var a := th.pos2() + Vector2(-6, -8)
	var b := th.pos2() + Vector2(2, -9)
	var d := InputEventMouseButton.new()
	d.button_index = MOUSE_BUTTON_LEFT
	d.pressed = true
	d.position = _screen(a)
	Input.parse_input_event(d)
	await _wait(2)
	var mv := InputEventMouseMotion.new()
	mv.position = _screen(b)
	Input.parse_input_event(mv)
	await _wait(2)
	print("UITEST wall ghosts ", ctl.wall_ghosts.size())
	d = d.duplicate()
	d.pressed = false
	d.position = _screen(b)
	Input.parse_input_event(d)
	await _wait(3)
	print("UITEST walls ", game.buildings_of(game.human).filter(func(x): return x.kind == "wall").size())
	# right click a gold mine with the workers
	var gm = game.find_resource(th.pos2(), "gold", 30.0)
	if gm:
		ctl.set_selection(game.units_of(game.human).filter(func(u): return u.cls == "worker").slice(0, 2))
		await _click(game.cam.cam.unproject_position(gm.position + Vector3.UP * 0.5), MOUSE_BUTTON_RIGHT)
		await _wait(5)
		print("UITEST gold gatherers ", game.units_of(game.human).filter(func(u): return u.state == Unit.GATHER and u.gtype == "gold").size())
	# select town hall with H, queue peasants with Q, cancel one, research
	await _key(KEY_H)
	print("UITEST selected ", ctl.sel.map(func(x): return x.kind))
	await _key(KEY_Q)
	await _key(KEY_Q)
	print("UITEST TH queue ", th.queue.size())
	game.hud._on_queue_pressed(1)
	print("UITEST TH queue after cancel ", th.queue.size())
	for i in 15:
		game.hud._on_cmd_hover(i)
	game.hud._on_cmd_unhover(0)
	# rally point by right click
	await _click(_screen(th.pos2() + Vector2(0, 8)), MOUSE_BUTTON_RIGHT)
	print("UITEST rally ", th.rally)
	# click select a single unit, control groups, idle peasant, double click
	var u: Unit = game.units_of(game.human)[0]
	await _click(_screen(u.pos2()))
	print("UITEST click selected ", ctl.sel.map(func(x): return x.kind))
	await _key(KEY_1, true)
	await _key(KEY_ESCAPE)
	await _key(KEY_1)
	print("UITEST group 1 -> ", ctl.sel.size())
	await _key(KEY_PERIOD)
	await _key(KEY_SPACE)
	# military commands
	var sp := game.units_of(game.human).filter(func(x): return x.cls != "worker")
	ctl.set_selection(sp)
	await _wait(2)
	game.hud._refresh_commands()
	await _key(KEY_A)
	await _click(_screen(th.pos2() + Vector2(10, 10)))
	print("UITEST amove state ", sp.map(func(x): return x.state))
	await _key(KEY_D)
	await _key(KEY_S)
	# minimap clicks
	var mmap := game.hud.minimap
	var me := InputEventMouseButton.new()
	me.button_index = MOUSE_BUTTON_LEFT
	me.pressed = true
	me.position = mmap.size * 0.5
	mmap._gui_input(me)
	me = me.duplicate()
	me.pressed = false
	mmap._gui_input(me)
	print("UITEST cam focus ", game.cam.focus)
	# speed, help, pause
	await _key(KEY_EQUAL)
	await _key(KEY_MINUS)
	await _key(KEY_F1)
	await _key(KEY_F1)
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)
	print("UITEST paused ", get_tree().paused)
	await _key(KEY_ESCAPE)
	print("UITEST paused after esc ", get_tree().paused)
	# demolish via command card
	var house := game.buildings_of(game.human).filter(func(x): return x.kind == "house")
	if not house.is_empty():
		ctl.set_selection([house[0]])
		await _wait(2)
		game.hud._refresh_commands()
		await _key(KEY_B)
		await _wait(5)
		print("UITEST house demolished ", not house[0].alive)
	# delete key
	ctl.set_selection([u])
	await _key(KEY_DELETE)
	await _wait(5)
	print("UITEST deleted unit alive=", u.alive)
	# champion: select, learn, cast a targeted ability
	await _key(KEY_QUOTELEFT)
	var ch: Champion = ctl.selected_champion()
	print("UITEST champion selected ", ch != null, " ", ch.display_name() if ch else "")
	if ch:
		game.players[game.human].champ_points = 3
		game.players[game.human].champ_level = 3
		game.hud._refresh_commands()
		await _key(KEY_Z)
		await _key(KEY_X)
		game.hud._refresh_commands()
		print("UITEST ranks ", game.players[game.human].champ_ranks, " pts ", game.players[game.human].champ_points)
		var tgt := -1
		for i in 4:
			if ch.rank(i) > 0 and ch.abilities()[i]["target"] == "point":
				tgt = i
		if tgt >= 0:
			await _key([KEY_Q, KEY_W, KEY_E, KEY_R][tgt])
			print("UITEST cast pending ", ctl.cast_pending)
			await _click(_screen(ch.pos2() + Vector2(4, 0)))
			await _wait(30)
			print("UITEST cooldown after cast ", ch.cds[tgt])
		for i in 4:
			if ch.rank(i) > 0 and ch.abilities()[i]["target"] == "self":
				await _key([KEY_Q, KEY_W, KEY_E, KEY_R][i])
				print("UITEST self cast cd ", ch.cds[i])
		ch.take_damage(99999, null)
		await _wait(3)
		print("UITEST champ respawn at ", game.players[game.human].champ_respawn)
		game.hud._process(0.1)
		print("UITEST champ button: ", game.hud.champ_btn.text)
	# game over screen
	game._end_game(true, "Test")
	await _wait(5)
	print("UITEST over panel ", game.hud.over_panel != null)
	game.quit_to_menu()
	await _wait(5)
	print("UITEST back at menu")
	get_tree().quit()
