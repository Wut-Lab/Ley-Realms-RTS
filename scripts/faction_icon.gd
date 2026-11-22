class_name FactionIcon
extends Control
## Drawn faction sigil: sun, thorn-leaf, anvil or star.

var faction := "dawnspire"


func _draw() -> void:
	var f: Dictionary = Defs.FACTIONS[faction]
	var c: Color = f["color"]
	var s := minf(size.x, size.y)
	var m := size * 0.5
	var r := s * 0.5
	draw_circle(m, r, Color(0.08, 0.06, 0.05, 0.85))
	draw_arc(m, r - 1.0, 0, TAU, 32, c.darkened(0.3), 1.5, true)
	match faction:
		"dawnspire":
			for i in 12:
				var a := TAU * i / 12.0
				var d := Vector2(cos(a), sin(a))
				var w := Vector2(-d.y, d.x) * r * 0.1
				var len := r * (0.82 if i % 2 == 0 else 0.68)
				draw_colored_polygon(PackedVector2Array([m + d * r * 0.3 + w, m + d * len, m + d * r * 0.3 - w]), c)
			draw_circle(m, r * 0.34, c.lightened(0.3))
		"thornveil":
			var leaf := PackedVector2Array()
			for i in 17:
				var t := float(i) / 16.0
				var y := lerpf(-0.78, 0.6, t)
				leaf.append(m + Vector2(sin(t * PI) * 0.42, y) * r)
			for i in range(15, 0, -1):
				var t := float(i) / 16.0
				leaf.append(m + Vector2(-sin(t * PI) * 0.42, lerpf(-0.78, 0.6, t)) * r)
			draw_colored_polygon(leaf, c)
			draw_line(m + Vector2(0, -0.6) * r, m + Vector2(0, 0.8) * r, c.darkened(0.5), 1.5)
			for sd in [-1.0, 1.0]:
				for y in [-0.2, 0.25]:
					var p := m + Vector2(sd * 0.4, y) * r
					draw_colored_polygon(PackedVector2Array([p, p + Vector2(sd * 0.25, -0.12) * r, p + Vector2(0, -0.2) * r]), c.darkened(0.2))
		"ironhold":
			draw_colored_polygon(PackedVector2Array([m + Vector2(-0.7, -0.35) * r, m + Vector2(0.5, -0.35) * r,
				m + Vector2(0.75, -0.15) * r, m + Vector2(0.25, -0.05) * r, m + Vector2(0.25, 0.25) * r,
				m + Vector2(-0.3, 0.25) * r, m + Vector2(-0.3, -0.05) * r, m + Vector2(-0.6, -0.15) * r]), c)
			draw_rect(Rect2(m + Vector2(-0.5, 0.25) * r, Vector2(1.0, 0.22) * r), c.darkened(0.2))
			draw_circle(m + Vector2(0, -0.62) * r, r * 0.12, Color(1.0, 0.55, 0.2))
		"starweave":
			var pts := PackedVector2Array()
			for i in 16:
				var a := TAU * i / 16.0 - PI / 2
				var rr := r * (0.85 if i % 2 == 0 else (0.3 if i % 4 == 1 else 0.38))
				pts.append(m + Vector2(cos(a), sin(a)) * rr)
			draw_colored_polygon(pts, c)
			draw_circle(m, r * 0.16, Color(1, 1, 1, 0.9))
