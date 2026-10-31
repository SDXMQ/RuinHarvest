"""
tests/e2e/framework.py
RuinHarvest E2E Testing Framework & Requirement Oracles
Provides base test execution, assertions, project inspectors, and specification domain oracles.
"""

import os
import sys
import re
import json
import math
import copy
import time
from typing import Dict, List, Any, Optional, Tuple, Callable

# Project root directory detection
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

class TestFailure(Exception):
    """Raised when an assertion fails in a test case."""
    pass

class TestResult:
    def __init__(self, test_id: str, name: str, tier: int, feature: str):
        self.test_id = test_id
        self.name = name
        self.tier = tier
        self.feature = feature
        self.passed = False
        self.skipped = False
        self.error_message: Optional[str] = None
        self.duration_ms: float = 0.0

    def mark_pass(self, duration_ms: float):
        self.passed = True
        self.duration_ms = duration_ms

    def mark_fail(self, error: str, duration_ms: float):
        self.passed = False
        self.error_message = error
        self.duration_ms = duration_ms

    def mark_skip(self, reason: str):
        self.skipped = True
        self.error_message = reason

class Assert:
    @staticmethod
    def true(condition: bool, msg: str = "Condition expected to be True"):
        if not condition:
            raise TestFailure(msg)

    @staticmethod
    def false(condition: bool, msg: str = "Condition expected to be False"):
        if condition:
            raise TestFailure(msg)

    @staticmethod
    def equal(actual: Any, expected: Any, msg: Optional[str] = None):
        if actual != expected:
            default_msg = f"Expected {expected!r}, but got {actual!r}"
            raise TestFailure(f"{msg}: {default_msg}" if msg else default_msg)

    @staticmethod
    def not_equal(actual: Any, expected: Any, msg: Optional[str] = None):
        if actual == expected:
            default_msg = f"Expected value not to equal {expected!r}"
            raise TestFailure(f"{msg}: {default_msg}" if msg else default_msg)

    @staticmethod
    def almost_equal(actual: float, expected: float, delta: float = 0.001, msg: Optional[str] = None):
        if abs(actual - expected) > delta:
            default_msg = f"Expected {expected} (+/- {delta}), but got {actual}"
            raise TestFailure(f"{msg}: {default_msg}" if msg else default_msg)

    @staticmethod
    def contains(item: Any, container: Any, msg: Optional[str] = None):
        if item not in container:
            default_msg = f"Expected {item!r} to be in {container!r}"
            raise TestFailure(f"{msg}: {default_msg}" if msg else default_msg)

    @staticmethod
    def not_contains(item: Any, container: Any, msg: Optional[str] = None):
        if item in container:
            default_msg = f"Expected {item!r} NOT to be in {container!r}"
            raise TestFailure(f"{msg}: {default_msg}" if msg else default_msg)

    @staticmethod
    def is_none(val: Any, msg: Optional[str] = None):
        if val is not None:
            raise TestFailure(msg or f"Expected None, but got {val!r}")

    @staticmethod
    def is_not_none(val: Any, msg: Optional[str] = None):
        if val is None:
            raise TestFailure(msg or "Expected not None, but got None")

    @staticmethod
    def greater(a: Any, b: Any, msg: Optional[str] = None):
        if not (a > b):
            raise TestFailure(msg or f"Expected {a!r} > {b!r}")

    @staticmethod
    def greater_equal(a: Any, b: Any, msg: Optional[str] = None):
        if not (a >= b):
            raise TestFailure(msg or f"Expected {a!r} >= {b!r}")

    @staticmethod
    def less(a: Any, b: Any, msg: Optional[str] = None):
        if not (a < b):
            raise TestFailure(msg or f"Expected {a!r} < {b!r}")

    @staticmethod
    def less_equal(a: Any, b: Any, msg: Optional[str] = None):
        if not (a <= b):
            raise TestFailure(msg or f"Expected {a!r} <= {b!r}")


# =========================================================================
# Project Source Code and Resource Inspector
# =========================================================================
class ProjectFileInspector:
    """Provides file reading, pattern matching, and AST-like parsing for Godot project files."""
    
    @staticmethod
    def get_absolute_path(rel_path: str) -> str:
        return os.path.normpath(os.path.join(PROJECT_ROOT, rel_path))

    @staticmethod
    def file_exists(rel_path: str) -> bool:
        return os.path.exists(ProjectFileInspector.get_absolute_path(rel_path))

    @staticmethod
    def read_file(rel_path: str) -> str:
        path = ProjectFileInspector.get_absolute_path(rel_path)
        if not os.path.exists(path):
            raise FileNotFoundError(f"Project file not found: {rel_path} (resolved {path})")
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            return f.read()

    @staticmethod
    def contains_pattern(rel_path: str, regex_pattern: str) -> bool:
        content = ProjectFileInspector.read_file(rel_path)
        return bool(re.search(regex_pattern, content))

    @staticmethod
    def find_all_matches(rel_path: str, regex_pattern: str) -> List[str]:
        content = ProjectFileInspector.read_file(rel_path)
        return re.findall(regex_pattern, content)


