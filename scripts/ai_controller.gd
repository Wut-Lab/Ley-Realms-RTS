class_name AIController
extends Node
## Computer opponent. Easy: slower decisions, smaller economy, later and smaller attacks, gather penalty.
## Hard: fast decisions, bigger economy, research, towers, shrine control, frequent attack waves, gather bonus.

const RATIOS := [
	{},
	{"food": 0.5, "wood": 0.37, "gold": 0.13, "mana": 0.0},
	{"food": 0.38, "wood": 0.27, "gold": 0.27, "mana": 0.08},
	{"food": 0.32, "wood": 0.23, "gold": 0.33, "mana": 0.12},
]
const MIX := {
	"barracks": {"swordsman": 4, "spearman": 3, "archer": 3},
	"stable": {"knight": 1},
	"mage_tower": {"mage": 3, "cleric": 1},
	"workshop": {"catapult": 1},
	"dragon_roost": {"dragon": 1},
}

var game: Game
var pid := 0
var hard := false
var t := 0.0
var interval := 1.0
var base := Vector2.ZERO
var rally := Vector2.ZERO
var attack_at := 0.0
var attacking := false
var target_pid := -1
var wave := 0
var squad: Array = []
var threat: Entity = null
var threat_t := -100.0
var recent := {}
var rebalance_t := 0.0
var rng := RandomNumberGenerator.new()
var hidden_workers := 0
var bell_t := -100.0
var claim_unit: Unit = null
var camp_runner: Unit = null
var merc_t := 0.0


func setup(g: Game, id: int, h: bool) -> void:
	game = g
	pid = id
	hard = h
	interval = 0.8 if hard else 1.6
	attack_at = maxf(game.peace_until, 330.0 if hard else 660.0)
	rng.seed = id * 1337 + GameSettings.map_seed
	t = rng.randf() * interval


func on_attacked(victim: Entity, attacker: Entity) -> void:
	if attacker != null and is_instance_valid(attacker) and attacker.alive and attacker.pid != pid:
		if victim.pos2().distance_to(base) < 35.0 or victim.is_building:
			threat = attacker
			threat_t = game.elapsed


func _process(delta: float) -> void:
	if game.over:
		return
	t -= delta
	rebalance_t -= delta
	if t > 0.0:
		return
	t = interval
	var p: PlayerData = game.players[pid]
	if p.defeated:
		return
	_think(p)


func _recent(k: String, secs: float) -> bool:
	return game.elapsed - recent.get(k, -1000.0) < secs


func _think(p: PlayerData) -> void:
	var peasants: Array = []
	var army: Array = []
	for u in game.units:
		if u.pid != pid or not u.alive:
			continue
		if u.cls == "worker":
			peasants.append(u)
		elif u.is_military():
			army.append(u)
	var mine: Array = game.buildings_of(pid)
	hidden_workers = 0
	for u in game.garrisoned_of(pid):
		if u.cls == "worker":
			hidden_workers += 1
	var th: Building = null
	for b in mine:
		if b.kind == "town_hall" and (th == null or b.complete):
			th = b
	if th:
		base = th.pos2()
	elif not mine.is_empty():
		base = mine[0].pos2()
	elif not peasants.is_empty():
		base = peasants[0].pos2()
	var center := Vector2(game.size, game.size) * 0.5
	rally = base + (center - base).normalized() * 11.0
	_economy(p, peasants, mine, th)
	_construct(p, peasants, mine, th)
	_produce(p, peasants, mine, th)
	_military(p, army, mine)


# ---------------------------------------------------------------- economy
func _target_peasants(p: PlayerData) -> int:
	var n := (16 if not hard else 26) + (p.age - 1) * (4 if not hard else 8)
	return mini(n, int(p.max_pop * 0.5))


