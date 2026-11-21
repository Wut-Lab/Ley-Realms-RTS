extends Node
## Autoload with all game data: units, buildings, technologies, resources.

const RES := ["food", "wood", "gold", "mana"]
const RES_NAMES := {"food": "Food", "wood": "Wood", "gold": "Gold", "mana": "Mana"}
const RES_COLORS := {
	"food": Color(0.92, 0.36, 0.32), "wood": Color(0.65, 0.45, 0.25),
	"gold": Color(1.0, 0.84, 0.25), "mana": Color(0.55, 0.45, 1.0),
}
const AGE_NAMES := ["", "Age of Settlement", "Age of Steel", "Age of Sorcery"]
const AGE_SHORT := ["", "I", "II", "III"]

const PLAYER_COLORS := [
	Color(0.55, 0.5, 0.45), Color(0.2, 0.45, 0.95), Color(0.9, 0.18, 0.18),
	Color(0.2, 0.75, 0.3), Color(0.95, 0.8, 0.15), Color(0.65, 0.3, 0.85), Color(0.95, 0.5, 0.12),
]
const COLOR_NAMES := ["Gaia", "Blue", "Red", "Green", "Yellow", "Purple", "Orange"]
const AI_NAMES := ["Lord Varric", "Queen Ysolde", "Archmage Thorne", "Warlord Grisk", "Lady Maelis", "King Aldren"]

const CARRY_CAP := 10.0
const GATHER_RATE := {"tree": 0.85, "berry": 0.9, "farm": 0.7, "gold_mine": 0.7, "mana_crystal": 0.55}
const RESOURCE_AMOUNT := {"tree": 100, "berry": 150, "gold_mine": 800, "mana_crystal": 450}
const RESOURCE_TYPE := {"tree": "wood", "berry": "food", "gold_mine": "gold", "mana_crystal": "mana"}
const RESOURCE_CELLS := {"tree": 0, "berry": 0, "gold_mine": 1, "mana_crystal": 0}
const RESOURCE_RADIUS := {"tree": 0.45, "berry": 0.5, "gold_mine": 1.5, "mana_crystal": 0.55}
const RESOURCE_NAMES := {"tree": "Tree", "berry": "Berry Bush", "gold_mine": "Gold Mine", "mana_crystal": "Mana Crystal"}

