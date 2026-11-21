class_name Entity
extends Node3D
## Base for anything with an owner and hit points (units and buildings).

var game: Game
var pid := 0
var kind := ""
var def: Dictionary = {}
var hp := 1.0
var max_hp := 1.0
var alive := true
var radius := 0.5
var is_building := false
var cls := ""
var flying := false
var height := 1.5
var selected := false
var ring: MeshInstance3D
var seen := true  # visible to the local player (fog of war)


func pos2() -> Vector2:
	return Vector2(position.x, position.z)


func player() -> PlayerData:
	return game.players[pid]


func display_name() -> String:
	return def.get("name", kind)


func set_selected(v: bool) -> void:
	selected = v
	if v and ring == null:
		ring = MeshInstance3D.new()
		var col := Color(0.3, 1.0, 0.35)
		if pid != game.human:
			col = Color(1.0, 0.3, 0.25) if game.is_enemy(game.human, pid) else Color(1, 1, 0.4)
		var r: float = radius + 0.25 if not is_building else def["size"] * 0.62
		ring.mesh = Models.ring_mesh(r, col)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.position.y = 0.08 - (position.y - game.height_at(position.x, position.z)) if flying else 0.08
		add_child(ring)
	if ring:
		ring.visible = v


func armor_val() -> float:
	return def.get("armor", 0)


func parmor_val() -> float:
	return def.get("parmor", 0)


func take_damage(_amount: float, _attacker: Entity) -> void:
	pass


func aim_point() -> Vector3:
	return position + Vector3.UP * height * 0.6


## Distance from a point to this entity's edge.
func edge_dist(p: Vector2) -> float:
	return p.distance_to(pos2()) - radius
