class_name HUD
extends CanvasLayer
## In-game interface.

const HOTKEYS := [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_A, KEY_S, KEY_D, KEY_F, KEY_G, KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B]
const HOTKEY_NAMES := ["Q", "W", "E", "R", "T", "A", "S", "D", "F", "G", "Z", "X", "C", "V", "B"]

var game: Game
var root: Control
var res_labels := {}
var pop_label: Label
var age_label: Label
var time_label: Label
var shrine_label: Label
var center_label: Label
var minimap: Minimap
var info_name: Label
var info_owner: Label
var info_hp: ProgressBar
var info_hp_label: Label
var info_stats: Label
var queue_buttons: Array = []
var multi_buttons: Array = []
var multi_kinds: Array = []
var cmd_buttons: Array = []
var cmds: Array = []
var tip_panel: PanelContainer
var tip_label: RichTextLabel
var hover_idx := -1
var msg_box: VBoxContainer
var overlay: Overlay
var pause_panel: Panel
var help_panel: Panel
var over_panel: Panel
var refresh_t := 0.0
var champ_btn: Button
var doctrine_panel: Panel
var doctrine_title: Label
var doctrine_buttons: Array = []
var doctrine_dismissed := -1
var save_panel: SavePanel
var touch_bar: VBoxContainer
var context_bar: HBoxContainer
var multi_btn: Button
var context_buttons := {}
var press_t := {}
var tip_hide_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.make()
	add_child(root)
	overlay = Overlay.new()
	overlay.game = game
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	_build_top()
	_build_bottom()
	_build_tooltip()
	msg_box = VBoxContainer.new()
	msg_box.position = Vector2(12, 46)
	msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(msg_box)
	center_label = _label("", 20)
	center_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	center_label.position = Vector2(-300, 46)
	center_label.size = Vector2(600, 30)
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(center_label)
	_build_pause()
	_build_help()
	_build_doctrine()
	if GameSettings.touch_active:
		_build_touch()
	selection_changed()
	_ignore_containers(root)


## Layout containers must never swallow clicks/taps meant for the 3D world.
func _ignore_containers(n: Node) -> void:
	for c in n.get_children():
		if c is Container and not (c is ScrollContainer):
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_containers(c)


func _label(text: String, fs: int = 14, col: Color = Color(0.96, 0.9, 0.78)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_top() -> void:
	var top := Panel.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 38
	root.add_child(top)
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 14
	hb.offset_right = -10
	hb.add_theme_constant_override("separation", 18)
	top.add_child(hb)
	for r in Defs.RES:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		var icon := ResIcon.new()
		icon.res = r
		icon.custom_minimum_size = Vector2(18, 18)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(icon)
		var l := _label("0", 16)
		l.custom_minimum_size.x = 64
		box.add_child(l)
		box.tooltip_text = Defs.RES_NAMES[r]
		res_labels[r] = l
		hb.add_child(box)
	pop_label = _label("", 16)
	hb.add_child(pop_label)
	champ_btn = Button.new()
	champ_btn.focus_mode = Control.FOCUS_NONE
	champ_btn.tooltip_text = "Select your champion (` or F2). Double-click to jump to it."
	champ_btn.pressed.connect(_on_champ_btn)
	champ_btn.add_theme_color_override("font_color", Color(1, 0.85, 0.45))
	hb.add_child(champ_btn)
	shrine_label = _label("", 15, Color(0.6, 0.95, 1.0))
	hb.add_child(shrine_label)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(sp)
	age_label = _label("", 16, Color(1, 0.85, 0.5))
	hb.add_child(age_label)
	time_label = _label("", 16)
	time_label.custom_minimum_size.x = 64
	hb.add_child(time_label)
	var mb := Button.new()
	mb.text = "Menu" if GameSettings.touch_active else "Menu (Esc)"
	mb.focus_mode = Control.FOCUS_NONE
	mb.pressed.connect(toggle_pause)
	hb.add_child(mb)
	for c in hb.get_children():
		if c is Control:
			c.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _build_bottom() -> void:
	var bot := Panel.new()
	bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot.offset_top = -214
	root.add_child(bot)
	minimap = Minimap.new()
	minimap.game = game
	minimap.position = Vector2(10, 10)
	minimap.size = Vector2(194, 194)
	bot.add_child(minimap)
	# selection info
	var info := VBoxContainer.new()
	info.anchor_left = 0.0
	info.anchor_right = 1.0
	info.anchor_bottom = 1.0
	info.offset_left = 222
	info.offset_right = -410
	info.offset_top = 10
	info.offset_bottom = -8
	info.add_theme_constant_override("separation", 4)
	bot.add_child(info)
	var row := HBoxContainer.new()
	info_name = _label("", 20, Color(1, 0.9, 0.6))
	row.add_child(info_name)
	info_owner = _label("", 14)
	info_owner.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(info_owner)
	info.add_child(row)
	var hprow := HBoxContainer.new()
	info_hp = ProgressBar.new()
	info_hp.custom_minimum_size = Vector2(260, 16)
	info_hp.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.3, 0.8, 0.3)
	info_hp.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.05, 0.05)
	info_hp.add_theme_stylebox_override("background", bg)
	hprow.add_child(info_hp)
	info_hp_label = _label("", 13)
	hprow.add_child(info_hp_label)
	info.add_child(hprow)
	info_stats = _label("", 13, Color(0.86, 0.82, 0.72))
	info_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_stats.custom_minimum_size.x = 300
	info.add_child(info_stats)
	var qrow := HBoxContainer.new()
	qrow.add_theme_constant_override("separation", 4)
	for i in 6:
		var b := Button.new()
		b.custom_minimum_size = Vector2(70, 34)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 11)
		b.tooltip_text = "Click to cancel"
		b.pressed.connect(_on_queue_pressed.bind(i))
		b.visible = false
		qrow.add_child(b)
		queue_buttons.append(b)
	info.add_child(qrow)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for i in 12:
		var b := Button.new()
		b.custom_minimum_size = Vector2(92, 30)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(_on_multi_pressed.bind(i))
		b.visible = false
		grid.add_child(b)
		multi_buttons.append(b)
	info.add_child(grid)
	# command card
	var cg := GridContainer.new()
	cg.columns = 5
	cg.add_theme_constant_override("h_separation", 5)
	cg.add_theme_constant_override("v_separation", 5)
	cg.anchor_left = 1.0
	cg.anchor_right = 1.0
	cg.offset_left = -400
	cg.offset_top = 12
	cg.offset_right = -10
	bot.add_child(cg)
	for i in 15:
		var b := Button.new()
		b.custom_minimum_size = Vector2(73, 60)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 11)
		b.clip_text = true
		b.pressed.connect(_on_cmd_pressed.bind(i))
		b.mouse_entered.connect(_on_cmd_hover.bind(i))
		b.button_down.connect(_on_cmd_down.bind(i))
		b.mouse_exited.connect(_on_cmd_unhover.bind(i))
		cg.add_child(b)
		cmd_buttons.append(b)


