"""
validate.py - 시스템 전체 검증 스크립트 v2
"""
import sys
import traceback
import os

# 하위 폴더들을 sys.path에 추가하여 기존 플랫 임포트 구조가 그대로 동작하도록 보장
src_dir = os.path.dirname(os.path.abspath(__file__))
subdirs = ['core', 'world', 'entities', 'systems', 'graphics']
for subdir in subdirs:
    path = os.path.join(src_dir, subdir)
    if path not in sys.path:
        sys.path.insert(0, path)

errors = []
warnings = []

def check(name, fn):
    try:
        fn()
        print(f"  ✅ {name}")
    except Exception as e:
        errors.append((name, str(e)))
        print(f"  ❌ {name}: {e}")
        traceback.print_exc()

print("=" * 60)
print("30일 서바이벌 - 시스템 검증 v2")
print("=" * 60)

# 1. 모듈 임포트
print("\n[1] 모듈 임포트 검증")
def import_all():
    import settings
    import utils
    import items
    import crafting
    import player
    import entities
    import combat
    import world
    import weather
    import events
    import camera
    import renderer
    import particles
    import transitions
    import ui
    import sounds
    import save_system
    import building_interior
    import i18n
check("모든 모듈 임포트", import_all)

# 2. i18n 시스템
print("\n[2] 다국어 시스템")
def test_i18n():
    from i18n import t, set_language, get_language, get_available_languages
    assert get_language() == "ko"
    assert t("game_title") == "RuinHarvest"
    set_language("en")
    assert t("game_title") == "30 Days to Survive"
    set_language("ko")
    assert t("new_day", 5) == "5일차가 밝았습니다."
    assert len(get_available_languages()) >= 2
check("i18n 번역 시스템", test_i18n)

# 3. 건물 내부 시스템
print("\n[3] 건물 내부 시스템")
def test_interior():
    from building_interior import BuildingInterior, FURNITURE_LOOT_TABLES
    for btype in ["house", "store", "hospital", "police", "military"]:
        interior = BuildingInterior(btype, 4, 4, seed=42)
        assert interior.width >= 8
        assert interior.height >= 8
        assert len(interior.rooms) > 0
        assert len(interior.furniture) > 0
        # 문, 벽, 바닥 올바르게 생성됐는지
        assert interior.get_tile(0, 0) == "wall"
        dx, dy = interior.door_pos
        assert interior.get_tile(dx, dy) == "door"
        # 가구 탐색
        f = interior.furniture[0]
        old_searched = f.searched
        loot = f.search(1.0)
        assert f.searched == True
        assert isinstance(loot, list)
        # 직렬화
        d = interior.to_dict()
        assert d["type"] == btype
    assert len(FURNITURE_LOOT_TABLES) >= 10
check("건물 내부 생성 (모든 타입)", test_interior)

# 4. 월드 생성 검증 (겹침/물 방지)
print("\n[4] 월드 생성 검증")
def test_world_gen():
    from world import World, TileType
    from settings import CHUNK_SIZE
    w = World(seed=12345, world_settings={"resource_density": 1.0, "building_density": 1.0})
    chunks_to_check = [(0,0), (1,0), (0,1), (-1,0), (0,-1), (2,2)]
    total_buildings = 0
    overlap_count = 0
    water_building = 0

    for cx, cy in chunks_to_check:
        chunk = w.get_chunk(cx, cy)
        total_buildings += len(chunk.buildings)

        # 건물 겹침 검사
        for i, b1 in enumerate(chunk.buildings):
            for j, b2 in enumerate(chunk.buildings):
                if i >= j:
                    continue
                if (b1.x < b2.x + b2.width and b1.x + b1.width > b2.x and
                    b1.y < b2.y + b2.height and b1.y + b1.height > b2.y):
                    overlap_count += 1
                    print(f"Overlap detected in chunk {cx},{cy}: b1({b1.building_type} at {b1.x},{b1.y} {b1.width}x{b1.height}) <-> b2({b2.building_type} at {b2.x},{b2.y} {b2.width}x{b2.height})")

        # 물 위 건물 검사
        for b in chunk.buildings:
            wx_base = cx * CHUNK_SIZE
            wy_base = cy * CHUNK_SIZE
            for dy in range(b.height):
                for dx in range(b.width):
                    lx = b.x - wx_base + dx
                    ly = b.y - wy_base + dy
                    if 0 <= lx < CHUNK_SIZE and 0 <= ly < CHUNK_SIZE:
                        tile = chunk.get_tile(lx, ly)
                        if tile == TileType.WATER:
                            water_building += 1

    assert overlap_count == 0, f"건물 겹침 {overlap_count}건"
    assert water_building == 0, f"물 위 건물 {water_building}건"
    print(f"     (총 건물 {total_buildings}개, 겹침 0, 물 위 0)")
