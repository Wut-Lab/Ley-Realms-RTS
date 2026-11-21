class_name Game
extends Node3D
## The running match: world construction, pathfinding, fog of war, combat resolution, victory.

const BK := 8.0
const CONTROL_HOLD_TIME := 180.0

var main: Node
var md: MapGenerator.MapData
var size := 128
var players: Array = []
var human := 1
var units: Array = []
var buildings: Array = []
var resources: Array = []
var shrines: Array = []
var projectiles: Array = []
var fx_nodes: Array = []
var areas: Array = []
var champ_t := 0.0

var astar := AStarGrid2D.new()
var terrain_walk := PackedByteArray()
var path_occ := PackedInt32Array()
var place_occ := PackedInt32Array()
var ubuckets := {}
var rbuckets := {}
var bbuckets := {}

var cam: RTSCamera
var hud: HUD
var ctl: PlayerController
var ais: Array = []
var sun: DirectionalLight3D

var elapsed := 0.0
var over := false
var peace_until := 0.0
var victory_mode := 0
var control_team := -1
var control_timer := 0.0

var fog_on := true
var fog_res := 64
var fog_vis := PackedByteArray()
var fog_exp := PackedByteArray()
var fog_tex: ImageTexture
var fog_t := 0.0
var stamp_cache := {}
var check_t := 0.0
var alert_t := {}
var gate_cells := {}
var camps: Array = []
var recruit_groups := {}
var recruit_t := 0.0
var load_data: Dictionary = {}
var save_slot := ""
var autosave_t := 180.0
var terrain_mat: ShaderMaterial
var water_mat: ShaderMaterial


func _ready() -> void:
	var gs := GameSettings
	if gs.random_seed:
		gs.map_seed = randi() % 999999
	md = MapGenerator.generate(gs.to_dict())
	size = md.size
	fog_on = gs.fog and (not gs.autotest or "--fog" in OS.get_cmdline_user_args())
	victory_mode = gs.victory if gs.shrines else 0
	peace_until = GameSettings.PEACE_MINUTES[gs.peace] * 60.0
	Engine.time_scale = GameSettings.SPEED_VALUES[gs.speed] if not gs.autotest else gs.test_scale

	_init_fog()
	Sfx.game = self
	Sfx.play_music()
	Models.setup(fog_tex, size, fog_on)
	_build_environment()
	_build_terrain()
	_init_grid()
	_create_players()
	_spawn_map_objects()
	if load_data.is_empty():
		_spawn_starts()
	else:
		SaveGame.restore(self, load_data)

	cam = RTSCamera.new()
	cam.game = self
	add_child(cam)
	var hs: Vector2 = md.starts[0]
	cam.focus = Vector3(hs.x, height_at(hs.x, hs.y), hs.y + 4.0)

	ctl = PlayerController.new()
	ctl.game = self
	add_child(ctl)
	if gs.touch_active:
		var ti := TouchInput.new()
		ti.game = self
		add_child(ti)
	hud = HUD.new()
	hud.game = self
	add_child(hud)

	for p in players:
		if p.id > 0 and not p.human:
			var ai := AIController.new()
			ai.setup(self, p.id, p.ai_hard)
			ais.append(ai)
			add_child(ai)
	if gs.autotest and not "--uitest" in OS.get_cmdline_user_args() and not "--touchtest" in OS.get_cmdline_user_args() and not "--featuretest" in OS.get_cmdline_user_args() and not "--showcase" in OS.get_cmdline_user_args():
		var ai := AIController.new()
		ai.setup(self, human, true)
		ais.append(ai)
		add_child(ai)
	if "--touchtest" in OS.get_cmdline_user_args():
		var tt = load("res://scripts/touch_test.gd").new()
		tt.game = self
		add_child(tt)
	if "--showcase" in OS.get_cmdline_user_args():
		var sc = load("res://scripts/showcase.gd").new()
		sc.game = self
		add_child(sc)
	if "--featuretest" in OS.get_cmdline_user_args() and not GameSettings.get_meta("ft_started", false):
		GameSettings.set_meta("ft_started", true)
		var ft = load("res://scripts/feature_test.gd").new()
		ft.game = self
		ft.main = main
		main.add_child(ft)
	if "--uitest" in OS.get_cmdline_user_args():
		var t = load("res://scripts/ui_test.gd").new()
		t.game = self
		add_child(t)
	if not load_data.is_empty():
		SaveGame.restore_late(self, load_data)
		_update_fog()
		hud.message("Game loaded (%s)." % SaveGame.SLOT_NAMES.get(save_slot, save_slot), Color(0.7, 1, 0.7))
		load_data = {}
		return
	_update_fog()
	hud.message("Welcome to %s. Gather resources and build your realm!" % GameSettings.BIOME_NAMES[md.biome], Color(1, 0.9, 0.6))
	if peace_until > 0:
		hud.message("Peace treaty: no attacks for %d minutes." % int(peace_until / 60), Color(0.7, 0.9, 1))
	if victory_mode > 0:
		hud.message("Hold every Ley Shrine for %d minutes to win by Dominion." % int(CONTROL_HOLD_TIME / 60), Color(0.6, 0.95, 1))


# ======================================================================= setup
func _build_environment() -> void:
	var bd: Dictionary = MapGenerator.BIOMES[md.biome]
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = bd["sky"]
	sm.sky_horizon_color = bd["horizon"]
	sm.ground_horizon_color = bd["horizon"]
	sm.ground_bottom_color = bd["horizon"].darkened(0.4)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	if RenderingServer.get_rendering_device() != null:
		# Forward+/Mobile light the scene more strongly from the sky; keep colours rich like the phone renderer
		env.ambient_light_energy = 0.55
		env.ambient_light_sky_contribution = 0.85
		env.tonemap_exposure = 0.92
		env.tonemap_white = 1.4
		env.adjustment_enabled = true
		env.adjustment_saturation = 1.18
		env.adjustment_contrast = 1.08
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.ssao_enabled = false
	env.fog_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = bd["sun"]
	sun.light_energy = 1.25
	sun.shadow_enabled = not GameSettings.low_quality
	if GameSettings.low_quality:
		env.glow_enabled = false
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	sun.directional_shadow_max_distance = 120.0
	sun.rotation = Vector3(deg_to_rad(-52), deg_to_rad(-35), 0)
	add_child(sun)


func _build_terrain() -> void:
	var vs := size + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	verts.resize(vs * vs)
	norms.resize(vs * vs)
	for z in vs:
		for x in vs:
			var i := z * vs + x
			verts[i] = Vector3(x, md.heights[i], z)
			var hl := md.h(maxi(x - 1, 0), z)
			var hr := md.h(mini(x + 1, size), z)
			var hd := md.h(x, maxi(z - 1, 0))
			var hu := md.h(x, mini(z + 1, size))
			norms[i] = Vector3(hl - hr, 2.0, hd - hu).normalized()
	idx.resize(size * size * 6)
	var k := 0
	for z in size:
		for x in size:
			var a := z * vs + x
			var b := a + 1
			var c := a + vs
			var d := c + 1
			idx[k] = a; idx[k + 1] = b; idx[k + 2] = c
			idx[k + 3] = b; idx[k + 4] = d; idx[k + 5] = c
			k += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = md.colors
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var sh := Shader.new()
	sh.code = Models.shader_code(Models.TERRAIN_SHADER)
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = sh
	terrain_mat.set_shader_parameter("fog_tex", fog_tex)
	terrain_mat.set_shader_parameter("map_size", float(size))
	terrain_mat.set_shader_parameter("fog_on", 1.0 if fog_on else 0.0)
	var bdc: Dictionary = MapGenerator.BIOMES[md.biome]
	var rk: Color = bdc["rock"]
	terrain_mat.set_shader_parameter("rock_color", Vector3(rk.r, rk.g, rk.b))
	terrain_mat.set_shader_parameter("cloud_on", 0.0 if GameSettings.low_quality else 1.0)
	terrain_mat.set_shader_parameter("hq", 0.0 if GameSettings.low_quality else 1.0)
	m.surface_set_material(0, terrain_mat)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	add_child(mi)
	# underside skirt so the map edge isn't see-through
	var skirt := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size, 20, size)
	skirt.mesh = bm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.12, 0.1, 0.09)
	bm.material = sm
	skirt.position = Vector3(size * 0.5, -12.0, size * 0.5)
	add_child(skirt)
	if md.water_level > -50.0:
		var wm := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(size + 40, size + 40)
		pm.subdivide_width = 64
		pm.subdivide_depth = 64
		var wsh := Shader.new()
		wsh.code = Models.shader_code(Models.WATER_SHADER)
		water_mat = ShaderMaterial.new()
		water_mat.shader = wsh
		var wc: Color = MapGenerator.BIOMES[md.biome]["water"]
		water_mat.set_shader_parameter("water_color", Vector3(wc.r, wc.g, wc.b))
		water_mat.set_shader_parameter("fog_tex", fog_tex)
		water_mat.set_shader_parameter("map_size", float(size))
		water_mat.set_shader_parameter("fog_on", 1.0 if fog_on else 0.0)
		water_mat.set_shader_parameter("water_level", md.water_level)
		var hz: Color = MapGenerator.BIOMES[md.biome]["horizon"]
		water_mat.set_shader_parameter("sky_color", Vector3(hz.r, hz.g, hz.b))
		# heightmap so the water knows how deep it is everywhere (shallows, foam)
		var hb := PackedByteArray()
		hb.resize((size + 1) * (size + 1) * 4)
		for i in md.heights.size():
			hb.encode_float(i * 4, md.heights[i])
		var himg := Image.create_from_data(size + 1, size + 1, false, Image.FORMAT_RF, hb)
		water_mat.set_shader_parameter("height_tex", ImageTexture.create_from_image(himg))
		pm.material = water_mat
		wm.mesh = pm
		wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wm.position = Vector3(size * 0.5, md.water_level, size * 0.5)
		add_child(wm)


