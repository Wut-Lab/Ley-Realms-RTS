class_name MapGenerator
extends RefCounted
## Builds a procedural world: heightmap, water, start positions, resources, shrines and monster lairs.

const BIOMES := [
	{"grass": Color(0.36, 0.56, 0.22), "grass2": Color(0.47, 0.62, 0.26), "sand": Color(0.8, 0.74, 0.52),
	 "rock": Color(0.5, 0.47, 0.43), "peak": Color(0.66, 0.64, 0.6), "water": Color(0.16, 0.38, 0.58),
	 "trees": ["tree_oak", "tree_oak", "tree_pine"], "hill": 3.0, "mount": 0.42, "forest": 1.0, "mana": 1.0,
	 "sun": Color(1.0, 0.95, 0.85), "sky": Color(0.45, 0.62, 0.9), "horizon": Color(0.75, 0.82, 0.9)},
	{"grass": Color(0.42, 0.5, 0.27), "grass2": Color(0.5, 0.52, 0.32), "sand": Color(0.62, 0.6, 0.5),
	 "rock": Color(0.47, 0.45, 0.44), "peak": Color(0.92, 0.93, 0.95), "water": Color(0.15, 0.32, 0.48),
	 "trees": ["tree_pine", "tree_pine", "tree_oak"], "hill": 4.4, "mount": 0.3, "forest": 0.9, "mana": 1.0,
	 "sun": Color(1.0, 0.93, 0.85), "sky": Color(0.42, 0.55, 0.8), "horizon": Color(0.72, 0.76, 0.82)},
	{"grass": Color(0.86, 0.89, 0.93), "grass2": Color(0.76, 0.81, 0.87), "sand": Color(0.62, 0.64, 0.66),
	 "rock": Color(0.44, 0.47, 0.53), "peak": Color(0.97, 0.98, 1.0), "water": Color(0.32, 0.52, 0.68),
	 "trees": ["tree_snowpine", "tree_snowpine", "tree_pine"], "hill": 3.4, "mount": 0.38, "forest": 0.9, "mana": 1.1,
	 "sun": Color(0.9, 0.93, 1.0), "sky": Color(0.55, 0.65, 0.85), "horizon": Color(0.82, 0.86, 0.92)},
	{"grass": Color(0.74, 0.56, 0.36), "grass2": Color(0.66, 0.46, 0.29), "sand": Color(0.87, 0.77, 0.52),
	 "rock": Color(0.46, 0.33, 0.26), "peak": Color(0.36, 0.26, 0.21), "water": Color(0.2, 0.42, 0.46),
	 "trees": ["tree_dead", "tree_acacia", "tree_acacia"], "hill": 3.2, "mount": 0.36, "forest": 0.55, "mana": 0.9,
	 "sun": Color(1.0, 0.86, 0.68), "sky": Color(0.6, 0.6, 0.72), "horizon": Color(0.92, 0.8, 0.65)},
	{"grass": Color(0.2, 0.42, 0.31), "grass2": Color(0.3, 0.36, 0.44), "sand": Color(0.52, 0.56, 0.46),
	 "rock": Color(0.36, 0.34, 0.42), "peak": Color(0.55, 0.5, 0.64), "water": Color(0.22, 0.24, 0.52),
	 "trees": ["tree_elder", "tree_elder", "tree_mushroom"], "hill": 3.0, "mount": 0.42, "forest": 1.35, "mana": 1.7,
	 "sun": Color(0.9, 0.85, 1.0), "sky": Color(0.35, 0.38, 0.65), "horizon": Color(0.6, 0.62, 0.78)},
]


class MapData:
	var size := 128
	var heights := PackedFloat32Array()
	var colors := PackedColorArray()
	var water_level := -100.0
	var walk := PackedByteArray()
	var starts: Array = []
	var resources: Array = []
	var shrines: Array = []
	var lairs: Array = []
	var biome := 0

	func h(x: int, z: int) -> float:
		return heights[z * (size + 1) + x]


