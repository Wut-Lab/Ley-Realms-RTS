class_name TouchInput
extends Node
## Touch-screen controls for phones and tablets.
##   Tap                      select / smart command (move, attack, gather, build) / rally point
##   Double-tap a unit        select all of that type on screen
##   One-finger drag          pan the camera
##   Long-press then drag     box-select
##   Two-finger pinch / twist zoom / rotate
## Building placement, ability targeting and attack-move use taps, with on-screen
## Place / Rotate / Cancel buttons supplied by the HUD.

const TAP_SLOP := 16.0
const LONG_PRESS := 0.42
const DOUBLE_TAP := 0.35

var game: Game
var touches := {}
var mode := ""  # "", "pending", "pan", "box", "pinch", "done"
var t0 := 0.0
var start := Vector2.ZERO
var pinch_d := 0.0
var pinch_a := 0.0
var pinch_mid := Vector2.ZERO
var last_tap_t := -1.0
var last_tap_e = null


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _unhandled_input(event: InputEvent) -> void:
	if game.over or get_tree().paused:
		return
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)


func _on_touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		if game.hud.is_over_ui(e.position):
			return
		touches[e.index] = e.position
		if touches.size() == 1:
			mode = "pending"
			t0 = _now()
			start = e.position
		elif touches.size() == 2:
			_end_box(false)
			mode = "pinch"
			_init_pinch()
		return
	if not touches.has(e.index):
		return
	touches.erase(e.index)
	match mode:
		"pending":
			_tap(e.position)
		"box":
			_end_box(true)
	if touches.is_empty():
		mode = ""
	else:
		# lifting one finger of a pinch must not turn into a tap or pan jump
		mode = "done"


func _on_drag(e: InputEventScreenDrag) -> void:
	if not touches.has(e.index):
		return
	var prev: Vector2 = touches[e.index]
	touches[e.index] = e.position
	match mode:
		"pending":
			if e.position.distance_to(start) > TAP_SLOP:
				mode = "pan"
				game.cam.drag_screen(start, e.position)
		"pan":
			game.cam.drag_screen(prev, e.position)
		"box":
			game.ctl.drag_now = e.position
		"pinch":
			if touches.size() >= 2:
				var pts: Array = touches.values()
				var a: Vector2 = pts[0]
				var b: Vector2 = pts[1]
				var d := a.distance_to(b)
				var ang := (b - a).angle()
				var mid := (a + b) * 0.5
				if pinch_d > 1.0 and d > 1.0:
					game.cam.pinch(d / pinch_d)
				game.cam.twist(wrapf(ang - pinch_a, -PI, PI))
				game.cam.drag_screen(pinch_mid, mid)
				pinch_d = d
				pinch_a = ang
				pinch_mid = mid


func _init_pinch() -> void:
	var pts: Array = touches.values()
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[1]
	pinch_d = a.distance_to(b)
	pinch_a = (b - a).angle()
	pinch_mid = (a + b) * 0.5


func _process(_delta: float) -> void:
	if mode == "pending" and _now() - t0 > LONG_PRESS and game.ctl.placing == "" and game.ctl.cast_pending < 0:
		mode = "box"
		var ctl := game.ctl
		ctl.dragging = true
		ctl.drag_start = start
		ctl.drag_now = touches.values()[0] if not touches.is_empty() else start
		Input.vibrate_handheld(25)


func _end_box(apply: bool) -> void:
	var ctl := game.ctl
	if ctl.dragging:
		ctl.dragging = false
		if apply and ctl.drag_start.distance_to(ctl.drag_now) > 8.0:
			ctl._box_select(ctl.drag_start, ctl.drag_now, ctl.touch_multi)
		elif apply:
			_tap(ctl.drag_start)


func _tap(pos: Vector2) -> void:
	var ctl := game.ctl
	if ctl.cast_pending >= 0:
		ctl.touch_cast(pos)
		return
	if ctl.placing != "":
		ctl.touch_place_tap(pos)
		return
	if ctl.garrison_pending:
		ctl.try_garrison_at(pos)
		return
	if ctl.amove_pending:
		ctl.amove_pending = false
		var gp = game.cam.ground_at(pos)
		if gp != null:
			game.cmd_move(ctl.own_units(), Vector2(gp.x, gp.z), true)
			game.spawn_fx("marker", gp + Vector3.UP * 0.1, 1.0, Color.WHITE)
		return
	var e = ctl.pick(pos)
	var now := _now()
	var double: bool = e != null and e == last_tap_e and now - last_tap_t < DOUBLE_TAP
	last_tap_t = now
	last_tap_e = e
	if double and e is Unit and e.pid == game.human:
		ctl._click_select(pos, false, true)
		return
	var mine := ctl.own_units()
	var sel_b := ctl.selected_building()
	if e is Entity and e.pid == game.human and e.alive:
		# workers tapping their own construction/farm/drop-off get to work instead of selecting it
		if e is Building and not ctl.own_workers().is_empty() and not ctl.touch_multi:
			var b: Building = e
			var carrying: bool = ctl.own_workers().any(func(u): return u.carry > 0)
			if not b.complete or b.hp < b.max_hp or b.kind == "farm" or (b.def.get("dropoff", false) and carrying):
				ctl._right_click(pos)
				return
		ctl._click_select(pos, ctl.touch_multi, false)
		return
	if not mine.is_empty() or (sel_b != null and sel_b.pid == game.human and sel_b.def.has("trains")):
		ctl._right_click(pos)
		return
	ctl._click_select(pos, false, false)