func _init_grid() -> void:
	terrain_walk = md.walk
	path_occ.resize(size * size)
	place_occ.resize(size * size)
	astar.region = Rect2i(0, 0, size, size)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for z in size:
		for x in size:
			if terrain_walk[z * size + x] == 0:
				astar.set_point_solid(Vector2i(x, z), true)


func _create_players() -> void:
	var gs := GameSettings
	var gaia := PlayerData.new()
	gaia.id = 0
	gaia.name = "Wild Creatures"
	gaia.color = Defs.PLAYER_COLORS[0]
	gaia.team = 99
	players.append(gaia)
	var colors: Array = [gs.player_color]
	for c in range(1, Defs.PLAYER_COLORS.size()):
		if c != gs.player_color:
			colors.append(c)
	var names: Array = Defs.AI_NAMES.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = gs.map_seed
	for i in range(1, gs.num_ai + 2):
		var p := PlayerData.new()
		p.id = i
		p.color = Defs.PLAYER_COLORS[colors[i - 1]]
		p.human = i == 1
		p.name = "You" if p.human else names.pop_at(rng.randi() % names.size())
		p.team = i
		if gs.teams == 1 and not p.human:
			p.team = 2
		p.ai_hard = gs.difficulty == 1
		if not p.human:
			p.gather_mult = 1.15 if p.ai_hard else 0.85
		p.max_pop = GameSettings.POP_VALUES[gs.pop_cap]
		var sr: Array = [[100, 100, 50, 0], [200, 200, 100, 50], [500, 500, 300, 150], [2000, 2000, 1500, 1000]][gs.start_res]
		for j in 4:
			p.res[Defs.RES[j]] = float(sr[j])
		p.age = gs.start_age
		players.append(p)


func _spawn_map_objects() -> void:
	var mult: float = [0.75, 1.0, 1.4][GameSettings.abundance]
	var tree_groups := {}
	var ri := 0
	for r in md.resources:
		var n := ResourceNode.new()
		n.idx = ri
		ri += 1
		n.setup(self, r["type"], mult)
		var p: Vector2 = r["pos"]
		n.position = Vector3(p.x, height_at(p.x, p.y), p.y)
		n.model_key = r["model"]
		add_child(n)
		if r["type"] == "tree":
			var key := "%s|%d|%d|%d" % [r["model"], r["v"], int(p.x / 32), int(p.y / 32)]
			if not tree_groups.has(key):
				tree_groups[key] = []
			tree_groups[key].append(n)
		else:
			n.mesh_i = MeshInstance3D.new()
			n.mesh_i.mesh = Models.mesh(r["model"], Color.WHITE, r["v"])
			n.mesh_i.rotation.y = randf() * TAU
			n.add_child(n.mesh_i)
		_add_resource(n)
	# trees are drawn with chunked multimeshes for performance
	for key in tree_groups:
		var list: Array = tree_groups[key]
		var parts: PackedStringArray = key.split("|")
		var mmesh := MultiMesh.new()
		mmesh.transform_format = MultiMesh.TRANSFORM_3D
		mmesh.mesh = Models.mesh(parts[0], Color.WHITE, int(parts[1]))
		mmesh.instance_count = list.size()
		for i in list.size():
			var n: ResourceNode = list[i]
			var s := randf_range(0.85, 1.2)
			mmesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3(s, s, s)), n.position))
			n.mm = mmesh
			n.mm_index = i
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mmesh
		add_child(mmi)
	for sp in md.shrines:
		var s := Shrine.new()
		s.setup(self)
		s.position = Vector3(sp.x, height_at(sp.x, sp.y), sp.y)
		add_child(s)
		shrines.append(s)
		_mark_cells(Rect2i(int(sp.x) - 1, int(sp.y) - 1, 3, 3), 1, true)
	for l in md.lairs:
		var lp: Vector2 = l["pos"]
		var deco := MeshInstance3D.new()
		deco.mesh = Models.mesh("lair")
		deco.position = Vector3(lp.x, height_at(lp.x, lp.y), lp.y)
		add_child(deco)
		if not load_data.is_empty():
			continue  # monsters come from the save
		var i := 0
		for mk in l["monsters"]:
			var off := Vector2.from_angle(i * 2.1) * 1.5
			var u := spawn_unit(mk, 0, lp + off)
			if u:
				u.home = lp + off
				u.rotation.y = randf() * TAU
			i += 1
	# mercenary camps and freeblade bands
	for c in md.camps:
		var cp: Vector2 = c["pos"]
		var camp := MercCamp.new()
		camp.setup(self, c["offers"])
		camp.position = Vector3(cp.x, height_at(cp.x, cp.y), cp.y)
		add_child(camp)
		camps.append(camp)
		_mark_cells(Rect2i(int(cp.x) - 1, int(cp.y) - 1, 3, 3), 1, true)
	for gi in md.freeblades.size():
		var fb: Dictionary = md.freeblades[gi]
		var fp: Vector2 = fb["pos"]
		var deco := MeshInstance3D.new()
		deco.mesh = Models.mesh("freeblade_camp")
		deco.position = Vector3(fp.x, height_at(fp.x, fp.y), fp.y)
		add_child(deco)
		recruit_groups[gi] = {"pos": fp, "units": []}
		if not load_data.is_empty():
			continue  # the band (or its absence) comes from the save
		var j := 0
		for mk in fb["units"]:
			var u := spawn_unit(mk, 0, fp + Vector2.from_angle(j * 2.4 + 0.5) * 1.6)
			if u:
				u.make_recruit(gi)
				u.rotation.y = randf() * TAU
			j += 1


func _spawn_starts() -> void:
	var gs := GameSettings
	for i in range(1, players.size()):
		var p: PlayerData = players[i]
		var s: Vector2 = md.starts[i - 1]
		var th := spawn_building("town_hall", p.id, Vector2(round(s.x) + 0.5, round(s.y) + 0.5), true)
		var to_c := (Vector2(size, size) * 0.5 - s).normalized()
		th.rally = th.pos2() + to_c * 5.0
		for k in (5 if gs.start_res >= 2 else 4):
			var a := to_c.angle() + (k - 2) * 0.5
			spawn_unit("peasant", p.id, th.pos2() + Vector2.from_angle(a) * 4.0)
		var sc := spawn_unit("spearman" if p.age < 2 else "knight", p.id, th.pos2() + to_c * 5.5)
		if sc:
			sc.rotation.y = atan2(to_c.x, to_c.y)
		if p.age >= 2:
			for k in 2:
				spawn_unit("peasant", p.id, th.pos2() - to_c * 4.0 + Vector2(k * 1.2 - 0.6, 0))
		_apply_age_bonus(p)
		recalc_pop(p.id)
		if gs.champions:
			if p.human:
				p.champ_class = Defs.CHAMPION_ORDER[gs.champion_class]
			else:
				p.champ_class = Defs.CHAMPION_ORDER[(gs.map_seed + p.id * 7) % Defs.CHAMPION_ORDER.size()]
			spawn_champion(p.id, th.pos2() - to_c * 4.5)
	if gs.reveal or not fog_on:
		fog_exp.fill(1)


func _apply_age_bonus(_p: PlayerData) -> void:
	pass


# ======================================================================= fog
func _init_fog() -> void:
	fog_res = size / 2
	fog_vis.resize(fog_res * fog_res)
	fog_exp.resize(fog_res * fog_res)
	var bytes := PackedByteArray()
	bytes.resize(fog_res * fog_res)
	bytes.fill(255 if not fog_on else 0)
	var img := Image.create_from_data(fog_res, fog_res, false, Image.FORMAT_L8, bytes)
	fog_tex = ImageTexture.create_from_image(img)


