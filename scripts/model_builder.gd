class_name ModelBuilder
extends RefCounted
## Accumulates transformed, vertex-coloured primitive meshes into one ArrayMesh.
## Colour alpha < 1 marks a part as glowing (emission) in the entity shader.

var verts := PackedVector3Array()
var norms := PackedVector3Array()
var cols := PackedColorArray()
var idx := PackedInt32Array()


func add(prim: PrimitiveMesh, xf: Transform3D, col: Color) -> void:
	var arr := prim.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var ii: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var base := verts.size()
	var nb := xf.basis.inverse().transposed()
	for i in v.size():
		verts.append(xf * v[i])
		norms.append((nb * n[i]).normalized())
		cols.append(col)
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
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	if mat:
		m.surface_set_material(0, mat)
	return m
