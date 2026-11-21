class_name Champion
extends Unit
## The player's hero character: levels up from battle XP, spends skill points on four abilities,
## and respawns at the Town Hall when slain. Progress lives on PlayerData so it survives death.

var class_id := ""
var cdef: Dictionary = {}
var cds := [0.0, 0.0, 0.0, 0.0]
var pending := -1
var pending_p := Vector2.ZERO
var ai_t := 0.0
var retreating := false


func init_champion(cid: String) -> void:
	class_id = cid
	cdef = Defs.CHAMPIONS[cid]
	refresh_stats(true)


func abilities() -> Array:
	return cdef["abilities"]


func level() -> int:
	return player().champ_level


func rank(i: int) -> int:
	return player().champ_ranks[i]


func display_name() -> String:
	return "%s (Level %d)" % [cdef["name"], level()]


func refresh_stats(full: bool = false) -> void:
	var frac := 1.0 if full or max_hp <= 0.0 else hp / max_hp
	max_hp = def["hp"] * (1.0 + 0.12 * (level() - 1))
	hp = max_hp * frac


func atk_val() -> float:
	return super.atk_val() * (1.0 + 0.1 * (level() - 1))


func armor_val() -> float:
	return super.armor_val() + 0.5 * (level() - 1)


func parmor_val() -> float:
	return super.parmor_val() + 0.5 * (level() - 1)


# ---------------------------------------------------------------- progression
func add_xp(x: float) -> void:
	var p := player()
	if p.champ_level >= Defs.MAX_LEVEL:
		return
	p.champ_xp += x
	while p.champ_level < Defs.MAX_LEVEL and p.champ_xp >= Defs.XP_TABLE[p.champ_level + 1]:
		p.champ_level += 1
		p.champ_points += 1
		refresh_stats()
		hp = minf(max_hp, hp + max_hp * 0.3)
		game.spawn_fx("levelup", position, 1.0, Color.WHITE)
		if pid == game.human and game.hud:
			game.hud.message("Your %s reached level %d! (+1 skill point)" % [cdef["name"], p.champ_level], Color(1, 0.85, 0.35))


func xp_progress() -> float:
	var p := player()
	if p.champ_level >= Defs.MAX_LEVEL:
		return 1.0
	var lo: float = Defs.XP_TABLE[p.champ_level]
	var hi: float = Defs.XP_TABLE[p.champ_level + 1]
	return clampf((p.champ_xp - lo) / (hi - lo), 0.0, 1.0)


## "" if the next rank of ability i can be learned, otherwise the reason.
func learn_check(i: int) -> String:
	var p := player()
	var a: Dictionary = abilities()[i]
	var r: int = p.champ_ranks[i]
	if r >= a["vals"].size():
		return "Maximum rank"
	if p.champ_points <= 0:
		return "No skill points"
	var need := Defs.rank_level(a, r + 1)
	if p.champ_level < need:
		return "Requires level %d" % need
	return ""


func learn(i: int) -> bool:
	if learn_check(i) != "":
		return false
	var p := player()
	p.champ_ranks[i] += 1
	p.champ_points -= 1
	return true


# ---------------------------------------------------------------- casting
func cast_check(i: int) -> String:
	if rank(i) <= 0:
		return "Not learned yet"
	if cds[i] > 0.0:
		return "Ready in %ds" % ceili(cds[i])
	if stun_t > 0.0:
		return "Stunned"
	return ""


func _clear() -> void:
	pending = -1
	super._clear()


## Cast ability i; point abilities walk into range first.
func request_cast(i: int, p: Vector2) -> bool:
	if cast_check(i) != "":
		return false
	var a: Dictionary = abilities()[i]
	if a["target"] == "self":
		_cast(i, pos2())
		return true
	var rng: float = a["range"]
	if pos2().distance_to(p) <= rng:
		_face(p - pos2())
		_cast(i, p)
	else:
		order_move(p)
		pending = i
		pending_p = p
	return true


func tick(delta: float) -> void:
	for i in 4:
		cds[i] = maxf(0.0, cds[i] - delta)
	if pending >= 0 and alive:
		var a: Dictionary = abilities()[pending]
		if pos2().distance_to(pending_p) <= a["range"]:
			var i := pending
			pending = -1
			path = PackedVector2Array()
			state = IDLE
			if cast_check(i) == "":
				_cast(i, pending_p)
		elif state != MOVE:
			pending = -1
	super.tick(delta)
	if alive:
		add_xp(0.4 * delta)
	if (not player().human or GameSettings.autotest) and alive:
		ai_t -= delta
		if ai_t <= 0.0:
			ai_t = 0.6 if player().ai_hard else 1.4
			_ai_think()


