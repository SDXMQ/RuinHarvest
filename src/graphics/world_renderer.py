import pygame
import math
import time as pytime
from settings import Colors, TILE_SIZE, CHUNK_SIZE
from renderer import TileRenderer, CharacterRenderer, EnvironmentRenderer, BuildingRenderer, ItemIconRenderer
from items import ITEM_DATABASE
from ui import FontManager
from i18n import t

class WorldSceneRenderer:
    """오버월드 및 인게임 씬 전체 렌더링을 돕는 렌더러 클래스"""
    def __init__(self, game):
        self.game = game

    def draw_tiles(self, surface):
        x1, y1, x2, y2 = self.game.camera.get_visible_area()

        cx1 = x1 // CHUNK_SIZE
        cx2 = x2 // CHUNK_SIZE
        cy1 = y1 // CHUNK_SIZE
        cy2 = y2 // CHUNK_SIZE

        for cy in range(cy1, cy2 + 1):
            for cx in range(cx1, cx2 + 1):
                chunk = self.game.world.get_chunk(cx, cy)

                if chunk.surface is None or chunk.dirty:
                    chunk_px_size = CHUNK_SIZE * TILE_SIZE
                    chunk.surface = pygame.Surface((chunk_px_size, chunk_px_size)).convert()

                    for ly in range(CHUNK_SIZE):
                        for lx in range(CHUNK_SIZE):
                            wx = cx * CHUNK_SIZE + lx
                            wy = cy * CHUNK_SIZE + ly
                            tile_type = chunk.get_tile(lx, ly)
                            variant = (wx * 7 + wy * 13) % 4
                            tile_surf = TileRenderer.get_tile(tile_type, variant)
                            chunk.surface.blit(tile_surf, (lx * TILE_SIZE, ly * TILE_SIZE))

                    chunk.dirty = False

                sx, sy_pos = self.game.camera.world_to_screen(cx * CHUNK_SIZE, cy * CHUNK_SIZE)
                surface.blit(chunk.surface, (sx, sy_pos))

    def draw_ground_items(self, surface):
        x1, y1, x2, y2 = self.game.camera.get_visible_area()

        for cy in range(y1 // CHUNK_SIZE - 1, y2 // CHUNK_SIZE + 2):
            for cx in range(x1 // CHUNK_SIZE - 1, x2 // CHUNK_SIZE + 2):
                chunk = self.game.world.chunks.get((cx, cy))
                if not chunk:
                    continue
                for item_tuple in chunk.items_on_ground:
                    item_name, ix, iy = item_tuple[0], item_tuple[1], item_tuple[2]
                    sx, sy = self.game.camera.world_to_screen(ix, iy)
                    if -32 <= sx <= self.game.screen_w + 32 and -32 <= sy <= self.game.screen_h + 32:
                        icon = ItemIconRenderer.get_icon(item_name)
                        bounce = math.sin(pytime.time() * 3 + ix + iy) * 3
                        surface.blit(icon, (sx + 4, sy + 4 + int(bounce)))

    def draw_environment(self, surface):
        x1, y1, x2, y2 = self.game.camera.get_visible_area()

        for cy in range(y1 // CHUNK_SIZE - 1, y2 // CHUNK_SIZE + 2):
            for cx in range(x1 // CHUNK_SIZE - 1, x2 // CHUNK_SIZE + 2):
                chunk = self.game.world.chunks.get((cx, cy))
                if not chunk:
                    continue
                for obj in chunk.objects:
                    if not (x1 - 2 <= obj.x <= x2 + 2 and y1 - 2 <= obj.y <= y2 + 2):
                        continue

                    sx, sy = self.game.camera.world_to_screen(obj.x, obj.y)

                    if obj.obj_type.startswith("tree_"):
                        if getattr(obj, "looted", False):
                            sprite = EnvironmentRenderer.get_stump(obj.variant)
                            surface.blit(sprite, (sx - sprite.get_width() // 2,
                                                sy - sprite.get_height() + TILE_SIZE // 2))
                        else:
                            tree_type = obj.obj_type.replace("tree_", "")
                            sprite = EnvironmentRenderer.get_tree(tree_type, obj.variant)
                            surface.blit(sprite, (sx - sprite.get_width() // 2,
                                                sy - sprite.get_height() + TILE_SIZE // 2))
                    elif obj.obj_type == "rock":
                        sprite = EnvironmentRenderer.get_rock(obj.variant)
                        surface.blit(sprite, (sx, sy))
                    elif obj.obj_type == "bush":
                        sprite = EnvironmentRenderer.get_bush(obj.variant)
                        surface.blit(sprite, (sx, sy))

    def draw_buildings(self, surface):
        x1, y1, x2, y2 = self.game.camera.get_visible_area()

        for cy in range(y1 // CHUNK_SIZE - 1, y2 // CHUNK_SIZE + 2):
            for cx in range(x1 // CHUNK_SIZE - 1, x2 // CHUNK_SIZE + 2):
                chunk = self.game.world.chunks.get((cx, cy))
                if not chunk:
                    continue
                for building in chunk.buildings:
                    bx = building.x
                    by = building.y
                    if not (x1 - 5 <= bx <= x2 + 5 and y1 - 5 <= by <= y2 + 5):
                        continue

                    sprite = BuildingRenderer.get_building(
                        building.building_type, building.width, building.height, building.variant
                    )
                    sx, sy = self.game.camera.world_to_screen(bx, by)
                    
                    # 플레이어가 건물 뒤편(북쪽)에 있어 가려지는 경우 원본은 그리지 않음(나중에 반투명으로 덧그림)
                    px, py = self.game.player.x, self.game.player.y
                    if bx - 0.5 <= px < bx + building.width + 0.5 and by - 2.5 <= py < by:
                        continue
                        
                    surface.blit(sprite, (sx, sy))

                    if building.explored:
                        font = FontManager.get(10)
                        mark = font.render("✓", True, Colors.UI_SUCCESS)
                        surface.blit(mark, (sx + 2, sy + 2))

    def draw_occluding_buildings(self, surface):
        x1, y1, x2, y2 = self.game.camera.get_visible_area()
        px, py = self.game.player.x, self.game.player.y

        for cy in range(y1 // CHUNK_SIZE - 1, y2 // CHUNK_SIZE + 2):
            for cx in range(x1 // CHUNK_SIZE - 1, x2 // CHUNK_SIZE + 2):
                chunk = self.game.world.chunks.get((cx, cy))
                if not chunk:
                    continue
                for building in chunk.buildings:
                    bx = building.x
                    by = building.y
                    if not (x1 - 5 <= bx <= x2 + 5 and y1 - 5 <= by <= y2 + 5):
                        continue

                    # 플레이어가 건물 뒤편(북쪽)에 위치할 경우 반투명 덧그리기
                    if bx - 0.5 <= px < bx + building.width + 0.5 and by - 2.5 <= py < by:
                        sprite = BuildingRenderer.get_building(
                            building.building_type, building.width, building.height, building.variant
                        ).copy()
                        sprite.set_alpha(128)
                        sx, sy = self.game.camera.world_to_screen(bx, by)
                        surface.blit(sprite, (sx, sy))

    def draw_extraction_points(self, surface):
        if not self.game.world or not hasattr(self.game.world, 'extraction_points'):
            return
        
        font = FontManager.get(11)
        for ep in self.game.world.extraction_points:
            if not self.game.camera.is_visible(ep["x"], ep["y"]):
                continue
                
            sx, sy = self.game.camera.world_to_screen(ep["x"], ep["y"])
            
            # 탈출구 중심에 반투명한 영역 그리기 (반경 1.5타일 = 48픽셀)
            radius = int(1.5 * TILE_SIZE * self.game.camera.zoom)
            area_surf = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
            
            color = (50, 200, 100, 40)
            border_color = (50, 200, 100, 150)
            if ep["type"] == "key_required":
                color = (200, 150, 50, 40)
                border_color = (200, 150, 50, 150)
            elif ep["type"] == "time_locked":
                color = (200, 50, 50, 40)
                border_color = (200, 50, 50, 150)
                
            pygame.draw.circle(area_surf, color, (radius, radius), radius)
            pygame.draw.circle(area_surf, border_color, (radius, radius), radius, 2)
            # 연막 입자 효과 (부유하는 반투명 연기)
            t_val = pytime.time()
            for j in range(5):
                smoke_x = radius + math.sin(t_val * 1.5 + j * 1.2) * radius * 0.5
                smoke_y = radius + math.cos(t_val * 1.0 + j * 0.9) * radius * 0.4 - j * 3
                smoke_r = int(radius * 0.2 + math.sin(t_val + j) * 3)
                smoke_alpha = max(10, min(60, 40 + int(math.sin(t_val * 2 + j) * 20)))
                smoke_color = (color[0], color[1], color[2], smoke_alpha)
                pygame.draw.circle(area_surf, smoke_color, (int(smoke_x), int(smoke_y)), smoke_r)
            surface.blit(area_surf, (sx + TILE_SIZE // 2 - radius, sy + TILE_SIZE // 2 - radius))
            
            # 탈출구 텍스트 라벨
            label_text = ep["name"]
            if ep["type"] == "key_required":
                label_text += " [열쇠 필요]"
            elif ep["type"] == "time_locked":
                label_text += " [시간제한]"
            
            text_surf = font.render(label_text, True, (255, 255, 255))
            tx = sx + TILE_SIZE // 2 - text_surf.get_width() // 2
            ty = sy - 20
            
            bg = pygame.Surface((text_surf.get_width() + 8, 16), pygame.SRCALPHA)
            bg.fill((20, 22, 30, 200))
            surface.blit(bg, (tx - 4, ty - 2))
            surface.blit(text_surf, (tx, ty))

    def draw_entities(self, surface):
        for zombie in self.game.entity_manager.zombies:
            if not zombie.active:
                continue
            if not self.game.camera.is_visible(zombie.x, zombie.y):
                continue

            sx, sy = self.game.camera.world_to_screen(zombie.x, zombie.y)
            sprite = CharacterRenderer.get_zombie_sprite(
                zombie.zombie_type, zombie.direction, zombie.animation_frame
            )

            if zombie.state == "hurt" and int(zombie.hurt_timer * 10) % 2:
                sprite = sprite.copy()
                sprite.fill((255, 100, 100, 128), special_flags=pygame.BLEND_RGBA_MULT)

            surface.blit(sprite, (sx, sy))

            if zombie.hp < zombie.max_hp:
                bar_w = TILE_SIZE
                bar_h = 3
                ratio = zombie.hp / zombie.max_hp
                pygame.draw.rect(surface, (40, 40, 45), (sx, sy - 5, bar_w, bar_h))
                pygame.draw.rect(surface, (220, 50, 50), (sx, sy - 5, int(bar_w * ratio), bar_h))

            # 총성 어그로 느낌표
            if zombie.aggro_alert > 0:
                alert_font = FontManager.get(14)
                alert_surf = alert_font.render("!", True, (255, 50, 50))
                bounce = math.sin(pytime.time() * 8) * 2
                surface.blit(alert_surf, (sx + TILE_SIZE // 2 - alert_surf.get_width() // 2,
                                          sy - 15 + int(bounce)))

        for npc in self.game.entity_manager.npcs:
            if not npc.active:
                continue
            if not self.game.camera.is_visible(npc.x, npc.y):
                continue

            sx, sy = self.game.camera.world_to_screen(npc.x, npc.y)
            sprite = CharacterRenderer.get_npc_sprite(
                npc.npc_type, npc.direction, npc.animation_frame
            )
            surface.blit(sprite, (sx, sy))

            font = FontManager.get(10)
            name_surf = font.render(npc.name, True, Colors.UI_ACCENT_WARM)
            surface.blit(name_surf, (sx + TILE_SIZE // 2 - name_surf.get_width() // 2, sy - 12))

            if getattr(npc, 'show_exclamation', False):
                excl_surf = font.render("!", True, (255, 255, 50))
                import time
                offset = math.sin(time.time() * 10) * 3
                surface.blit(excl_surf, (sx + TILE_SIZE // 2 - excl_surf.get_width() // 2, sy - 25 + offset))

    def draw_player(self, surface):
        sx, sy = self.game.camera.world_to_screen(self.game.player.x, self.game.player.y)
        has_weapon = self.game.player.equipped.get("weapon") is not None
        sprite = CharacterRenderer.get_player_sprite(
            self.game.player.direction, self.game.player.animation_frame, has_weapon, self.game.player.is_crouching
        )

        if self.game.player.invincible_timer > 0 and int(self.game.player.invincible_timer * 10) % 2:
            sprite = sprite.copy()
            sprite.set_alpha(128)

        surface.blit(sprite, (sx, sy))
        
        self.draw_radio_scan(surface, sx, sy)

    def draw_radio_scan(self, surface, sx, sy):
        # 라디오 스캔 방향 안내 (빨간 화살표가 플레이어 주변 원을 따라 회전)
        if not hasattr(self.game.player, 'radio_scan_timer') or self.game.player.radio_scan_timer <= 0:
            return
            
        target_type = getattr(self.game.player, 'radio_scan_target', '')
        if not target_type:
            return
            
        targets = []
        # 청크에서 빌딩 수집
        for (cx, cy), chunk in self.game.world.chunks.items():
            for b in chunk.buildings:
                btype = getattr(b, "building_type", "")
                variant = getattr(b, "variant", 0)
                # 통신 중계소 판정
                if target_type == "radio_tower":
                    if btype == "military" and variant == 999:
                        targets.append((b.x + b.width/2, b.y + b.height/2))
                # 군사기지 판정
                elif target_type == "military":
                    if btype == "military" and variant != 999:
                        targets.append((b.x + b.width/2, b.y + b.height/2))
                # 경찰서 판정
                elif target_type == "police":
                    if btype == "police":
                        targets.append((b.x + b.width/2, b.y + b.height/2))
                    
        # 탈출구
        if not targets and target_type == "escape" and hasattr(self.game.world, 'extraction_points'):
            targets = [ (ep["x"]+0.5, ep["y"]+0.5) for ep in self.game.world.extraction_points ]
            
        cx, cy = sx + 16, sy + 16 # 플레이어 스프라이트 중심
        r = 35 # 화살표 궤도 반경

        # 가이드 원 그리기 (반투명 느낌의 얇은 빨간 선)
        pygame.draw.circle(surface, (255, 80, 80), (int(cx), int(cy)), r, 1)

        for tx, ty in targets:
            dx = tx - self.game.player.x
            dy = ty - self.game.player.y
            angle = math.atan2(dy, dx)
            
            # 화살표 머리(삼각형)의 중심 좌표
            tx_pos = cx + math.cos(angle) * r
            ty_pos = cy + math.sin(angle) * r
            
            # 화살표 꼬리선 그리기
            start_tail = (cx + math.cos(angle) * (r - 10), cy + math.sin(angle) * (r - 10))
            end_tail = (cx + math.cos(angle) * r, cy + math.sin(angle) * r)
            pygame.draw.line(surface, (255, 40, 40), start_tail, end_tail, 3)

            # 화살표 삼각 머리 꼭지점 계산
            p1 = (tx_pos + math.cos(angle) * 10, ty_pos + math.sin(angle) * 10)
            p2 = (tx_pos + math.cos(angle + 2.4) * 6, ty_pos + math.sin(angle + 2.4) * 6)
            p3 = (tx_pos + math.cos(angle - 2.4) * 6, ty_pos + math.sin(angle - 2.4) * 6)
            
            pygame.draw.polygon(surface, (255, 40, 40), [p1, p2, p3])

    def draw_aim_indicator(self, surface, px, py, camera):
        if self.game.inventory_ui.visible or self.game.crafting_ui.visible or self.game.dialogue_ui.visible:
            return

        weapon = self.game.player.equipped.get("weapon")
        weapon_data = ITEM_DATABASE.get(weapon, {}) if weapon else {}
        weapon_type = weapon_data.get("type", "melee")
        attack_range = self.game.player.get_attack_range()

        mouse_sx, mouse_sy = pygame.mouse.get_pos()
        mouse_wx, mouse_wy = camera.screen_to_world(mouse_sx, mouse_sy)
        
        center_x = px + 0.5
        center_y = py + 0.5
        
        attack_angle = math.atan2(mouse_wy - center_y, mouse_wx - center_x)
        psx, psy = camera.world_to_screen(center_x, center_y)
        
        radius = int(attack_range * TILE_SIZE * camera.zoom)
        indicator_surf = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
        center = (radius, radius)
        
        points = [center]
        steps = 10
        if weapon_type == "melee":
            start_angle = attack_angle - math.pi / 6
            end_angle = attack_angle + math.pi / 6
            for i in range(steps + 1):
                ang = start_angle + (end_angle - start_angle) * i / steps
                dx = math.cos(ang) * radius
                dy = math.sin(ang) * radius
                points.append((radius + dx, radius + dy))
            pygame.draw.polygon(indicator_surf, (255, 100, 100, 30), points)
            pygame.draw.polygon(indicator_surf, (255, 50, 50, 80), points, 1)
        else:
            start_angle = attack_angle - math.pi / 12
            end_angle = attack_angle + math.pi / 12
            for i in range(steps + 1):
                ang = start_angle + (end_angle - start_angle) * i / steps
                dx = math.cos(ang) * radius
                dy = math.sin(ang) * radius
                points.append((radius + dx, radius + dy))
            pygame.draw.polygon(indicator_surf, (100, 255, 100, 30), points)
            pygame.draw.polygon(indicator_surf, (50, 255, 50, 80), points, 1)
            
            end_x = psx + math.cos(attack_angle) * radius
            end_y = psy + math.sin(attack_angle) * radius
            pygame.draw.line(surface, (255, 0, 0, 150), (psx, psy), (end_x, end_y), 1)

        surface.blit(indicator_surf, (psx - radius, psy - radius))

    def draw_combat_effects(self, surface, camera=None):
        cam = camera or self.game.camera
        font = FontManager.get(14)

        # 투명도 드로잉을 위한 임시 알파 서피스 생성
        temp_alpha_surf = pygame.Surface((self.game.screen_w, self.game.screen_h), pygame.SRCALPHA)

        # 1. 탄막 궤적 (Bullet Tracers)
        for tr in self.game.combat_system.tracers:
            if tr["timer"] <= 0:
                continue
            
            sx1, sy1 = cam.world_to_screen(tr["start"][0], tr["start"][1])
            sx2, sy2 = cam.world_to_screen(tr["end"][0], tr["end"][1])
            
            # 남은 시간에 따라 페이드 아웃
            alpha_ratio = tr["timer"] / tr["max_timer"]
            alpha = max(0, min(255, int(200 * alpha_ratio)))
            color = tr["color"]
            rgba_color = (color[0], color[1], color[2], alpha)
            
            # 점점 얇아지는 궤적선
            width = max(1, int(3 * alpha_ratio))
            pygame.draw.line(temp_alpha_surf, rgba_color, (sx1, sy1), (sx2, sy2), width)

        # 2. AI 조준선 / 레이저 사이트 (Laser Sights)
        # 플레이어 시야 내의 적이나 교전 상태의 적의 조준선을 실시간 렌더링
        zombies = []
        if self.game.current_interior:
            zombies = self.game.interior_zombies
        else:
            zombies = self.game.entity_manager.zombies

        t_val = pytime.time()
        for zombie in zombies:
            if not zombie.active or zombie.is_dead:
                continue
            
            target = getattr(zombie, "target", None)
            if zombie.state == "engage" and zombie.can_see_target and target is not None:
                # 타겟 위치 좌표 획득
                if hasattr(target, "x"):
                    tx, ty = target.x + 0.5, target.y + 0.5
                elif isinstance(target, tuple):
                    tx, ty = target[0], target[1]
                else:
                    tx, ty = self.game.player.x + 0.5, self.game.player.y + 0.5
                
                sx1, sy1 = cam.world_to_screen(zombie.x + 0.5, zombie.y + 0.5)
                sx2, sy2 = cam.world_to_screen(tx, ty)
                
                # 팩션 종류에 따라 레이저 빔 연출 차별화
                is_pmc = getattr(zombie, "faction", "scav") == "pmc"
                
                # 실시간으로 밝기가 깜빡여 보이게 함 (펄싱 효과)
                pulse = 100 + int(math.sin(t_val * 25) * 50)
                
                if is_pmc:
                    # PMC: 정밀한 연두빛 레이저
                    laser_color = (100, 255, 100, min(255, pulse + 20))
                    width = 1
                else:
                    # Scav: 투박하고 어두운 붉은색 레이저
                    laser_color = (255, 80, 50, max(40, pulse - 30))
                    width = 1
                
                pygame.draw.line(temp_alpha_surf, laser_color, (sx1, sy1), (sx2, sy2), width)
                # 레이저 끝점의 조준 도트 렌더링
                pygame.draw.circle(temp_alpha_surf, (laser_color[0], laser_color[1], laser_color[2], min(255, laser_color[3] + 60)), (int(sx2), int(sy2)), 2)

        surface.blit(temp_alpha_surf, (0, 0))

        # 대미지 데칼 텍스트 렌더링
        for x, y, dmg, timer, color in self.game.combat_system.get_damage_numbers():
            sx, sy = cam.world_to_screen(x, y)
            alpha = max(0, min(255, int(255 * min(1, timer))))
            
            text = str(dmg)
            try:
                if isinstance(dmg, (int, float)):
                    text = str(int(dmg))
                elif isinstance(dmg, str) and dmg.replace('.', '', 1).isdigit():
                    text = str(int(float(dmg)))
            except ValueError:
                pass
                
            dmg_surf = font.render(text, True, color)
            dmg_surf.set_alpha(alpha)
            surface.blit(dmg_surf, (sx, sy))

    def draw_interaction_hint(self, surface):
        if not self.game.player:
            return
        if self.game.inventory_ui.visible or self.game.crafting_ui.visible or self.game.dialogue_ui.visible:
            return

        px, py = self.game.player.x, self.game.player.y
        hint_text = None

        ground_items = self.game.world.get_ground_items_near(px, py, 1.5)
        if ground_items:
            item_name = ground_items[0][0][0]
            hint_text = f"[E] {item_name} 줍기"

        if not hint_text:
            npcs = self.game.entity_manager.get_nearby_npcs(px, py, 2.0)
            if npcs:
                hint_text = f"[E] {npcs[0].name}과 대화"

        if not hint_text:
            buildings = self.game.world.get_nearby_buildings(int(px), int(py), 2)
            for b in buildings:
                if b.is_near_door(px, py):
                    hint_text = t("press_e_enter")
                    break

        if not hint_text:
            objects = self.game.world.get_nearby_objects(int(px), int(py), 1.5)
            for obj in objects:
                if obj.obj_type.startswith("tree_") and not obj.looted:
                    hint_text = "[E] 나무 채집"
                    break
                elif obj.obj_type == "bush" and not obj.looted:
                    hint_text = "[E] 관목 조사"
                    break

        if hint_text:
            font = FontManager.get(13)
            text_surf = font.render(hint_text, True, Colors.UI_ACCENT)
            tw = text_surf.get_width()
            tx = (self.game.screen_w - tw) // 2
            ty = self.game.screen_h // 2 + 60

            bg = pygame.Surface((tw + 16, 24), pygame.SRCALPHA)
            pygame.draw.rect(bg, (15, 18, 28, 180), (0, 0, tw + 16, 24), border_radius=6)
            surface.blit(bg, (tx - 8, ty - 3))
            surface.blit(text_surf, (tx, ty))

    def draw_interior(self, surface):
        """건물 내부 렌더링"""
        if not self.game.current_interior or not self.game.interior_camera:
            return

        surface.fill((20, 18, 25))

        interior = self.game.current_interior
        cam = self.game.interior_camera

        # 타일 그리기
        for ty in range(interior.height):
            for tx in range(interior.width):
                tile = interior.get_tile(tx, ty)
                sx, sy = cam.world_to_screen(tx, ty)

                if sx < -TILE_SIZE or sx > self.game.screen_w + TILE_SIZE:
                    continue
                if sy < -TILE_SIZE or sy > self.game.screen_h + TILE_SIZE:
                    continue

                if tile == "wall":
                    pygame.draw.rect(surface, (55, 50, 60),
                                    (sx, sy, TILE_SIZE, TILE_SIZE))
                    pygame.draw.rect(surface, (70, 65, 75),
                                    (sx, sy, TILE_SIZE, TILE_SIZE), 1)
                elif tile == "floor":
                    color = Colors.FLOOR_WOOD if (tx + ty) % 2 == 0 else (145, 108, 65)
                    pygame.draw.rect(surface, color,
                                    (sx, sy, TILE_SIZE, TILE_SIZE))
                elif tile == "door":
                    pygame.draw.rect(surface, Colors.DOOR,
                                    (sx, sy, TILE_SIZE, TILE_SIZE))
                    # 출구 표시
                    font = FontManager.get(10)
                    exit_text = font.render("출구", True, (255, 255, 200))
                    surface.blit(exit_text, (sx + 4, sy + 10))
                elif tile == "stairs_up":
                    # 올라가는 계단 표시
                    pygame.draw.rect(surface, (100, 90, 80), (sx, sy, TILE_SIZE, TILE_SIZE))
                    font = FontManager.get(10)
                    exit_text = font.render("위층", True, (255, 255, 200))
                    surface.blit(exit_text, (sx + 4, sy + 10))
                    # 간단한 계단 무늬
                    for i in range(4):
                        pygame.draw.line(surface, (80, 70, 60), (sx, sy + i * 8), (sx + TILE_SIZE, sy + i * 8))
                elif tile == "stairs_down":
                    # 내려가는 계단 표시
                    pygame.draw.rect(surface, (80, 70, 60), (sx, sy, TILE_SIZE, TILE_SIZE))
                    font = FontManager.get(10)
                    exit_text = font.render("아래층", True, (255, 255, 200))
                    surface.blit(exit_text, (sx + 2, sy + 10))
                    for i in range(4):
                        pygame.draw.line(surface, (60, 50, 40), (sx, sy + i * 8), (sx + TILE_SIZE, sy + i * 8))
                elif tile == "furniture":
                    pygame.draw.rect(surface, Colors.FLOOR_WOOD,
                                    (sx, sy, TILE_SIZE, TILE_SIZE))
                elif tile == "window":
                    # 창문 타일: 벽 배경 + 반투명 파란 유리 + 십자 격자
                    pygame.draw.rect(surface, (55, 50, 60),
                                    (sx, sy, TILE_SIZE, TILE_SIZE))
                    win_surf = pygame.Surface((TILE_SIZE - 4, TILE_SIZE - 4), pygame.SRCALPHA)
                    win_surf.fill((120, 180, 220, 100))
                    surface.blit(win_surf, (sx + 2, sy + 2))
                    # 십자 격자
                    pygame.draw.line(surface, (80, 75, 85), (sx + TILE_SIZE // 2, sy + 2), (sx + TILE_SIZE // 2, sy + TILE_SIZE - 2), 1)
                    pygame.draw.line(surface, (80, 75, 85), (sx + 2, sy + TILE_SIZE // 2), (sx + TILE_SIZE - 2, sy + TILE_SIZE // 2), 1)
                    pygame.draw.rect(surface, (90, 85, 95), (sx, sy, TILE_SIZE, TILE_SIZE), 1)

        # 가구 그리기
        for furn in interior.furniture:
            sx, sy = cam.world_to_screen(furn.x, furn.y)

            if furn.searched:
                color = (80, 75, 70)
                border = (60, 55, 50)
            else:
                color = (120, 90, 55)
                border = (160, 120, 70)

            pygame.draw.rect(surface, color, (sx + 2, sy + 2, TILE_SIZE - 4, TILE_SIZE - 4), border_radius=3)
            pygame.draw.rect(surface, border, (sx + 2, sy + 2, TILE_SIZE - 4, TILE_SIZE - 4), 1, border_radius=3)

            # 가구 이름
            font = FontManager.get(8)
            name_surf = font.render(furn.type, True, (200, 200, 200) if not furn.searched else (100, 100, 100))
            surface.blit(name_surf, (sx + 2, sy + TILE_SIZE - 12))

        # 내부 바닥 아이템 그리기
        for item_tuple in interior.items_on_ground:
            item_name, ix, iy = item_tuple[0], item_tuple[1], item_tuple[2]
            isx, isy = cam.world_to_screen(ix, iy)
            icon = ItemIconRenderer.get_icon(item_name)
            bounce = math.sin(pytime.time() * 3 + ix + iy) * 3
            surface.blit(icon, (isx + 4, isy + 4 + int(bounce)))

        # 내부 좀비 그리기
        for z in self.game.interior_zombies:
            if z.active and not z.is_dead:
                zsx, zsy = cam.world_to_screen(z.x, z.y)
                sprite = CharacterRenderer.get_zombie_sprite(z.zombie_type, z.direction, z.animation_frame)
                
                # 피격 시 깜빡임
                if z.state == "hurt" and int(z.hurt_timer * 10) % 2:
                    sprite = sprite.copy()
                    sprite.fill((255, 100, 100, 128), special_flags=pygame.BLEND_RGBA_MULT)
                    
                surface.blit(sprite, (zsx, zsy))
                
                # 체력바
                if z.hp < z.max_hp:
                    bar_w = TILE_SIZE
                    bar_h = 3
                    ratio = z.hp / z.max_hp
                    pygame.draw.rect(surface, (40, 40, 45), (zsx, zsy - 5, bar_w, bar_h))
                    pygame.draw.rect(surface, (220, 50, 50), (zsx, zsy - 5, int(bar_w * ratio), bar_h))

                # 총성 어그로 느낌표
                if z.aggro_alert > 0:
                    alert_font = FontManager.get(14)
                    alert_surf = alert_font.render("!", True, (255, 50, 50))
                    bounce = math.sin(pytime.time() * 8) * 2
                    surface.blit(alert_surf, (zsx + TILE_SIZE // 2 - alert_surf.get_width() // 2,
                                              zsy - 15 + int(bounce)))

        # 전투 이펙트 및 파티클
        self.draw_combat_effects(surface, cam)
        self.game.game_particles.draw(surface, cam)

        # 플레이어 그리기
        psx, psy = cam.world_to_screen(self.game.player.x, self.game.player.y)
        player_sprite = CharacterRenderer.get_player_sprite(
            self.game.player.direction, self.game.player.animation_frame, self.game.player.is_sprinting, self.game.player.is_crouching
        )
        surface.blit(player_sprite, (psx, psy))
        self.draw_aim_indicator(surface, self.game.player.x, self.game.player.y, cam)

        # 창문 시야 오버레이 및 실외 렌더링
        window_vision = getattr(self.game, 'window_vision', None)
        if window_vision:
            win = window_vision["win"]
            wsx, wsy = cam.world_to_screen(win["x"], win["y"])

            win_angle = math.atan2(window_vision["dir_y"], window_vision["dir_x"])
            cone_range = window_vision["range"] * TILE_SIZE
            half_fov = math.pi / 6  # 30도

            cx = wsx + TILE_SIZE // 2
            cy = wsy + TILE_SIZE // 2

            # --- 실외 풍경 실제 렌더링 ---
            ext_cam = self.game.camera
            old_x, old_y = ext_cam.x, ext_cam.y

            wx = window_vision["world_x"]
            wy = window_vision["world_y"]
            ext_cam.x = wx * TILE_SIZE - cx / ext_cam.zoom
            ext_cam.y = wy * TILE_SIZE - cy / ext_cam.zoom

            ext_surf = pygame.Surface((self.game.screen_w, self.game.screen_h), pygame.SRCALPHA)

            self.draw_tiles(ext_surf)
            self.draw_ground_items(ext_surf)
            self.draw_environment(ext_surf)
            self.draw_buildings(ext_surf)
            self.draw_entities(ext_surf)
            self.draw_occluding_buildings(ext_surf)

            ext_cam.x, ext_cam.y = old_x, old_y

            # 부채꼴 마스크 생성
            mask_surf = pygame.Surface((self.game.screen_w, self.game.screen_h), pygame.SRCALPHA)
            num_points = 12
            points = [(cx, cy)]
            for i in range(num_points + 1):
                a = win_angle - half_fov + (2 * half_fov * i / num_points)
                px = cx + math.cos(a) * cone_range
                py = cy + math.sin(a) * cone_range
                points.append((int(px), int(py)))

            if len(points) >= 3:
                # 마스크: 부채꼴 영역은 흰색(완전 불투명)
                pygame.draw.polygon(mask_surf, (255, 255, 255, 255), points)
                # 실외 서피스에 마스크 적용
                ext_surf.blit(mask_surf, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
                # 최종 화면에 블릿
                surface.blit(ext_surf, (0, 0))
                
                # 푸른빛 오버레이 테두리 (알파 블렌딩을 위해 임시 서피스 사용)
                overlay_surf = pygame.Surface((self.game.screen_w, self.game.screen_h), pygame.SRCALPHA)
                pygame.draw.polygon(overlay_surf, (120, 200, 255, 35), points)
                pygame.draw.polygon(overlay_surf, (120, 200, 255, 60), points, 2)
                surface.blit(overlay_surf, (0, 0))

            # 좀비 수 표시 (실외 렌더링 위에)
            visible_zombies = window_vision.get("zombies", [])
            if visible_zombies:
                count_font = FontManager.get(10)
                count_text = count_font.render(f"외부 좀비: {len(visible_zombies)}", True, (255, 200, 100))
                surface.blit(count_text, (wsx - 10, wsy - 18))

        # 상호작용 힌트 (건물 내부용)
        ix, iy = self.game.player.x, self.game.player.y
        font = FontManager.get(12)
        hint_text = None

        if interior.is_at_exit(ix, iy):
            if interior.floor_idx > 0:
                hint_text = "[E] 아래층으로 내려가기"
            else:
                hint_text = t("press_e_exit")
        elif hasattr(interior, 'is_at_stairs_up') and interior.is_at_stairs_up(ix, iy):
            hint_text = "[E] 위층으로 올라가기"
        else:
            furn = interior.get_unsearched_furniture_near(ix, iy, 1.5)
            if furn:
                hint_text = f"{t('press_e_search')} [{furn.type}]"
            else:
                searched = interior.get_furniture_at(ix, iy, 1.5)
                if searched and searched.searched:
                    hint_text = t("searched_already")

        if hint_text:
            hint_surf = font.render(hint_text, True, Colors.UI_ACCENT)
            hx = (self.game.screen_w - hint_surf.get_width()) // 2
            hy = self.game.screen_h - 80
            bg = pygame.Surface((hint_surf.get_width() + 16, 24), pygame.SRCALPHA)
            bg.fill((10, 12, 20, 160))
            surface.blit(bg, (hx - 8, hy - 4))
            surface.blit(hint_surf, (hx, hy))

