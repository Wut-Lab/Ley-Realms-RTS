class_name Unit
extends Entity
## Mobile unit: movement, combat, gathering, construction.

enum { IDLE, MOVE, ATTACK, GATHER, RETURN, BUILD, AMOVE, GARRISON }

var state := IDLE
var path := PackedVector2Array()
var path_i := 0
var goal := Vector2.ZERO
var target: Entity = null
var explicit_target := false
var resume_amove := false
var chase_origin := Vector2.ZERO
var node = null  # ResourceNode or farm Building
var gtype := ""
var carry_type := ""
var carry := 0.0
var dropoff: Building = null
var btarget: Building = null
var hold := false
var cd := 0.0
var scan_t := 0.0
var repath_t := 0.0
var target_last := Vector2.INF
var home := Vector2.ZERO
var speed := 3.5
var fly_h := 0.0
var anim := 0.0
var work := 0.0
var lunge := 0.0
var moving := false
var body: Node3D
var mesh_i: MeshInstance3D
var carry_i: MeshInstance3D
var stuck_t := 0.0
var last_p := Vector2.ZERO
var idle_time := 0.0
var sep_phase := randi() % 2
var garrison_in: Building = null
var gtarget: Building = null
var pre_node = null
var gate_t := 0.0
var recruit_group := -1
var recruit_mark: MeshInstance3D
# status effects (champion abilities)
var stun_t := 0.0
var slow_t := 0.0
var rally_t := 0.0
var rally_mult := 1.0
var ward := 0.0
var ward_t := 0.0
var dr := 0.0
var dr_t := 0.0
var invuln_t := 0.0
var armor_buff := 0.0
var armor_buff_t := 0.0
var status_i: MeshInstance3D
var status_key := ""
var status_check := 0.0
var aura_t := 0.0
var aura_atk := 0.0
var aura_regen := 0.0
var aura_dr := 0.0


func setup(g: Game, k: String, owner_id: int) -> void:
	game = g
	kind = k
	pid = owner_id
	def = g.unit_def(owner_id, k)
	cls = def["cls"]
	radius = def["radius"]
	height = def["height"] * def.get("scale", 1.3)
	flying = def.get("flying", false)
	speed = def["speed"]
	max_hp = def["hp"]
	if k == "knight":
		max_hp += player().mods["knight_hp"]
	max_hp *= player().mods["hp_mult"]
	hp = max_hp
	fly_h = 4.2 if flying else 0.0
	body = Node3D.new()
	body.scale = Vector3.ONE * def.get("scale", 1.3)
	add_child(body)
	mesh_i = MeshInstance3D.new()
	mesh_i.mesh = Models.mesh(def["model"], player().color, int(def.get("tier", 0)))
	body.add_child(mesh_i)
	if cls == "worker":
		carry_i = MeshInstance3D.new()
		carry_i.position = Vector3(0, 0.95, -0.22)
		carry_i.visible = false
		body.add_child(carry_i)
	scan_t = randf() * 0.5
	anim = randf() * 10.0


# ---------------------------------------------------------------- stats
func atk_val() -> float:
	var a: float = def["atk"]
	var m: Dictionary = player().mods
	match def["atk_type"]:
		"melee": a += m["melee_atk"]
		"pierce": a += m["pierce_atk"]
		"magic": a *= m["magic"]
	if rally_t > 0.0:
		a *= rally_mult
	a *= m["atk_mult"]
	match cls:
		"infantry": a *= m["inf_mult"]
		"ranged": a *= m["ranged_mult"]
		"cavalry", "flying": a *= m["cav_mult"]
	if aura_t > 0.0:
		a *= 1.0 + aura_atk
	return a


func range_val() -> float:
	var r: float = def["range"]
	if def["atk_type"] == "pierce":
		r += player().mods["range"]
	elif cls == "ranged":
		r += player().mods["ranged_range"]
	return r


func armor_val() -> float:
	return def["armor"] + player().mods["armor"] + (armor_buff if armor_buff_t > 0.0 else 0.0)


func parmor_val() -> float:
	return def["parmor"] + player().mods["parmor"] + (armor_buff if armor_buff_t > 0.0 else 0.0)


func cur_speed() -> float:
	var s: float = speed * player().mods["speed_mult"]
	if cls == "cavalry" or cls == "flying":
		s *= player().mods["cav_speed"]
	if slow_t > 0.0:
		s *= 0.5
	if rally_t > 0.0:
		s *= 1.2
	return s