func _cast(i: int, p: Vector2) -> void:
	var a: Dictionary = abilities()[i]
	var r := rank(i)
	var v = a["vals"][r - 1]
	cds[i] = a["cd"]
	lunge = 1.0
	player().stats["casts"] = player().stats.get("casts", 0) + 1
	var p3 := Vector3(p.x, game.height_at(p.x, p.y), p.y)
	var rad: float = a["radius"]
	match a["id"]:
		"rally":
			for u in game.allies_near(pos2(), rad, pid):
				u.rally_t = 10.0
				u.rally_mult = 1.0 + v
			game.spawn_fx("burst_gold", position + Vector3.UP, rad * 0.5, Color.WHITE)
		"leap":
			var c := game.nearest_walkable(Vector2i(int(p.x), int(p.y)), 4, Vector2i(int(p.x), int(p.y)))
			var dest := Vector2(c.x + 0.5, c.y + 0.5) if c.x >= 0 else pos2()
			game.spawn_fx("burst", position + Vector3.UP * 0.5, 1.0, Color.WHITE)
			_set_pos(dest)
			position.y = game.height_at(dest.x, dest.y)
			var tw := create_tween()
			body.position.y = 2.5
			tw.tween_property(body, "position:y", 0.0, 0.25)
			var info := _info(v, "melee")
			for e in game.area_targets(dest, rad, pid):
				game.apply_damage(e, info)
				if e is Unit:
					e.stun_t = maxf(e.stun_t, 1.0 + 0.5 * (r - 1))
			game.spawn_fx("burst", Vector3(dest.x, position.y + 0.3, dest.y), rad * 0.7, Color.WHITE)
		"ironskin":
			dr = v
			dr_t = 7.0
		"banner":
			game.spawn_area("banner", p3, pid, rad, 20.0, v, self)
		"meteor":
			game.spawn_area("meteor", p3, pid, rad, 1.1, v, self)
		"nova":
			var info := _info(v, "magic")
			for e in game.area_targets(pos2(), rad, pid):
				game.apply_damage(e, info)
				if e is Unit:
					e.slow_t = 4.0
			game.spawn_fx("nova", position + Vector3.UP * 0.3, rad, Color.WHITE)
		"ward":
			for u in game.allies_near(pos2(), rad, pid):
				u.ward = maxf(u.ward, float(v))
				u.ward_t = 12.0
			game.spawn_fx("burst_blue", position + Vector3.UP, rad * 0.5, Color.WHITE)
		"storm":
			game.spawn_area("storm", p3, pid, rad, 6.0, v, self)
		"mend":
			for u in game.allies_near(pos2(), rad, pid):
				u.hp = minf(u.max_hp, u.hp + v)
				game.spawn_fx("heal_fx", u.position + Vector3.UP * 0.3, 0.8, Color.WHITE)
		"smite":
			for e in game.area_targets(p, rad, pid):
				var dmg: float = v * (2.0 if e.cls in ["monster", "hero"] else 1.0)
				game.apply_damage(e, _info(dmg, "magic"))
			game.spawn_fx("pillar", p3, 1.0, Color.WHITE)
		"aegis":
			for u in game.allies_near(pos2(), rad, pid):
				u.invuln_t = float(v)
			game.spawn_fx("burst_gold", position + Vector3.UP, rad * 0.5, Color.WHITE)
		"holy_nova":
			for u in game.allies_near(pos2(), rad, pid):
				u.hp = minf(u.max_hp, u.hp + v)
			var info := _info(v, "magic")
			for e in game.area_targets(pos2(), rad, pid):
				game.apply_damage(e, info)
			game.spawn_fx("holy_nova", position + Vector3.UP * 0.3, rad, Color.WHITE)


func _info(dmg: float, type: String) -> Dictionary:
	return {"atk": dmg, "type": type, "bonus": {}, "splash": 0.0, "owner": pid, "src": self, "ability": true}


# ---------------------------------------------------------------- death & respawn
func die(killer: Entity) -> void:
	if not alive:
		return
	var p := player()
	p.champ = null
	p.champ_respawn = game.elapsed + 20.0 + 4.0 * p.champ_level
	if pid == game.human and game.hud:
		game.hud.message("Your %s has fallen! Returning in %ds." % [cdef["name"], int(20 + 4 * p.champ_level)], Color(1, 0.4, 0.3))
	elif game.hud and killer != null and is_instance_valid(killer) and killer.pid == game.human:
		game.hud.message("You slew the enemy %s!" % cdef["name"], Color(1, 0.85, 0.35))
	super.die(killer)


# ---------------------------------------------------------------- AI use
func _ai_think() -> void:
	var p := player()
	# spend skill points: ultimate first, then the lowest-ranked ability
	while p.champ_points > 0:
		var best := -1
		if learn_check(3) == "":
			best = 3
		else:
			var lowest := 99
			for i in 3:
				if learn_check(i) == "" and rank(i) < lowest:
					lowest = rank(i)
					best = i
		if best < 0:
			break
		learn(best)
	# retreat when badly hurt
	if hp < max_hp * 0.28 and not retreating:
		var home := game.nearest_dropoff(pos2(), pid)
		if home:
			retreating = true
			order_move(home.pos2())
			return
	if retreating and (hp > max_hp * 0.75 or state == IDLE):
		retreating = false
	var enemies := game.area_targets(pos2(), 9.0, pid).filter(func(e): return e is Unit)
	var n := enemies.size()
	var centroid := Vector2.ZERO
	for e in enemies:
		centroid += e.pos2()
	if n > 0:
		centroid /= n
	var hurt := 0
	for u in game.allies_near(pos2(), 9.0, pid):
		if u.hp < u.max_hp * 0.6:
			hurt += 1
	var easy := not p.ai_hard
	for i in 4:
		if cast_check(i) != "":
			continue
		if easy and randf() < 0.5:
			continue
		var a: Dictionary = abilities()[i]
		var want := false
		match a["kind"]:
			"damage":
				if a["target"] == "self":
					want = game.area_targets(pos2(), a["radius"], pid).size() >= 2
				else:
					want = n >= (2 if not easy else 3) and centroid.distance_to(pos2()) <= a["range"] + 3.0
			"buff":
				want = n >= 3 or (a["id"] == "ironskin" and hp < max_hp * 0.6 and n >= 1)
			"heal":
				want = hurt >= 3 or (a["id"] == "banner" and n >= 4)
		if want:
			var tp: Vector2 = centroid if a["target"] == "point" and n > 0 else pos2()
			request_cast(i, tp)
			return
