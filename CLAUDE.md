# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**The Spire** is a cybersecurity-themed deckbuilding roguelike game built in **Godot 4**, inspired by Slay the Spire. Players act as SOC analysts using security tool cards to investigate, contain, and recover from cyber threats. Every card and threat references real-world incidents (SolarWinds, NotPetya, Colonial Pipeline, etc.).

## Running the Game

Open the project in **Godot 4** and run from the editor (F5), or export and run the binary. There is no CLI build command — all building is done through the Godot editor.

## Architecture

### Scene Hierarchy

`GameController.tscn` is the root scene. It holds persistent overlay layers (`SettingsUi`, `InformationBook`, `ShopUI`) and a `CurrentSceneHolder` node that swaps between:
- `main_menu.tscn` → Main menu with boot sequence and parallax background
- `stage_select.tscn` → Day/stage carousel selector
- `play_ui.tscn` → Active gameplay (loads via `SceneLoader` autoloader)
- `settings_ui.tscn`

### Autoloaders (always available globally)

| Name | Script | Purpose |
|------|--------|---------|
| `Music` | `UI_script/music.gd` | Background music with loop management |
| `GameManager` | `UI_script/GameManager.gd` | Day progression, unlocked stages, save/load (`user://save.cfg`) |
| `GlobalVars` | `Scripts/Autoloader/GlobalVars.gd` | Shared runtime references (see below) |
| `SceneLoader` | `Scripts/Autoloader/scene_loader.gd` | Threaded async scene loading |

> Note: There are two `global_vars.gd` files — the authoritative one is `Scripts/Autoloader/GlobalVars.gd`. The root-level `global_vars.gd` is legacy/minimal.

### GlobalVars — Shared State

`GlobalVars` holds runtime references registered by `GameController` on `_ready`:
```gdscript
GlobalVars.game_controller   # GameController node
GlobalVars.settings_ui       # CanvasLayer ($SettingsUi)
GlobalVars.info_book         # MarginContainer ($InformationBook)
GlobalVars.shop_ui           # CanvasLayer ($ShopUI)
GlobalVars.boot_sequence_played  # bool — skip intro after first run
```

### Scene Transitions

Menu buttons emit signals → `GameController` handles them via `change_sub_scene(scene_enum)`. This keeps scenes decoupled. Gameplay scenes load via `SceneLoader` (threaded) rather than `change_sub_scene`.

Relevant signal flow:
```
MainMenu   --open_stage_select-->  GameController.change_sub_scene(STAGE_SELECT)
StageSelect--stage_selected(i) -->  GameManager._on_stage_selected() → SceneLoader
StageSelect--back_to_main_menu -->  GameController.change_sub_scene(MAIN_MENU)
```

### Data: Cards and Threats

All card and threat data lives in CSV files:
- `CSV/cards.csv` — 33 cards: name, energy_cost, card_type, logic, tooltip, threat counters, real_world reference
- `CSV/threats.csv` — 9 threat types: alerts, clues, description, real_world, hint, counter cards

`InformationBook.gd` reads these CSVs to populate the in-game codex. `ShopUI.gd` defines the same 33 cards inline as dictionaries (redundant with the CSV — keep both in sync when adding cards).

### Card System

Cards have 7 types: Investigation, Monitoring, Hardening, Response, Recovery, Automation, Rare.

Shop mechanics: 6 random cards per visit; price = `energy_cost × 30` (Rare: `× 50`); player starts with 500 coins.

### Game Progression

`GameManager` tracks 6 days (3 unlocked by default). `complete_day(day_index)` unlocks the next and saves to `user://save.cfg`. Stage descriptions and scene paths are defined in `GameManager.gd`.

## Key Files Quick Reference

| File | Role |
|------|------|
| `GameController.gd` | Root hub; sub-scene swapping; registers GlobalVars refs |
| `Scripts/Autoloader/GlobalVars.gd` | Shared runtime state |
| `UI_script/GameManager.gd` | Day/stage progression and save state |
| `UI_script/StageSelect.gd` | Carousel UI; emits `stage_selected(day_index)` |
| `ShopUI.gd` | Card shop; all 33 cards defined inline |
| `UI_script/InformationBook.gd` | Codex; reads from CSV files |
| `UI_script/story_intro.gd` | Pre-battle dialogue system |
| `UI_script/BootSequence.gd` | One-time typewriter CLI intro |
| `UI_script/MatrixRain.gd` | Falling katakana/character effect (supports clip regions) |

## Conventions

- Signals are the primary communication mechanism between scenes — avoid direct node references across scene boundaries; use `GlobalVars` for anything that needs to persist across scene changes.
- The `CurrentSceneHolder` pattern in `GameController` is the intended way to swap top-level scenes.
- When adding new cards, update **both** `CSV/cards.csv` and the card array in `ShopUI.gd`.