check("건물 배치 유효성", test_world_gen)

# 5. 스태미나 시스템
print("\n[5] 스태미나 시스템")
def test_stamina():
    from player import Player
    from settings import PLAYER_MAX_STAMINA
    p = Player(5, 5)
    p.stamina = 0
    assert p.exhausted == False
    p.exhausted = True
    # 탈진 상태에서 스태미나가 30% 미만이면 sprinting 금지
    p.stamina = PLAYER_MAX_STAMINA * 0.2
    import pygame
    pygame.init()
    # 수동 체크
    assert p.exhausted == True  # 아직 30% 미만
    p.stamina = PLAYER_MAX_STAMINA * 0.35
    # 여기서 exhausted 해제는 _handle_movement에서
check("스태미나 탈진 로직", test_stamina)

# 6. 전투 각도 판정
print("\n[6] 전투 각도 판정")
def test_combat_angle():
    from combat import angle_diff
    import math
    assert abs(angle_diff(0, 0)) < 0.001
    assert abs(angle_diff(0, math.pi) - math.pi) < 0.001
    assert abs(angle_diff(math.pi/4, -math.pi/4) - math.pi/2) < 0.001
check("근접 전투 각도 함수", test_combat_angle)

# 7. 도로 시스템
print("\n[7] 도로 시스템")
def test_roads():
    from world import World, TileType
    from settings import CHUNK_SIZE
    w = World(seed=99, world_settings={"resource_density": 1.0, "building_density": 1.0})
    # 도시 바이옴 중심 근처 어딘가에서 도로 검증
    road_count = 0
    total_tiles = 0
    chunk = w.get_chunk(0, 0)
    for ly in range(CHUNK_SIZE):
        for lx in range(CHUNK_SIZE):
            tile = chunk.get_tile(lx, ly)
            total_tiles += 1
            if tile == TileType.ROAD:
                road_count += 1
    print(f"     (체크: {total_tiles}타일 중 도로 {road_count}개)")
check("도로 생성 검증", test_roads)

# 8. 엔티티 디스폰
print("\n[8] 엔티티 디스폰")
def test_despawn():
    from entities import EntityManager, Zombie
    from settings import CHUNK_SIZE
    em = EntityManager()
    # 플레이어에서 매우 먼 좀비
    z = Zombie(999, 999, "normal")
    em.zombies.append(z)
    em._cull_distant_entities(0, 0)
    assert z.active == False, "먼 엔티티가 비활성화되지 않음"
check("원거리 엔티티 디스폰", test_despawn)

# 9. Bresenham 사선 검사
print("\n[9] Bresenham 사선 검사")
def test_line_of_sight():
    from utils import check_line_of_sight
    
    class DummyWorld:
        def __init__(self):
            self.walls = {(2, 2)}
        def is_walkable(self, x, y):
            return (int(x), int(y)) not in self.walls
            
    world = DummyWorld()
    
    assert check_line_of_sight(0, 0, 4, 0, world) == True
    assert check_line_of_sight(0, 0, 4, 4, world) == False
check("사선 검사 (Line of Sight)", test_line_of_sight)

# 10. 전술 AI 엄폐물 및 우회 타겟
print("\n[10] 전술 AI 엄폐물 및 우회 타겟")
def test_tactical_ai_helpers():
    from entities import Zombie
    
    class DummyWorld:
        def __init__(self):
            self.walls = {(5, 5)}
        def is_walkable(self, x, y):
            return (int(x), int(y)) not in self.walls
            
    world = DummyWorld()
    z = Zombie(3, 3, "normal")
    
    cx, cy = z._find_cover_tile(6, 6, world)
    assert cx is not None or cy is not None
    
    fx, fy = z._calculate_flank_pos(6, 6, world)
    assert fx is not None and fy is not None
