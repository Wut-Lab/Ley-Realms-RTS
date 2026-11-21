class_name MainMenu
extends Control
## Title screen and skirmish setup with live procedural map preview.

var main: Node
var title_box: VBoxContainer
var setup: Control
var how: Panel
var preview: TextureRect
var seed_edit: LineEdit
var preview_t := -1.0
var info_label: Label
var opts := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.make()
	var bg := TextureRect.new()
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(0.16, 0.12, 0.2))
	gr.set_color(1, Color(0.04, 0.03, 0.05))
	gt.gradient = gr
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.35)
	gt.fill_to = Vector2(1.1, 1.1)
	bg.texture = gt
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)
	_build_title()
	_build_setup()
	_build_how()
	GameSettings.random_seed = false
	GameSettings.map_seed = randi() % 999999


func _lbl(text: String, fs: int, col: Color = Color(0.96, 0.9, 0.78)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _build_title() -> void:
	title_box = VBoxContainer.new()
	title_box.set_anchors_preset(Control.PRESET_CENTER)
	title_box.offset_left = -260
	title_box.offset_right = 260
	title_box.offset_top = -250
	title_box.offset_bottom = 250
	title_box.add_theme_constant_override("separation", 14)
	add_child(title_box)
	var t := _lbl("LEY REALMS", 72, Color(1.0, 0.82, 0.4))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_box.add_child(t)
	var s := _lbl("A fantasy real-time strategy game", 20, Color(0.8, 0.75, 0.9))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_box.add_child(s)
	var sp := Control.new()
	sp.custom_minimum_size.y = 40
	title_box.add_child(sp)
	for pair in [["Skirmish", _show_setup], ["How to Play", _show_how], ["Quit", _quit]]:
		var b := Button.new()
		b.text = pair[0]
		b.custom_minimum_size = Vector2(320, 52)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(pair[1])
		title_box.add_child(b)
	var v := _lbl("Built with Godot 4  •  All art generated procedurally", 13, Color(0.6, 0.55, 0.6))
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_box.add_child(v)


func _option(grid: GridContainer, key: String, label: String, items: Array, value: int) -> void:
	grid.add_child(_lbl(label, 15))
	var ob := OptionButton.new()
	for it in items:
		ob.add_item(str(it))
	ob.selected = value
	ob.custom_minimum_size = Vector2(230, 30)
	ob.item_selected.connect(func(i): _on_opt(key, i))
	grid.add_child(ob)
	opts[key] = ob


func _check(grid: GridContainer, key: String, label: String, value: bool) -> void:
	grid.add_child(_lbl(label, 15))
	var cb := CheckBox.new()
	cb.button_pressed = value
	cb.text = "On" if value else "Off"
	cb.toggled.connect(_on_check.bind(key, cb))
	grid.add_child(cb)
	opts[key] = cb


func _on_check(v: bool, key: String, cb: CheckBox) -> void:
	cb.text = "On" if v else "Off"
	_on_opt(key, v)


func _section(grid: GridContainer, text: String) -> void:
	grid.add_child(_lbl(text, 18, Color(1, 0.8, 0.45)))
	grid.add_child(Control.new())


func _build_setup() -> void:
	var gs := GameSettings
	setup = Panel.new()
	setup.set_anchors_preset(Control.PRESET_FULL_RECT)
	setup.offset_left = 40
	setup.offset_right = -40
	setup.offset_top = 30
	setup.offset_bottom = -30
	setup.visible = false
	add_child(setup)
	var head := _lbl("Skirmish Setup", 30, Color(1, 0.82, 0.4))
	head.position = Vector2(28, 14)
	setup.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 24
	scroll.offset_right = 924
	scroll.offset_top = 64
	scroll.offset_bottom = -80
	setup.add_child(scroll)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 40)
	scroll.add_child(cols)
	var g1 := GridContainer.new()
	g1.columns = 2
	g1.add_theme_constant_override("h_separation", 14)
	g1.add_theme_constant_override("v_separation", 8)
	cols.add_child(g1)
	var g2 := GridContainer.new()
	g2.columns = 2
	g2.add_theme_constant_override("h_separation", 14)
	g2.add_theme_constant_override("v_separation", 8)
	cols.add_child(g2)

	_section(g1, "World")
	_option(g1, "map_size", "Map size", GameSettings.MAP_SIZE_NAMES, gs.map_size)
	_option(g1, "biome", "Biome", GameSettings.BIOME_NAMES, gs.biome)
	_option(g1, "relief", "Terrain relief", GameSettings.RELIEF_NAMES, gs.relief)
	_option(g1, "water", "Water", GameSettings.WATER_NAMES, gs.water)
	_option(g1, "forests", "Forests", GameSettings.FOREST_NAMES, gs.forests)
	_option(g1, "abundance", "Resource deposits", GameSettings.ABUNDANCE_NAMES, gs.abundance)
	_check(g1, "monsters", "Monster lairs", gs.monsters)
	_check(g1, "shrines", "Ley Shrines", gs.shrines)
	g1.add_child(_lbl("Map seed", 15))
	var sh := HBoxContainer.new()
	seed_edit = LineEdit.new()
	seed_edit.custom_minimum_size = Vector2(140, 30)
	seed_edit.text_submitted.connect(func(_t): _seed_changed())
	seed_edit.focus_exited.connect(_seed_changed)
	sh.add_child(seed_edit)
	var rb := Button.new()
	rb.text = "Randomize"
	rb.pressed.connect(_randomize_seed)
	sh.add_child(rb)
	g1.add_child(sh)

	_section(g2, "Players")
	_option(g2, "num_ai", "AI opponents", [1, 2, 3, 4, 5], gs.num_ai - 1)
	_option(g2, "difficulty", "AI difficulty", GameSettings.DIFFICULTY_NAMES, gs.difficulty)
	_option(g2, "teams", "Teams", GameSettings.TEAM_NAMES, gs.teams)
	_option(g2, "player_color", "Your colour", Defs.COLOR_NAMES.slice(1), gs.player_color - 1)
	_check(g2, "champions", "Champions (hero units)", gs.champions)
	var cn: Array = []
	for k in Defs.CHAMPION_ORDER:
		cn.append(Defs.CHAMPIONS[k]["name"])
	_option(g2, "champion_class", "Your champion", cn, gs.champion_class)
	_section(g2, "Rules")
	_option(g2, "victory", "Victory", GameSettings.VICTORY_NAMES, gs.victory)
	_option(g2, "start_age", "Starting age", GameSettings.AGE_NAMES, gs.start_age - 1)
	_option(g2, "start_res", "Starting resources", GameSettings.START_RES_NAMES, gs.start_res)
	_option(g2, "pop_cap", "Population limit", GameSettings.POP_NAMES, gs.pop_cap)
	_option(g2, "peace", "Peace treaty", GameSettings.PEACE_NAMES, gs.peace)
	_option(g2, "speed", "Game speed", GameSettings.SPEED_NAMES, gs.speed)
	_check(g2, "fog", "Fog of war", gs.fog)
	_check(g2, "reveal", "Start with map explored", gs.reveal)

	# preview
	var pv := VBoxContainer.new()
	pv.anchor_left = 1.0
	pv.anchor_right = 1.0
	pv.offset_left = -440
	pv.offset_right = -24
	pv.offset_top = 64
	pv.add_theme_constant_override("separation", 8)
	setup.add_child(pv)
	pv.add_child(_lbl("Map preview", 18, Color(1, 0.8, 0.45)))
	var frame := PanelContainer.new()
	pv.add_child(frame)
	preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(400, 400)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_SCALE
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(preview)
	info_label = _lbl("", 13, Color(0.8, 0.78, 0.72))
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size.x = 400
	pv.add_child(info_label)

	var bh := HBoxContainer.new()
	bh.anchor_top = 1.0
	bh.anchor_bottom = 1.0
	bh.anchor_left = 1.0
	bh.anchor_right = 1.0
	bh.offset_left = -440
	bh.offset_right = -24
	bh.offset_top = -66
	bh.offset_bottom = -18
	bh.alignment = BoxContainer.ALIGNMENT_END
	bh.add_theme_constant_override("separation", 12)
	setup.add_child(bh)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(140, 46)
	back.pressed.connect(_hide_setup)
	bh.add_child(back)
	var start := Button.new()
	start.text = "Start Game"
	start.custom_minimum_size = Vector2(200, 46)
	start.add_theme_font_size_override("font_size", 20)
	start.pressed.connect(_start)
	bh.add_child(start)