func _tick_status(delta: float) -> void:
	stun_t = maxf(0.0, stun_t - delta)
	slow_t = maxf(0.0, slow_t - delta)
	rally_t = maxf(0.0, rally_t - delta)
	ward_t = maxf(0.0, ward_t - delta)
	if ward_t <= 0.0:
		ward = 0.0
	dr_t = maxf(0.0, dr_t - delta)
	invuln_t = maxf(0.0, invuln_t - delta)
	armor_buff_t = maxf(0.0, armor_buff_t - delta)
	aura_t = maxf(0.0, aura_t - delta)
	status_check -= delta
	if status_check > 0.0:
		return
	status_check = 0.2
	var k := ""
	if stun_t > 0.0:
		k = "fx_stun"
	elif invuln_t > 0.0:
		k = "fx_holy"
	elif ward > 0.0:
		k = "fx_ward"
	elif dr_t > 0.0:
		k = "fx_iron"
	elif slow_t > 0.0:
		k = "fx_frost"
	elif rally_t > 0.0 or armor_buff_t > 0.0:
		k = "fx_rally"
	if k == status_key:
		return
	status_key = k
	if k == "":
		if status_i:
			status_i.visible = false
		return
	if status_i == null:
		status_i = MeshInstance3D.new()
		status_i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(status_i)
	status_i.mesh = Models.mesh(k)
	status_i.visible = true
	var s := maxf(radius * 1.8, 0.8)
	status_i.scale = Vector3(s, 1.0, s)
	status_i.position.y = 0.0 if not flying else -fly_h + 0.1
	if k == "fx_stun":
		status_i.scale = Vector3.ONE
		status_i.position.y = height + 0.2


func sight() -> float:
	return def["sight"]


func is_military() -> bool:
	return cls != "worker" and (def["atk"] > 0 or def.has("heal"))


func can_hit(e: Entity) -> bool:
	if e == null or not e.alive:
		return false
	if def.get("no_air", false) and e.flying:
		return false
	if e.flying and not flying and range_val() < 2.0 and not def.get("anti_air", false):
		return false
	return true


# ---------------------------------------------------------------- orders
func _clear() -> void:
	if not is_instance_valid(node):
		node = null
	if node is Building and node.farmer == self:
		node.farmer = null
	target = null
	explicit_target = false
	resume_amove = false
	path = PackedVector2Array()
	path_i = 0
	hold = false
	idle_time = 0.0


func order_move(p: Vector2, amove: bool = false) -> void:
	_clear()
	goal = p
	_set_path(p)
	state = AMOVE if amove else MOVE


func order_attack(e: Entity) -> void:
	_clear()
	if def.has("heal"):
		if e.pid == pid or not game.is_enemy(pid, e.pid):
			target = e
			state = ATTACK
		return
	if not can_hit(e):
		order_move(e.pos2())
		return
	target = e
	explicit_target = true
	state = ATTACK


func order_gather(n) -> void:
	_clear()
	if n is Building:
		if n.farmer != null and is_instance_valid(n.farmer) and n.farmer != self and n.farmer.alive and n.farmer.node == n:
			var other = game.free_farm_near(n.pos2(), pid, 12.0)
			if other == null:
				order_move(n.pos2())
				return
			n = other
		n.farmer = self
		gtype = "food"
	else:
		gtype = n.rtype
	node = n
	state = GATHER


func order_build(b: Building) -> void:
	_clear()
	btarget = b
	state = BUILD


func order_return(b: Building) -> void:
	_clear()
	dropoff = b
	state = RETURN


func order_stop() -> void:
	_clear()
	state = IDLE


func order_garrison(b: Building) -> void:
	if node != null and is_instance_valid(node):
		pre_node = node
	_clear()
	gtarget = b
	state = GARRISON


func _garrison_tick(delta: float) -> void:
	if gtarget == null or not is_instance_valid(gtarget) or not gtarget.alive or gtarget.garrison.size() >= gtarget.capacity():
		gtarget = null
		state = IDLE
		return
	if gtarget.edge_dist(pos2()) <= 1.0 + radius:
		var b := gtarget
		gtarget = null
		if not game.enter_garrison(self, b):
			state = IDLE
	else:
		_chase(gtarget.pos2(), delta)


## Swap in an upgraded definition (unit upgrade lines), keeping the same share of health.
func set_def(nd: Dictionary) -> void:
	var frac := hp / max_hp if max_hp > 0.0 else 1.0
	def = nd
	max_hp = def["hp"]
	if kind == "knight":
		max_hp += player().mods["knight_hp"]
	max_hp *= player().mods["hp_mult"]
	hp = max_hp * frac
	speed = def["speed"]
	mesh_i.mesh = Models.mesh(def["model"], player().color, int(def.get("tier", 0)))


