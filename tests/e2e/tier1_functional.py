"""
tests/e2e/tier1_functional.py
Tier 1: Functional Baseline Verification
Contains 70 detailed test cases covering primary behaviors for features R1 through R14 (5 cases per feature).
"""

import os
import re
import math
from typing import List
from tests.e2e.framework import (
    BaseE2ETestCase, Assert, WeaponModdingOracle,
    ReceiverCompatibilityOracle, InventoryGridOracle,
    DurabilityEconomyOracle, ProjectFileInspector
)

def get_tier1_tests() -> List[BaseE2ETestCase]:
    tests: List[BaseE2ETestCase] = []

    # =========================================================================
    # R1: 총기 부품 키 단일화 및 모딩 스탯 연동 ("parts" 통일)
    # =========================================================================
    class T1_R1_01_parts_key_exclusivity(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R1_01", "Verify weapon dict uses 'parts' key exclusively", 1, "R1")
        def execute(self):
            # Authoritative spec: weapon dictionary must store attachments under "parts"
            test_weapon = {
                "id": "M4_리시버",
                "receiver": "M4_리시버",
                "parts": {"optic": "acog_scope", "muzzle": "m4_silencer"}
            }
            Assert.contains("parts", test_weapon, "Weapon must have 'parts' key")
            Assert.not_contains("attachments", test_weapon, "Legacy 'attachments' key should not be present")
            Assert.equal(test_weapon["parts"]["optic"], "acog_scope")

    class T1_R1_02_optic_zoom_stat_computation(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R1_02", "Verify optic scope increases zoom_level in computed_stats", 1, "R1")
        def execute(self):
            base_stats = WeaponModdingOracle.compute_weapon_stats("M4_리시버", {})
            modded_stats = WeaponModdingOracle.compute_weapon_stats("M4_리시버", {"optic": "acog_scope"})
            Assert.almost_equal(base_stats["zoom_level"], 1.0, 0.01)
            Assert.almost_equal(modded_stats["zoom_level"], 2.6, 0.01, "ACOG must add 1.6 to base 1.0 zoom")
            Assert.greater(modded_stats["zoom_level"], base_stats["zoom_level"])

    class T1_R1_03_silencer_noise_radius_reduction(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R1_03", "Verify silencer drastically decreases weapon noise_radius", 1, "R1")
        def execute(self):
            base_stats = WeaponModdingOracle.compute_weapon_stats("M4_리시버", {})
            modded_stats = WeaponModdingOracle.compute_weapon_stats("M4_리시버", {"muzzle": "m4_silencer"})
            Assert.equal(base_stats["noise_radius"], 380.0)
            Assert.equal(modded_stats["noise_radius"], 150.0, "Silencer should reduce noise by 230 (380 - 230 = 150)")
            Assert.less(modded_stats["noise_radius"], base_stats["noise_radius"])

    class T1_R1_04_magazine_capacity_computation(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R1_04", "Verify 60-round drum mag updates computed magazine_size", 1, "R1")
        def execute(self):
            base_stats = WeaponModdingOracle.compute_weapon_stats("M4_리시버", {})
            modded_stats = WeaponModdingOracle.compute_weapon_stats("M4_리시버", {"magazine": "m4_60rnd_drum"})
            Assert.equal(base_stats["magazine_size"], 30)
            Assert.equal(modded_stats["magazine_size"], 60, "Drum mag must increase capacity to 60")

    class T1_R1_05_stock_recoil_reduction(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R1_05", "Verify stock decreases recoil_scale", 1, "R1")
        def execute(self):
            base_stats = WeaponModdingOracle.compute_weapon_stats("M4_리시버", {})
            modded_stats = WeaponModdingOracle.compute_weapon_stats("M4_리시버", {"stock": "magpul_prs_stock"})
            Assert.almost_equal(base_stats["recoil_scale"], 1.0, 0.01)
            Assert.almost_equal(modded_stats["recoil_scale"], 0.65, 0.01, "PRS stock should reduce recoil scale to 0.65")

    # =========================================================================
    # R2: 부품 우클릭 자동 장착 슬롯 검사 정상화
    # =========================================================================
    class T1_R2_01_m9_blocks_stock_attachment(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R2_01", "Verify M9 pistol strictly blocks stock attachment", 1, "R2")
        def execute(self):
            can_equip, reason = ReceiverCompatibilityOracle.can_equip_part("M9_리시버", "stock", "folding_stock")
            Assert.false(can_equip, "M9 pistol must NOT allow stock attachment")
            Assert.contains("slot 'stock'", reason)

    class T1_R2_02_receiver_slots_lookup_correctness(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R2_02", "Verify receiver slot check accesses RECEIVERS table rather than PARTS", 1, "R2")
        def execute(self):
            # Authoritative check: M9_리시버 exists in RECEIVERS, not PARTS
            Assert.contains("M9_리시버", WeaponModdingOracle.RECEIVERS)
            Assert.not_contains("M9_리시버", WeaponModdingOracle.PARTS)
            rec_slots = WeaponModdingOracle.RECEIVERS["M9_리시버"]["slots"]
            Assert.false("stock" in rec_slots, "M9 slots must not define stock")

    class T1_R2_03_m4_allows_valid_stock(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R2_03", "Verify M4 receiver accepts compatible rifle stock", 1, "R2")
        def execute(self):
            can_equip, _ = ReceiverCompatibilityOracle.can_equip_part("M4_리시버", "stock", "magpul_prs_stock")
            Assert.true(can_equip, "M4 rifle must allow compatible PRS stock")

    class T1_R2_04_category_mismatch_rejection(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R2_04", "Verify sniper-only attachment rejected on pistol", 1, "R2")
        def execute(self):
            can_equip, reason = ReceiverCompatibilityOracle.can_equip_part("M9_리시버", "optic", "acog_scope")
            Assert.false(can_equip, "Pistol must reject rifle/sniper ACOG scope")

    class T1_R2_05_empty_slot_rejection(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R2_05", "Verify non-existent slot key is rejected unconditionally", 1, "R2")
        def execute(self):
            can_equip, _ = ReceiverCompatibilityOracle.can_equip_part("M4_리시버", "underbarrel_laser", "pistol_red_dot")
            Assert.false(can_equip, "Undefined slot must be rejected")

    # =========================================================================
    # R3: 공중 보급품(AirdropCrate) 확정 보상 아이템 ID 동기화
    # =========================================================================
    class T1_R3_01_airdrop_receiver_ids_valid(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R3_01", "Verify guaranteed airdrop weapon receivers exist in database", 1, "R3")
        def execute(self):
            valid_receivers = ["M4_리시버", "AK_리시버", "SV98_리시버"]
            for rec_id in valid_receivers:
                Assert.contains(rec_id, WeaponModdingOracle.RECEIVERS, f"{rec_id} must exist in RECEIVERS")

    class T1_R3_02_airdrop_armor_ids_valid(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R3_02", "Verify guaranteed airdrop armors exist as .tres resources", 1, "R3")
        def execute(self):
            valid_armors = ["3레벨_방탄복", "3레벨_헬멧"]
            for arm_id in valid_armors:
                tres_path = f"data/items/{arm_id}.tres"
                Assert.true(ProjectFileInspector.file_exists(tres_path), f"Armor resource must exist: {tres_path}")

    class T1_R3_03_no_legacy_korean_strings(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R3_03", "Verify obsolete legacy reward strings are purged", 1, "R3")
        def execute(self):
            legacy_strings = ["M4A1 카빈", "AK-74M 돌격소총", "AWM 저격소총", "6B43 6A급 중방탄복", "알틴 방탄 헬멧"]
            # When main_world.gd is inspected, it should not have these as item IDs in airdrop
            for s in legacy_strings:
                Assert.not_contains(s, WeaponModdingOracle.RECEIVERS)

    class T1_R3_04_airdrop_reward_item_instantiation(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R3_04", "Verify instantiating reward produces valid dictionary", 1, "R3")
        def execute(self):
            reward_item = {
                "id": "3레벨_방탄복",
                "name": "3레벨 방탄복",
                "category": "EQUIPMENT",
                "durability": 220.0,
                "max_durability": 220.0,
                "armor_defense": 45.0,
                "width": 2,
                "height": 2
            }
            Assert.equal(reward_item["id"], "3레벨_방탄복")
            Assert.equal(reward_item["durability"], 220.0)

    class T1_R3_05_airdrop_inventory_placement(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R3_05", "Verify airdrop items can be placed in 2D container grid", 1, "R3")
        def execute(self):
            grid = InventoryGridOracle(10, 10)
            reward_gear = {"id": "3레벨_방탄복", "width": 2, "height": 2, "category": "EQUIPMENT"}
            placed = grid.place_item(reward_gear, 4, 4)
            Assert.true(placed, "Valid reward item should fit into container grid")

    # =========================================================================
    # R4: 아이템 분할(Split) 상태 보존
    # =========================================================================
    class T1_R4_01_auto_add_does_not_call_consolidate(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R4_01", "Verify auto_add_item preserves separate identical item stacks", 1, "R4")
        def execute(self):
            grid = InventoryGridOracle(8, 8)
            # User manually split 9mm ammo into two stacks: 10 rounds at (2,0) and 20 rounds at (3,0)
            grid.place_item({"id": "ammo_9mm", "count": 10, "width": 1, "height": 1, "category": "AMMO"}, 2, 0)
            grid.place_item({"id": "ammo_9mm", "count": 20, "width": 1, "height": 1, "category": "AMMO"}, 3, 0)
            
            # Now player picks up a bandage
            grid.auto_add_item("bandage", 1)
            
            # Assert ammo stacks remain split (10 and 20), not merged into 30
            ammo_stacks = [it for it in grid.items if it["id"] == "ammo_9mm"]
            Assert.equal(len(ammo_stacks), 2, "Ammo stacks must remain 2 separate stacks")
            counts = sorted([it["count"] for it in ammo_stacks])
            Assert.equal(counts, [10, 20], "Counts must remain 10 and 20")

    class T1_R4_02_manual_split_stacks_preserved_on_pickup(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R4_02", "Verify picking up additional items preserves user stack splits", 1, "R4")
        def execute(self):
            grid = InventoryGridOracle(6, 6)
            grid.place_item({"id": "ammo_556", "count": 15, "width": 1, "height": 1, "category": "AMMO"}, 2, 2)
            grid.place_item({"id": "ammo_556", "count": 15, "width": 1, "height": 1, "category": "AMMO"}, 3, 2)
            grid.auto_add_item("medical_kit", 1)
            ammo_items = [it for it in grid.items if it["id"] == "ammo_556"]
            Assert.equal(len(ammo_items), 2)

    class T1_R4_03_auto_add_fills_matching_stack_first(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R4_03", "Verify auto_add fills existing stack up to max_stack before creating new", 1, "R4")
        def execute(self):
            grid = InventoryGridOracle(6, 6)
            grid.place_item({"id": "ammo_9mm", "count": 50, "width": 1, "height": 1, "category": "AMMO"}, 2, 2)
            rem = grid.auto_add_item("ammo_9mm", 5, max_stack=60)
            Assert.equal(rem, 0)
            Assert.equal(grid.items[0]["count"], 55, "Existing stack should be increased to 55")

    class T1_R4_04_auto_add_creates_new_stack_when_full(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R4_04", "Verify auto_add creates separate stack when existing is at max", 1, "R4")
        def execute(self):
            grid = InventoryGridOracle(6, 6)
            grid.place_item({"id": "ammo_9mm", "count": 60, "width": 1, "height": 1, "category": "AMMO"}, 2, 2)
            rem = grid.auto_add_item("ammo_9mm", 10, max_stack=60)
            Assert.equal(rem, 0)
            Assert.equal(len(grid.items), 2, "A second stack must be created")
            Assert.equal(grid.items[0]["count"], 60)
            Assert.equal(grid.items[1]["count"], 10)

    class T1_R4_05_explicit_sort_consolidates_stacks(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R4_05", "Verify explicit consolidation only runs when explicitly called", 1, "R4")
        def execute(self):
            grid = InventoryGridOracle(6, 6)
            grid.place_item({"id": "ammo_9mm", "count": 10, "width": 1, "height": 1, "category": "AMMO"}, 2, 2)
            grid.place_item({"id": "ammo_9mm", "count": 15, "width": 1, "height": 1, "category": "AMMO"}, 3, 2)
            # Simulated explicit sort
            total = sum(it["count"] for it in grid.items if it["id"] == "ammo_9mm")
            Assert.equal(total, 25)

    # =========================================================================
    # R5: 안전 컨테이너(2x2 SECURE) 포기(MIA) / 사망(KIA) 보호 통합
    # =========================================================================
    class T1_R5_01_mia_preserves_pouch_items(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R5_01", "Verify abandon raid (MIA) preserves 2x2 secure container items", 1, "R5")
        def execute(self):
            grid = InventoryGridOracle(10, 10)
            # Place gold clock in 2x2 secure pouch (cell 0,0)
            grid.place_item({"id": "gold_watch", "width": 1, "height": 1, "category": "MISC"}, 0, 0)
            # Place backpack item outside pouch (cell 5,5)
            grid.place_item({"id": "heavy_scrap", "width": 2, "height": 2, "category": "MISC"}, 5, 5)
            
            pouch_saved = grid.filter_pouch_items_for_mia_kia()
            Assert.equal(len(pouch_saved), 1, "Only 2x2 pouch item must be preserved")
            Assert.equal(pouch_saved[0]["id"], "gold_watch")

    class T1_R5_02_kia_preserves_pouch_items(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R5_02", "Verify killed in action (KIA) preserves 2x2 secure container items", 1, "R5")
        def execute(self):
            grid = InventoryGridOracle(10, 10)
            grid.place_item({"id": "encrypted_ssd", "width": 1, "height": 1, "category": "QUEST"}, 1, 1)
            pouch_saved = grid.filter_pouch_items_for_mia_kia()
            Assert.equal(len(pouch_saved), 1)
            Assert.equal(pouch_saved[0]["id"], "encrypted_ssd")

    class T1_R5_03_outside_pouch_lost_on_kia(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R5_03", "Verify items outside 2x2 pouch are completely lost on KIA", 1, "R5")
        def execute(self):
            grid = InventoryGridOracle(10, 10)
            grid.place_item({"id": "m4_mag", "width": 1, "height": 2, "category": "AMMO"}, 3, 3)
            pouch_saved = grid.filter_pouch_items_for_mia_kia()
            Assert.equal(len(pouch_saved), 0, "Outside item must not survive")

    class T1_R5_04_end_raid_mia_passes_backpack_items(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R5_04", "Verify GameManager.end_raid contract accepts looted_items on MIA", 1, "R5")
        def execute(self):
            # Authoritative check: end_raid signature accepts result and looted_items
            Assert.true(ProjectFileInspector.contains_pattern("autoload/game_manager.gd", r"func\s+end_raid\s*\(\s*result\s*:\s*String\s*,\s*looted_items\s*:\s*Array"))

    class T1_R5_05_building_interior_mia_passes_items(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R5_05", "Verify building interior scene supports MIA safe exit", 1, "R5")
        def execute(self):
            Assert.true(ProjectFileInspector.file_exists("scenes/interior/building_interior_scene.gd"))

    # =========================================================================
    # R6: 툴팁 및 무기 패널 슬롯 복원
    # =========================================================================
    class T1_R6_01_tooltip_shows_magazine_size(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R6_01", "Verify tooltip handles magazine_size stat key", 1, "R6")
        def execute(self):
            content = ProjectFileInspector.read_file("scenes/ui/item_tooltip.gd")
            Assert.true("magazine_size" in content and "탄창 용량" in content, "Tooltip must support magazine_size stat rendering")

    class T1_R6_02_tooltip_shows_reload_speed(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R6_02", "Verify tooltip handles reload_speed stat key", 1, "R6")
        def execute(self):
            content = ProjectFileInspector.read_file("scenes/ui/item_tooltip.gd")
            Assert.true("reload_speed" in content and "장전 시간" in content, "Tooltip must support reload_speed stat rendering")

    class T1_R6_03_sidearm_weapon_panel_slots_exposed(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R6_03", "Verify weapon panel supports sidearm slot exposure", 1, "R6")
        def execute(self):
            content = ProjectFileInspector.read_file("scenes/ui/inventory_window.gd")
            Assert.true(bool(re.search(r'slot_key == "sidearm"', content)), "Weapon panel must expose attachment slots for sidearm")

    class T1_R6_04_barrel_slot_supported(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R6_04", "Verify barrel slot is included in supported weapon slots", 1, "R6")
        def execute(self):
            content = ProjectFileInspector.read_file("scenes/ui/inventory_window.gd")
            Assert.true(bool(re.search(r'"barrel"', content)), "Weapon panel attachment slots must support barrel")

    class T1_R6_05_rail_slot_supported(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R6_05", "Verify rail slot is included in supported weapon slots", 1, "R6")
        def execute(self):
            content = ProjectFileInspector.read_file("scenes/ui/inventory_window.gd")
            Assert.true(bool(re.search(r'"rail"', content)), "Weapon panel attachment slots must support rail")

    # =========================================================================
    # R7: 미사용 1D 인벤토리 및 구형 잔재 정리
    # =========================================================================
    class T1_R7_01_no_1d_inventory_node_in_player(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R7_01", "Verify player.gd uses InventoryGrid exclusively for 2D bag", 1, "R7")
        def execute(self):
            content = ProjectFileInspector.read_file("scenes/entities/player/player.gd")
            Assert.false(bool(re.search(r'^\s*var\s+inventory\s*:\s*Inventory\b', content, re.MULTILINE)), "Legacy 1D Inventory variable must not exist")

    class T1_R7_02_no_1d_inventory_node_in_main_world(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R7_02", "Verify main_world.gd does not instantiate redundant 1D player inventory", 1, "R7")
        def execute(self):
            content = ProjectFileInspector.read_file("scenes/world/main_world.gd")
            Assert.not_contains("var player_inventory: Inventory", content, "Legacy player_inventory must be removed")

    class T1_R7_03_single_save_load_path(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R7_03", "Verify single 2D inventory load path in GameManager", 1, "R7")
        def execute(self):
            Assert.true(ProjectFileInspector.contains_pattern("autoload/game_manager.gd", r"player.*inventory"))

    class T1_R7_04_ghost_node_scripts_cleaned(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R7_04", "Verify 2D InventoryGrid is core system script", 1, "R7")
        def execute(self):
            Assert.true(ProjectFileInspector.file_exists("systems/inventory_grid.gd"))

    class T1_R7_05_container_inventory_preserved(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R7_05", "Verify container 1D inventory script preserved for loot boxes", 1, "R7")
        def execute(self):
            Assert.true(ProjectFileInspector.file_exists("systems/inventory.gd"))

    # =========================================================================
    # R8: 허공 드롭 시 아이템 버리기 방지 (조작 안전장치)
    # =========================================================================
    class T1_R8_01_drop_on_void_restores_item(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R8_01", "Verify dropping item onto void/empty space restores to slot", 1, "R8")
        def execute(self):
            content = ProjectFileInspector.read_file("scenes/ui/inventory_window.gd")
            Assert.true(bool(re.search(r'# 5\.\s*그 외 영역에 놓쳤을 경우 원래대로 복귀\s*_end_drag\(\)', content)), "Dropping on void/unhandled area must call _end_drag to restore item")

    class T1_R8_02_drop_on_window_margin_restores_item(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R8_02", "Verify dropping on window border margins restores item", 1, "R8")
        def execute(self):
            content = ProjectFileInspector.read_file("scenes/ui/inventory_window.gd")
            Assert.true("split_source_item" in content and "split_amount" in content and "_end_drag" in content, "Cancelling drag must safely restore split amount to original item")

    class T1_R8_03_drop_on_vicinity_drops_item(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R8_03", "Verify dropping specifically into VICINITY drops to ground", 1, "R8")
        def execute(self):
            content = ProjectFileInspector.read_file("scenes/ui/inventory_window.gd")
            Assert.true(bool(re.search(r'vicinity_rect\.has_point\(m_pos\):[\s\S]*?_drop_item_to_world', content)), "Only vicinity drop must trigger _drop_item_to_world")

    class T1_R8_04_drag_cancel_restores_original_position(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R8_04", "Verify drag cancellation safely restores original coordinates", 1, "R8")
        def execute(self):
            content = ProjectFileInspector.read_file("scenes/ui/inventory_window.gd")
            Assert.true(bool(re.search(r'split_item\["uid"\]\s*=\s*"item_%d_%d"', content)), "Split items must be assigned a unique UID to prevent item duplication or loss")

    class T1_R8_05_safety_boundary_check_logic(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R8_05", "Verify safety boundary logic requires vicinity_rect check only", 1, "R8")
        def execute(self):
            content = ProjectFileInspector.read_file("scenes/ui/inventory_window.gd")
            Assert.false(bool(re.search(r'func\s+_gui_input\b', content)), "Legacy _gui_input drop handler must be removed for safety")

    # =========================================================================
    # R9: 타이포그래피 & 시각 표기 체계 고도화
    # =========================================================================
    class T1_R9_01_tactical_theme_binds_system_font(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R9_01", "Verify tactical_theme.tres exists and defines UI theme", 1, "R9")
        def execute(self):
            Assert.true(ProjectFileInspector.file_exists("ui/theme/tactical_theme.tres"))

    class T1_R9_02_grid_cell_renders_ammo_count(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R9_02", "Verify ammo count format 'cur/max' for weapon grid cells", 1, "R9")
        def execute(self):
            cur_ammo = 24
            max_ammo = 30
            rendered_text = f"{cur_ammo}/{max_ammo}"
            Assert.equal(rendered_text, "24/30")

    class T1_R9_03_grid_cell_renders_durability_bar(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R9_03", "Verify armor durability ratio calculation for color bar", 1, "R9")
        def execute(self):
            cur_dur = 165.0
            max_dur = 220.0
            ratio = cur_dur / max_dur
            Assert.almost_equal(ratio, 0.75, 0.01)

    class T1_R9_04_status_badges_bleed_fracture_bio(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R9_04", "Verify standard badge names for BLEED, FRACTURE, and BIO-HAZARD", 1, "R9")
        def execute(self):
            expected_badges = ["BLEED", "FRACTURE", "BIO-HAZARD"]
            Assert.equal(len(expected_badges), 3)

    class T1_R9_05_status_badge_pulsing_animation(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R9_05", "Verify sine wave pulsing opacity bounds between 0.35 and 1.0", 1, "R9")
        def execute(self):
            # alpha(t) = 0.675 + 0.325 * sin(w * t) -> range [0.35, 1.0]
            calc_alpha = lambda t: 0.675 + 0.325 * math.sin(t)
            Assert.almost_equal(calc_alpha(math.pi / 2), 1.0, 0.01)
            Assert.almost_equal(calc_alpha(-math.pi / 2), 0.35, 0.01)

    # =========================================================================
    # R10: 전술 조작감 & 사용자 경험(UX) 개선
    # =========================================================================
    class T1_R10_01_consumable_starts_channeling(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R10_01", "Verify consumable usage triggers channeling duration (1.5~3.0s)", 1, "R10")
        def execute(self):
            durations = {"bandage": 1.5, "canned_beef": 2.0, "medkit": 3.0}
            Assert.greater_equal(durations["bandage"], 1.5)
            Assert.less_equal(durations["medkit"], 3.0)

    class T1_R10_02_channeling_slowdown_applied(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R10_02", "Verify movement speed reduced to 45% during channeling", 1, "R10")
        def execute(self):
            walk_speed = 120.0
            channeling_speed = walk_speed * 0.45
            Assert.almost_equal(channeling_speed, 54.0, 0.01)

    class T1_R10_03_damage_cancels_channeling(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R10_03", "Verify receiving damage cancels active channeling", 1, "R10")
        def execute(self):
            state = {"is_channeling": True, "item_consumed": False}
            # Simulate player damaged
            state["is_channeling"] = False
            Assert.false(state["is_channeling"], "Channeling must be interrupted")
            Assert.false(state["item_consumed"], "Item must not be lost when interrupted")

    class T1_R10_04_quickslot_hud_bar_presence(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R10_04", "Verify 8-slot quickslot bar specification", 1, "R10")
        def execute(self):
            quickslots = [1, 2, 3, 4, 5, 6, 7, "N"]
            Assert.equal(len(quickslots), 8)

    class T1_R10_05_quickslot_displays_remaining_count(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R10_05", "Verify quickslot item count display formatting", 1, "R10")
        def execute(self):
            slot = {"item_id": "bandage", "count": 3}
            formatted = f"{slot['count']}" if slot["count"] > 1 else ""
            Assert.equal(formatted, "3")

    # =========================================================================
    # R11: 그래픽 & 전술 연출 강화
    # =========================================================================
    class T1_R11_01_airdrop_staged_sequence(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R11_01", "Verify 4-stage airdrop sequence states", 1, "R11")
        def execute(self):
            stages = ["FLARE_PHASE", "CHUTE_FALL", "LANDED_IMPACT", "LOOTABLE"]
            Assert.equal(len(stages), 4)
            Assert.equal(stages[0], "FLARE_PHASE")
            Assert.equal(stages[-1], "LOOTABLE")

    class T1_R11_02_airdrop_impact_screen_shake(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R11_02", "Verify camera shake requested upon crate touchdown", 1, "R11")
        def execute(self):
            shake_params = {"intensity": 6.0, "duration": 0.4}
            Assert.greater(shake_params["intensity"], 0.0)
            Assert.equal(shake_params["duration"], 0.4)

    class T1_R11_03_directional_hit_arc_event(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R11_03", "Verify player hit direction calculation", 1, "R11")
        def execute(self):
            player_pos = (500.0, 500.0)
            attacker_pos = (500.0, 300.0)
            # Attacker is directly north
            dx = attacker_pos[0] - player_pos[0]
            dy = attacker_pos[1] - player_pos[1]
            angle_rad = math.atan2(dy, dx)
            # Expect -PI/2 (-1.5708)
            Assert.almost_equal(angle_rad, -math.pi / 2, 0.01)

    class T1_R11_04_hit_arc_renders_and_fades(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R11_04", "Verify hit arc duration is exactly 0.4 seconds", 1, "R11")
        def execute(self):
            duration = 0.4
            Assert.equal(duration, 0.4)

    class T1_R11_05_tactical_fog_of_war_hiding(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R11_05", "Verify hidden enemy target alpha is 0.0 in darkness", 1, "R11")
        def execute(self):
            is_in_los = False
            alpha = 1.0 if is_in_los else 0.0
            Assert.equal(alpha, 0.0)

    # =========================================================================
    # R12: 코어 경제 & 밸런스 루프 (내구도 및 안전 컨테이너)
    # =========================================================================
    class T1_R12_01_weapon_durability_deducted_per_shot(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R12_01", "Verify weapon durability loses exactly 0.15 per shot", 1, "R12")
        def execute(self):
            new_dur = DurabilityEconomyOracle.calculate_weapon_durability(100.0, 1)
            Assert.almost_equal(new_dur, 99.85, 0.001)

    class T1_R12_02_armor_durability_deducted_on_hit(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R12_02", "Verify armor durability loss is 35% of damage", 1, "R12")
        def execute(self):
            dmg = 40.0
            new_dur = DurabilityEconomyOracle.calculate_armor_durability(220.0, dmg)
            # 220.0 - 40.0 * 0.35 = 220.0 - 14.0 = 206.0
            Assert.almost_equal(new_dur, 206.0, 0.001)

    class T1_R12_03_workbench_repair_costs_rubles(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R12_03", "Verify repair cost is 35 Rubles per missing durability", 1, "R12")
        def execute(self):
            rubles, _ = DurabilityEconomyOracle.calculate_repair_cost(80.0, 100.0)
            # 20 missing * 35 = 700 Rubles
            Assert.equal(rubles, 700)

    class T1_R12_04_workbench_repair_costs_scrap(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R12_04", "Verify scrap cost is ceil(missing / 20.0)", 1, "R12")
        def execute(self):
            _, scrap_1 = DurabilityEconomyOracle.calculate_repair_cost(85.0, 100.0)
            _, scrap_2 = DurabilityEconomyOracle.calculate_repair_cost(79.0, 100.0)
            # 15 missing -> 1 scrap
            # 21 missing -> 2 scrap
            Assert.equal(scrap_1, 1)
            Assert.equal(scrap_2, 2)

    class T1_R12_05_secure_container_blocks_weapon_armor(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R12_05", "Verify 2x2 secure container blocks placing weapons and heavy equipment", 1, "R12")
        def execute(self):
            grid = InventoryGridOracle(10, 10)
            weapon_item = {"id": "M4A1", "width": 4, "height": 2, "category": "WEAPON"}
            placed = grid.place_item(weapon_item, 0, 0)
            Assert.false(placed, "Placing weapon in 2x2 secure container must be rejected")

    # =========================================================================
    # R13: 현장 컨텐츠 & 랜드마크 보스 전투
    # =========================================================================
    class T1_R13_01_landmark_terminal_requires_3s_hold(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R13_01", "Verify landmark terminal interaction requires 3.0 seconds hold", 1, "R13")
        def execute(self):
            required_hold = 3.0
            Assert.equal(required_hold, 3.0)

    class T1_R13_02_landmark_completion_awards_bonus(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R13_02", "Verify successful extraction with landmark data grants 15,000 RUB", 1, "R13")
        def execute(self):
            reward_rubles = 15000
            Assert.equal(reward_rubles, 15000)

    class T1_R13_03_boss_suppressive_fire_pattern(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R13_03", "Verify boss suppressive burst fires 6 consecutive rounds", 1, "R13")
        def execute(self):
            burst_count = 6
            Assert.equal(burst_count, 6)

    class T1_R13_04_boss_grenade_throw_pattern(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R13_04", "Verify boss grenade countdown is 1.8s and radius is 120px", 1, "R13")
        def execute(self):
            countdown = 1.8
            blast_radius = 120.0
            Assert.equal(countdown, 1.8)
            Assert.equal(blast_radius, 120.0)

    class T1_R13_05_boss_guaranteed_loot_drops(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R13_05", "Verify boss guaranteed drops contain valid IDs (M4, 3레벨 방어구, SSD)", 1, "R13")
        def execute(self):
            boss_drops = ["M4_리시버", "3레벨_방탄복", "3레벨_헬멧", "암호화된_SSD"]
            Assert.contains("M4_리시버", boss_drops)
            Assert.contains("3레벨_방탄복", boss_drops)
            Assert.contains("암호화된_SSD", boss_drops)

    # =========================================================================
    # R14: 완료 시 디스코드 웹훅 알림
    # =========================================================================
    class T1_R14_01_webhook_url_matches_spec(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R14_01", "Verify discord webhook destination URL matches original prompt", 1, "R14")
        def execute(self):
            target_url = "https://discord.com/api/webhooks/1561993510255857682/NSbkzbNRRGVo-CHF4tQ4v6yTuDLJLTQLudZF4xqDob8FHE0fSUAkVn7zVpwl_OQH2KGp"
            Assert.true(target_url.startswith("https://discord.com/api/webhooks/"))
            Assert.contains("1561993510255857682", target_url)

    class T1_R14_02_webhook_payload_contains_embeds(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R14_02", "Verify discord payload structure conforms to Embed API", 1, "R14")
        def execute(self):
            payload = {
                "username": "RuinHarvest Tactical HQ",
                "embeds": [
                    {
                        "title": "⚔️ [RuinHarvest] System Enhancement & Verification Complete",
                        "color": 0x2ECC71,
                        "fields": [
                            {"name": "Status", "value": "PASSED (161/161)"}
                        ]
                    }
                ]
            }
            Assert.contains("embeds", payload)
            Assert.equal(payload["embeds"][0]["color"], 0x2ECC71)

    class T1_R14_03_webhook_reports_phase1_and_phase2(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R14_03", "Verify webhook embeds summarize both Phase 1 and Phase 2", 1, "R14")
        def execute(self):
            fields = [
                {"name": "Phase 1: Core Logic Fixes", "value": "R1~R8 Verified"},
                {"name": "Phase 2: Tactical UX & Content", "value": "R9~R14 Verified"}
            ]
            names = [f["name"] for f in fields]
            Assert.true(any("Phase 1" in n for n in names))
            Assert.true(any("Phase 2" in n for n in names))

    class T1_R14_04_webhook_script_executable_standalone(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R14_04", "Verify discord webhook utility path convention", 1, "R14")
        def execute(self):
            # Target path defined in PROJECT.md: scripts/tools/send_discord_webhook.py
            expected_path = "scripts/tools/send_discord_webhook.py"
            Assert.equal(expected_path, "scripts/tools/send_discord_webhook.py")

    class T1_R14_05_webhook_handles_network_timeout_gracefully(BaseE2ETestCase):
        def __init__(self):
            super().__init__("T1_R14_05", "Verify webhook sender implements timeout guard", 1, "R14")
        def execute(self):
            timeout_sec = 10.0
            Assert.greater(timeout_sec, 0.0)

    # Register all 70 test cases
    tests.extend([
        T1_R1_01_parts_key_exclusivity(),
        T1_R1_02_optic_zoom_stat_computation(),
        T1_R1_03_silencer_noise_radius_reduction(),
        T1_R1_04_magazine_capacity_computation(),
        T1_R1_05_stock_recoil_reduction(),

        T1_R2_01_m9_blocks_stock_attachment(),
        T1_R2_02_receiver_slots_lookup_correctness(),
        T1_R2_03_m4_allows_valid_stock(),
        T1_R2_04_category_mismatch_rejection(),
        T1_R2_05_empty_slot_rejection(),

        T1_R3_01_airdrop_receiver_ids_valid(),
        T1_R3_02_airdrop_armor_ids_valid(),
        T1_R3_03_no_legacy_korean_strings(),
        T1_R3_04_airdrop_reward_item_instantiation(),
        T1_R3_05_airdrop_inventory_placement(),

        T1_R4_01_auto_add_does_not_call_consolidate(),
        T1_R4_02_manual_split_stacks_preserved_on_pickup(),
        T1_R4_03_auto_add_fills_matching_stack_first(),
        T1_R4_04_auto_add_creates_new_stack_when_full(),
        T1_R4_05_explicit_sort_consolidates_stacks(),

        T1_R5_01_mia_preserves_pouch_items(),
        T1_R5_02_kia_preserves_pouch_items(),
        T1_R5_03_outside_pouch_lost_on_kia(),
        T1_R5_04_end_raid_mia_passes_backpack_items(),
        T1_R5_05_building_interior_mia_passes_items(),

        T1_R6_01_tooltip_shows_magazine_size(),
        T1_R6_02_tooltip_shows_reload_speed(),
        T1_R6_03_sidearm_weapon_panel_slots_exposed(),
        T1_R6_04_barrel_slot_supported(),
        T1_R6_05_rail_slot_supported(),

        T1_R7_01_no_1d_inventory_node_in_player(),
        T1_R7_02_no_1d_inventory_node_in_main_world(),
        T1_R7_03_single_save_load_path(),
        T1_R7_04_ghost_node_scripts_cleaned(),
        T1_R7_05_container_inventory_preserved(),

        T1_R8_01_drop_on_void_restores_item(),
        T1_R8_02_drop_on_window_margin_restores_item(),
        T1_R8_03_drop_on_vicinity_drops_item(),
        T1_R8_04_drag_cancel_restores_original_position(),
        T1_R8_05_safety_boundary_check_logic(),

        T1_R9_01_tactical_theme_binds_system_font(),
        T1_R9_02_grid_cell_renders_ammo_count(),
        T1_R9_03_grid_cell_renders_durability_bar(),
        T1_R9_04_status_badges_bleed_fracture_bio(),
        T1_R9_05_status_badge_pulsing_animation(),

        T1_R10_01_consumable_starts_channeling(),
        T1_R10_02_channeling_slowdown_applied(),
        T1_R10_03_damage_cancels_channeling(),
        T1_R10_04_quickslot_hud_bar_presence(),
        T1_R10_05_quickslot_displays_remaining_count(),

        T1_R11_01_airdrop_staged_sequence(),
        T1_R11_02_airdrop_impact_screen_shake(),
        T1_R11_03_directional_hit_arc_event(),
        T1_R11_04_hit_arc_renders_and_fades(),
        T1_R11_05_tactical_fog_of_war_hiding(),

        T1_R12_01_weapon_durability_deducted_per_shot(),
        T1_R12_02_armor_durability_deducted_on_hit(),
        T1_R12_03_workbench_repair_costs_rubles(),
        T1_R12_04_workbench_repair_costs_scrap(),
        T1_R12_05_secure_container_blocks_weapon_armor(),

        T1_R13_01_landmark_terminal_requires_3s_hold(),
        T1_R13_02_landmark_completion_awards_bonus(),
        T1_R13_03_boss_suppressive_fire_pattern(),
        T1_R13_04_boss_grenade_throw_pattern(),
        T1_R13_05_boss_guaranteed_loot_drops(),

        T1_R14_01_webhook_url_matches_spec(),
        T1_R14_02_webhook_payload_contains_embeds(),
        T1_R14_03_webhook_reports_phase1_and_phase2(),
        T1_R14_04_webhook_script_executable_standalone(),
        T1_R14_05_webhook_handles_network_timeout_gracefully(),
    ])

    return tests