# atk_type: melee (vs armor), pierce (vs pierce armor), magic (mostly ignores armor), siege
const UNITS := {
	"peasant": {
		"name": "Peasant", "desc": "Gathers resources and constructs buildings.",
		"hp": 40, "atk": 3, "atk_type": "melee", "range": 0.5, "cooldown": 1.5, "speed": 3.8,
		"armor": 0, "parmor": 1, "sight": 8, "cost": {"food": 50}, "time": 10, "pop": 1, "age": 1,
		"cls": "worker", "radius": 0.35, "model": "peasant", "height": 1.5,
	},
	"swordsman": {
		"name": "Swordsman", "desc": "Sturdy melee infantry. Good all-rounder.",
		"hp": 95, "atk": 9, "atk_type": "melee", "range": 0.6, "cooldown": 1.3, "speed": 3.4,
		"armor": 2, "parmor": 1, "sight": 8, "cost": {"food": 60, "gold": 20}, "time": 16, "pop": 1, "age": 1,
		"cls": "infantry", "radius": 0.38, "model": "swordsman", "height": 1.6,
	},
	"spearman": {
		"name": "Spearman", "desc": "Cheap pike infantry. Big bonus vs cavalry and can strike flying beasts.",
		"hp": 75, "atk": 5, "atk_type": "melee", "range": 0.9, "cooldown": 1.4, "speed": 3.6,
		"armor": 1, "parmor": 1, "sight": 8, "cost": {"food": 35, "wood": 25}, "time": 12, "pop": 1, "age": 1,
		"cls": "infantry", "radius": 0.36, "model": "spearman", "height": 1.6,
		"bonus": {"cavalry": 14, "flying": 8}, "anti_air": true,
	},
	"archer": {
		"name": "Archer", "desc": "Ranged infantry. Can shoot flying units.",
		"hp": 45, "atk": 5, "atk_type": "pierce", "range": 7.0, "cooldown": 1.6, "speed": 3.6,
		"armor": 0, "parmor": 0, "sight": 9, "cost": {"wood": 30, "gold": 35}, "time": 15, "pop": 1, "age": 1,
		"cls": "ranged", "radius": 0.35, "model": "archer", "height": 1.55, "projectile": "arrow",
		"bonus": {"flying": 3},
	},
	"warden": {
		"name": "Warden (Hero)", "desc": "Unique hero. Powerful, regenerates health. Only one at a time.",
		"hp": 420, "atk": 18, "atk_type": "melee", "range": 0.8, "cooldown": 1.2, "speed": 4.2,
		"armor": 4, "parmor": 4, "sight": 11, "cost": {"food": 200, "gold": 150}, "time": 40, "pop": 2, "age": 2,
		"cls": "infantry", "radius": 0.45, "model": "warden", "height": 1.9, "regen": 2.5, "limit": 1,
		"anti_air": true,
	},
	"knight": {
		"name": "Knight", "desc": "Fast, heavily armored cavalry.",
		"hp": 170, "atk": 12, "atk_type": "melee", "range": 0.7, "cooldown": 1.6, "speed": 6.0,
		"armor": 2, "parmor": 2, "sight": 9, "cost": {"food": 70, "gold": 75}, "time": 24, "pop": 2, "age": 2,
		"cls": "cavalry", "radius": 0.6, "model": "knight", "height": 2.2,
	},
	"mage": {
		"name": "Battle Mage", "desc": "Hurls fireballs that damage everything in a small area.",
		"hp": 50, "atk": 13, "atk_type": "magic", "range": 8.0, "cooldown": 2.4, "speed": 3.3,
		"armor": 0, "parmor": 0, "sight": 10, "cost": {"gold": 50, "mana": 60}, "time": 22, "pop": 1, "age": 2,
		"cls": "ranged", "radius": 0.35, "model": "mage", "height": 1.8, "projectile": "fireball", "splash": 1.6,
	},
	"cleric": {
		"name": "Cleric", "desc": "Heals nearby wounded allies.",
		"hp": 50, "atk": 0, "heal": 8, "atk_type": "magic", "range": 6.0, "cooldown": 1.5, "speed": 3.4,
		"armor": 0, "parmor": 1, "sight": 9, "cost": {"food": 40, "gold": 40, "mana": 30}, "time": 20, "pop": 1, "age": 2,
		"cls": "support", "radius": 0.35, "model": "cleric", "height": 1.7,
	},
	"catapult": {
		"name": "Catapult", "desc": "Long-range siege engine. Devastating vs buildings. Cannot hit flyers.",
		"hp": 140, "atk": 40, "atk_type": "siege", "range": 11.0, "cooldown": 4.5, "speed": 2.2,
		"armor": 1, "parmor": 6, "sight": 11, "cost": {"wood": 160, "gold": 100}, "time": 35, "pop": 2, "age": 3,
		"cls": "siege", "radius": 0.8, "model": "catapult", "height": 2.2, "scale": 1.2, "projectile": "boulder", "splash": 1.8,
		"bonus": {"building": 90}, "no_air": true,
	},
	"dragon": {
		"name": "Dragon", "desc": "A flying terror that breathes fire. Only ranged units and spears can hit it.",
		"hp": 520, "atk": 20, "atk_type": "magic", "range": 5.0, "cooldown": 1.8, "speed": 5.0,
		"armor": 2, "parmor": 3, "sight": 12, "cost": {"gold": 220, "mana": 260}, "time": 45, "pop": 4, "age": 3,
		"cls": "flying", "radius": 1.1, "model": "dragon", "height": 2.0, "scale": 1.05, "projectile": "flame", "splash": 2.0,
		"flying": true, "bonus": {"building": 10},
	},
	"wolf": {
		"name": "Dire Wolf", "desc": "A wild beast guarding its lair.",
		"hp": 60, "atk": 6, "atk_type": "melee", "range": 0.5, "cooldown": 1.1, "speed": 5.0,
		"armor": 0, "parmor": 1, "sight": 7, "cost": {}, "time": 1, "pop": 0, "age": 1,
		"cls": "monster", "radius": 0.45, "model": "wolf", "height": 1.0, "bounty": {"food": 40},
	},
	"troll": {
		"name": "Cave Troll", "desc": "A huge brute guarding treasure.",
		"hp": 380, "atk": 18, "atk_type": "melee", "range": 0.8, "cooldown": 2.0, "speed": 3.0,
		"armor": 2, "parmor": 2, "sight": 7, "cost": {}, "time": 1, "pop": 0, "age": 1,
		"cls": "monster", "radius": 0.8, "model": "troll", "height": 2.6, "bounty": {"gold": 100}, "regen": 1.0,
	},
	"champ_warlord": {
		"name": "Warlord", "desc": "Your champion. A front-line fighter who leads from the front.",
		"hp": 560, "atk": 20, "atk_type": "melee", "range": 0.8, "cooldown": 1.2, "speed": 4.4,
		"armor": 4, "parmor": 4, "sight": 12, "cost": {}, "time": 1, "pop": 0, "age": 1,
		"cls": "hero", "radius": 0.5, "model": "champ_warlord", "height": 1.9, "regen": 1.5, "scale": 1.45,
		"anti_air": true, "champion": true,
	},
	"champ_archmage": {
		"name": "Archmage", "desc": "Your champion. A master of destructive sorcery.",
		"hp": 400, "atk": 15, "atk_type": "magic", "range": 7.5, "cooldown": 1.8, "speed": 4.0,
		"armor": 1, "parmor": 2, "sight": 13, "cost": {}, "time": 1, "pop": 0, "age": 1,
		"cls": "hero", "radius": 0.45, "model": "champ_archmage", "height": 2.0, "regen": 1.5, "scale": 1.45,
		"projectile": "fireball", "splash": 1.0, "champion": true,
	},
	"champ_priestess": {
		"name": "High Priestess", "desc": "Your champion. Shields and restores your armies, smites the wicked.",
		"hp": 460, "atk": 12, "atk_type": "magic", "range": 6.5, "cooldown": 1.5, "speed": 4.1,
		"armor": 2, "parmor": 3, "sight": 12, "cost": {}, "time": 1, "pop": 0, "age": 1,
		"cls": "hero", "radius": 0.45, "model": "champ_priestess", "height": 2.0, "regen": 2.5, "scale": 1.45,
		"projectile": "holy", "champion": true,
	},
}