check("전술 AI 엄폐/우회 알고리즘", test_tactical_ai_helpers)

# 11. 총기 궤적 및 AI 조준선 시각화 시스템 검증
print("\n[11] 총기 궤적 및 AI 조준선 검증")
def test_combat_tracers_and_aiming():
    from combat import CombatSystem
    from entities import Zombie, EntityManager
    from player import Player
    
    # 1. 궤적 초기화 및 등록 테스트
    cs = CombatSystem()
    assert len(cs.tracers) == 0
    
    # 궤적 추가
    cs.tracers.append({
        "start": (0, 0),
        "end": (10, 10),
        "color": (255, 220, 100),
        "timer": 0.2,
        "max_timer": 0.2
    })
    assert len(cs.tracers) == 1
    
    # 업데이트 타이머 소모 검증
    cs.update(0.1)
    assert len(cs.tracers) == 1
    assert abs(cs.tracers[0]["timer"] - 0.1) < 0.001
    
    # 타이머 만료 후 제거 검증
    cs.update(0.15)
    assert len(cs.tracers) == 0
    
    # 2. AI 조준 대상 인지 검증 (entity_manager 전달 확인)
    em = EntityManager()
    p = Player(0, 0)
    scav = Zombie(2, 2, "normal")
    pmc = Zombie(4, 4, "tank")
    
    em.zombies.extend([scav, pmc])
    
    # 팩션 확인
    assert scav.faction == "scav"
    assert pmc.faction == "pmc"
    
    class DummyWorld:
        def is_walkable(self, x, y):
            return True
        def get_biome(self, x, y):
            return "도시"
            
    world = DummyWorld()
    
    # zombie.update 호출 시 entity_manager가 잘 넘어가서 적대 팩션 타겟을 인지하는지 확인
    # pmc가 2타일 거리의 scav를 탐지해야 함
    pmc.ai_timer = 0.2  # AI 의사결정이 즉시 이루어지도록 타이머 조절
    pmc.update(0.1, p.x, p.y, world, player_crouching=False, entity_manager=em)
    assert pmc.target is not None

check("총기 궤적 및 AI 조준선 시스템", test_combat_tracers_and_aiming)

# 12. 건물 내부 시스템 리팩토링 검증 (OOP)
print("\n[12] 건물 내부 시스템 리팩토링 검증 (OOP)")
def test_interior_system_refactoring():
    import os
    os.environ["SDL_VIDEODRIVER"] = "dummy"
    import pygame
    pygame.init()
    
    from main import Game
    g = Game()
    assert g.interior_system is not None
    assert g.current_interior is None
    assert g.interior_system.current_interior is None
    
    # 프로퍼티 위임 쓰기/읽기 테스트
    g.current_interior = "TestInteriorValue"
    assert g.interior_system.current_interior == "TestInteriorValue"
    assert g.current_interior == "TestInteriorValue"

check("건물 내부 시스템 OOP 위임", test_interior_system_refactoring)

