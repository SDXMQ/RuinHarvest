"""
entities.py - 좀비, NPC, 동물 엔티티 시스템
"""
import math
import random
from settings import TILE_SIZE, CHUNK_SIZE, DIFFICULTY_PRESETS
from utils import distance, direction_to, clamp, distance_sq, check_line_of_sight
from pathfinding import find_path


# ============================================================
# 적(Scav/PMC) 타입 정의 (원거리 교전 사거리 적용)
# ============================================================
ENEMY_TYPES = {
    "normal": {
        "name": "일반 스캐브",
        "hp": 40,
        "damage": 8,
        "speed": 1.2,
        "detection_range": 8,
        "attack_range": 1.0,
        "attack_cooldown": 1.5,
        "xp": 15,
        "loot_chance": 0.3,
    },
    "runner": {
        "name": "러너 스캐브",
        "hp": 30,
        "damage": 6,
        "speed": 2.0,
        "detection_range": 10,
        "attack_range": 1.0,
        "attack_cooldown": 1.2,
        "xp": 20,
        "loot_chance": 0.2,
    },
    "scav": {
        "name": "스캐브 (Scav)",
        "hp": 45,
        "damage": 6,
        "speed": 1.3,
        "detection_range": 10,
        "attack_range": 6.0,
        "attack_cooldown": 1.8,
        "xp": 35,
        "loot_chance": 0.5,
    },
    "tank": {
        "name": "정예 PMC 용병",
        "hp": 100,
        "damage": 12,
        "speed": 1.4,
        "detection_range": 12,
        "attack_range": 7.0,
        "attack_cooldown": 1.5,
        "xp": 70,
        "loot_chance": 0.8,
    },
    "spider": {
        "name": "스나이퍼 PMC",
        "hp": 50,
        "damage": 16,
        "speed": 1.5,
        "detection_range": 16,
        "attack_range": 10.0,
        "attack_cooldown": 2.5,
        "xp": 60,
        "loot_chance": 0.7,
    },
}

# AI가 드롭하는 아이템 풀
ENEMY_LOOT = [
    ("천", 0.2), ("고철", 0.15), ("못", 0.1),
    ("식량통조림", 0.05), ("붕대", 0.1), ("탄약", 0.2),
    ("생수", 0.05), ("나이프", 0.05),
]


class EnemyState:
    IDLE = "idle"
    WANDER = "wander"
    CHASE = "chase"
    ATTACK = "attack"
    HURT = "hurt"
    DEAD = "dead"
    # 전술 AI 추가 상태
    PATROL = "patrol"
    ALERT = "alert"
    FIND_COVER = "find_cover"
    ENGAGE = "engage"
    FLANK = "flank"


