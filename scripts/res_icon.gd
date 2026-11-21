class_name ResIcon
extends Control
## Small drawn resource glyph for the top bar.

var res := "food"


func _draw() -> void:
	var c: Color = Defs.RES_COLORS[res]
	var s := size
	var m := s * 0.5
	match res:
		"food":
			draw_circle(m + Vector2(0, 1), s.x * 0.38, c)
			draw_line(m + Vector2(0, -s.y * 0.3), m + Vector2(3, -s.y * 0.5), Color(0.3, 0.6, 0.2), 2.0)
		"wood":
			draw_rect(Rect2(Vector2(2, s.y * 0.3), Vector2(s.x - 4, s.y * 0.4)), c)
			draw_circle(Vector2(s.x - 3, m.y), s.y * 0.2, c.lightened(0.3))
		"gold":
			var pts := PackedVector2Array([Vector2(m.x, 1), Vector2(s.x - 1, m.y), Vector2(m.x, s.y - 1), Vector2(1, m.y)])
			draw_colored_polygon(pts, c)
		"mana":
			var pts := PackedVector2Array([Vector2(m.x, 0), Vector2(s.x - 3, m.y), Vector2(m.x, s.y), Vector2(3, m.y)])
			draw_colored_polygon(pts, c)
			draw_colored_polygon(PackedVector2Array([Vector2(m.x, 3), Vector2(m.x + 2, m.y), Vector2(m.x, s.y - 3), Vector2(m.x - 2, m.y)]), c.lightened(0.5))