func _build_tooltip() -> void:
	tip_panel = PanelContainer.new()
	tip_panel.anchor_left = 1.0
	tip_panel.anchor_right = 1.0
	tip_panel.anchor_top = 1.0
	tip_panel.anchor_bottom = 1.0
	tip_panel.offset_left = -400
	tip_panel.offset_right = -10
	tip_panel.offset_bottom = -220
	tip_panel.offset_top = -340
	tip_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_label = RichTextLabel.new()
	tip_label.bbcode_enabled = true
	tip_label.fit_content = true
	tip_label.custom_minimum_size = Vector2(370, 20)
	tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_label.add_theme_font_size_override("normal_font_size", 14)
	tip_label.add_theme_font_size_override("bold_font_size", 15)
	var mc := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, 8)
	mc.add_child(tip_label)
	tip_panel.add_child(mc)
	tip_panel.visible = false
	root.add_child(tip_panel)


func _center_panel(w: float, h: float) -> Panel:
	var p := Panel.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.offset_left = -w / 2
	p.offset_right = w / 2
	p.offset_top = -h / 2
	p.offset_bottom = h / 2
	p.visible = false
	root.add_child(p)
	return p


func _build_pause() -> void:
	pause_panel = _center_panel(360, 572)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 30
	vb.offset_right = -30
	vb.offset_top = 24
	vb.offset_bottom = -24
	vb.add_theme_constant_override("separation", 12)
	pause_panel.add_child(vb)
	var t := _label("Paused", 26, Color(1, 0.85, 0.5))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	for pair in [["Resume", toggle_pause], ["Save Game", _open_save], ["Save & Quit", _save_and_quit],
			["Controls (F1)", toggle_help], ["Concede", _concede], ["Quit without saving", _quit]]:
		var b := Button.new()
		b.text = pair[0]
		b.custom_minimum_size.y = 40
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(pair[1])
		vb.add_child(b)
	vb.add_child(Sfx.volume_controls())
	save_panel = SavePanel.new()
	save_panel.game = game
	root.add_child(save_panel)
	save_panel.closed.connect(func(): pause_panel.visible = get_tree().paused)


func _build_help() -> void:
	help_panel = _center_panel(620, 560)
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.offset_left = 24
	l.offset_right = -24
	l.offset_top = 18
	l.offset_bottom = -60
	l.text = """[b][font_size=22]Controls[/font_size][/b]

[b]Left click[/b] select  •  [b]drag[/b] box-select  •  [b]double-click[/b] select all of type  •  [b]Shift[/b] add to selection
[b]Right click[/b] move / attack / gather / build / repair  (with a building selected: set rally point)
[b]Command card hotkeys[/b] Q W E R T / A S D F G / Z X C V B
[b]A[/b] attack-move (military)  •  [b]S[/b] stop  •  [b]D[/b] hold position  •  [b]F[/b] garrison (then click a Town Hall or tower)
[b]Town Hall[/b]: C ungarrison, V Town Bell / All Clear  •  [b]Wall[/b]: Q Make Gate
[b]Arrow keys / screen edge[/b] pan  •  [b]Mouse wheel[/b] zoom  •  [b]Middle drag / PgUp PgDn[/b] rotate  •  [b]Home[/b] reset view
[b]Ctrl+0-9[/b] set control group  •  [b]0-9[/b] select group (double-tap to jump)
[b]` or F2[/b] select champion (twice to jump)  •  champion abilities Q W E R, learn Z X C V
[b]H[/b] town hall  •  [b].[/b] next idle peasant  •  [b]Space[/b] centre on selection  •  [b]Delete[/b] destroy selected
[b]+ / -[/b] game speed  •  [b]Esc[/b] cancel / pause

[b]Building[/b]: select peasants and pick a building. Place it anywhere valid (green). [b]R[/b] rotates, [b]Shift[/b]-click places several. Walls: click and drag a line.

[b]Economy[/b]: Food (berries, farms), Wood (trees), Gold (mines), Mana (crystals and captured Ley Shrines).
[b]Ages[/b]: research the next Age at your Town Hall to unlock new buildings and units.
[b]Ley Shrines[/b]: stand units next to a shrine to capture it. Shrines produce mana, and holding all of them wins by Dominion (when enabled).
[b]Counters[/b]: spearmen beat knights, archers and spears hit dragons, catapults crush buildings, mages blast clumps."""
	help_panel.add_child(l)
	var b := Button.new()
	b.text = "Close"
	b.anchor_left = 0.5
	b.anchor_right = 0.5
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = -60
	b.offset_right = 60
	b.offset_top = -50
	b.offset_bottom = -14
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(toggle_help)
	help_panel.add_child(b)


