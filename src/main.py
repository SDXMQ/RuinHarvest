"""
main.py - 30일간의 생존 (좀비 아포칼립스 오픈월드 서바이벌)
엔트리포인트, 메인 게임 루프, 씬 매니저
"""
import pygame
import sys
import os

# 하위 폴더들을 sys.path에 추가하여 기존 플랫 임포트 구조가 그대로 동작하도록 보장
src_dir = os.path.dirname(os.path.abspath(__file__))
subdirs = ['core', 'world', 'entities', 'systems', 'graphics']
for subdir in subdirs:
    path = os.path.join(src_dir, subdir)
    if path not in sys.path:
        sys.path.insert(0, path)

import math
import random
import time as pytime

from settings import (Colors, FPS, TILE_SIZE, CHUNK_SIZE, RENDER_DISTANCE,
                       DIFFICULTY_PRESETS, DEFAULT_WORLD_SETTINGS,
                       GameSettings, RESOLUTION_OPTIONS)
from camera import Camera
from world import World
from player import Player
from entities import EntityManager, Enemy, NPC, EnemyState
from combat import CombatSystem
from weather import TimeSystem, WeatherSystem
from events import EventSystem, determine_ending
from items import ITEM_DATABASE, generate_loot
from renderer import (TileRenderer, CharacterRenderer, EnvironmentRenderer,
                       BuildingRenderer, draw_rounded_rect, draw_glow, ItemIconRenderer)
from particles import ParticleSystem, ParticleEmitters
from transitions import TransitionManager
from world_renderer import WorldSceneRenderer
from ui import (FontManager, HUD, InventoryUI, CraftingUI, DialogueUI,
                EventLogUI, MainMenuUI, WorldCreationUI, SettingsUI,
                PauseUI, EndingUI, SaveSlotsUI)
from sounds import SoundGenerator
from save_system import save_game, load_game, get_save_files, delete_save, rename_save, GameSaveManager
from interaction import InteractionHandler
from building_interior import BuildingInterior
from i18n import t, set_language, get_language
from flea_market import FleaMarket
from ui.hideout_ui import HideoutUI
from ui.radio_ui import RadioScannerUI
from interior_system import InteriorSystem
from ui.map_ui import MapUI


# ============================================================
# 게임 상태
# ============================================================
class GameState:
    MAIN_MENU = "main_menu"
    WORLD_CREATION = "world_creation"
    HIDEOUT = "hideout"                 # 은신처 정비 상태 (창고, 정비 상인 UI 기동)
    MARKET = "market"                   # 가상 플리마켓 거래 전용 상태
    SETTINGS = "settings"
    LOADING = "loading"                 # 레이드 생성 및 리소스 프리로딩
    PLAYING = "playing"                 # 실제 레이드 인게임 플레이 (야외)
    BUILDING_INTERIOR = "building_interior" # 건물 내부 파밍 진입
    PAUSED = "paused"
    INVENTORY = "inventory"
    CRAFTING = "crafting"
    DIALOGUE = "dialogue"
    ENDING = "ending"                   # 레이드 정산 결과 창 (생환 / KIA 여부 요약)
    GAME_OVER = "game_over"
    SAVE_SLOTS = "save_slots"


