class_name AreaEffect
extends Node3D
## Lingering ability effects on the ground: Banner of Kings, Meteor (delayed impact), Arcane Storm.

var game: Game
var kind := ""
var owner_id := 0
var radius := 3.0
var dur := 1.0
var val := 0.0
var src: Entity = null
var t := 0.0
var tick_t := 0.0
var visual: MeshInstance3D
var extra: MeshInstance3D


func setup(g: Game, k: String, p: Vector3, pid: int, r: float, d: float, v: float, s: Entity) -> void:
	game = g
	kind = k
	owner_id = pid
	radius = r
	dur = d
	val = v
	src = s
	position = p
	visual = MeshInstance3D.new()
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	match k:
		"banner":
			visual.mesh = Models.mesh("banner", g.players[pid].color)
			extra = MeshInstance3D.new()
			extra.mesh = Models.mesh("area_ring", Color(1.0, 0.85, 0.3))
			extra.scale = Vector3(radius, 1, radius)
			extra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(extra)
		"meteor":
			visual.mesh = Models.mesh("meteor")
			visual.position = Vector3(-6, 28, -6)
			extra = MeshInstance3D.new()
			extra.mesh = Models.mesh("area_ring", Color(1.0, 0.4, 0.1))
			extra.scale = Vector3(radius, 1, radius)
			extra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(extra)
		"storm":
			visual.mesh = Models.mesh("storm")
			visual.scale = Vector3(radius / 6.0, 1, radius / 6.0)
			extra = MeshInstance3D.new()
			extra.mesh = Models.mesh("area_ring", Color(0.7, 0.45, 1.0))
			extra.scale = Vector3(radius, 1, radius)
			extra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(extra)


func _src() -> Entity:
	return src if src != null and is_instance_valid(src) else null


func tick(delta: float) -> bool:
	t += delta
	tick_t -= delta
	var p2 := Vector2(position.x, position.z)
	match kind:
		"meteor":
			var k := clampf(t / dur, 0.0, 1.0)
			visual.position = Vector3(-6, 28, -6).lerp(Vector3(0, 0.5, 0), k * k)
			visual.rotation.x += delta * 6.0
			if t >= dur:
				var info := {"atk": val, "type": "magic", "bonus": {"building": val}, "splash": 0.0, "owner": owner_id, "src": _src(), "ability": true}
				for e in game.area_targets(p2, radius, owner_id):
					game.apply_damage(e, info)
				game.spawn_fx("burst", position + Vector3.UP * 0.5, radius, Color.WHITE)
				return false
		"banner":
			if tick_t <= 0.0:
				tick_t = 0.5
				for u in game.allies_near(p2, radius, owner_id):
					u.hp = minf(u.max_hp, u.hp + val * 0.5)
					u.armor_buff = 3.0
					u.armor_buff_t = 0.7
			extra.rotation.y += delta * 0.5
		"storm":
			visual.rotation.y += delta * 3.0
			if tick_t <= 0.0:
				tick_t = 0.5
				var info := {"atk": val * 0.5, "type": "magic", "bonus": {}, "splash": 0.0, "owner": owner_id, "src": _src(), "ability": true}
				for e in game.area_targets(p2, radius, owner_id):
					game.apply_damage(e, info)
				var off := Vector2.from_angle(randf() * TAU) * randf() * radius
				game.spawn_fx("bolt", position + Vector3(off.x, 0, off.y), 1.0, Color.WHITE)
	if t >= dur:
		return false
	if dur - t < 1.0:
		var f := maxf(0.01, dur - t)
		visual.scale.y = f
	return true