# ---------------------------------------------------------------- public API
func message(text: String, col: Color = Color.WHITE) -> void:
	if msg_box == null:
		return
	var l := _label(text, 15, col)
	msg_box.add_child(l)
	while msg_box.get_child_count() > 7:
		msg_box.get_child(0).queue_free()
		msg_box.remove_child(msg_box.get_child(0))
	var tw := l.create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.5)
	tw.tween_callback(l.queue_free)


func ping(p: Vector2) -> void:
	if minimap:
		minimap.ping(p)


func toggle_pause() -> void:
	if game.over:
		return
	var paused := not get_tree().paused
	get_tree().paused = paused
	pause_panel.visible = paused
	if not paused:
		help_panel.visible = false
		save_panel.visible = false


func toggle_help() -> void:
	help_panel.visible = not help_panel.visible


func _quit() -> void:
	game.quit_to_menu()


func _concede() -> void:
	if game.over:
		return
	toggle_pause()
	game.concede()


func _open_save() -> void:
	pause_panel.visible = false
	save_panel.open("save")


func _save_and_quit() -> void:
	if game.save_to():
		Sfx.play("complete")
		game.quit_to_menu()
	else:
		message("Could not save the game.", Color(1, 0.4, 0.3))


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if save_panel.visible:
				save_panel.close()
			elif help_panel.visible:
				help_panel.visible = false
			else:
				toggle_pause()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F1:
			toggle_help()


func hotkey(k: int) -> void:
	var i := HOTKEYS.find(k)
	if i >= 0:
		_on_cmd_pressed(i)


func selection_changed() -> void:
	refresh_t = 0.0


func show_game_over(won: bool, how: String) -> void:
	tip_panel.visible = false
	Sfx.play("victory" if won else "defeat")
	over_panel = _center_panel(760, 470)
	over_panel.visible = true
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 30
	vb.offset_right = -30
	vb.offset_top = 20
	vb.offset_bottom = -20
	vb.add_theme_constant_override("separation", 10)
	over_panel.add_child(vb)
	var t := _label("VICTORY!" if won else "DEFEAT", 40, Color(1, 0.85, 0.35) if won else Color(1, 0.35, 0.3))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var sub := _label(("Your realm prevails by %s." if won else "Your realm has fallen (%s).") % how, 17)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var tl := _label("Game time %s" % _fmt_time(game.elapsed), 14)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tl)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 6)
	for h in ["Player", "Trained", "Killed", "Lost", "Built", "Razed", "Gathered"]:
		grid.add_child(_label(h, 15, Color(1, 0.85, 0.5)))
	for i in range(1, game.players.size()):
		var p: PlayerData = game.players[i]
		grid.add_child(_label(p.name, 15, p.color.lightened(0.3)))
		for k in ["trained", "killed", "lost", "built", "razed", "gathered"]:
			grid.add_child(_label(str(int(p.stats[k])), 15))
	vb.add_child(grid)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sp)
	var b := Button.new()
	b.text = "Return to Main Menu"
	b.custom_minimum_size = Vector2(240, 44)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_quit)
	vb.add_child(b)


static func _fmt_time(t: float) -> String:
	var s := int(t)
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]


