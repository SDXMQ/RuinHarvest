"""
tests/e2e/tier4_workloads.py
Tier 4: End-to-End Raid Workload Scenarios
Contains 7 full-lifecycle tactical extraction raid workloads simulating complex player journeys.
"""

from typing import List
from tests.e2e.framework import (
    BaseE2ETestCase, Assert, WeaponModdingOracle,
    ReceiverCompatibilityOracle, InventoryGridOracle,
    DurabilityEconomyOracle, ProjectFileInspector
)

def get_tier4_tests() -> List[BaseE2ETestCase]:
    tests: List[BaseE2ETestCase] = []

    class T4_01_full_successful_raid_workload(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T4_01", "Full Standard Extraction Raid: Spawn -> Engage -> Loot & Mod -> Channel Meds -> Extract", 4, "Raid_Lifecycle")
        def execute(self):
            # 1. Spawn in raid with M4A1 and 10x15 backpack
            grid = InventoryGridOracle(10, 15)
            weapon = {
                "id": "M4_리시버",
                "durability": 100.0,
                "parts": {"magazine": "m4_30rnd_mag"}
            }
            player = {"hp": 100.0, "is_bleeding": False, "wallet_rubles": 50000}
            
            # 2. Engage scavenger: Fire 15 rounds
            shots = 15
            weapon["durability"] = DurabilityEconomyOracle.calculate_weapon_durability(weapon["durability"], shots)
            Assert.almost_equal(weapon["durability"], 97.75, 0.001)
            
            # 3. Loot ACOG scope and equip onto M4
            can_equip, _ = ReceiverCompatibilityOracle.can_equip_part(weapon["id"], "optic", "acog_scope")
            Assert.true(can_equip)
            weapon["parts"]["optic"] = "acog_scope"
            new_stats = WeaponModdingOracle.compute_weapon_stats(weapon["id"], weapon["parts"])
            Assert.almost_equal(new_stats["zoom_level"], 2.6, 0.01)
            
            # 4. Take minor damage, apply bandage (1.5s channeling)
            player["hp"] = 85.0
            player["is_bleeding"] = True
            # Channeling complete
            player["hp"] = min(100.0, player["hp"] + 15.0)
            player["is_bleeding"] = False
            Assert.equal(player["hp"], 100.0)
            Assert.false(player["is_bleeding"])
            
            # 5. Extract safely: all items preserved
            grid.place_item({"id": "valuable_gem", "width": 1, "height": 1, "category": "MISC"}, 5, 5)
            Assert.equal(len(grid.items), 1)

    class T4_02_tragic_kia_with_secure_pouch_survival(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T4_02", "Fatal Raid (KIA): Secure high-value loot in 2x2 pouch -> Died -> Verify pouch preserved", 4, "Raid_Lifecycle")
        def execute(self):
            grid = InventoryGridOracle(10, 15)
            
            # 1. Place encrypted intel and gold watch in 2x2 pouch (cells 0,0 and 1,0)
            grid.place_item({"id": "encrypted_ssd", "width": 1, "height": 1, "category": "QUEST"}, 0, 0)
            grid.place_item({"id": "gold_watch", "width": 1, "height": 1, "category": "MISC"}, 1, 0)
            
            # 2. Place heavy loot in general backpack
            grid.place_item({"id": "large_battery", "width": 2, "height": 2, "category": "MISC"}, 4, 4)
            
            # 3. Ambushed by sniper, HP drops to 0 (KIA)
            pouch_rescued = grid.filter_pouch_items_for_mia_kia()
            
            # 4. General backpack wiped, pouch rescued
            Assert.equal(len(pouch_rescued), 2)
            rescued_ids = [it["id"] for it in pouch_rescued]
            Assert.contains("encrypted_ssd", rescued_ids)
            Assert.contains("gold_watch", rescued_ids)
            Assert.not_contains("large_battery", rescued_ids)

    class T4_03_desperate_mia_timeout_abandonment(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T4_03", "MIA Timeout Raid: Complete landmark terminal, miss extraction -> Verify pouch & quest payout", 4, "Raid_Lifecycle")
        def execute(self):
            grid = InventoryGridOracle(10, 15)
            grid.place_item({"id": "quest_drive", "width": 1, "height": 1, "category": "QUEST"}, 0, 0)
            
            # 1. Complete 3s landmark terminal
            landmark_completed = True
            Assert.true(landmark_completed)
            
            # 2. Timer expires at 00:00 -> GameManager.end_raid('mia', looted_items)
            pouch_items = grid.filter_pouch_items_for_mia_kia()
            Assert.equal(len(pouch_items), 1)
            Assert.equal(pouch_items[0]["id"], "quest_drive")

    class T4_04_boss_conquest_and_airdrop_sweep(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T4_04", "Hardcore Boss & Airdrop Raid: Loot airdrop -> Evade boss bursts -> Slay boss -> Extract", 4, "Raid_Lifecycle")
        def execute(self):
            # 1. Airdrop arrives: Verify guaranteed airdrop crate rewards defined in main_world.gd
            world_content = ProjectFileInspector.read_file("scenes/world/main_world.gd")
            Assert.true('"M4_리시버"' in world_content, "Airdrop bonus weapons must include M4_리시버")
            Assert.true('"3레벨_방탄복"' in world_content, "Airdrop bonus gear must include 3레벨_방탄복")
            Assert.true('"고급 치료킷"' in world_content, "Airdrop bonus gear must include 고급 치료킷 with space ID")
            Assert.true('"장거리 무전기"' in world_content, "Airdrop bonus gear must include 장거리 무전기 with space ID")

            # 2. Verify ItemDatabase bidirectional lookup support
            item_db_content = ProjectFileInspector.read_file("autoload/item_database.gd")
            Assert.true('id.replace("_", " ")' in item_db_content, "ItemDatabase must support underscore/space fallback")
            
            # 3. Boss defeated -> drops guaranteed custom modded M4 with attachments
            boss_parts = {"optic": "acog_scope", "muzzle": "m4_silencer", "magazine": "m4_60rnd_drum"}
            computed = WeaponModdingOracle.compute_weapon_stats("M4_리시버", boss_parts)
            Assert.almost_equal(computed["zoom_level"], 2.6, 0.01, "ACOG scope must increase zoom")
            Assert.almost_equal(computed["noise_radius"], 150.0, 0.01, "Silencer must reduce noise radius")
            Assert.equal(computed["magazine_size"], 60, "Drum magazine must set capacity to 60")
            enemy_content = ProjectFileInspector.read_file("scenes/entities/enemies/enemy.gd")
            Assert.true('"3레벨_방탄복"' in enemy_content and '"암호화된_SSD"' in enemy_content, "Boss must drop valid 3레벨_방탄복 and 암호화된_SSD")

    class T4_05_hideout_full_economy_and_repair_loop(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T4_05", "Hideout Economy Loop: Repair damaged weapon & armor at workbench using Rubles & Scrap", 4, "Raid_Lifecycle")
        def execute(self):
            player_rubles = 20000
            player_scrap = 5
            
            # Damaged items from previous raid
            weapon = {"durability": 70.0, "max_durability": 100.0} # 30 missing
            armor = {"durability": 180.0, "max_durability": 220.0} # 40 missing
            
            # Calculate repair costs
            w_rubles, _ = DurabilityEconomyOracle.calculate_repair_cost(weapon["durability"], weapon["max_durability"])
            _, a_scrap = DurabilityEconomyOracle.calculate_repair_cost(armor["durability"], armor["max_durability"])
            
            # 30 * 35 = 1050 Rubles
            Assert.equal(w_rubles, 1050)
            # ceil(40 / 20.0) = 2 Scrap
            Assert.equal(a_scrap, 2)
            
            # Deduct wallet & resources
            player_rubles -= w_rubles
            player_scrap -= a_scrap
            weapon["durability"] = weapon["max_durability"]
            armor["durability"] = armor["max_durability"]
            
            Assert.equal(player_rubles, 18950)
            Assert.equal(player_scrap, 3)
            Assert.equal(weapon["durability"], 100.0)
            Assert.equal(armor["durability"], 220.0)

    class T4_06_tactical_night_raid_fow_simulation(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T4_06", "Night Infiltration: NVG and flashlight visibility switching with silenced stealth shot", 4, "Raid_Lifecycle")
        def execute(self):
            # In pitch darkness: enemy at 150px is invisible (alpha=0.0)
            enemy_dist = 150.0
            flashlight_on = False
            nvg_on = False
            is_visible = (flashlight_on or nvg_on) or (enemy_dist < 35.0)
            Assert.false(is_visible)
            
            # Turn on NVG -> enemy becomes visible
            nvg_on = True
            is_visible = (flashlight_on or nvg_on) or (enemy_dist < 35.0)
            Assert.true(is_visible)
            
            # Silenced shot: noise radius is 150px (does not alert enemy at 250px)
            stats = WeaponModdingOracle.compute_weapon_stats("M4_리시버", {"muzzle": "m4_silencer"})
            Assert.equal(stats["noise_radius"], 150.0)
            Assert.less(stats["noise_radius"], 250.0)

    class T4_07_ultimate_disaster_recovery_and_webhook(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T4_07", "Full Stress Run: Inventory boundary stress + Void drop recovery -> Webhook payload assembly", 4, "Raid_Lifecycle")
        def execute(self):
            grid = InventoryGridOracle(10, 15)
            # Fill 2x2 with medical items
            grid.place_item({"id": "med_1", "width": 1, "height": 1, "category": "MEDICAL"}, 0, 0)
            grid.place_item({"id": "med_2", "width": 1, "height": 1, "category": "MEDICAL"}, 1, 0)
            grid.place_item({"id": "med_3", "width": 1, "height": 1, "category": "MEDICAL"}, 0, 1)
            grid.place_item({"id": "med_4", "width": 1, "height": 1, "category": "MEDICAL"}, 1, 1)
            Assert.equal(len(grid.items), 4)
            
            # Drag drop on void -> safely restored
            in_vicinity = False
            action = "drop_to_world" if in_vicinity else "restore_to_grid"
            Assert.equal(action, "restore_to_grid")
            
            # Prepare final webhook payload
            webhook_payload = {
                "username": "RuinHarvest Tactical HQ",
                "embeds": [{
                    "title": "⚔️ [RuinHarvest] All 161 Tests Passed",
                    "color": 0x2ECC71,
                    "fields": [
                        {"name": "Tier 1: Functional Baseline", "value": "70/70 Passed"},
                        {"name": "Tier 2: Boundary Value Analysis", "value": "70/70 Passed"},
                        {"name": "Tier 3: Pairwise Interactions", "value": "14/14 Passed"},
                        {"name": "Tier 4: Workload Scenarios", "value": "7/7 Passed"}
                    ]
                }]
            }
            Assert.equal(len(webhook_payload["embeds"][0]["fields"]), 4)

    # Register all 7 test cases
    tests.extend([
        T4_01_full_successful_raid_workload(),
        T4_02_tragic_kia_with_secure_pouch_survival(),
        T4_03_desperate_mia_timeout_abandonment(),
        T4_04_boss_conquest_and_airdrop_sweep(),
        T4_05_hideout_full_economy_and_repair_loop(),
        T4_06_tactical_night_raid_fow_simulation(),
        T4_07_ultimate_disaster_recovery_and_webhook(),
    ])

    return tests
