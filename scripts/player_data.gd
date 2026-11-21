class_name PlayerData
extends RefCounted
## Per-player economy, tech and status.

var id := 0
var name := ""
var color := Color.WHITE
var team := 0
var human := false
var ai_hard := false
var res := {"food": 0.0, "wood": 0.0, "gold": 0.0, "mana": 0.0}
var age := 1
var techs := {}
var researching := {}
var pop := 0
var pop_cap := 0
var max_pop := 200
var defeated := false
var gather_mult := 1.0
var mods := {
	"melee_atk": 0.0, "pierce_atk": 0.0, "range": 0.0, "armor": 0.0, "parmor": 0.0, "magic": 1.0,
	"food": 1.0, "wood": 1.0, "gold": 1.0, "mana": 1.0, "bhp": 1.0, "knight_hp": 0.0,
}
var champ_class := ""
var champ_level := 1
var champ_xp := 0.0
var champ_points := 1
var champ_ranks := [0, 0, 0, 0]
var champ: Unit = null
var champ_respawn := -1.0
var stats := {"trained": 0, "killed": 0, "lost": 0, "gathered": 0.0, "built": 0, "razed": 0}


func can_afford(cost: Dictionary) -> bool:
	for r in cost:
		if res.get(r, 0.0) < cost[r]:
			return false
	return true


func pay(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for r in cost:
		res[r] -= cost[r]
	return true


func refund(cost: Dictionary, frac: float = 1.0) -> void:
	for r in cost:
		res[r] += cost[r] * frac


func missing_text(cost: Dictionary) -> String:
	var parts: Array = []
	for r in cost:
		var need: float = cost[r] - res.get(r, 0.0)
		if need > 0:
			parts.append("%d %s" % [ceil(need), Defs.RES_NAMES[r]])
	return "Need " + ", ".join(parts)
