class_name ResourceNode
extends Node3D
## A gatherable resource: tree, berry bush, gold mine or mana crystal.

var game: Game
var kind := ""
var rtype := ""
var amount := 100.0
var max_amount := 100.0
var radius := 0.5
var rcells := 0
var depleted := false
var mm: MultiMesh = null
var mm_index := -1
var mesh_i: MeshInstance3D
var cells := Rect2i()
var model_key := ""
var seen := true


func setup(g: Game, k: String, mult: float) -> void:
	game = g
	kind = k
	rtype = Defs.RESOURCE_TYPE[k]
	max_amount = Defs.RESOURCE_AMOUNT[k] * mult
	amount = max_amount
	radius = Defs.RESOURCE_RADIUS[k]
	rcells = Defs.RESOURCE_CELLS[k]


func pos2() -> Vector2:
	return Vector2(position.x, position.z)


func display_name() -> String:
	return Defs.RESOURCE_NAMES[kind]


func edge_dist(p: Vector2) -> float:
	return p.distance_to(pos2()) - radius


func take(x: float) -> float:
	if depleted:
		return 0.0
	var t := minf(x, amount)
	amount -= t
	if amount <= 0.0:
		deplete()
	elif mesh_i and kind != "tree":
		var s := 0.55 + 0.45 * amount / max_amount
		mesh_i.scale = Vector3(s, s, s)
	return t


func deplete() -> void:
	if depleted:
		return
	depleted = true
	game.remove_resource(self)
	if mm and mm_index >= 0:
		var t := mm.get_instance_transform(mm_index)
		mm.set_instance_transform(mm_index, Transform3D(Basis.from_scale(Vector3(0.001, 0.001, 0.001)), t.origin))
		queue_free()
	elif mesh_i:
		var tw := create_tween()
		tw.tween_property(mesh_i, "scale", Vector3(0.01, 0.01, 0.01), 0.6)
		tw.tween_callback(queue_free)
	else:
		queue_free()
