"""
player.py - 플레이어 캐릭터 시스템
"""
import pygame
import math
from settings import (PLAYER_MAX_HP, PLAYER_MAX_HUNGER, PLAYER_MAX_THIRST,
                       PLAYER_MAX_STRESS, PLAYER_MAX_STAMINA,
                       PLAYER_SPEED, PLAYER_SPRINT_SPEED, TILE_SIZE,
                       CHUNK_SIZE, DIFFICULTY_PRESETS)
from items import Inventory, ITEM_DATABASE
from crafting import CraftingSystem
from utils import clamp, distance, CooldownManager


class Player:
    """플레이어 캐릭터"""

    def __init__(self, x=0, y=0, difficulty_settings=None):
        # 위치 (월드 타일 좌표)
        self.x = float(x)
        self.y = float(y)
        self.vx = 0.0
        self.vy = 0.0

        # 스탯
        self.hp = PLAYER_MAX_HP
        self.max_hp = PLAYER_MAX_HP
        self.hunger = PLAYER_MAX_HUNGER
        self.thirst = PLAYER_MAX_THIRST
        self.stress = 0
        self.stamina = PLAYER_MAX_STAMINA
        self.defense = 0
        self.shelter_defense = 10

        # 난이도 설정
        self.diff = difficulty_settings or DIFFICULTY_PRESETS["보통"]

        # 이동
        self.speed = PLAYER_SPEED
        self.sprint_speed = PLAYER_SPRINT_SPEED
        self.is_sprinting = False
        self.is_crouching = False
        self.direction = 0  # 0~7 (하, 좌하, 좌, 좌상, 상, 우상, 우, 우하)
        self.moving = False
        self.animation_frame = 0
        self.animation_timer = 0

        # 전투
        self.equipped_weapon = None
        self.attack_cooldown = CooldownManager()
        self.invincible_timer = 0
        self.combo_count = 0
        self.recoil_stack = 0.0  # 반동 스택 (연사 시 누적)

        # 인벤토리 & 크래프팅
        self.inventory = Inventory(slots=12)
        self.inventory.max_weight = 15.0
        self.stash = Inventory(slots=150)
        self.secure_container = Inventory(slots=9) # 하베스트 파우치 (3x3)
        self.crafting = CraftingSystem()

        self.rubles = 10000
        self.equipped_backpack_meta = {}
        self.level = 1
        self.xp = 0
        self.reputation = {"prapor": 0.2, "therapist": 0.2, "fence": 0.2}
        self.spent_money = {"prapor": 0, "therapist": 0, "fence": 0}

        # 장비 슬롯
        self.equipped = {
            "head": None,
            "body": None,
            "feet": None,
            "weapon": None,
        }

        # 내부/외부 상태 관리 (인테리어)
        self.is_interior = False
        self.exterior_x = 0.0
        self.exterior_y = 0.0

        # 상태
        self.alive = True
        self.cause_of_death = ""
        self.exhausted = False  # 탈진 상태 (스태미나 0 도달 시)
        self.footstep_timer = 0
        self.stat_timer = 0.0  # 스탯 업데이트 주기 제한용 타이머
        self.damage_taken_this_frame = False  # 현재 프레임 피격 여부

        # 상태이상
        self.bleeding = False
        self.broken_bone = False

        # 버프 타이머
        self.stamina_buff_timer = 0.0
        self.aim_buff_timer = 0.0

        # 장비 내구도 (100.0 기준)
        self.equipped_durability = {
            "head": 100.0,
            "body": 100.0,
            "feet": 100.0,
            "weapon": 100.0,
        }

        # 보험 가입 여부
        self.equipped_insured = {
            "head": False,
            "body": False,
            "feet": False,
            "weapon": False,
        }

        # 퀘스트/진행 추적
        self.discovered_biomes = set()
        self.killed_zombies = 0
        self.buildings_explored = 0
        self.items_crafted = 0
        self.days_survived = 0
        self.raid_status = "NONE"  # NONE, IN_RAID, HIDEOUT
        self.explored_tiles = set()  # set of (x, y)
        self.event_system = None
        
        # 라디오 스캔 시스템
        self.radio_scan_timer = 0.0
        self.radio_scan_target = ""

    def enter_interior(self, ix, iy):
        """건물 내부 진입 시 좌표 전환"""
        if not self.is_interior:
            self.exterior_x = self.x
            self.exterior_y = self.y
        self.is_interior = True
        self.x = float(ix)
        self.y = float(iy)
        self.moving = False
        self.is_sprinting = False

    def exit_interior(self):
        """건물 외부 퇴장 시 좌표 복구"""
        self.is_interior = False
        self.x = self.exterior_x
        self.y = self.exterior_y
        self.moving = False

    def update(self, dt, current_world, weather_type=None, time_system=None):
        """플레이어 업데이트 (world 혹은 interior를 받아 다형성 적용)"""
        if not self.alive:
            return None

        # 어두운 환경(밤/실내)에서 광원 도구 내구도 소모
        is_dark = self.is_interior
        if time_system:
            hour = time_system.current_hour
            if hour >= 18.0 or hour < 6.0:
                is_dark = True
        
        if is_dark:
            tools_to_consume = ["손전등", "횃불", "개조 손전등"]
            for i, it in enumerate(self.inventory.items):
                item_name = it[0]
                if item_name in tools_to_consume:
                    meta = it[2] if len(it) > 2 else {}
                    durability = meta.get("durability", 100.0)
                    
                    consume_rate = 0.08
                    if item_name == "횃불":
                        consume_rate = 0.15
                    elif item_name == "개조 손전등":
                        consume_rate = 0.05
                        
                    durability -= consume_rate * dt
                    if durability <= 0:
                        self.inventory.remove_item(item_name, 1)
                        if self.event_system:
                            self.event_system.add_log(f"[{item_name}]의 내구도가 다하여 소멸했습니다.")
                    else:
                        meta["durability"] = durability
                        self.inventory.items[i] = (it[0], it[1], meta)
                    break

        # 피격 프레임 플래그 초기화
        self.damage_taken_this_frame = False

        # 버프 타이머 갱신
        if self.stamina_buff_timer > 0:
            self.stamina_buff_timer = max(0.0, self.stamina_buff_timer - dt)
        if self.aim_buff_timer > 0:
            self.aim_buff_timer = max(0.0, self.aim_buff_timer - dt)

        # 이동 처리
        self._handle_movement(dt, current_world)

        # 애니메이션
        self._update_animation(dt)

        # 쿨다운
        self.attack_cooldown.update(dt)

        # 무적 타이머
        if self.invincible_timer > 0:
            self.invincible_timer -= dt
            
        # 라디오 스캔 타이머
        if self.radio_scan_timer > 0:
            self.radio_scan_timer = max(0.0, self.radio_scan_timer - dt)

        # 총기 반동 감쇠
        if self.recoil_stack > 0:
            self.recoil_stack = max(0.0, self.recoil_stack - dt * 4.0)

        # 스태미나 자연 회복 (매 프레임 처리로 부드럽게 개선)
        if not self.is_sprinting:
            recovery_rate = 10.0  # 기본 10/초
            
            # 스태미나 버프 활성화 시 회복 속도 2배
            if self.stamina_buff_timer > 0:
                recovery_rate *= 2.0
            else:
                # 허기 20% 이하 시 50% 감속 디버프
                if self.hunger < PLAYER_MAX_HUNGER * 0.2:
                    recovery_rate *= 0.5
                # 갈증 20% 이하 시 50% 감속 디버프 (중첩 가능)
                if self.thirst < PLAYER_MAX_THIRST * 0.2:
                    recovery_rate *= 0.5
                    
            bad_weather = weather_type in ("비", "폭우", "폭풍") if weather_type else False
            is_outside = not self.is_interior
            if bad_weather and is_outside:
                recovery_rate *= 0.5  # 악천후 야외 시 회복 50% 추가 감소
                
            old_stamina = self.stamina
            self.stamina = min(PLAYER_MAX_STAMINA, self.stamina + recovery_rate * dt)
            recovered = self.stamina - old_stamina
            if recovered > 0:
                # 스태미나 회복 10당 배고픔 0.3 소모
                self.hunger = max(0.0, self.hunger - recovered * 0.03)

        # 스탯 감소 (시간 경과 - 0.5초 주기로 갱신하여 연산 부하 축소)
        self.stat_timer += dt
        if self.stat_timer >= 0.5:
            world_settings = getattr(current_world, 'world_settings', {})
            self._update_stats(self.stat_timer, world_settings, weather_type)
            self.stat_timer = 0.0

        # 크래프팅 진행
        # 크래프팅 시 좌표는 현재 좌표를 넘김
        result = self.crafting.update(dt, self.inventory, current_world, self.x, self.y)
        if result:
            self.items_crafted += 1

        # 상태 확인
        self._check_status()

        # 발자국 타이머
        if self.moving:
            self.footstep_timer += dt

        # 전장의 안개 갱신: 현재 타일 기준 반경 4타일 내
        px, py = int(self.x), int(self.y)
        radius = 4
        for dy in range(-radius, radius + 1):
            for dx in range(-radius, radius + 1):
                if dx*dx + dy*dy <= radius*radius:
                    self.explored_tiles.add((px + dx, py + dy))

        return result

    def _handle_movement(self, dt, world):
        """키 입력 기반 이동"""
        keys = pygame.key.get_pressed()
        dx, dy = 0, 0

        if keys[pygame.K_w] or keys[pygame.K_UP]:
            dy -= 1
        if keys[pygame.K_s] or keys[pygame.K_DOWN]:
            dy += 1
        if keys[pygame.K_a] or keys[pygame.K_LEFT]:
            dx -= 1
        if keys[pygame.K_d] or keys[pygame.K_RIGHT]:
            dx += 1

        # 스프린트 (탈진 상태면 30% 회복될 때까지 금지)
        wants_sprint = keys[pygame.K_LSHIFT]
        if self.exhausted:
            if self.stamina >= PLAYER_MAX_STAMINA * 0.3:
                self.exhausted = False
            else:
                wants_sprint = False

        # 은신 (앉기) - LCTRL 토글
        self.is_crouching = keys[pygame.K_LCTRL]
        if self.is_crouching:
            wants_sprint = False  # 은신 중에는 스프린트 불가
        self.is_sprinting = wants_sprint and self.stamina > 0

        # 정규화
        if dx != 0 or dy != 0:
            length = math.sqrt(dx * dx + dy * dy)
            dx /= length
            dy /= length
            self.moving = True

            # 방향 계산 (8방향)
            angle = math.atan2(dy, dx)
            self.direction = int(((angle + math.pi) / (math.pi / 4) + 0.5)) % 8
            self.direction = (self.direction + 4) % 8  # 보정
        else:
            self.moving = False

        # 속도 결정
        current_speed = self.sprint_speed if self.is_sprinting else self.speed
        if self.is_crouching:
            current_speed *= 0.5  # 은신 시 50% 감속

        # 골절(broken_bone) 상태 페널티
        if self.broken_bone:
            current_speed *= 0.5

        # 장비 보너스 (속도 및 가방 무게)
        if self.equipped.get("feet"):
            data = ITEM_DATABASE.get(self.equipped["feet"], {})
            current_speed += data.get("speed_bonus", 0)
            
        if not self.inventory.is_sandbox:
            if self.equipped.get("back"):
                self.inventory.slots = 24
                data = ITEM_DATABASE.get(self.equipped["back"], {})
                self.inventory.max_weight = 15.0 + data.get("weight_bonus", 15.0)
            else:
                self.inventory.slots = 12
                self.inventory.max_weight = 15.0
        
        # 무게 초과 확인 (80% 이상 시 속도 점진적 감소, 샌드박스 제외)
        current_weight = self.inventory.current_weight
        if not self.inventory.is_sandbox and current_weight > self.inventory.max_weight * 0.8:
            penalty_ratio = (current_weight - self.inventory.max_weight * 0.8) / (self.inventory.max_weight * 0.2)
            penalty_ratio = min(1.0, penalty_ratio)
            current_speed *= (1.0 - 0.3 * penalty_ratio) # 최대 30% 감속

        # 이동 및 충돌 체크 (서브스텝 단위 처리로 터널링 방지)
        move_dist_x = dx * current_speed * dt
        move_dist_y = dy * current_speed * dt
        
        total_dist = math.hypot(move_dist_x, move_dist_y)
        MAX_STEP = 0.5  # 최대 0.5타일(16픽셀)씩 쪼개어 검사
        steps = max(1, int(math.ceil(total_dist / MAX_STEP)))
        
        step_x = move_dist_x / steps
        step_y = move_dist_y / steps
        
        for _ in range(steps):
            new_x = self.x + step_x
            new_y = self.y + step_y
            
            # 다중 포인트 충돌 체크 (플레이어 발밑 영역: 가로 +0.2~+0.8, 세로 +0.8~+0.95)
            can_move_x = (
                world.is_walkable(new_x + 0.2, self.y + 0.8) and
                world.is_walkable(new_x + 0.8, self.y + 0.8) and
                world.is_walkable(new_x + 0.2, self.y + 0.95) and
                world.is_walkable(new_x + 0.8, self.y + 0.95)
            )
            if can_move_x:
                self.x = new_x
                
            can_move_y = (
                world.is_walkable(self.x + 0.2, new_y + 0.8) and
                world.is_walkable(self.x + 0.8, new_y + 0.8) and
                world.is_walkable(self.x + 0.2, new_y + 0.95) and
                world.is_walkable(self.x + 0.8, new_y + 0.95)
            )
            if can_move_y:
                self.y = new_y

        # 스프린트 시 스태미나 소모 (20/초)
        if self.is_sprinting and self.moving:
            self.stamina -= 20 * dt
            if self.stamina <= 0:
                self.stamina = 0
                self.exhausted = True
                self.is_sprinting = False

    def _update_animation(self, dt):
        """애니메이션 프레임 업데이트"""
        if self.moving:
            speed = 0.15 if self.is_sprinting else 0.1
            self.animation_timer += dt
            if self.animation_timer >= speed:
                self.animation_timer -= speed
                self.animation_frame = (self.animation_frame + 1) % 8
        else:
            self.animation_frame = 0
            self.animation_timer = 0

    def _update_stats(self, dt, world_settings, weather_type=None):
        """스탯 자연 감소/회복"""
        day_length = world_settings.get("day_length_minutes", 12) if world_settings else 12
        # 기본 12분 기준. 하루 길이가 길수록 천천히 감소 (0.5배까지)
        time_scale = 12 / max(5, day_length)
        
        hunger_rate = 0.4 * self.diff.get("hunger_rate", 1.0) * time_scale
        thirst_rate = 0.5 * self.diff.get("thirst_rate", 1.0) * time_scale
        stress_rate = 0.1 * self.diff.get("stress_rate", 1.0) * time_scale

        self.hunger -= hunger_rate * dt
        self.thirst -= thirst_rate * dt

        # 출혈 상태이상 피해 (초당 0.5 피해 - 방치 시 서서히 사망하도록 완화)
        if self.bleeding:
            self.hp -= 0.5 * dt
            self.stress += 0.3 * dt

        # 배고픔/갈증 0 하한선 제한만 적용 (아사/탈수 사망은 제거됨)
        if self.hunger <= 0:
            self.hunger = 0
        if self.thirst <= 0:
            self.thirst = 0

        # 날씨 페널티 (야외에서 비/폭우/폭풍 노출 시)
        bad_weather = weather_type in ("비", "폭우", "폭풍") if weather_type else False
        is_outside = not self.is_interior

        # 악천후 야외 노출 시 스트레스 지속 증가
        if bad_weather and is_outside:
            self.stress += 0.3 * dt

        # 스트레스 자연 감소 (낮, 은신처 근처)
        self.stress = max(0, self.stress - 0.1 * dt)

        # 값 제한
        self.hp = clamp(self.hp, 0, self.max_hp)
        self.hunger = clamp(self.hunger, 0, PLAYER_MAX_HUNGER)
        self.thirst = clamp(self.thirst, 0, PLAYER_MAX_THIRST)
        self.stress = clamp(self.stress, 0, PLAYER_MAX_STRESS)
        self.stamina = clamp(self.stamina, 0, PLAYER_MAX_STAMINA)

    def _check_status(self):
        """생존 상태 확인"""
        if self.hp <= 0:
            self.alive = False
            self.cause_of_death = "체력 고갈"
        elif self.stress >= PLAYER_MAX_STRESS:
            self.alive = False
            self.cause_of_death = "극심한 스트레스"

    def take_damage(self, amount, source=""):
        """피해 받기"""
        if self.invincible_timer > 0:
            return 0

        # 방어력 적용
        defense = self.defense
        if self.equipped.get("body"):
            if self.equipped_durability.get("body", 100.0) > 0:
                data = ITEM_DATABASE.get(self.equipped["body"], {})
                defense += data.get("defense", 0)
                # 방탄조끼 내구도 소모
                self.equipped_durability["body"] = max(0.0, self.equipped_durability["body"] - amount * 0.2)
        
        if self.equipped.get("head"):
            if self.equipped_durability.get("head", 100.0) > 0:
                # 머리 장비 내구도 소모
                self.equipped_durability["head"] = max(0.0, self.equipped_durability["head"] - amount * 0.1)

        actual_damage = max(1, amount * self.diff.get("damage_multiplier", 1.0) - defense * 0.5)
        self.hp -= actual_damage
        self.invincible_timer = 0.5
        self.damage_taken_this_frame = True

        # 상태이상 판정 (피격 시 15% 출혈, 10% 골절)
        import random
        if random.random() < 0.15:
            self.bleeding = True
        if random.random() < 0.10:
            self.broken_bone = True

        # 스트레스 증가
        self.stress += actual_damage * 0.3

        return actual_damage

    def heal(self, amount):
        """체력 회복"""
        self.hp = min(self.max_hp, self.hp + amount)

    def use_item(self, item_name):
        """아이템 사용"""
        if not self.inventory.has_item(item_name):
            return False

        data = ITEM_DATABASE.get(item_name, {})
        effects = data.get("effects", {})
        category = data.get("category")

        if not effects and item_name not in ("수류탄", "조명탄", "장거리 무전기"):
            return False

        # 장거리 무전기 특수 처리
        if item_name == "장거리 무전기":
            # 인벤토리에서 아이템 찾기 (내구도 확인용)
            item_idx = -1
            meta = {}
            for i, it in enumerate(self.inventory.items):
                if it[0] == item_name:
                    item_idx = i
                    meta = it[2] if len(it) > 2 else {}
                    break
            
            if item_idx != -1:
                durability = meta.get("durability", 100.0)
                durability -= 10.0 # 10% 소모 (10회 사용)
                
                if durability <= 0:
                    self.inventory.remove_item(item_name, 1)
                else:
                    meta["durability"] = durability
                    it = self.inventory.items[item_idx]
                    self.inventory.items[item_idx] = (it[0], it[1], meta)
                
                # UI 오픈을 위한 특수 반환값
                return "radio_scan"

        # 효과 적용
        if "hp" in effects:
            self.heal(effects["hp"])
        if "hunger" in effects:
            self.hunger = min(PLAYER_MAX_HUNGER, self.hunger + effects["hunger"])
        if "thirst" in effects:
            self.thirst = min(PLAYER_MAX_THIRST, self.thirst + effects["thirst"])
        if "stress" in effects:
            self.stress = max(0, self.stress + effects["stress"])
        if "stamina" in effects:
            self.stamina = min(PLAYER_MAX_STAMINA, self.stamina + effects["stamina"])

        # 식료품 버프 활성화
        from items import ItemCategory
        if category in (ItemCategory.FOOD, ItemCategory.WATER):
            self.stamina_buff_timer = 30.0
            self.aim_buff_timer = 30.0

        # 상태이상 치료
        if item_name == "붕대":
            self.bleeding = False
        elif item_name in ("구급상자", "고급 치료킷"):
            self.bleeding = False
            self.broken_bone = False
        elif item_name == "진통제":
            self.broken_bone = False

        self.inventory.remove_item(item_name, 1)
        return True

    def equip_item(self, item_name, world=None):
        """장비 착용"""
        import copy
        data = ITEM_DATABASE.get(item_name)
        if not data:
            return False

        slot = data.get("equip_slot")
        if not slot and data.get("category") == "무기":
            slot = "weapon"

        if not slot:
            return False
            
        if not self.inventory.has_item(item_name):
            return False

        # 인벤토리에서 아이템 메타데이터 백업
        item_meta = {}
        for it in self.inventory.items:
            if it[0] == item_name:
                item_meta = copy.deepcopy(it[2]) if len(it) > 2 else {}
                break

        old_item = self.equipped.get(slot)
        old_meta = {}
        if old_item:
            if slot == "back":
                old_meta = getattr(self, "equipped_backpack_meta", {})
                backpack_items = []
                remaining_items = []
                for it in self.inventory.items:
                    slot_idx = it[2].get("slot_idx", 0) if len(it) > 2 else 0
                    if slot_idx >= 12:
                        backpack_items.append(it)
                    else:
                        remaining_items.append(it)
                old_meta["backpack_items"] = backpack_items
                self.inventory.items = remaining_items
                self.inventory.slots = 12
                self.inventory.max_weight = 15.0

        # 새 아이템 인벤토리에서 제거
        self.inventory.remove_item(item_name, 1)

        # 기존에 장착 중이던 장비를 인벤토리에 추가
        if old_item:
            if not self.inventory.add_item(old_item, 1, old_meta):
                # 인벤토리가 가득 찼으면 바닥에 드롭 (장비 증발 방지)
                if world and hasattr(world, 'drop_item'):
                    drop_x = self.x
                    drop_y = self.y
                    world.drop_item(old_item, drop_x, drop_y)

        self.equipped[slot] = item_name
        
        if slot == "back":
            self.equipped_backpack_meta = item_meta
            if not self.inventory.is_sandbox:
                self.inventory.slots = 24
                self.inventory.max_weight = 15.0 + data.get("weight_bonus", 15.0)
                
                # 가방 내부 아이템 복원
                backpack_items = item_meta.get("backpack_items", [])
                for it in backpack_items:
                    self.inventory.items.append(it)
                
        return True

    def unequip_item(self, slot, world=None):
        """장비 해제"""
        import copy
        item_name = self.equipped.get(slot)
        if not item_name:
            return False

        item_meta = {}
        backpack_items = []
        if slot == "back":
            item_meta = copy.deepcopy(getattr(self, "equipped_backpack_meta", {}))
            if not self.inventory.is_sandbox:
                remaining_items = []
                for it in self.inventory.items:
                    slot_idx = it[2].get("slot_idx", 0) if len(it) > 2 else 0
                    if slot_idx >= 12:
                        backpack_items.append(it)
                    else:
                        remaining_items.append(it)
                item_meta["backpack_items"] = backpack_items
                self.inventory.items = remaining_items
                self.inventory.slots = 12
                self.inventory.max_weight = 15.0

        self.equipped[slot] = None

        # 레이드 월드 중 장비 해제 시 바닥에 드롭
        if world and hasattr(world, 'drop_item') and not isinstance(world, Inventory):
            world.drop_item(item_name, self.x, self.y, item_meta)
            if slot == "back":
                self.equipped_backpack_meta = {}
            return True

        # 은신처 등 월드가 없을 때는 인벤토리나 stash에 추가 시도
        dest_inv = world if isinstance(world, Inventory) else self.inventory
        if dest_inv.add_item(item_name, 1, item_meta):
            if slot == "back":
                self.equipped_backpack_meta = {}
            return True
            
        # 실패 시 롤백 (인벤토리나 stash에 넣을 공간이 없을 때)
        self.equipped[slot] = item_name
        if slot == "back" and not self.inventory.is_sandbox:
            self.inventory.slots = 24
            data = ITEM_DATABASE.get(item_name, {})
            self.inventory.max_weight = 15.0 + data.get("weight_bonus", 15.0)
            for it in backpack_items:
                self.inventory.items.append(it)
        return False

    def get_attack_damage(self):
        """현재 무기의 공격력"""
        weapon = self.equipped.get("weapon")
        if weapon:
            data = ITEM_DATABASE.get(weapon, {})
            return data.get("damage", 5)
        return 5  # 주먹

    def get_attack_range(self):
        """현재 무기의 사거리"""
        weapon = self.equipped.get("weapon")
        if weapon:
            data = ITEM_DATABASE.get(weapon, {})
            return data.get("range", 1.0)
        return 0.8  # 주먹

    def get_weapon_type(self):
        weapon = self.equipped.get("weapon")
        if weapon:
            data = ITEM_DATABASE.get(weapon, {})
            return data.get("type", "melee")
        return "melee"

    @property
    def chunk_pos(self):
        return (int(self.x) // CHUNK_SIZE, int(self.y) // CHUNK_SIZE)

    @property
    def tile_pos(self):
        return (int(self.x), int(self.y))

    @property
    def hp_ratio(self):
        return self.hp / self.max_hp if self.max_hp > 0 else 0

    @property
    def hunger_ratio(self):
        return self.hunger / PLAYER_MAX_HUNGER

    @property
    def thirst_ratio(self):
        return self.thirst / PLAYER_MAX_THIRST

    @property
    def stress_ratio(self):
        return self.stress / PLAYER_MAX_STRESS

    @property
    def stamina_ratio(self):
        return self.stamina / PLAYER_MAX_STAMINA

    def to_dict(self):
        """저장용"""
        return {
            "x": self.x, "y": self.y,
            "exterior_x": self.exterior_x,
            "exterior_y": self.exterior_y,
            "is_interior": self.is_interior,
            "hp": self.hp, "hunger": self.hunger, "thirst": self.thirst,
            "stress": self.stress, "stamina": self.stamina,
            "shelter_defense": self.shelter_defense,
            "direction": self.direction,
            "inventory": self.inventory.to_dict(),
            "stash": self.stash.to_dict(),
            "secure_container": self.secure_container.to_dict(),
            "rubles": self.rubles,
            "level": self.level,
            "xp": self.xp,
            "reputation": dict(self.reputation),
            "spent_money": dict(self.spent_money),
            "crafting": self.crafting.to_dict(),
            "equipped": dict(self.equipped),
            "equipped_durability": dict(self.equipped_durability),
            "equipped_insured": dict(self.equipped_insured),
            "equipped_backpack_meta": getattr(self, "equipped_backpack_meta", {}),
            "bleeding": self.bleeding,
            "broken_bone": self.broken_bone,
            "killed_zombies": self.killed_zombies,
            "buildings_explored": self.buildings_explored,
            "items_crafted": self.items_crafted,
            "days_survived": self.days_survived,
            "discovered_biomes": list(self.discovered_biomes),
            "raid_status": self.raid_status,
            "explored_tiles": [list(t) for t in self.explored_tiles],
        }

    @classmethod
    def from_dict(cls, data, difficulty_settings=None):
        p = cls(data["x"], data["y"], difficulty_settings)
        p.exterior_x = data.get("exterior_x", 0.0)
        p.exterior_y = data.get("exterior_y", 0.0)
        p.is_interior = data.get("is_interior", False)
        p.hp = data.get("hp", PLAYER_MAX_HP)
        p.hunger = data.get("hunger", PLAYER_MAX_HUNGER)
        p.thirst = data.get("thirst", PLAYER_MAX_THIRST)
        p.stress = data.get("stress", 0)
        p.stamina = data.get("stamina", PLAYER_MAX_STAMINA)
        p.shelter_defense = data.get("shelter_defense", 10)
        p.direction = data.get("direction", 0)
        p.inventory = Inventory.from_dict(data.get("inventory", {}))
        p.stash = Inventory.from_dict(data.get("stash", {"slots": 150, "items": []}))
        p.secure_container = Inventory.from_dict(data.get("secure_container", {"slots": 9, "items": []}))
        p.rubles = data.get("rubles", 10000)
        p.level = data.get("level", 1)
        p.xp = data.get("xp", 0)
        p.reputation = data.get("reputation", {"prapor": 0.2, "therapist": 0.2, "fence": 0.2})
        p.spent_money = data.get("spent_money", {"prapor": 0, "therapist": 0, "fence": 0})
        p.crafting = CraftingSystem.from_dict(data.get("crafting", {}))
        p.equipped = data.get("equipped", {"head": None, "body": None, "feet": None, "weapon": None})
        p.equipped_backpack_meta = data.get("equipped_backpack_meta", {})
        p.equipped_durability = data.get("equipped_durability", {"head": 100.0, "body": 100.0, "feet": 100.0, "weapon": 100.0})
        p.equipped_insured = data.get("equipped_insured", {"head": False, "body": False, "feet": False, "weapon": False})
        p.bleeding = data.get("bleeding", False)
        p.broken_bone = data.get("broken_bone", False)
        p.killed_zombies = data.get("killed_zombies", 0)
        p.buildings_explored = data.get("buildings_explored", 0)
        p.items_crafted = data.get("items_crafted", 0)
        p.days_survived = data.get("days_survived", 0)
        p.discovered_biomes = set(data.get("discovered_biomes", []))
        p.raid_status = data.get("raid_status", "NONE")
        p.explored_tiles = set(tuple(item) for item in data.get("explored_tiles", []))
        return p
