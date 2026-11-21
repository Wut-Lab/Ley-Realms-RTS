extends Node
## Developer test (--autotest --savetest): play, save, reload, compare, keep playing.

var main: Node


func _ready() -> void:
	_run()


func _summary(g: Game) -> Dictionary:
	var s := {"elapsed": int(g.elapsed), "resources": g.resources.size(), "shrines": g.shrines.map(func(x): return x.owner_id)}
	for i in range(1, g.players.size()):
		var p: PlayerData = g.players[i]
		var nu := 0
		var nb := 0
		var gath := 0
		for u in g.units:
			if u.pid == i and u.alive:
				nu += 1
				if u.state == Unit.GATHER or u.state == Unit.RETURN:
					gath += 1
		for b in g.buildings:
			if b.pid == i and b.alive:
				nb += 1
		s["P%d" % i] = "units %d bld %d pop %d/%d age %d food %d wood %d gold %d mana %d champLv %d doctrines %d techs %d gatherers %d" % [
			nu, nb, p.pop, p.pop_cap, p.age, p.res["food"], p.res["wood"], p.res["gold"], p.res["mana"], p.champ_level, p.passives.size(), p.techs.size(), gath]
	return s


func _run() -> void:
	var g: Game = main.current
	while g.elapsed < 240.0:
		await get_tree().process_frame
	var before := _summary(g)
	var ok := g.save_to("slot3")
	print("SAVETEST saved=", ok, " file=", SaveGame.describe("slot3"))
	print("SAVETEST before: ", before)
	main.load_game("slot3")
	await get_tree().process_frame
	await get_tree().process_frame
	var g2: Game = main.current
	var after := _summary(g2)
	print("SAVETEST after:  ", after)
	var diff := []
	for k in before:
		if str(before[k]) != str(after[k]):
			diff.append(k)
	print("SAVETEST differences: ", diff)
	var t0 := g2.elapsed
	while g2.elapsed < t0 + 120.0:
		await get_tree().process_frame
	print("SAVETEST continued: ", _summary(g2))
	print("SAVETEST DONE")
	get_tree().quit()
