class_name SaveGame
extends RefCounted
## Saving and loading matches. The map is regenerated from its seed and settings; everything that
## changes during play (economy, buildings, units, resources left, fog, shrines, AI plans) is stored as JSON.

const VERSION := 1
const DIR := "user://saves"
const SLOTS := ["quick", "slot1", "slot2", "slot3", "autosave"]
const SLOT_NAMES := {"quick": "Quick Save", "slot1": "Slot 1", "slot2": "Slot 2", "slot3": "Slot 3", "autosave": "Autosave"}
const SETTINGS_KEYS := ["map_size", "biome", "map_seed", "num_ai", "difficulty", "abundance", "start_res", "forests",
	"water", "relief", "fog", "reveal", "monsters", "shrines", "start_age", "peace", "victory", "pop_cap", "teams",
	"player_color", "speed", "champions", "champion_class"]
const PLAYER_KEYS := ["name", "team", "human", "ai_hard", "res", "age", "techs", "researching", "max_pop", "defeated",
	"gather_mult", "mods", "stats", "champ_class", "champ_level", "champ_xp", "champ_points", "champ_ranks",
	"champ_respawn", "passives", "bell"]


static func _path(slot: String) -> String:
	return "%s/%s.json" % [DIR, slot]


static func _v2(v: Vector2) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01)]


static func _to_v2(a) -> Vector2:
	if a == null or not (a is Array) or a.size() < 2:
		return Vector2.INF
	return Vector2(a[0], a[1])