# =========================================================================
# Domain Oracles (Authoritative Business Logic & Specifications)
# =========================================================================
class WeaponModdingOracle:
    """Authoritative oracle for WeaponPartsDatabase calculation and parts unification."""
    
    # Official Receiver definitions as specified in systems/weapon_parts_database.gd
    RECEIVERS: Dict[str, Dict[str, Any]] = {
        "M4_리시버": {
            "name": "M4A1 어퍼/로워 리시버",
            "category": "rifle",
            "base_stats": {
                "base_damage": 32.0,
                "fire_rate": 0.08,
                "bullet_speed": 1100.0,
                "noise_radius": 380.0,
                "camera_shake": 2.2,
                "recoil_scale": 1.0,
                "recoil_recovery": 7.0,
                "spread_angle": 2.5,
                "magazine_size": 30,
                "reload_time": 2.4,
                "weight": 2.9,
                "zoom_level": 1.0
            },
            "slots": {
                "barrel": "m4_standard_barrel",
                "optic": "iron_sight",
                "muzzle": "none",
                "grip": "none",
                "magazine": "m4_30rnd_mag",
                "stock": "m4_standard_stock",
                "rail": []
            }
        },
        "AK_리시버": {
            "name": "AK-74M 리시버",
            "category": "rifle",
            "base_stats": {
                "base_damage": 37.0,
                "fire_rate": 0.095,
                "bullet_speed": 1000.0,
                "noise_radius": 400.0,
                "camera_shake": 2.6,
                "recoil_scale": 1.25,
                "recoil_recovery": 6.0,
                "spread_angle": 3.0,
                "magazine_size": 30,
                "reload_time": 2.6,
                "weight": 3.4,
                "zoom_level": 1.0
            },
            "slots": {
                "barrel": "ak_standard_barrel",
                "optic": "iron_sight",
                "muzzle": "none",
                "grip": "none",
                "magazine": "ak_30rnd_mag",
                "stock": "ak_standard_stock",
                "rail": []
            }
        },
        "M9_리시버": {
            "name": "M9A3 슬라이드/프레임",
            "category": "pistol",
            "base_stats": {
                "base_damage": 26.0,
                "fire_rate": 0.18,
                "bullet_speed": 750.0,
                "noise_radius": 280.0,
                "camera_shake": 1.4,
                "recoil_scale": 0.8,
                "recoil_recovery": 9.0,
                "spread_angle": 3.2,
                "magazine_size": 15,
                "reload_time": 1.6,
                "weight": 1.1,
                "zoom_level": 1.0
            },
            "slots": {
                "barrel": "m9_standard_barrel",
                "optic": "none",
                "muzzle": "none",
                "grip": "none",
                "magazine": "m9_standard_mag",
                "rail": []
                # NOTE: Specifically NO "stock" slot!
            }
        },
        "SV98_리시버": {
            "name": "SV-98 볼트액션 리시버",
            "category": "sniper",
            "base_stats": {
                "base_damage": 115.0,
                "fire_rate": 0.9,
                "bullet_speed": 1400.0,
                "noise_radius": 600.0,
                "camera_shake": 5.0,
                "recoil_scale": 2.5,
                "recoil_recovery": 3.0,
                "spread_angle": 0.2,
                "magazine_size": 10,
                "reload_time": 3.2,
                "weight": 5.8,
                "zoom_level": 1.0
            },
            "slots": {
                "barrel": "sv98_match_barrel",
                "optic": "sv98_iron_sight",
                "muzzle": "none",
                "grip": "none",
                "magazine": "sv98_10rnd_mag",
                "stock": "sv98_wooden_stock",
                "rail": []
            }
        }
    }

    PARTS: Dict[str, Dict[str, Any]] = {
        "acog_scope": {
            "name": "ACOG 4x 스코프",
            "type": "optic",
            "stat_modifiers": {"zoom_level": 1.6, "spread_angle": -0.5, "weight": 0.45},
            "compatible_categories": ["rifle", "sniper", "dmr"]
        },
        "m4_silencer": {
            "name": "소음기 (5.56 NATO)",
            "type": "muzzle",
            "stat_modifiers": {"noise_radius": -230.0, "recoil_scale": -0.1, "bullet_speed": -50.0, "weight": 0.4},
            "compatible_categories": ["rifle"]
        },
        "m4_60rnd_drum": {
            "name": "60발 드럼 탄창 (5.56 NATO)",
            "type": "magazine",
            "stat_modifiers": {"magazine_size": 30, "reload_time": 0.8, "weight": 0.9},
            "compatible_categories": ["rifle"]
        },
        "magpul_prs_stock": {
            "name": "정밀 개머리판 (PRS)",
            "type": "stock",
            "stat_modifiers": {"recoil_scale": -0.35, "recoil_recovery": 2.0, "weight": 0.65},
            "compatible_categories": ["rifle", "sniper"]
        },
        "pistol_red_dot": {
            "name": "권총용 미니 도트",
            "type": "optic",
            "stat_modifiers": {"zoom_level": 1.15, "spread_angle": -0.3, "weight": 0.08},
            "compatible_categories": ["pistol", "all"]
        },
        "folding_stock": {
            "name": "경량 접이식 스톡",
            "type": "stock",
            "stat_modifiers": {"recoil_scale": -0.2, "weight": 0.3},
            "compatible_categories": ["rifle", "smg"]
        }
    }

    @classmethod
    def compute_weapon_stats(cls, receiver_id: str, parts: Dict[str, str]) -> Dict[str, Any]:
        """Calculates final weapon stats given receiver and parts dictionary."""
        rec = cls.RECEIVERS.get(receiver_id)
        if not rec:
            raise ValueError(f"Unknown receiver: {receiver_id}")
        
        stats = copy.deepcopy(rec["base_stats"])
        
        for slot, part_id in parts.items():
            if not part_id or part_id == "none":
                continue
            part = cls.PARTS.get(part_id)
            if not part:
                continue
            modifiers = part.get("stat_modifiers", {})
            for stat_name, mod_val in modifiers.items():
                if stat_name in stats:
                    stats[stat_name] += mod_val

        # Clamping logic
        stats["recoil_scale"] = max(0.1, stats["recoil_scale"])
        stats["spread_angle"] = max(0.05, stats["spread_angle"])
        stats["noise_radius"] = max(50.0, stats["noise_radius"])
        stats["zoom_level"] = max(1.0, stats["zoom_level"])
        return stats