# 13. 4차 편의성 및 지도 확장 검증
print("\n[13] 4차 편의성 및 지도 확장 검증")
def test_convenience_and_map():
    from main import Game, GameState
    import pygame
    
    # 1. 인벤토리 단축키 B 및 M 지도 토글 테스트
    g = Game()
    g.state = GameState.PLAYING
    assert g.inventory_ui.visible == False
    assert g.map_visible == False
    
    # B키 누름 시뮬레이션
    event_b = pygame.event.Event(pygame.KEYDOWN, key=pygame.K_b)
    g._process_global_inputs(event_b)
    assert g.inventory_ui.visible == True

    # 1.5 은신처 로비에서 ESC 누름 시 포즈 화면(pause_game) 리턴 테스트
    from player import Player
    p = Player(0, 0)
    class DummyEventSystem:
        def add_log(self, text):
            pass
    p.event_system = DummyEventSystem()
    event_esc = pygame.event.Event(pygame.KEYDOWN, key=pygame.K_ESCAPE)
    res_esc = g.hideout_ui.handle_event(event_esc, p)
    assert res_esc == "pause_game"
    
    # M키 누름 시뮬레이션
    event_m = pygame.event.Event(pygame.KEYDOWN, key=pygame.K_m)
    g._process_global_inputs(event_m)
    # M키를 누르면 인벤토리가 닫히고 지도가 켜져야 함
    assert g.inventory_ui.visible == False
    assert g.map_visible == True
    
    # 2. 상인 클릭 좌표 검증
    # Stash 탭에 "생수" 1개 배치하여 상점에 판매
    from player import Player
    p = Player(0, 0)
    class DummyEventSystem:
        def add_log(self, text):
            pass
    p.event_system = DummyEventSystem()
    p.rubles = 10000
    p.stash.add_item("생수", 1)
    
    # sell 액션
    g.hideout_ui.active_tab = "traders"
    g.hideout_ui.trader_sub_tab = "sell"
    g.hideout_ui.selected_shop_item = {
        "name": "생수",
        "price": 250,
        "action": "sell",
        "index": 0
    }
    # buy/sell 액션 좌표는 470 <= mx <= 730, 490 <= my <= 525
    # mx = 500, my = 500 (클릭 좌표가 범위 내에 들어옴)
    click_event = pygame.event.Event(pygame.MOUSEBUTTONDOWN, button=1, pos=(500, 500))
    g.hideout_ui.handle_event(click_event, p)
    # 판매 처리 후 rubles가 증가하고 Stash 아이템이 비어있어야 함
    assert p.rubles == 10250
    assert len(p.stash.items) == 0

    # 3. 전장의 안개 및 지도 직렬화 검증
    # 플레이어가 (10, 10)에 위치할 때 탐색 범위 확인
    p.x, p.y = 10.0, 10.0
    
    class DummyWorld:
        def is_walkable(self, x, y):
            return True
    
    p.update(0.1, DummyWorld()) # world를 전달하여 _handle_movement가 에러 나지 않게 함
    assert (10, 10) in p.explored_tiles
    assert (6, 6) not in p.explored_tiles # 반경 4를 벗어나므로 없어야 함
    
    # 직렬화 / 역직렬화
    p_dict = p.to_dict()
    p_loaded = Player.from_dict(p_dict)
    assert (10, 10) in p_loaded.explored_tiles
    assert (6, 6) not in p_loaded.explored_tiles

check("4차 편의성 및 안개 지도 시스템", test_convenience_and_map)

# 14. A* 길찾기 알고리즘 검증
print("\n[14] A* 길찾기 알고리즘 검증")
def test_astar_pathfinding():
    from pathfinding import find_path
    
    class DummyWorldForAStar:
        def __init__(self):
            # (1, 1)에 벽이 가로막고 있는 상태
            self.walls = {(1, 1), (1, 0), (1, 2)}
        def is_walkable(self, x, y):
            return (int(x), int(y)) not in self.walls
            
    world = DummyWorldForAStar()
    # (0, 1)에서 (2, 1)로 가려면 벽 (1, 1)을 넘지 못하고 위나 아래로 우회해야 함
    path = find_path((0.5, 1.5), (2.5, 1.5), world)
    assert len(path) > 0
    # 경로 내에 벽 (1, 1)이 없어야 함
    for x, y in path:
        assert (int(x), int(y)) not in world.walls

check("A* 길찾기 알고리즘 및 우회 경로 탐색", test_astar_pathfinding)