# ---------------------------------------------------------------- per-frame
func _process(delta: float) -> void:
	if game == null:
		return
	var p: PlayerData = game.players[game.human]
	for r in Defs.RES:
		res_labels[r].text = str(int(p.res[r]))
	var cap := mini(p.pop_cap, p.max_pop)
	pop_label.text = "Pop %d/%d" % [p.pop, cap]
	pop_label.add_theme_color_override("font_color", Color(1, 0.5, 0.4) if p.pop >= cap else Color(0.96, 0.9, 0.78))
	age_label.text = Defs.AGE_NAMES[p.age]
	if p.champ_class == "":
		champ_btn.visible = false
	else:
		var cn: String = Defs.CHAMPIONS[p.champ_class]["name"]
		if p.champ != null and is_instance_valid(p.champ) and p.champ.alive:
			var extra := ""
			if p.champ_points > 0:
				extra += "  +%d skill" % p.champ_points
			if p.passive_pending() > 0:
				extra += "  +doctrine!"
			champ_btn.text = "%s  Lv %d%s" % [cn, p.champ_level, extra]
		elif p.champ_respawn >= 0.0:
			champ_btn.text = "%s returns in %ds" % [cn, maxi(0, ceili(p.champ_respawn - game.elapsed))]
		else:
			champ_btn.text = cn
	time_label.text = _fmt_time(game.elapsed)
	if game.shrines.size() > 0:
		var mine := 0
		for s in game.shrines:
			if s.owner_id > 0 and game.players[s.owner_id].team == p.team:
				mine += 1
		shrine_label.text = "Shrines %d/%d" % [mine, game.shrines.size()]
	var ct := ""
	if game.victory_mode > 0 and game.control_team >= 0:
		var mine2: bool = game.control_team == p.team
		ct = ("Dominion in " if mine2 else "Enemy Dominion in ") + _fmt_time(game.control_timer)
		center_label.add_theme_color_override("font_color", Color(0.5, 1, 0.6) if mine2 else Color(1, 0.45, 0.35))
	elif game.elapsed < game.peace_until:
		ct = "Peace treaty: " + _fmt_time(game.peace_until - game.elapsed)
		center_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1))
	center_label.text = ct
	_update_doctrine(p)
	if GameSettings.touch_active:
		_update_touch(delta)
	refresh_t -= delta
	if refresh_t <= 0.0:
		refresh_t = 0.2
		_refresh_selection()
		_refresh_commands()
		if hover_idx >= 0:
			_on_cmd_hover(hover_idx)


func _refresh_selection() -> void:
	var sel: Array = game.ctl.sel.filter(func(e): return is_instance_valid(e))
	for b in queue_buttons:
		b.visible = false
	for b in multi_buttons:
		b.visible = false
	if sel.is_empty():
		info_name.text = ""
		info_owner.text = ""
		info_hp.visible = false
		info_hp_label.text = ""
		info_stats.text = "Tap units or buildings. Long-press and drag to box-select; pinch to zoom." if GameSettings.touch_active else "Select units or buildings. Press F1 for controls."
		return
	if sel.size() > 1:
		var groups := {}
		var order: Array = []
		for e in sel:
			if not groups.has(e.kind):
				groups[e.kind] = 0
				order.append(e.kind)
			groups[e.kind] += 1
		info_name.text = "%d units selected" % sel.size()
		info_owner.text = ""
		var hp := 0.0
		var mhp := 0.0
		for e in sel:
			hp += e.hp
			mhp += e.max_hp
		info_hp.visible = true
		info_hp.max_value = mhp
		info_hp.value = hp
		info_hp_label.text = " %d / %d" % [hp, mhp]
		info_stats.text = ("Tap" if GameSettings.touch_active else "Click") + " a group to select only that type."
		multi_kinds = order
		for i in mini(order.size(), multi_buttons.size()):
			multi_buttons[i].visible = true
			multi_buttons[i].text = "%s x%d" % [game.unit_def(game.human, order[i])["name"].replace(" (Hero)", ""), groups[order[i]]]
		return
	var e = sel[0]
	info_name.text = e.display_name()
	if e is Entity:
		var op: PlayerData = game.players[e.pid]
		info_owner.text = "   " + op.name
		info_owner.add_theme_color_override("font_color", op.color.lightened(0.3))
		if e is Unit and e.recruit_group >= 0:
			info_owner.text = "   Freeblades (neutral)"
			info_owner.add_theme_color_override("font_color", Color(1, 0.9, 0.55))
		info_hp.visible = true
		info_hp.max_value = e.max_hp
		info_hp.value = e.hp
		info_hp_label.text = " %d / %d" % [e.hp, e.max_hp]
		if e is Unit and e.recruit_group >= 0:
			info_stats.text = "A band of freeblades looking for a cause. The first player to bring any unit within %d of them recruits the whole band.\n%s" % [int(Defs.RECRUIT_REACH), _unit_text(e)]
		elif e is Unit:
			info_stats.text = _unit_text(e)
		else:
			info_stats.text = _building_text(e)
			if e.pid == game.human:
				for i in mini(e.queue.size(), 6):
					var q: Dictionary = e.queue[i]
					var nm: String = Defs.UNITS[q["id"]]["name"] if not q["tech"] else Defs.TECHS[q["id"]]["name"].replace("Advance: ", "")
					var b: Button = queue_buttons[i]
					b.visible = true
					b.text = nm.substr(0, 10) + ("\n%d%%" % int(q["t"] / q["total"] * 100) if i == 0 else "")
	elif e is ResourceNode:
		info_owner.text = ""
		info_hp.visible = false
		info_hp_label.text = ""
		info_stats.text = "%s: %d / %d remaining" % [Defs.RES_NAMES[e.rtype], e.amount, e.max_amount]
	elif e is MercCamp:
		info_owner.text = "   Neutral"
		info_owner.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
		info_hp.visible = false
		info_hp_label.text = ""
		var offers: Array = []
		for k in e.offers:
			offers.append("%s (%d left)" % [Defs.UNITS[k]["name"], e.stock[k]])
		info_stats.text = "Hire mercenaries here for gold. You need a unit within %d of the camp.\nOffers: %s\nRestocks in %ds.%s" % [
			int(Defs.CAMP_REACH), ", ".join(offers), int(Defs.CAMP_RESTOCK - e.restock_t),
			"" if e.has_unit_near(game.human) else "\nNone of your units are close enough yet."]
	elif e is Shrine:
		info_owner.text = ""
		info_hp.visible = true
		info_hp.max_value = 1.0
		info_hp.value = e.capture
		info_hp_label.text = " control %d%%" % int(e.capture * 100)
		info_stats.text = "A Ley Shrine. Keep units nearby to capture it. Produces %.1f mana per second for its owner.%s" % [Shrine.MANA_RATE, "\nContested!" if e.contested else ""]