func _economy(p: PlayerData, peasants: Array, mine: Array, th: Building) -> void:
	if th and th.complete and th.queued_count("peasant") < 2 and peasants.size() + hidden_workers + th.queued_count("peasant") < _target_peasants(p):
		if not _saving(p) or p.res["food"] > _age_cost(p).get("food", 0) + 50:
			th.enqueue("peasant")
	var counts := {"food": 0, "wood": 0, "gold": 0, "mana": 0}
	var idle: Array = []
	for u in peasants:
		if u.state == Unit.IDLE:
			idle.append(u)
		elif (u.state == Unit.GATHER or u.state == Unit.RETURN) and u.gtype != "":
			counts[u.gtype] += 1
	var ratio: Dictionary = RATIOS[p.age]
	var total := peasants.size()
	for u in idle:
		var order: Array = Defs.RES.duplicate()
		order.sort_custom(func(a, b): return ratio[a] * total - counts[a] > ratio[b] * total - counts[b])
		for r in order:
			if _assign(u, r, p, mine):
				counts[r] += 1
				break
	# hard AI periodically rebalances its workforce
	if hard and rebalance_t <= 0.0 and total > 6:
		rebalance_t = 12.0
		var over_r := ""
		var under_r := ""
		var best_o := 1.5
		var best_u := 1.5
		for r in Defs.RES:
			var diff: float = counts[r] - ratio[r] * total
			if diff > best_o:
				best_o = diff
				over_r = r
			if -diff > best_u:
				best_u = -diff
				under_r = r
		if over_r != "" and under_r != "":
			for u in peasants:
				if u.state == Unit.GATHER and u.gtype == over_r and u.carry < 1.0:
					_assign(u, under_r, p, mine)
					break


func _assign(u: Unit, r: String, p: PlayerData, mine: Array) -> bool:
	if r == "food":
		var n = game.find_resource(base, "food", 24.0)
		if n:
			u.order_gather(n)
			return true
		var f = game.free_farm_near(base, pid, 40.0)
		if f:
			u.order_gather(f)
			return true
		var farms := 0
		for b in mine:
			if b.kind == "farm":
				farms += 1
		if p.res["wood"] >= 60 and farms < 24:
			var spot = _find_spot("farm", base, 4.5, 13.0 + farms * 0.4)
			if spot != null and game.place_building(pid, "farm", spot, [u]) != null:
				return true
		return false
	var n = game.find_resource(base, r, 40.0)
	if n == null:
		n = game.find_resource(base, r, 80.0)
	if n == null:
		return false
	var dp := game.nearest_dropoff(n.pos2(), pid)
	if (dp == null or dp.edge_dist(n.pos2()) > 11.0) and p.res["wood"] >= 90 and not _recent("storehouse", 30.0):
		var spot = _find_spot("storehouse", n.pos2(), 3.0, 7.0)
		if spot != null:
			if game.place_building(pid, "storehouse", spot, [u]) != null:
				recent["storehouse"] = game.elapsed
				return true
	u.order_gather(n)
	return true


func _find_spot(k: String, c: Vector2, rmin: float, rmax: float):
	var s: float = Defs.BUILDINGS[k]["size"]
	var margin := 0 if k == "farm" or k == "wall" else 1
	for i in 40:
		var a := rng.randf() * TAU
		var r := rng.randf_range(rmin, rmax) + i * 0.15
		var p := Game.snap_pos(s, c + Vector2.from_angle(a) * r)
		if game.can_place(k, p, pid, margin):
			return p
	return null


# ---------------------------------------------------------------- construction
func _count(mine: Array, k: String) -> int:
	var n := 0
	for b in mine:
		if b.kind == k:
			n += 1
	return n


func _unfinished(mine: Array, k: String) -> int:
	var n := 0
	for b in mine:
		if b.kind == k and not b.complete:
			n += 1
	return n


func _builder(peasants: Array, near: Vector2) -> Unit:
	var best: Unit = null
	var bd := 1e9
	for u in peasants:
		if u.state == Unit.BUILD:
			continue
		var d: float = u.pos2().distance_to(near) + (0.0 if u.state == Unit.IDLE else 8.0) + (6.0 if u.gtype == "food" else 0.0)
		if d < bd:
			bd = d
			best = u
	return best