func _stamp_offsets(r: int) -> PackedInt32Array:
	if stamp_cache.has(r):
		return stamp_cache[r]
	var arr := PackedInt32Array()
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dz * dz <= r * r:
				arr.append(dx)
				arr.append(dz)
	stamp_cache[r] = arr
	return arr


func _stamp(p: Vector2, sight: float) -> void:
	var cx := int(p.x * 0.5)
	var cz := int(p.y * 0.5)
	var offs := _stamp_offsets(int(ceil(sight * 0.5)))
	for i in range(0, offs.size(), 2):
		var x := cx + offs[i]
		var z := cz + offs[i + 1]
		if x >= 0 and z >= 0 and x < fog_res and z < fog_res:
			var j := z * fog_res + x
			fog_vis[j] = 1
			fog_exp[j] = 1


func _update_fog() -> void:
	var hteam: int = players[human].team
	if not fog_on:
		return
	fog_vis.fill(0)
	for u in units:
		if u.alive and players[u.pid].team == hteam:
			_stamp(u.pos2(), u.sight())
	for b in buildings:
		if b.alive and players[b.pid].team == hteam:
			_stamp(b.pos2(), b.def["sight"] + b.radius if b.complete else 3.0)
	for s in shrines:
		if s.owner_id > 0 and players[s.owner_id].team == hteam:
			_stamp(s.pos2(), 7.0)
	var bytes := PackedByteArray()
	bytes.resize(fog_res * fog_res)
	for i in bytes.size():
		bytes[i] = 255 if fog_vis[i] == 1 else (150 if fog_exp[i] == 1 else 0)
	fog_tex.update(Image.create_from_data(fog_res, fog_res, false, Image.FORMAT_L8, bytes))
	for u in units:
		if players[u.pid].team != hteam:
			u.seen = fog_visible(u.pos2())
			u.visible = u.seen
	for b in buildings:
		if players[b.pid].team != hteam:
			b.seen = fog_explored(b.pos2())
			b.visible = b.seen


func fog_visible(p: Vector2) -> bool:
	if not fog_on:
		return true
	var x := clampi(int(p.x * 0.5), 0, fog_res - 1)
	var z := clampi(int(p.y * 0.5), 0, fog_res - 1)
	return fog_vis[z * fog_res + x] == 1


func fog_explored(p: Vector2) -> bool:
	if not fog_on:
		return true
	var x := clampi(int(p.x * 0.5), 0, fog_res - 1)
	var z := clampi(int(p.y * 0.5), 0, fog_res - 1)
	return fog_exp[z * fog_res + x] == 1


# ======================================================================= main loop
func _process(delta: float) -> void:
	if over:
		return
	elapsed += delta
	var t0 := Time.get_ticks_usec()
	_rebuild_buckets()
	var t1 := Time.get_ticks_usec()
	for u in units.duplicate():
		if u.alive:
			u.tick(delta)
	var t2 := Time.get_ticks_usec()
	for b in buildings.duplicate():
		if b.alive:
			b.tick(delta)
	var t3 := Time.get_ticks_usec()
	prof["buckets"] = prof.get("buckets", 0) + t1 - t0
	prof["units"] = prof.get("units", 0) + t2 - t1
	prof["bld"] = prof.get("bld", 0) + t3 - t2
	for s in shrines:
		s.tick(delta)
	for c in camps:
		c.tick(delta)
	recruit_t -= delta
	if recruit_t <= 0.0:
		recruit_t = 0.5
		_check_recruits()
	for pr in projectiles.duplicate():
		pr.tick(delta)
	for a in areas.duplicate():
		if not a.tick(delta):
			areas.erase(a)
			a.queue_free()
	champ_t -= delta
	if champ_t <= 0.0:
		champ_t = 1.0
		_update_champions()
	fog_t -= delta
	if fog_t <= 0.0:
		fog_t = 0.2
		_update_fog()
	check_t -= delta
	if check_t <= 0.0:
		check_t = 1.0
		_check_victory()
	if victory_mode > 0:
		_update_control(delta)
	if not GameSettings.autotest:
		autosave_t -= delta / maxf(Engine.time_scale, 0.01)
		if autosave_t <= 0.0:
			autosave_t = 180.0
			SaveGame.save(self, "autosave")
	if GameSettings.autotest:
		_autotest_report()
		if not GameSettings.shots.is_empty():
			RenderingServer.render_loop_enabled = elapsed >= GameSettings.shots[0] - 1.0
		if not GameSettings.shots.is_empty() and elapsed >= GameSettings.shots[0]:
			var tt: float = GameSettings.shots.pop_front()
			_shot(tt)


func _shot(tt: float) -> void:
	# frame the most interesting area: the human base, or the biggest fight
	var focus: Vector2 = md.starts[0]
	var best := 0
	for u in units:
		if u.state == Unit.ATTACK and u.pid > 0:
			var n := units_near(u.pos2(), 8.0).size()
			if n > best and tt > 400:
				best = n
				focus = u.pos2()
	var mine: Array = units.filter(func(u): return u.pid == human and u.cls == "worker")
	if tt < 100 and not mine.is_empty():
		ctl.set_selection(mine.slice(0, 4))
	else:
		var near: Array = units.filter(func(u): return u.pos2().distance_to(focus) < 8 and u.pid > 0)
		ctl.set_selection(near.filter(func(u): return u.pid == near[0].pid) if not near.is_empty() else [])
	if "--champshot" in OS.get_cmdline_user_args():
		var best_c = null
		var bn := -1
		for i in range(1, players.size()):
			var ch = players[i].champ
			if ch != null and is_instance_valid(ch) and ch.alive:
				var n := area_targets(ch.pos2(), 10.0, i).size()
				if n > bn:
					bn = n
					best_c = ch
		if best_c:
			focus = best_c.pos2()
			ctl.set_selection([best_c])
	cam.center_on(focus)
	cam.dist = 30.0 if not "--close" in OS.get_cmdline_user_args() else 15.0
	cam.target_dist = cam.dist
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := OS.get_user_data_dir() + "/shot_%d.png" % int(tt)
	img.save_png(path)
	print("saved ", path)
	RenderingServer.render_loop_enabled = false


var _report_t := 0.0
var prof := {}
func _autotest_report() -> void:
	if elapsed < _report_t:
		return
	_report_t += 60.0
	var line := "[t=%4ds fps=%d units=%d bld=%d proj=%d res=%d]" % [elapsed, Engine.get_frames_per_second(), units.size(), buildings.size(), projectiles.size(), resources.size()]
	for i in range(1, players.size()):
		var p: PlayerData = players[i]
		var nu := 0
		var nb := 0
		for u in units:
			if u.pid == i:
				nu += 1
		for b in buildings:
			if b.pid == i:
				nb += 1
		var st := {}
		for u in units:
			if u.pid == i and u.cls == "worker":
				var key: String = ["idle","move","atk","gath","ret","build","amove"][u.state] + ("-" + u.gtype if u.state in [Unit.GATHER, Unit.RETURN] else "")
				st[key] = st.get(key, 0) + 1
		line += "\n    P%d workers %s\n   " % [i, str(st)]
		if p.champ_class != "":
			line += " [%s Lv%d xp%d pts%d ranks%s casts%d %s doctrines%s]" % [p.champ_class, p.champ_level, p.champ_xp, p.champ_points, str(p.champ_ranks), p.stats.get("casts", 0), "alive" if p.champ != null else "dead", str(p.passives)]
		line += " [garrisoned %d bell %s lost %d ups %s] " % [garrisoned_of(i).size(), p.bell, p.stats["lost"], str(p.techs.keys().filter(func(t): return t.begins_with("up_")))]
		line += " [recruited %d hired %d mercs %s] " % [p.stats.get("recruited", 0), p.stats.get("hired", 0), str(units.filter(func(u): return u.pid == i and u.def.get("merc", false)).map(func(u): return u.kind))]
		line += " P%d age%d pop%d/%d u%d b%d f%d w%d g%d m%d k%d%s" % [i, p.age, p.pop, p.pop_cap, nu, nb, p.res["food"], p.res["wood"], p.res["gold"], p.res["mana"], p.stats["killed"], " DEAD" if p.defeated else ""]
	line += "\n    camps stock: %s  open freeblade bands: %d" % [str(camps.map(func(c): return c.stock)), open_recruits().size()]
	print(line)
	print("   PROF ms: ", prof.keys().map(func(k): return "%s=%d" % [k, prof[k] / 1000]))
	prof.clear()
	if elapsed > GameSettings.autotest_time:
		print("AUTOTEST DONE")
		get_tree().quit()


