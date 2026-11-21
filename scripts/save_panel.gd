class_name SavePanel
extends Panel
## Lists save slots. mode "save": write the current game into a slot. mode "load": start a saved game.

signal closed

var mode := "save"
var game: Game = null
var main: Node = null
var rows: VBoxContainer
var title: Label
var status: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -380
	offset_right = 380
	offset_top = -250
	offset_bottom = 250
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 20
	vb.offset_right = -20
	vb.offset_top = 14
	vb.offset_bottom = -14
	vb.add_theme_constant_override("separation", 10)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vb)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(rows)
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color", Color(0.7, 1, 0.7))
	vb.add_child(status)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(160, 44)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(close)
	vb.add_child(back)
	visible = false


func open(m: String) -> void:
	mode = m
	title.text = "Save Game" if mode == "save" else "Load Game"
	status.text = ""
	_refresh()
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _refresh() -> void:
	for c in rows.get_children():
		c.queue_free()
	for slot in SaveGame.SLOTS:
		if mode == "save" and slot == "autosave":
			continue
		var exists := SaveGame.exists(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var info := Label.new()
		info.text = "%s\n%s" % [SaveGame.SLOT_NAMES[slot], SaveGame.describe(slot)]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_font_size_override("font_size", 13)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.custom_minimum_size.x = 420
		row.add_child(info)
		var act := Button.new()
		act.custom_minimum_size = Vector2(100, 46)
		act.focus_mode = Control.FOCUS_NONE
		if mode == "save":
			act.text = "Overwrite" if exists else "Save"
			act.pressed.connect(_on_save.bind(slot))
		else:
			act.text = "Load"
			act.disabled = not exists
			act.pressed.connect(_on_load.bind(slot))
		row.add_child(act)
		var del := Button.new()
		del.text = "Delete"
		del.custom_minimum_size = Vector2(80, 46)
		del.focus_mode = Control.FOCUS_NONE
		del.disabled = not exists
		del.pressed.connect(_on_delete.bind(slot))
		row.add_child(del)
		rows.add_child(row)


func _on_save(slot: String) -> void:
	if game and game.save_to(slot):
		status.text = "Saved to %s." % SaveGame.SLOT_NAMES[slot]
		Sfx.play("complete")
	else:
		status.text = "Could not save."
	_refresh()


func _on_load(slot: String) -> void:
	if main == null:
		return
	get_tree().paused = false
	if not main.load_game(slot):
		status.text = "That save could not be read."


func _on_delete(slot: String) -> void:
	SaveGame.delete(slot)
	status.text = "Deleted %s." % SaveGame.SLOT_NAMES[slot]
	_refresh()