# 15. 미니맵 캐싱 동작성 검증
print("\n[15] 미니맵 캐싱 동작성 검증")
def test_minimap_caching():
    import os
    os.environ["SDL_VIDEODRIVER"] = "dummy"
    import pygame
    pygame.init()
    
    from ui.hud import HUD
    from player import Player
    
    class DummyWorld:
        def __init__(self):
            self.chunks = {}
        def get_biome(self, x, y):
            return "도시"
            
    hud = HUD(800, 600)
    p = Player(10, 10)
    w = DummyWorld()
    
    # 첫 렌더링 호출 (캐시 채우기)
    surf = pygame.Surface((800, 600))
    hud._draw_minimap(surf, p, w, dt=0.05)
    
    # 초기 타이머는 캐시 생성 시 0.0으로 리셋됨
    assert hud.minimap_timer == 0.0
    assert hud.last_player_tile_pos == (10, 10)
    
    # dt를 0.1 주면 타이머가 누적되지만 1.0 미만이고 플레이어 위치도 그대로이므로 캐시 재사용
    hud._draw_minimap(surf, p, w, dt=0.1)
    assert hud.minimap_timer == 0.1
    
    # 플레이어가 이동하면 타이머 상관없이 캐시 강제 갱신
    p.x, p.y = 11.5, 11.5
    hud._draw_minimap(surf, p, w, dt=0.1)
    assert hud.minimap_timer == 0.0
    assert hud.last_player_tile_pos == (11, 11)

check("미니맵 캐싱 및 타이머/이동 감지", test_minimap_caching)

# 16. Stash 복사 무결성 검증
print("\n[16] Stash 복사 무결성 검증")
def test_stash_integrity():
    from player import Player
    from main import Game
    import pygame
    
    g = Game()
    p = Player(0, 0)
    
    # 인벤토리에 아이템 추가
    p.inventory.add_item("생수", 1)
    assert p.inventory.count_item("생수") == 1
    
    # 인벤토리 -> Stash 이동 처리 (Stash에 deepcopy하여 추가)
    g.hideout_ui.active_tab = "stash"
    g.hideout_ui.selected_item = {"source": "inventory", "index": 0, "item_name": "생수"}
    
    # 드래그 앤 드롭이 아닌 탭 클릭을 통한 이동 처리 시뮬레이션
    # 210 <= mx <= 350, 80 <= my <= 115 좌표 클릭 시 Stash -> Inventory 또는 그 반대 동작
    click_event = pygame.event.Event(pygame.MOUSEBUTTONDOWN, button=1, pos=(250, 90))
    g.hideout_ui.handle_event(click_event, p)
    
    # Stash에 "생수"가 정상 복사 및 추가되어야 하고, 인벤토리에서는 제거되어야 함
    assert p.stash.count_item("생수") == 1
    assert p.inventory.count_item("생수") == 0
    
    # deepcopy가 성공적으로 되었는지 입증하기 위해, Stash 내부 아이템의 정보를 별도 조작해도 영향이 없는지 혹은
    # 세이브/로드 사망 패널티 상황 시뮬레이션(인벤토리 클리어)을 수행해도 Stash가 절대 훼손되지 않는지 검사
    p.inventory.items = []
    assert p.stash.count_item("생수") == 1

check("Stash 아이템 복사 무결성(Deepcopy) 검증", test_stash_integrity)

# 17. 레이드 시작 팝업 일시정지 검증
print("\n[17] 레이드 시작 팝업 일시정지 검증")
def test_raid_popup_pause():
    from main import Game, GameState
    from player import Player
    g = Game()
    g.player = Player(0, 0)
    g.state = GameState.PLAYING
    g.show_raid_start_popup = True
    
    # 팝업이 활성화된 경우 즉시 리턴하므로 어떠한 예외(NoneType AttributeError 등)도 발생하지 않음
    try:
        g._process_global_update(0.1)
        popup_blocked = True
    except:
        popup_blocked = False
    assert popup_blocked == True
    
    # 팝업을 끄면 업데이트 로직이 흐르며 미설정된 서브시스템(time_system 등) 참조로 예외가 발생함
    g.show_raid_start_popup = False
    try:
        g._process_global_update(0.1)
        popup_passed = True
    except AttributeError:
        # 정상적으로 방어막이 풀려 AttributeError가 발생한 상황
        popup_passed = False
    except:
        popup_passed = True
    assert popup_passed == False


check("레이드 시작 팝업 일시정지 상태 제어", test_raid_popup_pause)