func _rebuild_buckets() -> void:
	ubuckets.clear()
	for u in units:
		var k := Vector2i(int(u.position.x / BK), int(u.position.z / BK))
		if ubuckets.has(k):
			ubuckets[k].append(u)
		else:
			ubuckets[k] = [u]


func _bkeys(b: Building) -> Array:
	var out: Array = []
	var r: Rect2i = b.cells
	for bz in range(int(r.position.y / BK), int(r.end.y / BK) + 1):
		for bx in range(int(r.position.x / BK), int(r.end.x / BK) + 1):
			out.append(Vector2i(bx, bz))
	return out


func buildings_near(p: Vector2, r: float) -> Array:
	var out: Array = []
	for bz in range(int((p.y - r) / BK), int((p.y + r) / BK) + 1):
		for bx in range(int((p.x - r) / BK), int((p.x + r) / BK) + 1):
			var k := Vector2i(bx, bz)
			if bbuckets.has(k):
				for b in bbuckets[k]:
					if not (b in out):
						out.append(b)
	return out


func units_near(p: Vector2, r: float) -> Array:
	var out: Array = []
	var x0 := int((p.x - r) / BK)
	var x1 := int((p.x + r) / BK)
	var z0 := int((p.y - r) / BK)
	var z1 := int((p.y + r) / BK)
	for bz in range(z0, z1 + 1):
		for bx in range(x0, x1 + 1):
			var k := Vector2i(bx, bz)
			if ubuckets.has(k):
				out.append_array(ubuckets[k])
	return out


# ======================================================================= queries
func is_enemy(a: int, b: int) -> bool:
	if a == b:
		return false
	return players[a].team != players[b].team


func height_at(x: float, z: float) -> float:
	x = clampf(x, 0.0, size - 0.001)
	z = clampf(z, 0.0, size - 0.001)
	var ix := int(x)
	var iz := int(z)
	var fx := x - ix
	var fz := z - iz
	var h00 := md.h(ix, iz)
	var h10 := md.h(ix + 1, iz)
	var h01 := md.h(ix, iz + 1)
	var h11 := md.h(ix + 1, iz + 1)
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fz)


func cell_ok(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= size or c.y >= size:
		return false
	var i := c.y * size + c.x
	return terrain_walk[i] == 1 and path_occ[i] == 0


func walkable_world(p: Vector2) -> bool:
	return cell_ok(Vector2i(int(floor(p.x)), int(floor(p.y))))


func nearest_walkable(c: Vector2i, maxr: int, bias: Vector2i) -> Vector2i:
	if cell_ok(c):
		return c
	for r in range(1, maxr + 1):
		var best := Vector2i(-1, -1)
		var bd := 1e9
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dz) != r:
					continue
				var cc := c + Vector2i(dx, dz)
				if cell_ok(cc):
					var d := Vector2(cc - bias).length_squared()
					if d < bd:
						bd = d
						best = cc
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var tp0 := Time.get_ticks_usec()
	var r := _find_path(from, to)
	prof["path"] = prof.get("path", 0) + Time.get_ticks_usec() - tp0
	prof["npath"] = prof.get("npath", 0) + 1000
	return r


func _find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var fc := Vector2i(int(from.x), int(from.y))
	var tc := Vector2i(int(to.x), int(to.y))
	var a := nearest_walkable(fc, 8, tc)
	var b := nearest_walkable(tc, 14, fc)
	if a.x < 0 or b.x < 0:
		return PackedVector2Array([to])
	var ids: Array[Vector2i] = astar.get_id_path(a, b, true)
	if ids.is_empty():
		return PackedVector2Array([to])
	var pts := PackedVector2Array()
	for c in ids:
		pts.append(Vector2(c.x + 0.5, c.y + 0.5))
	if b == tc and ids[ids.size() - 1] == b:
		pts[pts.size() - 1] = to
	# string-pull the grid path
	var out := PackedVector2Array()
	var anchor := from
	for i in range(1, pts.size()):
		if not _los(anchor, pts[i]):
			out.append(pts[i - 1])
			anchor = pts[i - 1]
	out.append(pts[pts.size() - 1])
	return out


func _los(a: Vector2, b: Vector2) -> bool:
	var d := b - a
	var l := d.length()
	var steps := int(l / 0.5) + 1
	var perp := d.orthogonal().normalized() * 0.3
	var inv := 1.0 / steps
	var sz := size
	for i in range(1, steps + 1):
		var p := a + d * (i * inv)
		var q := p + perp
		var r := p - perp
		var i1 := int(q.y) * sz + int(q.x)
		var i2 := int(r.y) * sz + int(r.x)
		if q.x < 0 or q.y < 0 or r.x < 0 or r.y < 0 or q.x >= sz or q.y >= sz or r.x >= sz or r.y >= sz:
			return false
		if terrain_walk[i1] == 0 or path_occ[i1] != 0 or terrain_walk[i2] == 0 or path_occ[i2] != 0:
			return false
	return true


func find_enemy(p: Vector2, r: float, owner_id: int, attacker: Entity, units_only: bool = false) -> Entity:
	var best: Entity = null
	var bd := 1e9
	var hteam: int = players[human].team
	var ua: Unit = attacker as Unit
	var unit_att := ua != null
	var peace := elapsed < peace_until and owner_id > 0
	for u in units_near(p, r + 2.0):
		if not u.alive or not is_enemy(owner_id, u.pid):
			continue
		if u.recruit_group >= 0:
			continue
		if peace and u.pid > 0:
			continue
		if unit_att and not ua.can_hit(u):
			continue
		if players[owner_id].team == hteam and not u.seen:
			continue
		var d: float = u.edge_dist(p)
		if d <= r and d < bd:
			bd = d
			best = u
	if best or units_only:
		return best
	if peace:
		return best
	for b in buildings_near(p, r + 3.0):
		if not b.alive or not is_enemy(owner_id, b.pid):
			continue
		if unit_att and not ua.can_hit(b):
			continue
		var d: float = b.edge_dist(p)
		if b.kind == "wall":
			d += 3.0
		if d <= r and d < bd:
			bd = d
			best = b
	return best


func wounded_ally_near(p: Vector2, r: float, owner_id: int, me: Entity) -> Entity:
	var best: Entity = null
	var bd := 1e9
	for u in units_near(p, r):
		if u == me or not u.alive or is_enemy(owner_id, u.pid) or u.pid == 0 or u.hp >= u.max_hp:
			continue
		var d: float = u.pos2().distance_to(p)
		if d <= r and d < bd:
			bd = d
			best = u
	return best


func _add_resource(n: ResourceNode) -> void:
	resources.append(n)
	var k := Vector2i(int(n.position.x / BK), int(n.position.z / BK))
	if not rbuckets.has(k):
		rbuckets[k] = []
	rbuckets[k].append(n)
	var c := Vector2i(int(n.position.x), int(n.position.z))
	n.cells = Rect2i(c.x - n.rcells, c.y - n.rcells, n.rcells * 2 + 1, n.rcells * 2 + 1)
	_mark_cells(n.cells, 1, true)


func remove_resource(n: ResourceNode) -> void:
	resources.erase(n)
	var k := Vector2i(int(n.position.x / BK), int(n.position.z / BK))
	if rbuckets.has(k):
		rbuckets[k].erase(n)
	_mark_cells(n.cells, -1, true)


func find_resource(p: Vector2, rtype: String, r: float):
	var best = null
	var bd := 1e9
	var x0 := int((p.x - r) / BK)
	var x1 := int((p.x + r) / BK)
	var z0 := int((p.y - r) / BK)
	var z1 := int((p.y + r) / BK)
	for bz in range(z0, z1 + 1):
		for bx in range(x0, x1 + 1):
			var k := Vector2i(bx, bz)
			if not rbuckets.has(k):
				continue
			for n in rbuckets[k]:
				if n.depleted or n.rtype != rtype:
					continue
				var d: float = n.pos2().distance_to(p)
				if d <= r and d < bd:
					bd = d
					best = n
	return best


func resources_near(p: Vector2, r: float) -> Array:
	var out: Array = []
	for bz in range(int((p.y - r) / BK), int((p.y + r) / BK) + 1):
		for bx in range(int((p.x - r) / BK), int((p.x + r) / BK) + 1):
			var k := Vector2i(bx, bz)
			if rbuckets.has(k):
				for n in rbuckets[k]:
					if not n.depleted and n.pos2().distance_to(p) <= r:
						out.append(n)
	return out


func free_farm_near(p: Vector2, owner_id: int, r: float):
	var best = null
	var bd := 1e9
	for b in buildings:
		if b.kind != "farm" or b.pid != owner_id or not b.alive or not b.complete:
			continue
		if b.farmer != null and is_instance_valid(b.farmer) and b.farmer.alive and b.farmer.node == b:
			continue
		var d: float = b.pos2().distance_to(p)
		if d < r and d < bd:
			bd = d
			best = b
	return best