## Neutral freeblade waiting to be claimed by the first player who reaches it.
func make_recruit(gid: int) -> void:
	recruit_group = gid
	state = IDLE
	if recruit_mark == null:
		recruit_mark = MeshInstance3D.new()
		recruit_mark.mesh = Models.mesh("recruit_mark")
		recruit_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		recruit_mark.scale = Vector3.ONE * maxf(radius * 2.0, 0.9)
		recruit_mark.position.y = -fly_h if flying else 0.0
		add_child(recruit_mark)
	game.register_recruit(self, gid)


## Changes hands (freeblades joining a player).
func change_owner(new_pid: int) -> void:
	pid = new_pid
	recruit_group = -1
	if recruit_mark:
		recruit_mark.queue_free()
		recruit_mark = null
	def = game.unit_def(pid, kind)
	mesh_i.mesh = Models.mesh(def["model"], player().color, int(def.get("tier", 0)))
	if ring:
		ring.queue_free()
		ring = null
	selected = false
	home = pos2()
	_clear()
	state = IDLE
	visible = true


func order_hold() -> void:
	_clear()
	state = IDLE
	hold = true


# ---------------------------------------------------------------- tick
func tick(delta: float) -> void:
	_tick_status(delta)
	if stun_t > 0.0:
		_animate(delta)
		return
	cd -= delta
	scan_t -= delta
	repath_t -= delta
	moving = false
	if hp < max_hp and pid > 0:
		var rg: float = def.get("regen", 0.0) + player().mods["regen"] + (aura_regen if aura_t > 0.0 else 0.0)
		if rg > 0.0:
			hp = minf(max_hp, hp + rg * delta)
	elif def.has("regen") and hp < max_hp:
		hp = minf(max_hp, hp + def["regen"] * delta)
	match state:
		IDLE: _idle(delta)
		MOVE:
			if _step(delta):
				state = IDLE
		AMOVE:
			if scan_t <= 0.0:
				scan_t = 0.4
				var e := _scan()
				if e:
					_auto_attack(e, true)
					return
			if _step(delta):
				state = IDLE
		ATTACK: _attack(delta)
		GATHER: _gather(delta)
		RETURN: _return(delta)
		BUILD: _build(delta)
		GARRISON: _garrison_tick(delta)
	if not flying and (Engine.get_process_frames() + sep_phase) % 2 == 0:
		_separate(delta * 2.0)
	_animate(delta)


func _idle(delta: float) -> void:
	idle_time += delta
	if recruit_group >= 0:
		return
	if scan_t > 0.0:
		return
	scan_t = 0.5
	if cls == "worker":
		return
	if def.has("heal"):
		var w := game.wounded_ally_near(pos2(), sight(), pid, self)
		if w:
			target = w
			state = ATTACK
			chase_origin = pos2()
		return
	var e := _scan()
	if e:
		_auto_attack(e, false)
	elif cls == "monster" and pos2().distance_to(home) > 3.0:
		_set_path(home)
		state = MOVE


func _scan() -> Entity:
	if def["atk"] <= 0:
		return null
	var r := sight()
	if cls == "monster":
		r = 6.0
		if pos2().distance_to(home) > 14.0:
			return null
	if hold:
		r = range_val() + radius + 0.5
	return game.find_enemy(pos2(), r, pid, self)


func _auto_attack(e: Entity, from_amove: bool) -> void:
	target = e
	explicit_target = false
	resume_amove = from_amove
	chase_origin = pos2()
	state = ATTACK
	path = PackedVector2Array()


func _end_attack() -> void:
	target = null
	path = PackedVector2Array()
	if resume_amove:
		state = AMOVE
		_set_path(goal)
	else:
		state = IDLE
	resume_amove = false