func _unit_text(u: Unit) -> String:
	var d: Dictionary = u.def
	var lines: Array = []
	if u is Champion:
		var c: Champion = u
		var p: PlayerData = c.player()
		var xp_line := "MAX LEVEL" if p.champ_level >= Defs.MAX_LEVEL else "XP %d / %d" % [p.champ_xp, Defs.XP_TABLE[p.champ_level + 1]]
		lines.append("Level %d  •  %s  •  Skill points: %d" % [p.champ_level, xp_line, p.champ_points])
		var ab: Array = []
		for i in 4:
			ab.append("%s %d" % [c.abilities()[i]["name"], c.rank(i)])
		lines.append("Abilities: " + ", ".join(ab))
		if not p.passives.is_empty():
			lines.append("Doctrines: " + ", ".join(p.passives.map(func(x): return Defs.PASSIVES[x]["name"])))
	if d.has("heal"):
		lines.append("Heals %d  •  Range %.0f" % [d["heal"], u.range_val()])
	elif d["atk"] > 0:
		lines.append("Attack %d (%s)  •  Range %.1f  •  Armor %d / %d  •  Speed %.1f" % [u.atk_val(), d["atk_type"], u.range_val(), u.armor_val(), u.parmor_val(), u.speed])
	if u.cls == "worker":
		var st := "Idle"
		match u.state:
			Unit.GATHER: st = "Gathering " + u.gtype
			Unit.RETURN: st = "Returning " + u.carry_type
			Unit.BUILD: st = "Building"
			Unit.MOVE: st = "Moving"
			Unit.ATTACK: st = "Fighting"
		if u.carry > 0.5:
			st += "  (carrying %d %s)" % [u.carry, u.carry_type]
		lines.append(st)
	lines.append(d["desc"])
	return "\n".join(lines)


func _building_text(b: Building) -> String:
	var lines: Array = []
	if not b.complete:
		lines.append("Construction %d%%" % int(b.progress * 100))
	if b.def.get("atk", 0) > 0:
		lines.append("Attack %d  •  Range %.0f" % [b.def["atk"], b.def["range"]])
	if b.def.get("pop", 0) > 0:
		lines.append("Provides %d population" % b.def["pop"])
	if b.capacity() > 0:
		lines.append("Garrisoned: %d / %d%s" % [b.garrison.size(), b.capacity(), ("  (+%d arrows)" % b.garrison.size()) if b.garrison.size() > 0 and b.def.get("atk", 0) > 0 else ""])
	if b.kind == "farm" and b.complete:
		lines.append("Farmer: " + ("working" if b.farmer and is_instance_valid(b.farmer) and b.farmer.node == b else "none - right-click with a peasant"))
	if b.stalled:
		lines.append("[Need more houses to continue training]")
	if b.pid == game.human and b.queue.size() > 0:
		var q: Dictionary = b.queue[0]
		lines.append("Producing: %d%%" % int(q["t"] / q["total"] * 100))
	lines.append(b.def["desc"])
	return "\n".join(lines)


func _on_queue_pressed(i: int) -> void:
	var b: Building = game.ctl.selected_building()
	if b and b.pid == game.human:
		b.cancel(i)
		refresh_t = 0.0


func _on_multi_pressed(i: int) -> void:
	if i >= multi_kinds.size():
		return
	var k: String = multi_kinds[i]
	game.ctl.set_selection(game.ctl.sel.filter(func(e): return is_instance_valid(e) and e.kind == k))