func nearest_dropoff(p: Vector2, owner_id: int) -> Building:
	var best: Building = null
	var bd := 1e9
	for b in buildings:
		if b.pid == owner_id and b.alive and b.complete and b.def.get("dropoff", false):
			var d: float = b.edge_dist(p)
			if d < bd:
				bd = d
				best = b
	return best


func unfinished_near(p: Vector2, owner_id: int, r: float) -> Building:
	var best: Building = null
	var bd := 1e9
	for b in buildings:
		if b.pid == owner_id and b.alive and (not b.complete):
			var d: float = b.pos2().distance_to(p)
			if d < r and d < bd:
				bd = d
				best = b
	return best


func count_units(owner_id: int, k: String, include_queued: bool = false) -> int:
	var n := 0
	for u in units:
		if u.pid == owner_id and u.kind == k and u.alive:
			n += 1
	if include_queued:
		for b in buildings:
			if b.pid == owner_id and b.alive:
				n += b.queued_count(k)
	return n


func units_of(owner_id: int) -> Array:
	var out: Array = []
	for u in units:
		if u.pid == owner_id and u.alive:
			out.append(u)
	return out


func buildings_of(owner_id: int) -> Array:
	var out: Array = []
	for b in buildings:
		if b.pid == owner_id and b.alive:
			out.append(b)
	return out


# ======================================================================= placement
static func footprint(s: float, p: Vector2) -> Rect2i:
	var n := int(ceil(s - 0.01))
	var x0 := int(round(p.x - n * 0.5))
	var z0 := int(round(p.y - n * 0.5))
	return Rect2i(x0, z0, n, n)


static func snap_pos(s: float, p: Vector2) -> Vector2:
	var n := int(ceil(s - 0.01))
	if n % 2 == 1:
		return Vector2(floor(p.x) + 0.5, floor(p.y) + 0.5)
	return Vector2(round(p.x), round(p.y))


func can_place(k: String, p: Vector2, owner_id: int, margin: int = 0) -> bool:
	var d: Dictionary = Defs.BUILDINGS[k]
	var r := footprint(d["size"], p)
	var rm := r.grow(margin)
	if rm.position.x < 2 or rm.position.y < 2 or rm.end.x > size - 2 or rm.end.y > size - 2:
		return false
	for z in range(rm.position.y, rm.end.y):
		for x in range(rm.position.x, rm.end.x):
			var i := z * size + x
			if terrain_walk[i] == 0 or place_occ[i] > 0:
				return false
	if fog_on and players[owner_id].team == players[human].team:
		for z in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if not fog_explored(Vector2(x, z)):
					return false
	var hmin := 1e9
	var hmax := -1e9
	for z in range(r.position.y, r.end.y + 1):
		for x in range(r.position.x, r.end.x + 1):
			var h := md.h(x, z)
			hmin = minf(hmin, h)
			hmax = maxf(hmax, h)
	if hmax - hmin > 1.8:
		return false
	# not on top of enemy units
	for u in units_near(p, d["size"]):
		if u.alive and is_enemy(owner_id, u.pid) and r.has_point(Vector2i(int(u.position.x), int(u.position.z))):
			return false
	return true


func _mark_cells(r: Rect2i, delta: int, blocks_path: bool) -> void:
	for z in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if x < 0 or z < 0 or x >= size or z >= size:
				continue
			var i := z * size + x
			place_occ[i] += delta
			if blocks_path:
				path_occ[i] += delta
				astar.set_point_solid(Vector2i(x, z), terrain_walk[i] == 0 or path_occ[i] > 0)


func spawn_building(k: String, owner_id: int, p: Vector2, done: bool, rot: float = 0.0) -> Building:
	var b := Building.new()
	b.setup(self, k, owner_id, done)
	var d: Dictionary = Defs.BUILDINGS[k]
	b.cells = footprint(d["size"], p)
	var hsum := 0.0
	var hmin := 1e9
	var cnt := 0
	for z in range(b.cells.position.y, b.cells.end.y + 1):
		for x in range(b.cells.position.x, b.cells.end.x + 1):
			var h := md.h(clampi(x, 0, size), clampi(z, 0, size))
			hsum += h
			hmin = minf(hmin, h)
			cnt += 1
	var avg := hsum / maxf(cnt, 1)
	b.position = Vector3(p.x, lerpf(hmin, avg, 0.6) if k != "farm" else avg, p.y)
	b.rotation.y = rot
	add_child(b)
	buildings.append(b)
	for bk in _bkeys(b):
		if not bbuckets.has(bk):
			bbuckets[bk] = []
		bbuckets[bk].append(b)
	var blocks: bool = not d.get("walkable", false) and not d.get("gate", false)
	_mark_cells(b.cells, 1, blocks)
	if d.get("gate", false):
		_register_gate(b, true)
	if not d.get("walkable", false):
		_push_units_out(b.cells)
	if done:
		on_building_complete(b, true)
	return b


func _push_units_out(r: Rect2i) -> void:
	for u in units:
		if u.flying or not u.alive:
			continue
		var c := Vector2i(int(u.position.x), int(u.position.z))
		if r.has_point(c):
			var nc := nearest_walkable(c, 8, c)
			if nc.x >= 0:
				u.position.x = nc.x + 0.5
				u.position.z = nc.y + 0.5


## Pays for and lays a foundation; assigns builders. Returns the building or null.
func place_building(owner_id: int, k: String, p: Vector2, builders: Array, rot: float = 0.0) -> Building:
	var d: Dictionary = Defs.BUILDINGS[k]
	var pl: PlayerData = players[owner_id]
	if pl.age < d["age"]:
		return null
	p = snap_pos(d["size"], p)
	if not can_place(k, p, owner_id):
		return null
	if not pl.pay(d["cost"]):
		return null
	var b := spawn_building(k, owner_id, p, false, rot)
	for u in builders:
		if is_instance_valid(u) and u.alive and u.cls == "worker":
			u.order_build(b)
	return b


func spawn_unit(k: String, owner_id: int, p: Vector2, inst: Unit = null) -> Unit:
	var u := inst if inst != null else Unit.new()
	u.setup(self, k, owner_id)
	var c := Vector2i(int(p.x), int(p.y))
	if not u.flying and not cell_ok(c):
		var nc := nearest_walkable(c, 10, c)
		if nc.x >= 0:
			p = Vector2(nc.x + 0.5, nc.y + 0.5)
	p.x = clampf(p.x, 1, size - 1)
	p.y = clampf(p.y, 1, size - 1)
	u.position = Vector3(p.x, height_at(p.x, p.y) + u.fly_h, p.y)
	u.home = p
	add_child(u)
	units.append(u)
	if owner_id > 0:
		players[owner_id].pop += int(u.def["pop"])
		if inst == null:
			players[owner_id].stats["trained"] += 1
	if fog_on and players[owner_id].team != players[human].team:
		u.seen = fog_visible(p)
		u.visible = u.seen
	return u


func spawn_champion(owner_id: int, p: Vector2) -> Champion:
	var pl: PlayerData = players[owner_id]
	var c := Champion.new()
	var cd: Dictionary = Defs.CHAMPIONS[pl.champ_class]
	spawn_unit(cd["unit"], owner_id, p, c)
	c.init_champion(pl.champ_class)
	pl.champ = c
	pl.champ_respawn = -1.0
	spawn_fx("levelup", c.position, 1.0, Color.WHITE)
	return c


func _update_champions() -> void:
	for i in range(1, players.size()):
		var p: PlayerData = players[i]
		if p.champ_class == "" or p.defeated or p.champ != null or p.champ_respawn < 0.0:
			continue
		if elapsed < p.champ_respawn:
			continue
		var th: Building = null
		for b in buildings:
			if b.pid == i and b.alive and b.complete and b.kind == "town_hall":
				th = b
				break
		if th == null:
			p.champ_respawn = elapsed + 5.0
			continue
		var c := spawn_champion(i, th.pos2() + Vector2(0, th.size * 0.5 + 1.5))
		if p.human and hud:
			hud.message("Your %s has returned to the Town Hall." % c.cdef["name"], Color(1, 0.85, 0.35))


func grant_xp(victim: Entity, killer: Entity) -> void:
	var amount: float
	if victim is Unit:
		amount = 8.0 + victim.max_hp / 8.0
		if victim is Champion:
			amount += 80.0 + 25.0 * victim.level()
	else:
		amount = 20.0 + victim.max_hp / 60.0
	var kpid := killer.pid if killer != null and is_instance_valid(killer) else -1
	for i in range(1, players.size()):
		var c = players[i].champ
		if c == null or not is_instance_valid(c) or not c.alive:
			continue
		if c == killer:
			c.add_xp(amount)
		elif kpid >= 0 and not is_enemy(kpid, i) and kpid > 0 and c.pos2().distance_to(victim.pos2()) < 20.0 and is_enemy(i, victim.pid):
			c.add_xp(amount * 0.5)


