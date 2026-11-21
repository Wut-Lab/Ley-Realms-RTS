class_name Models
extends RefCounted
## Procedural low-poly models for every unit, building, resource and effect.

const SKIN := Color(0.93, 0.76, 0.6)
const WOOD := Color(0.52, 0.34, 0.19)
const DWOOD := Color(0.34, 0.22, 0.12)
const STONE := Color(0.64, 0.62, 0.58)
const DSTONE := Color(0.42, 0.4, 0.39)
const STEEL := Color(0.76, 0.78, 0.82)
const PLASTER := Color(0.88, 0.82, 0.68)
const LEATHER := Color(0.45, 0.3, 0.18)
const STRAW := Color(0.88, 0.76, 0.42)
const GOLD := Color(1.0, 0.82, 0.25)

const ENTITY_SHADER := """
shader_type spatial;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform float map_size = 128.0;
uniform float fog_on = 0.0;
varying vec3 lpos;
varying vec3 lnorm;
varying float mid;
%NOISE%
void vertex() {
	lpos = VERTEX;
	lnorm = NORMAL;
	mid = UV.x;
}
vec2 face_plane(vec3 p, vec3 n) {
	vec3 a = abs(n);
	if (a.y > a.x && a.y > a.z) { return p.xz; }
	if (a.x > a.z) { return p.zy; }
	return p.xy;
}
float surface(float m, vec3 p, vec3 n) {
	vec2 q = face_plane(p, n);
	if (m < 0.5) { return 1.0; }
	if (m < 1.5) {
		// stone bricks with mortar lines
		vec2 b = q * vec2(2.2, 4.4);
		b.x += floor(b.y) * 0.5;
		vec2 fb = fract(b);
		float mortar = smoothstep(0.0, 0.07, fb.x) * smoothstep(1.0, 0.93, fb.x) * smoothstep(0.0, 0.1, fb.y) * smoothstep(1.0, 0.9, fb.y);
		return mix(0.6, 0.86 + 0.24 * hash(floor(b)) + 0.06 * vnoise(q * 9.0), mortar);
	}
	if (m < 2.5) {
		// wooden planks with grain
		float w = q.x * 6.0 + q.y * 0.02;
		float cell = floor(w);
		float edge = smoothstep(0.0, 0.08, fract(w)) * smoothstep(1.0, 0.92, fract(w));
		float grain = 0.9 + 0.1 * sin(q.y * 28.0 + hash(vec2(cell, 1.0)) * 6.0 + sin(q.y * 6.0 + cell) * 2.0);
		return mix(0.66, (0.84 + 0.24 * hash(vec2(cell, 3.0))) * grain, edge);
	}
	if (m < 3.5) {
		// rough plaster
		return 0.9 + 0.1 * vnoise(q * 3.0) + 0.05 * vnoise(q * 14.0);
	}
	// overlapping roof shingles
	vec2 s = q * vec2(5.0, 7.0);
	s.x += floor(s.y) * 0.5;
	vec2 fs = fract(s);
	float rim = smoothstep(0.0, 0.18, fs.y) * smoothstep(0.0, 0.05, fs.x) * smoothstep(1.0, 0.95, fs.x);
	return mix(0.62, 0.86 + 0.2 * hash(floor(s)) - fs.y * 0.12, rim);
}
void fragment() {
	vec3 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float f = 1.0;
	if (fog_on > 0.5) { f = texture(fog_tex, w.xz / map_size).r; }
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	float glow = 1.0 - COLOR.a;
	c *= surface(mid, lpos, lnorm);
	ALBEDO = c * f * f;
	EMISSION = c * glow * 3.0 * f;
	ROUGHNESS = 0.82;
	SPECULAR = 0.5 * f;
}
"""

const NOISE_LIB := """
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * vnoise(p); p *= 2.03; a *= 0.5; }
	return v;
}
"""

const TERRAIN_SHADER := """
shader_type spatial;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform float map_size = 128.0;
uniform float fog_on = 0.0;
uniform vec3 rock_color = vec3(0.5, 0.47, 0.43);
uniform float cloud_on = 1.0;
uniform float hq = 1.0;
varying vec3 wpos;
varying vec3 wnorm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
%NOISE%
void fragment() {
	float f = 1.0;
	if (fog_on > 0.5) { f = texture(fog_tex, wpos.xz / map_size).r; }
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	// soften the saturation a little
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(lum), c, 0.78) * 0.93;
	// colour variation at three scales: broad meadows, patches, fine speckle
	float big = hq > 0.5 ? fbm(wpos.xz * 0.045) : vnoise(wpos.xz * 0.045);
	float mid = vnoise(wpos.xz * 0.35);
	float fine = vnoise(wpos.xz * 3.1);
	c *= 0.72 + 0.5 * big;
	c = mix(c, c * vec3(1.14, 1.05, 0.76), smoothstep(0.5, 0.8, mid) * 0.5);
	c = mix(c, c * vec3(0.8, 0.95, 0.86), smoothstep(0.55, 0.85, vnoise(wpos.xz * 0.12 + 7.0)) * 0.5);
	c *= 0.9 + 0.18 * fine;
	// layered rock strata on steep slopes
	float slope = 1.0 - clamp(wnorm.y, 0.0, 1.0);
	float rock = smoothstep(0.34, 0.55, slope);
	float strata = 0.78 + 0.28 * sin(wpos.y * 5.0 + vnoise(wpos.xz * 0.6) * 4.0);
	vec3 rc = pow(rock_color, vec3(2.2)) * strata * (0.88 + 0.24 * fine);
	c = mix(c, rc, rock * 0.85);
	// slow drifting cloud shadows
	if (cloud_on > 0.5) {
		float cl = smoothstep(0.5, 0.74, fbm(wpos.xz * 0.018 + vec2(TIME * 0.012, TIME * 0.007)));
		c *= 1.0 - 0.28 * cl;
	}
	ALBEDO = c * f * f;
	ROUGHNESS = 0.92 - rock * 0.15;
	SPECULAR = 0.35 * f;
}
"""

