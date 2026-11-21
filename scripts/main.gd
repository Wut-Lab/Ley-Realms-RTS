extends Node
## Root scene: swaps between the main menu and a running game.

var current: Node = null
var menu: MainMenu = null


func _ready() -> void:
	get_tree().set_auto_accept_quit(true)
	GameSettings.apply_device_settings(get_window())
	if "--autotest" in OS.get_cmdline_user_args():
		GameSettings.autotest = true
		if "--featuretest" in OS.get_cmdline_user_args():
			GameSettings.ui_test = true
		if "--savetest" in OS.get_cmdline_user_args():
			var st = load("res://scripts/save_test.gd").new()
			st.main = self
			add_child.call_deferred(st)
		GameSettings.ui_test = "--uitest" in OS.get_cmdline_user_args() or "--touchtest" in OS.get_cmdline_user_args()
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--time="):
				GameSettings.autotest_time = float(a.substr(7))
			if a.begins_with("--hard="):
				GameSettings.difficulty = int(a.substr(7))
			if a.begins_with("--size="):
				GameSettings.map_size = int(a.substr(7))
			if a.begins_with("--ai="):
				GameSettings.num_ai = int(a.substr(5))
			if a.begins_with("--shots="):
				for v in a.substr(8).split(","):
					GameSettings.shots.append(float(v))
			if a.begins_with("--scale="):
				GameSettings.test_scale = float(a.substr(8))
			if a.begins_with("--menushot"):
				GameSettings.autotest = false
				show_menu()
				await get_tree().create_timer(1.0).timeout
				get_viewport().get_texture().get_image().save_png(OS.get_user_data_dir() + "/title.png")
				menu._show_load()
				await get_tree().create_timer(0.5).timeout
				get_viewport().get_texture().get_image().save_png(OS.get_user_data_dir() + "/load.png")
				menu.load_panel.close()
				menu._show_setup()
				await get_tree().create_timer(1.0).timeout
				get_viewport().get_texture().get_image().save_png(OS.get_user_data_dir() + "/menu.png")
				print("saved menu shot")
				get_tree().quit()
				return
			if a.begins_with("--age="):
				GameSettings.start_age = int(a.substr(6))
			if a.begins_with("--res="):
				GameSettings.start_res = int(a.substr(6))
			if a == "--touch":
				GameSettings.touch_mode = 1
				GameSettings.apply_device_settings(get_window())
			if a.begins_with("--biome="):
				GameSettings.biome = int(a.substr(8))
		start_game()
	else:
		show_menu()


func _swap(n: Node) -> void:
	if current and is_instance_valid(current):
		current.queue_free()
	current = n
	add_child(n)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android back button: pause in game, step back in menus
		if current is Game and current.hud:
			current.hud.back_pressed()
		elif menu and is_instance_valid(menu):
			menu.back_pressed()


func show_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	var layer := CanvasLayer.new()
	var m := MainMenu.new()
	m.main = self
	menu = m
	layer.add_child(m)
	_swap(layer)


func load_game(slot: String) -> bool:
	var data := SaveGame.read(slot)
	if data.is_empty():
		return false
	SaveGame.apply_settings(data)
	get_tree().paused = false
	var g := Game.new()
	g.main = self
	g.load_data = data
	g.save_slot = slot
	_swap(g)
	return true


func start_game() -> void:
	get_tree().paused = false
	var g := Game.new()
	g.main = self
	_swap(g)
