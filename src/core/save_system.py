"""
save_system.py - 세이브/로드 시스템
"""
import json
import os
import time
import random
from settings import (Colors, CHUNK_SIZE, DIFFICULTY_PRESETS, DEFAULT_WORLD_SETTINGS)
from camera import Camera
from world import World, WorldObject, Building
from player import Player
from entities import EntityManager, Enemy, NPC
from combat import CombatSystem
from weather import TimeSystem, WeatherSystem
from particles import ParticleSystem
from building_interior import BuildingInterior
from events import EventSystem

SAVE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "saves")


def ensure_save_dir():
    os.makedirs(SAVE_DIR, exist_ok=True)


def get_save_files():
    """저장 파일 목록"""
    ensure_save_dir()
    saves = []
    for f in os.listdir(SAVE_DIR):
        if f.endswith(".json"):
            path = os.path.join(SAVE_DIR, f)
            try:
                with open(path, 'r', encoding='utf-8') as fp:
                    data = json.load(fp)
                # player.rubles에서 자금 추출
                rubles = 0
                player_data = data.get("player", {})
                if isinstance(player_data, dict):
                    rubles = player_data.get("rubles", 0)
                saves.append({
                    "filename": f,
                    "path": path,
                    "world_name": data.get("world_name", "알 수 없음"),
                    "day": data.get("current_day", 0),
                    "difficulty": data.get("difficulty", "보통"),
                    "save_time": data.get("save_time", ""),
                    "created_at": data.get("created_at", ""),
                    "playtime": data.get("playtime", 0),
                    "funds": rubles,
                })
            except Exception:
                continue
    saves.sort(key=lambda x: x.get("save_time", ""), reverse=True)
    return saves


def save_game(game_state, slot_name="autosave"):
    """게임 저장"""
    ensure_save_dir()
    filename = f"{slot_name}.json"
    path = os.path.join(SAVE_DIR, filename)
    tmp_path = path + ".tmp"

    game_state["save_time"] = time.strftime("%Y-%m-%d %H:%M:%S")

    # created_at은 최초 저장 시에만 기록
    if not game_state.get("created_at"):
        # 기존 파일에서 created_at 유지 시도
        if os.path.exists(path):
            try:
                with open(path, 'r', encoding='utf-8') as f:
                    old = json.load(f)
                game_state["created_at"] = old.get("created_at", game_state["save_time"])
            except Exception:
                game_state["created_at"] = game_state["save_time"]
        else:
            game_state["created_at"] = game_state["save_time"]

    try:
        # 1. 임시 파일에 쓰기
        with open(tmp_path, 'w', encoding='utf-8') as f:
            json.dump(game_state, f, ensure_ascii=False, indent=2)
            # 2. 강제 동기화 (OS 캐시 문제 방어)
            f.flush()
            os.fsync(f.fileno())
            
        # 3. 원자적으로 원본 덮어쓰기
        os.replace(tmp_path, path)
        return True
    except Exception as e:
        print(f"저장 실패: {e}")
        # 실패 시 잔여 임시파일 정리 시도
        if os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except:
                pass
        return False