# ---------------------------------------------------------------- writing
static func save(game: Game, slot: String) -> bool:
	if game.over:
		return false
	var data := serialize(game)
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(_path(slot), FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save " + slot)
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true


static func serialize(game: Game) -> Dictionary:
	var gs := GameSettings
	var settings := {}
	for k in SETTINGS_KEYS:
		settings[k] = gs.get(k)
	var players: Array = []
	for p in game.players:
		var d := {"color": p.color.to_html()}
		for k in PLAYER_KEYS:
			d[k] = p.get(k)
		players.append(d)
	var res_left := []
	res_left.resize(game.md.resources.size())
	res_left.fill(-1)
	for n in game.resources:
		if is_instance_valid(n) and not n.depleted:
			res_left[n.idx] = snappedf(n.amount, 0.1)
	var blds: Array = []
	for b in game.buildings:
		if not b.alive:
			continue
		blds.append({"k": b.kind, "pid": b.pid, "p": _v2(b.pos2()), "rot": b.rotation.y, "done": b.complete,
			"prog": b.progress, "hp": b.hp, "queue": b.queue, "rally": _v2(b.rally) if b.rally != Vector2.INF else null})
	var units: Array = []
	var all_units: Array = game.units.duplicate()
	for b in game.buildings:
		all_units.append_array(b.garrison)
	for u in all_units:
		if not u.alive:
			continue
		var d := {"k": u.kind, "pid": u.pid, "p": _v2(u.pos2()), "rot": u.rotation.y, "hp": u.hp,
			"home": _v2(u.home), "carry": u.carry, "ct": u.carry_type, "gt": u.gtype, "st": u.state, "hold": u.hold}
		if u.state in [Unit.GATHER, Unit.RETURN] and u.node != null and is_instance_valid(u.node):
			d["np"] = _v2(u.node.pos2())
			d["farm"] = u.node is Building
		if u.state == Unit.BUILD and u.btarget != null and is_instance_valid(u.btarget):
			d["bp"] = _v2(u.btarget.pos2())
		if u.state in [Unit.MOVE, Unit.AMOVE] or (u.state == Unit.ATTACK and u.resume_amove):
			d["goal"] = _v2(u.goal)
			d["amove"] = u.state != Unit.MOVE
		if u is Champion:
			d["cds"] = u.cds
		if u.garrison_in != null:
			d["gin"] = _v2(u.garrison_in.pos2())
			if u.pre_node != null and is_instance_valid(u.pre_node):
				d["pre"] = _v2(u.pre_node.pos2())
				d["pre_farm"] = u.pre_node is Building
		units.append(d)
	var shrines: Array = []
	for s in game.shrines:
		shrines.append({"o": s.owner_id, "c": s.capture, "by": s.capturer})
	var ais: Array = []
	for ai in game.ais:
		ais.append({"pid": ai.pid, "attack_at": ai.attack_at, "wave": ai.wave, "attacking": ai.attacking, "target": ai.target_pid})
	var champ_ok: bool = game.players[game.human].champ != null
	return {
		"version": VERSION,
		"meta": {
			"date": Time.get_datetime_string_from_system(false, true),
			"biome": GameSettings.BIOME_NAMES[gs.biome], "size": GameSettings.MAP_SIZE_NAMES[gs.map_size],
			"elapsed": game.elapsed, "players": game.players.size() - 1,
			"age": game.players[game.human].age, "champ_level": game.players[game.human].champ_level if champ_ok or game.players[game.human].champ_class != "" else 0,
			"difficulty": GameSettings.DIFFICULTY_NAMES[gs.difficulty],
		},
		"settings": settings,
		"elapsed": game.elapsed,
		"control_team": game.control_team, "control_timer": game.control_timer,
		"players": players,
		"resources": res_left,
		"buildings": blds,
		"units": units,
		"shrines": shrines,
		"ais": ais,
		"fog": Marshalls.raw_to_base64(game.fog_exp),
		"cam": {"f": [game.cam.focus.x, game.cam.focus.z], "yaw": game.cam.yaw, "dist": game.cam.target_dist, "pitch": game.cam.pitch},
	}


# ---------------------------------------------------------------- reading
static func read(slot: String) -> Dictionary:
	if not FileAccess.file_exists(_path(slot)):
		return {}
	var f := FileAccess.open(_path(slot), FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary) or int(parsed.get("version", 0)) != VERSION:
		return {}
	return parsed


static func exists(slot: String) -> bool:
	return FileAccess.file_exists(_path(slot))


static func delete(slot: String) -> void:
	if exists(slot):
		DirAccess.remove_absolute(_path(slot))


static func modified(slot: String) -> int:
	return FileAccess.get_modified_time(_path(slot)) if exists(slot) else 0


## The most recently written save slot, or "" if there are none.
static func latest() -> String:
	var best := ""
	var bt := 0
	for s in SLOTS:
		var t := modified(s)
		if t > bt:
			bt = t
			best = s
	return best


static func describe(slot: String) -> String:
	var d := read(slot)
	if d.is_empty():
		return "Empty"
	var m: Dictionary = d["meta"]
	var t := int(m["elapsed"])
	var champ := ("  •  Champion Lv %d" % m["champ_level"]) if int(m["champ_level"]) > 0 else ""
	return "%s  •  %s %s  •  %d players (%s)  •  %s  •  %d:%02d played%s" % [
		m["date"].replace("T", " ").substr(0, 16), m["size"], m["biome"], m["players"], m["difficulty"],
		Defs.AGE_NAMES[int(m["age"])], t / 60, t % 60, champ]


## Copies a save's match settings into GameSettings so the same world is regenerated.
static func apply_settings(data: Dictionary) -> void:
	var s: Dictionary = data["settings"]
	for k in s:
		GameSettings.set(k, s[k])
	GameSettings.random_seed = false


## Called by Game while building a loaded match, after players, terrain and resource nodes exist.
static func restore(game: Game, data: Dictionary) -> void:
	# players
	var pl: Array = data["players"]
	for i in mini(pl.size(), game.players.size()):
		var p: PlayerData = game.players[i]
		var d: Dictionary = pl[i]
		for k in PLAYER_KEYS:
			if d.has(k) and k != "stats":
				var v = d[k]
				if k in ["age", "max_pop", "team", "champ_level", "champ_points"]:
					v = int(v)
				elif k == "champ_ranks":
					v = v.map(func(x): return int(x))
				p.set(k, v)
		p.color = Color.html(d["color"])
	# rebuild upgraded unit stats from researched upgrade lines (lower tiers first)
	for i in range(game.players.size()):
		var ups: Array = game.players[i].techs.keys().filter(func(t): return Defs.TECHS.has(t) and Defs.TECHS[t].has("line"))
		ups.sort_custom(func(a, b): return Defs.TECHS[a]["tier"] < Defs.TECHS[b]["tier"])
		for t in ups:
			game.apply_upgrade(i, t, false)
	# resources (depleted ones are removed, others keep what's left)
	var left: Array = data["resources"]
	for n in game.resources.duplicate():
		if n.idx < left.size():
			var a: float = left[n.idx]
			if a < 0.0:
				n.deplete()
			else:
				n.amount = a
	# buildings
	for d in data["buildings"]:
		var b := game.spawn_building(d["k"], int(d["pid"]), _to_v2(d["p"]), d["done"], d["rot"])
		b.progress = d["prog"]
		b.hp = minf(d["hp"], b.max_hp)
		b._update_visual()
		var q: Array = []
		for it in d["queue"]:
			q.append({"id": it["id"], "tech": it["tech"], "t": float(it["t"]), "total": float(it["total"])})
		b.queue = q
		var r := _to_v2(d.get("rally"))
		if r != Vector2.INF:
			b.rally = r
	for i in range(1, game.players.size()):
		game.recalc_pop(i)
	# units
	var restored: Array = []
	for d in data["units"]:
		var k: String = d["k"]
		var pid := int(d["pid"])
		var u: Unit
		if Defs.UNITS[k].get("champion", false):
			var c := Champion.new()
			game.spawn_unit(k, pid, _to_v2(d["p"]), c)
			c.init_champion(game.players[pid].champ_class)
			game.players[pid].champ = c
			var cds: Array = d.get("cds", [0, 0, 0, 0])
			for j in 4:
				c.cds[j] = float(cds[j])
			u = c
		else:
			u = game.spawn_unit(k, pid, _to_v2(d["p"]))
		if u == null:
			continue
		u.hp = minf(d["hp"], u.max_hp)
		u.rotation.y = d["rot"]
		var home := _to_v2(d["home"])
		if home != Vector2.INF:
			u.home = home
		restored.append([u, d])
	# resume what everyone was doing
	for pair in restored:
		var u: Unit = pair[0]
		var d: Dictionary = pair[1]
		if d.has("gin"):
			u.gtype = d["gt"]
			if d.has("pre"):
				var pp := _to_v2(d["pre"])
				if d.get("pre_farm", false):
					for b in game.buildings:
						if b.kind == "farm" and b.pid == u.pid and b.pos2().distance_to(pp) < 0.6:
							u.pre_node = b
				else:
					u.pre_node = game.find_resource(pp, u.gtype, 1.0)
			var gp := _to_v2(d["gin"])
			for b in game.buildings:
				if b.pid == u.pid and b.capacity() > 0 and b.pos2().distance_to(gp) < 0.6:
					game.enter_garrison(u, b)
					break
			if u.garrison_in != null:
				continue
		var st := int(d["st"])
		u.gtype = d["gt"]
		if d.has("np"):
			var np := _to_v2(d["np"])
			var target = null
			if d.get("farm", false):
				for b in game.buildings:
					if b.kind == "farm" and b.pid == u.pid and b.pos2().distance_to(np) < 0.6:
						target = b
						break
			else:
				target = game.find_resource(np, u.gtype, 1.0)
				if target == null:
					target = game.find_resource(np, u.gtype, 10.0)
			if target != null:
				u.order_gather(target)
		elif d.has("bp"):
			var bp := _to_v2(d["bp"])
			for b in game.buildings:
				if b.pid == u.pid and b.pos2().distance_to(bp) < 0.6:
					u.order_build(b)
					break
		elif d.has("goal"):
			u.order_move(_to_v2(d["goal"]), d.get("amove", false))
		elif d.get("hold", false):
			u.order_hold()
		u.carry = float(d["carry"])
		u.carry_type = d["ct"]
		if st == Unit.RETURN and u.carry > 0.0:
			u._go_return()
		u._update_carry()
	# stats last (spawning counted units as "trained")
	for i in mini(pl.size(), game.players.size()):
		game.players[i].stats = pl[i]["stats"]
	# shrines
	var sh: Array = data["shrines"]
	for i in mini(sh.size(), game.shrines.size()):
		var s: Shrine = game.shrines[i]
		s.owner_id = int(sh[i]["o"])
		s.capture = sh[i]["c"]
		s.capturer = int(sh[i]["by"])
		s._refresh()
	game.elapsed = data["elapsed"]
	game.control_team = int(data["control_team"])
	game.control_timer = data["control_timer"]
	var fog := Marshalls.base64_to_raw(data["fog"])
	if fog.size() == game.fog_exp.size():
		game.fog_exp = fog


static func restore_late(game: Game, data: Dictionary) -> void:
	for a in data["ais"]:
		for ai in game.ais:
			if ai.pid == int(a["pid"]):
				ai.attack_at = a["attack_at"]
				ai.wave = int(a["wave"])
				ai.attacking = a["attacking"]
				ai.target_pid = int(a["target"])
	var c: Dictionary = data["cam"]
	game.cam.focus = Vector3(c["f"][0], game.height_at(c["f"][0], c["f"][1]), c["f"][1])
	game.cam.yaw = c["yaw"]
	game.cam.pitch = c["pitch"]
	game.cam.target_dist = c["dist"]
	game.cam.dist = c["dist"]