static func generate(cfg: Dictionary) -> MapData:
	var md := MapData.new()
	var size: int = cfg["size"]
	md.size = size
	md.biome = cfg["biome"]
	var bd: Dictionary = BIOMES[md.biome]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg["seed"])
	var n_players: int = cfg["players"]
	var center := Vector2(size, size) * 0.5
	var vs := size + 1

	# ---- start positions ----
	var a0 := rng.randf() * TAU
	for i in n_players:
		var a := a0 + TAU * i / n_players + rng.randf_range(-0.12, 0.12)
		var rad := size * rng.randf_range(0.34, 0.38)
		md.starts.append(center + Vector2(cos(a), sin(a)) * rad)

	# ---- heights ----
	var relief: int = cfg["relief"]
	var hill_amp: float = bd["hill"] * [0.35, 1.0, 1.35][relief]
	var mount_scale: float = [0.0, 1.0, 1.6][relief]
	var mount_t: float = bd["mount"] - [0.0, 0.0, 0.1][relief]
	var water: int = cfg["water"]
	md.water_level = [-100.0, -0.35, 0.45][water]

	var n1 := FastNoiseLite.new()
	n1.seed = rng.randi()
	n1.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n1.frequency = 0.014
	n1.fractal_octaves = 4
	var n2 := FastNoiseLite.new()
	n2.seed = rng.randi()
	n2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n2.frequency = 0.009
	n2.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	n2.fractal_octaves = 3
	var n3 := FastNoiseLite.new()
	n3.seed = rng.randi()
	n3.frequency = 0.012
	n3.fractal_octaves = 2

	md.heights.resize(vs * vs)
	for z in vs:
		for x in vs:
			var h := n1.get_noise_2d(x, z) * hill_amp + 0.9
			if mount_scale > 0.0:
				var r := n2.get_noise_2d(x, z)
				var m := clampf((r - mount_t) / (1.0 - mount_t), 0.0, 1.0)
				h += m * m * 14.0 * mount_scale
			if water > 0:
				var l := n3.get_noise_2d(x, z)
				h -= maxf(0.0, l - (0.25 if water == 1 else 0.05)) * 9.0
			# map edge rises gently into hills
			var ed := minf(minf(x, z), minf(size - x, size - z))
			if ed < 6:
				h += (6 - ed) * 0.5
			md.heights[z * vs + x] = h

	var wl := md.water_level
	var lo := maxf(wl + 0.8, -1.0)
	var hi := lo + 2.6
	# ---- roads guarantee every start connects to the centre ----
	for s in md.starts:
		var seg: Vector2 = center - s
		var steps := int(seg.length())
		for k in range(0, steps + 1, 2):
			var p: Vector2 = s + seg * (float(k) / maxf(steps, 1))
			_soften(md, p, 5.0, lo, hi)
	_soften(md, center, 9.0, lo, hi)
	# ---- flat start plateaus ----
	var start_h := clampf(lo + 0.6, lo, hi)
	for s in md.starts:
		for z in range(int(s.y) - 22, int(s.y) + 23):
			for x in range(int(s.x) - 22, int(s.x) + 23):
				if x < 0 or z < 0 or x >= vs or z >= vs:
					continue
				var d := Vector2(x, z).distance_to(s)
				if d < 21.0:
					var t := 1.0 - smoothstep(12.0, 21.0, d)
					var i := z * vs + x
					md.heights[i] = lerpf(md.heights[i], start_h, t)

	# ---- walkability ----
	md.walk.resize(size * size)
	for z in size:
		for x in size:
			var h00 := md.h(x, z)
			var h10 := md.h(x + 1, z)
			var h01 := md.h(x, z + 1)
			var h11 := md.h(x + 1, z + 1)
			var mn := minf(minf(h00, h10), minf(h01, h11))
			var mx := maxf(maxf(h00, h10), maxf(h01, h11))
			var avg := (h00 + h10 + h01 + h11) * 0.25
			var ok := avg > wl + 0.2 and (mx - mn) < 1.0 and x > 1 and z > 1 and x < size - 2 and z < size - 2
			md.walk[z * size + x] = 1 if ok else 0

	# reachable region from start 0
	var reach := PackedByteArray()
	reach.resize(size * size)
	var q: Array = []
	var sc := Vector2i(md.starts[0])
	q.append(sc)
	reach[sc.y * size + sc.x] = 1
	var qi := 0
	while qi < q.size():
		var c: Vector2i = q[qi]
		qi += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nc: Vector2i = c + d
			if nc.x < 0 or nc.y < 0 or nc.x >= size or nc.y >= size:
				continue
			var ni := nc.y * size + nc.x
			if reach[ni] == 0 and md.walk[ni] == 1:
				reach[ni] = 1
				q.append(nc)

	# ---- resources ----
	var occ := PackedByteArray()
	occ.resize(size * size)
	for s in md.starts:
		_mark_disc(occ, size, s, 6.5)
	# keep road corridors free of forests
	var road := PackedByteArray()
	road.resize(size * size)
	for s in md.starts:
		var seg: Vector2 = center - s
		var steps := int(seg.length())
		for k in range(0, steps + 1):
			_mark_disc(road, size, s + seg * (float(k) / maxf(steps, 1)), 2.6)

	var ab: float = [0.6, 1.0, 1.6][cfg["abundance"]]
	var fd: float = [0.55, 1.0, 1.6][cfg["forests"]] * bd["forest"]
	var trees: Array = bd["trees"]
	var ctx := {"md": md, "occ": occ, "reach": reach, "rng": rng, "size": size}

	for s in md.starts:
		var dir: Vector2 = (center - s).normalized()
		var base_a := dir.angle() + rng.randf_range(-0.6, 0.6)
		_cluster(ctx, "berry", s + Vector2.from_angle(base_a) * 9.0, 6, 2.4)
		_place(ctx, "gold_mine", s + Vector2.from_angle(base_a + 2.1) * 11.0, 6)
		_cluster(ctx, "mana_crystal", s + Vector2.from_angle(base_a - 2.1) * 13.0, 2, 1.5)
		var fa := base_a + PI + rng.randf_range(-0.5, 0.5)
		_forest(ctx, s + Vector2.from_angle(fa) * 16.0, int(34 * ab), 5.0, trees)
		_forest(ctx, s + Vector2.from_angle(fa + 1.4) * 19.0, int(20 * ab), 3.5, trees)
		if ab >= 1.0:
			_place(ctx, "gold_mine", s + Vector2.from_angle(base_a - 0.9) * 21.0, 8)
		if ab > 1.2:
			_cluster(ctx, "berry", s + Vector2.from_angle(base_a + 1.0) * 18.0, 5, 2.0)

	# scattered world forests
	var fn := FastNoiseLite.new()
	fn.seed = rng.randi()
	fn.frequency = 0.045
	var thr := 0.42 - 0.18 * fd
	var prob := clampf(0.45 * fd, 0.2, 0.75)
	for z in range(2, size - 2):
		for x in range(2, size - 2):
			var i := z * size + x
			if reach[i] == 0 or occ[i] != 0 or road[i] != 0:
				continue
			if fn.get_noise_2d(x, z) < thr:
				continue
			var p := Vector2(x + 0.5, z + 0.5)
			var near := false
			for s in md.starts:
				if p.distance_to(s) < 13.0:
					near = true
					break
			if near or rng.randf() > prob:
				continue
			occ[i] = 1
			md.resources.append({"type": "tree", "pos": p, "model": trees[rng.randi() % trees.size()], "v": rng.randi() % 3})

	var area_f := float(size * size) / 16384.0
	var n_gold := int(round(3 * area_f * ab))
	var n_mana := int(round(2.5 * area_f * ab * bd["mana"]))
	var n_berry := int(round(2 * area_f * ab))
	for i in n_gold:
		var p = _random_far(ctx, 24.0, 2)
		if p != null:
			_place(ctx, "gold_mine", p, 2)
	for i in n_mana:
		var p = _random_far(ctx, 24.0, 1)
		if p != null:
			_cluster(ctx, "mana_crystal", p, 2 + rng.randi() % 2, 1.6)
	for i in n_berry:
		var p = _random_far(ctx, 20.0, 1)
		if p != null:
			_cluster(ctx, "berry", p, 4, 2.0)

	# ---- ley shrines (strategic points) ----
	if cfg["shrines"]:
		var spots: Array = [center]
		for i in n_players:
			var s1: Vector2 = md.starts[i]
			var s2: Vector2 = md.starts[(i + 1) % n_players]
			var mid := (s1 + s2) * 0.5
			if n_players == 2:
				var perp := (s2 - s1).normalized().orthogonal()
				spots.append(center + perp * size * (0.25 if i == 0 else -0.25))
			else:
				spots.append(center + (mid - center).normalized() * size * 0.26)
		for sp in spots:
			var p = _find_free(ctx, sp, 2, 14)
			if p != null:
				_mark_disc(occ, size, p, 3.5)
				md.shrines.append(p)

	# ---- monster lairs ----
	if cfg["monsters"]:
		var packs := [["wolf", "wolf", "wolf"], ["troll"], ["troll", "wolf", "wolf"], ["wolf", "wolf", "wolf", "wolf"]]
		var n_lairs := n_players + 1 + int(area_f)
		for i in n_lairs:
			var p = _random_far(ctx, 30.0, 2)
			if p == null:
				continue
			var ok := true
			for sh in md.shrines:
				if p.distance_to(sh) < 10:
					ok = false
			if not ok:
				continue
			_mark_disc(occ, size, p, 2.0)
			_place(ctx, "gold_mine", p + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4)), 4)
			md.lairs.append({"pos": p, "monsters": packs[rng.randi() % packs.size()]})

	# ---- vertex colours ----
	md.colors.resize(vs * vs)
	var dn := FastNoiseLite.new()
	dn.seed = rng.randi()
	dn.frequency = 0.08
	var peak_h := lo + 6.0
	for z in vs:
		for x in vs:
			var h := md.h(x, z)
			var hx := md.h(mini(x + 1, size), z) - md.h(maxi(x - 1, 0), z)
			var hz := md.h(x, mini(z + 1, size)) - md.h(x, maxi(z - 1, 0))
			var slope := sqrt(hx * hx + hz * hz) * 0.5
			var t := dn.get_noise_2d(x, z) * 0.5 + 0.5
			var c: Color = bd["grass"].lerp(bd["grass2"], t)
			if h < wl + 0.45:
				c = bd["sand"]
			elif h < wl + 0.8:
				c = bd["sand"].lerp(c, (h - wl - 0.45) / 0.35)
			if slope > 0.5:
				c = c.lerp(bd["rock"], clampf((slope - 0.5) * 2.0, 0.0, 1.0))
			if h > peak_h:
				c = c.lerp(bd["peak"], clampf((h - peak_h) / 2.5, 0.0, 1.0))
			if h < wl:
				c = c.darkened(clampf((wl - h) * 0.3, 0.0, 0.6))
			md.colors[z * vs + x] = c
	return md