const BUILDINGS := {
	"town_hall": {
		"name": "Town Hall", "desc": "Trains peasants, accepts all resources, researches ages. Shoots arrows.",
		"hp": 2400, "size": 5.0, "cost": {"wood": 275, "gold": 150}, "time": 80, "age": 1, "pop": 10,
		"dropoff": true, "trains": ["peasant", "warden"], "research": ["harvest_tools", "deep_mining", "age2", "age3"],
		"atk": 5, "range": 8.0, "cooldown": 2.0, "sight": 12, "armor": 4, "parmor": 10, "height": 6.0, "garrison": 12,
	},
	"house": {
		"name": "House", "desc": "Provides +5 population.",
		"hp": 450, "size": 2.5, "cost": {"wood": 30}, "time": 14, "age": 1, "pop": 5,
		"sight": 5, "armor": 1, "parmor": 6, "height": 3.0,
	},
	"farm": {
		"name": "Farm", "desc": "An endless source of food, worked by one peasant.",
		"hp": 300, "size": 3.6, "cost": {"wood": 60}, "time": 10, "age": 1, "walkable": true,
		"sight": 3, "armor": 0, "parmor": 0, "height": 0.6,
	},
	"storehouse": {
		"name": "Storehouse", "desc": "Drop-off point for all resources.",
		"hp": 800, "size": 3.0, "cost": {"wood": 90}, "time": 22, "age": 1, "dropoff": true,
		"sight": 6, "armor": 1, "parmor": 7, "height": 3.0,
	},
	"barracks": {
		"name": "Barracks", "desc": "Trains swordsmen, spearmen and archers.",
		"hp": 1300, "size": 4.2, "cost": {"wood": 160}, "time": 35, "age": 1,
		"trains": ["swordsman", "spearman", "archer"],
		"research": ["up_longsword", "up_blademaster", "up_pike", "up_halberd", "up_crossbow", "up_arbalest"], "sight": 6, "armor": 2, "parmor": 8, "height": 4.0,
	},
	"blacksmith": {
		"name": "Blacksmith", "desc": "Researches weapon and armor upgrades.",
		"hp": 1000, "size": 3.6, "cost": {"wood": 130, "gold": 30}, "time": 30, "age": 1,
		"research": ["forged_blades", "fletching", "plate_armor", "masonry"], "sight": 6, "armor": 2, "parmor": 8, "height": 4.0,
	},
	"tower": {
		"name": "Watch Tower", "desc": "Defensive tower that shoots arrows at enemies, including flyers.",
		"hp": 900, "size": 2.0, "cost": {"wood": 60, "gold": 80}, "time": 30, "age": 1,
		"atk": 7, "range": 9.0, "cooldown": 1.6, "sight": 11, "armor": 3, "parmor": 9, "height": 7.0, "garrison": 5,
	},
	"wall": {
		"name": "Stone Wall", "desc": "Cheap barrier. Click and drag to build a line of wall.",
		"hp": 700, "size": 1.0, "cost": {"wood": 6, "gold": 2}, "time": 4, "age": 1,
		"sight": 2, "armor": 6, "parmor": 12, "height": 2.4,
	},
	"gate": {
		"name": "Gate", "desc": "Opens for your units, blocks enemies. Build in a wall gap, or convert a wall section.",
		"hp": 900, "size": 1.0, "cost": {"wood": 20, "gold": 10}, "time": 10, "age": 1, "gate": true,
		"sight": 3, "armor": 6, "parmor": 12, "height": 2.6,
	},
	"stable": {
		"name": "Stable", "desc": "Trains knights.",
		"hp": 1300, "size": 4.2, "cost": {"wood": 175, "gold": 40}, "time": 35, "age": 2,
		"trains": ["knight"], "research": ["barding", "up_paladin"], "sight": 6, "armor": 2, "parmor": 8, "height": 4.0,
	},
	"mage_tower": {
		"name": "Mage Tower", "desc": "Trains battle mages and clerics.",
		"hp": 1100, "size": 3.4, "cost": {"wood": 120, "gold": 100, "mana": 40}, "time": 40, "age": 2,
		"trains": ["mage", "cleric"], "research": ["arcane_focus", "up_sorcerer", "up_hierophant"], "sight": 9, "armor": 2, "parmor": 8, "height": 8.0,
	},
	"workshop": {
		"name": "Siege Workshop", "desc": "Builds catapults.",
		"hp": 1300, "size": 4.4, "cost": {"wood": 200, "gold": 100}, "time": 40, "age": 3,
		"trains": ["catapult"], "sight": 6, "armor": 2, "parmor": 8, "height": 4.0,
	},
	"dragon_roost": {
		"name": "Dragon Roost", "desc": "Hatches dragons.",
		"hp": 1800, "size": 5.0, "cost": {"wood": 200, "gold": 200, "mana": 150}, "time": 60, "age": 3,
		"trains": ["dragon"], "research": ["up_elder_dragon"], "sight": 8, "armor": 3, "parmor": 9, "height": 5.0,
	},
}