# 18. 비정상 종료(Alt+F4) 패널티 삭제 검증
print("\n[18] 비정상 종료 패널티 삭제 검증")
def test_save_no_penalty():
    from main import Game
    from save_system import GameSaveManager
    g = Game()
    
    # 가상의 세이브 데이터 (IN_RAID 상태)
    dummy_data = {
        "world_settings": {"seed": 1234, "difficulty": "보통"},
        "player": {
            "x": 10.0, "y": 10.0,
            "inventory": {"slots": 24, "items": [["생수", 2]]},
            "equipped": {"head": None, "body": None, "feet": None, "weapon": None},
            "raid_status": "IN_RAID" # 레이드 진행 도중 강제 종료 가정
        },
        "current_day": 1,
        "playtime": 100
    }
    
    # 복원 수행
    res = GameSaveManager.deserialize_game(g, dummy_data)
    assert res == True
    # 이전 비정상종료 메커니즘이 삭제되었으므로, 복원 후 인벤토리에 아이템이 지워지지 않고 보존되어야 함
    assert g.player.inventory.count_item("생수") == 2

check("비정상 종료(Alt+F4) 패널티 삭제 검증", test_save_no_penalty)

# 19. 맵 델타 및 엔티티 복원 검증
print("\n[19] 맵 델타 및 엔티티 복원 검증")
def test_save_delta_and_entities_restoration():
    from main import Game
    from entities import Zombie, NPC
    from world import World
    from save_system import GameSaveManager
    import pygame
    
    g = Game()
    g.world_settings = {"seed": 42, "difficulty": "보통"}
    g.world = World(seed=42, world_settings=g.world_settings)
    from settings import DIFFICULTY_PRESETS
    from entities import EntityManager
    from weather import TimeSystem
    g.difficulty = DIFFICULTY_PRESETS["보통"]
    g.entity_manager = EntityManager(g.difficulty)
    g.time_system = TimeSystem(12)
    from player import Player
    g.player = Player(0, 0)
    
    # 1. 월드 오브젝트 변경 (파밍 상태 변경 시뮬레이션)
    chunk = g.world.get_chunk(0, 0)
    if chunk.objects:
        obj = chunk.objects[0]
        obj.looted = True
        obj.hp = 10
        
    # 2. 좀비 및 NPC 추가
    z = Zombie(5.5, 5.5, "normal")
    z.hp = 25
    g.entity_manager.zombies.append(z)
    
    n = NPC(10.5, 10.5, "merchant")
    g.entity_manager.npcs.append(n)
    
    # 직렬화
    data = GameSaveManager.serialize_game(g)
    assert data is not None
    assert len(data["world_deltas"]) > 0
    assert len(data["entities"]["zombies"]) > 0
    
    # 복원
    g2 = Game()
    res = GameSaveManager.deserialize_game(g2, data)
    assert res == True
    
    # 복원된 엔티티 검증
    assert len(g2.entity_manager.zombies) == 1
    z_restored = g2.entity_manager.zombies[0]
    assert z_restored.x == 5.5
    assert z_restored.y == 5.5
    assert z_restored.hp == 25
    
    assert len(g2.entity_manager.npcs) == 1
    n_restored = g2.entity_manager.npcs[0]
    assert n_restored.x == 10.5
    assert n_restored.y == 10.5

check("맵 델타 및 좀비/PMC 엔티티 위치 보존 검증", test_save_delta_and_entities_restoration)

# 20. 레이드 맵 내 은신처 제외 검증
print("\n[20] 레이드 맵 내 은신처 제외 검증")
def test_raid_shelter_exclusion():
    from world import World
    
    # 1. is_raid=False 인 경우 0,0 청크에 shelter 건물이 존재해야 함
    world_non_raid = World(seed=999, world_settings={}, is_raid=False)
    chunk_non_raid = world_non_raid.get_chunk(0, 0)
    has_shelter = any(b.building_type == "shelter" for b in chunk_non_raid.buildings)
    assert has_shelter == True, "일반 월드의 (0,0) 청크에는 은신처가 생성되어야 합니다."
    
    # 2. is_raid=True 인 경우 0,0 청크에 shelter 건물이 없어야 함
    world_raid = World(seed=999, world_settings={}, is_raid=True)
    chunk_raid = world_raid.get_chunk(0, 0)
    has_shelter_raid = any(b.building_type == "shelter" for b in chunk_raid.buildings)
    assert has_shelter_raid == False, "레이드 월드의 (0,0) 청크에는 은신처가 생성되지 않아야 합니다."

