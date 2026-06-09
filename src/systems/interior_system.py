"""
interior_system.py - 건물 내부 시스템 및 창문 시야 처리 매니저
OOP 리팩토링의 일환으로 main.py의 비대한 실내 관련 로직을 캡슐화합니다.
"""
import math
import random
import pygame
from settings import TILE_SIZE
from camera import Camera
from entities import Enemy, EnemyState
from items import ITEM_DATABASE
from particles import ParticleEmitters
from sounds import SoundGenerator
from i18n import t
import zlib

def get_building_hash(building_id):
    return zlib.crc32(building_id.encode('utf-8'))


class InteriorSystem:
    """건물 내부(Building Interior) 상태 및 시야 계산, 행동 전담 매니저"""

    def __init__(self, game):
        self.game = game
        
        # 상태 변수 캡슐화
        self.current_interior = None       # BuildingInterior 객체
        self.interior_camera = None        # 내부용 카메라
        self.interior_building_ref = None   # 외부 건물 참조
        self.interior_enemies = []         # 내부 은신형 적
        self.explored_interiors = {}       # 건물_id -> BuildingInterior (델타 저장)
        self.enemy_intrusion_timer = 0.0   # 야외 적 건물 침입 주기 타이머
        self.window_vision = None          # 창문 시야 데이터
        self.last_window_angle = None      # 창문의 마지막 유효 시야 각도
        self.active_window_pos = None      # 현재 주시 중인 창문 위치

    def enter_building(self, building):
        """건물 내부로 진입 처리"""
        building_id = f"{building.x}_{building.y}"

        # 이미 탐색한 건물이면 기존 내부 복원, 아니면 새로 생성
        if building_id in self.explored_interiors:
            self.current_interior = self.explored_interiors[building_id]
        else:
            from building_interior import BuildingInterior
            # 50% chance to have 2 floors
            from utils import seeded_random
            max_floors = 2 if getattr(building, "building_type", "house") != "barn" and seeded_random(get_building_hash(building_id), 0.5) else 1
            
            self.current_interior = BuildingInterior(
                building.building_type,
                building.width, building.height,
                seed=get_building_hash(building_id) + (self.game.world.seed if self.game.world else 0),
                floor_idx=0,
                max_floors=max_floors
            )
            self.explored_interiors[building_id] = self.current_interior

        self.interior_building_ref = building
        # 플레이어 스폰 위치 조정 (내부 문 바로 앞)
        self.game.player.enter_interior(float(self.current_interior.door_pos[0]), float(self.current_interior.door_pos[1] - 1))

        # 내부 카메라 인스턴스화
        self.interior_camera = Camera()
        self.interior_camera.resize(self.game.screen_w, self.game.screen_h)

        # 적 인스턴스 복원
        self.interior_enemies = []
        for edata in self.current_interior.enemies:
            e_type = edata.get("type", "normal")
            e = Enemy(edata["x"], edata["y"], e_type, self.game.difficulty)
            e.speed *= 0.5  # 은신형 적은 야외보다 느림
            e.detection_range = 3
            if "hp" in edata:
                e.hp = edata["hp"]
            self.interior_enemies.append(e)

        # 추적 중이던 야외 적 유입
        MAX_INTERIOR_ENEMIES = 8
        if self.game.entity_manager:
            door_x, door_y = building.door_x, building.door_y
            nearby_outdoor = self.game.entity_manager.get_nearby_enemies(door_x, door_y, 8)
            for oe in nearby_outdoor:
                if len(self.interior_enemies) >= MAX_INTERIOR_ENEMIES:
                    break
                if oe.state in (EnemyState.ENGAGE, EnemyState.FLANK, EnemyState.ALERT):
                    ix = float(self.current_interior.door_pos[0])
                    iy = float(self.current_interior.door_pos[1] - 2)
                    ie = Enemy(ix, iy, oe.enemy_type, self.game.difficulty)
                    ie.hp = oe.hp
                    ie.state = EnemyState.ENGAGE
                    self.interior_enemies.append(ie)
                    oe.active = False
            if len(self.interior_enemies) > len(self.current_interior.enemies):
                self.game.event_system.add_log(t("enemy_followed"))

        self.enemy_intrusion_timer = 0.0

        if not building.explored:
            building.explored = True
            self.game.player.buildings_explored += 1

        SoundGenerator.play("door_open")
        self.game.event_system.add_log(t("entering_building"))

        from main import GameState
        self.game.transition.start("fade", 0.5,
            on_mid=lambda: setattr(self.game, 'state', GameState.BUILDING_INTERIOR))

    def exit_building(self):
        """건물에서 퇴장 처리"""
        b = self.interior_building_ref
        followed_enemies = []
        remaining_interior_enemies = []

        for e in self.interior_enemies:
            if not e.is_dead and e.active:
                if e.state in (EnemyState.ENGAGE, EnemyState.FLANK, EnemyState.ALERT) and b:
                    followed_enemies.append(e)
                else:
                    remaining_interior_enemies.append(e)

        # 내부의 남은 적 상태 동기화
        if self.current_interior is not None:
            self.current_interior.enemies = [
                {"x": e.x, "y": e.y, "hp": e.hp, "type": e.enemy_type}
                for e in remaining_interior_enemies
            ]
        
        self.game.player.exit_interior()
        self.current_interior = None
        self.interior_building_ref = None
        self.interior_enemies = []

        # 문 밖으로 따라 나온 적들을 야외 맵에 인스턴스화
        if b and self.game.entity_manager and followed_enemies:
            for fe in followed_enemies:
                spawn_x = float(b.door_x) + random.uniform(-0.5, 0.5)
                spawn_y = float(b.door_y) + 1.2
                oe = Enemy(spawn_x, spawn_y, fe.enemy_type, self.game.difficulty)
                oe.hp = fe.hp
                oe.state = EnemyState.ENGAGE
                self.game.entity_manager.enemies.append(oe)
            self.game.event_system.add_log(t("enemy_followed_outside"))

        SoundGenerator.play("door_open")
        self.game.event_system.add_log(t("exiting_building"))

        from main import GameState
        self.game.transition.start("fade", 0.5,
            on_mid=lambda: setattr(self.game, 'state', GameState.PLAYING))

    def go_upstairs(self):
        """위층으로 이동"""
        if not self.current_interior or not self.interior_building_ref:
            return
            
        b = self.interior_building_ref
        building_id = f"{b.x}_{b.y}_floor_{self.current_interior.floor_idx + 1}"
        
        # 적 상태 저장
        self._save_current_floor_enemies()
        
        if building_id in self.explored_interiors:
            self.current_interior = self.explored_interiors[building_id]
        else:
            from building_interior import BuildingInterior
            self.current_interior = BuildingInterior(
                b.building_type,
                b.width, b.height,
                seed=get_building_hash(building_id) + (self.game.world.seed if self.game.world else 0),
                floor_idx=self.current_interior.floor_idx + 1,
                max_floors=self.current_interior.max_floors
            )
            self.explored_interiors[building_id] = self.current_interior
            
        self._load_current_floor_enemies()
        
        # 윗층으로 올라가면 플레이어 위치는 내려가는 계단(door_pos) 앞
        self.game.player.enter_interior(float(self.current_interior.door_pos[0]), float(self.current_interior.door_pos[1] - 1))
        
        SoundGenerator.play("door_open") # 계단 소리로 대체 가능
        self.game.transition.start("fade", 0.5)
        
    def go_downstairs(self):
        """아래층으로 이동"""
        if not self.current_interior or not self.interior_building_ref:
            return
            
        b = self.interior_building_ref
        
        # 1층으로 가는 경우 0층
        next_idx = self.current_interior.floor_idx - 1
        building_id = f"{b.x}_{b.y}" if next_idx == 0 else f"{b.x}_{b.y}_floor_{next_idx}"
        
        # 적 상태 저장
        self._save_current_floor_enemies()
        
        if building_id in self.explored_interiors:
            self.current_interior = self.explored_interiors[building_id]
            
        self._load_current_floor_enemies()
        
        # 아래층으로 내려가면 플레이어 위치는 올라가는 계단 앞
        # 올라가는 계단(stairs_up) 타일 찾기
        spawn_x, spawn_y = self.current_interior.width // 2, self.current_interior.height // 2
        for y in range(self.current_interior.height):
            for x in range(self.current_interior.width):
                if self.current_interior.tiles[y][x] == "stairs_up":
                    spawn_x, spawn_y = x, y + 1
                    break
                    
        self.game.player.enter_interior(float(spawn_x), float(spawn_y))
        
        SoundGenerator.play("door_open")
        self.game.transition.start("fade", 0.5)

    def _save_current_floor_enemies(self):
        if self.current_interior:
            self.current_interior.enemies = [
                {"x": e.x, "y": e.y, "hp": e.hp, "type": e.enemy_type}
                for e in self.interior_enemies if not e.is_dead
            ]
            
    def _load_current_floor_enemies(self):
        self.interior_enemies = []
        for edata in self.current_interior.enemies:
            e_type = edata.get("type", "normal")
            e = Enemy(edata["x"], edata["y"], e_type, self.game.difficulty)
            e.speed *= 0.5
            e.detection_range = 3
            if "hp" in edata:
                e.hp = edata["hp"]
            self.interior_enemies.append(e)

    def handle_interior_attack(self):
        """실내 공격 및 탄약 소모 판정"""
        if not self.game.player.attack_cooldown.is_ready("attack"):
            return

        weapon = self.game.player.equipped.get("weapon")
        weapon_data = ITEM_DATABASE.get(weapon, {}) if weapon else {}
        weapon_type = weapon_data.get("type", "melee")
        speed = weapon_data.get("speed", 1.0)
        self.game.player.attack_cooldown.set_cooldown("attack", speed)

        damage = self.game.player.get_attack_damage()
        attack_range = self.game.player.get_attack_range()

        mouse_sx, mouse_sy = pygame.mouse.get_pos()
        mouse_wx, mouse_wy = self.interior_camera.screen_to_world(mouse_sx, mouse_sy)

        px, py = self.game.player.x, self.game.player.y
        attack_angle = math.atan2(mouse_wy - py, mouse_wx - px)
        
        hit_enemies = []
        from combat import angle_diff

        if weapon_type == "melee":
            for e in self.interior_enemies:
                if e.is_dead or not e.active:
                    continue
                dist = math.sqrt((e.x - px)**2 + (e.y - py)**2)
                if dist <= attack_range:
                    angle_to_target = math.atan2(e.y - py, e.x - px)
                    if abs(angle_diff(attack_angle, angle_to_target)) <= math.pi / 6:
                        hit_enemies.append(e)
        else:
            closest_e = None
            min_dist = 999.0
            for e in self.interior_enemies:
                if e.is_dead or not e.active:
                    continue
                dist = math.sqrt((e.x - px)**2 + (e.y - py)**2)
                if dist <= attack_range:
                    angle_to_target = math.atan2(e.y - py, e.x - px)
                    if abs(angle_diff(attack_angle, angle_to_target)) <= math.pi / 12:
                        if dist < min_dist:
                            min_dist = dist
                            closest_e = e
            if closest_e:
                hit_enemies.append(closest_e)

        if weapon_type == "melee":
            SoundGenerator.play("melee_swing")
            self.game.player.stamina = max(0, self.game.player.stamina - 5)
        else:
            SoundGenerator.play("gunshot")
            self.game._trigger_gunshot_noise(px, py, True)

        for e in hit_enemies:
            e.take_damage(damage)
            actual_damage = damage
            self.game.combat_system.damage_numbers.append((e.x, e.y - 0.5, actual_damage, 1.0, (255, 255, 100)))
            if weapon_type == "melee":
                SoundGenerator.play("hit_melee")
                self.interior_camera.shake(3, 0.15)
            self.game.game_particles.emit(lambda: ParticleEmitters.blood(e.x * TILE_SIZE, e.y * TILE_SIZE))
            
            kb_dist = 1.0 if weapon_type == "melee" else 0.5
            angle = math.atan2(e.y - py, e.x - px)
            e.x += math.cos(angle) * kb_dist
            e.y += math.sin(angle) * kb_dist
            
            if e.is_dead:
                self.game.player.killed_enemies += 1
                self.game.event_system.add_log(t("log_enemy_killed"))
                loot = e.get_loot() if hasattr(e, 'get_loot') else []
                for item_name in loot:
                    if self.current_interior:
                        self.current_interior.drop_item(item_name, e.x, e.y)
                    self.game.event_system.add_log(f"  [{item_name}] 드롭!")

    def update(self, dt, current_world):
        """실내 업데이트 주기 관리"""
        # 1. 내부 적 물리 및 공격 갱신
        for e in self.interior_enemies:
            if not e.is_dead and e.active:
                e.update(dt, self.game.player.x, self.game.player.y, current_world, self.game.player.is_crouching)
                if e.state == EnemyState.ENGAGE and e.can_attack():
                    damage = e.do_attack()
                    actual = self.game.player.take_damage(damage, t("stealth_enemy"))
                    if actual > 0:
                        self.game.combat_system.damage_numbers.append((self.game.player.x, self.game.player.y - 0.5, actual, 1.0, (255, 60, 60)))
                        self.game.event_system.add_log(t("log_stealth_enemy_damage", int(actual)))
                        if self.game.camera:
                            self.game.camera.shake(3, 0.2)
                        if self.interior_camera:
                            self.interior_camera.shake(3, 0.2)

        # 2. 야외 추적 중인 적 침입 판단
        MAX_INTERIOR_ENEMIES = 8
        self.enemy_intrusion_timer += dt
        if self.enemy_intrusion_timer >= 3.0 and self.interior_building_ref and self.game.entity_manager:
            self.enemy_intrusion_timer = 0.0
            bref = self.interior_building_ref
            door_x, door_y = bref.door_x, bref.door_y
            nearby = self.game.entity_manager.get_nearby_enemies(door_x, door_y, 5)
            for oe in nearby:
                if len(self.interior_enemies) >= MAX_INTERIOR_ENEMIES:
                    break
                if oe.state in (EnemyState.ENGAGE, EnemyState.FLANK, EnemyState.ALERT):
                    ix = float(self.current_interior.door_pos[0])
                    iy = float(self.current_interior.door_pos[1] - 2)
                    ie = Enemy(ix, iy, oe.enemy_type, self.game.difficulty)
                    ie.hp = oe.hp
                    ie.state = EnemyState.ENGAGE
                    self.interior_enemies.append(ie)
                    oe.active = False
                    self.game.event_system.add_log(t("enemy_intrusion"))
                    SoundGenerator.play("enemy_die")
                    if self.interior_camera:
                        self.interior_camera.shake(5, 0.3)

        # 3. 창문 시야 오버레이 계산
        self.window_vision = None
        if self.current_interior and self.interior_building_ref:
            win = self.current_interior.get_nearby_window(self.game.player.x, self.game.player.y, 1.5)
            if win:
                bref = self.interior_building_ref
                # 창문 위치의 외부 좌표 환산
                ratio_x = win["x"] / max(1, self.current_interior.width)
                ratio_y = win["y"] / max(1, self.current_interior.height)
                world_x = bref.x + ratio_x * bref.width
                world_y = bref.y + ratio_y * bref.height
                
                # 창문 기본 시선 각도
                base_angle = math.atan2(win["dir_y"], win["dir_x"])
                
                win_pos = (win["x"], win["y"])
                if self.active_window_pos != win_pos:
                    self.active_window_pos = win_pos
                    self.last_window_angle = base_angle

                # 마우스 이동에 연동한 시야각 미세 보정
                mouse_sx, mouse_sy = pygame.mouse.get_pos()
                if self.interior_camera:
                    mouse_wx, mouse_wy = self.interior_camera.screen_to_world(mouse_sx, mouse_sy)
                    mouse_angle = math.atan2(mouse_wy - win["y"], mouse_wx - win["x"])
                    
                    max_diff = math.pi / 3  # 60도 FOV 제한
                    diff = (mouse_angle - base_angle + math.pi) % (2 * math.pi) - math.pi
                    if abs(diff) <= max_diff:
                        self.last_window_angle = mouse_angle
                    
                    final_angle = self.last_window_angle if self.last_window_angle is not None else base_angle
                else:
                    final_angle = base_angle
                    
                view_dir_x = math.cos(final_angle)
                view_dir_y = math.sin(final_angle)

                vision_range = 8
                look_x = world_x + view_dir_x * vision_range * 0.5
                look_y = world_y + view_dir_y * vision_range * 0.5
                
                # 시야각(60도 콘) 범위 내 야외 적 인지 필터링
                visible_enemies = []
                if self.game.entity_manager:
                    outdoor_e = self.game.entity_manager.get_nearby_enemies(look_x, look_y, vision_range)
                    for oe in outdoor_e:
                        dx = oe.x - world_x
                        dy = oe.y - world_y
                        angle_to = math.atan2(dy, dx)
                        e_diff = abs((angle_to - final_angle + math.pi) % (2 * math.pi) - math.pi)
                        if e_diff <= math.pi / 6:
                            visible_enemies.append({
                                "x": oe.x,
                                "y": oe.y,
                                "type": oe.enemy_type,
                                "state": oe.state
                            })

                self.window_vision = {
                    "win": win,
                    "world_x": world_x,
                    "world_y": world_y,
                    "dir_x": view_dir_x,
                    "dir_y": view_dir_y,
                    "range": vision_range,
                    "enemies": visible_enemies,
                }
            else:
                self.active_window_pos = None
                self.last_window_angle = None
        else:
            self.active_window_pos = None
            self.last_window_angle = None
