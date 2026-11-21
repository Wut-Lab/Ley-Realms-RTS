class_name Overlay
extends Control
## Screen-space health bars, construction/capture progress and drag box.

var game: Game


func _process(_d: float) -> void:
	queue_redraw()


func _bar(c: Camera3D, wp: Vector3, w: float, frac: float, col: Color) -> void:
	if c.is_position_behind(wp):
		return
	var sp := c.unproject_position(wp)
	if sp.x < -50 or sp.y < -50 or sp.x > size.x + 50 or sp.y > size.y + 50:
		return
	var r := Rect2(sp - Vector2(w * 0.5, 0), Vector2(w, 5))
	draw_rect(r.grow(1), Color(0, 0, 0, 0.75))
	draw_rect(Rect2(r.position, Vector2(w * clampf(frac, 0, 1), 5)), col)


func _col(pid: int) -> Color:
	if pid == game.human:
		return Color(0.3, 0.95, 0.35)
	if pid == 0:
		return Color(1.0, 0.6, 0.2)
	return Color(0.95, 0.85, 0.2) if not game.is_enemy(game.human, pid) else Color(0.95, 0.25, 0.2)


func _draw() -> void:
	if game == null or game.cam == null:
		return
	var c := game.cam.cam
	var zoom := clampf(40.0 / game.cam.dist, 0.6, 1.6)
	for u in game.units:
		if u.alive and u.visible and (u.selected or u.hp < u.max_hp) and not (u is Champion):
			_bar(c, u.position + Vector3.UP * (u.height + 0.5 + (0.9 if u.flying else 0.0)), 30.0 * zoom, u.hp / u.max_hp, _col(u.pid))
	var font := ThemeDB.fallback_font
	for i in range(1, game.players.size()):
		var ch = game.players[i].champ
		if ch == null or not is_instance_valid(ch) or not ch.alive or not ch.visible:
			continue
		var top: Vector3 = ch.position + Vector3.UP * (ch.height + 0.5)
		if c.is_position_behind(top):
			continue
		var sp := c.unproject_position(top)
		var w := 40.0 * zoom
		draw_rect(Rect2(sp + Vector2(-w * 0.5, -1), Vector2(w, 7)).grow(1), Color(0, 0, 0, 0.75))
		draw_rect(Rect2(sp + Vector2(-w * 0.5, -1), Vector2(w * ch.hp / ch.max_hp, 4)), _col(ch.pid))
		draw_rect(Rect2(sp + Vector2(-w * 0.5, 3), Vector2(w * ch.xp_progress(), 3)), Color(0.75, 0.5, 1.0))
		draw_string(font, sp + Vector2(-w * 0.5 - 30, 7), "Lv%d" % ch.level(), HORIZONTAL_ALIGNMENT_RIGHT, 28, 12, Color(1, 0.88, 0.45))
	for b in game.buildings:
		if b.alive and b.visible and (b.selected or b.hp < b.max_hp or not b.complete or b.garrison.size() > 0):
			var top: Vector3 = b.position + Vector3.UP * (b.height * (b.model.scale.y) + 0.6)
			_bar(c, top, 16.0 * b.size * zoom, b.hp / b.max_hp, _col(b.pid))
			if b.garrison.size() > 0 and not c.is_position_behind(top):
				var gp := c.unproject_position(top) + Vector2(8.0 * b.size * zoom + 6, 6)
				draw_circle(gp, 9, Color(0.1, 0.08, 0.05, 0.85))
				draw_string(font, gp + Vector2(-5, 5), str(b.garrison.size()), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.85, 0.45))
			if not b.complete:
				_bar(c, top + Vector3.UP * 0.01 - c.global_transform.basis.y * 0.35, 16.0 * b.size * zoom, b.progress, Color(0.35, 0.65, 1.0))
	for s in game.shrines:
		if s.capture > 0.0 and (s.capture < 1.0 or s.contested) and game.fog_visible(s.pos2()):
			var who: int = s.owner_id if s.owner_id >= 0 else s.capturer
			var col: Color = game.players[who].color if who >= 0 else Color.WHITE
			_bar(c, s.position + Vector3.UP * 4.0, 60.0 * zoom, s.capture, col)
	var ctl := game.ctl
	if ctl and ctl.dragging and ctl.drag_start.distance_to(ctl.drag_now) > 8.0:
		var r := Rect2(ctl.drag_start, Vector2.ZERO).expand(ctl.drag_now)
		draw_rect(r, Color(0.4, 1.0, 0.45, 0.12))
		draw_rect(r, Color(0.4, 1.0, 0.45, 0.8), false, 1.5)