static func _soften(md: MapData, p: Vector2, r: float, lo: float, hi: float) -> void:
	var vs := md.size + 1
	for z in range(int(p.y - r), int(p.y + r) + 1):
		for x in range(int(p.x - r), int(p.x + r) + 1):
			if x < 0 or z < 0 or x >= vs or z >= vs:
				continue
			var d := Vector2(x, z).distance_to(p)
			if d > r:
				continue
			var w := 1.0 - smoothstep(r * 0.5, r, d)
			var i := z * vs + x
			var h := md.heights[i]
			md.heights[i] = lerpf(h, clampf(h, lo, hi), w)


static func _mark_disc(arr: PackedByteArray, size: int, p: Vector2, r: float) -> void:
	for z in range(int(p.y - r), int(p.y + r) + 1):
		for x in range(int(p.x - r), int(p.x + r) + 1):
			if x < 0 or z < 0 or x >= size or z >= size:
				continue
			if Vector2(x + 0.5, z + 0.5).distance_to(p) <= r:
				arr[z * size + x] = 1


static func _free(ctx: Dictionary, c: Vector2i, r: int) -> bool:
	var size: int = ctx["size"]
	for z in range(c.y - r, c.y + r + 1):
		for x in range(c.x - r, c.x + r + 1):
			if x < 2 or z < 2 or x >= size - 2 or z >= size - 2:
				return false
			var i := z * size + x
			if ctx["reach"][i] == 0 or ctx["occ"][i] != 0:
				return false
	return true