func _build(k: String, near: Vector2, rmin: float, rmax: float, peasants: Array, helpers: int = 0) -> bool:
	var p: PlayerData = game.players[pid]
	var d: Dictionary = Defs.BUILDINGS[k]
	if p.age < d["age"] or not p.can_afford(d["cost"]) or _recent("b_" + k, 8.0):
		return false
	var spot = _find_spot(k, near, rmin, rmax)
	if spot == null:
		recent["b_" + k] = game.elapsed
		return false
	var who: Array = []
	var u := _builder(peasants, spot)
	if u == null:
		return false
	who.append(u)
	for i in helpers:
		var h := _builder(peasants.filter(func(x): return not (x in who)), spot)
		if h:
			who.append(h)
	var b := game.place_building(pid, k, spot, who)
	recent["b_" + k] = game.elapsed
	return b != null


func _construct(p: PlayerData, peasants: Array, mine: Array, th: Building) -> void:
	if peasants.is_empty():
		return
	if th == null:
		_build("town_hall", base, 0.0, 12.0, peasants, 2)
		return
	var cap := mini(p.pop_cap, p.max_pop)
	var room := cap - p.pop
	var houses_building := _unfinished(mine, "house")
	if p.pop_cap < p.max_pop and room < (5 if not hard else 8) and houses_building < (1 if not hard else 2):
		_build("house", base, 7.0, 18.0, peasants)
	var np := peasants.size()
	if _count(mine, "barracks") == 0 and np >= (9 if not hard else 7):
		_build("barracks", rally, 0.0, 8.0, peasants, 1)
	if _count(mine, "blacksmith") == 0 and np >= (18 if not hard else 13):
		_build("blacksmith", base, 8.0, 16.0, peasants)
	if p.age >= 2:
		if _count(mine, "stable") == 0:
			_build("stable", rally, 0.0, 10.0, peasants, 1)
		if _count(mine, "mage_tower") == 0 and p.res["mana"] >= 40:
			_build("mage_tower", base, 9.0, 18.0, peasants)
		if hard and _count(mine, "barracks") < 2 and np >= 22:
			_build("barracks", rally, 0.0, 12.0, peasants)
		if hard and _count(mine, "tower") < 3:
			_build("tower", base + (rally - base) * 0.6, 3.0, 10.0, peasants)
	if p.age >= 3:
		if _count(mine, "workshop") == 0:
			_build("workshop", rally, 0.0, 12.0, peasants, 1)
		if _count(mine, "dragon_roost") == 0 and (hard or game.elapsed > 1500.0):
			_build("dragon_roost", base, 10.0, 20.0, peasants, 1)


# ---------------------------------------------------------------- production
func _age_cost(p: PlayerData) -> Dictionary:
	if p.age == 1:
		return Defs.TECHS["age2"]["cost"]
	if p.age == 2:
		return Defs.TECHS["age3"]["cost"]
	return {}


func _wants_age(p: PlayerData, np: int) -> bool:
	if p.age >= 3 or p.researching.has("age2") or p.researching.has("age3"):
		return false
	if p.age == 1:
		return np >= (13 if hard else 15) and game.elapsed > (0.0 if hard else 300.0)
	return np >= (22 if hard else 20) and game.elapsed > (0.0 if hard else 900.0)


func _saving(p: PlayerData) -> bool:
	var np := game.count_units(pid, "peasant")
	return _wants_age(p, np) and not p.can_afford(_age_cost(p))


func _spend_ok(p: PlayerData, cost: Dictionary) -> bool:
	# never spend the food needed to rebuild a collapsed workforce
	var workers := game.count_units(pid, "peasant") + hidden_workers
	if workers < 8 and cost.get("food", 0) > 0 and p.res["food"] - cost["food"] < 100:
		return false
	if not _saving(p):
		return true
	var ac := _age_cost(p)
	for r in cost:
		if p.res[r] - cost[r] < ac.get(r, 0):
			return false
	return true


