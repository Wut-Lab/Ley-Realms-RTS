extends Node
## Developer test (--autotest --featuretest): gates, unit upgrade lines, garrisons, and their save/load.

var game: Game
var main: Node


func _ready() -> void:
	_run()


func _wait(sec: float) -> void:
	var t0 := game.elapsed
	while game.elapsed < t0 + sec:
		await get_tree().process_frame


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x)), int(floor(p.y)))


func _run() -> void:
	await get_tree().process_frame
	var h := game.human
	var p: PlayerData = game.players[h]
	for r in Defs.RES:
		p.res[r] = 5000.0
	var th: Building = game.buildings_of(h)[0]
	# ---------------------------------------------------------------- gates
	# find an open walkable spot near the town hall
	var gp := Vector2.ZERO
	for k in 40:
		var cand := th.pos2() + Vector2.from_angle(k * 0.7) * (16.0 + k * 0.3)
		cand = Game.snap_pos(1.0, cand)
		var ok := true
		for dz in range(-3, 4):
			for dx in range(-3, 4):
				if not game.cell_ok(_cell(cand) + Vector2i(dx, dz)):
					ok = false
		if ok:
			gp = cand
			break
	print("FT gate spot ", gp)
	var gate := game.spawn_building("gate", h, gp, true)
	for dz in [-3, -2, -1, 1, 2, 3]:
		game.spawn_building("wall", h, gp + Vector2(0, dz), true)
	var mine := game.spawn_unit("peasant", h, gp + Vector2(-3, 0))
	var foe_pid := 2
	var foe := game.spawn_unit("swordsman", foe_pid, gp + Vector2(-3.2, 0.3))
	mine.order_move(gp + Vector2(3, 0))
	foe.order_move(gp + Vector2(3, 0))
	var foe_entered := false
	var mine_entered := false
	var t0 := game.elapsed
	while game.elapsed < t0 + 8.0:
		await get_tree().process_frame
		if foe.alive and _cell(foe.pos2()) == _cell(gp):
			foe_entered = true
		if mine.alive and _cell(mine.pos2()) == _cell(gp):
			mine_entered = true
	print("FT enemy ended at offset ", foe.pos2() - gp, " state ", foe.state, " target ", foe.target.kind if foe.target else "none")
	print("FT gate: own peasant passed through=", mine_entered, " (now x-offset %.1f)" % (mine.pos2().x - gp.x),
		"  enemy entered gate cell=", foe_entered, " enemy attacking gate=", foe.alive and foe.state == Unit.ATTACK and foe.target == gate,
		" gate hp %d/%d" % [gate.hp, gate.max_hp], " door open %.2f" % gate.door_open)
	# with nothing else to fight, the enemy must break the gate down
	mine.die(null)
	foe.order_move(gp + Vector2(3, 0))
	var hp0 := gate.hp
	await _wait(8.0)
	var alive := is_instance_valid(foe) and foe.alive
	print("FT enemy alone at gate: alive=", alive, " attacking gate=", alive and foe.state == Unit.ATTACK and foe.target == gate, " gate hp %d -> %d" % [hp0, gate.hp], " still blocked=", alive and foe.pos2().x < gp.x)
	if alive:
		foe.die(null)
	# wall -> gate conversion
	var wall: Building = null
	for b in game.buildings:
		if b.kind == "wall" and b.pid == h:
			wall = b
			break
	var g2 := game.convert_to_gate(wall)
	print("FT convert wall to gate: ", g2 != null and g2.kind == "gate", " wall removed=", not (wall in game.buildings))
	# ---------------------------------------------------------------- upgrades
	p.age = 3
	var sw := game.spawn_unit("swordsman", h, th.pos2() + Vector2(0, 6))
	var barr := game.spawn_building("barracks", h, Game.snap_pos(4.2, th.pos2() + Vector2(-9, -9)), true)
	game.hud.ctl_refresh_for_test(barr)
	print("FT barracks research before: ", game.hud.cmds.filter(func(c): return c != null and c.get("tech", false)).map(func(c): return c["title"]))
	print("FT enqueue blademaster before longsword (should be refused): ", barr.check("up_blademaster"))
	game.finish_tech(h, "up_longsword")
	print("FT existing swordsman -> ", sw.def["name"], " hp %d/%d atk %d armor %d tier %d" % [sw.hp, sw.max_hp, sw.atk_val(), sw.armor_val(), sw.def.get("tier", 0)])
	game.finish_tech(h, "up_blademaster")
	var sw2 := game.spawn_unit("swordsman", h, th.pos2() + Vector2(1, 6))
	print("FT newly trained -> ", sw2.def["name"], " hp %d atk %d" % [sw2.max_hp, sw2.atk_val()], " base def untouched: ", Defs.UNITS["swordsman"]["name"])
	game.hud.ctl_refresh_for_test(barr)
	print("FT barracks train button now: ", game.hud.cmds[0]["label"])
	# ---------------------------------------------------------------- garrison
	var workers: Array = game.units.filter(func(u): return u.pid == h and u.cls == "worker")
	var nw := workers.size()
	for u in workers:
		var n = game.find_resource(u.pos2(), "wood", 40.0)
		if n:
			u.order_gather(n)
	await _wait(5.0)
	game.town_bell(h)
	await _wait(12.0)
	print("FT town bell: workers %d, inside TH %d, still outside %d" % [nw, th.garrison.size(), game.units.filter(func(u): return u.pid == h and u.cls == "worker").size()])
	var raider := game.spawn_unit("archer", 2, th.pos2() + Vector2(0, 6.5))
	var before := game.projectiles.size()
	var max_proj := 0
	t0 = game.elapsed
	while game.elapsed < t0 + 3.0:
		await get_tree().process_frame
		max_proj = maxi(max_proj, game.projectiles.size())
	print("FT TH arrows in flight with %d inside: max %d (1 without garrison)" % [th.garrison.size(), max_proj])
	if is_instance_valid(raider) and raider.alive:
		raider.die(null)
	# save and load with a garrison and upgrades
	var inside := th.garrison.size()
	game.save_to("slot2")
	main.load_game("slot2")
	await get_tree().process_frame
	await get_tree().process_frame
	var g: Game = main.current
	game = g
	var th2: Building = null
	for b in g.buildings_of(h):
		if b.kind == "town_hall":
			th2 = b
	var sws: Array = g.units.filter(func(u): return u.pid == h and u.kind == "swordsman")
	print("FT after load: TH garrison %d (was %d), bell %s, swordsmen %s, gates %d" % [th2.garrison.size(), inside, g.players[h].bell,
		sws.map(func(u): return u.def["name"]), g.buildings_of(h).filter(func(b): return b.kind == "gate").size()])
	g.all_clear(h)
	await _wait(6.0)
	var working := g.units.filter(func(u): return u.pid == h and u.cls == "worker" and (u.state == Unit.GATHER or u.state == Unit.RETURN)).size()
	print("FT all clear: TH garrison %d, workers gathering %d" % [th2.garrison.size(), working])
	# destroyed shelter ejects its garrison alive
	var tower := g.spawn_building("tower", h, Game.snap_pos(2.0, th2.pos2() + Vector2(8, -8)), true)
	var pe: Array = g.units.filter(func(u): return u.pid == h and u.cls == "worker").slice(0, 3)
	for u in pe:
		g.enter_garrison(u, tower)
	print("FT tower garrison ", tower.garrison.size())
	tower.die(null)
	print("FT tower destroyed: ejected alive ", pe.filter(func(u): return u.alive and u.garrison_in == null and u in g.units).size(), "/3")
	# ---------------------------------------------------------------- freeblades & mercenary camps
	game = g
	var bands := g.open_recruits()
	print("FT freeblade bands on map: ", bands.size(), "  camps: ", g.camps.size())
	if not bands.is_empty():
		var bp: Vector2 = bands[0][0]
		var band: Array = []
		for gid in g.recruit_groups:
			for u in g.recruit_groups[gid]["units"]:
				if is_instance_valid(u) and u.alive and u.recruit_group >= 0 and u.pos2().distance_to(bp) < 4.0:
					band.append(u)
		var foe2 := g.spawn_unit("swordsman", 2, bp + Vector2(6, 0))
		await _wait(2.0)
		print("FT recruits ignored by enemies: enemy attacking a recruit=", foe2.state == Unit.ATTACK and foe2.target in band, " find_enemy picks a recruit=", g.find_enemy(foe2.pos2(), 10.0, 2, foe2) in band)
		foe2.die(null)
		var pop0: int = g.players[h].pop
		var scout := g.spawn_unit("knight", h, bp + Vector2(12, 0))
		scout.order_move(bp + Vector2(1.5, 0))
		await _wait(6.0)
		print("FT claim band: members now owned by you=", band.filter(func(u): return u.pid == h).size(), "/", band.size(),
			" kinds=", band.map(func(u): return u.kind), " pop %d -> %d" % [pop0, g.players[h].pop], " open bands left=", g.open_recruits().size())
	if not g.camps.is_empty():
		var camp: MercCamp = g.camps[0]
		var k: String = camp.offers[0]
		g.players[h].age = 3
		g.players[h].res["gold"] = 2000.0
		g.players[h].res["mana"] = 2000.0
		g.players[h].res["food"] = 2000.0
		for i in 4:
			g.spawn_building("house", h, Game.snap_pos(2.5, g.buildings_of(h)[0].pos2() + Vector2(-10 + i * 3, 12)), true)
		print("FT pop room: %d/%d" % [g.players[h].pop, g.players[h].pop_cap])
		print("FT hire without a unit nearby: ", camp.hire_check(h, k))
		var hirer := g.spawn_unit("knight", h, camp.pos2() + Vector2(4, 0))
		await _wait(0.5)
		var s0: int = camp.stock[k]
		var g0: float = g.players[h].res["gold"]
		var merc := camp.hire(h, k)
		print("FT hired: ", merc.def["name"] if merc else "none", " stock %d -> %d gold %d -> %d" % [s0, camp.stock[k], g0, g.players[h].res["gold"]])
		camp.hire(h, k)
		print("FT hire until sold out: ", camp.hire_check(h, k))
		g.save_to("slot1")
		var open_before := g.open_recruits().size()
		var stock_before: Dictionary = camp.stock.duplicate()
		main.load_game("slot1")
		await get_tree().process_frame
		await get_tree().process_frame
		var g3: Game = main.current
		print("FT after load: open bands %d (was %d), camp stock %s (was %s), mercs owned %d" % [g3.open_recruits().size(), open_before,
			str(g3.camps[0].stock), str(stock_before), g3.units.filter(func(u): return u.pid == h and u.def.get("merc", false)).size()])
	print("FT DONE")
	get_tree().quit()