func _attack(delta: float) -> void:
	var heal := def.has("heal")
	if target == null or not is_instance_valid(target) or not target.alive or (target is Unit and target.garrison_in != null):
		_end_attack()
		return
	if heal:
		if target.hp >= target.max_hp:
			_end_attack()
			return
	elif not game.is_enemy(pid, target.pid) or not can_hit(target) or (not target.seen and pid == game.human and not explicit_target):
		_end_attack()
		return
	# switch from buildings to nearby units when fighting automatically
	if not heal and target.is_building and not explicit_target and scan_t <= 0.0:
		scan_t = 0.6
		var e := game.find_enemy(pos2(), sight(), pid, self, true)
		if e:
			target = e
	var reach := range_val() + radius
	var d := target.edge_dist(pos2())
	if d <= reach:
		path = PackedVector2Array()
		_face(target.pos2() - pos2())
		if cd <= 0.0:
			cd = def["cooldown"]
			_perform_attack()
	else:
		if hold:
			_end_attack()
			return
		var leash := maxf(sight() * 1.8, 14.0)
		if cls == "monster":
			if pos2().distance_to(home) > 16.0:
				target = null
				_set_path(home)
				state = MOVE
				return
		elif not explicit_target and pos2().distance_to(chase_origin) > leash:
			_end_attack()
			return
		_chase(target.pos2(), delta)


func _perform_attack() -> void:
	lunge = 1.0
	if def.has("heal"):
		var amt: float = def["heal"] * player().mods["magic"]
		target.hp = minf(target.max_hp, target.hp + amt)
		game.spawn_fx("heal_fx", target.position + Vector3.UP * 0.3, 0.6, Color.WHITE)
		Sfx.play_at("heal", position, -12.0)
		return
	var info := {
		"atk": atk_val(), "type": def["atk_type"], "bonus": def.get("bonus", {}),
		"splash": def.get("splash", 0.0), "owner": pid, "src": self,
	}
	var proj: String = def.get("projectile", "")
	if proj != "":
		var from := position + Vector3.UP * height * 0.75
		if flying:
			from = position + Vector3.UP * 0.6 + basis.z * 2.0
		game.spawn_projectile(proj, from, target, info)
		match proj:
			"arrow": Sfx.play_at("bow", position, -6.0)
			"fireball": Sfx.play_at("fire_cast", position, -8.0)
			"boulder": Sfx.play_at("catapult", position, -2.0)
			"holy": Sfx.play_at("cast", position, -10.0)
			"flame":
				if randf() < 0.35:
					Sfx.play_at("roar", position, -3.0)
				Sfx.play_at("fire_cast", position, -5.0)
	else:
		game.apply_damage(target, info)
		Sfx.play_at("hit" if cls in ["monster", "worker"] else "sword", position, -4.0)


func _gather(delta: float) -> void:
	if carry >= Defs.CARRY_CAP:
		_go_return()
		return
	var valid: bool = node != null and is_instance_valid(node)
	if valid:
		if node is Building:
			valid = node.alive and node.complete
			if valid and node.farmer != self:
				if node.farmer == null or not is_instance_valid(node.farmer) or node.farmer.node != node:
					node.farmer = self
				else:
					valid = false
		else:
			valid = not node.depleted
	if not valid:
		var nn = null
		if gtype == "food":
			nn = game.find_resource(pos2(), "food", 14.0)
			if nn == null:
				nn = game.free_farm_near(pos2(), pid, 16.0)
		else:
			nn = game.find_resource(pos2(), gtype, 14.0)
		if nn == null:
			node = null
			if carry > 0:
				_go_return()
			else:
				state = IDLE
			return
		if nn is Building:
			nn.farmer = self
		node = nn
	if carry > 0 and carry_type != gtype:
		carry = 0.0
	var reach := 0.65 + radius
	var d: float
	if node is Building:
		d = pos2().distance_to(node.pos2()) - 0.9
	else:
		d = node.edge_dist(pos2())
	if d <= reach:
		path = PackedVector2Array()
		_face(node.pos2() - pos2())
		work += delta
		var p := player()
		var key: String = "farm" if node is Building else node.kind
		var rate: float = Defs.GATHER_RATE[key] * p.gather_mult * p.mods[gtype]
		var amt := rate * delta
		if node is Building:
			carry += amt
		else:
			carry += node.take(amt)
		_work_sound(delta, {"tree": "chop", "gold_mine": "mine", "mana_crystal": "mana"}.get(key, ""))
		carry_type = gtype
		_update_carry()
	else:
		_chase(node.pos2(), delta)


func _go_return() -> void:
	dropoff = game.nearest_dropoff(pos2(), pid)
	if dropoff == null:
		state = IDLE
		return
	path = PackedVector2Array()
	state = RETURN


