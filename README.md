# DarkBrawl 🗡️

> Dark fantasy 2D arena brawler. Smash-style ring-outs. Pre-match loadout building. Easy to play, hard to master.

## Setup

1. Install [Godot 4](https://godotengine.org/) (already installed via winget on Omar's PC)
2. Open Godot → **Import** → navigate to this folder → select `project.godot`
3. Hit **Play** (F5)

## Controls (default)

| Action | Player 1 | Player 2 |
|--------|----------|----------|
| Move   | A / D    | ← / →    |
| Jump   | W        | ↑        |
| Dodge  | S        | ↓        |
| Attack | F        | Numpad 1 |
| Emote  | G        | Numpad 2 |

## Project Structure

```
darkbrawl/
├── project.godot         # Godot project file
├── scenes/
│   └── main_menu.tscn    # Main menu (host/join)
├── scripts/
│   ├── player.gd         # Player controller (movement, stamina, combat, knockback)
│   ├── game_manager.gd   # Game state, multiplayer peer setup, lives tracking
│   ├── lobby.gd          # Host/join networking
│   ├── hud.gd            # HUD updater (damage %, lives, stamina bar)
│   ├── map_base.gd       # Base class for all maps
│   ├── moving_platform.gd# Sinusoidal moving platform
│   └── input_map.gd      # Input action registration
├── maps/
│   └── map_01_ashfall.tscn  # First map: Ashfall Arena (solid + moving platforms)
└── assets/
    ├── sprites/
    ├── sounds/
    └── fonts/
```

## Current Status

**Phase 2 — Prototype**

- [x] Project scaffolded
- [x] Player controller (move, jump, dodge, attack, stamina, knockback)
- [x] Smash-style knockback formula (scales with damage %)
- [x] VIT stat reduces launch distance
- [x] Online multiplayer foundation (ENet host/join)
- [x] Map 01: Ashfall Arena (solid + moving platforms)
- [x] HUD system (damage %, lives, stamina bar)
- [ ] Player sprites (placeholder boxes for now)
- [ ] Loadout/archetype select screen
- [ ] Stat point allocation UI
- [ ] Weapon system
- [ ] All 8 archetypes implemented
- [ ] Emote system + voice lines

## Archetypes (planned)

| # | Name | Stats | Tagline |
|---|------|-------|---------|
| 1 | ⚔️ Warrior | STR/VIT | "The immovable wall." |
| 2 | 🗡️ Rogue | DEX | "Blink and you miss it." |
| 3 | 🔮 Sorcerer | INT | "Keep your distance or die." |
| 4 | 🩸 Berserker | STR | "The harder you hit him, the angrier he gets." |
| 5 | ✝️ Paladin | STR/INT | "The judge, jury, and executioner." |
| 6 | 👁️ Phantom | DEX/INT | "You're fighting a ghost." |
| 7 | 🌑 Hexblade | DEX/INT | "Every hit leaves a mark." |
| 8 | ⚖️ Warden | Balanced | "No crutch. Just skill." |