# ---------------------------------------------------------------- command card
func _refresh_commands() -> void:
	cmds = []
	cmds.resize(15)
	var ctl := game.ctl
	var p: PlayerData = game.players[game.human]
	var b := ctl.selected_building()
	var us := ctl.own_units()
	var camp: MercCamp = ctl.sel[0] if ctl.sel.size() == 1 and is_instance_valid(ctl.sel[0]) and ctl.sel[0] is MercCamp else null
	if camp:
		for i in camp.offers.size():
			var k: String = camp.offers[i]
			var d: Dictionary = Defs.UNITS[k]
			var reason := camp.hire_check(game.human, k)
			cmds[i] = {"label": k.capitalize(), "title": "Hire " + d["name"], "desc": d["desc"], "cost": d["cost"],
				"extra": "HP %d  •  Attack %d  •  Pop %d  •  In stock %d" % [d["hp"], d["atk"], d["pop"], camp.stock[k]],
				"ok": reason == "", "reason": reason, "act": func(): camp.hire(game.human, k)}
	elif b and b.pid == game.human:
		if not b.complete:
			cmds[14] = {"label": "Cancel", "title": "Cancel construction", "desc": "Refunds 75% of the cost.", "ok": true,
				"act": func(): _cancel_construction(b)}
		else:
			var i := 0
			if b.kind == "wall":
				var gd: Dictionary = Defs.BUILDINGS["gate"]
				var gr := "" if p.can_afford(gd["cost"]) else p.missing_text(gd["cost"])
				cmds[0] = {"label": "Make Gate", "title": "Convert to Gate", "desc": "Turn this wall section into a gate that opens for your units and blocks enemies.",
					"cost": gd["cost"], "ok": gr == "", "reason": gr, "act": func(): _make_gate(b)}
			for t in b.def.get("trains", []):
				var d: Dictionary = game.unit_def(game.human, t)
				var reason := b.check(t)
				cmds[i] = {"label": d["name"].replace(" (Hero)", ""), "title": "Train " + d["name"], "desc": d["desc"], "cost": d["cost"],
					"extra": "Time %ds  •  HP %d  •  Pop %d" % [d["time"], d["hp"], d["pop"]], "ok": reason == "", "reason": reason,
					"act": func(): _train(b, t)}
				i += 1
			for r in b.def.get("research", []):
				var td: Dictionary = Defs.TECHS[r]
				if p.techs.has(r):
					continue
				if td.has("max_age") and p.age > td["max_age"]:
					continue
				if td.has("requires") and not p.techs.has(td["requires"]):
					continue
				var reason := b.check(r)
				cmds[i] = {"label": td["name"].replace("Advance: ", ""), "title": td["name"], "desc": td["desc"], "cost": td["cost"],
					"extra": "Research time %ds" % td["time"], "ok": reason == "", "reason": reason, "tech": true,
					"act": func(): _train(b, r)}
				i += 1
			if b.capacity() > 0:
				var n := b.garrison.size()
				cmds[12] = {"label": "Ungarrison", "title": "Ungarrison (%d/%d)" % [n, b.capacity()], "desc": "Send every unit sheltering inside back out.",
					"ok": n > 0, "reason": "Nobody is inside", "act": func(): b.eject_all()}
			if b.kind == "town_hall":
				if p.bell:
					cmds[13] = {"label": "All Clear", "title": "All Clear", "desc": "Peasants leave their shelters and return to work.", "ok": true,
						"act": func(): game.all_clear(game.human)}
				else:
					cmds[13] = {"label": "Town Bell", "title": "Ring the Town Bell", "desc": "Every peasant runs to the nearest Town Hall or Watch Tower with room. Each one inside adds an arrow.",
						"ok": true, "act": func(): game.town_bell(game.human)}
			cmds[14] = {"label": "Demolish", "title": "Demolish", "desc": "Destroy this building.", "ok": true,
				"act": func(): b.die(null)}
	elif ctl.selected_champion() != null and ctl.own_workers().is_empty():
		_champion_commands(ctl.selected_champion())
	elif not us.is_empty():
		var workers := us.filter(func(u): return u.cls == "worker")
		if not workers.is_empty():
			for i in Defs.BUILD_MENU.size():
				var k: String = Defs.BUILD_MENU[i]
				var d: Dictionary = Defs.BUILDINGS[k]
				var reason := ""
				if p.age < d["age"]:
					reason = "Requires " + Defs.AGE_NAMES[d["age"]]
				elif not p.can_afford(d["cost"]):
					reason = p.missing_text(d["cost"])
				cmds[i] = {"label": d["name"].replace("Stone ", ""), "title": "Build " + d["name"], "desc": d["desc"], "cost": d["cost"],
					"extra": "HP %d  •  Build time %ds" % [d["hp"], d["time"]], "ok": reason == "", "reason": reason,
					"act": func(): ctl.begin_place(k)}
			cmds[13] = _garrison_cmd()
			cmds[14] = {"label": "Stop", "title": "Stop", "desc": "Halt current orders.", "ok": true,
				"act": func(): _stop(false)}
		else:
			cmds[8] = _garrison_cmd()
			cmds[5] = {"label": "Attack\nMove", "title": "Attack-move", "desc": "Move to a point, attacking any enemies on the way. Click the ground after pressing.", "ok": true,
				"act": _begin_amove}
			cmds[6] = {"label": "Stop", "title": "Stop", "desc": "Halt current orders.", "ok": true,
				"act": func(): _stop(false)}
			cmds[7] = {"label": "Hold", "title": "Hold position", "desc": "Stay put and only attack enemies in range.", "ok": true,
				"act": func(): _stop(true)}
	for i in 15:
		var btn: Button = cmd_buttons[i]
		var c = cmds[i]
		if c == null:
			btn.text = ""
			btn.disabled = true
			btn.modulate = Color(1, 1, 1, 0.35)
		else:
			var lab: String = c["label"]
			if lab.length() > 9 and not "\n" in lab:
				lab = lab.replace(" ", "\n")
			btn.text = lab if GameSettings.touch_active else "%s\n[%s]" % [lab, HOTKEY_NAMES[i]]
			btn.disabled = false
			btn.modulate = Color.WHITE if c["ok"] else Color(1, 0.6, 0.55, 0.75)