func _return(delta: float) -> void:
	if dropoff == null or not is_instance_valid(dropoff) or not dropoff.alive or not dropoff.complete:
		dropoff = game.nearest_dropoff(pos2(), pid)
		if dropoff == null:
			state = IDLE
			return
	if dropoff.edge_dist(pos2()) <= 0.8 + radius:
		if carry > 0 and carry_type != "":
			var p := player()
			p.res[carry_type] += carry
			p.stats["gathered"] += carry
		carry = 0.0
		_update_carry()
		path = PackedVector2Array()
		if gtype != "":
			state = GATHER
		else:
			state = IDLE
	else:
		_chase(dropoff.pos2(), delta)


func _build(delta: float) -> void:
	if btarget == null or not is_instance_valid(btarget) or not btarget.alive:
		var nb := game.unfinished_near(pos2(), pid, 12.0)
		if nb:
			btarget = nb
		else:
			state = IDLE
			return
	if btarget.complete and btarget.hp >= btarget.max_hp:
		if btarget.kind == "farm" and (btarget.farmer == null or not is_instance_valid(btarget.farmer)):
			order_gather(btarget)
			return
		var nb := game.unfinished_near(pos2(), pid, 12.0)
		if nb:
			btarget = nb
		else:
			# go back to the previous job
			if gtype != "":
				var nn = null
				if node != null and is_instance_valid(node) and not (node is Building) and not node.depleted:
					nn = node
				elif gtype == "food":
					nn = game.free_farm_near(pos2(), pid, 16.0)
					if nn == null:
						nn = game.find_resource(pos2(), "food", 20.0)
				else:
					nn = game.find_resource(pos2(), gtype, 20.0)
				if nn:
					order_gather(nn)
					return
			state = IDLE
		return
	if btarget.edge_dist(pos2()) <= 0.9 + radius:
		path = PackedVector2Array()
		_face(btarget.pos2() - pos2())
		work += delta
		btarget.add_work(delta)
		_work_sound(delta, "hammer")
	else:
		_chase(btarget.pos2(), delta)


# ---------------------------------------------------------------- movement
func _set_path(p: Vector2) -> void:
	if flying:
		path = PackedVector2Array([p])
	else:
		path = game.find_path(pos2(), p)
	path_i = 0
	stuck_t = 0.0


func _chase(tp: Vector2, delta: float) -> void:
	var moved := tp.distance_to(target_last)
	if path_i >= path.size() and moved < 0.5:
		# reached the end of the path but not in range yet: step straight toward the target,
		# and only search again if we've been blocked for a while
		var before := pos2()
		_move_dir((tp - before).normalized(), delta)
		if pos2().distance_to(before) < cur_speed() * delta * 0.3:
			stuck_t += delta
			if stuck_t > 1.5:
				stuck_t = 0.0
				target_last = Vector2.INF
		return
	if path_i >= path.size() or (repath_t <= 0.0 and moved > 1.5):
		_set_path(tp)
		target_last = tp
		repath_t = 0.8 + randf() * 0.4
	_step(delta)


func _step(delta: float) -> bool:
	if path_i >= path.size():
		return true
	var p := pos2()
	var wp := path[path_i]
	var d := wp - p
	var dist := d.length()
	var step := cur_speed() * delta
	if dist <= maxf(step, 0.2):
		path_i += 1
		if path_i >= path.size():
			_set_pos(wp)
			return true
		return false
	_move_dir(d / dist, delta)
	# stuck detection
	stuck_t += delta
	if stuck_t > 1.0:
		if p.distance_to(last_p) < 0.3:
			if not flying:
				path = game.find_path(p, path[path.size() - 1])
				path_i = 0
		last_p = p
		stuck_t = 0.0
	return false


func _move_dir(dir: Vector2, delta: float) -> void:
	var np := pos2() + dir * cur_speed() * delta
	if flying or game.walkable_world(np) or not game.walkable_world(pos2()):
		_set_pos(np)
	else:
		# slide along obstacles
		var nx := pos2() + Vector2(dir.x, 0) * cur_speed() * delta
		var nz := pos2() + Vector2(0, dir.y) * cur_speed() * delta
		if game.walkable_world(nx):
			_set_pos(nx)
		elif game.walkable_world(nz):
			_set_pos(nz)
	_face(dir)
	moving = true


func _set_pos(p: Vector2) -> void:
	p.x = clampf(p.x, 0.5, game.size - 0.5)
	p.y = clampf(p.y, 0.5, game.size - 0.5)
	if not flying and not game.gate_cells.is_empty():
		var g := game.gate_blocks(p, pid)
		if g != null:
			_blocked_by_gate(g)
			return
	position.x = p.x
	position.z = p.y