static func _find_free(ctx: Dictionary, p: Vector2, r: int, search: int):
	var c := Vector2i(int(p.x), int(p.y))
	for rad in range(0, search + 1):
		for dz in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				if abs(dx) != rad and abs(dz) != rad:
					continue
				var cc := c + Vector2i(dx, dz)
				if _free(ctx, cc, r):
					return Vector2(cc.x + 0.5, cc.y + 0.5)
	return null


static func _place(ctx: Dictionary, type: String, p: Vector2, search: int) -> bool:
	var r: int = Defs.RESOURCE_CELLS[type]
	var fp = _find_free(ctx, p, r + 1 if type == "gold_mine" else r, search)
	if fp == null:
		return false
	var c := Vector2i(int(fp.x), int(fp.y))
	var size: int = ctx["size"]
	for z in range(c.y - r, c.y + r + 1):
		for x in range(c.x - r, c.x + r + 1):
			ctx["occ"][z * size + x] = 1
	var rng: RandomNumberGenerator = ctx["rng"]
	ctx["md"].resources.append({"type": type, "pos": fp, "model": type, "v": rng.randi() % 3})
	return true


static func _cluster(ctx: Dictionary, type: String, p: Vector2, count: int, spread: float) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	for i in count:
		var off := Vector2.from_angle(rng.randf() * TAU) * rng.randf() * spread
		_place(ctx, type, p + off, 3)


