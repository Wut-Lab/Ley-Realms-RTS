# Ley-Realms-RTS
An RTS with RPG elements made with AI and minimal human input to see how it does.

A 3D fantasy real-time strategy game for **Godot 4.3+**. It draws on classic base-building RTS games (economy, ages, free-form building, walls) and on strategic-point RTS games (capturable Ley Shrines that fund your army and can win the game).

Every model, map, effect and UI element is generated in code. There are no external assets to install.

## Running it

1. Install [Godot 4.3 or newer](https://godotengine.org/download) (the standard build; .NET is not needed).
2. Open Godot, click **Import**, and pick `project.godot` in this folder.
3. Press **F5** (Run Project).

To make a standalone executable: **Project → Export…**, add a Windows/macOS/Linux preset (Godot will offer to download the export templates), then **Export Project**.

## Features

| | |
|---|---|
| **3D graphics** | Low-poly procedural models, dynamic shadows, glowing magic, animated water, fire on damaged buildings, arrows/fireballs/boulders/dragon fire |
| **Four resources** | Food (berry bushes, farms), Wood (trees), Gold (mines), Mana (crystals + captured Ley Shrines) |
| **Procedural maps** | Heightmap terrain with hills, mountains, lakes, forests, guaranteed land routes between players, fair start resources, Ley Shrines and monster lairs. Seeds can be reused |
| **Free building** | Place any building anywhere valid, rotate with **R**, Shift-click to place several, click-and-drag to lay walls |
| **3 ages** | Settlement → Steel → Sorcery, researched at the Town Hall |
| **12 buildings, 10 units + hero, 10 techs** | Peasant, Swordsman, Spearman, Archer, Knight, Battle Mage, Cleric, Catapult, Dragon, Warden (hero); Blacksmith and other upgrades |
| **Combat** | Melee, pierce, magic and siege damage vs armor; counters (spears vs cavalry, ranged vs flyers, siege vs buildings); splash damage; healing; towers |
| **Ley Shrines** | Capturable strategic points that produce mana. Optional *Dominion* victory: hold them all for 3 minutes |
| **Monster lairs** | Wolves and trolls guard gold and pay bounties |
| **Fog of war** | Unexplored areas, explored areas and current vision, with a live minimap |
| **Champions** | Pick a hero class (Warlord, Archmage, High Priestess). It levels 1–10 from battle XP, gains stats each level, spends skill points on 4 abilities (ultimate at level 6) and respawns at your Town Hall. AI players get champions and cast their abilities too |
| **Doctrines** | At champion levels 2, 4, 6, 8 and 10 you pick one of three army-wide passives (e.g. Drill Sergeant, Shield Wall, Command Aura, Siege Masters, Spoils of War). Some are auras around your champion |
| **Save & load** | Save to Quick Save or 3 slots from the pause menu, **Save & Quit**, **Continue** / **Load Game** on the title screen. Autosaves every 3 minutes and whenever the app is closed or sent to the background on a phone |
| **Sound** | Synthesized effects for combat, gathering, construction, magic, alerts and notifications, plus a looping fantasy soundtrack. Music and effects volume in the pause menu and on the title screen |
| **Phones & tablets** | Full touch controls, a larger touch-friendly UI, Android APK and web builds |
| **AI** | **Easy** and **Hard** opponents that build economies, age up, research, claim shrines, defend and attack in waves |

### Skirmish setup options
Map size (Small to Huge), biome (Verdant Vale, Highland Crags, Frostmarch, Ashen Wastes, Elderwood), terrain relief, water, forest density, resource abundance, monster lairs on/off, Ley Shrines on/off, map seed (with live preview), champions on/off and your champion class, 1–5 AI opponents, AI difficulty, free-for-all or allied AIs, your colour, victory condition, starting age, starting resources, population limit, peace treaty, game speed, fog of war, and a pre-explored map.

## Playing on a phone

* **Android:** install `LeyRealms.apk` from the GitHub release (allow "install unknown apps" for your browser when asked).
* **Any phone, including iPhone:** open the web version link from the repository's GitHub Pages site in the phone browser, landscape.

Touch controls switch on automatically on phones and tablets. You can force them on or off in Skirmish Setup under **Device → Controls**; **Graphics** has a Low setting for older phones.

| Touch | Action |
|---|---|
| Tap | Select a unit/building. With units selected, tap the ground, an enemy, a resource or your own construction to move/attack/gather/build. With a building selected, tap the ground to set its rally point |
| Double-tap a unit | Select all of that type on screen |
| Long-press, then drag | Box-select |
| Drag with one finger | Pan the camera |
| Pinch / two-finger twist | Zoom / rotate |
| Right-side buttons | Army, Idle peasant, Hero, Town Hall, Multi-select toggle, Clear selection |
| Building | Pick it from the command card, tap the map to position it, then **Place** / **Rotate** / **Cancel**. Walls: tap the start, tap the end, then **Place** |
| Command card | Tap to use; press and hold to read the description |
| Android back button | Cancel / pause menu |

## Controls (mouse & keyboard)

| Input | Action |
|---|---|
| Left click / drag | Select / box-select (Shift adds, double-click selects all of that type on screen) |
| Right click | Smart command: move, attack, gather, build/repair, drop off. With a building selected: set rally point |
| Q W E R T / A S D F G / Z X C V B | Command card hotkeys |
| A, S, D (military) | Attack-move, stop, hold position |
| Arrow keys / screen edge | Pan camera |
| Mouse wheel | Zoom |
| Middle-drag / PgUp / PgDn | Rotate camera (Home resets) |
| ` or F2 / top-bar button | Select champion (twice to jump to it) |
| Q W E R (champion) | Cast abilities: self abilities fire instantly, targeted ones wait for a click |
| Z X C V (champion) | Spend skill points |
| Ctrl+0–9 / 0–9 | Set / recall control group (double-tap to jump) |
| H | Select Town Hall |
| . | Cycle idle peasants |
| Space | Centre on selection |
| Delete | Destroy selected |
| + / − | Game speed |
| F1 | Controls help |
| Esc | Cancel / deselect / pause menu |

## Project layout

```
project.godot
scenes/main.tscn            root scene (menu <-> game switching)
scripts/
  game_settings.gd          skirmish options (autoload)
  defs.gd                   all unit/building/tech/resource data (autoload) - tweak balance here
  map_generator.gd          procedural world generation + preview images
  models.gd, model_builder.gd  procedural low-poly meshes and shaders
  game.gd                   match: world, pathfinding (AStarGrid2D), fog, combat, victory
  unit.gd, building.gd, entity.gd, resource_node.gd, shrine.gd, projectile.gd
  champion.gd, area_effect.gd  hero levelling, abilities, doctrines, lingering spell areas
  touch_input.gd            touch-screen controls
  ai_controller.gd          Easy/Hard computer opponents
  player_controller.gd      mouse/keyboard input, selection, placement
  rts_camera.gd             RTS camera
  hud.gd, minimap.gd, overlay.gd, ui_theme.gd, res_icon.gd, main_menu.gd
  save_game.gd, save_panel.gd  saving/loading matches and the slot picker
  sfx.gd                    sound manager (autoload)
  ui_test.gd, touch_test.gd, save_test.gd  scripted tests (developer tools)
sounds/                     generated sound effects and music
tools/gen_audio.py          regenerates sounds/ from scratch (python3 + numpy, ffmpeg for the music)
export_presets.cfg          Android (APK) and Web export presets
```

## Developer testing

The game has a headless self-play mode in which AIs control every player:

```bash
godot --headless --fixed-fps 20 -- --autotest --time=1200 --ai=3 --hard=1 --size=2
```

It prints economy and performance stats each game-minute and quits at the end. Other flags: `--biome=N`, `--age=N`, `--res=N`, `--fog`, and `--uitest`, which runs a scripted pass over the human controls.

### Building the phone versions yourself

1. In Godot, install the export templates (**Editor → Manage Export Templates**).
2. **Android:** in Editor Settings, set the Android SDK path and a keystore, then **Project → Export → Android → Export Project**. The preset builds an arm64 APK without needing Gradle.
3. **Web:** **Project → Export → Web**. It's single-threaded, so it works on any static host (e.g. GitHub Pages) without special headers.

Touch tests: `godot --headless -- --autotest --touch --touchtest`. Save/load round trip: `godot --headless --fixed-fps 20 -- --autotest --savetest`.