const WATER_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform float map_size = 128.0;
uniform float fog_on = 0.0;
uniform float water_level = 0.0;
uniform vec3 water_color = vec3(0.1, 0.3, 0.5);
uniform vec3 sky_color = vec3(0.7, 0.8, 0.9);
varying vec3 wpos;
%NOISE%
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(wpos.x * 0.35 + TIME * 1.1) * 0.05 + cos(wpos.z * 0.28 + TIME * 0.9) * 0.05;
}
void fragment() {
	float f = 1.0;
	if (fog_on > 0.5) { f = texture(fog_tex, wpos.xz / map_size).r; }
	// depth of water above the terrain at this point
	float h = texture(height_tex, (wpos.xz + 0.5) / (map_size + 1.0)).r;
	float d = max(water_level - h, 0.0);
	float dt = 1.0 - exp(-d * 0.9);
	vec3 shallow = mix(water_color, vec3(0.32, 0.74, 0.70), 0.5);
	vec3 deep = water_color * 0.42;
	vec3 col = mix(shallow, deep, dt);
	// rippling normals from a few moving waves
	vec2 p = wpos.xz;
	float t = TIME;
	vec2 g = vec2(
		cos(p.x * 0.9 + t * 1.3) * 0.9 + cos((p.x + p.y) * 1.7 - t * 1.9) * 0.5 + cos(p.x * 3.1 - t * 2.7) * 0.25,
		cos(p.y * 1.1 + t * 1.1) * 0.9 + cos((p.x - p.y) * 1.5 - t * 1.7) * 0.5 + cos(p.y * 2.9 + t * 2.3) * 0.25) * 0.07;
	vec3 n = normalize(vec3(-g.x, 1.0, -g.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	// reflect the sky at grazing angles
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	col = mix(col, sky_color, fr * 0.6);
	// foam along the shore, with lapping bands
	float fn = vnoise(p * 2.2 + vec2(t * 0.3, -t * 0.2));
	float shore = 1.0 - smoothstep(0.0, 0.3, d);
	float band = (sin(d * 16.0 - t * 2.2) * 0.5 + 0.5) * (1.0 - smoothstep(0.0, 0.8, d));
	float foam = clamp(smoothstep(0.4, 0.85, shore + fn * 0.45 - 0.2) + band * fn * 0.35, 0.0, 1.0) * 0.85;
	col = mix(col, vec3(0.88, 0.93, 0.94), foam);
	ALBEDO = pow(col, vec3(2.2)) * f * f;
	ALPHA = mix(1.0, clamp(mix(0.55, 0.93, dt) + foam * 0.5, 0.0, 1.0), f);
	ROUGHNESS = mix(0.06, 0.6, foam);
	METALLIC = 0.0;
	SPECULAR = 0.9 * f * (1.0 - foam);
}
"""

static var cache := {}


static func shader_code(src: String) -> String:
	return src.replace("%NOISE%", NOISE_LIB)

static var entity_mat: ShaderMaterial
static var ring_mats := {}
static var ghost_ok: StandardMaterial3D
static var ghost_bad: StandardMaterial3D


static func setup(fog_tex: Texture2D, map_size: float, fog_on: bool) -> void:
	if entity_mat == null:
		var sh := Shader.new()
		sh.code = shader_code(ENTITY_SHADER)
		entity_mat = ShaderMaterial.new()
		entity_mat.shader = sh
	entity_mat.set_shader_parameter("fog_tex", fog_tex)
	entity_mat.set_shader_parameter("map_size", map_size)
	entity_mat.set_shader_parameter("fog_on", 1.0 if fog_on else 0.0)
	if ghost_ok == null:
		ghost_ok = _ghost_mat(Color(0.3, 1.0, 0.4, 0.45))
		ghost_bad = _ghost_mat(Color(1.0, 0.25, 0.2, 0.45))


static func _ghost_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.no_depth_test = false
	return m


static func ring_mesh(r: float, col: Color) -> Mesh:
	var key := "ring|%.2f|%s" % [r, col.to_html()]
	if cache.has(key):
		return cache[key]
	var m := TorusMesh.new()
	m.inner_radius = r * 0.88
	m.outer_radius = r
	m.rings = 24
	m.ring_segments = 4
	var ck := col.to_html()
	if not ring_mats.has(ck):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = col
		ring_mats[ck] = mat
	m.material = ring_mats[ck]
	cache[key] = m
	return m


static func mesh(key: String, tc: Color = Color.WHITE, variant: int = 0) -> Mesh:
	var ck := "%s|%s|%d" % [key, tc.to_html(), variant]
	if cache.has(ck):
		return cache[ck]
	var mb := ModelBuilder.new()
	mb.textured = Defs.BUILDINGS.has(key) or key in ["gate_door", "merc_camp", "shrine"]
	_build(mb, key, tc, variant)
	var m := mb.commit(entity_mat)
	cache[ck] = m
	return m


static func _build(mb: ModelBuilder, key: String, tc: Color, v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) + v * 7919
	if v > 0 and (TIER_HEAD.has(key) or key == "dragon"):
		_tier_extras(mb, key, tc, v)
	match key:
		# ---------------- units ----------------
		"peasant":
			_legs(mb, LEATHER)
			mb.box(Vector3(0, 0.8, 0), Vector3(0.38, 0.5, 0.24), tc)
			mb.box(Vector3(0, 0.58, 0), Vector3(0.4, 0.08, 0.26), LEATHER)
			_arms(mb, tc.darkened(0.2))
			mb.sphere(Vector3(0, 1.19, 0), 0.15, SKIN)
			mb.cyl(Vector3(0, 1.3, 0), 0.1, 0.27, 0.12, STRAW, 10)
			mb.box(Vector3(0.27, 0.78, 0.28), Vector3(0.05, 0.05, 0.6), WOOD)
			mb.box(Vector3(0.27, 0.78, 0.58), Vector3(0.05, 0.22, 0.08), STEEL)
		"swordsman":
			_legs(mb, DSTONE)
			mb.box(Vector3(0, 0.82, 0), Vector3(0.42, 0.52, 0.27), tc)
			mb.box(Vector3(0, 0.9, 0.02), Vector3(0.36, 0.3, 0.26), STEEL)
			_arms(mb, STEEL.darkened(0.2))
			mb.sphere(Vector3(0, 1.22, 0), 0.16, SKIN)
			mb.sphere(Vector3(0, 1.28, 0), 0.18, STEEL, Vector3(1, 0.8, 1))
			mb.box(Vector3(0, 1.22, 0.16), Vector3(0.04, 0.14, 0.04), STEEL)
			mb.box(Vector3(0.3, 0.75, 0.42), Vector3(0.06, 0.06, 0.8), STEEL)
			mb.box(Vector3(0.3, 0.75, 0.05), Vector3(0.18, 0.05, 0.05), GOLD)
			mb.box(Vector3(-0.32, 0.8, 0.12), Vector3(0.06, 0.55, 0.42), tc)
			mb.box(Vector3(-0.35, 0.8, 0.12), Vector3(0.04, 0.6, 0.47), STEEL.darkened(0.3))
		"spearman":
			_legs(mb, LEATHER)
			mb.box(Vector3(0, 0.82, 0), Vector3(0.4, 0.5, 0.25), tc)
			_arms(mb, tc.darkened(0.25))
			mb.sphere(Vector3(0, 1.2, 0), 0.15, SKIN)
			mb.cone(Vector3(0, 1.38, 0), 0.19, 0.28, STEEL, 8)
			mb.box(Vector3(0.28, 1.05, 0.12), Vector3(0.05, 2.1, 0.05), WOOD)
			mb.cone(Vector3(0.28, 2.2, 0.12), 0.07, 0.25, STEEL, 4)
			mb.cyl(Vector3(-0.3, 0.82, 0.08), 0.26, 0.26, 0.06, tc.darkened(0.3), 10, Vector3(0, 0, PI / 2))
		"archer":
			_legs(mb, LEATHER)
			mb.box(Vector3(0, 0.82, 0), Vector3(0.38, 0.5, 0.24), Color(0.3, 0.45, 0.22))
			mb.box(Vector3(0, 0.82, 0.01), Vector3(0.2, 0.5, 0.24), tc)
			_arms(mb, Color(0.3, 0.45, 0.22))
			mb.sphere(Vector3(0, 1.2, 0), 0.15, SKIN)
			mb.cone(Vector3(0, 1.36, -0.03), 0.2, 0.42, Color(0.25, 0.38, 0.18), 8)
			mb.box(Vector3(-0.32, 0.9, 0.18), Vector3(0.05, 1.1, 0.06), WOOD, Vector3(0.15, 0, 0))
			mb.box(Vector3(-0.32, 0.9, 0.2), Vector3(0.01, 1.05, 0.01), Color(0.9, 0.9, 0.85))
			mb.cyl(Vector3(0.1, 0.95, -0.17), 0.08, 0.08, 0.5, LEATHER, 6, Vector3(0.3, 0, 0))
		"warden":
			_legs(mb, GOLD.darkened(0.3), 1.15)
			mb.box(Vector3(0, 0.98, 0), Vector3(0.5, 0.62, 0.32), GOLD.darkened(0.15))
			mb.box(Vector3(0, 0.98, -0.2), Vector3(0.5, 0.9, 0.05), tc)
			mb.box(Vector3(0, 0.7, 0), Vector3(0.52, 0.1, 0.34), LEATHER)
			mb.box(Vector3(-0.33, 1.0, 0), Vector3(0.14, 0.5, 0.15), GOLD.darkened(0.3))
			mb.box(Vector3(0.33, 1.0, 0.05), Vector3(0.14, 0.5, 0.15), GOLD.darkened(0.3), Vector3(-0.4, 0, 0))
			mb.sphere(Vector3(0, 1.46, 0), 0.18, SKIN)
			mb.sphere(Vector3(0, 1.52, 0), 0.2, GOLD, Vector3(1, 0.85, 1))
			mb.box(Vector3(0, 1.75, -0.03), Vector3(0.05, 0.25, 0.3), tc)
			mb.box(Vector3(0.36, 1.0, 0.55), Vector3(0.08, 0.08, 1.1), Color(0.8, 0.9, 1.0, 0.5))
			mb.box(Vector3(0.36, 1.0, 0.05), Vector3(0.25, 0.06, 0.06), GOLD)
			mb.sphere(Vector3(0, 1.05, 0.17), 0.06, Color(0.4, 0.9, 1.0, 0.2))
		"knight":
			var hc := Color(0.45, 0.32, 0.22)
			mb.box(Vector3(0, 0.95, 0), Vector3(0.48, 0.5, 1.25), hc)
			mb.box(Vector3(0, 0.88, 0), Vector3(0.54, 0.38, 1.3), tc)
			for lx in [-0.15, 0.15]:
				for lz in [-0.45, 0.45]:
					mb.box(Vector3(lx, 0.35, lz), Vector3(0.12, 0.7, 0.12), hc.darkened(0.2))
			mb.box(Vector3(0, 1.3, 0.62), Vector3(0.24, 0.5, 0.26), hc, Vector3(-0.6, 0, 0))
			mb.box(Vector3(0, 1.48, 0.85), Vector3(0.2, 0.2, 0.42), hc)
			mb.box(Vector3(0, 0.9, -0.68), Vector3(0.08, 0.5, 0.08), Color(0.15, 0.1, 0.08), Vector3(0.5, 0, 0))
			mb.box(Vector3(0, 1.6, -0.05), Vector3(0.36, 0.5, 0.26), STEEL)
			mb.box(Vector3(0, 1.55, -0.05), Vector3(0.38, 0.25, 0.28), tc)
			mb.sphere(Vector3(0, 2.0, -0.05), 0.17, STEEL)
			mb.box(Vector3(0.26, 1.6, 0.6), Vector3(0.06, 0.06, 1.8), WOOD)
			mb.cone(Vector3(0.26, 1.6, 1.6), 0.06, 0.25, STEEL, 4, Vector3(PI / 2, 0, 0))
			mb.box(Vector3(-0.28, 1.55, 0.05), Vector3(0.05, 0.45, 0.35), tc.darkened(0.2))
		"mage":
			mb.cyl(Vector3(0, 0.55, 0), 0.16, 0.34, 1.1, tc, 10)
			mb.box(Vector3(0, 0.95, 0), Vector3(0.38, 0.12, 0.26), GOLD)
			_arms(mb, tc.darkened(0.2))
			mb.sphere(Vector3(0, 1.25, 0), 0.15, SKIN)
			mb.cyl(Vector3(0, 1.36, 0), 0.22, 0.25, 0.04, tc.darkened(0.4), 10)
			mb.cone(Vector3(0, 1.62, -0.03), 0.17, 0.55, tc.darkened(0.4), 8, Vector3(-0.2, 0, 0))
			mb.box(Vector3(0.3, 0.9, 0.15), Vector3(0.05, 1.6, 0.05), DWOOD)
			mb.sphere(Vector3(0.3, 1.75, 0.15), 0.11, Color(1.0, 0.5, 0.15, 0.2))
		"cleric":
			mb.cyl(Vector3(0, 0.55, 0), 0.16, 0.34, 1.1, Color(0.93, 0.92, 0.86), 10)
			mb.cyl(Vector3(0, 0.4, 0), 0.25, 0.3, 0.12, tc, 10)
			mb.box(Vector3(0, 0.98, 0), Vector3(0.38, 0.1, 0.26), GOLD)
			_arms(mb, Color(0.9, 0.9, 0.84))
			mb.sphere(Vector3(0, 1.24, 0), 0.15, SKIN)
			mb.sphere(Vector3(0, 1.28, -0.03), 0.18, Color(0.93, 0.92, 0.86), Vector3(1, 1.05, 1))
			mb.torus(Vector3(0, 1.55, 0), 0.12, 0.17, Color(1.0, 0.95, 0.5, 0.3))
			mb.box(Vector3(0.3, 0.9, 0.15), Vector3(0.05, 1.5, 0.05), GOLD.darkened(0.3))
			mb.sphere(Vector3(0.3, 1.7, 0.15), 0.1, Color(0.8, 1.0, 0.7, 0.2))
		"catapult":
			for sx in [-0.5, 0.5]:
				mb.box(Vector3(sx, 0.45, 0), Vector3(0.14, 0.14, 1.8), WOOD)
				for sz in [-0.6, 0.6]:
					mb.cyl(Vector3(sx * 1.25, 0.35, sz), 0.35, 0.35, 0.12, DWOOD, 10, Vector3(0, 0, PI / 2))
			mb.box(Vector3(0, 0.5, 0.75), Vector3(1.1, 0.14, 0.14), WOOD)
			mb.box(Vector3(0, 0.5, -0.75), Vector3(1.1, 0.14, 0.14), WOOD)
			mb.box(Vector3(0.45, 1.0, 0.1), Vector3(0.12, 1.1, 0.12), WOOD)
			mb.box(Vector3(-0.45, 1.0, 0.1), Vector3(0.12, 1.1, 0.12), WOOD)
			mb.box(Vector3(0, 1.45, 0.1), Vector3(1.0, 0.12, 0.12), DWOOD)
			mb.box(Vector3(0, 1.1, -0.2), Vector3(0.12, 0.12, 1.8), WOOD, Vector3(-0.6, 0, 0))
			mb.box(Vector3(0, 0.65, 0.5), Vector3(0.4, 0.4, 0.4), DSTONE)
			mb.cyl(Vector3(0, 1.62, -0.72), 0.2, 0.15, 0.15, DWOOD, 8)
			mb.box(Vector3(0.55, 1.7, 0.6), Vector3(0.03, 0.8, 0.03), WOOD)
			mb.box(Vector3(0.55, 1.95, 0.75), Vector3(0.02, 0.25, 0.3), tc)
		"dragon":
			var dc := tc.darkened(0.25)
			mb.sphere(Vector3(0, 0, 0), 0.6, dc, Vector3(1.0, 0.85, 2.2), 10, 6)
			mb.sphere(Vector3(0, -0.2, 0.2), 0.5, Color(0.85, 0.75, 0.5), Vector3(0.8, 0.5, 1.6), 8, 5)
			mb.cyl(Vector3(0, 0.55, 1.35), 0.2, 0.32, 1.1, dc, 8, Vector3(0.9, 0, 0))
			mb.box(Vector3(0, 0.95, 1.9), Vector3(0.42, 0.34, 0.7), dc)
			mb.box(Vector3(0, 0.82, 2.2), Vector3(0.32, 0.14, 0.4), dc.darkened(0.2))
			mb.cone(Vector3(0.14, 1.2, 1.7), 0.06, 0.4, Color(0.9, 0.85, 0.7), 5, Vector3(-0.8, 0, 0))
			mb.cone(Vector3(-0.14, 1.2, 1.7), 0.06, 0.4, Color(0.9, 0.85, 0.7), 5, Vector3(-0.8, 0, 0))
			mb.sphere(Vector3(0.15, 1.02, 2.15), 0.05, Color(1.0, 0.8, 0.1, 0.1))
			mb.sphere(Vector3(-0.15, 1.02, 2.15), 0.05, Color(1.0, 0.8, 0.1, 0.1))
			mb.cone(Vector3(0, 0.05, -2.2), 0.3, 2.0, dc, 8, Vector3(-PI / 2 - 0.1, 0, 0))
			for s in [-1.0, 1.0]:
				mb.prism(Vector3(s * 1.25, 0.4, 0.2), Vector3(2.1, 1.3, 0.06), tc, Vector3(-PI / 2, 0, s * 0.25))
				mb.box(Vector3(s * 1.2, 0.48, 0.75), Vector3(2.2, 0.1, 0.1), dc, Vector3(0, 0, s * 0.25))
				mb.box(Vector3(s * 0.35, -0.55, 0.6), Vector3(0.16, 0.5, 0.16), dc)
				mb.box(Vector3(s * 0.35, -0.55, -0.6), Vector3(0.16, 0.5, 0.16), dc)
			for i in 4:
				mb.cone(Vector3(0, 0.55, 0.6 - i * 0.45), 0.1, 0.3, Color(0.9, 0.85, 0.7), 4)
		"wolf":
			var wc := Color(0.45, 0.44, 0.46)
			mb.box(Vector3(0, 0.55, 0), Vector3(0.38, 0.38, 0.95), wc)
			for lx in [-0.12, 0.12]:
				for lz in [-0.32, 0.32]:
					mb.box(Vector3(lx, 0.2, lz), Vector3(0.1, 0.42, 0.1), wc.darkened(0.2))
			mb.box(Vector3(0, 0.72, 0.55), Vector3(0.3, 0.3, 0.32), wc)
			mb.box(Vector3(0, 0.66, 0.78), Vector3(0.16, 0.14, 0.22), wc.darkened(0.3))
			mb.cone(Vector3(0.09, 0.92, 0.5), 0.05, 0.14, wc, 4)
			mb.cone(Vector3(-0.09, 0.92, 0.5), 0.05, 0.14, wc, 4)
			mb.box(Vector3(0, 0.6, -0.6), Vector3(0.08, 0.08, 0.45), wc, Vector3(0.5, 0, 0))
			mb.sphere(Vector3(0.08, 0.78, 0.71), 0.03, Color(1.0, 0.3, 0.1, 0.1))
			mb.sphere(Vector3(-0.08, 0.78, 0.71), 0.03, Color(1.0, 0.3, 0.1, 0.1))
		"troll":
			var tcol := Color(0.42, 0.52, 0.4)
			mb.box(Vector3(-0.25, 0.45, 0), Vector3(0.3, 0.9, 0.3), tcol.darkened(0.2))
			mb.box(Vector3(0.25, 0.45, 0), Vector3(0.3, 0.9, 0.3), tcol.darkened(0.2))
			mb.sphere(Vector3(0, 1.45, 0), 0.6, tcol, Vector3(1.1, 1.0, 0.85))
			mb.box(Vector3(0, 0.95, 0), Vector3(0.8, 0.3, 0.55), LEATHER)
			mb.box(Vector3(-0.72, 1.2, 0.1), Vector3(0.25, 1.0, 0.25), tcol)
			mb.box(Vector3(0.72, 1.2, 0.2), Vector3(0.25, 1.0, 0.25), tcol, Vector3(-0.5, 0, 0))
			mb.sphere(Vector3(0, 2.15, 0.2), 0.28, tcol)
			mb.cone(Vector3(0, 2.1, 0.5), 0.06, 0.2, tcol.darkened(0.2), 4, Vector3(PI / 2, 0, 0))
			mb.cyl(Vector3(0.75, 1.0, 0.75), 0.16, 0.08, 1.4, DWOOD, 6, Vector3(1.0, 0, 0))
		"ironbreaker":
			mb.box(Vector3(-0.11, 0.18, 0), Vector3(0.16, 0.36, 0.17), LEATHER)
			mb.box(Vector3(0.11, 0.18, 0), Vector3(0.16, 0.36, 0.17), LEATHER)
			mb.box(Vector3(0, 0.56, 0), Vector3(0.54, 0.46, 0.36), STEEL.darkened(0.15))
			mb.box(Vector3(0, 0.56, 0.17), Vector3(0.3, 0.42, 0.04), tc)
			mb.box(Vector3(-0.33, 0.58, 0), Vector3(0.15, 0.38, 0.17), STEEL.darkened(0.3))
			mb.box(Vector3(0.33, 0.58, 0.05), Vector3(0.15, 0.38, 0.17), STEEL.darkened(0.3), Vector3(-0.5, 0, 0))
			mb.sphere(Vector3(0, 0.9, 0.02), 0.15, SKIN)
			mb.box(Vector3(0, 0.76, 0.14), Vector3(0.3, 0.3, 0.1), Color(0.75, 0.38, 0.15), Vector3(0.25, 0, 0))
			mb.sphere(Vector3(0, 0.97, 0), 0.19, STEEL, Vector3(1.05, 0.75, 1.05))
			mb.cone(Vector3(0.2, 1.05, 0), 0.05, 0.22, Color(0.9, 0.86, 0.75), 5, Vector3(0, 0, -1.0))
			mb.cone(Vector3(-0.2, 1.05, 0), 0.05, 0.22, Color(0.9, 0.86, 0.75), 5, Vector3(0, 0, 1.0))
			mb.box(Vector3(0.36, 0.62, 0.3), Vector3(0.06, 0.06, 0.75), DWOOD)
			mb.box(Vector3(0.36, 0.62, 0.62), Vector3(0.05, 0.36, 0.22), STEEL)
			mb.cyl(Vector3(-0.38, 0.58, 0.08), 0.3, 0.3, 0.07, tc.darkened(0.2), 10, Vector3(0, 0, PI / 2))
			mb.cyl(Vector3(-0.42, 0.58, 0.08), 0.1, 0.1, 0.05, GOLD, 8, Vector3(0, 0, PI / 2))
		"ranger":
			_legs(mb, Color(0.3, 0.26, 0.18), 1.1)
			mb.box(Vector3(0, 0.92, 0), Vector3(0.34, 0.56, 0.22), Color(0.22, 0.42, 0.25))
			mb.box(Vector3(0, 0.8, 0.12), Vector3(0.36, 0.08, 0.02), tc)
			mb.box(Vector3(0, 0.85, -0.14), Vector3(0.42, 0.95, 0.04), Color(0.16, 0.3, 0.18))
			_arms(mb, Color(0.22, 0.42, 0.25))
			mb.sphere(Vector3(0, 1.33, 0), 0.14, Color(0.96, 0.88, 0.76))
			mb.cone(Vector3(0.15, 1.38, 0), 0.04, 0.2, Color(0.96, 0.88, 0.76), 4, Vector3(0, 0, -1.2))
			mb.cone(Vector3(-0.15, 1.38, 0), 0.04, 0.2, Color(0.96, 0.88, 0.76), 4, Vector3(0, 0, 1.2))
			mb.box(Vector3(0, 1.45, -0.03), Vector3(0.26, 0.06, 0.26), Color(0.95, 0.88, 0.55))
			mb.box(Vector3(-0.32, 1.0, 0.18), Vector3(0.05, 1.5, 0.06), Color(0.85, 0.78, 0.6), Vector3(0.12, 0, 0))
			mb.cyl(Vector3(0.12, 1.05, -0.17), 0.08, 0.08, 0.6, LEATHER, 6, Vector3(0.3, 0, 0))
		"ogre":
			var oc := Color(0.66, 0.55, 0.38)
			mb.box(Vector3(-0.24, 0.42, 0), Vector3(0.3, 0.84, 0.32), oc.darkened(0.15))
			mb.box(Vector3(0.24, 0.42, 0), Vector3(0.3, 0.84, 0.32), oc.darkened(0.15))
			mb.sphere(Vector3(0, 1.3, 0.05), 0.62, oc, Vector3(1.05, 0.95, 0.9))
			mb.box(Vector3(0, 0.88, 0), Vector3(0.82, 0.3, 0.6), tc.darkened(0.2))
			mb.box(Vector3(-0.72, 1.15, 0.1), Vector3(0.26, 0.95, 0.26), oc)
			mb.box(Vector3(0.72, 1.2, 0.2), Vector3(0.26, 0.95, 0.26), oc, Vector3(-0.5, 0, 0))
			mb.sphere(Vector3(0, 1.98, 0.22), 0.26, oc)
			mb.cone(Vector3(0.08, 2.02, 0.45), 0.03, 0.1, Color(0.95, 0.92, 0.8), 4, Vector3(-0.3, 0, 0))
			mb.cone(Vector3(-0.08, 2.02, 0.45), 0.03, 0.1, Color(0.95, 0.92, 0.8), 4, Vector3(-0.3, 0, 0))
			mb.cyl(Vector3(0.78, 1.0, 0.8), 0.2, 0.09, 1.5, DWOOD, 7, Vector3(1.0, 0, 0))
			for i in 4:
				mb.cone(Vector3(0.78 + (0.18 if i % 2 == 0 else -0.18), 1.3 + i * 0.12, 1.2 + i * 0.05), 0.05, 0.18, STEEL, 4, Vector3(0, 0, PI / 2 * (1 if i % 2 == 0 else -1)))
		"golem":
			mb.box(Vector3(-0.3, 0.45, 0), Vector3(0.38, 0.9, 0.42), DSTONE)
			mb.box(Vector3(0.3, 0.45, 0), Vector3(0.38, 0.9, 0.42), DSTONE)
			mb.box(Vector3(0, 1.35, 0), Vector3(1.05, 0.95, 0.7), STONE.darkened(0.1))
			mb.box(Vector3(0, 1.4, 0.36), Vector3(0.35, 0.35, 0.04), Color(0.35, 0.85, 1.0, 0.1))
			mb.box(Vector3(0, 1.0, 0), Vector3(1.08, 0.12, 0.72), tc)
			mb.box(Vector3(-0.72, 1.15, 0.05), Vector3(0.4, 1.1, 0.4), DSTONE)
			mb.box(Vector3(0.72, 1.15, 0.05), Vector3(0.4, 1.1, 0.4), DSTONE)
			mb.box(Vector3(-0.72, 0.55, 0.1), Vector3(0.48, 0.38, 0.48), STONE)
			mb.box(Vector3(0.72, 0.55, 0.1), Vector3(0.48, 0.38, 0.48), STONE)
			mb.box(Vector3(0, 2.0, 0.05), Vector3(0.42, 0.36, 0.4), STONE)
			mb.box(Vector3(0.1, 2.03, 0.26), Vector3(0.08, 0.05, 0.02), Color(0.4, 0.9, 1.0, 0.0))
			mb.box(Vector3(-0.1, 2.03, 0.26), Vector3(0.08, 0.05, 0.02), Color(0.4, 0.9, 1.0, 0.0))
			mb.sphere(Vector3(0.45, 1.75, 0), 0.18, Color(0.45, 0.52, 0.4))
		"griffin":
			var gb := Color(0.78, 0.62, 0.35)
			mb.sphere(Vector3(0, 0, 0), 0.5, gb, Vector3(0.9, 0.8, 1.7), 9, 6)
			mb.sphere(Vector3(0, 0.45, 0.85), 0.3, Color(0.95, 0.94, 0.9), Vector3(1, 1.1, 1.1))
			mb.cone(Vector3(0, 0.42, 1.2), 0.08, 0.25, GOLD, 5, Vector3(PI / 2 + 0.3, 0, 0))
			mb.sphere(Vector3(0.1, 0.52, 1.08), 0.03, Color(0.1, 0.1, 0.1))
			mb.sphere(Vector3(-0.1, 0.52, 1.08), 0.03, Color(0.1, 0.1, 0.1))
			mb.cone(Vector3(0, 0.0, -1.2), 0.12, 0.9, gb.darkened(0.2), 6, Vector3(-PI / 2 - 0.2, 0, 0))
			mb.sphere(Vector3(0, -0.12, -1.65), 0.12, gb.darkened(0.35))
			for sd in [-1.0, 1.0]:
				mb.prism(Vector3(sd * 1.05, 0.3, 0.1), Vector3(1.8, 1.1, 0.06), Color(0.88, 0.82, 0.7), Vector3(-PI / 2, 0, sd * 0.3))
				mb.box(Vector3(sd * 0.3, -0.45, 0.5), Vector3(0.1, 0.4, 0.1), GOLD.darkened(0.3))
				mb.box(Vector3(sd * 0.3, -0.45, -0.5), Vector3(0.12, 0.4, 0.12), gb.darkened(0.25))
			mb.box(Vector3(0, 0.6, 0.0), Vector3(0.3, 0.42, 0.22), tc)
			mb.sphere(Vector3(0, 0.95, 0.0), 0.13, STEEL)
			mb.box(Vector3(0.22, 0.65, 0.45), Vector3(0.05, 0.05, 1.0), WOOD)
		"merc_camp":
			for i in 3:
				var a := TAU * i / 3.0 + 0.4
				var tp := Vector3(cos(a) * 1.7, 0.0, sin(a) * 1.7)
				mb.cone(tp + Vector3(0, 0.9, 0), 1.0, 1.8, [Color(0.6, 0.25, 0.18), Color(0.7, 0.55, 0.3), Color(0.35, 0.4, 0.5)][i], 8)
				mb.box(tp + Vector3(0, 1.95, 0), Vector3(0.05, 0.5, 0.05), DWOOD)
			mb.cyl(Vector3(0, 0.08, 0), 0.5, 0.55, 0.15, DSTONE, 10)
			for i in 3:
				mb.cyl(Vector3(0, 0.22, 0), 0.06, 0.06, 0.8, WOOD, 5, Vector3(0, TAU * i / 3.0, PI / 2))
			mb.cone(Vector3(0, 0.45, 0), 0.28, 0.6, Color(1.0, 0.55, 0.1, 0.0), 6)
			mb.box(Vector3(-0.2, 1.3, -2.4), Vector3(0.08, 2.6, 0.08), DWOOD)
			mb.box(Vector3(0.25, 2.2, -2.4), Vector3(0.8, 0.6, 0.04), Color(0.85, 0.65, 0.15))
			mb.box(Vector3(0.25, 2.2, -2.37), Vector3(0.3, 0.3, 0.02), Color(0.15, 0.12, 0.1))
			for i in 4:
				mb.box(Vector3(1.6 + i * 0.12, 0.6, -0.9), Vector3(0.04, 1.2, 0.04), STEEL, Vector3(0, 0, 0.25))
			mb.box(Vector3(-1.4, 0.3, 0.9), Vector3(0.6, 0.6, 0.6), WOOD.lightened(0.15))
			mb.box(Vector3(-0.9, 0.25, 1.2), Vector3(0.5, 0.5, 0.5), WOOD)
		"freeblade_camp":
			mb.cyl(Vector3(0, 0.06, 0), 0.4, 0.45, 0.12, DSTONE, 8)
			for i in 3:
				mb.cyl(Vector3(0, 0.18, 0), 0.05, 0.05, 0.6, WOOD, 5, Vector3(0, TAU * i / 3.0, PI / 2))
			mb.cone(Vector3(0, 0.38, 0), 0.22, 0.5, Color(1.0, 0.55, 0.1, 0.0), 6)
			mb.prism(Vector3(1.4, 0.6, 0.6), Vector3(1.4, 1.2, 1.6), Color(0.45, 0.5, 0.35), Vector3(0, 0.5, 0))
			mb.box(Vector3(-1.2, 0.9, -0.8), Vector3(0.06, 1.8, 0.06), DWOOD)
			mb.box(Vector3(-1.0, 1.55, -0.8), Vector3(0.4, 0.3, 0.03), Color(1.0, 0.9, 0.5))
		"recruit_mark":
			mb.torus(Vector3(0, 0.1, 0), 0.62, 0.72, Color(1.0, 0.85, 0.3, 0.0))
		"carry_wood":
			mb.cyl(Vector3(0, 0, 0), 0.07, 0.07, 0.5, WOOD, 6, Vector3(PI / 2, 0, 0))
			mb.cyl(Vector3(0.1, 0.05, 0), 0.07, 0.07, 0.5, WOOD.darkened(0.1), 6, Vector3(PI / 2, 0, 0))
		"carry_food":
			mb.sphere(Vector3.ZERO, 0.16, Color(0.75, 0.6, 0.4))
			mb.sphere(Vector3(0, 0.1, 0), 0.06, Color(0.85, 0.2, 0.2))
		"carry_gold":
			mb.box(Vector3.ZERO, Vector3(0.22, 0.16, 0.18), GOLD)
		"carry_mana":
			mb.cyl(Vector3.ZERO, 0.0, 0.1, 0.3, Color(0.6, 0.45, 1.0, 0.3), 6)
		"champ_warlord":
			_legs(mb, STEEL.darkened(0.35), 1.15)
			mb.box(Vector3(0, 0.98, 0), Vector3(0.56, 0.64, 0.34), STEEL.darkened(0.1))
			mb.box(Vector3(0, 1.0, 0.04), Vector3(0.3, 0.4, 0.32), tc)
			mb.box(Vector3(0, 0.98, -0.22), Vector3(0.6, 1.0, 0.05), tc.darkened(0.2))
			mb.box(Vector3(0, 0.7, 0), Vector3(0.58, 0.1, 0.36), GOLD.darkened(0.2))
			mb.sphere(Vector3(-0.36, 1.25, 0), 0.17, STEEL, Vector3(1.2, 0.8, 1.1))
			mb.sphere(Vector3(0.36, 1.25, 0), 0.17, STEEL, Vector3(1.2, 0.8, 1.1))
			mb.box(Vector3(-0.37, 0.95, 0), Vector3(0.15, 0.48, 0.16), STEEL.darkened(0.25))
			mb.box(Vector3(0.37, 0.95, 0.06), Vector3(0.15, 0.48, 0.16), STEEL.darkened(0.25), Vector3(-0.5, 0, 0))
			mb.sphere(Vector3(0, 1.5, 0), 0.2, STEEL, Vector3(1, 0.95, 1))
			mb.box(Vector3(0, 1.46, 0.17), Vector3(0.22, 0.05, 0.04), Color(0.1, 0.1, 0.1))
			mb.cone(Vector3(0.2, 1.68, 0), 0.06, 0.32, Color(0.9, 0.86, 0.75), 6, Vector3(0, 0, -0.7))
			mb.cone(Vector3(-0.2, 1.68, 0), 0.06, 0.32, Color(0.9, 0.86, 0.75), 6, Vector3(0, 0, 0.7))
			mb.box(Vector3(0.4, 1.1, 0.75), Vector3(0.12, 0.12, 1.3), Color(0.85, 0.9, 1.0, 0.55))
			mb.box(Vector3(0.4, 1.1, 0.12), Vector3(0.35, 0.08, 0.08), GOLD)
		"champ_archmage":
			mb.cyl(Vector3(0, 0.6, 0), 0.18, 0.4, 1.2, tc.darkened(0.2), 12)
			mb.cyl(Vector3(0, 0.25, 0), 0.38, 0.42, 0.1, GOLD, 12)
			mb.box(Vector3(0, 1.08, 0), Vector3(0.42, 0.12, 0.3), GOLD)
			mb.box(Vector3(0, 0.9, -0.2), Vector3(0.5, 1.0, 0.04), tc.darkened(0.45))
			_arms(mb, tc.darkened(0.25))
			mb.sphere(Vector3(0, 1.35, 0), 0.16, SKIN)
			mb.cone(Vector3(0, 1.2, 0.12), 0.12, 0.35, Color(0.92, 0.92, 0.95), 6, Vector3(PI, 0, 0))
			mb.cyl(Vector3(0, 1.47, 0), 0.3, 0.32, 0.04, tc.darkened(0.5), 12)
			mb.cone(Vector3(0, 1.85, -0.05), 0.2, 0.75, tc.darkened(0.5), 10, Vector3(-0.25, 0, 0))
			mb.sphere(Vector3(0.05, 1.6, 0.17), 0.05, Color(1.0, 0.9, 0.3, 0.1))
			mb.box(Vector3(0.34, 1.0, 0.15), Vector3(0.06, 2.0, 0.06), DWOOD)
			mb.torus(Vector3(0.34, 2.05, 0.15), 0.14, 0.2, GOLD)
			mb.sphere(Vector3(0.34, 2.05, 0.15), 0.15, Color(0.6, 0.4, 1.0, 0.0))
		"champ_priestess":
			mb.cyl(Vector3(0, 0.6, 0), 0.18, 0.4, 1.2, Color(0.96, 0.95, 0.9), 12)
			mb.cyl(Vector3(0, 0.4, 0), 0.33, 0.37, 0.14, tc, 12)
			mb.box(Vector3(0, 1.08, 0), Vector3(0.42, 0.12, 0.3), GOLD)
			_arms(mb, Color(0.95, 0.94, 0.88))
			mb.sphere(Vector3(0, 1.35, 0), 0.16, SKIN)
			mb.sphere(Vector3(0, 1.4, -0.04), 0.19, Color(0.98, 0.9, 0.55), Vector3(1, 1.1, 1))
			mb.torus(Vector3(0, 1.72, 0), 0.15, 0.22, Color(1.0, 0.95, 0.5, 0.1))
			for sd in [-1.0, 1.0]:
				mb.prism(Vector3(sd * 0.42, 1.2, -0.2), Vector3(0.7, 0.9, 0.04), Color(1.0, 0.97, 0.85, 0.4), Vector3(0, sd * 0.4, sd * -0.6))
			mb.box(Vector3(0.34, 1.0, 0.15), Vector3(0.05, 1.9, 0.05), GOLD.darkened(0.2))
			mb.torus(Vector3(0.34, 2.0, 0.15), 0.12, 0.17, GOLD)
			mb.sphere(Vector3(0.34, 2.0, 0.15), 0.1, Color(1.0, 1.0, 0.8, 0.0))
		"holy":
			mb.sphere(Vector3.ZERO, 0.2, Color(1.0, 0.95, 0.6, 0.0))
			mb.sphere(Vector3(0, 0, -0.2), 0.12, Color(1.0, 1.0, 0.9, 0.0))
		"fx_stun":
			for i in 4:
				var a := TAU * i / 4.0
				mb.sphere(Vector3(cos(a) * 0.3, 0, sin(a) * 0.3), 0.07, Color(1.0, 0.9, 0.2, 0.0))
		"fx_holy":
			mb.torus(Vector3(0, 0.08, 0), 0.75, 1.0, Color(1.0, 0.95, 0.6, 0.0))
			mb.cyl(Vector3(0, 1.0, 0), 0.9, 0.9, 2.0, Color(1.0, 0.95, 0.7, 0.55), 12)
		"fx_ward":
			mb.torus(Vector3(0, 0.08, 0), 0.8, 1.0, Color(0.4, 0.75, 1.0, 0.0))
			mb.torus(Vector3(0, 0.9, 0), 0.85, 0.95, Color(0.5, 0.8, 1.0, 0.2))
		"fx_iron":
			mb.torus(Vector3(0, 0.08, 0), 0.8, 1.0, Color(0.75, 0.75, 0.8, 0.3))
			mb.torus(Vector3(0, 0.6, 0), 0.85, 0.95, Color(0.8, 0.8, 0.85, 0.4))
		"fx_frost":
			mb.torus(Vector3(0, 0.08, 0), 0.75, 1.0, Color(0.6, 0.9, 1.0, 0.1))
			for i in 5:
				var a := TAU * i / 5.0
				mb.cone(Vector3(cos(a) * 0.8, 0.2, sin(a) * 0.8), 0.08, 0.35, Color(0.75, 0.95, 1.0, 0.3), 4)
		"fx_rally":
			mb.torus(Vector3(0, 0.08, 0), 0.8, 1.0, Color(1.0, 0.7, 0.2, 0.0))
		"levelup":
			mb.torus(Vector3(0, 0.2, 0), 0.9, 1.2, Color(1.0, 0.85, 0.3, 0.0))
			mb.cyl(Vector3(0, 1.5, 0), 0.6, 0.9, 3.0, Color(1.0, 0.9, 0.5, 0.5), 12)
		"burst_gold":
			mb.torus(Vector3.ZERO, 0.85, 1.0, Color(1.0, 0.75, 0.2, 0.0))
			mb.sphere(Vector3.ZERO, 0.35, Color(1.0, 0.85, 0.3, 0.0))
		"burst_blue":
			mb.torus(Vector3.ZERO, 0.85, 1.0, Color(0.4, 0.7, 1.0, 0.0))
			mb.sphere(Vector3.ZERO, 0.35, Color(0.5, 0.75, 1.0, 0.0))
		"nova":
			mb.torus(Vector3.ZERO, 0.85, 1.0, Color(0.6, 0.9, 1.0, 0.0))
			for i in 10:
				var a := TAU * i / 10.0
				mb.cone(Vector3(cos(a) * 0.9, 0.1, sin(a) * 0.9), 0.05, 0.2, Color(0.8, 0.95, 1.0, 0.1), 4)
		"holy_nova":
			mb.torus(Vector3.ZERO, 0.85, 1.0, Color(1.0, 0.95, 0.55, 0.0))
			mb.torus(Vector3(0, 0.3, 0), 0.6, 0.7, Color(1.0, 1.0, 0.8, 0.0))
		"pillar":
			mb.cyl(Vector3(0, 6.0, 0), 1.0, 1.3, 12.0, Color(1.0, 0.95, 0.65, 0.0), 12)
			mb.torus(Vector3(0, 0.1, 0), 2.0, 2.5, Color(1.0, 0.9, 0.5, 0.0))
		"banner":
			mb.box(Vector3(0, 1.6, 0), Vector3(0.1, 3.2, 0.1), DWOOD)
			mb.box(Vector3(0.45, 2.7, 0), Vector3(0.8, 1.1, 0.04), tc)
			mb.box(Vector3(0.45, 2.7, 0.03), Vector3(0.3, 0.3, 0.02), GOLD)
			mb.sphere(Vector3(0, 3.3, 0), 0.12, Color(1.0, 0.85, 0.3, 0.1))
		"meteor":
			mb.sphere(Vector3.ZERO, 0.9, Color(0.35, 0.15, 0.08), Vector3.ONE, 8, 5)
			mb.sphere(Vector3(0, 0.6, 0.6), 0.7, Color(1.0, 0.45, 0.05, 0.0))
			mb.sphere(Vector3(0, 1.4, 1.4), 0.45, Color(1.0, 0.7, 0.2, 0.0))
		"storm":
			mb.cyl(Vector3(0, 3.0, 0), 4.5, 2.0, 0.6, Color(0.45, 0.3, 0.8, 0.3), 16)
			mb.cyl(Vector3(0, 4.0, 0), 5.5, 4.0, 0.8, Color(0.3, 0.2, 0.55, 0.5), 16)
			mb.torus(Vector3(0, 0.15, 0), 5.0, 5.6, Color(0.7, 0.5, 1.0, 0.0))
		"bolt":
			mb.box(Vector3(0, 2.0, 0), Vector3(0.12, 4.0, 0.12), Color(0.85, 0.75, 1.0, 0.0))
			mb.sphere(Vector3(0, 0.2, 0), 0.4, Color(0.8, 0.6, 1.0, 0.0))
		"area_ring":
			mb.torus(Vector3(0, 0.12, 0), 0.95, 1.0, Color(tc.r, tc.g, tc.b, 0.1))
		# ---------------- buildings ----------------
		"town_hall":
			_plinth(mb, 5.0)
			mb.box(Vector3(0, 1.2, 0), Vector3(4.4, 2.2, 3.6), STONE)
			mb.box(Vector3(0, 3.0, 0), Vector3(3.8, 1.4, 3.0), PLASTER)
			for bx in [-1.85, -0.6, 0.6, 1.85]:
				mb.box(Vector3(bx, 3.0, 1.51), Vector3(0.14, 1.4, 0.06), DWOOD)
			mb.box(Vector3(0, 3.65, 1.51), Vector3(3.8, 0.14, 0.06), DWOOD)
			mb.prism(Vector3(0, 4.5, 0), Vector3(4.3, 1.7, 3.4), tc, Vector3(0, PI / 2, 0))
			mb.box(Vector3(0, 0.85, 1.82), Vector3(1.0, 1.5, 0.1), DWOOD)
			mb.cyl(Vector3(1.85, 2.6, 1.4), 0.62, 0.72, 5.2, STONE, 10)
			mb.cone(Vector3(1.85, 5.9, 1.4), 0.85, 1.4, tc, 10)
			mb.box(Vector3(1.85, 7.0, 1.4), Vector3(0.05, 1.0, 0.05), DWOOD)
			mb.box(Vector3(2.15, 7.3, 1.4), Vector3(0.6, 0.35, 0.03), tc)
			mb.cyl(Vector3(-1.85, 2.0, -1.4), 0.55, 0.65, 4.0, STONE, 10)
			mb.cone(Vector3(-1.85, 4.6, -1.4), 0.75, 1.2, tc, 10)
		"house":
			_plinth(mb, 2.5)
			mb.box(Vector3(0, 0.85, 0), Vector3(2.0, 1.5, 1.9), PLASTER)
			for bx in [-0.97, 0.97]:
				mb.box(Vector3(bx, 0.85, 0.96), Vector3(0.1, 1.5, 0.05), DWOOD)
			mb.box(Vector3(0, 1.55, 0.96), Vector3(2.0, 0.1, 0.05), DWOOD)
			mb.prism(Vector3(0, 2.15, 0), Vector3(2.3, 1.1, 2.2), tc.darkened(0.1), Vector3(0, PI / 2, 0))
			mb.box(Vector3(0.6, 2.3, -0.4), Vector3(0.3, 0.9, 0.3), DSTONE)
			mb.box(Vector3(0, 0.6, 0.97), Vector3(0.5, 0.9, 0.06), DWOOD)
			mb.box(Vector3(-0.55, 1.0, 0.97), Vector3(0.35, 0.35, 0.06), Color(1.0, 0.85, 0.5, 0.6))
		"farm":
			mb.box(Vector3(0, 0.0, 0), Vector3(3.5, 0.3, 3.5), Color(0.42, 0.3, 0.18))
			for i in 5:
				var cz := -1.3 + i * 0.65
				mb.box(Vector3(0, 0.22, cz), Vector3(3.0, 0.22, 0.32), Color(0.55, 0.7, 0.25) if i % 2 == 0 else Color(0.85, 0.75, 0.3))
			for px in [-1.7, 1.7]:
				for pz in [-1.7, 1.7]:
					mb.box(Vector3(px, 0.35, pz), Vector3(0.1, 0.7, 0.1), WOOD)
			mb.box(Vector3(0, 0.55, 1.72), Vector3(3.4, 0.06, 0.05), WOOD)
			mb.box(Vector3(0, 0.55, -1.72), Vector3(3.4, 0.06, 0.05), WOOD)
			mb.box(Vector3(1.2, 0.7, 1.2), Vector3(0.05, 1.3, 0.05), WOOD)
			mb.box(Vector3(1.2, 1.05, 1.2), Vector3(0.5, 0.05, 0.05), WOOD)
			mb.box(Vector3(1.2, 0.95, 1.2), Vector3(0.22, 0.32, 0.15), tc)
			mb.sphere(Vector3(1.2, 1.3, 1.2), 0.1, STRAW)
		"storehouse":
			_plinth(mb, 3.0)
			mb.box(Vector3(0, 0.9, 0), Vector3(2.6, 1.6, 2.2), WOOD)
			mb.prism(Vector3(0, 2.15, 0), Vector3(2.8, 0.9, 2.5), tc, Vector3(0, PI / 2, 0))
			mb.box(Vector3(0, 0.75, 1.11), Vector3(1.0, 1.2, 0.05), DWOOD)
			mb.box(Vector3(1.1, 0.4, 1.35), Vector3(0.5, 0.5, 0.5), WOOD.lightened(0.2))
			mb.box(Vector3(0.6, 0.3, 1.4), Vector3(0.4, 0.4, 0.4), WOOD.lightened(0.1))
			for i in 3:
				mb.cyl(Vector3(-1.0, 0.2 + i * 0.25, 1.3), 0.12, 0.12, 1.0, WOOD, 6, Vector3(0, 0, PI / 2))
		"barracks":
			_plinth(mb, 4.2)
			mb.box(Vector3(0, 1.0, 0), Vector3(3.8, 1.8, 3.2), STONE)
			mb.prism(Vector3(0, 2.6, 0), Vector3(4.1, 1.4, 3.5), tc, Vector3(0, PI / 2, 0))
			mb.box(Vector3(0, 0.75, 1.62), Vector3(1.2, 1.3, 0.06), DWOOD)
			mb.box(Vector3(-1.6, 0.6, 1.85), Vector3(0.6, 1.1, 0.1), WOOD)
			for i in 3:
				mb.box(Vector3(-1.8 + i * 0.2, 0.9, 1.92), Vector3(0.04, 1.2, 0.04), STEEL)
			mb.box(Vector3(1.6, 1.2, 1.85), Vector3(0.06, 2.4, 0.06), DWOOD)
			mb.box(Vector3(1.6, 1.9, 1.88), Vector3(0.5, 0.9, 0.03), tc)
			mb.cyl(Vector3(-1.5, 2.6, -1.0), 0.15, 0.15, 1.2, DSTONE, 6)
		"blacksmith":
			_plinth(mb, 3.6)
			mb.box(Vector3(0, 0.9, 0), Vector3(3.2, 1.6, 2.8), DSTONE)
			mb.prism(Vector3(0, 2.2, 0), Vector3(3.4, 1.0, 3.0), tc.darkened(0.15), Vector3(0, PI / 2, 0))
			mb.box(Vector3(1.0, 2.4, -0.8), Vector3(0.6, 2.2, 0.6), STONE)
			mb.box(Vector3(1.0, 3.55, -0.8), Vector3(0.45, 0.1, 0.45), Color(1.0, 0.45, 0.1, 0.1))
			mb.box(Vector3(-0.8, 0.35, 1.7), Vector3(0.5, 0.5, 0.3), Color(0.25, 0.25, 0.27))
			mb.box(Vector3(-0.8, 0.65, 1.7), Vector3(0.7, 0.15, 0.3), Color(0.3, 0.3, 0.33))
			mb.box(Vector3(0.4, 0.6, 1.41), Vector3(0.9, 0.7, 0.05), Color(1.0, 0.5, 0.15, 0.4))
		"tower":
			mb.box(Vector3(0, -0.6, 0), Vector3(2.0, 1.6, 2.0), DSTONE)
			mb.cyl(Vector3(0, 2.7, 0), 0.75, 0.92, 5.4, STONE, 10)
			mb.cyl(Vector3(0, 5.55, 0), 1.05, 1.0, 0.5, DSTONE, 10)
			for i in 6:
				var a := TAU * i / 6.0
				mb.box(Vector3(cos(a) * 0.95, 5.95, sin(a) * 0.95), Vector3(0.3, 0.35, 0.3), STONE)
			mb.cone(Vector3(0, 6.75, 0), 1.0, 1.6, tc, 10)
			mb.box(Vector3(0, 3.2, 0.86), Vector3(0.2, 0.5, 0.1), Color(0.1, 0.08, 0.06))
		"wall":
			mb.box(Vector3(0, 0.55, 0), Vector3(1.04, 3.2, 1.04), STONE)
			mb.box(Vector3(0, 1.9, 0), Vector3(1.08, 0.14, 1.08), tc.darkened(0.2))
			mb.box(Vector3(0.3, 2.25, 0.3), Vector3(0.32, 0.35, 0.32), STONE)
			mb.box(Vector3(-0.3, 2.25, -0.3), Vector3(0.32, 0.35, 0.32), STONE)
		"gate":
			for sx in [-0.42, 0.42]:
				mb.box(Vector3(sx, 0.55, 0), Vector3(0.24, 3.2, 1.04), STONE)
				mb.box(Vector3(sx, 2.25, 0), Vector3(0.3, 0.3, 1.08), STONE)
			mb.box(Vector3(0, 2.25, 0), Vector3(1.04, 0.5, 0.7), DSTONE)
			mb.box(Vector3(0, 2.25, 0.36), Vector3(0.5, 0.3, 0.04), tc)
			mb.box(Vector3(0, 2.25, -0.36), Vector3(0.5, 0.3, 0.04), tc)
		"gate_door":
			for i in 4:
				mb.box(Vector3(-0.24 + i * 0.16, 0.95, 0), Vector3(0.05, 1.9, 0.06), Color(0.25, 0.24, 0.26))
			for j in 3:
				mb.box(Vector3(0, 0.35 + j * 0.6, 0), Vector3(0.62, 0.05, 0.06), Color(0.3, 0.29, 0.31))
			mb.box(Vector3(0, 0.95, 0.04), Vector3(0.58, 1.8, 0.03), DWOOD)
		"stable":
			_plinth(mb, 4.2)
			mb.box(Vector3(0, 0.9, -0.4), Vector3(3.8, 1.6, 2.4), WOOD)
			mb.prism(Vector3(0, 2.25, -0.4), Vector3(4.0, 1.1, 2.7), tc, Vector3(0, PI / 2, 0))
			for i in 3:
				mb.box(Vector3(-1.2 + i * 1.2, 0.7, 0.81), Vector3(0.9, 1.1, 0.05), DWOOD)
			for px in [-1.9, -0.6, 0.6, 1.9]:
				mb.box(Vector3(px, 0.4, 1.8), Vector3(0.1, 0.8, 0.1), WOOD)
			mb.box(Vector3(0, 0.65, 1.8), Vector3(3.9, 0.07, 0.06), WOOD)
			mb.cyl(Vector3(1.3, 0.3, 1.2), 0.3, 0.3, 0.6, STRAW, 8, Vector3(0, 0, PI / 2))
			mb.cyl(Vector3(-1.4, 0.3, 1.3), 0.3, 0.3, 0.6, STRAW, 8, Vector3(PI / 2, 0, 0))
		"mage_tower":
			_plinth(mb, 3.4)
			var mc := Color(0.5, 0.46, 0.6)
			mb.cyl(Vector3(0, 1.5, 0), 1.2, 1.5, 3.0, mc, 10)
			mb.cyl(Vector3(0, 4.2, 0), 0.95, 1.15, 2.5, mc.lightened(0.1), 10)
			mb.cyl(Vector3(0, 6.1, 0), 0.8, 0.9, 1.4, mc.lightened(0.2), 10)
			mb.cone(Vector3(0, 7.8, 0), 1.1, 2.0, tc, 10)
			mb.torus(Vector3(0, 3.05, 0), 1.15, 1.3, Color(0.5, 0.8, 1.0, 0.2))
			mb.torus(Vector3(0, 5.5, 0), 0.92, 1.05, Color(0.5, 0.8, 1.0, 0.2))
			mb.cyl(Vector3(0, 9.4, 0), 0.0, 0.25, 0.6, Color(0.6, 0.5, 1.0, 0.1), 6)
			mb.cyl(Vector3(0, 8.85, 0), 0.25, 0.0, 0.5, Color(0.6, 0.5, 1.0, 0.1), 6)
			mb.box(Vector3(0, 0.7, 1.45), Vector3(0.7, 1.2, 0.1), DWOOD)
		"workshop":
			_plinth(mb, 4.4)
			mb.box(Vector3(0, 1.0, -0.3), Vector3(4.0, 1.8, 2.8), WOOD)
			mb.prism(Vector3(0, 2.5, -0.3), Vector3(4.2, 1.2, 3.1), tc.darkened(0.1), Vector3(0, PI / 2, 0))
			mb.cyl(Vector3(1.2, 1.4, 1.15), 0.8, 0.8, 0.15, DSTONE, 12, Vector3(PI / 2, 0, 0))
			mb.cyl(Vector3(1.2, 1.4, 1.25), 0.25, 0.25, 0.1, tc, 8, Vector3(PI / 2, 0, 0))
			for i in 4:
				mb.cyl(Vector3(-1.2, 0.2 + i * 0.22, 1.5), 0.1, 0.1, 1.4, WOOD, 6, Vector3(0, PI / 2, PI / 2))
			mb.box(Vector3(-0.2, 0.85, 1.11), Vector3(1.0, 1.4, 0.05), DWOOD)
		"dragon_roost":
			mb.box(Vector3(0, -0.6, 0), Vector3(5.0, 1.6, 5.0), DSTONE.darkened(0.2))
			for i in 9:
				var a := TAU * i / 9.0
				mb.sphere(Vector3(cos(a) * 2.0, 0.6, sin(a) * 2.0), 0.8, DSTONE, Vector3(1.0, 1.3 + 0.3 * (i % 3), 1.0))
				mb.cone(Vector3(cos(a) * 2.1, 1.9 + 0.2 * (i % 2), sin(a) * 2.1), 0.22, 1.4, Color(0.25, 0.22, 0.22), 5)
			mb.torus(Vector3(0, 0.5, 0), 0.6, 1.3, Color(0.4, 0.3, 0.2))
			mb.sphere(Vector3(0.3, 0.7, 0.2), 0.3, Color(0.9, 0.5, 0.2, 0.35), Vector3(1, 1.3, 1))
			mb.sphere(Vector3(-0.3, 0.7, -0.1), 0.3, Color(0.9, 0.5, 0.2, 0.35), Vector3(1, 1.3, 1))
			mb.box(Vector3(2.2, 2.6, 2.2), Vector3(0.06, 2.2, 0.06), DWOOD)
			mb.box(Vector3(2.2, 3.3, 2.45), Vector3(0.04, 0.7, 0.5), tc)
			mb.box(Vector3(-2.2, 2.6, -2.2), Vector3(0.06, 2.2, 0.06), DWOOD)
			mb.box(Vector3(-2.2, 3.3, -1.95), Vector3(0.04, 0.7, 0.5), tc)
		# ---------------- resources ----------------
		"tree_oak":
			var s := 0.85 + rng.randf() * 0.35
			mb.cyl(Vector3(0, 0.8 * s, 0), 0.12, 0.19, 1.6 * s, Color(0.4, 0.28, 0.17), 6)
			var g := Color(0.25, 0.5, 0.2).lerp(Color(0.38, 0.55, 0.18), rng.randf())
			mb.sphere(Vector3(0, 2.1 * s, 0), 0.85 * s, g, Vector3.ONE, 7, 5)
			mb.sphere(Vector3(0.45 * s, 1.75 * s, 0.2 * s), 0.55 * s, g.darkened(0.1), Vector3.ONE, 6, 4)
			mb.sphere(Vector3(-0.35 * s, 1.85 * s, -0.3 * s), 0.6 * s, g.lightened(0.05), Vector3.ONE, 6, 4)
		"tree_pine", "tree_snowpine":
			var s := 0.85 + rng.randf() * 0.4
			mb.cyl(Vector3(0, 0.5 * s, 0), 0.1, 0.15, 1.0 * s, Color(0.36, 0.25, 0.15), 6)
			var g := Color(0.14, 0.36, 0.2).lerp(Color(0.2, 0.42, 0.22), rng.randf())
			for i in 3:
				var y := (1.0 + i * 0.7) * s
				var r := (0.95 - i * 0.25) * s
				mb.cone(Vector3(0, y, 0), r, 1.1 * s, g.lightened(i * 0.04), 7)
				if key == "tree_snowpine":
					mb.cone(Vector3(0, y + 0.25 * s, 0), r * 0.62, 0.62 * s, Color(0.94, 0.96, 1.0), 7)
		"tree_dead":
			var s := 0.8 + rng.randf() * 0.4
			var bc := Color(0.3, 0.24, 0.2)
			mb.cyl(Vector3(0, 1.0 * s, 0), 0.08, 0.17, 2.0 * s, bc, 5)
			mb.cyl(Vector3(0.3 * s, 1.5 * s, 0), 0.03, 0.07, 0.9 * s, bc, 4, Vector3(0, 0, -0.8))
			mb.cyl(Vector3(-0.25 * s, 1.75 * s, 0.1), 0.03, 0.06, 0.8 * s, bc, 4, Vector3(0.3, 0, 0.9))
			mb.sphere(Vector3(0, 2.1 * s, 0), 0.45 * s, Color(0.55, 0.42, 0.22), Vector3(1.2, 0.5, 1.2), 6, 3)
		"tree_acacia":
			var s := 0.8 + rng.randf() * 0.4
			mb.cyl(Vector3(0, 0.9 * s, 0), 0.08, 0.14, 1.8 * s, Color(0.4, 0.3, 0.2), 5)
			mb.cyl(Vector3(0, 1.95 * s, 0), 1.0 * s, 1.2 * s, 0.35 * s, Color(0.45, 0.5, 0.2), 8)
		"tree_elder":
			var s := 0.9 + rng.randf() * 0.4
			mb.cyl(Vector3(0, 1.0 * s, 0), 0.14, 0.25, 2.0 * s, Color(0.3, 0.26, 0.3), 6)
			var g := Color(0.15, 0.45, 0.4).lerp(Color(0.3, 0.3, 0.55), rng.randf())
			mb.sphere(Vector3(0, 2.6 * s, 0), 1.0 * s, g, Vector3(1, 0.8, 1), 7, 5)
			mb.sphere(Vector3(0.5 * s, 2.1 * s, 0.3 * s), 0.6 * s, g.darkened(0.15), Vector3.ONE, 6, 4)
			for i in 4:
				var a := TAU * i / 4.0 + rng.randf()
				mb.sphere(Vector3(cos(a) * 0.9 * s, 2.3 * s, sin(a) * 0.9 * s), 0.07, Color(0.6, 1.0, 0.9, 0.1))
		"tree_mushroom":
			var s := 0.8 + rng.randf() * 0.5
			mb.cyl(Vector3(0, 0.9 * s, 0), 0.16, 0.24, 1.8 * s, Color(0.9, 0.88, 0.8), 7)
			var cc := Color(0.75, 0.2, 0.35).lerp(Color(0.45, 0.3, 0.8), rng.randf())
			mb.sphere(Vector3(0, 1.9 * s, 0), 0.95 * s, cc, Vector3(1, 0.45, 1), 9, 5)
			for i in 5:
				var a := TAU * i / 5.0
				mb.sphere(Vector3(cos(a) * 0.55 * s, 2.1 * s, sin(a) * 0.55 * s), 0.09 * s, Color(1, 1, 0.9, 0.3))
		"berry":
			var g := Color(0.22, 0.48, 0.2)
			mb.sphere(Vector3(0, 0.35, 0), 0.45, g, Vector3(1, 0.75, 1), 7, 4)
			mb.sphere(Vector3(0.25, 0.3, 0.15), 0.3, g.lightened(0.08), Vector3.ONE, 6, 4)
			for i in 7:
				var a := TAU * i / 7.0
				mb.sphere(Vector3(cos(a) * 0.4, 0.3 + rng.randf() * 0.3, sin(a) * 0.4), 0.07, Color(0.85, 0.12, 0.3))
		"gold_mine":
			for i in 5:
				var a := TAU * i / 5.0 + rng.randf()
				mb.sphere(Vector3(cos(a) * 0.8, 0.4, sin(a) * 0.8), 0.6, Color(0.5, 0.47, 0.44), Vector3(1, 0.8 + rng.randf() * 0.4, 1), 6, 4)
			mb.sphere(Vector3(0, 0.7, 0), 0.8, Color(0.46, 0.43, 0.4), Vector3(1, 0.9, 1), 7, 4)
			for i in 8:
				var a := TAU * i / 8.0
				mb.box(Vector3(cos(a) * 0.9, 0.6 + rng.randf() * 0.6, sin(a) * 0.9), Vector3(0.25, 0.2, 0.25), Color(1.0, 0.82, 0.2, 0.75), Vector3(rng.randf(), rng.randf(), 0))
		"mana_crystal":
			mb.sphere(Vector3(0, 0.1, 0), 0.5, Color(0.35, 0.33, 0.38), Vector3(1, 0.4, 1), 6, 3)
			for i in 4:
				var a := TAU * i / 4.0 + rng.randf()
				var h := 0.8 + rng.randf() * 0.9
				var r := 0.12 + rng.randf() * 0.08
				var p := Vector3(cos(a) * 0.22, h * 0.5, sin(a) * 0.22)
				mb.cyl(p, r * 0.3, r, h, Color(0.55, 0.42, 1.0, 0.35), 6, Vector3(sin(a) * 0.3, 0, cos(a) * 0.3))
		"shrine":
			mb.cyl(Vector3(0, 0.0, 0), 2.4, 2.6, 0.6, DSTONE, 16)
			mb.cyl(Vector3(0, 0.35, 0), 1.9, 2.1, 0.2, STONE, 16)
			for i in 4:
				var a := TAU * i / 4.0 + PI / 4
				mb.box(Vector3(cos(a) * 1.7, 1.4, sin(a) * 1.7), Vector3(0.35, 2.4, 0.35), STONE)
				mb.box(Vector3(cos(a) * 1.7, 2.65, sin(a) * 1.7), Vector3(0.5, 0.15, 0.5), DSTONE)
			mb.cyl(Vector3(0, 0.9, 0), 0.25, 0.4, 1.0, DSTONE, 6)
			mb.torus(Vector3(0, 0.48, 0), 1.2, 1.35, Color(0.4, 0.9, 1.0, 0.2))
		"shrine_crystal":
			mb.cyl(Vector3(0, 0.35, 0), 0.0, 0.35, 0.7, tc, 6)
			mb.cyl(Vector3(0, -0.35, 0), 0.35, 0.0, 0.7, tc, 6)
		"shrine_flags":
			for i in 4:
				var a := TAU * i / 4.0 + PI / 4
				mb.box(Vector3(cos(a) * 1.7, 2.0, sin(a) * 1.7) + Vector3(cos(a), 0, sin(a)) * 0.2, Vector3(0.05, 0.9, 0.05) + Vector3(abs(sin(a)), 0, abs(cos(a))) * 0.35, tc)
		# ---------------- effects ----------------
		"arrow":
			mb.box(Vector3(0, 0, 0), Vector3(0.04, 0.04, 0.7), WOOD)
			mb.cone(Vector3(0, 0, 0.38), 0.05, 0.12, STEEL, 4, Vector3(PI / 2, 0, 0))
		"fireball":
			mb.sphere(Vector3.ZERO, 0.25, Color(1.0, 0.5, 0.1, 0.0))
			mb.sphere(Vector3(0, 0, -0.2), 0.16, Color(1.0, 0.8, 0.2, 0.0))
		"flame":
			mb.sphere(Vector3.ZERO, 0.35, Color(1.0, 0.45, 0.05, 0.0))
			mb.sphere(Vector3(0, 0, -0.25), 0.25, Color(1.0, 0.75, 0.15, 0.0))
		"boulder":
			mb.sphere(Vector3.ZERO, 0.3, DSTONE, Vector3.ONE, 6, 4)
		"burst":
			mb.sphere(Vector3.ZERO, 1.0, Color(1.0, 0.55, 0.15, 0.0), Vector3.ONE, 10, 6)
		"heal_fx":
			mb.torus(Vector3.ZERO, 0.4, 0.5, Color(0.6, 1.0, 0.5, 0.0))
		"fire":
			for i in 4:
				var a := TAU * i / 4.0
				mb.cone(Vector3(cos(a) * 0.4, 0.3, sin(a) * 0.4), 0.22, 0.6 + 0.2 * (i % 2), Color(1.0, 0.45 + 0.1 * i, 0.05, 0.05), 5)
			mb.cone(Vector3(0, 0.5, 0), 0.35, 1.0, Color(1.0, 0.7, 0.1, 0.05), 6)
		"rally":
			mb.box(Vector3(0, 0.9, 0), Vector3(0.05, 1.8, 0.05), DWOOD)
			mb.box(Vector3(0.3, 1.55, 0), Vector3(0.55, 0.35, 0.03), tc)
		"marker":
			mb.torus(Vector3.ZERO, 0.45, 0.6, Color(tc.r, tc.g, tc.b, 0.2))
		"lair":
			for i in 6:
				var a := TAU * i / 6.0 + rng.randf()
				mb.sphere(Vector3(cos(a) * 1.4, 0.2, sin(a) * 1.4), 0.5, Color(0.35, 0.32, 0.3), Vector3(1, 0.6, 1), 5, 3)
			for i in 5:
				var a := rng.randf() * TAU
				mb.box(Vector3(cos(a) * 0.7, 0.08, sin(a) * 0.7), Vector3(0.6, 0.08, 0.08), Color(0.9, 0.88, 0.8), Vector3(0, rng.randf() * PI, 0))
			mb.sphere(Vector3(0.4, 0.15, 0.2), 0.15, Color(0.9, 0.88, 0.8))
		_:
			mb.box(Vector3(0, 0.5, 0), Vector3(1, 1, 1), tc)


const TIER_HEAD := {"swordsman": 1.28, "spearman": 1.38, "archer": 1.36, "knight": 2.0, "mage": 1.62, "cleric": 1.3}


## Visual upgrades for unit upgrade tiers: plumes and gold pauldrons (tier 1), capes and glowing gems (tier 2).
static func _tier_extras(mb: ModelBuilder, key: String, tc: Color, tier: int) -> void:
	if key == "dragon":
		mb.cone(Vector3(0.18, 1.25, 1.65), 0.09, 0.65, GOLD, 5, Vector3(-0.9, 0, 0.2))
		mb.cone(Vector3(-0.18, 1.25, 1.65), 0.09, 0.65, GOLD, 5, Vector3(-0.9, 0, -0.2))
		for i in 5:
			mb.cone(Vector3(0, 0.62, 0.8 - i * 0.45), 0.12, 0.45, Color(1.0, 0.5, 0.15, 0.25), 4)
		return
	if not TIER_HEAD.has(key):
		return
	var h: float = TIER_HEAD[key]
	var sh := h - 0.42
	var dz := -0.05 if key == "knight" else 0.0
	mb.box(Vector3(0, h + 0.2, dz - 0.03), Vector3(0.05, 0.22, 0.28), tc.lightened(0.2), Vector3(0.3, 0, 0))
	mb.sphere(Vector3(0.24, sh, dz), 0.1, GOLD, Vector3(1.2, 0.7, 1.1))
	mb.sphere(Vector3(-0.24, sh, dz), 0.1, GOLD, Vector3(1.2, 0.7, 1.1))
	if tier >= 2:
		mb.box(Vector3(0, sh - 0.25, dz - 0.18), Vector3(0.44, 0.75, 0.04), tc.darkened(0.35), Vector3(0.12, 0, 0))
		mb.sphere(Vector3(0, sh - 0.05, dz + 0.16), 0.055, Color(0.5, 0.9, 1.0, 0.1))
		mb.box(Vector3(0, h + 0.05, dz), Vector3(0.36, 0.05, 0.36), GOLD)


static func _plinth(mb: ModelBuilder, s: float) -> void:
	mb.box(Vector3(0, -0.85, 0), Vector3(s, 2.0, s), DSTONE)


static func _legs(mb: ModelBuilder, c: Color, sc: float = 1.0) -> void:
	mb.box(Vector3(-0.09 * sc, 0.28 * sc, 0), Vector3(0.13, 0.56, 0.14) * sc, c)
	mb.box(Vector3(0.09 * sc, 0.28 * sc, 0), Vector3(0.13, 0.56, 0.14) * sc, c)


static func _arms(mb: ModelBuilder, c: Color) -> void:
	mb.box(Vector3(-0.26, 0.82, 0), Vector3(0.11, 0.44, 0.12), c)
	mb.box(Vector3(0.26, 0.82, 0.06), Vector3(0.11, 0.44, 0.12), c, Vector3(-0.45, 0, 0))