func _produce(p: PlayerData, peasants: Array, mine: Array, th: Building) -> void:
	var np := peasants.size()
	if th and th.complete and _wants_age(p, np):
		var id := "age2" if p.age == 1 else "age3"
		if th.check(id) == "":
			th.enqueue(id)
	# research
	var chance := 0.35 if hard else 0.08
	for b in mine:
		if not b.complete or b.queue.size() > 1:
			continue
		for r in b.def.get("research", []):
			if r.begins_with("age"):
				continue
			if b.check(r) == "" and _spend_ok(p, Defs.TECHS[r]["cost"]) and rng.randf() < chance:
				b.enqueue(r)
				break
	# hero
	if th and th.complete and p.age >= 2 and (hard or game.elapsed > 1200.0) and th.check("warden") == "" and _spend_ok(p, Defs.UNITS["warden"]["cost"]):
		th.enqueue("warden")
	# army
	for b in mine:
		if not b.complete or not MIX.has(b.kind) or b.queue.size() >= 2:
			continue
		if b.rally == Vector2.INF or b.rally.distance_to(rally) > 6.0:
			b.set_rally(rally)
		var mix: Dictionary = MIX[b.kind]
		var tot := 0
		for k in mix:
			tot += mix[k]
		var roll := rng.randi() % tot
		var pick := ""
		for k in mix:
			roll -= mix[k]
			if roll < 0:
				pick = k
				break
		if pick != "" and b.check(pick) == "" and _spend_ok(p, Defs.UNITS[pick]["cost"]):
			if not hard and rng.randf() < 0.35:
				continue
			b.enqueue(pick)


# ---------------------------------------------------------------- military
func _military(p: PlayerData, army: Array, mine: Array) -> void:
	squad = squad.filter(func(u): return is_instance_valid(u) and u.alive)
	# defend the base
	var t_valid := threat != null and is_instance_valid(threat) and threat.alive and game.elapsed - threat_t < 20.0
	if not t_valid:
		threat = null
		for b in mine:
			var e := game.find_enemy(b.pos2(), 14.0, pid, null, true)
			if e and e.pid != 0:
				threat = e
				threat_t = game.elapsed
				break
	# Town Bell: shelter peasants from raids the army can't answer; all clear once it's quiet
	if threat and not p.bell and threat.pos2().distance_to(base) < 24.0 and game.elapsed - bell_t > 30.0:
		var raiders := game.area_targets(threat.pos2(), 10.0, pid).filter(func(e): return e is Unit and e.cls != "worker").size()
		var defenders := army.filter(func(u): return u.pos2().distance_to(base) < 30.0).size()
		if raiders >= 2 and defenders < raiders and (hard or rng.randf() < 0.4):
			game.town_bell(pid)
			bell_t = game.elapsed
	elif p.bell and ((threat == null and game.elapsed - threat_t > 12.0) or game.elapsed - bell_t > 60.0):
		game.all_clear(pid)
	if threat:
		for u in army:
			if u in squad:
				continue
			if u.state == Unit.IDLE or (u.state == Unit.AMOVE and not attacking) or (hard and u.pos2().distance_to(base) < 45.0 and u.state != Unit.ATTACK):
				u.order_move(threat.pos2(), true)
		return
	_mercenaries(p, army)
	# claim ley shrines
	if not game.shrines.is_empty() and army.size() >= (4 if hard else 9) and game.elapsed >= game.peace_until * 0.5:
		var want := 4 if hard else 2
		var shrine: Shrine = null
		var bd := 1e9
		for s in game.shrines:
			if s.owner_id >= 0 and game.players[s.owner_id].team == p.team:
				continue
			var d: float = s.pos2().distance_to(base)
			if d < bd:
				bd = d
				shrine = s
		if shrine:
			if squad.size() < want:
				for u in army:
					if squad.size() >= want:
						break
					if u.state == Unit.IDLE and not (u in squad) and not u.flying:
						squad.append(u)
			for u in squad:
				if u.state == Unit.IDLE and u.pos2().distance_to(shrine.pos2()) > 3.0:
					u.order_move(shrine.pos2() + Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2)), true)
	# attack waves
	var avail: Array = army.filter(func(u): return not (u in squad))
	if game.elapsed >= attack_at and game.elapsed >= game.peace_until:
		var need := mini((6 + wave * 2) if not hard else (8 + wave * 3), 36)
		if not attacking and avail.size() >= need:
			var tgt := _pick_target(p)
			if tgt:
				attacking = true
				wave += 1
				attack_at = game.elapsed + (240.0 if not hard else 150.0)
				for u in avail:
					u.order_move(tgt.pos2(), true)
		elif attacking:
			var tgt := _pick_target(p)
			var away := 0
			for u in avail:
				if u.pos2().distance_to(base) > 30.0:
					away += 1
			if tgt == null or away < 2:
				attacking = false
			else:
				for u in avail:
					if u.state == Unit.IDLE:
						u.order_move(tgt.pos2(), true)
	if not attacking:
		for u in avail:
			if u.state == Unit.IDLE and u.pos2().distance_to(rally) > 9.0 and u != camp_runner and u != claim_unit:
				u.order_move(rally + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)))


