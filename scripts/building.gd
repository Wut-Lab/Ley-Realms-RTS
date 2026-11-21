class_name Building
extends Entity
## Static structure: construction, production queue, research, defensive fire.

var complete := false
var progress := 0.0
var queue: Array = []
var rally := Vector2.INF
var rally_node = null
var farmer: Unit = null
var model: MeshInstance3D
var fire: MeshInstance3D
var flag: MeshInstance3D
var cd := 0.0
var scan_t := 0.0
var target: Entity = null
var cells := Rect2i()
var size := 1.0
var stalled := false
var flicker := 0.0


func setup(g: Game, k: String, owner_id: int, done: bool) -> void:
	game = g
	kind = k
	pid = owner_id
	def = Defs.BUILDINGS[k]
	is_building = true
	cls = "building"
	size = def["size"]
	radius = size * 0.5
	height = def["height"]
	max_hp = def["hp"] * player().mods["bhp"]
	model = MeshInstance3D.new()
	model.mesh = Models.mesh(k, player().color)
	add_child(model)
	if done:
		complete = true
		progress = 1.0
		hp = max_hp
	else:
		hp = maxf(1.0, max_hp * 0.05)
	_update_visual()


func display_name() -> String:
	return def["name"] + ("" if complete else " (under construction)")


func edge_dist(p: Vector2) -> float:
	var d := (p - pos2()).abs() - Vector2(size * 0.5, size * 0.5)
	return Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length()


func aim_point() -> Vector3:
	return position + Vector3.UP * height * 0.4


func _update_visual() -> void:
	if kind == "farm":
		model.scale = Vector3.ONE
		return
	model.scale = Vector3(1.0, lerpf(0.12, 1.0, progress), 1.0)


func set_selected(v: bool) -> void:
	super.set_selected(v)
	if pid == game.human and def.has("trains"):
		if v and flag == null:
			flag = MeshInstance3D.new()
			flag.mesh = Models.mesh("rally", player().color)
			flag.top_level = true
			add_child(flag)
		if flag:
			flag.visible = v and rally != Vector2.INF
			_place_flag()


func _place_flag() -> void:
	if flag and rally != Vector2.INF:
		flag.global_position = Vector3(rally.x, game.height_at(rally.x, rally.y), rally.y)


func set_rally(p: Vector2, n = null) -> void:
	rally = p
	rally_node = n
	if flag:
		flag.visible = selected
		_place_flag()


func add_work(delta: float) -> void:
	if not complete:
		var inc: float = delta / float(def["time"])
		progress = minf(1.0, progress + inc)
		hp = minf(max_hp, hp + max_hp * inc * 0.95)
		_update_visual()
		if progress >= 1.0:
			complete = true
			game.on_building_complete(self)
	else:
		hp = minf(max_hp, hp + max_hp * delta / (float(def["time"]) * 3.0))


## Returns "" if the item can be queued, otherwise a reason.
func check(id: String) -> String:
	var p := player()
	if not complete:
		return "Under construction"
	if queue.size() >= 6:
		return "Queue is full"
	var cost: Dictionary
	if Defs.UNITS.has(id):
		var d: Dictionary = Defs.UNITS[id]
		if p.age < d["age"]:
			return "Requires " + Defs.AGE_NAMES[d["age"]]
		if d.has("limit") and game.count_units(pid, id, true) >= d["limit"]:
			return "Limit reached"
		cost = d["cost"]
	else:
		var t: Dictionary = Defs.TECHS[id]
		if p.techs.has(id):
			return "Already researched"
		if p.researching.has(id):
			return "Being researched"
		if p.age < t["age"]:
			return "Requires " + Defs.AGE_NAMES[t["age"]]
		if t.has("max_age") and p.age > t["max_age"]:
			return "Already reached"
		if (id == "age3") and p.researching.has("age2"):
			return "Requires Age of Steel"
		cost = t["cost"]
	if not p.can_afford(cost):
		return p.missing_text(cost)
	return ""


func enqueue(id: String) -> bool:
	if check(id) != "":
		return false
	var p := player()
	if Defs.UNITS.has(id):
		var d: Dictionary = Defs.UNITS[id]
		p.pay(d["cost"])
		queue.append({"id": id, "tech": false, "t": 0.0, "total": float(d["time"])})
	else:
		var t: Dictionary = Defs.TECHS[id]
		p.pay(t["cost"])
		p.researching[id] = true
		queue.append({"id": id, "tech": true, "t": 0.0, "total": float(t["time"])})
	return true