func _champion_commands(c: Champion) -> void:
	var p: PlayerData = c.player()
	for i in 4:
		var a: Dictionary = c.abilities()[i]
		var r := c.rank(i)
		var reason := c.cast_check(i)
		var lab: String = a["short"]
		if r > 0 and c.cds[i] > 0.0:
			lab += "\n(%ds)" % ceili(c.cds[i])
		elif r > 0:
			lab += "\n" + "*".repeat(r)
		var extra := "Rank %d/%d  •  Cooldown %ds" % [r, a["vals"].size(), a["cd"]]
		if a["target"] == "point":
			extra += "  •  Range %d" % a["range"]
		cmds[i] = {"label": lab, "title": a["name"], "desc": Defs.ability_desc(a, maxi(r, 1)), "extra": extra,
			"ok": reason == "", "reason": reason, "act": func(): ctl_cast(i)}
		if p.champ_points > 0 and r < a["vals"].size():
			var lr := c.learn_check(i)
			var nxt := Defs.ability_desc(a, r + 1)
			cmds[10 + i] = {"label": "Learn\n" + a["short"], "title": "Learn %s (rank %d)" % [a["name"], r + 1],
				"desc": nxt, "extra": "Skill points: %d" % p.champ_points, "ok": lr == "", "reason": lr,
				"act": func(): c.learn(i)}
	cmds[5] = {"label": "Attack\nMove", "title": "Attack-move", "desc": "Move, attacking enemies on the way.", "ok": true, "act": _begin_amove}
	cmds[6] = {"label": "Stop", "title": "Stop", "desc": "Halt current orders.", "ok": true, "act": func(): _stop(false)}
	cmds[7] = {"label": "Hold", "title": "Hold position", "desc": "Stay put and only attack enemies in range.", "ok": true, "act": func(): _stop(true)}
	cmds[8] = _garrison_cmd()


## Test helper: build the command card as if this building were selected.
func ctl_refresh_for_test(b: Building) -> void:
	game.ctl.set_selection([b])
	_refresh_commands()


func _garrison_cmd() -> Dictionary:
	return {"label": "Garrison", "title": "Garrison", "desc": "Shelter inside a Town Hall (12) or Watch Tower (5): units heal and each adds an arrow. Then %s the building." % ("tap" if GameSettings.touch_active else "click"),
		"ok": true, "act": _begin_garrison}


func _begin_garrison() -> void:
	game.ctl.garrison_pending = true
	message("Garrison: %s a Town Hall or Watch Tower." % ("tap" if GameSettings.touch_active else "click"), Color(0.9, 0.9, 0.6))


func _make_gate(w: Building) -> void:
	var g := game.convert_to_gate(w)
	if g:
		game.ctl.set_selection([g])
		Sfx.play("complete", -6.0)
	else:
		Sfx.play("error", -6.0)


func ctl_cast(i: int) -> void:
	game.ctl.begin_cast(i)


func _build_doctrine() -> void:
	doctrine_panel = Panel.new()
	doctrine_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	doctrine_panel.offset_left = -430
	doctrine_panel.offset_right = 430
	doctrine_panel.offset_top = 80
	doctrine_panel.offset_bottom = 300
	doctrine_panel.visible = false
	doctrine_panel.clip_contents = true
	root.add_child(doctrine_panel)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 16
	vb.offset_right = -16
	vb.offset_top = 10
	vb.offset_bottom = -10
	vb.add_theme_constant_override("separation", 8)
	doctrine_panel.add_child(vb)
	doctrine_title = _label("Choose a Doctrine", 20, Color(1, 0.85, 0.45))
	doctrine_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(doctrine_title)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(hb)
	for i in 3:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(250, 120)
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_on_doctrine.bind(i))
		hb.add_child(b)
		doctrine_buttons.append(b)
	var later := Button.new()
	later.text = "Decide later (tap your champion button to reopen)"
	later.focus_mode = Control.FOCUS_NONE
	later.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	later.pressed.connect(_on_doctrine_later)
	vb.add_child(later)


func _update_doctrine(p: PlayerData) -> void:
	var pend := p.passive_pending()
	if pend <= 0 or game.over:
		doctrine_panel.visible = false
		return
	var tier := p.passives.size()
	if doctrine_dismissed == tier:
		return
	if not doctrine_panel.visible:
		var opts: Array = p.next_passive_options()
		doctrine_title.text = "Champion level %d - choose a Doctrine for your army" % Defs.PASSIVE_TIERS[tier]["level"]
		for i in 3:
			var d: Dictionary = Defs.PASSIVES[opts[i]]
			doctrine_buttons[i].text = "%s\n\n%s" % [d["name"], d["desc"]]
		doctrine_panel.visible = true


func _on_doctrine(i: int) -> void:
	var p: PlayerData = game.players[game.human]
	var opts: Array = p.next_passive_options()
	if i < opts.size():
		game.choose_passive(game.human, opts[i])
	doctrine_panel.visible = false


func _on_doctrine_later() -> void:
	doctrine_dismissed = game.players[game.human].passives.size()
	doctrine_panel.visible = false


func _on_champ_btn() -> void:
	var p: PlayerData = game.players[game.human]
	if p.passive_pending() > 0:
		doctrine_dismissed = -1
	game.ctl.select_champion()