class Enemy:
    """적 엔티티"""

    def __init__(self, x, y, enemy_type="normal", difficulty_settings=None):
        self.x = float(x)
        self.y = float(y)
        self.enemy_type = enemy_type
        self.diff = difficulty_settings or DIFFICULTY_PRESETS["보통"]

        type_data = ENEMY_TYPES.get(enemy_type, ENEMY_TYPES["normal"])

        self.max_hp = type_data["hp"] * self.diff.get("enemy_hp_mult", 1.0)
        self.hp = self.max_hp
        self.damage = type_data["damage"] * self.diff.get("enemy_damage_mult", 1.0)
        self.speed = type_data["speed"] * self.diff.get("enemy_speed_mult", 1.0)
        self.detection_range = type_data["detection_range"]
        self.attack_range = type_data["attack_range"]
        self.attack_cooldown_time = type_data["attack_cooldown"]
        self.loot_chance = type_data["loot_chance"]
        self.xp = type_data["xp"]

        self.state = EnemyState.PATROL
        self.direction = 0
        self.animation_frame = 0
        self.animation_timer = 0

        self.attack_timer = 0
        self.idle_timer = random.uniform(0, 3)
        self.wander_target_x = x
        self.wander_target_y = y
        self.hurt_timer = 0
        self.death_timer = 0
        self.aggro_alert = 0.0  # 총성 어그로 느낌표 표시 잔여 시간
        self.ai_timer = random.uniform(0, 0.15)  # AI 업데이트 주기 관리용 타이머

        # 전술적 AI 추가 속성
        self.alert_target_x = x
        self.alert_target_y = y
        self.cover_target_x = None
        self.cover_target_y = None
        self.flank_target_x = None
        self.flank_target_y = None
        self.cover_timer = 0.0
        self.flank_timer = 0.0
        self.alert_timer = 0.0

        self.active = True

        # 진영 (Faction) 시스템
        if enemy_type in ("tank", "spider"):
            self.faction = "pmc"
        elif enemy_type == "scav":
            self.faction = "scav"
        else:
            self.faction = "scav"
        self.target = None  # 현재 타겟 (Player 또는 다른 Enemy)
        self.can_see_target = False
        self.vision_timer = random.uniform(0.0, 0.2)  # 시야 검사 분산 타이머
        self.vision_interval = random.uniform(0.5, 0.7)  # 개별 시야 갱신 주기

        # A* 길찾기 속성 추가
        self.path = []
        self.path_update_timer = random.uniform(0.0, 0.4)

    def update(self, dt, player_x, player_y, world, player_crouching=False, entity_manager=None):
        if not self.active:
            return

        if self.aggro_alert > 0:
            self.aggro_alert -= dt

        # 사망 처리
        if self.hp <= 0:
            if self.state != EnemyState.DEAD:
                self.state = EnemyState.DEAD
                self.death_timer = 1.5
            self.death_timer -= dt
            if self.death_timer <= 0:
                self.active = False
            return

        # 피격 상태 (기존 유지하되, 회복 후 즉시 교전 또는 도망 유도)
        if self.state == EnemyState.HURT:
            self.hurt_timer -= dt
            if self.hurt_timer <= 0:
                if self.hp < self.max_hp * 0.4:
                    self.state = EnemyState.FIND_COVER
                    self.cover_target_x = None
                else:
                    self.state = EnemyState.ENGAGE
            return

        # 쿨다운 감소
        if self.attack_timer > 0:
            self.attack_timer -= dt

        # 시야 검사 분산 타이머 (vision_timer 기반, 인스턴스별 0.5~0.7초 주기)
        self.vision_timer += dt
        vision_updated = False
        if self.vision_timer >= self.vision_interval:
            self.vision_timer = 0
            vision_updated = True

        # AI 의사결정 주기 조절 (0.15초 간격)
        self.ai_timer += dt
        if self.ai_timer >= 0.15:
            self.ai_timer = 0
            
            # 타겟 선정: 플레이어 + 적대 진영 AI 중 가장 가까운 대상
            best_target = None
            best_dist = 9999
            best_is_player = False

            player_dist = distance(self.x, self.y, player_x, player_y)
            effective_detection = self.detection_range * 0.5 if player_crouching else self.detection_range
            if player_dist <= effective_detection:
                best_target = (player_x, player_y)
                best_dist = player_dist
                best_is_player = True

            # 적대 진영 AI 탐색
            if entity_manager:
                for other in entity_manager.enemies:
                    if other is self or other.is_dead or not other.active:
                        continue
                    if other.faction == self.faction:
                        continue
                    d = distance(self.x, self.y, other.x, other.y)
                    if d <= self.detection_range and d < best_dist:
                        best_target = other
                        best_dist = d
                        best_is_player = False

            # 사선(LOS) 검사 - vision_timer가 갱신될 때만 수행
            has_los = False
            if vision_updated and best_target is not None:
                if best_is_player:
                    has_los = check_line_of_sight(self.x, self.y, player_x, player_y, world)
                else:
                    has_los = check_line_of_sight(self.x, self.y, best_target.x, best_target.y, world)
                self.can_see_target = has_los
            else:
                has_los = self.can_see_target

            # 타겟 좌표 결정
            if best_is_player:
                target_x, target_y = player_x, player_y
            elif best_target and not best_is_player:
                target_x, target_y = best_target.x, best_target.y
            else:
                target_x, target_y = player_x, player_y
            
            self.target = best_target
            dist = best_dist

            # 상태 전이 로직
            if self.state in (EnemyState.IDLE, EnemyState.WANDER, EnemyState.PATROL):
                if has_los:
                    self.state = EnemyState.ENGAGE
                elif self.aggro_alert > 0: # 총성 등의 소음을 감지했을 때 경계
                    self.state = EnemyState.ALERT
                    self.alert_target_x = target_x
                    self.alert_target_y = target_y
                    self.alert_timer = 6.0
            
            elif self.state == EnemyState.ALERT:
                if has_los:
                    self.state = EnemyState.ENGAGE
                else:
                    self.alert_timer -= 0.15
                    if self.alert_timer <= 0:
                        self.state = EnemyState.PATROL
                        
            elif self.state == EnemyState.ENGAGE:
                if not has_los:
                    # 타겟 시야 상실 시 마지막 위치 경계
                    self.state = EnemyState.ALERT
                    self.alert_target_x = target_x
                    self.alert_target_y = target_y
                    self.alert_timer = 8.0
                elif self.hp < self.max_hp * 0.3:
                    # 체력이 낮으면 엄폐
                    self.state = EnemyState.FIND_COVER
                    self.cover_target_x = None
                elif random.random() < 0.05:
                    # 간헐적인 우회 공격 시도
                    self.state = EnemyState.FLANK
                    self.flank_target_x = None
                    self.flank_timer = 5.0
                    
            elif self.state == EnemyState.FIND_COVER:
                if self.cover_target_x is not None:
                    # 엄폐 타겟 접근 검증
                    if distance(self.x, self.y, self.cover_target_x, self.cover_target_y) < 0.5:
                        self.cover_timer += 0.15
                        # 엄폐 상태에서 자가 수리/치유 (초당 2.0 hp)
                        self.hp = min(self.max_hp, self.hp + 0.3)
                        if self.cover_timer > 3.0:
                            if has_los:
                                self.state = EnemyState.ENGAGE
                            else:
                                self.state = EnemyState.ALERT
                                self.alert_target_x = target_x
                                self.alert_target_y = target_y
                                self.alert_timer = 5.0
                else:
                    cx, cy = self._find_cover_tile(target_x, target_y, world)
                    if cx is not None:
                        self.cover_target_x = cx
                        self.cover_target_y = cy
                        self.cover_timer = 0.0
                    else:
                        self.state = EnemyState.ENGAGE
                        
            elif self.state == EnemyState.FLANK:
                self.flank_timer -= 0.15
                if self.flank_timer <= 0:
                    self.state = EnemyState.ENGAGE
                elif has_los and dist <= self.attack_range:
                    self.state = EnemyState.ENGAGE
                elif self.flank_target_x is None:
                    fx, fy = self._calculate_flank_pos(target_x, target_y, world)
                    if fx is not None:
                        self.flank_target_x = fx
                        self.flank_target_y = fy
                    else:
                        self.state = EnemyState.ENGAGE


        # 상태에 따른 최종 목적지 결정
        move_target_x, move_target_y = self.x, self.y
        if self.state in (EnemyState.IDLE, EnemyState.PATROL, EnemyState.WANDER):
            self.idle_timer -= dt
            if self.idle_timer <= 0:
                self.idle_timer = random.uniform(3, 7)
                self.wander_target_x = self.x + random.uniform(-4, 4)
                self.wander_target_y = self.y + random.uniform(-4, 4)
            move_target_x, move_target_y = self.wander_target_x, self.wander_target_y
            
        elif self.state == EnemyState.ALERT:
            move_target_x, move_target_y = self.alert_target_x, self.alert_target_y
            
        elif self.state == EnemyState.ENGAGE:
            if self.target is not None:
                if hasattr(self.target, 'x'):
                    move_target_x, move_target_y = self.target.x, self.target.y
                elif isinstance(self.target, tuple):
                    move_target_x, move_target_y = self.target
                else:
                    move_target_x, move_target_y = player_x, player_y
            else:
                move_target_x, move_target_y = player_x, player_y
                
        elif self.state == EnemyState.FIND_COVER:
            if self.cover_target_x is not None:
                move_target_x, move_target_y = self.cover_target_x, self.cover_target_y
            else:
                move_target_x, move_target_y = player_x, player_y
                
        elif self.state == EnemyState.FLANK:
            if self.flank_target_x is not None:
                move_target_x, move_target_y = self.flank_target_x, self.flank_target_y
            else:
                move_target_x, move_target_y = player_x, player_y

        # A* 경로 탐색 및 업데이트
        self.path_update_timer += dt
        has_los = check_line_of_sight(self.x, self.y, move_target_x, move_target_y, world)
        
        if has_los:
            # 타겟과 직선 시야가 확보된 경우 A* 연산 생략하고 직선 이동
            self.path = []
        else:
            if self.path_update_timer >= 0.4:
                self.path_update_timer = 0.0
                self.path = find_path((self.x, self.y), (move_target_x, move_target_y), world)

        # 이동 처리
        # 상태별 기본 속도 가중치 결정
        speed_mult = 1.0
        if self.state in (EnemyState.IDLE, EnemyState.PATROL, EnemyState.WANDER):
            speed_mult = 0.5
        elif self.state == EnemyState.ALERT:
            speed_mult = 0.7
        elif self.state == EnemyState.FIND_COVER:
            speed_mult = 1.3
        elif self.state == EnemyState.FLANK:
            speed_mult = 1.1

        move_speed = self.speed * speed_mult * dt

        # ENGAGE 상태일 때 사격 사거리 안이면 굳이 접근하지 않고 멈춤
        dist_to_dest = distance(self.x, self.y, move_target_x, move_target_y)
        should_move = True
        if self.state == EnemyState.ENGAGE and dist_to_dest <= self.attack_range * 0.8:
            should_move = False

        if should_move:
            if self.path:
                # A* 경로 추적 이동
                next_node = self.path[0]
                node_dist = distance(self.x, self.y, next_node[0], next_node[1])
                if node_dist <= 0.35:
                    self.path.pop(0)
                    if self.path:
                        next_node = self.path[0]
                    else:
                        next_node = (move_target_x, move_target_y)

                dx, dy = direction_to(self.x, self.y, next_node[0], next_node[1])
                self._move_with_collision(dx * move_speed, dy * move_speed, world, entity_manager)
            else:
                # 직선 이동
                dx, dy = direction_to(self.x, self.y, move_target_x, move_target_y)
                self._move_with_collision(dx * move_speed, dy * move_speed, world, entity_manager)

        # 방향 업데이트
        if self.state in (EnemyState.ENGAGE, EnemyState.FLANK, EnemyState.ALERT):
            dx = move_target_x - self.x
            dy = move_target_y - self.y
        else:
            dx = self.wander_target_x - self.x
            dy = self.wander_target_y - self.y

        if abs(dx) > 0.01 or abs(dy) > 0.01:
            angle = math.atan2(dy, dx)
            self.direction = int(((angle + math.pi) / (math.pi / 4) + 0.5)) % 8
            self.direction = (self.direction + 4) % 8

        # 애니메이션
        if self.state not in (EnemyState.IDLE, EnemyState.DEAD):
            self.animation_timer += dt
            if self.animation_timer >= 0.15:
                self.animation_timer -= 0.15
                self.animation_frame = (self.animation_frame + 1) % 8

    def _move_with_collision(self, dx, dy, world, entity_manager=None):
        total_dist = math.hypot(dx, dy)
        MAX_STEP = 0.4  # 최대 0.4타일씩 쪼개어 검사
        steps = max(1, int(math.ceil(total_dist / MAX_STEP)))
        
        step_x = dx / steps
        step_y = dy / steps
        
        for _ in range(steps):
            new_x = self.x + step_x
            new_y = self.y + step_y
            
            # 1. 월드 타일 충돌 체크
            can_move_x = world.is_walkable(new_x + 0.5, self.y + 0.9)
            can_move_y = world.is_walkable(self.x + 0.5, new_y + 0.9)
            
            # 2. 좀비 간의 충돌 검사 (밀치기 효과 적용하여 한 점 겹침 방지)
            if entity_manager:
                push_force_x = 0.0
                push_force_y = 0.0
                for other in entity_manager.enemies:
                    if other is self or not other.active or other.is_dead:
                        continue
                    # 대상과의 거리 계산
                    dist = distance(new_x, self.y, other.x, other.y)
                    MIN_DIST = 0.45  # 좀비 충돌 반경
                    if dist < MIN_DIST:
                        if dist > 0.01:
                            push_force_x += ((new_x - other.x) / dist) * 0.05
                            push_force_y += ((self.y - other.y) / dist) * 0.05
                        else:
                            push_force_x += random.uniform(-0.05, 0.05)
                            push_force_y += random.uniform(-0.05, 0.05)
                            
                # 반발력 가산
                if abs(push_force_x) > 0.01 and world.is_walkable(new_x + push_force_x + 0.5, self.y + 0.9):
                    new_x += push_force_x
                if abs(push_force_y) > 0.01 and world.is_walkable(self.x + 0.5, new_y + push_force_y + 0.9):
                    new_y += push_force_y
            
            if can_move_x:
                self.x = new_x
            if can_move_y:
                self.y = new_y

    def _find_cover_tile(self, player_x, player_y, world):
        best_cover = None
        min_dist_to_self = 999.0
        
        px, py = int(player_x), int(player_y)
        ax, ay = int(self.x), int(self.y)
        
        for dx in range(-8, 9):
            for dy in range(-8, 9):
                tx = ax + dx
                ty = ay + dy
                
                if not world.is_walkable(tx, ty):
                    continue
                    
                dist_to_player = distance(tx, ty, player_x, player_y)
                if dist_to_player < 3.0:
                    continue
                    
                if not check_line_of_sight(tx, ty, player_x, player_y, world):
                    dist_to_self = distance(tx, ty, self.x, self.y)
                    if dist_to_self < min_dist_to_self:
                        min_dist_to_self = dist_to_self
                        best_cover = (tx + 0.5, ty + 0.5)
                        
        return best_cover if best_cover else (None, None)

    def _calculate_flank_pos(self, player_x, player_y, world):
        dx, dy = direction_to(self.x, self.y, player_x, player_y)
        perp_x, perp_y = (-dy, dx) if random.random() < 0.5 else (dy, -dx)
        
        flank_dist = random.uniform(5.0, 8.0)
        fx = player_x + perp_x * flank_dist
        fy = player_y + perp_y * flank_dist
        
        if world.is_walkable(fx, fy):
            return fx, fy
            
        for offset in range(1, 4):
            for sign in [-1, 1]:
                nfx = fx + perp_y * offset * sign
                nfy = fy - perp_x * offset * sign
                if world.is_walkable(nfx, nfy):
                    return nfx, nfy
                    
        return None, None

    def can_attack(self):
        return self.state == EnemyState.ENGAGE and self.attack_timer <= 0

    def do_attack(self):
        self.attack_timer = self.attack_cooldown_time
        return self.damage

    def take_damage(self, amount, knockback_dir=None):
        self.hp -= amount
        self.state = EnemyState.HURT
        self.hurt_timer = 0.3

        if knockback_dir:
            self.x += knockback_dir[0] * 0.5
            self.y += knockback_dir[1] * 0.5

    def get_loot(self):
        """사망 시 루트"""
        loot = []
        if random.random() < self.loot_chance:
            for item_name, chance in ENEMY_LOOT:
                if random.random() < chance:
                    loot.append(item_name)
                    if len(loot) >= 2:
                        break
        return loot

    @property
    def is_dead(self):
        return self.hp <= 0

    def to_dict(self):
        return {
            "x": self.x, "y": self.y, "type": self.enemy_type,
            "hp": self.hp, "state": self.state, "active": self.active,
        }

    @classmethod
    def from_dict(cls, data):
        z = cls(data["x"], data["y"], data.get("type", "normal"))
        z.hp = data.get("hp", z.max_hp)
        z.state = data.get("state", "idle")
        z.active = data.get("active", True)
        return z