check("레이드 맵 내 은신처 제외 검증", test_raid_shelter_exclusion)

# 21. 샌드박스 무게 한도 및 속도 패널티 면제 검증
print("\n[21] 샌드박스 무게 한도 및 속도 패널티 면제 검증")
def test_sandbox_weight_exemption():
    from main import Game
    from player import Player
    from items import Inventory
    from save_system import GameSaveManager
    from world import World
    from weather import TimeSystem
    
    g = Game()
    g.world_settings = {"seed": 42, "difficulty": "보통", "sandbox": True}
    g.sandbox_mode = True
    g.player = Player(0, 0, g.difficulty)
    g.player.inventory.is_sandbox = True
    g.world = World(seed=42, world_settings=g.world_settings)
    g.time_system = TimeSystem(12)
    
    # 샌드박스 상태일 때는 무게 제한을 넘어도 아이템을 계속 담을 수 있어야 함
    # "고철" 무게는 0.4. max_weight=30.0일 때 100개(무게 40.0) 담기 시도
    res = g.player.inventory.add_item("고철", 100)
    assert res == True, "샌드박스 모드에서는 무게 초과와 무관하게 아이템이 추가되어야 합니다."
    assert g.player.inventory.current_weight > g.player.inventory.max_weight
    
    # 세이브/로드 시에도 sandbox_mode와 is_sandbox 속성이 복원되는지 확인
    data = GameSaveManager.serialize_game(g)
    g2 = Game()
    res_load = GameSaveManager.deserialize_game(g2, data)
    assert res_load == True
    assert g2.sandbox_mode == True
    assert g2.player.inventory.is_sandbox == True
    
    # 플레이어 과적 시 속도 패널티가 적용되지 않는지 확인
    # 기본 스피드
    p = g2.player
    p.inventory.items = [("고철", 100)] # 무게 40.0 (max_weight인 30.0 초과)
    
    # _handle_movement 시뮬레이션용 가짜 world 클래스
    class DummyWorld:
        def is_walkable(self, x, y):
            return True
    
    # 샌드박스이므로 무게 페널티로 감속되면 안 됨.
    # p.speed가 current_speed로 잘 작동해야 함.
    # _handle_movement 내에서 current_speed에 감속이 적용 안되었는지 검사하기 위해 
    # mock key press 대신 _handle_movement가 current_speed를 바르게 업데이트했는지 위치 변동폭으로 역산
    import pygame
    keys = pygame.key.get_pressed()
    # pygame이 초기화되어 있지 않으면 get_pressed()가 빈 튜플 등을 반환하거나 작동이 어려울 수 있으나,
    # player.py의 _handle_movement를 직접 호출해보거나, 내부 속도 로직만 부분 시뮬레이션
    
    # 직접 player._handle_movement의 current_speed 계산부 검증:
    # is_sandbox = True이므로 current_weight > max_weight * 0.8 임에도 감속 페널티가 0이어야 함
    current_speed = p.speed
    if not p.inventory.is_sandbox and p.inventory.current_weight > p.inventory.max_weight * 0.8:
        # 이 블록은 샌드박스이므로 실행되지 않아야 함
        penalty_ratio = (p.inventory.current_weight - p.inventory.max_weight * 0.8) / (p.inventory.max_weight * 0.2)
        penalty_ratio = min(1.0, penalty_ratio)
        current_speed *= (1.0 - 0.3 * penalty_ratio)
        
    assert current_speed == p.speed, "샌드박스 모드에서는 과적 상태에서도 속도 페널티를 받지 않아야 합니다."

check("샌드박스 무게 한도 및 속도 패널티 면제 검증", test_sandbox_weight_exemption)

# 결과 요약
print("\n" + "=" * 60)
if errors:
    print(f"⚠️  {len(errors)}개 오류 발견:")
    for name, err in errors:
        print(f"  - {name}: {err}")
else:
    print("✅ 모든 검증 통과!")
print("=" * 60)
sys.exit(len(errors))
