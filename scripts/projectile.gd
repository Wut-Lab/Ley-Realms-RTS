class_name Projectile
extends Node3D
## Arrow / fireball / boulder / dragon flame travelling to a target.

var game: Game
var target: Entity
var tpos := Vector3.ZERO
var start := Vector3.ZERO
var info := {}
var t := 0.0
var dur := 0.5
var arc := 0.0
var kind := ""
var last := Vector3.ZERO


func setup(g: Game, k: String, from: Vector3, tgt: Entity, inf: Dictionary) -> void:
	game = g
	kind = k
	start = from
	target = tgt
	info = inf
	tpos = tgt.aim_point()
	var dist := from.distance_to(tpos)
	var speed := 22.0
	match k:
		"arrow":
			speed = 24.0
			arc = dist * 0.12
		"fireball":
			speed = 15.0
			arc = dist * 0.06
		"boulder":
			speed = 13.0
			arc = dist * 0.32
		"flame":
			speed = 16.0
			arc = 0.0
	dur = maxf(0.08, dist / speed)
	var m := MeshInstance3D.new()
	m.mesh = Models.mesh(k)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	position = from
	last = from


func tick(delta: float) -> void:
	t += delta
	if target != null and is_instance_valid(target) and target.alive:
		tpos = target.aim_point()
	var k := minf(1.0, t / dur)
	var p := start.lerp(tpos, k) + Vector3.UP * arc * 4.0 * k * (1.0 - k)
	position = p
	var dir := p - last
	if dir.length_squared() > 0.000001:
		look_at(p - dir, Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.RIGHT)
	last = p
	if kind == "flame" or kind == "fireball":
		var s := 1.0 + sin(t * 30.0) * 0.15
		scale = Vector3(s, s, s)
	if k >= 1.0:
		_hit()


func _hit() -> void:
	var splash: float = info.get("splash", 0.0)
	match kind:
		"arrow": Sfx.play_at("arrow_hit", tpos, -8.0)
		"boulder": Sfx.play_at("explosion", tpos, -2.0)
		"fireball", "flame": Sfx.play_at("explosion", tpos, -9.0)
	if splash > 0.0:
		game.splash_damage(tpos, splash, info, target)
		game.spawn_fx("burst", tpos, splash * 0.7, Color.WHITE)
	elif target != null and is_instance_valid(target) and target.alive:
		game.apply_damage(target, info)
	game.remove_projectile(self)