# ============================================================
# NPC 타입 정의
# ============================================================
NPC_TYPES = {
    "merchant": {
        "name": "떠돌이 상인",
        "dialogue_intro": "여어, 반가워! 좋은 물건 많이 있어.",
        "trade_items": [
            ("방독면", "식량통조림", 2),
            ("방탄조끼", "식량통조림", 3),
            ("비상용 배터리", "식량통조림", 1),
            ("구급상자", "생수", 2),
            ("탄약", "고철", 3),
        ],
    },
    "survivor": {
        "name": "생존자",
        "dialogue_intro": "살아있는 사람이라니... 도와줄 수 있나요?",
        "quest_types": ["rescue", "fetch", "defend"],
    },
    "soldier": {
        "name": "군인",
        "dialogue_intro": "생존자인가? 이 지역 정보를 공유할 수 있소.",
        "provides": ["map_info", "military_loot"],
    },
}


class NPCState:
    IDLE = "idle"
    TALKING = "talking"
    TRADING = "trading"
    MOVING = "moving"
    APPROACHING = "approaching"


class NPC:
    """NPC 엔티티"""

    def __init__(self, x, y, npc_type="merchant"):
        self.x = float(x)
        self.y = float(y)
        self.npc_type = npc_type
        self.state = NPCState.IDLE
        self.direction = 0
        self.animation_frame = 0
        self.animation_timer = 0
        self.active = True
        self.met = False

        type_data = NPC_TYPES.get(npc_type, {})
        self.name = type_data.get("name", "NPC")
        self.dialogue_intro = type_data.get("dialogue_intro", "...")

        # 상인 전용
        self.trade_items = type_data.get("trade_items", [])

        # 퀘스트 주는 NPC 전용 (survivor, soldier 등)
        if npc_type == "soldier":
            self.quest_req = ("식량통조림", random.randint(1, 3))
            self.quest_reward = ("권총", 1) if random.random() < 0.5 else ("탄약", random.randint(5, 15))
        elif npc_type == "survivor":
            self.quest_req = ("붕대", random.randint(1, 2)) if random.random() < 0.5 else ("생수", random.randint(1, 3))
            self.quest_reward = ("가방", 1) if random.random() < 0.2 else ("고철", random.randint(3, 8))
        else:
            self.quest_req = (None, 0)
            self.quest_reward = (None, 0)

        self.idle_timer = random.uniform(0, 3)
        self.wander_target_x = x
        self.wander_target_y = y

    def update(self, dt, world, px=None, py=None):
        if not self.active:
            return

        # 상인 플레이어 감지 시 접근 로직 (IDLE, MOVING 상태에서 작동)
        if self.npc_type == "merchant" and self.state in (NPCState.IDLE, NPCState.MOVING) and px is not None and py is not None:
            if distance(self.x, self.y, px, py) <= 8.0:
                self.state = NPCState.APPROACHING
                self.show_exclamation = True
                self.exclamation_timer = 2.0

        if self.state == NPCState.IDLE:
            self.idle_timer -= dt
            if self.idle_timer <= 0:
                self.state = NPCState.MOVING
                self.wander_target_x = self.x + random.uniform(-3, 3)
                self.wander_target_y = self.y + random.uniform(-3, 3)
                self.idle_timer = random.uniform(3, 8)

        elif self.state == NPCState.MOVING:
            dx, dy = direction_to(self.x, self.y, self.wander_target_x, self.wander_target_y)
            speed = 0.8 * dt
            new_x = self.x + dx * speed
            new_y = self.y + dy * speed

            if world.is_walkable(new_x + 0.5, self.y + 0.9):
                self.x = new_x
            if world.is_walkable(self.x + 0.5, new_y + 0.9):
                self.y = new_y

            if distance(self.x, self.y, self.wander_target_x, self.wander_target_y) < 0.3:
                self.state = NPCState.IDLE
                self.idle_timer = random.uniform(2, 6)

            # 애니메이션
            self.animation_timer += dt
            if self.animation_timer >= 0.2:
                self.animation_timer -= 0.2
                self.animation_frame = (self.animation_frame + 1) % 8

        elif self.state == NPCState.APPROACHING:
            if px is not None and py is not None:
                dist = distance(self.x, self.y, px, py)
                if dist > 8.5:
                    self.state = NPCState.IDLE
                    self.idle_timer = 2.0
                elif dist > 1.5:
                    # 천천히 다가감
                    dx, dy = direction_to(self.x, self.y, px, py)
                    speed = 0.5 * dt
                    new_x = self.x + dx * speed
                    new_y = self.y + dy * speed

                    if world.is_walkable(new_x + 0.5, self.y + 0.9):
                        self.x = new_x
                    if world.is_walkable(self.x + 0.5, new_y + 0.9):
                        self.y = new_y
                else:
                    # 플레이어와 충분히 가까움
                    pass
            else:
                self.state = NPCState.IDLE
                
            # 애니메이션
            self.animation_timer += dt
            if self.animation_timer >= 0.2:
                self.animation_timer -= 0.2
                self.animation_frame = (self.animation_frame + 1) % 8

        # 느낌표 타이머
        if hasattr(self, 'show_exclamation') and self.show_exclamation:
            if not hasattr(self, 'exclamation_timer'):
                self.exclamation_timer = 0
            self.exclamation_timer -= dt
            if self.exclamation_timer <= 0:
                self.show_exclamation = False

    def is_near(self, px, py, radius=2.0):
        return distance(self.x, self.y, px, py) <= radius

    def to_dict(self):
        return {
            "x": self.x, "y": self.y, "type": self.npc_type,
            "active": self.active,
            "met": getattr(self, "met", False),
            "quest_req": list(self.quest_req) if hasattr(self, "quest_req") else [None, 0],
            "quest_reward": list(self.quest_reward) if hasattr(self, "quest_reward") else [None, 0],
        }

    @classmethod
    def from_dict(cls, data):
        n = cls(data["x"], data["y"], data.get("type", "survivor"))
        n.active = data.get("active", True)
        n.met = data.get("met", False)
        if "quest_req" in data:
            n.quest_req = tuple(data["quest_req"])
        if "quest_reward" in data:
            n.quest_reward = tuple(data["quest_reward"])
        return n