func choose_passive(owner_id: int, id: String) -> bool:
	var p: PlayerData = players[owner_id]
	if not (id in p.next_passive_options()):
		return false
	p.passives.append(id)
	var m: Dictionary = p.mods
	match id:
		"drill": m["inf_mult"] *= 1.15
		"eagle_eye":
			m["ranged_range"] += 1.0
			m["range"] += 1.0
			m["ranged_mult"] *= 1.10
		"quartermaster":
			for r in Defs.RES:
				m[r] += 0.12
		"shield_wall":
			m["armor"] += 1.0
			m["parmor"] += 1.0
		"swift_march": m["speed_mult"] *= 1.12
		"field_medic": m["regen"] += 0.6
		"siege_masters": m["siege_mult"] *= 1.35
		"veterans": _scale_hp(owner_id, 1.15)
		"arcane_attunement":
			m["magic"] += 0.25
			m["mana"] += 0.2
		"cavalry_doctrine":
			m["cav_mult"] *= 1.2
			m["cav_speed"] *= 1.1
		"legendary":
			m["atk_mult"] *= 1.1
			_scale_hp(owner_id, 1.1)
	if owner_id == human and hud:
		hud.message("Doctrine adopted: %s" % Defs.PASSIVES[id]["name"], Color(1, 0.85, 0.4))
	return true


func _scale_hp(owner_id: int, f: float) -> void:
	players[owner_id].mods["hp_mult"] *= f
	for u in units:
		if u.pid == owner_id and u.alive:
			u.max_hp *= f
			u.hp *= f


func allies_near(p: Vector2, r: float, owner_id: int) -> Array:
	var out: Array = []
	for u in units_near(p, r + 1.0):
		if u.alive and u.pid > 0 and not is_enemy(owner_id, u.pid) and u.pos2().distance_to(p) <= r:
			out.append(u)
	return out


## Enemy units and buildings whose edge lies within r of p (abilities hit flyers too).
func area_targets(p: Vector2, r: float, owner_id: int) -> Array:
	var out: Array = []
	for u in units_near(p, r + 2.0):
		if u.alive and is_enemy(owner_id, u.pid) and u.edge_dist(p) <= r and u.recruit_group < 0:
			out.append(u)
	for b in buildings_near(p, r + 3.0):
		if b.alive and is_enemy(owner_id, b.pid) and b.edge_dist(p) <= r:
			out.append(b)
	return out


func spawn_area(k: String, p: Vector3, owner_id: int, r: float, d: float, v: float, src: Entity) -> void:
	var a := AreaEffect.new()
	add_child(a)
	a.setup(self, k, p, owner_id, r, d, v, src)
	areas.append(a)


# ======================================================================= upgrade lines
## The unit definition this player currently trains for a kind (base stats merged with upgrades).
func unit_def(owner_id: int, k: String) -> Dictionary:
	if owner_id >= 0 and owner_id < players.size():
		var ud: Dictionary = players[owner_id].unit_defs
		if ud.has(k):
			return ud[k]
	return Defs.UNITS[k]


func apply_upgrade(owner_id: int, tech_id: String, update_units: bool) -> void:
	var t: Dictionary = Defs.TECHS[tech_id]
	var line: String = t["line"]
	var nd: Dictionary = unit_def(owner_id, line).duplicate(true)
	for k in t["stats"]:
		nd[k] = t["stats"][k]
	nd["tier"] = int(t["tier"])
	nd["desc"] = Defs.UNITS[line]["desc"]
	players[owner_id].unit_defs[line] = nd
	if not update_units:
		return
	var all: Array = units.duplicate()
	for b in buildings:
		all.append_array(b.garrison)
	for u in all:
		if u.pid == owner_id and u.kind == line and u.alive:
			u.set_def(nd)
			if u.visible:
				spawn_fx("levelup", u.position, 0.6, Color.WHITE)


# ======================================================================= gates
func _register_gate(b: Building, on: bool) -> void:
	for z in range(b.cells.position.y, b.cells.end.y):
		for x in range(b.cells.position.x, b.cells.end.x):
			var c := Vector2i(x, z)
			if on:
				gate_cells[c] = b
				# paths may cross gates, but prefer going around so enemies don't all queue at one
				if astar.is_in_boundsv(c):
					astar.set_point_weight_scale(c, 6.0)
			elif gate_cells.get(c) == b:
				gate_cells.erase(c)
				if astar.is_in_boundsv(c):
					astar.set_point_weight_scale(c, 1.0)


## The enemy gate standing at p that stops a unit of this owner, or null.
func gate_blocks(p: Vector2, owner_id: int) -> Building:
	if gate_cells.is_empty():
		return null
	var c := Vector2i(int(floor(p.x)), int(floor(p.y)))
	var b = gate_cells.get(c)
	if b != null and is_instance_valid(b) and b.alive and is_enemy(owner_id, b.pid):
		return b
	return null


func convert_to_gate(wall: Building) -> Building:
	var p: PlayerData = players[wall.pid]
	var d: Dictionary = Defs.BUILDINGS["gate"]
	if not wall.alive or wall.kind != "wall" or not wall.complete or not p.pay(d["cost"]):
		return null
	var frac: float = wall.hp / wall.max_hp
	var pos := wall.pos2()
	var owner_id := wall.pid
	# remove the wall without destruction effects
	wall.alive = false
	buildings.erase(wall)
	for k in _bkeys(wall):
		if bbuckets.has(k):
			bbuckets[k].erase(wall)
	_mark_cells(wall.cells, -1, true)
	if ctl:
		ctl.on_entity_removed(wall)
	wall.queue_free()
	var g := spawn_building("gate", owner_id, pos, true, wall.rotation.y)
	g.hp = g.max_hp * frac
	return g


# ======================================================================= garrisons
func enter_garrison(u: Unit, b: Building) -> bool:
	if not b.alive or not b.complete or b.garrison.size() >= b.capacity() or not u.alive:
		return false
	units.erase(u)
	u.garrison_in = b
	u.visible = false
	u.path = PackedVector2Array()
	u.state = Unit.IDLE
	b.garrison.append(u)
	if ctl:
		ctl.on_entity_removed(u)
	return true


func exit_garrison(u: Unit, b: Building) -> void:
	b.garrison.erase(u)
	u.garrison_in = null
	var toward: Vector2 = b.rally if b.rally != Vector2.INF else Vector2(size, size) * 0.5
	var dir := (toward - b.pos2()).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(0, 1)
	dir = dir.rotated(randf_range(-0.9, 0.9))
	var sp := b.pos2() + dir * (b.size * 0.5 + 1.0)
	var c := nearest_walkable(Vector2i(int(sp.x), int(sp.y)), 8, Vector2i(int(sp.x), int(sp.y)))
	if c.x >= 0:
		sp = Vector2(c.x + 0.5, c.y + 0.5)
	u.position = Vector3(sp.x, height_at(sp.x, sp.y) + u.fly_h, sp.y)
	u.visible = true
	units.append(u)
	u.state = Unit.IDLE
	if u.cls == "worker" and u.pre_node != null and is_instance_valid(u.pre_node) and not (u.pre_node is ResourceNode and u.pre_node.depleted):
		u.order_gather(u.pre_node)
	elif u.cls == "worker" and u.gtype != "":
		var nn = free_farm_near(u.pos2(), u.pid, 20.0) if u.gtype == "food" else null
		if nn == null:
			nn = find_resource(u.pos2(), u.gtype, 25.0)
		if nn != null:
			u.order_gather(nn)
	elif u.cls != "worker" and b.rally != Vector2.INF:
		u.order_move(b.rally + Vector2(randf() - 0.5, randf() - 0.5) * 2.0)


func garrison_space(b: Building, reserved: Dictionary) -> int:
	return b.capacity() - b.garrison.size() - reserved.get(b, 0)


## Order units into the nearest garrisonable buildings with room (Town Bell, or a group order).
func send_to_shelter(us: Array, owner_id: int, only: Building = null) -> int:
	var shelters: Array = []
	for b in buildings:
		if b.pid == owner_id and b.alive and b.complete and b.capacity() > 0 and (only == null or b == only):
			shelters.append(b)
	var reserved := {}
	for u in units:
		if u.state == Unit.GARRISON and u.gtarget != null and is_instance_valid(u.gtarget):
			reserved[u.gtarget] = reserved.get(u.gtarget, 0) + 1
	var sent := 0
	for u in us:
		if not u.alive or u.garrison_in != null:
			continue
		var best: Building = null
		var bd := 1e9
		for b in shelters:
			if garrison_space(b, reserved) <= 0:
				continue
			var d: float = b.pos2().distance_to(u.pos2())
			if d < bd:
				bd = d
				best = b
		if best == null:
			break
		reserved[best] = reserved.get(best, 0) + 1
		u.order_garrison(best)
		sent += 1
	return sent


