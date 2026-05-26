"""
interior_system.py - 건물 내부 시스템 및 창문 시야 처리 매니저
OOP 리팩토링의 일환으로 main.py의 비대한 실내 관련 로직을 캡슐화합니다.
"""
import math
import random
import pygame
from settings import TILE_SIZE
from camera import Camera
from entities import Zombie, ZombieState
from items import ITEM_DATABASE
from particles import ParticleEmitters
from sounds import SoundGenerator
from i18n import t


class InteriorSystem:
    """건물 내부(Building Interior) 상태 및 시야 계산, 행동 전담 매니저"""

    def __init__(self, game):
        self.game = game
        
        # 상태 변수 캡슐화
        self.current_interior = None       # BuildingInterior 객체
        self.interior_camera = None        # 내부용 카메라
        self.interior_building_ref = None   # 외부 건물 참조
        self.interior_zombies = []         # 내부 은신형 좀비
        self.explored_interiors = {}       # 건물_id -> BuildingInterior (델타 저장)
        self.zombie_intrusion_timer = 0.0  # 야외 좀비 건물 침입 주기 타이머
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
            self.current_interior = BuildingInterior(
                building.building_type,
                building.width, building.height,
                seed=hash(building_id) + (self.game.world.seed if self.game.world else 0)
            )
            self.explored_interiors[building_id] = self.current_interior

        self.interior_building_ref = building
        # 플레이어 스폰 위치 조정 (내부 문 바로 앞)
        self.game.player.enter_interior(float(self.current_interior.door_pos[0]), float(self.current_interior.door_pos[1] - 1))

        # 내부 카메라 인스턴스화
        self.interior_camera = Camera()
        self.interior_camera.resize(self.game.screen_w, self.game.screen_h)

        # 좀비 인스턴스 복원
        self.interior_zombies = []
        for zdata in self.current_interior.zombies:
            z_type = zdata.get("type", "normal")
            z = Zombie(zdata["x"], zdata["y"], z_type, self.game.difficulty)
            z.speed *= 0.5  # 은신형 좀비는 야외보다 느림
            z.detection_range = 3
            if "hp" in zdata:
                z.hp = zdata["hp"]
            self.interior_zombies.append(z)

        # 추적 중이던 야외 좀비 유입
        MAX_INTERIOR_ZOMBIES = 8
        if self.game.entity_manager:
            door_x, door_y = building.door_x, building.door_y
            nearby_outdoor = self.game.entity_manager.get_nearby_zombies(door_x, door_y, 8)
            for oz in nearby_outdoor:
                if len(self.interior_zombies) >= MAX_INTERIOR_ZOMBIES:
                    break
                if oz.state in (ZombieState.ENGAGE, ZombieState.FLANK, ZombieState.ALERT):
                    ix = float(self.current_interior.door_pos[0])
                    iy = float(self.current_interior.door_pos[1] - 2)
                    iz = Zombie(ix, iy, oz.zombie_type, self.game.difficulty)
                    iz.hp = oz.hp
                    iz.state = ZombieState.ENGAGE
                    self.interior_zombies.append(iz)
                    oz.active = False
            if len(self.interior_zombies) > len(self.current_interior.zombies):
                self.game.event_system.add_log(t("zombie_followed"))

        self.zombie_intrusion_timer = 0.0

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
        followed_zombies = []
        remaining_interior_zombies = []

        for z in self.interior_zombies:
            if not z.is_dead and z.active:
                if z.state in (ZombieState.ENGAGE, ZombieState.FLANK, ZombieState.ALERT) and b:
                    followed_zombies.append(z)
                else:
                    remaining_interior_zombies.append(z)

        # 내부의 남은 좀비 상태 동기화
        if self.current_interior is not None:
            self.current_interior.zombies = [
                {"x": z.x, "y": z.y, "hp": z.hp, "type": z.zombie_type}
                for z in remaining_interior_zombies
            ]
        
        self.game.player.exit_interior()
        self.current_interior = None
        self.interior_building_ref = None
        self.interior_zombies = []

        # 문 밖으로 따라 나온 적들을 야외 맵에 인스턴스화
        if b and self.game.entity_manager and followed_zombies:
            for fz in followed_zombies:
                spawn_x = float(b.door_x) + random.uniform(-0.5, 0.5)
                spawn_y = float(b.door_y) + 1.2
                oz = Zombie(spawn_x, spawn_y, fz.zombie_type, self.game.difficulty)
                oz.hp = fz.hp
                oz.state = ZombieState.ENGAGE
                self.game.entity_manager.zombies.append(oz)
            self.game.event_system.add_log(t("zombie_followed_outside"))

        SoundGenerator.play("door_open")
        self.game.event_system.add_log(t("exiting_building"))

        from main import GameState
        self.game.transition.start("fade", 0.5,
            on_mid=lambda: setattr(self.game, 'state', GameState.PLAYING))

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
        
        hit_zombies = []
        from combat import angle_diff

        if weapon_type == "melee":
            for z in self.interior_zombies:
                if z.is_dead or not z.active:
                    continue
                dist = math.sqrt((z.x - px)**2 + (z.y - py)**2)
                if dist <= attack_range:
                    angle_to_target = math.atan2(z.y - py, z.x - px)
                    if abs(angle_diff(attack_angle, angle_to_target)) <= math.pi / 6:
                        hit_zombies.append(z)
        else:
            closest_z = None
            min_dist = 999.0
            for z in self.interior_zombies:
                if z.is_dead or not z.active:
                    continue
                dist = math.sqrt((z.x - px)**2 + (z.y - py)**2)
                if dist <= attack_range:
                    angle_to_target = math.atan2(z.y - py, z.x - px)
                    if abs(angle_diff(attack_angle, angle_to_target)) <= math.pi / 12:
                        if dist < min_dist:
                            min_dist = dist
                            closest_z = z
            if closest_z:
                hit_zombies.append(closest_z)

        if weapon_type == "melee":
            SoundGenerator.play("melee_swing")
            self.game.player.stamina = max(0, self.game.player.stamina - 5)
        else:
            SoundGenerator.play("gunshot")
            self.game._trigger_gunshot_noise(px, py, True)

        for z in hit_zombies:
            z.take_damage(damage)
            actual_damage = damage
            self.game.combat_system.damage_numbers.append((z.x, z.y - 0.5, actual_damage, 1.0, (255, 255, 100)))
            if weapon_type == "melee":
                SoundGenerator.play("hit_melee")
                self.interior_camera.shake(3, 0.15)
            self.game.game_particles.emit(lambda: ParticleEmitters.blood(z.x * TILE_SIZE, z.y * TILE_SIZE))
            
            kb_dist = 1.0 if weapon_type == "melee" else 0.5
            angle = math.atan2(z.y - py, z.x - px)
            z.x += math.cos(angle) * kb_dist
            z.y += math.sin(angle) * kb_dist
            
            if z.is_dead:
                self.game.player.killed_zombies += 1
                self.game.event_system.add_log(t("zombie_killed"))
                loot = z.get_loot() if hasattr(z, 'get_loot') else []
                for item_name in loot:
                    if self.current_interior:
                        self.current_interior.drop_item(item_name, z.x, z.y)
                    self.game.event_system.add_log(f"  [{item_name}] 드롭!")

    def update(self, dt, current_world):
        """실내 업데이트 주기 관리"""
        # 1. 내부 좀비 물리 및 공격 갱신
        for z in self.interior_zombies:
            if not z.is_dead and z.active:
                z.update(dt, self.game.player.x, self.game.player.y, current_world, self.game.player.is_crouching)
                if z.state == ZombieState.ENGAGE and z.can_attack():
                    damage = z.do_attack()
                    actual = self.game.player.take_damage(damage, t("stealth_zombie"))
                    if actual > 0:
                        self.game.combat_system.damage_numbers.append((self.game.player.x, self.game.player.y - 0.5, actual, 1.0, (255, 60, 60)))
                        self.game.event_system.add_log(t("log_stealth_zombie_damage", int(actual)))
                        if self.game.camera:
                            self.game.camera.shake(3, 0.2)
                        if self.interior_camera:
                            self.interior_camera.shake(3, 0.2)

        # 2. 야외 추적 중인 좀비 침입 판단
        MAX_INTERIOR_ZOMBIES = 8
        self.zombie_intrusion_timer += dt
        if self.zombie_intrusion_timer >= 3.0 and self.interior_building_ref and self.game.entity_manager:
            self.zombie_intrusion_timer = 0.0
            bref = self.interior_building_ref
            door_x, door_y = bref.door_x, bref.door_y
            nearby = self.game.entity_manager.get_nearby_zombies(door_x, door_y, 5)
            for oz in nearby:
                if len(self.interior_zombies) >= MAX_INTERIOR_ZOMBIES:
                    break
                if oz.state in (ZombieState.ENGAGE, ZombieState.FLANK, ZombieState.ALERT):
                    ix = float(self.current_interior.door_pos[0])
                    iy = float(self.current_interior.door_pos[1] - 2)
                    iz = Zombie(ix, iy, oz.zombie_type, self.game.difficulty)
                    iz.hp = oz.hp
                    iz.state = ZombieState.ENGAGE
                    self.interior_zombies.append(iz)
                    oz.active = False
                    self.game.event_system.add_log(t("zombie_intrusion"))
                    SoundGenerator.play("zombie_die")
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
                
                # 시야각(60도 콘) 범위 내 야외 좀비 인지 필터링
                visible_zombies = []
                if self.game.entity_manager:
                    outdoor_z = self.game.entity_manager.get_nearby_zombies(look_x, look_y, vision_range)
                    for oz in outdoor_z:
                        dx = oz.x - world_x
                        dy = oz.y - world_y
                        angle_to = math.atan2(dy, dx)
                        z_diff = abs((angle_to - final_angle + math.pi) % (2 * math.pi) - math.pi)
                        if z_diff <= math.pi / 6:
                            visible_zombies.append({
                                "x": oz.x,
                                "y": oz.y,
                                "type": oz.zombie_type,
                                "state": oz.state
                            })

                self.window_vision = {
                    "win": win,
                    "world_x": world_x,
                    "world_y": world_y,
                    "dir_x": view_dir_x,
                    "dir_y": view_dir_y,
                    "range": vision_range,
                    "zombies": visible_zombies,
                }
            else:
                self.active_window_pos = None
                self.last_window_angle = None
        else:
            self.active_window_pos = None
            self.last_window_angle = None