class ReceiverCompatibilityOracle:
    """Authoritative slot and category compatibility validator."""
    
    @classmethod
    def can_equip_part(cls, receiver_id: str, slot: str, part_id: str) -> Tuple[bool, str]:
        rec = WeaponModdingOracle.RECEIVERS.get(receiver_id)
        if not rec:
            return False, f"Unknown receiver {receiver_id}"
        
        # Check slot existence in receiver
        allowed_slots = rec.get("slots", {})
        if slot not in allowed_slots:
            return False, f"Receiver {receiver_id} does not have slot '{slot}'"
        
        part = WeaponModdingOracle.PARTS.get(part_id)
        if not part:
            return False, f"Unknown part {part_id}"
        
        if part.get("type") != slot:
            return False, f"Part type '{part.get('type')}' does not match slot '{slot}'"
        
        rec_cat = rec.get("category", "")
        comp_cats = part.get("compatible_categories", ["all"])
        if "all" not in comp_cats and rec_cat not in comp_cats:
            return False, f"Part category incompatible with receiver '{rec_cat}'"
        
        return True, "Compatible"


class InventoryGridOracle:
    """Simulates 2D Grid, Item Stacking, Manual Split, and 2x2 Pouch persistence."""
    
    POUCH_W = 2
    POUCH_H = 2

    def __init__(self, width: int = 10, height: int = 15):
        self.width = width
        self.height = height
        self.items: List[Dict[str, Any]] = []

    def place_item(self, item: Dict[str, Any], x: int, y: int) -> bool:
        w = item.get("width", 1)
        h = item.get("height", 1)
        if x < 0 or y < 0 or x + w > self.width or y + h > self.height:
            return False
        
        # Check secure container restriction (R12)
        if self.overlaps_secure_container(x, y, w, h):
            cat = item.get("category", "")
            if cat in ["WEAPON", "EQUIPMENT", "weapon", "equipment"]:
                return False  # Block weapon / heavy armor in 2x2 pouch
        
        # Check overlap
        for existing in self.items:
            ex = existing["x"]
            ey = existing["y"]
            ew = existing.get("width", 1)
            eh = existing.get("height", 1)
            if not (x + w <= ex or x >= ex + ew or y + h <= ey or y >= ey + eh):
                return False
        
        placed = copy.deepcopy(item)
        placed["x"] = x
        placed["y"] = y
        self.items.append(placed)
        return True

    def overlaps_secure_container(self, x: int, y: int, w: int, h: int) -> bool:
        return (x < self.POUCH_W and y < self.POUCH_H)

    def is_fully_inside_secure_container(self, x: int, y: int, w: int, h: int) -> bool:
        return (x >= 0 and y >= 0 and x + w <= self.POUCH_W and y + h <= self.POUCH_H)

    def auto_add_item(self, item_id: str, amount: int, max_stack: int = 60) -> int:
        """
        R4 specification:
        Only add to matching stacks or new slots.
        NEVER unconditionally consolidate ALL stacks in the grid.
        Returns remaining amount.
        """
        remaining = amount
        # 1. Fill existing stack of same item_id that has room
        for item in self.items:
            if item.get("id") == item_id and item.get("count", 1) < max_stack:
                room = max_stack - item.get("count", 1)
                added = min(remaining, room)
                item["count"] += added
                remaining -= added
                if remaining == 0:
                    return 0
        
        # 2. Place remaining into first available empty slot
        while remaining > 0:
            batch = min(remaining, max_stack)
            placed = False
            for y in range(self.height):
                for x in range(self.width):
                    temp_item = {"id": item_id, "count": batch, "width": 1, "height": 1, "category": "AMMO"}
                    if self.place_item(temp_item, x, y):
                        remaining -= batch
                        placed = True
                        break
                if placed:
                    break
            if not placed:
                break
        return remaining

    def filter_pouch_items_for_mia_kia(self) -> List[Dict[str, Any]]:
        """Extracts items fully within the 2x2 pouch zone."""
        pouch = []
        for it in self.items:
            x = it["x"]
            y = it["y"]
            w = it.get("width", 1)
            h = it.get("height", 1)
            if self.is_fully_inside_secure_container(x, y, w, h):
                pouch.append(copy.deepcopy(it))
        return pouch


