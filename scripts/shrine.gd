class_name Shrine
extends Node3D
## Ley shrine: a capturable strategic point that generates mana (inspired by strategic points).

const CAPTURE_TIME := 10.0
const RADIUS := 4.0
const MANA_RATE := 0.6

var game: Game
var owner_id := -1
var capturer := -1
var capture := 0.0
var tick_t := 0.0
var crystal: MeshInstance3D
var flags: MeshInstance3D
var spin := 0.0
var contested := false
var seen := true


func setup(g: Game) -> void:
	game = g
	var base := MeshInstance3D.new()
	base.mesh = Models.mesh("shrine")
	add_child(base)
	crystal = MeshInstance3D.new()
	crystal.position.y = 2.2
	add_child(crystal)
	_refresh()


func pos2() -> Vector2:
	return Vector2(position.x, position.z)


func display_name() -> String:
	if owner_id < 0:
		return "Ley Shrine (unclaimed)"
	return "Ley Shrine (%s)" % game.players[owner_id].name


func edge_dist(p: Vector2) -> float:
	return p.distance_to(pos2()) - 2.4


func _refresh() -> void:
	var col := Color(0.4, 0.95, 1.0, 0.2)
	if owner_id >= 0:
		var pc: Color = game.players[owner_id].color
		col = Color(pc.r, pc.g, pc.b, 0.15)
	crystal.mesh = Models.mesh("shrine_crystal", col)
	if flags:
		flags.queue_free()
		flags = null
	if owner_id >= 0:
		flags = MeshInstance3D.new()
		flags.mesh = Models.mesh("shrine_flags", game.players[owner_id].color)
		add_child(flags)


func tick(delta: float) -> void:
	spin += delta
	crystal.rotation.y = spin * 1.2
	crystal.position.y = 2.2 + sin(spin * 2.0) * 0.2
	if owner_id >= 0:
		var p: PlayerData = game.players[owner_id]
		p.res["mana"] += MANA_RATE * delta
		p.stats["gathered"] += MANA_RATE * delta
	tick_t -= delta
	if tick_t > 0.0:
		return
	var dt := 0.25 - tick_t
	tick_t = 0.25
	var teams := {}
	var first_pid := -1
	for u in game.units_near(pos2(), RADIUS + 1.0):
		if u.pid == 0 or u.flying or u.pos2().distance_to(pos2()) > RADIUS:
			continue
		var t: int = game.players[u.pid].team
		teams[t] = true
		if first_pid < 0 or u.pid == owner_id or u.pid == capturer:
			first_pid = u.pid
	contested = teams.size() > 1
	if teams.size() != 1:
		return
	var team: int = teams.keys()[0]
	var rate := dt / CAPTURE_TIME
	if owner_id >= 0:
		if game.players[owner_id].team == team:
			capture = minf(1.0, capture + rate)
		else:
			capture -= rate
			if capture <= 0.0:
				var old := owner_id
				owner_id = -1
				capture = 0.0
				capturer = first_pid
				_refresh()
				game.on_shrine_lost(self, old)
	else:
		if capturer >= 0 and game.players[capturer].team != team:
			capture -= rate
			if capture <= 0.0:
				capture = 0.0
				capturer = first_pid
		else:
			capturer = first_pid
			capture += rate
			if capture >= 1.0:
				capture = 1.0
				owner_id = capturer
				_refresh()
				game.on_shrine_captured(self)