# ============================================================
# 엔티티 관리자
# ============================================================
class EntityManager:
    """모든 엔티티 관리"""

    def __init__(self, difficulty_settings=None):
        self.enemies = []
        self.npcs = []
        self.diff = difficulty_settings or DIFFICULTY_PRESETS["보통"]
        self.spawn_timer = 0
        self.spawn_interval = 5.0 / max(0.1, self.diff.get("enemy_spawn_rate", 1.0))
        self.max_enemies = self.diff.get("max_enemies", 20)
        self.npc_spawn_timer = 0
        self.despawn_distance = 120  # 플레이어로부터 120타일 초과 시 디스폰

    def update(self, dt, player, world):
        # 거리 기반 엔티티 동면/디스폰
        self._cull_distant_entities(player.x, player.y)

        # 적 업데이트 (활성 상태만)
        for enemy in self.enemies:
            if enemy.active:
                enemy.update(dt, player.x, player.y, world, player.is_crouching, self)

        # 비활성 적 제거
        self.enemies = [e for e in self.enemies if e.active]

        # NPC 업데이트 (활성 상태만)
        for npc in self.npcs:
            if npc.active:
                npc.update(dt, world, player.x, player.y)

        # 적 스폰
        self.spawn_timer += dt
        if self.spawn_timer >= self.spawn_interval and len(self.enemies) < self.max_enemies:
            self.spawn_timer = 0
            self._spawn_enemies(player, world)

        # NPC 랜덤 스폰
        self.npc_spawn_timer += dt
        if self.npc_spawn_timer >= 60 and len(self.npcs) < 3:
            self.npc_spawn_timer = 0
            if random.random() < 0.3:
                self._spawn_npc(player, world)

    def _cull_distant_entities(self, px, py):
        """플레이어에서 먼 엔티티 비활성화 (청크 무한 재생성 방지)"""
        for enemy in self.enemies:
            if enemy.active and not enemy.is_dead:
                d = distance(enemy.x, enemy.y, px, py)
                if d > self.despawn_distance:
                    enemy.active = False

        for npc in self.npcs:
            if npc.active:
                d = distance(npc.x, npc.y, px, py)
                if d > self.despawn_distance:
                    npc.active = False

    def _spawn_enemies(self, player, world):
        """플레이어 주변에 적 스폰"""
        player_biome = world.get_biome(int(player.x), int(player.y))
        
        if player_biome in ("도시", "병원구역"):
            spawn_count = random.randint(3, 7)
        elif player_biome == "군사기지":
            spawn_count = random.randint(4, 8)
        elif player_biome in ("산림", "황무지", "호수"):
            spawn_count = random.randint(0, 1)
        else:
            spawn_count = random.randint(1, 3)

        for _ in range(spawn_count):
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(8, 15)
            sx = player.x + math.cos(angle) * dist
            sy = player.y + math.sin(angle) * dist

            if not world.is_walkable(sx, sy):
                continue

            # 바이옴에 따른 적 타입
            biome = world.get_biome(int(sx), int(sy))
            r = random.random()
            if biome in ("군사기지",):
                if r < 0.002:
                    etype = "tank"
                elif r < 0.05:
                    etype = "scav"
                else:
                    etype = random.choice(["normal", "runner"])
            elif biome in ("병원구역",):
                if r < 0.002:
                    etype = "spider"
                elif r < 0.05:
                    etype = "scav"
                else:
                    etype = random.choice(["normal", "runner"])
            elif biome in ("산림", "황무지", "호수"):
                if r < 0.015:
                    etype = "scav"
                else:
                    etype = random.choice(["normal", "runner"])
            else:
                if r < 0.03:
                    etype = "scav"
                else:
                    etype = random.choice(["normal", "normal", "normal", "runner"])

            enemy = Enemy(sx, sy, etype, self.diff)
            self.enemies.append(enemy)

    def _spawn_npc(self, player, world):
        """NPC 스폰"""
        angle = random.uniform(0, math.pi * 2)
        dist = random.uniform(5, 10)
        sx = player.x + math.cos(angle) * dist
        sy = player.y + math.sin(angle) * dist

        if world.is_walkable(sx, sy):
            biome = world.get_biome(int(sx), int(sy))
            
            # 바이옴 특화 NPC 스폰 확률 조정
            if biome == "군사기지":
                types = ["soldier"] * 7 + ["merchant", "survivor", "survivor"]
            elif biome in ("도시", "공장단지"):
                types = ["merchant"] * 6 + ["survivor"] * 3 + ["soldier"]
            elif biome == "병원구역":
                types = ["survivor"] * 6 + ["merchant"] * 3 + ["soldier"]
            else:
                types = ["merchant", "survivor", "soldier"]
                
            npc_type = random.choice(types)
            npc = NPC(sx, sy, npc_type)
            self.npcs.append(npc)

    def get_nearby_enemies(self, x, y, radius):
        return [e for e in self.enemies if distance(e.x, e.y, x, y) <= radius and not e.is_dead]

    def get_nearby_npcs(self, x, y, radius):
        return [n for n in self.npcs if n.is_near(x, y, radius) and n.active]

    def remove_dead_enemies(self, world):
        """사망 적에서 루트 드롭"""
        drops = []
        for e in self.enemies:
            if e.is_dead and e.active:
                loot = e.get_loot()
                for item in loot:
                    world.drop_item(item, e.x, e.y)
                    drops.append((item, e.x, e.y))
        return drops