class DurabilityEconomyOracle:
    """Authoritative formulas for Durability deduction and Hideout Repair."""
    
    WEAPON_DURABILITY_LOSS_PER_SHOT = 0.15
    ARMOR_DURABILITY_LOSS_RATIO = 0.35
    RUBLES_PER_MISSING_DURABILITY = 35
    SCRAP_PER_MISSING_DURABILITY_CHUNK = 20.0

    @classmethod
    def calculate_weapon_durability(cls, current_dur: float, shots_fired: int) -> float:
        deducted = current_dur - (shots_fired * cls.WEAPON_DURABILITY_LOSS_PER_SHOT)
        return max(0.0, round(deducted, 4))

    @classmethod
    def calculate_armor_durability(cls, current_dur: float, damage_taken: float) -> float:
        deducted = current_dur - (damage_taken * cls.ARMOR_DURABILITY_LOSS_RATIO)
        return max(0.0, round(deducted, 4))

    @classmethod
    def calculate_repair_cost(cls, current_dur: float, max_dur: float = 100.0) -> Tuple[int, int]:
        missing = max(0.0, max_dur - current_dur)
        rubles = int(round(missing * cls.RUBLES_PER_MISSING_DURABILITY))
        scrap = int(math.ceil(missing / cls.SCRAP_PER_MISSING_DURABILITY_CHUNK))
        return rubles, scrap


class BaseE2ETestCase:
    """Base class for all RuinHarvest E2E test cases."""
    
    def __init__(self, test_id: str, name: str, tier: int, feature: str):
        self.test_id = test_id
        self.name = name
        self.tier = tier
        self.feature = feature

    def run(self) -> TestResult:
        result = TestResult(self.test_id, self.name, self.tier, self.feature)
        t0 = time.perf_counter()
        try:
            self.setup()
            self.execute()
            self.teardown()
            elapsed_ms = (time.perf_counter() - t0) * 1000.0
            result.mark_pass(elapsed_ms)
        except TestFailure as e:
            elapsed_ms = (time.perf_counter() - t0) * 1000.0
            result.mark_fail(str(e), elapsed_ms)
        except Exception as e:
            elapsed_ms = (time.perf_counter() - t0) * 1000.0
            result.mark_fail(f"Unhandled Exception: {type(e).__name__}: {str(e)}", elapsed_ms)
        return result

    def setup(self):
        pass

    def execute(self):
        raise NotImplementedError("Subclasses must implement execute()")

    def teardown(self):
        pass