func town_bell(owner_id: int) -> void:
	var p: PlayerData = players[owner_id]
	p.bell = true
	var workers: Array = units.filter(func(u): return u.pid == owner_id and u.alive and u.cls == "worker")
	var n := send_to_shelter(workers, owner_id)
	if owner_id == human and hud:
		Sfx.play("alert", -2.0)
		hud.message("Town Bell! %d peasants take shelter%s." % [n, "" if n >= workers.size() else " (no room for the rest)"], Color(1, 0.8, 0.4))


func all_clear(owner_id: int) -> void:
	players[owner_id].bell = false
	for b in buildings:
		if b.pid == owner_id and b.alive:
			for u in b.garrison.duplicate():
				if u.cls == "worker":
					exit_garrison(u, b)
	for u in units:
		if u.pid == owner_id and u.cls == "worker" and u.state == Unit.GARRISON:
			u.order_stop()
			if u.pre_node != null and is_instance_valid(u.pre_node):
				u.order_gather(u.pre_node)
	if owner_id == human and hud:
		hud.message("All clear - peasants return to work.", Color(0.7, 1, 0.7))


func garrisoned_of(owner_id: int) -> Array:
	var out: Array = []
	for b in buildings:
		if b.pid == owner_id:
			out.append_array(b.garrison)
	return out


# ======================================================================= freeblades
func register_recruit(u: Unit, gid: int) -> void:
	if not recruit_groups.has(gid):
		recruit_groups[gid] = {"pos": u.pos2(), "units": []}
	recruit_groups[gid]["units"].append(u)


func _check_recruits() -> void:
	for gid in recruit_groups.keys():
		var g: Dictionary = recruit_groups[gid]
		var members: Array = g["units"].filter(func(u): return is_instance_valid(u) and u.alive and u.recruit_group == gid)
		g["units"] = members
		if members.is_empty():
			continue
		var best_pid := -1
		var bd := 1e9
		for m in members:
			for u in units_near(m.pos2(), Defs.RECRUIT_REACH + 1.0):
				if u.pid > 0 and u.alive and u.recruit_group < 0:
					var d: float = u.pos2().distance_to(m.pos2())
					if d <= Defs.RECRUIT_REACH and d < bd:
						bd = d
						best_pid = u.pid
		if best_pid > 0:
			_claim_recruits(gid, members, best_pid)


func _claim_recruits(gid: int, members: Array, owner_id: int) -> void:
	var p: PlayerData = players[owner_id]
	var names: Array = []
	for m in members:
		m.change_owner(owner_id)
		p.pop += int(m.def["pop"])
		p.stats["recruited"] = p.stats.get("recruited", 0) + 1
		spawn_fx("levelup", m.position, 0.8, Color.WHITE)
		names.append(m.def["name"])
	recruit_groups[gid]["units"] = []
	if not hud:
		return
	if owner_id == human:
		Sfx.play("levelup", -4.0)
		hud.message("Freeblades join your cause: %s!" % ", ".join(names), Color(1, 0.88, 0.45))
	elif fog_visible(recruit_groups[gid]["pos"]) or not fog_on:
		hud.message("%s recruited a band of freeblades." % p.name, Color(0.95, 0.75, 0.5))
		hud.ping(recruit_groups[gid]["pos"])


## Unclaimed freeblade bands as [center, member count].
func open_recruits() -> Array:
	var out: Array = []
	for gid in recruit_groups:
		var g: Dictionary = recruit_groups[gid]
		var ms: Array = g["units"].filter(func(u): return is_instance_valid(u) and u.alive and u.recruit_group == gid)
		if not ms.is_empty():
			out.append([ms[0].pos2(), ms.size()])
	return out


func recalc_pop(owner_id: int) -> void:
	var p: PlayerData = players[owner_id]
	var cap := 0
	for b in buildings:
		if b.pid == owner_id and b.alive and b.complete:
			cap += int(b.def.get("pop", 0))
	p.pop_cap = mini(cap, p.max_pop)


# ======================================================================= combat
func spawn_projectile(k: String, from: Vector3, target: Entity, info: Dictionary) -> void:
	var pr := Projectile.new()
	add_child(pr)
	pr.setup(self, k, from, target, info)
	projectiles.append(pr)


func remove_projectile(pr: Projectile) -> void:
	projectiles.erase(pr)
	pr.queue_free()


func damage_vs(target: Entity, info: Dictionary) -> float:
	var dmg: float = info["atk"]
	var bonus: Dictionary = info["bonus"]
	if bonus.has(target.cls):
		dmg += bonus[target.cls]
	if target.is_building and info.has("owner") and info["owner"] > 0:
		dmg *= players[info["owner"]].mods["siege_mult"]
	match info["type"]:
		"melee": dmg -= target.armor_val()
		"pierce": dmg -= target.parmor_val()
		"magic": dmg -= target.armor_val() * 0.25
		"siege": dmg -= target.armor_val() * 0.5
	return maxf(1.0, dmg)


func apply_damage(target: Entity, info: Dictionary) -> void:
	if target == null or not is_instance_valid(target) or not target.alive:
		return
	if target is Unit and (target.garrison_in != null or target.recruit_group >= 0):
		return
	var src = info.get("src")
	if not is_instance_valid(src):
		src = null
	if elapsed < peace_until and target.pid > 0 and info["owner"] > 0:
		return
	target.take_damage(damage_vs(target, info), src)


func splash_damage(p: Vector3, r: float, info: Dictionary, primary: Entity) -> void:
	var owner_id: int = info["owner"]
	var p2 := Vector2(p.x, p.z)
	var hit_air := primary != null and is_instance_valid(primary) and primary.flying
	for u in units_near(p2, r + 1.5):
		if u.alive and is_enemy(owner_id, u.pid) and u.pos2().distance_to(p2) <= r + u.radius and u.recruit_group < 0:
			if u.flying and not hit_air:
				continue
			var mult := 1.0 if u == primary else 0.6
			var i2 := info.duplicate()
			i2["atk"] = info["atk"] * mult
			apply_damage(u, i2)
	for b in buildings_near(p2, r + 3.0):
		if b.alive and is_enemy(owner_id, b.pid) and b.edge_dist(p2) <= r * 0.6:
			apply_damage(b, info)


func on_attacked(victim: Entity, attacker: Entity) -> void:
	if victim.pid == human and attacker != null and is_instance_valid(attacker):
		var key := "b" if victim.is_building else "u"
		if elapsed - alert_t.get(key, -100.0) > 12.0:
			alert_t[key] = elapsed
			if hud:
				hud.message("Your %s is under attack!" % victim.display_name().to_lower(), Color(1, 0.4, 0.3))
				Sfx.play("alert", -4.0)
				hud.ping(victim.pos2())
	for ai in ais:
		if ai.pid == victim.pid:
			ai.on_attacked(victim, attacker)


func on_unit_died(u: Unit, killer: Entity) -> void:
	units.erase(u)
	grant_xp(u, killer)
	if u.pid > 0:
		players[u.pid].pop -= int(u.def["pop"])
		players[u.pid].stats["lost"] += 1
	if killer != null and is_instance_valid(killer) and killer.pid > 0:
		players[killer.pid].stats["killed"] += 1
		if "spoils" in players[killer.pid].passives and is_enemy(killer.pid, u.pid):
			players[killer.pid].refund({"gold": 6, "mana": 3})
		if u.def.has("bounty"):
			players[killer.pid].refund(u.def["bounty"])
			if killer.pid == human:
				hud.message("Bounty: %s" % Defs.cost_text(u.def["bounty"]), Color(1, 0.9, 0.4))
	if ctl:
		ctl.on_entity_removed(u)


func on_building_complete(b: Building, initial: bool = false) -> void:
	recalc_pop(b.pid)
	if not initial:
		players[b.pid].stats["built"] += 1
		if b.pid == human and hud:
			hud.message("%s complete." % b.def["name"], Color(0.7, 1, 0.7))
			Sfx.play("complete", -5.0)
	if b.rally == Vector2.INF and b.def.has("trains"):
		var c := (Vector2(size, size) * 0.5 - b.pos2()).normalized()
		b.rally = b.pos2() + c * (b.size * 0.5 + 2.5)


func on_building_died(b: Building, killer: Entity) -> void:
	buildings.erase(b)
	if killer != null:
		grant_xp(b, killer)
	for k in _bkeys(b):
		if bbuckets.has(k):
			bbuckets[k].erase(b)
	_mark_cells(b.cells, -1, not b.def.get("walkable", false) and not b.def.get("gate", false))
	if b.def.get("gate", false):
		_register_gate(b, false)
	recalc_pop(b.pid)
	if killer != null and is_instance_valid(killer) and killer.pid > 0:
		players[killer.pid].stats["razed"] += 1
	if b.pid == human and hud:
		hud.message("Your %s was destroyed!" % b.def["name"].to_lower(), Color(1, 0.35, 0.3))
	if ctl:
		ctl.on_entity_removed(b)


