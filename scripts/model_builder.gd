class_name ModelBuilder
extends RefCounted
## Accumulates transformed, vertex-coloured primitive meshes into one ArrayMesh.
## Colour alpha < 1 marks a part as glowing (emission) in the entity shader.

var verts := PackedVector3Array()
var norms := PackedVector3Array()
var cols := PackedColorArray()
var idx := PackedInt32Array()
var uvs := PackedVector2Array()
var textured := false  # buildings: tag each part with a surface material for the shader
var unit_tex := false  # units: cloth, metal, leather, stone


## 0 plain, 1 stone bricks, 2 wood planks, 3 plaster, 4 roof shingles
func _mat_id(prim: PrimitiveMesh, col: Color) -> float:
	if col.a < 0.99:
		return 0.0
	if unit_tex:
		if col.h > 0.1 and col.h < 0.16 and col.s > 0.55 and col.v > 0.75:
			return 5.0  # gold trim
		if col.s < 0.16 and col.v > 0.62:
			return 5.0  # steel
		if col.s < 0.16 and col.v > 0.25:
			return 1.0  # stone (golems)
		if col.h > 0.02 and col.h < 0.13 and col.s > 0.3 and col.v < 0.65:
			return 6.0  # leather / wood
		if col.s > 0.35 and not (col.h > 0.03 and col.h < 0.1 and col.v > 0.85):
			return 7.0  # cloth (skin excluded)
		return 0.0
	if not textured:
		return 0.0
	var roofish: bool = prim is PrismMesh or (prim is CylinderMesh and prim.top_radius == 0.0)
	if roofish and col.s > 0.25:
		return 4.0
	if col.s < 0.16 and col.v > 0.25 and col.v < 0.82:
		return 1.0
	if col.h > 0.03 and col.h < 0.13 and col.s > 0.3 and col.v < 0.62:
		return 2.0
	if col.v > 0.75 and col.s < 0.32:
		return 3.0
	return 0.0


func add(prim: PrimitiveMesh, xf: Transform3D, col: Color) -> void:
	var arr := prim.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var ii: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var base := verts.size()
	var nb := xf.basis.inverse().transposed()
	var mid := Vector2(_mat_id(prim, col), 0.0)
	for i in v.size():
		verts.append(xf * v[i])
		norms.append((nb * n[i]).normalized())
		cols.append(col)
		uvs.append(mid)
	for i in ii.size():
		idx.append(base + ii[i])


static func xf(pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot) * Basis.from_scale(scl), pos)


func box(pos: Vector3, size: Vector3, col: Color, rot: Vector3 = Vector3.ZERO) -> void:
	var m := BoxMesh.new()
	m.size = size
	add(m, xf(pos, rot), col)


func cyl(pos: Vector3, rt: float, rb: float, h: float, col: Color, seg: int = 8, rot: Vector3 = Vector3.ZERO) -> void:
	var m := CylinderMesh.new()
	m.top_radius = rt
	m.bottom_radius = rb
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	add(m, xf(pos, rot), col)


func cone(pos: Vector3, r: float, h: float, col: Color, seg: int = 8, rot: Vector3 = Vector3.ZERO) -> void:
	cyl(pos, 0.0, r, h, col, seg, rot)


func sphere(pos: Vector3, r: float, col: Color, scl: Vector3 = Vector3.ONE, seg: int = 8, rings: int = 5, rot: Vector3 = Vector3.ZERO) -> void:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = seg
	m.rings = rings
	add(m, xf(pos, rot, scl), col)


func prism(pos: Vector3, size: Vector3, col: Color, rot: Vector3 = Vector3.ZERO) -> void:
	var m := PrismMesh.new()
	m.size = size
	add(m, xf(pos, rot), col)


func torus(pos: Vector3, inner: float, outer: float, col: Color, rot: Vector3 = Vector3.ZERO) -> void:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 16
	m.ring_segments = 6
	add(m, xf(pos, rot), col)


func commit(mat: Material) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	if mat:
		m.surface_set_material(0, mat)
	return m