# ============================================================
# 메인 게임 클래스
# ============================================================
class Game:
    """메인 게임"""

    def __init__(self):
        pygame.init()
        pygame.display.set_caption("30일간의 생존 - 좀비 아포칼립스")

        self.game_settings = GameSettings()
        self.screen_w = self.game_settings.width
        self.screen_h = self.game_settings.height

        self._create_window()

        self.clock = pygame.time.Clock()
        self.running = True
        self.state = GameState.MAIN_MENU

        # 폰트 초기화
        FontManager.init()
        SoundGenerator.init()

        # 전환 효과
        self.transition = TransitionManager()

        # 렌더러 및 상호작용 매니저
        self.world_renderer = WorldSceneRenderer(self)
        self.interaction_handler = InteractionHandler(self)

        self.flea_market = FleaMarket()

        # UI 시스템
        self._init_ui()

        # 메뉴 파티클
        self.menu_particles = ParticleSystem()

        # 게임 월드 (게임 시작 시 생성)
        self.world = None
        self.player = None
        self.camera = None
        self.entity_manager = None
        self.combat_system = None
        self.time_system = None
        self.weather_system = None
        self.event_system = None
        self.game_particles = None

        self.world_settings = None
        self.difficulty = None
        self.sandbox_mode = False
        self.current_day = 1
        self.total_days = 30
        self.is_final_ending = False
        self.day_changed = False
        self.last_day = 1
        self.playtime = 0

        # 상호작용 상태
        self.interact_target = None
        self.chunk_unload_timer = 0.0
        self.loading_progress = 0

        # 건물 내부 시스템 모듈화 (OOP 리팩토링)
        self.interior_system = InteriorSystem(self)

        # 레이드 및 탈출 시스템 상태
        self.raid_time_left = 600.0   # 레이드 제한시간 (10분 = 600초)
        self.extract_timer = 0.0      # 탈출 대기 타이머
        self.extract_target = None    # 현재 서있는 탈출구 정보
        self.map_visible = False
        self.prev_state = None
        self.dt = 0.0
        self.show_raid_start_popup = False

    def _create_window(self):
        """창 생성"""
        flags = pygame.RESIZABLE
        if self.game_settings.fullscreen:
            flags = pygame.FULLSCREEN
            info = pygame.display.Info()
            self.screen_w = info.current_w
            self.screen_h = info.current_h
        self.screen = pygame.display.set_mode(
            (self.screen_w, self.screen_h), flags
        )

    def _init_ui(self):
        """UI 초기화"""
        w, h = self.screen_w, self.screen_h
        self.main_menu_ui = MainMenuUI(w, h)
        self.world_creation_ui = WorldCreationUI(w, h)
        self.settings_ui = SettingsUI(w, h)
        self.hud = HUD(w, h)
        self.inventory_ui = InventoryUI(w, h)
        self.radio_ui = RadioScannerUI(w, h)
        self.crafting_ui = CraftingUI(w, h)
        self.dialogue_ui = DialogueUI(w, h)
        self.event_log_ui = EventLogUI(w, h)
        self.pause_ui = PauseUI(w, h)
        self.ending_ui = EndingUI(w, h)
        self.hideout_ui = HideoutUI(w, h, self.flea_market)
        self.map_ui = MapUI(w, h)
        self.save_slots_ui = SaveSlotsUI(w, h)

    def _apply_resolution(self):
        """해상도 변경 적용"""
        self.screen_w = self.game_settings.width
        self.screen_h = self.game_settings.height
        self._create_window()
        self._init_ui()
        if self.camera:
            self.camera.resize(self.screen_w, self.screen_h)

    # ============================================================
    # 게임 시작 / 로드
    # ============================================================
    def start_new_game(self, world_settings):
        """새 게임 시작"""
        self.world_settings = world_settings
        diff_name = world_settings.get("difficulty", "보통")
        self.difficulty = DIFFICULTY_PRESETS.get(diff_name, DIFFICULTY_PRESETS["보통"])
        self.total_days = world_settings.get("total_days", 30)

        seed = world_settings.get("seed") or random.randint(0, 2**31)
        world_settings["seed"] = seed

        # 월드 생성
        self.world = World(seed=seed, world_settings=world_settings)

        # 플레이어 (은신처 문 앞에 스폰)
        spawn_x = CHUNK_SIZE // 2 + 0.5
        spawn_y = CHUNK_SIZE // 2 + 3.5  # 은신처 문 바로 아래
        self.player = Player(spawn_x, spawn_y, self.difficulty)

        # 시작 아이템
        if world_settings.get("starting_items", True):
            self.player.inventory.add_item("생수", 2)
            self.player.inventory.add_item("식량통조림", 1)
            self.player.inventory.add_item("붕대", 2)

        # 샌드박스 모드
        self.sandbox_mode = world_settings.get("sandbox", False)
        if self.sandbox_mode:
            self.player.inventory.slots = 100  # 슬롯 대폭 확장
            self.player.inventory.is_sandbox = True
            for item_name, item_data in ITEM_DATABASE.items():
                if item_data.get("stackable"):
                    count = item_data.get("max_stack", 10)
                else:
                    count = 1
                self.player.inventory.add_item(item_name, count)

        # 시스템 초기화
        self.camera = Camera()
        self.camera.resize(self.screen_w, self.screen_h)
        self.entity_manager = EntityManager(self.difficulty)
        self.combat_system = CombatSystem()
        day_len = world_settings.get("day_length_minutes", 12)
        self.time_system = TimeSystem(day_len)
        weather_var = world_settings.get("weather_variability", 1.0)
        self.weather_system = WeatherSystem(weather_var)
        self.event_system = EventSystem(self.difficulty)
        self.player.event_system = self.event_system
        self.game_particles = ParticleSystem()

        self.current_day = 1
        self.last_day = 1
        self.playtime = 0
        self.day_changed = False

        # 레이드 타이머 초기화
        self.raid_time_left = 600.0
        self.extract_timer = 0.0
        self.extract_target = None

        # 초기 청크 로드
        self.world.get_chunk(0, 0)

        self.state = GameState.HIDEOUT
        if self.sandbox_mode:
            self.event_system.add_log(t("log_sandbox_started"))
        self.event_system.add_log(t("log_survival_started"))
        SoundGenerator.play("day_start")

    def load_saved_game(self, slot_name=None):
        """저장된 게임 로드"""
        if slot_name is None:
            saves = get_save_files()
            if not saves:
                return False
            slot_name = saves[0]["filename"].replace(".json", "")

        data = load_game(slot_name)
        if not data:
            return False

        if GameSaveManager.deserialize_game(self, data):
            if self.player.raid_status == "IN_RAID":
                if self.player.is_interior:
                    self.state = GameState.BUILDING_INTERIOR
                else:
                    self.state = GameState.PLAYING
                self.show_raid_start_popup = True
            else:
                self.state = GameState.HIDEOUT
            self.player.event_system = self.event_system
            self.event_system.add_log(t("log_game_loaded", self.current_day))
            return True
        return False

    def save_current_game(self):
        """현재 게임 저장 (월드 상태 델타 포함)"""
        game_data = GameSaveManager.serialize_game(self)
        if not game_data:
            return

        world_name = self.world_settings.get("world_name", "autosave").replace(" ", "_")
        if save_game(game_data, world_name):
            self.event_system.add_log(t("log_game_saved"))
            SoundGenerator.play("craft_complete")

    # ============================================================
    # 메인 루프
    # ============================================================
    def run(self):
        """메인 게임 루프"""
        while self.running:
            dt = self.clock.tick(FPS) / 1000.0
            dt = min(dt, 0.05)  # 프레임 레이트 안전장치
            self.dt = dt

            self._handle_events()
            self._update(dt)
            self._draw()

            pygame.display.flip()

        pygame.quit()
        sys.exit()

    def _handle_events(self):
        """이벤트 처리"""
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                self.running = False
                return

            if event.type == pygame.VIDEORESIZE:
                self.screen_w = event.w
                self.screen_h = event.h
                self.game_settings.resolution = [event.w, event.h]
                self._init_ui()
                if self.camera:
                    self.camera.resize(self.screen_w, self.screen_h)
                if self.interior_camera:
                    self.interior_camera.resize(self.screen_w, self.screen_h)

            # 전환 중엔 입력 무시
            if self.transition.is_active:
                continue

            if self.state == GameState.MAIN_MENU:
                result = self.main_menu_ui.handle_event(event)
                if result == "new_game":
                    SoundGenerator.play("menu_select")
                    self.transition.start("fade", 0.6,
                        on_mid=lambda: setattr(self, 'state', GameState.WORLD_CREATION))
                elif result == "load_game":
                    SoundGenerator.play("menu_select")
                    saves = get_save_files()
                    self.save_slots_ui.refresh(saves)
                    self.transition.start("fade", 0.4,
                        on_mid=lambda: setattr(self, 'state', GameState.SAVE_SLOTS))
                elif result == "settings":
                    SoundGenerator.play("menu_select")
                    self.transition.start("fade", 0.4,
                        on_mid=lambda: setattr(self, 'state', GameState.SETTINGS))
                elif result == "quit":
                    self.running = False

            elif self.state == GameState.WORLD_CREATION:
                result = self.world_creation_ui.handle_event(event)
                if result == "start":
                    SoundGenerator.play("menu_select")
                    ws = self.world_creation_ui.get_settings()
                    self.transition.start("circle", 1.0,
                        on_mid=lambda: self.start_new_game(ws))
                elif result == "back":
                    self.transition.start("fade", 0.4,
                        on_mid=lambda: setattr(self, 'state', GameState.MAIN_MENU))

            elif self.state == GameState.SAVE_SLOTS:
                result = self.save_slots_ui.handle_event(event)
                if result == "back":
                    self.transition.start("fade", 0.4,
                        on_mid=lambda: setattr(self, 'state', GameState.MAIN_MENU))
                elif isinstance(result, tuple):
                    action = result[0]
                    if action == "load":
                        idx = result[1]
                        saves = self.save_slots_ui.saves
                        if 0 <= idx < len(saves):
                            slot = saves[idx]["filename"].replace(".json", "")
                            SoundGenerator.play("menu_select")
                            self.transition.start("fade", 0.6,
                                on_mid=lambda s=slot: self.load_saved_game(s) or setattr(self, 'state',
                                    GameState.HIDEOUT if self.player else GameState.SAVE_SLOTS))
                    elif action == "delete":
                        idx = result[1]
                        saves = self.save_slots_ui.saves
                        if 0 <= idx < len(saves):
                            slot = saves[idx]["filename"].replace(".json", "")
                            delete_save(slot)
                            self.save_slots_ui.refresh(get_save_files())
                            SoundGenerator.play("menu_select")
                    elif action == "rename":
                        idx = result[1]
                        new_name = result[2].strip()
                        saves = self.save_slots_ui.saves
                        if 0 <= idx < len(saves) and new_name:
                            old_slot = saves[idx]["filename"].replace(".json", "")
                            rename_save(old_slot, new_name)
                            self.save_slots_ui.refresh(get_save_files())
                            SoundGenerator.play("menu_select")

            elif self.state == GameState.SETTINGS:
                result = self.settings_ui.handle_event(event)
                if result == "apply":
                    self._apply_resolution()
                elif result == "back":
                    next_state = GameState.PAUSED if self.prev_state in (GameState.PLAYING, GameState.BUILDING_INTERIOR, GameState.HIDEOUT) else GameState.MAIN_MENU
                    self.transition.start("fade", 0.4,
                        on_mid=lambda: setattr(self, 'state', next_state))

            elif self.state == GameState.HIDEOUT:
                result = self.hideout_ui.handle_event(event, self.player)
                if result == "start_raid":
                    if self.hideout_ui.dragging:
                        self.hideout_ui._cancel_drag(self.player)
                    self.player.hp = self.player.max_hp
                    self.player.hunger = 100.0
                    self.player.thirst = 100.0
                    self.player.stress = 0.0
                    self.player.alive = True
                    self.player.bleeding = False
                    self.player.broken_bone = False
                    self.player.raid_status = "IN_RAID"
                    self.raid_time_left = 600.0
                    self.extract_timer = 0.0
                    self.extract_target = None
                    
                    if self.world_settings:
                        self.world = World(seed=self.world_settings["seed"], world_settings=self.world_settings, is_raid=True)
                        spawn_x = CHUNK_SIZE // 2 + 0.5
                        spawn_y = CHUNK_SIZE // 2 + 3.5
                        self.player.x = spawn_x
                        self.player.y = spawn_y
                        self.entity_manager = EntityManager(self.difficulty)
                        self.combat_system = CombatSystem()
                        self.game_particles = ParticleSystem()
                        self.world.get_chunk(0, 0)
                        self.save_current_game()  # IN_RAID 상태 원자적 저장
                        
                    self.transition.start("fade", 0.8,
                        on_mid=lambda: setattr(self, 'state', GameState.PLAYING))
                elif result == "main_menu":
                    self.transition.start("fade", 0.6,
                        on_mid=lambda: setattr(self, 'state', GameState.MAIN_MENU))
                elif result == "pause_game":
                    self.prev_state = GameState.HIDEOUT
                    self.state = GameState.PAUSED

            elif self.state in (GameState.PLAYING, GameState.BUILDING_INTERIOR):
                if self.show_raid_start_popup:
                    if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                        mx, my = event.pos
                        pw, ph = 340, 220
                        px = (self.screen_w - pw) // 2
                        py = (self.screen_h - ph) // 2
                        
                        # 버튼 1: 은신처로 돌아가기 (퇴각 - 패널티 적용)
                        if px + 30 <= mx <= px + 310 and py + 130 <= my <= py + 162:
                            SoundGenerator.play("menu_select")
                            self.show_raid_start_popup = False
                            self.resolve_raid_end(success=False, reason="MIA")
                        # 버튼 2: 레이드 계속하기 (진입)
                        elif px + 30 <= mx <= px + 310 and py + 172 <= my <= py + 204:
                            SoundGenerator.play("menu_select")
                            self.show_raid_start_popup = False
                else:
                    self._process_global_inputs(event)

            elif self.state == GameState.PAUSED:
                result = self.pause_ui.handle_event(event)
                if result == "resume":
                    self.state = self.prev_state if self.prev_state else GameState.PLAYING
                elif result == "save":
                    self.save_current_game()
                elif result == "settings":
                    self.state = GameState.SETTINGS
                elif result == "main_menu":
                    self.save_current_game()
                    self.transition.start("fade", 0.6,
                        on_mid=lambda: setattr(self, 'state', GameState.MAIN_MENU))

            elif self.state == GameState.ENDING:
                result = self.ending_ui.handle_event(event)
                if result == "main_menu":
                    if self.is_final_ending:
                        world_name = self.world_settings.get("world_name", "autosave").replace(" ", "_")
                        delete_save(world_name)
                        self.is_final_ending = False
                        self.transition.start("fade", 1.0,
                            on_mid=lambda: setattr(self, 'state', GameState.MAIN_MENU))
                    else:
                        self.transition.start("fade", 1.0,
                            on_mid=lambda: setattr(self, 'state', GameState.HIDEOUT))

    def _process_global_inputs(self, event):
        """게임플레이 중 이벤트"""
        if hasattr(self, "radio_ui") and self.radio_ui.visible:
            res = self.radio_ui.handle_event(event, self.player)
            if res and res[0] == "radio_scan_start":
                self.event_system.add_log(f"스캔 타겟 설정됨: {res[1]}")
            return
            
        # 인벤토리/크래프팅이 열려있으면 우선 처리
        if self.inventory_ui.visible:
            # 단축키(B, ESC, C, M) 입력은 아래쪽 글로벌 단축키 처리로 통과시킴
            if not (event.type == pygame.KEYDOWN and event.key in (pygame.K_b, pygame.K_ESCAPE, pygame.K_c, pygame.K_m)):
                result = self.inventory_ui.handle_event(event, self.player)
                if result:
                    action, value = result
                    slot_idx = None
                    if isinstance(value, tuple):
                        item_name, slot_idx = value
                    else:
                        item_name = value

                    if action == "use":
                        use_res = self.player.use_item(item_name, slot_idx=slot_idx)
                        if use_res == "radio_scan":
                            self.event_system.add_log("장거리 무전기를 켰습니다. 주파수를 스캔합니다...")
                            SoundGenerator.play("pickup")
                            if hasattr(self, "radio_ui"):
                                self.radio_ui.open()
                        elif use_res == "grenade":
                            self.event_system.add_log("수류탄을 투척했습니다! 폭발이 일어납니다!")
                            SoundGenerator.play("gunshot")
                            px, py = self.player.x, self.player.y
                            targets = self.interior_enemies if self.player.is_interior else (self.entity_manager.enemies if self.entity_manager else [])
                            for e in targets:
                                if e.active and not e.is_dead:
                                    dist = math.sqrt((e.x - px)**2 + (e.y - py)**2)
                                    if dist <= 3.5:
                                        e.take_damage(80)
                                        self.combat_system.damage_numbers.append((e.x, e.y - 0.5, 80, 1.0, (255, 150, 50)))
                                        from particles import ParticleEmitters
                                        self.game_particles.emit(lambda: ParticleEmitters.blood(e.x * 32, e.y * 32), 4)
                            if self.camera:
                                self.camera.shake(8, 0.3)
                            if self.player.is_interior and self.interior_camera:
                                self.interior_camera.shake(8, 0.3)
                        elif use_res == "flare":
                            self.event_system.add_log("조명탄을 피웠습니다! 주변이 밝아집니다.")
                            SoundGenerator.play("pickup")
                        elif use_res:
                            self.event_system.add_log(t("log_item_used", item_name))
                            SoundGenerator.play("pickup")
                    elif action == "equip":
                        equip_world = self.current_interior if self.player.is_interior else self.world
                        if self.player.equip_item(item_name, equip_world, slot_idx=slot_idx):
                            self.event_system.add_log(t("log_item_equipped", item_name))
                            SoundGenerator.play("pickup")
                    elif action == "drop_item":
                        # 아이템 바닥에 버리기 (메타데이터 보존)
                        found_idx = -1
                        for idx, it in enumerate(self.player.inventory.items):
                            if slot_idx is not None:
                                if len(it) > 2 and it[2].get("slot_idx") == slot_idx:
                                    found_idx = idx
                                    break
                            else:
                                if it[0] == item_name:
                                    found_idx = idx
                                    break
                        if found_idx != -1:
                            item_tup = self.player.inventory.items[found_idx]
                            item_name = item_tup[0]
                            item_meta = item_tup[2] if len(item_tup) > 2 else {}
                            
                            self.player.inventory.items.pop(found_idx)
                            
                            equip_world = self.current_interior if self.player.is_interior else self.world
                            equip_world.drop_item(item_name, self.player.x, self.player.y, item_meta)
                            self.event_system.add_log(t("log_item_dropped", item_name))
                            SoundGenerator.play("pickup")
                    elif action == "unequip":
                        # 장착 해제
                        item = self.player.equipped.get(value)
                        if item:
                            # 가방("back")일 때만 unequip 시 항상 바닥에 드롭되도록 world를 넘김
                            equip_world = None
                            if value == "back":
                                equip_world = self.current_interior if self.player.is_interior else self.world
                            
                            if self.player.unequip_item(value, equip_world):
                                if value == "back":
                                    self.event_system.add_log(t("log_item_dropped", item))
                                else:
                                    self.event_system.add_log(t("log_item_unequipped", item))
                                SoundGenerator.play("pickup")
                            else:
                                self.event_system.add_log(t("log_inventory_full"))
                return

        if self.crafting_ui.visible:
            # 단축키(B, ESC, C, M) 입력은 아래쪽 글로벌 단축키 처리로 통과시킴
            if not (event.type == pygame.KEYDOWN and event.key in (pygame.K_b, pygame.K_ESCAPE, pygame.K_c, pygame.K_m)):
                result = self.crafting_ui.handle_event(event, self.player)
                if result:
                    action, recipe_name = result
                    if action == "craft":
                        if self.player.crafting.start_craft(recipe_name, self.player.inventory):
                            self.event_system.add_log(t("log_crafting_started", recipe_name))
                            SoundGenerator.play("menu_select")
                return

        if self.dialogue_ui.visible:
            self.dialogue_ui.handle_event(event)
            return

        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                if self.inventory_ui.visible:
                    self.inventory_ui.toggle()
                elif self.crafting_ui.visible:
                    self.crafting_ui.toggle()
                elif self.map_visible:
                    self.map_visible = False
                else:
                    self.prev_state = self.state
                    self.state = GameState.PAUSED
            elif event.key == pygame.K_b:
                self.inventory_ui.toggle()
                if self.crafting_ui.visible:
                    self.crafting_ui.toggle()
                self.map_visible = False
            elif event.key == pygame.K_c:
                self.crafting_ui.toggle()
                if self.inventory_ui.visible:
                    self.inventory_ui.toggle()
                self.map_visible = False
            elif event.key == pygame.K_m:
                if self.state in (GameState.PLAYING, GameState.BUILDING_INTERIOR):
                    self.map_visible = not self.map_visible
                    if self.inventory_ui.visible:
                        self.inventory_ui.toggle()
                    if self.crafting_ui.visible:
                        self.crafting_ui.toggle()
            elif event.key == pygame.K_e:
                if self.state == GameState.BUILDING_INTERIOR:
                    self.interaction_handler.handle_interior_interaction()
                else:
                    self.interaction_handler.handle_interaction()
            elif event.key == pygame.K_F5:
                self.save_current_game()

        if event.type == pygame.MOUSEBUTTONDOWN:
            if event.button == 1 and not self.inventory_ui.visible and not self.crafting_ui.visible:
                if self.state == GameState.BUILDING_INTERIOR:
                    self._handle_interior_attack()
                else:
                    self._handle_exterior_attack()

    def _handle_exterior_attack(self):
        # 공격
        results = self.combat_system.player_attack(
            self.player, self.entity_manager, self.world, self.camera
        )
        if results:
            for action, target, dmg in results:
                if action == "hit":
                    SoundGenerator.play("hit_melee")
                    self.camera.shake(3, 0.15)
                    # 피 파티클
                    if target:
                        self.game_particles.emit(
                            lambda: ParticleEmitters.blood(
                                target.x * TILE_SIZE, target.y * TILE_SIZE),
                            5)
                elif action == "kill":
                    SoundGenerator.play("enemy_die")
                    self.event_system.add_log(t("log_enemy_killed"))
                    if target:
                        loot = target.get_loot()
                        for item in loot:
                            self.world.drop_item(item, target.x, target.y)
                            self.event_system.add_log(t("log_item_dropped_by_enemy", item))
                elif action == "no_ammo":
                    self.event_system.add_log(t("log_ammo_lacking"))
                elif action == "gunshot_fired":
                    SoundGenerator.play("gunshot")
                    self._trigger_gunshot_noise(self.player.x, self.player.y, False)


    def _trigger_gunshot_noise(self, px, py, is_interior):
        """총성 소음 어그로: 반경 내 적을 ALERT 경계 상태로 전환"""
        NOISE_RADIUS = 60  # 타일 단위 (~3~4 청크)
        if is_interior:
            for e in self.interior_enemies:
                if not e.is_dead and e.active:
                    e.state = EnemyState.ALERT
                    e.alert_target_x = px
                    e.alert_target_y = py
                    e.alert_timer = 6.0
                    e.aggro_alert = 2.0
        else:
            nearby = self.entity_manager.get_nearby_enemies(px, py, NOISE_RADIUS)
            for e in nearby:
                if e.state in (EnemyState.IDLE, EnemyState.WANDER, EnemyState.PATROL):
                    e.state = EnemyState.ALERT
                    e.alert_target_x = px
                    e.alert_target_y = py
                    e.alert_timer = 6.0
                    e.aggro_alert = 2.0

    # ============================================================
    # 건물 내부 진입/퇴장
    # ============================================================
    def _enter_building(self, building):
        """건물 내부로 진입"""
        self.interior_system.enter_building(building)

    def _exit_building(self):
        """건물에서 나가기"""
        self.interior_system.exit_building()

    def _handle_interior_attack(self):
        self.interior_system.handle_interior_attack()


    def _update(self, dt):
        """상태별 업데이트"""
        self.transition.update(dt)
        if self.transition.is_active:
            return

        if self.state == GameState.MAIN_MENU:
            self.main_menu_ui.update(dt)
            self.menu_particles.update(dt)
            if random.random() < 0.05:
                from particles import ParticleEmitters
                self.menu_particles.emit(lambda: ParticleEmitters.ember(self.screen_w // 2, self.screen_h), 1)

        elif self.state == GameState.WORLD_CREATION:
            pass

        elif self.state == GameState.SETTINGS:
            pass

        elif self.state == GameState.HIDEOUT:
            self.hideout_ui.update(dt)

        elif self.state in (GameState.PLAYING, GameState.BUILDING_INTERIOR):
            self._process_global_update(dt)

        elif self.state == GameState.PAUSED:
            pass

        elif self.state == GameState.ENDING:
            self.ending_ui.update(dt)


    def _process_global_update(self, dt):
        """게임플레이 및 건물 내부 공통 업데이트"""
        if self.show_raid_start_popup:
            return
        if not self.player or not self.player.alive:
            return

        is_interior = (self.state == GameState.BUILDING_INTERIOR)
        current_world = self.current_interior if is_interior else self.world
        cam = self.interior_camera if is_interior else self.camera

        self.playtime += dt

        # 시간 & 날씨 (내부에서도 시간은 흐름)
        self.time_system.update(dt)
        if not is_interior:
            self.weather_system.update(dt)

        # 날짜 변경 체크
        self.current_day = self.time_system.current_day
        if self.current_day != self.last_day:
            self.last_day = self.current_day
            self.player.days_survived = self.current_day
            self._on_new_day()

        # 레이드 타이머 차감
        self.raid_time_left -= dt
        if self.raid_time_left <= 0:
            self.raid_time_left = 0
            self.resolve_raid_end(success=False, reason="MIA")
            return

        # 탈출구 탐색 및 업데이트
        self.interaction_handler.update_extraction(dt)
        if self.combat_system is None or self.player.raid_status != "IN_RAID":
            return

        # 플레이어
        weather = self.weather_system.current_weather if not is_interior and self.weather_system else None
        craft_result = self.player.update(dt, current_world, weather, self.time_system)
        if craft_result:
            self.event_system.add_log(t("log_craft_success", craft_result))
            SoundGenerator.play("craft_complete")

        # 카메라
        if cam:
            cam.set_target(self.player.x, self.player.y)
            cam.update(dt)

        # 엔티티 (외부 vs 내부)
        if is_interior:
            self.interior_system.update(dt, current_world)
        else:
            if self.entity_manager is not None:
                self.entity_manager.update(dt, self.player, self.world)
            if self.combat_system is not None and self.entity_manager is not None:
                combat_results = self.combat_system.process_enemy_attacks(self.player, self.entity_manager, self.world)
                for action, enemy, dmg in combat_results:
                    if action == "player_hit":
                        from particles import ParticleEmitters
                        SoundGenerator.play("player_hurt")
                        self.camera.shake(5, 0.2)
                        self.game_particles.emit(
                            lambda: ParticleEmitters.blood(
                                self.player.x * 32, self.player.y * 32), 3)

        # 전투, 이벤트, 파티클
        self.combat_system.update(dt)
        self.event_system.update(dt, self.player, self.current_day)
        self.game_particles.update(dt)

        # 발자국 먼지 (은신 중에는 발생하지 않음)
        if self.player.moving and not self.player.is_crouching and self.player.footstep_timer > 0.3:
            self.player.footstep_timer = 0
            from particles import ParticleEmitters
            self.game_particles.emit(
                lambda: ParticleEmitters.footstep_dust(
                    self.player.x * 32, self.player.y * 32), 2)

        # UI
        self.hud.update(dt, self.player)
        self.inventory_ui.update(dt)
        if hasattr(self, "radio_ui"):
            self.radio_ui.update(dt)
        self.crafting_ui.update(dt)

        # 청크 관리 (외부일 때만)
        if not is_interior:
            self.chunk_unload_timer += dt
            if self.chunk_unload_timer >= 2.0:
                pcx, pcy = self.player.chunk_pos
                self.world.unload_far_chunks(pcx, pcy, 5) # RENDER_DISTANCE is roughly 5 chunks
                self.chunk_unload_timer = 0.0

        # 플레이어 사망 체크
        if not self.player.alive:
            self.transition.start("fade", 1.5,
                on_mid=lambda: self.resolve_raid_end(success=False, reason="KIA"))

    def _on_new_day(self):
        """새로운 날 시작"""
        if self.current_day > self.total_days:
            ending_id, ending_data = determine_ending(self.player)
            self.is_final_ending = True
            self.ending_ui.show(ending_data, self.player)
            self.state = GameState.ENDING
            return

        self.event_system.add_log(t("log_day_header", self.current_day))
        SoundGenerator.play("day_start")

        # 새 날 이벤트
        events = self.event_system.check_new_day_events(self.player, self.current_day)

        # 바이옴 발견 추적
        is_interior = (self.state == GameState.BUILDING_INTERIOR)
        px = self.player.exterior_x if is_interior else self.player.x
        py = self.player.exterior_y if is_interior else self.player.y
        biome = self.world.get_biome(int(px), int(py))
        if biome not in self.player.discovered_biomes:
            self.player.discovered_biomes.add(biome)
            self.event_system.add_log(t("log_new_biome", biome))

        # 자동 저장 (5일마다)
        if self.current_day % 5 == 0:
            self.save_current_game()

    def resolve_raid_end(self, success, reason=""):
        """레이드 세션 종료 및 정산 처리"""
        self.extract_timer = 0.0
        self.extract_target = None
        self.player.raid_status = "NONE"
        
        self.player.is_interior = False
        self.player.moving = False
        self.player.is_sprinting = False

        if success:
            self.event_system.add_log("레이드 탈출에 성공했습니다!")
            ending_data = {
                "title": "레이드 탈출 성공 (SURVIVED)",
                "description": f"무사히 구역을 벗어났습니다. 획득한 전리품을 은신처로 회수합니다.\n생환 사유: {reason}",
            }
            self.player.bleeding = False
            self.player.broken_bone = False
        else:
            self.event_system.add_log(f"레이드 실패: {reason}")
            ending_data = {
                "title": f"레이드 실패 ({reason})",
                "description": "구역에서 돌아오지 못했습니다. 보안 컨테이너 외의 장비와 획득물을 모두 소실했습니다.",
            }
            # 인벤토리 및 무장 초기화 (하베스트 파우치는 Phase 2에서 별도로 보존)
            self.player.inventory.items = []
            
            reclaimed_items = []
            for slot, item_name in list(self.player.equipped.items()):
                if item_name and self.player.equipped_insured.get(slot):
                    if random.random() < 0.60:
                        reclaimed_items.append(item_name)
                        meta = {}
                        if slot == "back":
                            import copy
                            meta = copy.deepcopy(getattr(self.player, "equipped_backpack_meta", {}))
                        else:
                            dur = self.player.equipped_durability.get(slot, 100.0)
                            meta = {"durability": dur}
                        self.player.stash.add_item(item_name, 1, meta)
                self.player.equipped_insured[slot] = False
                
            if reclaimed_items:
                reclaimed_str = ", ".join(reclaimed_items)
                ending_data["description"] += f"\n\n[보험 회수 품목]\n{reclaimed_str}"
                self.event_system.add_log(f"보험 회수 완료: {reclaimed_str}")

            self.player.equipped = {
                "head": None,
                "body": None,
                "feet": None,
                "weapon": None,
                "back": None,
            }
            self.player.hp = self.player.max_hp  # 로비 복귀 후 스탯 초기화
            self.player.stress = 0
            self.player.hunger = 100
            self.player.thirst = 100
            self.player.alive = True
            self.player.bleeding = False
            self.player.broken_bone = False

        # 30일 초과 시 최종 엔딩 판정
        if self.current_day > self.total_days:
            ending_id, ending_data = determine_ending(self.player)
            self.is_final_ending = True

        # 플리마켓 업데이트 및 플레이어 등록 물품 정산
        self.flea_market.update_market_prices(self.current_day)
        self.flea_market.refresh_listings(self.current_day)
        completed_sales, failed_sales = self.flea_market.process_player_sales(self.player)
        
        for sale in completed_sales:
            self.event_system.add_log(f"[마켓] 등록한 {t(sale['item_name'])} {sale['count']}개가 판매되어 {sale['earned']} 루블이 정산되었습니다.")
            
        for failed in failed_sales:
            self.player.stash.add_item(failed["item_name"], failed["count"], {})
            self.event_system.add_log(f"[마켓] 기한 만료된 {t(failed['item_name'])} {failed['count']}개가 창고로 반환되었습니다.")

        # 레이드 리소스 정리 (메모리 누수 방지)
        self.cleanup_raid()

        self.ending_ui.show(ending_data, self.player)
        self.state = GameState.ENDING
        
        # 최종 엔딩이 아닐 때만 즉시 저장
        if not self.is_final_ending:
            self.save_current_game()
        SoundGenerator.play("game_over")

    def cleanup_raid(self):
        """레이드 종료 시 리소스 해제 (메모리 누수 방지)"""
        if self.world:
            for chunk in self.world.chunks.values():
                if hasattr(chunk, 'surface') and chunk.surface:
                    chunk.surface = None
            self.world.chunks.clear()
            self.world.unloaded_deltas.clear()
            self.world = None
            
        self.entity_manager = None
        self.combat_system = None
        if self.game_particles:
            self.game_particles.particles = []
            self.game_particles = None
        self.current_interior = None
        self.interior_building_ref = None
        self.interior_enemies = []
        self.explored_interiors = {}
        self.window_vision = None
        self.active_window_pos = None
        self.last_window_angle = None
        import gc
        gc.collect()

    # ============================================================
    # 렌더링
    # ============================================================
    def _draw(self):
        """상태별 렌더링"""
        if self.state == GameState.MAIN_MENU:
            self.main_menu_ui.draw(self.screen)
            self.menu_particles.draw(self.screen)

        elif self.state == GameState.WORLD_CREATION:
            self.world_creation_ui.draw(self.screen)

        elif self.state == GameState.SETTINGS:
            self.settings_ui.draw(self.screen)

        elif self.state == GameState.PLAYING:
            self._draw_gameplay()

        elif self.state == GameState.BUILDING_INTERIOR:
            self._draw_interior_gameplay()

        elif self.state == GameState.PAUSED:
            if self.prev_state == GameState.HIDEOUT:
                self.hideout_ui.draw(self.screen, self.player)
            elif self.current_interior:
                self._draw_interior_gameplay()
            else:
                self._draw_gameplay()
            self.pause_ui.draw(self.screen)

        elif self.state == GameState.ENDING:
            self.ending_ui.draw(self.screen)

        elif self.state == GameState.SAVE_SLOTS:
            self.save_slots_ui.draw(self.screen)

        elif self.state == GameState.HIDEOUT:
            self.hideout_ui.draw(self.screen, self.player)

        # 지도 오버레이 렌더링
        if self.map_ui and self.map_visible and self.state in (GameState.PLAYING, GameState.BUILDING_INTERIOR):
            self.map_ui.draw(self.screen, self.player, self.world)

        # 전환 효과
        self.transition.draw(self.screen)

        # FPS 표시
        if self.game_settings.show_fps:
            font = FontManager.get(12)
            fps_text = font.render(f"FPS: {int(self.clock.get_fps())}", True, (100, 255, 100))
            self.screen.blit(fps_text, (self.screen_w - 80, 5))

    def _draw_gameplay(self):
        """게임플레이 렌더링"""
        if not self.world or not self.player or not self.camera:
            self.screen.fill(Colors.BLACK)
            return

        # 하늘 색상
        sky_color = self.time_system.get_sky_color()
        self.screen.fill(sky_color)

        # 게임 월드를 렌더링할 서피스
        game_surface = self.screen

        # 타일 렌더링
        self.world_renderer.draw_tiles(game_surface)

        # 바닥 아이템
        self.world_renderer.draw_ground_items(game_surface)

        # 환경 오브젝트
        self.world_renderer.draw_environment(game_surface)

        # 건물
        self.world_renderer.draw_buildings(game_surface)

        # 탈출구 그리기
        self.world_renderer.draw_extraction_points(game_surface)

        # 엔티티 (적, NPC)
        self.world_renderer.draw_entities(game_surface)

        # 플레이어
        self.world_renderer.draw_player(game_surface)
        self.world_renderer.draw_occluding_buildings(game_surface)
        self.world_renderer.draw_aim_indicator(game_surface, self.player.x, self.player.y, self.camera)

        # 전투 이펙트
        self.world_renderer.draw_combat_effects(game_surface)

        # 파티클
        self.game_particles.draw(game_surface, self.camera)

        # 낮밤 오버레이
        self.weather_system.draw_ambient(game_surface, self.time_system)

        # 조명탄 효과 렌더링
        if getattr(self.player, 'flare_timer', 0) > 0:
            px_scr, py_scr = self.camera.world_to_screen(self.player.x, self.player.y) if self.state == GameState.PLAYING else self.interior_camera.world_to_screen(self.player.x, self.player.y)
            flare_light = pygame.Surface((300, 300), pygame.SRCALPHA)
            for r in range(150, 0, -10):
                alpha = int(70 * (1.0 - r / 150.0))
                pygame.draw.circle(flare_light, (250, 240, 200, alpha), (150, 150), r)
            game_surface.blit(flare_light, (px_scr - 150 + 16, py_scr - 150 + 16), special_flags=pygame.BLEND_RGBA_ADD)

        # 날씨 효과
        self.weather_system.draw_effects(game_surface, 0)

        # UI (가장 위에)
        self.hud.draw(game_surface, self.player, self.time_system,
                     self.weather_system, self.current_day, self.total_days,
                     raid_time_left=self.raid_time_left,
                     world=self.world,
                     extract_target=self.extract_target,
                     extract_timer=self.extract_timer,
                     dt=self.dt,
                     extract_points=self.world.extraction_points if self.world else None)

        # 이벤트 로그
        self.event_log_ui.draw(game_surface, self.event_system.event_log)

        # 인벤토리 / 크래프팅
        self.inventory_ui.draw(game_surface, self.player)
        self.crafting_ui.draw(game_surface, self.player)
        
        if hasattr(self, "radio_ui") and self.radio_ui.visible:
            self.radio_ui.draw(game_surface)

        # 대화
        self.dialogue_ui.draw(game_surface)

        # 퀘스트 HUD
        self._draw_quest_hud(game_surface)

        # 상호작용 힌트
        self.world_renderer.draw_interaction_hint(game_surface)

        # 레이드 진입 안내 팝업창
        if self.show_raid_start_popup:
            self._draw_raid_start_popup(game_surface)

    def _draw_interior_gameplay(self):
        """건물 내부 게임플레이 및 UI 렌더링"""
        if not self.player:
            self.screen.fill(Colors.BLACK)
            return

        self.world_renderer.draw_interior(self.screen)

        # UI (가장 위에)
        self.hud.draw(self.screen, self.player, self.time_system,
                     self.weather_system, self.current_day, self.total_days,
                     raid_time_left=self.raid_time_left,
                     world=self.world,
                     extract_target=self.extract_target,
                     extract_timer=self.extract_timer,
                     dt=self.dt,
                     extract_points=self.world.extraction_points if self.world else None)

        # 이벤트 로그
        self.event_log_ui.draw(self.screen, self.event_system.event_log)

        # 인벤토리 / 크래프팅
        self.inventory_ui.draw(self.screen, self.player)
        self.crafting_ui.draw(self.screen, self.player)
        
        if hasattr(self, "radio_ui") and self.radio_ui.visible:
            self.radio_ui.draw(self.screen)

        # 대화
        self.dialogue_ui.draw(self.screen)

        # 퀘스트 HUD
        self._draw_quest_hud(self.screen)

        # 레이드 진입 안내 팝업창
        if self.show_raid_start_popup:
            self._draw_raid_start_popup(self.screen)

    def _draw_quest_hud(self, surface):
        """퀘스트 진행 상황 HUD 렌더링"""
        active_quests = []
        for npc in self.entity_manager.npcs:
            if npc.active and hasattr(npc, 'met') and npc.met and npc.quest_req[0] is not None:
                active_quests.append(npc)
        
        if not active_quests:
            return
            
        font = FontManager.get(10)
        start_x = self.screen_w - 240
        start_y = 60
        
        # 배경 그리기
        max_display = 3
        display_quests = active_quests[:max_display]
        panel_h = 30 + len(display_quests) * 16 + (20 if len(active_quests) > max_display else 0)
        
        bg = pygame.Surface((230, panel_h), pygame.SRCALPHA)
        bg.fill((15, 18, 25, 200))
        surface.blit(bg, (start_x - 10, start_y - 10))
        
        # 제목
        title_surf = FontManager.get(12).render("진행 중인 퀘스트", True, (255, 200, 100))
        surface.blit(title_surf, (start_x, start_y - 5))
        
        for i, npc in enumerate(display_quests):
            req_item, req_count = npc.quest_req
            has = self.player.inventory.count_item(req_item)
            
            translated_item = t(req_item)
            if has >= req_count:
                color = (150, 255, 150)
                text = f"- {translated_item} ({has}/{req_count}) [{t('quest_ready')}]"
            else:
                color = (200, 200, 200)
                text = f"- {translated_item} ({has}/{req_count})"
                
            text_surf = font.render(text, True, color)
            surface.blit(text_surf, (start_x, start_y + 18 + i * 16))
            
        if len(active_quests) > max_display:
            more_surf = font.render(f"...외 {len(active_quests) - max_display}개", True, (150, 150, 150))
            surface.blit(more_surf, (start_x, start_y + 18 + max_display * 16))


    # ============================================================
    # 건물 내부 위임 프로퍼티 (하위 호환성 유지용)
    # ============================================================
    @property
    def current_interior(self):
        return self.interior_system.current_interior

    @current_interior.setter
    def current_interior(self, value):
        self.interior_system.current_interior = value

    @property
    def interior_camera(self):
        return self.interior_system.interior_camera

    @interior_camera.setter
    def interior_camera(self, value):
        self.interior_system.interior_camera = value

    @property
    def interior_building_ref(self):
        return self.interior_system.interior_building_ref

    @interior_building_ref.setter
    def interior_building_ref(self, value):
        self.interior_system.interior_building_ref = value

    @property
    def interior_enemies(self):
        return self.interior_system.interior_enemies

    @interior_enemies.setter
    def interior_enemies(self, value):
        self.interior_system.interior_enemies = value

    @property
    def explored_interiors(self):
        return self.interior_system.explored_interiors

    @explored_interiors.setter
    def explored_interiors(self, value):
        self.interior_system.explored_interiors = value

    @property
    def enemy_intrusion_timer(self):
        return self.interior_system.enemy_intrusion_timer

    @enemy_intrusion_timer.setter
    def enemy_intrusion_timer(self, value):
        self.interior_system.enemy_intrusion_timer = value

    @property
    def window_vision(self):
        return self.interior_system.window_vision

    @window_vision.setter
    def window_vision(self, value):
        self.interior_system.window_vision = value

    @property
    def last_window_angle(self):
        return self.interior_system.last_window_angle

    @last_window_angle.setter
    def last_window_angle(self, value):
        self.interior_system.last_window_angle = value

    @property
    def active_window_pos(self):
        return self.interior_system.active_window_pos

    @active_window_pos.setter
    def active_window_pos(self, value):
        self.interior_system.active_window_pos = value

    def _draw_raid_start_popup(self, surface):
        """레이드 진입 안내 팝업창 렌더링"""
        # 화면 어둡게 오버레이
        overlay = pygame.Surface((self.screen_w, self.screen_h), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 180))
        surface.blit(overlay, (0, 0))
        
        # 팝업 패널 설정 (가로 340, 세로 220)
        pw, ph = 340, 220
        px = (self.screen_w - pw) // 2
        py = (self.screen_h - ph) // 2
        
        # 배경 그리기 (글래스모피즘 연출)
        draw_rounded_rect(surface, (18, 22, 36, 240), (px, py, pw, ph), radius=10)
        pygame.draw.rect(surface, (100, 110, 130), (px, py, pw, ph), 1, border_radius=10)
        
        font_title = FontManager.get(15)
        font_body = FontManager.get(12)
        font_btn = FontManager.get(13)
        
        # 제목 및 경고 문구
        title_surf = font_title.render("레이드 진입 안내", True, (255, 100, 100))
        surface.blit(title_surf, (px + (pw - title_surf.get_width()) // 2, py + 20))
        
        lines = [
            "현재 위험한 레이드 지역에 진입했습니다.",
            "레이드 도중 사망 시 무장과 가방이 소실됩니다.",
            "지금 바로 레이드를 시작하시겠습니까?"
        ]
        for idx, line in enumerate(lines):
            body_surf = font_body.render(line, True, Colors.UI_TEXT)
            surface.blit(body_surf, (px + (pw - body_surf.get_width()) // 2, py + 60 + idx * 20))
            
        # 버튼 1: 은신처로 돌아가기 (퇴각)
        btn1_color = (180, 60, 60, 220)
        draw_rounded_rect(surface, btn1_color, (px + 30, py + 130, 280, 32), radius=5)
        pygame.draw.rect(surface, (220, 80, 80), (px + 30, py + 130, 280, 32), 1, border_radius=5)
        btn1_lbl = font_btn.render("은신처로 돌아가기 (퇴각)", True, Colors.WHITE)
        surface.blit(btn1_lbl, (px + 30 + (280 - btn1_lbl.get_width()) // 2, py + 130 + (32 - btn1_lbl.get_height()) // 2))
        
        # 버튼 2: 레이드 계속하기 (진입)
        btn2_color = (45, 135, 90, 220)
        draw_rounded_rect(surface, btn2_color, (px + 30, py + 172, 280, 32), radius=5)
        pygame.draw.rect(surface, (70, 180, 120), (px + 30, py + 172, 280, 32), 1, border_radius=5)
        btn2_lbl = font_btn.render("레이드 계속하기 (진입)", True, Colors.WHITE)
        surface.blit(btn2_lbl, (px + 30 + (280 - btn2_lbl.get_width()) // 2, py + 172 + (32 - btn2_lbl.get_height()) // 2))


# ============================================================
# 엔트리포인트
# ============================================================
if __name__ == "__main__":
    game = Game()
    game.run()