func _build_how() -> void:
	how = Panel.new()
	how.set_anchors_preset(Control.PRESET_CENTER)
	how.offset_left = -380
	how.offset_right = 380
	how.offset_top = -330
	how.offset_bottom = 330
	how.visible = false
	add_child(how)
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.offset_left = 26
	l.offset_right = -26
	l.offset_top = 20
	l.offset_bottom = -70
	l.text = """[font_size=26][color=#ffd166]How to Play[/color][/font_size]

You lead a young realm. Build an economy, advance through three [b]Ages[/b], raise an army and defeat your rivals.

[b][color=#ffd166]Resources[/color][/b]
[color=#ec5c52]Food[/color] berries & farms  •  [color=#a6733f]Wood[/color] trees  •  [color=#ffd640]Gold[/color] mines  •  [color=#8c73ff]Mana[/color] crystals & Ley Shrines
Peasants carry resources to your Town Hall or a Storehouse. Build Houses for population.

[b][color=#ffd166]Ages[/color][/b]
I  [b]Settlement[/b]: barracks, blacksmith, towers, walls
II [b]Steel[/b]: stables (knights), mage towers (mages, clerics), the Warden hero
III [b]Sorcery[/b]: siege workshops (catapults), dragon roosts (dragons)

[b][color=#ffd166]Ley Shrines[/color][/b]
Strategic points scattered across the map. Keep units beside one to capture it. Each shrine streams mana to its owner. With Dominion victory enabled, holding every shrine for 3 minutes wins the game.

[b][color=#ffd166]Building[/color][/b]
Select peasants, choose a building and place it anywhere you like. Press R to rotate, hold Shift to place several, and drag to lay walls.

[b][color=#ffd166]Combat[/color][/b]
Spearmen counter knights. Archers, spearmen, towers and mages can strike flying dragons; swordsmen and knights cannot. Catapults wreck buildings. Clerics heal. Monster lairs guard rich gold, and killing monsters pays bounties.

[b][color=#ffd166]Champions[/color][/b]
You lead a hero who levels up (to 10) from battle XP. Each level grants a skill point for one of four abilities; ultimates unlock at level 6. Fallen champions return to your Town Hall after a delay.
[b]Warlord[/b]: Rallying Cry, Cleaving Leap, Iron Skin, Banner of Kings.  [b]Archmage[/b]: Meteor, Frost Nova, Arcane Ward, Arcane Storm.  [b]High Priestess[/b]: Mending Light, Smite, Divine Aegis, Holy Nova.

Press [b]F1[/b] in game for the full list of controls."""
	how.add_child(l)
	var b := Button.new()
	b.text = "Back"
	b.anchor_left = 0.5
	b.anchor_right = 0.5
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = -80
	b.offset_right = 80
	b.offset_top = -58
	b.offset_bottom = -16
	b.pressed.connect(_hide_how)
	how.add_child(b)


