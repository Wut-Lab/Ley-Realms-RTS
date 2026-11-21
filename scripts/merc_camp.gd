class_name MercCamp
extends Node3D
## Neutral mercenary camp. Any player with a unit within CAMP_REACH can hire its mercenaries for gold.
## Each camp offers three mercenary types with limited stock that slowly restocks.

var game: Game
var offers: Array = []
var stock := {}
var restock_t := 0.0
var seen := true


func setup(g: Game, offer_list: Array) -> void:
	game = g
	offers = offer_list
	for k in offers:
		stock[k] = Defs.CAMP_STOCK
	var m := MeshInstance3D.new()
	m.mesh = Models.mesh("merc_camp")
	add_child(m)


func pos2() -> Vector2:
	return Vector2(position.x, position.z)


func display_name() -> String:
	return "Mercenary Camp"


func edge_dist(p: Vector2) -> float:
	return p.distance_to(pos2()) - 2.5


func tick(delta: float) -> void:
	restock_t += delta
	if restock_t >= Defs.CAMP_RESTOCK:
		restock_t = 0.0
		for k in offers:
			stock[k] = mini(Defs.CAMP_MAX_STOCK, int(stock[k]) + 1)


func has_unit_near(owner_id: int) -> bool:
	for u in game.units_near(pos2(), Defs.CAMP_REACH + 1.0):
		if u.pid == owner_id and u.alive and u.pos2().distance_to(pos2()) <= Defs.CAMP_REACH:
			return true
	return false


## "" if this player can hire the mercenary right now, otherwise the reason.
func hire_check(owner_id: int, k: String) -> String:
	var p: PlayerData = game.players[owner_id]
	var d: Dictionary = Defs.UNITS[k]
	if int(stock.get(k, 0)) <= 0:
		return "Sold out (restocks every %ds)" % int(Defs.CAMP_RESTOCK)
	if p.age < d["age"]:
		return "Requires " + Defs.AGE_NAMES[d["age"]]
	if p.pop + int(d["pop"]) > mini(p.pop_cap, p.max_pop):
		return "Need more houses"
	if not has_unit_near(owner_id):
		return "Bring a unit within %d of the camp" % int(Defs.CAMP_REACH)
	if not p.can_afford(d["cost"]):
		return p.missing_text(d["cost"])
	return ""


func hire(owner_id: int, k: String) -> Unit:
	if hire_check(owner_id, k) != "":
		return null
	var p: PlayerData = game.players[owner_id]
	p.pay(Defs.UNITS[k]["cost"])
	stock[k] = int(stock[k]) - 1
	var a := randf() * TAU
	var u := game.spawn_unit(k, owner_id, pos2() + Vector2.from_angle(a) * 3.2)
	if u:
		game.spawn_fx("levelup", u.position, 0.8, Color.WHITE)
		p.stats["recruited"] = p.stats.get("recruited", 0) + 1
		p.stats["hired"] = p.stats.get("hired", 0) + 1
		if owner_id == game.human:
			Sfx.play("ready", -3.0)
			game.hud.message("Hired a %s." % Defs.UNITS[k]["name"], Color(1, 0.85, 0.45))
	return u
