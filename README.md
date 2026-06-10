# RuinHarvest (30 Days to Survive)

[한국어 (Korean)](./README_KR.md)

RuinHarvest is a 2D top-down **Harvest & Extraction** survival indie game set in a zombie apocalypse. Players enter dangerous ruins (Raids) to scavenge for resources, survive threats, and escape through extraction points to upgrade their hideouts and survive for 30 days.

---

## 🎮 Key Gameplay Systems

### 1. Procedural Open World & Chunk Rendering
- Explore an infinite world generated dynamically based on seeds.
- **Diverse Biomes**: Residential, City, Factory, Hospital, Military Base, Forest, Lake, etc., each with unique structures and spawn rates.
- **Chunk Management**: Unloads distant chunks and preserves state deltas to prevent memory leaks.

### 2. Hardcore Extraction & Settlement Logic
- If you die (KIA) or run out of time (MIA) during a raid, you lose all items in your inventory and equipment, except for those in the Harvest Pouch (secure container).
- **Extractions**: Unique extraction points across the map requiring different actions (always open, key required, time-locked).

### 3. Intelligent Tactical AI (Zombies & PMCs)
- **A* Pathfinding**: Obstacle avoidance and flank maneuvering.
- Real-time reaction to player actions (sprint noise, gunshots, crouching).
- **Cover & Flank**: Injured AI retreat to cover to heal, or perform flank attacks.
- **Faction Hostility**: PMC and Scav factions engage in active combat when they spot each other (AI vs AI).

### 4. 2.5D Graphics & Ambient Lighting
- Dynamic day-night cycles (Day, Dusk, Night, Dawn) and weather conditions (Rain, Snow, Fog) that affect player stress and vision.
- Visual tracers and laser sights indicating AI aiming state (distinguishable between PMC and Scav).

### 5. Multi-story Building Looting (OOP Refactored)
- Enter buildings to search furniture (Fridge, Locker, Weapon Box, etc.) for loot.
- **Stairs**: Navigate multi-story buildings (e.g., 2nd floor) via interior stairs.
- **Window Vision**: Look through windows to monitor outside zombie movements and items in real time.

### 6. Virtual Flea Market & Hideout
- Trade scavenged loot on the Flea Market with fluctuating prices.
- Trade with specific merchants or upgrade Stash slots to organize your gear.

---

## 🛠 Recent Updates & Changes

- **PMC Spawn Balancing**: Reduced PMC (`tank`, `spider`) spawn rates from `2%` to `0.2%` to make encounters rare and high-stakes, fitting the military or hospital zones.
- **Precise Collisions**: Upgraded player collision detection to a 4-point footstep bounding box (`+0.2` to `+0.8` width, `+0.8` to `+0.95` height) to resolve corner clipping bugs.
- **Roof Blocking & Occlusion Transparency**: Blocked overworld movement on building roofs. Walking behind a building now triggers alpha transparency (alpha 128) to keep the player visible.
- **Merchant Approach AI**: Merchants in `IDLE` state will show an exclamation mark (`!`) and slowly approach the player when detected within 8 tiles.
- **Light Tool Durability**: Added battery/durability depletion to `Flashlight`, `Torch`, and `Modified Flashlight` when used in dark environments (Night or Inside). Tools disappear when durability hits 0.
- **High-Value Loot**: Added `"Encrypted SSD"` and `"Military Compass"` with custom pixel icons to the Factory, Military, and Police loot tables.

---

## ⌨️ Basic Controls

| Key | Action |
| :---: | :--- |
| **W, A, S, D / Arrow Keys** | Move |
| **LSHIFT** | Sprint (Uses stamina, increases noise) |
| **LCTRL** | Crouch (Halves speed, reduces detection range, silent) |
| **E** | Interact (Loot, Talk, Enter Doors/Stairs) |
| **Left Click** | Attack / Shoot (Ranged weapons require ammunition) |
| **B** | Toggle Inventory |
| **C** | Toggle Crafting |
| **M** | Toggle Tactical Map |
| **F5** | Quick Save (Autosave) |
| **ESC** | Pause / Game Menu |

---

## ⚙️ Run & Build

Built using **Python 3** and **pygame-ce**.

1. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
2. Run the game:
   ```bash
   python src/main.py
   ```
3. Run validation tests:
   ```bash
   python src/validate.py
   ```