def load_game(slot_name="autosave"):
    """게임 로드"""
    ensure_save_dir()
    filename = f"{slot_name}.json"
    path = os.path.join(SAVE_DIR, filename)

    try:
        with open(path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        print(f"로드 실패: {e}")
        return None


def delete_save(slot_name):
    """세이브 삭제"""
    ensure_save_dir()
    filename = f"{slot_name}.json"
    path = os.path.join(SAVE_DIR, filename)
    try:
        if os.path.exists(path):
            os.remove(path)
            return True
    except Exception:
        pass
    return False


def rename_save(old_slot_name, new_name):
    """세이브 파일 이름 변경 (파일명 + 내부 world_name)"""
    ensure_save_dir()
    old_filename = f"{old_slot_name}.json"
    old_path = os.path.join(SAVE_DIR, old_filename)
    if not os.path.exists(old_path):
        return False

    new_slot_name = new_name.replace(" ", "_")
    new_filename = f"{new_slot_name}.json"
    new_path = os.path.join(SAVE_DIR, new_filename)

    # 같은 이름이면 내부 world_name만 갱신
    try:
        with open(old_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        data["world_name"] = new_name
        if "world_settings" in data and isinstance(data["world_settings"], dict):
            data["world_settings"]["world_name"] = new_name

        if old_path == new_path:
            with open(old_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            return True

        # 대상 파일이 이미 존재하면 실패
        if os.path.exists(new_path):
            return False

        with open(new_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        os.remove(old_path)
        return True
    except Exception:
        return False


class GameSaveManager:
    """게임 인스턴스의 모든 상태를 직렬화하고 복구하는 총괄 매니저"""

    @staticmethod
    def serialize_game(game):
        """게임의 모든 상태를 딕셔너리로 직렬화 (RuinHarvest 세션 기반 저장)"""
        if not game.player:
            return None

        # 1. 맵 델타 추출
        world_deltas = []
        if game.world:
            # 활성화된 청크들의 델타 추출
            for (cx, cy), chunk in game.world.chunks.items():
                delta = game.world._extract_delta(chunk)
                if delta:
                    delta["cx"] = cx
                    delta["cy"] = cy
                    world_deltas.append(delta)
            # 언로드 대기 중인 델타 병합
            for (cx, cy), delta in game.world.unloaded_deltas.items():
                delta_copy = dict(delta)
                delta_copy["cx"] = cx
                delta_copy["cy"] = cy
                world_deltas.append(delta_copy)

        # 2. 엔티티 데이터 추출 (야외 및 건물 내부 적/NPC)
        enemies_data = []
        npcs_data = []
        if game.entity_manager:
            for e in game.entity_manager.enemies:
                enemies_data.append(e.to_dict())
            for n in game.entity_manager.npcs:
                npcs_data.append(n.to_dict())

        # 건물 내부 적 저장
        if hasattr(game, 'interior_enemies') and game.interior_enemies:
            for e in game.interior_enemies:
                e_dict = e.to_dict()
                e_dict["is_interior"] = True
                enemies_data.append(e_dict)

        # 3. 건물 내부 델타 추출
        interior_deltas = {}
        if hasattr(game, 'explored_interiors') and game.explored_interiors:
            for bid, interior in game.explored_interiors.items():
                interior_deltas[bid] = interior.to_dict()

        # 건물 내부 식별 정보 저장
        current_interior_bid = None
        interior_floor_idx = 0
        if game.current_interior and game.interior_building_ref:
            current_interior_bid = f"{game.interior_building_ref.x}_{game.interior_building_ref.y}"
            interior_floor_idx = game.current_interior.floor_idx

        return {
            "world_settings": game.world_settings,
            "player": game.player.to_dict(),
            "current_interior_bid": current_interior_bid,
            "interior_floor_idx": interior_floor_idx,
            "current_day": game.current_day,
            "current_hour": game.time_system.current_hour,
            "playtime": game.playtime,
            "world_name": game.world_settings.get("world_name", "월드 1"),
            "difficulty": game.world_settings.get("difficulty", "보통"),
            "world_deltas": world_deltas,
            "entities": {"enemies": enemies_data, "npcs": npcs_data},
            "interior_deltas": interior_deltas,
        }

    @staticmethod
    def deserialize_game(game, data):
        """딕셔너리 데이터를 기반으로 게임 인스턴스 복구"""
        if not data:
            return False

        game.world_settings = data.get("world_settings", DEFAULT_WORLD_SETTINGS)
        diff_name = game.world_settings.get("difficulty", "보통")
        game.difficulty = DIFFICULTY_PRESETS.get(diff_name, DIFFICULTY_PRESETS["보통"])
        game.total_days = game.world_settings.get("total_days", 30)

        # 월드 및 카메라 로드
        is_raid_state = data.get("player", {}).get("raid_status", "NONE") == "IN_RAID"
        game.sandbox_mode = game.world_settings.get("sandbox", False)
        game.world = World(seed=game.world_settings.get("seed"), world_settings=game.world_settings, is_raid=is_raid_state)
        game.player = Player.from_dict(data.get("player", {}), game.difficulty)
        game.player.inventory.is_sandbox = game.sandbox_mode

        game.camera = Camera()
        game.camera.resize(game.screen_w, game.screen_h)
        game.entity_manager = EntityManager(game.difficulty)
        
        # 시스템 복원
        day_len = game.world_settings.get("day_length_minutes", 12)
        game.time_system = TimeSystem(day_len)
        game.time_system.current_day = data.get("current_day", 1)
        game.time_system.current_hour = data.get("current_hour", 8.0)
        
        weather_var = game.world_settings.get("weather_variability", 1.0)
        game.weather_system = WeatherSystem(weather_var)
        game.event_system = EventSystem(game.difficulty)
        game.combat_system = CombatSystem()
        game.game_particles = ParticleSystem()

        game.current_day = data.get("current_day", 1)
        game.last_day = game.current_day
        game.playtime = data.get("playtime", 0)

        # 월드 상태 델타 복구 (lazy: unloaded_deltas에 보존, 접근 시 적용)
        world_deltas = data.get("world_deltas", [])
        px = game.player.x
        py = game.player.y
        pcx = int(px) // CHUNK_SIZE
        pcy = int(py) // CHUNK_SIZE

        for delta in world_deltas:
            cx, cy = delta["cx"], delta["cy"]
            compact_delta = {}
            if delta.get("objects"):
                compact_delta["objects"] = delta["objects"]
            if delta.get("buildings"):
                compact_delta["buildings"] = delta["buildings"]
            if delta.get("items"):
                compact_delta["items"] = delta["items"]
            if not compact_delta:
                continue

            # 플레이어 근처 청크만 즉시 로드, 나머지는 lazy
            if abs(cx - pcx) <= 5 and abs(cy - pcy) <= 5:
                chunk = game.world.get_chunk(cx, cy)
                game.world._apply_delta(chunk, compact_delta)
            else:
                game.world.unloaded_deltas[(cx, cy)] = compact_delta

        # 엔티티 복구
        entities_data = data.get("entities", {})
        game.entity_manager.enemies = []
        game.interior_enemies = []
        loaded_interior_enemy_count = 0
        for edict in entities_data.get("enemies", []):
            e = Enemy.from_dict(edict)
            if edict.get("is_interior", False):
                game.interior_enemies.append(e)
                loaded_interior_enemy_count += 1
            else:
                game.entity_manager.enemies.append(e)
            
        game.entity_manager.npcs = []
        for ndict in entities_data.get("npcs", []):
            game.entity_manager.npcs.append(NPC.from_dict(ndict))

        # 건물 내부 델타 복구
        game.explored_interiors = {}
        interior_deltas = data.get("interior_deltas", {})
        for bid, idata in interior_deltas.items():
            ext_w = idata.get("width", 8) // 2
            ext_h = idata.get("height", 8) // 2
            game.explored_interiors[bid] = BuildingInterior.from_dict(idata, ext_w, ext_h)

        # 건물 내부 복구
        current_interior_bid = data.get("current_interior_bid")
        interior_floor_idx = data.get("interior_floor_idx", 0)
        if current_interior_bid:
            bx_str, by_str = current_interior_bid.split("_")
            bx, by = int(bx_str), int(by_str)
            
            target_building = None
            cx, cy = bx // CHUNK_SIZE, by // CHUNK_SIZE
            chunk = game.world.get_chunk(cx, cy)
            for b in chunk.buildings:
                if b.x == bx and b.y == by:
                    target_building = b
                    break
                    
            if target_building:
                game.interior_building_ref = target_building
                bid = f"{bx}_{by}" if interior_floor_idx == 0 else f"{bx}_{by}_floor_{interior_floor_idx}"
                if bid in game.explored_interiors:
                    game.current_interior = game.explored_interiors[bid]
                else:
                    import zlib
                    max_floors = 2 if getattr(target_building, "building_type", "house") != "barn" else 1
                    game.current_interior = BuildingInterior(
                        target_building.building_type,
                        target_building.width, target_building.height,
                        seed=zlib.crc32(bid.encode('utf-8')) + (game.world.seed if game.world else 0),
                        floor_idx=interior_floor_idx,
                        max_floors=max_floors
                    )
                    game.explored_interiors[bid] = game.current_interior
                
                if loaded_interior_enemy_count == 0 and not game.interior_enemies:
                    game.interior_enemies = []
                    for edata in game.current_interior.enemies:
                        e_type = edata.get("type", "normal")
                        e = Enemy(edata["x"], edata["y"], e_type, game.difficulty)
                        e.speed *= 0.5
                        e.detection_range = 3
                        if "hp" in edata:
                            e.hp = edata["hp"]
                        game.interior_enemies.append(e)
                    
                game.interior_camera = Camera()
                game.interior_camera.resize(game.screen_w, game.screen_h)

        return True
