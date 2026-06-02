"""
combat.py - 전투 시스템
마우스 방향 기반 부채꼴 판정, 원거리 조준
"""
import math
import random
import pygame
from utils import distance, direction_to, angle_between
from items import ITEM_DATABASE
from settings import TILE_SIZE


def angle_diff(a, b):
    """두 각도(라디안) 사이의 최소 차이 (정규화)"""
    d = (a - b) % (2 * math.pi)
    if d > math.pi:
        d -= 2 * math.pi
    return abs(d)


class CombatSystem:
    """전투 로직 관리"""

    def __init__(self):
        self.hit_effects = []   # [(x, y, timer)]
        self.damage_numbers = []  # [(x, y, damage, timer, color)]
        self.tracers = []       # [{"start": (x,y), "end": (x,y), "color": (r,g,b), "timer": t, "max_timer": t}]

    def update(self, dt):
        self.hit_effects = [(x, y, t - dt) for x, y, t in self.hit_effects if t > 0]
        self.damage_numbers = [(x, y - dt * 30, d, t - dt, c)
                               for x, y, d, t, c in self.damage_numbers if t > 0]
        for tr in self.tracers:
            tr["timer"] -= dt
        self.tracers = [tr for tr in self.tracers if tr["timer"] > 0]

    def player_attack(self, player, entity_manager, world, camera=None):
        """플레이어 공격 (camera 필요: 마우스→월드 좌표 변환)"""
        if not player.attack_cooldown.is_ready("attack"):
            return None

        weapon = player.equipped.get("weapon")
        weapon_data = ITEM_DATABASE.get(weapon, {}) if weapon else {}
        weapon_type = weapon_data.get("type", "melee")

        damage = player.get_attack_damage()
        attack_range = player.get_attack_range()

        # 마우스 방향 → 월드 좌표 → 공격 각도
        mouse_sx, mouse_sy = pygame.mouse.get_pos()
        center_x = player.x + 0.5
        center_y = player.y + 0.5
        
        if camera:
            # 스크린 좌표 → 월드 좌표
            mouse_wx, mouse_wy = camera.screen_to_world(mouse_sx, mouse_sy)
        else:
            mouse_wx = center_x + 1
            mouse_wy = center_y

        attack_angle = math.atan2(mouse_wy - center_y, mouse_wx - center_x)

        results = []

        if weapon_type == "melee":
            # 근접 공격 - 부채꼴 60° (±30°) 판정
            MELEE_ARC = math.pi / 3  # 60도
            targets = entity_manager.get_nearby_zombies(center_x, center_y, attack_range + 0.5)

            for zombie in targets:
                zx = zombie.x + 0.5
                zy = zombie.y + 0.5
                if distance(zx, zy, center_x, center_y) > attack_range:
                    continue
                target_angle = math.atan2(zy - center_y, zx - center_x)
                if angle_diff(target_angle, attack_angle) > MELEE_ARC / 2:
                    continue  # 부채꼴 밖 → 미스

                actual_damage = damage + random.randint(-2, 3)
                kb_dir = direction_to(player.x, player.y, zombie.x, zombie.y)
                zombie.take_damage(actual_damage, kb_dir)

                self.hit_effects.append((zombie.x, zombie.y, 0.3))
                self.damage_numbers.append((zombie.x, zombie.y - 0.5, actual_damage, 1.0, (255, 255, 100)))
                results.append(("hit", zombie, actual_damage))

                if zombie.is_dead:
                    player.killed_zombies += 1
                    results.append(("kill", zombie, 0))

        elif weapon_type == "ranged":
            ammo_type = weapon_data.get("ammo")
            if ammo_type and not player.inventory.has_item(ammo_type):
                results.append(("no_ammo", None, 0))
            else:
                if ammo_type:
                    player.inventory.remove_item(ammo_type, 1)

                # 반동 누적 (연사 시 정확도 감소)
                player.recoil_stack = min(15.0, player.recoil_stack + weapon_data.get("recoil", 3.0))

                # 총성 발사 신호 (어그로 트리거용)
                results.append(("gunshot_fired", None, 0))

                # 탄 퍼짐 적용 (반동 + 기본 스프레드)
                base_spread = weapon_data.get("spread", 0.05)  # 라디안
                recoil_spread = player.recoil_stack * 0.015  # 반동 누적에 비례한 추가 퍼짐

                # 조준 버프 활성 시 스프레드 50% 감소
                if player.aim_buff_timer > 0:
                    base_spread *= 0.5
                    recoil_spread *= 0.5

                total_spread = base_spread + recoil_spread
                # 탄퍼짐 각도 가우시안 오프셋 적용
                attack_angle += random.gauss(0, total_spread)

                # 마우스 방향에서 가장 가까운 적 (±15° 내)
                RANGED_ARC = math.pi / 6  # 30도
                targets = entity_manager.get_nearby_zombies(center_x, center_y, attack_range + 0.5)
                valid = []
                for z in targets:
                    zx = z.x + 0.5
                    zy = z.y + 0.5
                    if distance(zx, zy, center_x, center_y) > attack_range:
                        continue
                    t_angle = math.atan2(zy - center_y, zx - center_x)
                    if angle_diff(t_angle, attack_angle) <= RANGED_ARC:
                        valid.append(z)

                start_x, start_y = center_x, center_y
                if valid:
                    target = min(valid, key=lambda z: distance(z.x + 0.5, z.y + 0.5, center_x, center_y))
                    dist = distance(target.x + 0.5, target.y + 0.5, center_x, center_y)
                    end_x, end_y = target.x + 0.5, target.y + 0.5
                    
                    # 비선형 대미지 감쇠 탄도식 적용
                    k = 0.08 if weapon == "권총" else (0.015 if weapon == "레버액션 소총" else 0.05)
                    base_dmg = damage + random.randint(-3, 5)
                    actual_damage = max(1, int(base_dmg * math.exp(-k * dist)))
                    
                    kb_dir = direction_to(center_x, center_y, target.x, target.y)
                    target.take_damage(actual_damage, kb_dir)

                    self.hit_effects.append((target.x, target.y, 0.3))
                    self.damage_numbers.append((target.x, target.y - 0.5, actual_damage, 1.0, (255, 200, 50)))
                    results.append(("hit", target, actual_damage))

                    if target.is_dead:
                        player.killed_zombies += 1
                        results.append(("kill", target, 0))
                else:
                    end_x = center_x + math.cos(attack_angle) * attack_range
                    end_y = center_y + math.sin(attack_angle) * attack_range

                self.tracers.append({
                    "start": (start_x, start_y),
                    "end": (end_x, end_y),
                    "color": (255, 220, 100),
                    "timer": 0.2,
                    "max_timer": 0.2
                })

        attack_speed = weapon_data.get("attack_speed", 0.5)
        player.attack_cooldown.set_cooldown("attack", attack_speed)
        return results

    def process_zombie_attacks(self, player, entity_manager, world):
        """AI 공격 처리 (사선 검사 및 원거리 사격 연동)"""
        results = []
        px = player.x + 0.5
        py = player.y + 0.5
        from utils import check_line_of_sight
        
        for zombie in entity_manager.zombies:
            if zombie.is_dead or not zombie.active:
                continue
            if zombie.can_attack():
                dist = distance(zombie.x, zombie.y, player.x, player.y)
                
                # 사거리 내에 있고 사선이 뚫려 있을 때만 공격
                if dist <= zombie.attack_range and check_line_of_sight(zombie.x, zombie.y, player.x, player.y, world):
                    zombie.do_attack() # 쿨다운 시작
                    
                    is_ranged = zombie.attack_range > 1.5
                    
                    if is_ranged:
                        # 원거리 사격 공격
                        is_pmc = "pmc" in zombie.zombie_type or zombie.zombie_type in ("tank", "spider")
                        miss_chance = 0.45 if is_pmc else 0.65
                        
                        # 플레이어가 뛰고(움직이고) 있으면 맞추기 더 힘듦
                        if player.moving:
                            miss_chance += 0.15
                            
                        start_x, start_y = zombie.x + 0.5, zombie.y + 0.5
                        tracer_color = (255, 60, 60) if is_pmc else (255, 150, 50)

                        if random.random() < miss_chance:
                            # 빗나감 표시
                            self.damage_numbers.append(
                                (player.x, player.y - 0.7, "Miss", 1.0, (200, 200, 200))
                            )
                            results.append(("player_miss", zombie, 0))
                            
                            end_x = player.x + 0.5 + random.uniform(-1.5, 1.5)
                            end_y = player.y + 0.5 + random.uniform(-1.5, 1.5)
                            self.tracers.append({
                                "start": (start_x, start_y),
                                "end": (end_x, end_y),
                                "color": tracer_color,
                                "timer": 0.2,
                                "max_timer": 0.2
                            })
                            continue
                        
                        # 명중
                        end_x, end_y = player.x + 0.5, player.y + 0.5
                        self.tracers.append({
                            "start": (start_x, start_y),
                            "end": (end_x, end_y),
                            "color": tracer_color,
                            "timer": 0.2,
                            "max_timer": 0.2
                        })

                        # 거리 비례 대미지 감쇄 (지수 감쇄 공식)
                        base_damage = zombie.damage
                        actual_damage = base_damage * math.exp(-0.04 * dist)
                        actual_damage = max(1.0, actual_damage) # 최소 1대미지
                        
                        # 플레이어 아머 감쇄 등은 player.take_damage 내부에서 처리됨
                        source_name = "PMC 사격" if is_pmc else "Scav 사격"
                        actual = player.take_damage(actual_damage, source_name)
                        
                        if actual > 0:
                            self.damage_numbers.append(
                                (player.x, player.y - 0.5, int(actual), 1.0, (255, 60, 60))
                            )
                            results.append(("player_hit", zombie, actual))
                    else:
                        # 근접 공격
                        base_damage = zombie.damage
                        actual_damage = base_damage + random.randint(-1, 2)
                        actual_damage = max(1.0, actual_damage)
                        
                        source_name = "좀비 공격"
                        actual = player.take_damage(actual_damage, source_name)
                        
                        if actual > 0:
                            self.damage_numbers.append(
                                (player.x, player.y - 0.5, int(actual), 1.0, (255, 60, 60))
                            )
                            results.append(("player_hit", zombie, actual))

        # 진영 간 AI vs AI 교전 처리
        for zombie in entity_manager.zombies:
            if zombie.is_dead or not zombie.active:
                continue
            if not zombie.can_attack():
                continue
            target = getattr(zombie, 'target', None)
            if target is None or not hasattr(target, 'x'):
                continue
            # 타겟이 다른 AI인 경우만 (플레이어 공격은 위에서 처리)
            if not hasattr(target, 'faction'):
                continue
            if target.is_dead or not target.active:
                continue
            d = distance(zombie.x, zombie.y, target.x, target.y)
            if d <= zombie.attack_range and getattr(zombie, 'can_see_target', False):
                zombie.do_attack()
                
                is_ranged = zombie.attack_range > 1.5
                if is_ranged:
                    is_pmc = getattr(zombie, 'faction', 'scav') == "pmc"
                    miss_chance = 0.45 if is_pmc else 0.65
                    
                    start_x, start_y = zombie.x + 0.5, zombie.y + 0.5
                    tracer_color = (255, 60, 60) if is_pmc else (255, 150, 50)

                    if random.random() < miss_chance:
                        self.damage_numbers.append(
                            (target.x, target.y - 0.7, "Miss", 1.0, (200, 200, 200))
                        )
                        end_x = target.x + 0.5 + random.uniform(-1.5, 1.5)
                        end_y = target.y + 0.5 + random.uniform(-1.5, 1.5)
                        self.tracers.append({
                            "start": (start_x, start_y),
                            "end": (end_x, end_y),
                            "color": tracer_color,
                            "timer": 0.2,
                            "max_timer": 0.2
                        })
                        continue
                    
                    end_x, end_y = target.x + 0.5, target.y + 0.5
                    self.tracers.append({
                        "start": (start_x, start_y),
                        "end": (end_x, end_y),
                        "color": tracer_color,
                        "timer": 0.2,
                        "max_timer": 0.2
                    })

                    base_damage = zombie.damage
                    actual_damage = base_damage * math.exp(-0.04 * d)
                    actual_damage = max(1.0, actual_damage)
                    target.take_damage(actual_damage)
                    self.damage_numbers.append(
                        (target.x, target.y - 0.5, int(actual_damage), 1.0, (255, 180, 50))
                    )
                else:
                    # 근접 공격
                    base_damage = zombie.damage
                    actual_damage = base_damage + random.randint(-1, 2)
                    actual_damage = max(1.0, actual_damage)
                    target.take_damage(actual_damage)
                    self.damage_numbers.append(
                        (target.x, target.y - 0.5, int(actual_damage), 1.0, (255, 180, 50))
                    )

        return results

    def get_hit_effects(self):
        return self.hit_effects

    def get_damage_numbers(self):
        return self.damage_numbers