const BUILD_MENU := ["house", "farm", "storehouse", "barracks", "blacksmith", "tower", "wall",
	"town_hall", "stable", "mage_tower", "workshop", "dragon_roost", "gate"]

const TECHS := {
	"age2": {"name": "Advance: Age of Steel", "desc": "Unlocks stables, mage towers, knights, mages, clerics and the hero.",
		"cost": {"food": 400, "gold": 150}, "time": 50, "age": 1, "max_age": 1},
	"age3": {"name": "Advance: Age of Sorcery", "desc": "Unlocks siege workshops, dragon roosts, catapults and dragons.",
		"cost": {"food": 700, "gold": 350, "mana": 200}, "time": 70, "age": 2, "max_age": 2},
	"harvest_tools": {"name": "Harvest Tools", "desc": "+20% food and wood gather rate.",
		"cost": {"food": 100, "wood": 75}, "time": 25, "age": 1},
	"deep_mining": {"name": "Deep Mining", "desc": "+20% gold and mana gather rate.",
		"cost": {"food": 100, "wood": 125}, "time": 25, "age": 1},
	"forged_blades": {"name": "Forged Blades", "desc": "+2 melee attack for all units.",
		"cost": {"food": 120, "gold": 80}, "time": 30, "age": 1},
	"fletching": {"name": "Fletching", "desc": "+1 pierce attack and +1 range for archers, towers and town halls.",
		"cost": {"food": 100, "wood": 60}, "time": 30, "age": 1},
	"plate_armor": {"name": "Plate Armor", "desc": "+2 armor and +1 pierce armor for all units.",
		"cost": {"food": 200, "gold": 150}, "time": 40, "age": 2},
	"masonry": {"name": "Masonry", "desc": "+30% hit points for buildings.",
		"cost": {"wood": 150, "gold": 100}, "time": 35, "age": 2},
	"arcane_focus": {"name": "Arcane Focus", "desc": "+25% magic damage and healing.",
		"cost": {"gold": 120, "mana": 150}, "time": 40, "age": 2},
	"barding": {"name": "Horse Barding", "desc": "+40 hit points for knights.",
		"cost": {"food": 150, "gold": 100}, "time": 35, "age": 2},
	# ---- unit upgrade lines: upgrade every existing and future unit of the line
	"up_longsword": {"name": "Longswordsman", "desc": "Upgrade Swordsmen to Longswordsmen: 115 HP, 11 attack, 3 armor.",
		"cost": {"food": 200, "gold": 65}, "time": 40, "age": 2, "line": "swordsman", "tier": 1,
		"stats": {"name": "Longswordsman", "hp": 115, "atk": 11, "armor": 3}},
	"up_blademaster": {"name": "Blademaster", "desc": "Upgrade Longswordsmen to Blademasters: 145 HP, 14 attack, 4/2 armor.",
		"cost": {"food": 300, "gold": 120}, "time": 55, "age": 3, "line": "swordsman", "tier": 2, "requires": "up_longsword",
		"stats": {"name": "Blademaster", "hp": 145, "atk": 14, "armor": 4, "parmor": 2}},
	"up_pike": {"name": "Pikeman", "desc": "Upgrade Spearmen to Pikemen: 90 HP, +18 vs cavalry, +10 vs flyers.",
		"cost": {"food": 160, "gold": 90}, "time": 40, "age": 2, "line": "spearman", "tier": 1,
		"stats": {"name": "Pikeman", "hp": 90, "atk": 6, "bonus": {"cavalry": 18, "flying": 10}}},
	"up_halberd": {"name": "Halberdier", "desc": "Upgrade Pikemen to Halberdiers: 110 HP, 2 armor, +24 vs cavalry, +14 vs flyers.",
		"cost": {"food": 250, "gold": 150}, "time": 55, "age": 3, "line": "spearman", "tier": 2, "requires": "up_pike",
		"stats": {"name": "Halberdier", "hp": 110, "atk": 7, "armor": 2, "bonus": {"cavalry": 24, "flying": 14}}},
	"up_crossbow": {"name": "Crossbowman", "desc": "Upgrade Archers to Crossbowmen: 50 HP, 6 attack, 7.5 range.",
		"cost": {"food": 125, "gold": 75}, "time": 35, "age": 2, "line": "archer", "tier": 1,
		"stats": {"name": "Crossbowman", "hp": 50, "atk": 6, "range": 7.5}},
	"up_arbalest": {"name": "Arbalest", "desc": "Upgrade Crossbowmen to Arbalests: 60 HP, 7 attack, 8 range, 1 pierce armor.",
		"cost": {"food": 300, "gold": 200}, "time": 50, "age": 3, "line": "archer", "tier": 2, "requires": "up_crossbow",
		"stats": {"name": "Arbalest", "hp": 60, "atk": 7, "range": 8.0, "parmor": 1}},
	"up_paladin": {"name": "Paladin", "desc": "Upgrade Knights to Paladins: 230 HP, 15 attack, 3/3 armor.",
		"cost": {"food": 400, "gold": 250}, "time": 60, "age": 3, "line": "knight", "tier": 1,
		"stats": {"name": "Paladin", "hp": 230, "atk": 15, "armor": 3, "parmor": 3}},
	"up_sorcerer": {"name": "Sorcerer", "desc": "Upgrade Battle Mages to Sorcerers: 60 HP, 18 attack, larger blasts, 8.5 range.",
		"cost": {"gold": 150, "mana": 200}, "time": 50, "age": 3, "line": "mage", "tier": 1,
		"stats": {"name": "Sorcerer", "hp": 60, "atk": 18, "splash": 2.0, "range": 8.5}},
	"up_hierophant": {"name": "Hierophant", "desc": "Upgrade Clerics to Hierophants: 65 HP, heals 13, 7 range.",
		"cost": {"gold": 150, "mana": 150}, "time": 45, "age": 3, "line": "cleric", "tier": 1,
		"stats": {"name": "Hierophant", "hp": 65, "heal": 13, "range": 7.0}},
	"up_elder_dragon": {"name": "Elder Dragon", "desc": "Upgrade Dragons to Elder Dragons: 650 HP, 26 attack, 3/4 armor.",
		"cost": {"gold": 400, "mana": 400}, "time": 70, "age": 3, "line": "dragon", "tier": 1,
		"stats": {"name": "Elder Dragon", "hp": 650, "atk": 26, "armor": 3, "parmor": 4}},
}