## An enemy gate is in the way: soldiers and beasts break it down, others stop.
func _blocked_by_gate(g: Building) -> void:
	if state == ATTACK and target == g:
		return
	if def["atk"] > 0 and cls != "worker" and can_hit(g):
		var was_amove := state == AMOVE or (state == ATTACK and resume_amove)
		var keep_goal := goal
		_auto_attack(g, was_amove or state == MOVE)
		goal = keep_goal
		chase_origin = pos2()
	else:
		path = PackedVector2Array()
		state = IDLE


func _face(dir: Vector2) -> void:
	if dir.length_squared() < 0.0001:
		return
	var a := atan2(dir.x, dir.y)
	rotation.y = lerp_angle(rotation.y, a, 0.25)


func _separate(delta: float) -> void:
	var push := Vector2.ZERO
	var p := pos2()
	for o in game.units_near(p, radius + 1.2):
		if o == self or o.flying:
			continue
		var d: Vector2 = p - o.pos2()
		var l := d.length()
		var md: float = radius + o.radius
		if l < md:
			if l < 0.001:
				push += Vector2(randf() - 0.5, randf() - 0.5) * 0.2
			else:
				var w := 0.5 if (moving and o.state != IDLE) else 1.0
				push += d / l * (md - l) * w
	if push != Vector2.ZERO:
		var np := p + push * minf(1.0, delta * 6.0)
		if game.walkable_world(np):
			_set_pos(np)


func _animate(delta: float) -> void:
	var gh := game.height_at(position.x, position.z)
	if flying:
		anim += delta
		position.y = lerpf(position.y, gh + fly_h, 0.1) if position.y > 0.01 else gh + fly_h
		body.position.y = sin(anim * 2.5) * 0.25
		body.rotation.z = sin(anim * 1.3) * 0.06
	else:
		position.y = gh
		if moving:
			anim += delta * speed * 2.6
			body.position.y = absf(sin(anim)) * 0.09
			body.rotation.x = 0.0
		elif state in [GATHER, BUILD] and work > 0.0 and path_i >= path.size():
			body.position.y = 0.0
			body.rotation.x = sin(work * 9.0) * 0.18
		else:
			body.position.y = lerpf(body.position.y, 0.0, 0.2)
			body.rotation.x = lerpf(body.rotation.x, 0.0, 0.2)
	if lunge > 0.0:
		lunge = maxf(0.0, lunge - delta * 4.0)
		body.position.z = sin(lunge * PI) * 0.25
	else:
		body.position.z = 0.0


var work_snd_t := randf()


func _work_sound(delta: float, snd: String) -> void:
	if snd == "":
		return
	work_snd_t -= delta
	if work_snd_t <= 0.0:
		work_snd_t = 0.9 + randf() * 0.3
		Sfx.play_at(snd, position, -10.0 if snd == "mana" else -7.0)


func _update_carry() -> void:
	if carry_i == null:
		return
	if carry > 0.5 and carry_type != "":
		carry_i.mesh = Models.mesh("carry_" + carry_type)
		carry_i.visible = true
	else:
		carry_i.visible = false


# ---------------------------------------------------------------- damage
func take_damage(amount: float, attacker: Entity) -> void:
	if not alive:
		return
	if invuln_t > 0.0:
		return
	if dr_t > 0.0:
		amount *= 1.0 - dr
	if aura_t > 0.0 and aura_dr > 0.0:
		amount *= 1.0 - aura_dr
	if ward > 0.0:
		var absorbed := minf(ward, amount)
		ward -= absorbed
		amount -= absorbed
		if amount <= 0.0:
			return
	hp -= amount
	game.on_attacked(self, attacker)
	if hp <= 0.0:
		die(attacker)
		return
	if attacker and is_instance_valid(attacker) and attacker.alive and not attacker.is_building:
		if state == IDLE and is_military() and not def.has("heal") and can_hit(attacker) and not hold:
			_auto_attack(attacker, false)
		elif cls == "monster" and state != ATTACK and can_hit(attacker):
			_auto_attack(attacker, false)


func die(killer: Entity) -> void:
	if not alive:
		return
	alive = false
	if node != null and is_instance_valid(node) and node is Building and node.farmer == self:
		node.farmer = null
	game.on_unit_died(self, killer)
	Sfx.play_at("death", position, -5.0)
	if ring:
		ring.visible = false
	var tw := create_tween()
	tw.tween_property(body, "rotation:x", -PI / 2, 0.4)
	tw.tween_property(self, "position:y", position.y - 1.5, 2.0)
	tw.tween_callback(queue_free)