func _show_setup() -> void:
	title_box.visible = false
	setup.visible = true
	seed_edit.text = str(GameSettings.map_seed)
	_regen_preview()


func _hide_setup() -> void:
	setup.visible = false
	title_box.visible = true


func _hide_how() -> void:
	how.visible = false
	title_box.visible = true


func _show_how() -> void:
	title_box.visible = false
	how.visible = true


func _quit() -> void:
	get_tree().quit()


func _on_opt(key: String, v) -> void:
	var gs := GameSettings
	match key:
		"num_ai": gs.num_ai = v + 1
		"start_age": gs.start_age = v + 1
		"player_color": gs.player_color = v + 1
		_: gs.set(key, v)
	if key == "champion_class":
		info_label.text = Defs.CHAMPIONS[Defs.CHAMPION_ORDER[v]]["name"] + ": " + Defs.CHAMPIONS[Defs.CHAMPION_ORDER[v]]["blurb"]
		return
	if key in ["map_size", "biome", "relief", "water", "forests", "abundance", "monsters", "shrines", "num_ai"]:
		preview_t = 0.15
	if key == "victory" and v > 0 and not gs.shrines:
		gs.shrines = true
		opts["shrines"].set_pressed_no_signal(true)
		opts["shrines"].text = "On"
	if key == "shrines" and not v and gs.victory > 0:
		gs.victory = 0
		opts["victory"].selected = 0


func _seed_changed() -> void:
	var s := seed_edit.text.strip_edges()
	var v: int = s.to_int() if s.is_valid_int() else absi(hash(s)) % 999999
	if v != GameSettings.map_seed:
		GameSettings.map_seed = v
		_regen_preview()


func _randomize_seed() -> void:
	GameSettings.map_seed = randi() % 999999
	seed_edit.text = str(GameSettings.map_seed)
	_regen_preview()


func _process(delta: float) -> void:
	if preview_t > 0.0:
		preview_t -= delta
		if preview_t <= 0.0:
			_regen_preview()


func _regen_preview() -> void:
	var md := MapGenerator.generate(GameSettings.to_dict())
	var img := MapGenerator.preview_image(md, 256)
	for i in md.starts.size():
		var col: Color
		if i == 0:
			col = Defs.PLAYER_COLORS[GameSettings.player_color]
		else:
			col = Color(0.95, 0.95, 0.95)
		MapGenerator._dot(img, md.starts[i] / md.size * 256.0, 5, Color.BLACK)
		MapGenerator._dot(img, md.starts[i] / md.size * 256.0, 4, col)
	preview.texture = ImageTexture.create_from_image(img)
	var counts := {"tree": 0, "gold_mine": 0, "mana_crystal": 0, "berry": 0}
	for r in md.resources:
		counts[r["type"]] += 1
	info_label.text = "%d×%d  •  %d players  •  Trees %d  •  Gold mines %d  •  Mana crystals %d  •  Berry bushes %d  •  Shrines %d  •  Lairs %d\nYour start is marked in your colour; opponents in white. Cyan = Ley Shrines, red = monster lairs." % [
		md.size, md.size, md.starts.size(), counts["tree"], counts["gold_mine"], counts["mana_crystal"], counts["berry"], md.shrines.size(), md.lairs.size()]


func _start() -> void:
	_seed_changed()
	GameSettings.random_seed = false
	main.start_game()