static func cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	for r in RES:
		if cost.has(r) and cost[r] > 0:
			parts.append("%d %s" % [cost[r], RES_NAMES[r]])
	return ", ".join(parts) if parts.size() > 0 else "Free"


# ---------------------------------------------------------------- champions
const CHAMPION_ORDER := ["warlord", "archmage", "priestess"]
const XP_TABLE := [0, 0, 100, 250, 450, 700, 1000, 1350, 1750, 2200, 2700]
const MAX_LEVEL := 10

# target: "self" (centred on the champion) or "point" (click a location)
# kind: used by the AI to decide when to cast: "damage", "buff", "heal"
const CHAMPIONS := {
	"warlord": {"name": "Warlord", "unit": "champ_warlord",
		"blurb": "Melee bruiser. Buffs nearby troops, leaps into the fray and shrugs off damage.",
		"abilities": [
			{"id": "rally", "short": "Rally", "name": "Rallying Cry", "target": "self", "radius": 9.0, "cd": 40.0, "kind": "buff",
				"vals": [0.3, 0.45, 0.6], "desc": "Allies within 9 gain +%d%% attack and +20%% speed for 10s."},
			{"id": "leap", "short": "Leap", "name": "Cleaving Leap", "target": "point", "range": 10.0, "radius": 3.0, "cd": 18.0, "kind": "damage",
				"vals": [45, 75, 110], "desc": "Leap to a point, dealing %d damage nearby and stunning enemies."},
			{"id": "ironskin", "short": "Iron Skin", "name": "Iron Skin", "target": "self", "radius": 0.0, "cd": 30.0, "kind": "buff",
				"vals": [0.5, 0.6, 0.7], "desc": "Take %d%% less damage for 7s."},
			{"id": "banner", "short": "Banner", "name": "Banner of Kings", "target": "point", "range": 8.0, "radius": 8.0, "cd": 90.0, "kind": "heal", "ult": true,
				"vals": [8, 14], "desc": "ULTIMATE. Plant a banner: allies nearby regenerate %d HP/s and gain +3 armor for 20s."},
		]},
	"archmage": {"name": "Archmage", "unit": "champ_archmage",
		"blurb": "Ranged caster. Devastating area damage, slows and magical shields.",
		"abilities": [
			{"id": "meteor", "short": "Meteor", "name": "Meteor", "target": "point", "range": 12.0, "radius": 3.0, "cd": 20.0, "kind": "damage",
				"vals": [80, 130, 180], "desc": "Call down a meteor dealing %d damage in an area (double vs buildings)."},
			{"id": "nova", "short": "Nova", "name": "Frost Nova", "target": "self", "radius": 6.0, "cd": 16.0, "kind": "damage",
				"vals": [30, 50, 75], "desc": "Deal %d damage to nearby enemies and slow them by 50%% for 4s."},
			{"id": "ward", "short": "Ward", "name": "Arcane Ward", "target": "self", "radius": 8.0, "cd": 35.0, "kind": "buff",
				"vals": [40, 70, 100], "desc": "Allies within 8 gain a shield absorbing %d damage for 12s."},
			{"id": "storm", "short": "Storm", "name": "Arcane Storm", "target": "point", "range": 12.0, "radius": 6.0, "cd": 100.0, "kind": "damage", "ult": true,
				"vals": [30, 50], "desc": "ULTIMATE. A storm that deals %d damage per second to enemies in an area for 6s."},
		]},
	"priestess": {"name": "High Priestess", "unit": "champ_priestess",
		"blurb": "Support. Heals armies, makes them briefly invulnerable and smites foes.",
		"abilities": [
			{"id": "mend", "short": "Mend", "name": "Mending Light", "target": "self", "radius": 9.0, "cd": 14.0, "kind": "heal",
				"vals": [60, 100, 140], "desc": "Heal allies within 9 for %d HP."},
			{"id": "smite", "short": "Smite", "name": "Smite", "target": "point", "range": 11.0, "radius": 2.5, "cd": 10.0, "kind": "damage",
				"vals": [60, 90, 125], "desc": "A pillar of light deals %d damage (double vs monsters and champions)."},
			{"id": "aegis", "short": "Aegis", "name": "Divine Aegis", "target": "self", "radius": 7.0, "cd": 50.0, "kind": "buff",
				"vals": [2, 3, 4], "desc": "Allies within 7 become invulnerable for %d seconds."},
			{"id": "holy_nova", "short": "Holy Nova", "name": "Holy Nova", "target": "self", "radius": 10.0, "cd": 90.0, "kind": "heal", "ult": true,
				"vals": [120, 200], "desc": "ULTIMATE. Heal allies within 10 for %d and deal the same damage to enemies."},
		]},
}