func _free_unit(army: Array, near: Vector2) -> Unit:
	var best: Unit = null
	var bd := 1e9
	for u in army:
		if u in squad or u == claim_unit or u == camp_runner or u.state != Unit.IDLE:
			continue
		var d: float = u.pos2().distance_to(near)
		if d < bd:
			bd = d
			best = u
	return best


## Send scouts to claim freeblades, and hire at mercenary camps when there's gold to spare.
func _mercenaries(p: PlayerData, army: Array) -> void:
	merc_t -= interval
	if merc_t > 0.0:
		return
	merc_t = 4.0 if hard else 9.0
	# freeblades: whoever arrives first gets the band
	var busy := claim_unit != null and is_instance_valid(claim_unit) and claim_unit.alive and claim_unit.state == Unit.MOVE
	if not busy and game.elapsed > (45.0 if hard else 200.0) and (hard or rng.randf() < 0.5):
		claim_unit = null
		var best = null
		var bd := 1e9
		for g in game.open_recruits():
			var d: float = g[0].distance_to(base)
			if d < bd and d < game.size * (0.55 if hard else 0.35):
				bd = d
				best = g[0]
		if best != null:
			var u := _free_unit(army, best)
			if u:
				claim_unit = u
				u.order_move(best)
	# mercenary camps
	if game.camps.is_empty() or p.res["gold"] < (110.0 if hard else 220.0):
		return
	for c in game.camps:
		if not c.has_unit_near(pid):
			continue
		var picks: Array = c.offers.duplicate()
		picks.sort_custom(func(a, b): return Defs.UNITS[a]["age"] > Defs.UNITS[b]["age"])
		for k in picks:
			var cost: Dictionary = Defs.UNITS[k]["cost"]
			if c.hire_check(pid, k) == "" and _spend_ok(p, cost) and p.res["gold"] - cost["gold"] >= (0.0 if hard else 80.0):
				var hired: Unit = c.hire(pid, k)
				if hired:
					hired.order_move(rally)
					if camp_runner != null and is_instance_valid(camp_runner) and camp_runner.pos2().distance_to(c.pos2()) < 12.0:
						camp_runner.order_move(rally)
						camp_runner = null
				return
	var running := camp_runner != null and is_instance_valid(camp_runner) and camp_runner.alive and camp_runner.state == Unit.MOVE
	if not running and p.res["gold"] >= (150.0 if hard else 300.0):
		var near_camp: MercCamp = null
		var cd := 1e9
		for c in game.camps:
			var d: float = c.pos2().distance_to(base)
			if d < cd and d < game.size * (0.6 if hard else 0.4):
				cd = d
				near_camp = c
		if near_camp and not near_camp.has_unit_near(pid):
			var u := _free_unit(army, near_camp.pos2())
			if u:
				camp_runner = u
				u.order_move(near_camp.pos2() + Vector2(randf_range(-3, 3), randf_range(-3, 3)))


func _pick_target(p: PlayerData) -> Entity:
	if target_pid < 0 or game.players[target_pid].defeated or not game.is_enemy(pid, target_pid):
		target_pid = -1
		var bd := 1e9
		for i in range(1, game.players.size()):
			var op: PlayerData = game.players[i]
			if op.defeated or not game.is_enemy(pid, i):
				continue
			var d: float = game.md.starts[i - 1].distance_to(base)
			if op.human and not hard:
				d *= 0.7
			if d < bd:
				bd = d
				target_pid = i
	if target_pid < 0:
		return null
	var best: Entity = null
	var bd2 := 1e9
	for b in game.buildings:
		if b.pid == target_pid and b.alive:
			var d: float = b.pos2().distance_to(base) + (12.0 if b.kind == "wall" else 0.0)
			if d < bd2:
				bd2 = d
				best = b
	if best == null:
		for u in game.units:
			if u.pid == target_pid and u.alive:
				return u
	return best