static func _forest(ctx: Dictionary, p: Vector2, count: int, spread: float, trees: Array) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var size: int = ctx["size"]
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 4:
		tries += 1
		var off := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * spread
		var c := Vector2i(int(p.x + off.x), int(p.y + off.y))
		if not _free(ctx, c, 0):
			continue
		ctx["occ"][c.y * size + c.x] = 1
		ctx["md"].resources.append({"type": "tree", "pos": Vector2(c.x + 0.5, c.y + 0.5),
			"model": trees[rng.randi() % trees.size()], "v": rng.randi() % 3})
		placed += 1


static func _random_far(ctx: Dictionary, min_d: float, r: int):
	var rng: RandomNumberGenerator = ctx["rng"]
	var md: MapData = ctx["md"]
	var size: int = ctx["size"]
	for t in 60:
		var p := Vector2(rng.randf_range(6, size - 6), rng.randf_range(6, size - 6))
		var ok := true
		for s in md.starts:
			if p.distance_to(s) < min_d:
				ok = false
				break
		if not ok:
			continue
		if _free(ctx, Vector2i(int(p.x), int(p.y)), r):
			return Vector2(int(p.x) + 0.5, int(p.y) + 0.5)
	return null


## Renders a top-down preview image (used by the setup screen and minimap base).
static func preview_image(md: MapData, px: int, with_objects: bool = true) -> Image:
	var img := Image.create(px, px, false, Image.FORMAT_RGB8)
	var bd: Dictionary = BIOMES[md.biome]
	var sc := float(md.size) / px
	for y in px:
		for x in px:
			var wx := int(x * sc)
			var wz := int(y * sc)
			var c: Color = md.colors[wz * (md.size + 1) + wx]
			if md.h(wx, wz) < md.water_level:
				c = bd["water"].darkened(clampf((md.water_level - md.h(wx, wz)) * 0.15, 0.0, 0.5))
			img.set_pixel(x, y, c)
	if with_objects:
		for r in md.resources:
			var p: Vector2 = r["pos"] / sc
			var col: Color
			match r["type"]:
				"tree": col = Color(0.1, 0.3, 0.12)
				"berry": col = Color(0.9, 0.3, 0.4)
				"gold_mine": col = Color(1, 0.85, 0.2)
				_: col = Color(0.6, 0.45, 1.0)
			var rr := 0 if r["type"] == "tree" or px < 200 else 1
			_dot(img, p, rr if r["type"] == "tree" else rr + 1, col)
		for s in md.shrines:
			_dot(img, s / sc, 3, Color(0.4, 0.95, 1.0))
		for l in md.lairs:
			_dot(img, l["pos"] / sc, 2, Color(0.7, 0.1, 0.1))
	return img


static func _dot(img: Image, p: Vector2, r: int, col: Color) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := int(p.x) + dx
			var y := int(p.y) + dy
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, col)