# ---------------------------------------------------------------- touch screen
func _build_touch() -> void:
	touch_bar = VBoxContainer.new()
	touch_bar.anchor_left = 1.0
	touch_bar.anchor_right = 1.0
	touch_bar.offset_left = -118
	touch_bar.offset_right = -8
	touch_bar.offset_top = 48
	touch_bar.add_theme_constant_override("separation", 6)
	root.add_child(touch_bar)
	for pair in [["Army", func(): game.ctl.select_army()], ["Idle", func(): game.ctl.select_idle_worker()],
			["Hero", _on_champ_btn], ["Town", func(): game.ctl.select_town_hall()],
			["Multi: Off", _toggle_multi], ["Clear", func(): game.ctl.set_selection([])]]:
		var b := _touch_button(pair[0], pair[1])
		touch_bar.add_child(b)
		if pair[0].begins_with("Multi"):
			multi_btn = b
	context_bar = HBoxContainer.new()
	context_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	context_bar.offset_left = -200
	context_bar.offset_right = 200
	context_bar.offset_top = -284
	context_bar.offset_bottom = -226
	context_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	context_bar.add_theme_constant_override("separation", 10)
	root.add_child(context_bar)
	for pair in [["Place", func(): game.ctl.touch_place_confirm()], ["Rotate", func(): game.ctl.touch_rotate()],
			["Cancel", _touch_cancel]]:
		var b := _touch_button(pair[0], pair[1])
		b.custom_minimum_size = Vector2(120, 56)
		context_bar.add_child(b)
		context_buttons[pair[0]] = b


func _touch_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(110, 50)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(cb)
	return b


func _toggle_multi() -> void:
	game.ctl.touch_multi = not game.ctl.touch_multi
	multi_btn.text = "Multi: On" if game.ctl.touch_multi else "Multi: Off"


func _touch_cancel() -> void:
	var ctl := game.ctl
	ctl.cancel_place()
	ctl.cancel_cast()
	ctl.amove_pending = false
	ctl.garrison_pending = false


func _update_touch(delta: float) -> void:
	var ctl := game.ctl
	var placing := ctl.placing != ""
	var pending := ctl.cast_pending >= 0 or ctl.amove_pending or ctl.garrison_pending
	context_bar.visible = placing or pending
	context_buttons["Place"].visible = placing
	context_buttons["Rotate"].visible = placing and ctl.placing != "wall"
	if placing:
		context_buttons["Place"].disabled = not ctl.ghost_ok and ctl.placing != "wall"
	if tip_hide_t > 0.0:
		tip_hide_t -= delta
		if tip_hide_t <= 0.0:
			tip_panel.visible = false
			hover_idx = -1


## True if a screen position is covered by an interactive HUD element.
func is_over_ui(p: Vector2) -> bool:
	for c in root.get_children():
		if c == overlay or not (c is Control) or not c.visible or c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			if c is BoxContainer and c.visible:
				for b in c.get_children():
					if b is Button and b.visible and b.get_global_rect().has_point(p):
						return true
			continue
		if c.get_global_rect().has_point(p):
			return true
	return false


func back_pressed() -> void:
	var ctl := game.ctl
	if save_panel.visible:
		save_panel.close()
	elif ctl.placing != "" or ctl.cast_pending >= 0 or ctl.amove_pending or ctl.garrison_pending:
		_touch_cancel()
	elif help_panel.visible:
		help_panel.visible = false
	else:
		toggle_pause()


func _begin_amove() -> void:
	game.ctl.amove_pending = true
	message("Attack-move: %s a destination." % ("tap" if GameSettings.touch_active else "left-click"), Color(0.9, 0.9, 0.6))


func _train(b: Building, id: String) -> void:
	if not b.enqueue(id):
		var r := b.check(id)
		message(r if r != "" else "Cannot do that now.", Color(1, 0.6, 0.4))


func _cancel_construction(b: Building) -> void:
	if is_instance_valid(b) and b.alive and not b.complete:
		game.players[b.pid].refund(b.def["cost"], 0.75)
		b.die(null)


func _stop(hold: bool) -> void:
	for u in game.ctl.own_units():
		if hold:
			u.order_hold()
		else:
			u.order_stop()


func _on_cmd_down(i: int) -> void:
	press_t[i] = Time.get_ticks_msec() / 1000.0
	if GameSettings.touch_active:
		_on_cmd_hover(i)
		tip_hide_t = 3.0


func _on_cmd_pressed(i: int) -> void:
	if i >= cmds.size() or cmds[i] == null:
		return
	# touch: press-and-hold just shows the description
	if GameSettings.touch_active and Time.get_ticks_msec() / 1000.0 - press_t.get(i, 1e9) > 0.5:
		return
	var c: Dictionary = cmds[i]
	if not c["ok"]:
		message(c.get("reason", "Not available"), Color(1, 0.6, 0.4))
		Sfx.play("error", -6.0)
		return
	c["act"].call()
	refresh_t = 0.0


func _on_cmd_hover(i: int) -> void:
	hover_idx = i
	if i >= cmds.size() or cmds[i] == null:
		tip_panel.visible = false
		return
	var c: Dictionary = cmds[i]
	var t := "[b]%s[/b]  [color=#aaa](%s)[/color]\n%s" % [c["title"], HOTKEY_NAMES[i], c["desc"]]
	if c.has("cost"):
		t += "\n[color=#ffd166]Cost: %s[/color]" % Defs.cost_text(c["cost"])
	if c.has("extra"):
		t += "\n[color=#bbb]%s[/color]" % c["extra"]
	if not c["ok"] and c.get("reason", "") != "":
		t += "\n[color=#ff7b6b]%s[/color]" % c["reason"]
	tip_label.text = t
	tip_panel.visible = true


func _on_cmd_unhover(i: int) -> void:
	if hover_idx == i:
		hover_idx = -1
		tip_panel.visible = false