func cancel(i: int) -> void:
	if i < 0 or i >= queue.size():
		return
	var q: Dictionary = queue[i]
	var p := player()
	if q["tech"]:
		p.refund(Defs.TECHS[q["id"]]["cost"])
		p.researching.erase(q["id"])
	else:
		p.refund(Defs.UNITS[q["id"]]["cost"])
	queue.remove_at(i)


func queued_count(id: String) -> int:
	var n := 0
	for q in queue:
		if q["id"] == id:
			n += 1
	return n


func tick(delta: float) -> void:
	if not complete:
		return
	# burning when badly damaged
	if hp < max_hp * 0.5 and kind != "wall" and kind != "farm":
		if fire == null:
			fire = MeshInstance3D.new()
			fire.mesh = Models.mesh("fire")
			fire.position = Vector3(size * 0.15, height * 0.55, size * 0.1)
			fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(fire)
		flicker += delta * 9.0
		var s := 1.0 + sin(flicker) * 0.15 + (1.0 - hp / max_hp) * 0.8
		fire.scale = Vector3(s, s * (1.0 + sin(flicker * 1.7) * 0.2), s)
	elif fire:
		fire.queue_free()
		fire = null
	_production(delta)
	if def.get("atk", 0) > 0:
		_defend(delta)


func _production(delta: float) -> void:
	stalled = false
	if queue.is_empty():
		return
	var q: Dictionary = queue[0]
	var p := player()
	if not q["tech"]:
		var d: Dictionary = Defs.UNITS[q["id"]]
		if p.pop + int(d["pop"]) > mini(p.pop_cap, p.max_pop):
			stalled = true
			return
	q["t"] += delta
	if q["t"] >= q["total"]:
		queue.remove_at(0)
		if q["tech"]:
			game.finish_tech(pid, q["id"])
		else:
			_spawn(q["id"])


func _spawn(id: String) -> void:
	var toward := rally if rally != Vector2.INF else Vector2(game.size, game.size) * 0.5
	var dir := (toward - pos2()).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(0, 1)
	var sp := pos2() + dir * (size * 0.5 + 0.8)
	var u := game.spawn_unit(id, pid, sp)
	if u == null:
		return
	if rally_node != null and is_instance_valid(rally_node) and u.cls == "worker":
		if rally_node is ResourceNode and not rally_node.depleted:
			u.order_gather(rally_node)
			return
		if rally_node is Building and rally_node.kind == "farm" and rally_node.alive:
			u.order_gather(rally_node)
			return
	if rally != Vector2.INF:
		u.order_move(rally + Vector2(randf() - 0.5, randf() - 0.5) * 1.5)


func _defend(delta: float) -> void:
	cd -= delta
	scan_t -= delta
	var rng: float = def["range"] + player().mods["range"] + radius
	if target != null and (not is_instance_valid(target) or not target.alive or target.edge_dist(pos2()) > rng):
		target = null
	if target == null and scan_t <= 0.0:
		scan_t = 0.5
		target = game.find_enemy(pos2(), rng, pid, self)
	if target and cd <= 0.0:
		cd = def["cooldown"]
		var info := {"atk": def["atk"] + player().mods["pierce_atk"], "type": "pierce", "bonus": {},
			"splash": 0.0, "owner": pid, "src": self}
		game.spawn_projectile("arrow", position + Vector3.UP * height * 0.85, target, info)


func take_damage(amount: float, attacker: Entity) -> void:
	if not alive:
		return
	hp -= amount
	game.on_attacked(self, attacker)
	if hp <= 0.0:
		die(attacker)


func die(killer: Entity) -> void:
	if not alive:
		return
	alive = false
	for i in range(queue.size() - 1, -1, -1):
		if queue[i]["tech"]:
			player().researching.erase(queue[i]["id"])
	queue.clear()
	game.on_building_died(self, killer)
	if ring:
		ring.visible = false
	if flag:
		flag.visible = false
	game.spawn_fx("burst", position + Vector3.UP * 1.0, size * 0.6, Color.WHITE)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(model, "position:y", -height - 1.0, 2.5)
	tw.tween_property(model, "rotation:z", 0.15, 2.5)
	tw.chain().tween_callback(queue_free)
