extends Node
## Developer tool (--autotest --showcase): stages gates, upgraded units and a garrison for a screenshot.

var game: Game


func _ready() -> void:
	_run()


func _run() -> void:
	await get_tree().process_frame
	if "--mercshot" in OS.get_cmdline_user_args():
		await _mercs()
		return
	var h := game.human
	var p: PlayerData = game.players[h]
	p.age = 3
	var th: Building = game.buildings_of(h)[0]
	var c := Game.snap_pos(1.0, th.pos2() + Vector2(0, 9))
	for dx in range(-6, 7):
		var k := "gate" if dx == 0 else "wall"
		if game.can_place(k, c + Vector2(dx, 0), h):
			game.spawn_building(k, h, c + Vector2(dx, 0), true)
	var lines := [["swordsman", ["", "up_longsword", "up_blademaster"]], ["spearman", ["", "up_pike", "up_halberd"]],
		["archer", ["", "up_crossbow", "up_arbalest"]]]
	# three columns per line: base, tier 1, tier 2 (shown by temporarily applying upgrades per unit)
	var row := 0
	for ln in lines:
		var kind: String = ln[0]
		for tier in 3:
			var u := game.spawn_unit(kind, h, c + Vector2(-2.4 + tier * 1.6, 3.0 + row * 1.5))
			if tier > 0:
				var d: Dictionary = Defs.UNITS[kind].duplicate(true)
				for t in range(1, tier + 1):
					var tech: Dictionary = Defs.TECHS[ln[1][t]]
					for k in tech["stats"]:
						d[k] = tech["stats"][k]
					d["tier"] = t
				u.set_def(d)
			u.rotation.y = 0.0
			u.order_hold()
		row += 1
	game.spawn_unit("knight", h, c + Vector2(3.4, 3.6)).order_hold()
	var pal := game.spawn_unit("knight", h, c + Vector2(3.4, 5.8))
	pal.order_hold()
	var pd: Dictionary = Defs.UNITS["knight"].duplicate(true)
	for k in Defs.TECHS["up_paladin"]["stats"]:
		pd[k] = Defs.TECHS["up_paladin"]["stats"][k]
	pd["tier"] = 1
	pal.set_def(pd)
	var ws: Array = game.units.filter(func(u): return u.pid == h and u.cls == "worker")
	for u in ws.slice(0, 3):
		game.enter_garrison(u, th)
	var foe := game.spawn_unit("swordsman", 2, c + Vector2(0.2, -2.0))
	foe.rotation.y = PI
	var ch = game.players[h].champ
	if ch:
		ch.die(null)
	game.cam.center_on(c + Vector2(0.5, 4.5))
	game.cam.dist = 13.0
	game.cam.target_dist = 13.0
	game.cam.pitch = deg_to_rad(42.0)
	game.ctl.set_selection([th])
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_user_data_dir() + "/showcase.png")
	print("SHOWCASE saved")
	get_tree().quit()


func _mercs() -> void:
	var h := game.human
	game.players[h].age = 3
	var camp: MercCamp = game.camps[0]
	var c := camp.pos2()
	var kinds := ["ironbreaker", "ranger", "ogre", "golem", "griffin"]
	for i in kinds.size():
		var u := game.spawn_unit(kinds[i], h, c + Vector2(-5.0 + i * 2.4, 5.0))
		u.order_hold()
		u.rotation.y = 0.0
	# a neutral band beside the camp
	for i in 2:
		var r := game.spawn_unit("ironbreaker", 0, c + Vector2(5.5 + i * 1.3, 1.0))
		r.make_recruit(99)
	game.cam.center_on(c + Vector2(0.5, 3.0))
	game.cam.dist = 17.0
	game.cam.target_dist = 17.0
	game.cam.pitch = deg_to_rad(45.0)
	game.ctl.set_selection([camp])
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_user_data_dir() + "/mercs.png")
	print("SHOWCASE saved")
	get_tree().quit()