static func ability_desc(a: Dictionary, rank: int) -> String:
	var r := clampi(rank, 1, a["vals"].size())
	var v = a["vals"][r - 1]
	if v is float and v < 1.0:
		v = int(round(v * 100))
	return a["desc"] % v


## Level needed to learn the given rank of an ability.
static func rank_level(a: Dictionary, rank: int) -> int:
	if a.get("ult", false):
		return 6 if rank <= 1 else 9
	return rank * 2 - 1


# ---------------------------------------------------------------- champion doctrines (army passives)
# At each listed champion level the player picks one of three doctrines.
# "aura": only affects units within the radius of a living champion; otherwise army-wide and permanent.
const PASSIVE_TIERS := [
	{"level": 2, "options": ["drill", "eagle_eye", "quartermaster"]},
	{"level": 4, "options": ["shield_wall", "swift_march", "field_medic"]},
	{"level": 6, "options": ["command_aura", "battle_hymn", "siege_masters"]},
	{"level": 8, "options": ["veterans", "arcane_attunement", "cavalry_doctrine"]},
	{"level": 10, "options": ["legendary", "unbreakable", "spoils"]},
]

const PASSIVES := {
	"drill": {"name": "Drill Sergeant", "desc": "Infantry deal +15% damage."},
	"eagle_eye": {"name": "Eagle Eye", "desc": "Ranged units and towers get +1 range; ranged units deal +10% damage."},
	"quartermaster": {"name": "Quartermaster", "desc": "Peasants gather all resources 12% faster."},
	"shield_wall": {"name": "Shield Wall", "desc": "All units gain +1 armor and +1 pierce armor."},
	"swift_march": {"name": "Swift March", "desc": "All units move 12% faster."},
	"field_medic": {"name": "Field Medic", "desc": "All units regenerate 0.6 HP per second."},
	"command_aura": {"name": "Command Aura", "desc": "Aura: allies within 10 of your champion deal +20% damage.", "aura": 10.0},
	"battle_hymn": {"name": "Battle Hymn", "desc": "Aura: allies within 10 of your champion regenerate 3 HP per second.", "aura": 10.0},
	"siege_masters": {"name": "Siege Masters", "desc": "All units deal +35% damage to buildings."},
	"veterans": {"name": "Veteran Recruits", "desc": "All units have +15% maximum hit points."},
	"arcane_attunement": {"name": "Arcane Attunement", "desc": "+25% magic damage and healing, +20% mana gathering."},
	"cavalry_doctrine": {"name": "Cavalry Doctrine", "desc": "Knights and dragons deal +20% damage and move 10% faster."},
	"legendary": {"name": "Legendary Leader", "desc": "All units deal +10% damage and have +10% maximum hit points."},
	"unbreakable": {"name": "Unbreakable", "desc": "Aura: allies within 12 of your champion take 25% less damage.", "aura": 12.0},
	"spoils": {"name": "Spoils of War", "desc": "Every enemy your army kills yields 6 gold and 3 mana."},
}
