class_name FactionIcon
extends Control
## Drawn faction sigil on a rimmed medallion.

var faction := "dawnspire"
var m := Vector2.ZERO
var r := 1.0
var c := Color.WHITE


func _draw() -> void:
	c = Defs.FACTIONS[faction]["color"]
	m = size * 0.5
	r = minf(size.x, size.y) * 0.5
	# medallion: rim, bevel, radial-shaded field
	draw_circle(m, r, c.darkened(0.65))
	_disc(r * 0.92, c.lightened(0.15), c.darkened(0.45))
	_disc(r * 0.8, c.darkened(0.55).lerp(Color(0.1, 0.08, 0.12), 0.4), Color(0.05, 0.04, 0.06))
	for i in 12:
		var a := TAU * i / 12.0
		draw_circle(m + Vector2(cos(a), sin(a)) * r * 0.86, r * 0.025, c.lightened(0.4))
	match faction:
		"dawnspire": _sun()
		"thornveil": _leaf()
		"ironhold": _anvil()
		"starweave": _star()
		"duskmire": _moon()
	# top-left gloss
	draw_arc(m, r * 0.74, PI * 1.05, PI * 1.45, 12, Color(1, 1, 1, 0.18), r * 0.05, true)


func _p(x: float, y: float) -> Vector2:
	return m + Vector2(x, y) * r


func _disc(rad: float, inner: Color, outer: Color) -> void:
	var pts := PackedVector2Array([m + Vector2(-0.25, -0.3) * rad])
	var cols := PackedColorArray([inner])
	for i in 41:
		var a := TAU * i / 40.0
		pts.append(m + Vector2(cos(a), sin(a)) * rad)
		cols.append(outer)
	draw_polygon(pts, cols)


## Gradient fill (light top, dark bottom) with a dark outline.
func _shape(pts: PackedVector2Array, col: Color, outline := true) -> void:
	var cols := PackedColorArray()
	for p in pts:
		var t := clampf((p.y - (m.y - r * 0.7)) / (r * 1.4), 0.0, 1.0)
		cols.append(col.lightened(0.4).lerp(col.darkened(0.3), t))
	draw_polygon(pts, cols)
	if outline:
		var o := pts.duplicate()
		o.append(pts[0])
		draw_polyline(o, Color(0.05, 0.03, 0.02, 0.9), maxf(1.0, r * 0.045), true)


func _sun() -> void:
	var rays := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0 - PI / 2
		var rr := 0.3
		if i % 2 == 0:
			rr = 0.7 if i % 4 == 0 else 0.52
		rays.append(_p(cos(a) * rr, sin(a) * rr))
	_shape(rays, c)
	var disc := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		disc.append(_p(cos(a) * 0.27, sin(a) * 0.27))
	_shape(disc, c.lightened(0.35))
	draw_arc(m, r * 0.19, 0, TAU, 24, c.darkened(0.25), maxf(1.0, r * 0.03), true)


func _leaf() -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		var w := sin(t * PI) * 0.36 + (0.07 if i % 3 == 1 else 0.0)
		pts.append(_p(w + 0.08 * (1.0 - t), lerpf(0.5, -0.68, t)))
	for i in range(11, 0, -1):
		var t := float(i) / 12.0
		var w := sin(t * PI) * 0.36 + (0.07 if i % 3 == 1 else 0.0)
		pts.append(_p(-w + 0.08 * (1.0 - t), lerpf(0.5, -0.68, t)))
	_shape(pts, c)
	var dark := c.darkened(0.55)
	var lw := maxf(1.0, r * 0.04)
	draw_line(_p(0.12, 0.72), _p(0.03, -0.55), dark, lw, true)
	for k in 3:
		var y := 0.25 - k * 0.3
		var cx := 0.08 - k * 0.025
		draw_line(_p(cx, y), _p(cx + 0.24, y - 0.18), dark, lw * 0.8, true)
		draw_line(_p(cx, y), _p(cx - 0.24, y - 0.18), dark, lw * 0.8, true)


func _anvil() -> void:
	# flame
	var fl := PackedVector2Array([_p(0, -0.72), _p(0.12, -0.5), _p(0.2, -0.62), _p(0.24, -0.38), _p(0.1, -0.28),
		_p(-0.1, -0.28), _p(-0.24, -0.4), _p(-0.16, -0.56), _p(-0.08, -0.46)])
	_shape(fl, Color(1.0, 0.55, 0.15))
	draw_colored_polygon(PackedVector2Array([_p(0, -0.52), _p(0.08, -0.34), _p(-0.08, -0.34)]), Color(1, 0.9, 0.5))
	var av := PackedVector2Array([_p(-0.72, -0.22), _p(-0.4, -0.24), _p(0.52, -0.24), _p(0.6, -0.12),
		_p(0.3, -0.04), _p(0.18, 0.04), _p(0.18, 0.26), _p(0.42, 0.42), _p(0.42, 0.52), _p(-0.42, 0.52),
		_p(-0.42, 0.42), _p(-0.18, 0.26), _p(-0.18, 0.04), _p(-0.36, -0.06)])
	_shape(av, c)
	draw_line(_p(-0.38, -0.17), _p(0.48, -0.17), c.lightened(0.5), maxf(1.0, r * 0.04), true)


func _star() -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0 - PI / 2
		var rr := 0.2
		if i % 2 == 0:
			rr = 0.72 if i % 4 == 0 else 0.46
		pts.append(_p(cos(a) * rr, sin(a) * rr))
	_shape(pts, c)
	var inner := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8.0 - PI / 2
		var rr := 0.26 if i % 2 == 0 else 0.1
		inner.append(_p(cos(a) * rr, sin(a) * rr))
	_shape(inner, Color(0.95, 0.97, 1.0), false)
	for s in [Vector2(-0.48, -0.5), Vector2(0.5, 0.46), Vector2(0.52, -0.42)]:
		draw_circle(_p(s.x, s.y), r * 0.04, Color(1, 1, 1, 0.85))


func _moon() -> void:
	var pts := PackedVector2Array()
	for i in 21:
		var a := lerpf(-PI * 0.78, PI * 0.78, i / 20.0) + PI
		pts.append(_p(cos(a) * 0.6, sin(a) * 0.6))
	for i in range(19, 0, -1):
		var a := lerpf(-PI * 0.62, PI * 0.62, i / 20.0) + PI
		pts.append(_p(0.24 + cos(a) * 0.48, sin(a) * 0.48))
	_shape(pts, c)
	for s in [[Vector2(0.38, -0.22), 0.12], [Vector2(0.22, 0.3), 0.07], [Vector2(0.52, 0.12), 0.05]]:
		var p: Vector2 = s[0]
		var k: float = s[1]
		var st := PackedVector2Array()
		for i in 8:
			var a := TAU * i / 8.0 - PI / 2
			var rr := k if i % 2 == 0 else k * 0.35
			st.append(_p(p.x + cos(a) * rr, p.y + sin(a) * rr))
		draw_colored_polygon(st, Color(1, 0.95, 1.0))