func finish_tech(owner_id: int, id: String) -> void:
	var p: PlayerData = players[owner_id]
	p.researching.erase(id)
	p.techs[id] = true
	var m: Dictionary = p.mods
	if Defs.TECHS[id].has("line"):
		apply_upgrade(owner_id, id, true)
	match id:
		"age2": p.age = 2
		"age3": p.age = 3
		"harvest_tools":
			m["food"] += 0.2
			m["wood"] += 0.2
		"deep_mining":
			m["gold"] += 0.2
			m["mana"] += 0.2
		"forged_blades": m["melee_atk"] += 2.0
		"fletching":
			m["pierce_atk"] += 1.0
			m["range"] += 1.0
		"plate_armor":
			m["armor"] += 2.0
			m["parmor"] += 1.0
		"masonry":
			m["bhp"] += 0.3
			for b in buildings:
				if b.pid == owner_id and b.alive:
					var f: float = b.hp / b.max_hp
					b.max_hp = b.def["hp"] * m["bhp"]
					b.hp = b.max_hp * f
		"arcane_focus": m["magic"] += 0.25
		"barding":
			m["knight_hp"] += 40.0
			for u in units:
				if u.pid == owner_id and u.kind == "knight":
					u.max_hp += 40.0
					u.hp += 40.0
	if owner_id == human and hud:
		Sfx.play("age_up" if id.begins_with("age") else "research", -3.0)
		hud.message("Research complete: %s" % Defs.TECHS[id]["name"].replace("Advance: ", ""), Color(0.6, 0.9, 1.0))
	elif id.begins_with("age") and hud and not players[owner_id].defeated:
		hud.message("%s has advanced to the %s." % [p.name, Defs.AGE_NAMES[p.age]], Color(0.9, 0.85, 0.6))


# ======================================================================= shrines & victory
func on_shrine_captured(s: Shrine) -> void:
	if not hud:
		return
	var p: PlayerData = players[s.owner_id]
	if s.owner_id == human:
		Sfx.play("shrine", -3.0)
		hud.message("You captured a Ley Shrine! (+mana)", Color(0.5, 0.95, 1.0))
	else:
		hud.message("%s captured a Ley Shrine." % p.name, Color(0.9, 0.7, 0.5))
	hud.ping(s.pos2())


func on_shrine_lost(s: Shrine, old: int) -> void:
	if old == human and hud:
		Sfx.play("alert", -6.0)
		hud.message("You lost control of a Ley Shrine!", Color(1, 0.5, 0.3))
		hud.ping(s.pos2())


func _update_control(delta: float) -> void:
	if shrines.is_empty():
		return
	var t := -1
	for s in shrines:
		if s.owner_id < 0:
			t = -1
			break
		var st: int = players[s.owner_id].team
		if t == -1:
			t = st
		elif t != st:
			t = -1
			break
	if t != control_team:
		control_team = t
		control_timer = CONTROL_HOLD_TIME
		if t >= 0 and hud:
			var mine: bool = t == players[human].team
			hud.message(("Your realm holds" if mine else "An enemy holds") + " every Ley Shrine! Dominion in 3:00.",
				Color(0.5, 1, 0.6) if mine else Color(1, 0.5, 0.4))
	if control_team >= 0:
		control_timer -= delta
		if control_timer <= 0.0:
			_end_game(control_team == players[human].team, "Ley Dominion")


func _is_dead(pid: int) -> bool:
	for u in units:
		if u.pid == pid and u.alive and not (u is Champion):
			return false
	for b in buildings:
		if b.pid == pid and b.alive and not (b.kind in ["wall", "house", "farm", "tower"]):
			return false
	return true


func _check_victory() -> void:
	if over:
		return
	for i in range(1, players.size()):
		var p: PlayerData = players[i]
		if not p.defeated and _is_dead(i):
			p.defeated = true
			p.champ_respawn = -1.0
			if p.champ != null and is_instance_valid(p.champ) and p.champ.alive:
				p.champ.die(null)
			if hud:
				hud.message("%s has been defeated!" % ("You have" if p.human else p.name), Color(1, 0.6, 0.3))
			for b in buildings.duplicate():
				if b.pid == i:
					b.die(null)
	if players[human].defeated:
		_end_game(false, "Conquest")
		return
	var hteam: int = players[human].team
	var enemies_left := false
	for i in range(1, players.size()):
		if not players[i].defeated and players[i].team != hteam:
			enemies_left = true
	if not enemies_left:
		_end_game(true, "Conquest")


func _end_game(won: bool, how: String) -> void:
	if over:
		return
	over = true
	if GameSettings.autotest and not "--uitest" in OS.get_cmdline_user_args():
		print("GAME OVER won=%s by %s at %ds" % [won, how, elapsed])
		_report_t = 0.0
		_autotest_report()
		get_tree().quit()
	if hud:
		hud.show_game_over(won, how)


func spawn_fx(k: String, p: Vector3, s: float, _c: Color) -> void:
	var m := MeshInstance3D.new()
	m.mesh = Models.mesh(k)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = p
	m.scale = Vector3.ONE * s * 0.3
	add_child(m)
	var tw := m.create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3.ONE * s, 0.35)
	if k == "heal_fx":
		tw.tween_property(m, "position:y", p.y + 1.5, 0.6)
	tw.chain().tween_callback(m.queue_free)


# ======================================================================= commands
func formation(center: Vector2, n: int, spacing: float = 1.3) -> Array:
	var out: Array = []
	var side := int(ceil(sqrt(n)))
	for i in n:
		var gx := i % side - (side - 1) * 0.5
		var gz := int(i / side) - (side - 1) * 0.5
		out.append(center + Vector2(gx, gz) * spacing)
	return out


func cmd_move(sel: Array, p: Vector2, amove: bool = false) -> void:
	var us: Array = sel.filter(func(e): return e is Unit and e.alive)
	var spots := formation(p, us.size(), 1.4)
	for i in us.size():
		us[i].order_move(spots[i], amove)


func cmd_smart(sel: Array, p: Vector2, target) -> void:
	var us: Array = sel.filter(func(e): return e is Unit and e.alive)
	if us.is_empty():
		return
	var owner_id: int = us[0].pid
	if target is Unit and target.recruit_group >= 0:
		cmd_move(us, target.pos2())
		return
	if target is Entity and target.alive:
		if is_enemy(owner_id, target.pid):
			for u in us:
				u.order_attack(target)
			return
		if target.pid == owner_id and target is Building:
			var b: Building = target
			var rest: Array = []
			for u in us:
				if u.cls == "worker":
					if not b.complete or b.hp < b.max_hp:
						u.order_build(b)
					elif b.kind == "farm":
						u.order_gather(b)
					elif b.def.get("dropoff", false) and u.carry > 0:
						u.order_return(b)
					else:
						rest.append(u)
				else:
					rest.append(u)
			if not rest.is_empty() and b.complete and b.capacity() > 0:
				send_to_shelter(rest, owner_id, b)
				rest = rest.filter(func(u): return u.state != Unit.GARRISON)
			if not rest.is_empty():
				cmd_move(rest, b.pos2() + (rest[0].pos2() - b.pos2()).normalized() * (b.size * 0.5 + 2.0))
			return
		if target is Unit and def_heals(us):
			for u in us:
				if u.def.has("heal"):
					u.order_attack(target)
				else:
					u.order_move(target.pos2())
			return
	if target is ResourceNode and not target.depleted:
		var rest: Array = []
		for u in us:
			if u.cls == "worker":
				u.order_gather(target)
			else:
				rest.append(u)
		if not rest.is_empty():
			cmd_move(rest, p)
		return
	cmd_move(us, p)


func def_heals(us: Array) -> bool:
	for u in us:
		if u.def.has("heal"):
			return true
	return false


func _notification(what: int) -> void:
	# phones: the OS may kill a backgrounded app, so save when we lose focus or close
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not over and not GameSettings.autotest and is_inside_tree() and hud != null:
			SaveGame.save(self, "autosave")


## Saves to the given slot (or the slot this game was last saved/loaded from) and remembers it.
func save_to(slot: String = "") -> bool:
	if slot == "":
		slot = save_slot if save_slot != "" and save_slot != "autosave" else "quick"
	var ok := SaveGame.save(self, slot)
	if ok:
		save_slot = slot
	return ok


func _exit_tree() -> void:
	if Sfx.game == self:
		Sfx.game = null


func quit_to_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	if main:
		main.show_menu()
