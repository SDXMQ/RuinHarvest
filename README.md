<div align="center">

# RuinHarvest

**Hardcore Singleplayer 2D Top-Down Extraction Shooter**

[![Godot Engine](https://img.shields.io/badge/Godot-4.7-478CBF?logo=godot-engine&logoColor=white)](https://godotengine.org/)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

**English** | [한국어 (Korean)](README_ko.md)

</div>

> [!NOTE]
> **AI-Authored Codebase:** The code in this repository was written with AI.

---

## Overview

**RuinHarvest** is a singleplayer 2D top-down tactical extraction shooter built with **Godot 4.7**. Deploy from your hideout into procedurally generated ruin zones, scavenge gear and supplies across enterable multi-room buildings, fight infected and armed factions, complete field objectives, and reach an extraction point before the raid timer expires.

Surviving a raid lets you bring everything in your backpack back to your hideout. Dying (**KIA**) or running out of time (**MIA**) costs your carried items—except what fits inside your **2x2 Secure Pouch** and any **insured equipment**.

---

## Key Features

### Hideout, Economy & Progression
- **2D Grid Inventory & Secure Pouch (`InventoryGrid`):** Tarkov-style `WxH` grid inventory with item rotation (`R`), stack splitting, auto-sorting, quick-move/equip (`Ctrl+Click` / `Right-Click`), and a top-left **2x2 Secure Pouch** in the backpack that protects keys, keycards, ammo, and non-weapon/non-armor items on death.
- **Equipment & Insurance:** Dedicated slots for Helmet, Armor Vest, Backpack (dynamically expands raid bag grid size), Footwear, Primary 1, Primary 2, Sidearm, and Throwable. Equipment can be insured for `1,500 RUB` prior to a raid.
- **3 Traders (`ItemDatabase`):**
  - **Prapor:** Firearms, receivers, ammo, armor, and attachments
  - **Therapist:** Medical supplies, food, and water
  - **Fence:** Crafting materials, tools, Long-Range Radio, Armory Keys, and Security Keycards
- **Dynamic Flea Market (`FleaMarket`):** Daily fluctuating market prices, player-listed sales (5% fee), and **Daily 2.5x Urgent Bounties** for high-value deliveries.
- **Hideout Facilities & Trader Quests (`HideoutProgression`):**
  - **4 Upgradeable Facilities (Lv. 1–3):** Stash Expansion (up to `10x24`), Med Station (bonus Max HP), Generator & Mining Rack (passive RUB income per survived raid), and Intel Center (trader purchase discounts & higher sell ratios).
  - **7 Trader Quests & Service Record:** Item delivery, kill contracts, field terminal hacking missions, and per-weapon mastery tracking.

### Modular Weapon Smithing & Shooting Range
- **7 Weapon Receiver Platforms (`WeaponPartsDatabase`):** `M9`, `MP5A5`, `AK-47`, `M4A1`, `Remington 870`, `Winchester Lever-Action`, and `SV-98`.
- **7 Attachment Slot Types:** Barrel, Muzzle, Stock, Grip, Magazine, Optic, and Tactical Rail.
- **6 Ammunition Types:** `9mm`, `.45 ACP`, `5.56x45mm`, `7.62x39mm`, `12ga Buckshot` (8 pellets), and `12ga Slug` (cycle ammo mid-raid with `Alt + R`).
- **Smart Presets & Shooting Range (`F2`):** One-click build presets that automatically buy missing parts, paired with an underground shooting range featuring `10m / 25m / 50m` silhouettes, ADS zoom, recoil/spread testing, and an infinite ammo toggle.

### Procedural World, Combat & Survival
- **Chunk-Based Procedural World (`WorldGenerator`):** `16x16` tile chunks (`32px` tiles) combining an orthogonal urban road grid with curved outer roads, multiple biomes (`residential`, `commercial`, `industrial`, `military`, `forest`), and **12 building presets**.
- **Interactive Environments & Interiors:** Enterable building interiors (`building_interior_scene.gd`), toggleable doors, breakable windows (creating sound alerts), locked armory/medical vaults opened with keys/keycards, and power switches that restore interior lighting and unlock electronic security doors and bunker exits.
- **Enemy Archetypes (`enemy.gd`):** `Zombie`, `Runner`, `Tank`, `Scav` (armed ranged), `Raider` (elite armed), `Boss` (commander with burst fire and grenades), and `Night Stalker` (low visibility in darkness unless lit by your flashlight).
- **Tactical Survival Systems (`SurvivalStats`):** HP, Stamina, Hunger, Thirst, Weight tiers (`35 kg` overweight stamina penalty; `50 kg+` sprint disabled & movement penalty), armor durability wear, weapon jamming/dry-fire, and status ailments (**Bleeding**, **Fracture**, **Infection**) cured through channeled consumables.
- **Atmosphere & Dynamic Lighting:** Day/night cycle, shadow-casting directional flashlight (`F`), Night Vision Goggles (`N`), 6 weather types (`Clear`, `Cloudy`, `Rain`, `Heavy Rain`, `Fog`, `Storm` with lightning & thunder), and post-processing effects (vignette, bloom, chromatic aberration).
- **Tactical Tools & Extraction (`main_world.gd`):**
  - Top HUD compass bar, Tactical Map (`M`), Field Crafting (`C`), and Field Weapon Modding (`B`).
  - **Tactical Radio (`U`, requires radio in backpack):** Recon frequency scans (enemies, supply drops, boss), emergency drone supply drops, and **Fulton Recovery** to extract a single item mid-raid.
  - **3 Field Objectives & Airdrops:** Hold `E` for `3.0s` at terminals/biosamplers/relays (triggering defense waves) to earn extraction bonuses and unlock bunker exits.
  - **3 Extraction Types:** Standard (`7s`), Paid Armored Vehicle (`2s` for `3,000 RUB`), and Emergency Bunker (`5s`, unlocked via field objective / power restoration).

### Game Modes & Localization
- **New Raid Presets & Custom Rules:** `Casual`, `Standard`, `Hardcore`, and `Custom` settings for zombie density, raid duration (`10 / 20 / 30 / 60 min` or `Infinite`), loot multiplier, day/night speed, starting RUB, and optional **Permadeath**.
- **Sandbox Mode:** Custom multipliers up to `400%` zombie density/loot, up to `100,000 RUB` starting funds, instant safe return from the pause menu, and an in-game Item Spawner (`F1`).
- **Bilingual Support (`I18nManager`):** Supports Korean (`ko`) and English (`en`) via `resources/i18n/translations.csv` *(note: parts of the in-game UI and item names are Korean-first)*.

---

## Controls

| Key / Input | Action |
| :--- | :--- |
| `W` `A` `S` `D` / Arrow Keys | Move |
| `Mouse` | Aim |
| `Left Click` (Hold for auto) | Attack / Fire weapon |
| `Right Click` (Hold) | Aim Down Sights (ADS) |
| `R` | Reload weapon / Rotate dragged item (in inventory) |
| `Alt + R` | Cycle compatible ammo type |
| `Shift` | Sprint |
| `Ctrl` | Crouch / Stealth |
| `E` | Interact / Loot / Open-Close Doors / Hold `3s` for Field Objectives |
| `1` – `4` / `Mouse Wheel` | Switch weapon slots (`Primary 1`, `Primary 2`, `Sidearm`, `Throwable`) |
| `5` – `7` | Quickslots (`5`: Bandage/Bleed, `6`: Heal, `7`: Food/Water) |
| `F` | Toggle Flashlight |
| `N` | Toggle Night Vision Goggles (NVG) |
| `Tab` / `I` | Open Inventory (4-panel layout in raid) |
| `C` | Open Crafting window |
| `B` | Open Weapon Modding window / Workbench tab |
| `M` | Open Tactical Map |
| `U` | Open Tactical Radio (requires radio in backpack) |
| `Esc` | Pause Menu |
| `F1` | Sandbox / Item Spawner |
| `F2` | Shooting Range (in Hideout) |

---

## Getting Started

### Windows One-Line Installer (PowerShell)

Install **RuinHarvest** as a Windows desktop application into `C:\Program Files\RuinHarvest` (automatically requests Administrator permission via UAC, creates Start Menu & Desktop shortcuts, and registers the app in Windows **Installed apps**):

```powershell
irm https://raw.githubusercontent.com/SDXMQ/RuinHarvest/main/install.ps1 | iex
```

> [!IMPORTANT]
> [install.ps1](install.ps1) downloads `RuinHarvest.exe` (or a Windows `.zip` build) from the latest [GitHub Release](https://github.com/SDXMQ/RuinHarvest/releases/latest). Make sure a Windows release asset is published on GitHub Releases before running this command.

To uninstall, remove **RuinHarvest** from **Windows Settings → Apps → Installed apps** (save data under `%APPDATA%\Godot\app_userdata\RuinHarvest` is preserved), or run:

```powershell
& "$env:ProgramFiles\RuinHarvest\uninstall.ps1"
```

### Run from Source (Godot 4.7)

#### Prerequisites
- **Godot Engine 4.7** (Forward Plus renderer; see `project.godot`)
- *(Optional, only if regenerating pixel sprite sheets)* **Python 3** with `numpy` and `Pillow`

#### Run the Project
1. Clone the repository:
   ```bash
   git clone https://github.com/SDXMQ/RuinHarvest.git
   ```
2. Open **Godot Engine 4.7** and import `project.godot`.
3. Press **F5** (or click **Run Project**) to launch from `res://scenes/main_menu/main_menu.tscn`.

#### Regenerate Pixel Art Atlases (Optional)
All pre-baked diffuse (`*_d.png`) and OpenGL normal-map (`*_n.png`) atlases are already committed under `assets/pixel/`. If you modify `scripts/tools/bake_pixel_assets.py`, re-bake them with:
```bash
pip install numpy pillow
python scripts/tools/bake_pixel_assets.py
```

---

## Project Structure

```text
RuinHarvest/
├── assets/pixel/              # Pre-baked pixel sprite sheets (*_d.png, *_n.png), icons & manifest.json
├── autoload/                  # Global singletons (GameManager, SaveManager, ItemDatabase, I18nManager, etc.)
├── data/items/                # Item resource definitions (.tres)
├── graphics/shaders/          # Custom shaders (pixel_entity, hit_flash, post_process, water_foliage)
├── resources/i18n/            # Localization table (translations.csv)
├── scenes/
│   ├── entities/              # Player (camera, lighting, stats, weapons), enemies, bullets, ground items
│   ├── hideout/               # Hideout UI, stash/loadout grids, traders, flea market, workbench
│   ├── interior/              # Enterable building interior scene
│   ├── main_menu/             # Main menu, custom raid setup, sandbox menu
│   ├── ui/                    # Inventory, crafting, map, radio, weapon modding, shooting range, settings
│   └── world/                 # Main raid world, chunk manager, world generator, extraction zones, objects
├── scripts/tools/             # Asset pipeline scripts (bake_pixel_assets.py)
├── systems/                   # Core gameplay systems (2D inventory grid, weapon parts DB, progression, weather, events)
├── ui/theme/                  # Tactical pixel UI theme (tactical_theme.tres)
├── world/interior/            # Interior layout generator
└── install.ps1                # Windows one-line PowerShell installer (Program Files + shortcuts + Apps registry)
```

---

## License

This project is licensed under the **GNU General Public License v3.0** — see the [LICENSE](LICENSE) file for details.
