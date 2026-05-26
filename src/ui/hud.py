import pygame
import math
from settings import Colors, RESOLUTION_OPTIONS, DIFFICULTY_PRESETS, DEFAULT_WORLD_SETTINGS, GameSettings, TILE_SIZE
from renderer import draw_rounded_rect, draw_gradient_rect, draw_glow, ItemIconRenderer
from items import ITEM_DATABASE, ItemCategory
from crafting import CRAFTING_RECIPES, RECIPE_CATEGORIES
from utils import wrap_text, ease_out_cubic, lerp
from .fonts import FontManager
from i18n import t


class HUD:
    """인게임 HUD"""

    def __init__(self, screen_w, screen_h):
        self.sw = screen_w
        self.sh = screen_h
        self.notification_queue = []
        self.shown_hp = 100
        self.shown_hunger = 100
        self.shown_thirst = 100
        self.shown_stress = 0
        self.shown_stamina = 100
        # 미니맵 캐시 서피스 및 타이머 초기화 (120x120 크기)
        self.minimap_surface = pygame.Surface((120, 120), pygame.SRCALPHA)
        self.minimap_surface.fill((10, 12, 18, 250))
        self.minimap_timer = 1.0  # 처음에 즉시 생성되도록 1.0으로 초기화
        self.last_player_tile_pos = None

    def resize(self, w, h):
        self.sw = w
        self.sh = h

    def update(self, dt, player):
        # 부드러운 바 애니메이션
        self.shown_hp = lerp(self.shown_hp, player.hp, 0.1)
        self.shown_hunger = lerp(self.shown_hunger, player.hunger, 0.1)
        self.shown_thirst = lerp(self.shown_thirst, player.thirst, 0.1)
        self.shown_stress = lerp(self.shown_stress, player.stress, 0.1)
        self.shown_stamina = lerp(self.shown_stamina, player.stamina, 0.1)

        # 알림 업데이트
        self.notification_queue = [(msg, t - dt, a) for msg, t, a in self.notification_queue if t > 0]

    def add_notification(self, message, duration=3.0):
        self.notification_queue.append((message, duration, 0))

    def draw(self, surface, player, time_system, weather_system, current_day, total_days, raid_time_left=None, world=None, extract_target=None, extract_timer=None, dt=0.0):
        self._draw_stat_bars(surface, player)
        self._draw_time_info(surface, time_system, current_day, total_days, raid_time_left)
        self._draw_weather_info(surface, weather_system)
        self._draw_minimap(surface, player, world, dt)
        self._draw_notifications(surface)
        self._draw_equipped_weapon(surface, player)
        self._draw_quick_info(surface, player)
        self._draw_crouch_indicator(surface, player)
        if extract_target and extract_timer is not None:
            self._draw_extraction_hud(surface, extract_target, extract_timer)

    def _draw_stat_bars(self, surface, player):
        """스탯 바 (좌측 상단)"""
        x, y = 15, 15
        bar_w, bar_h = 180, 14
        spacing = 22
        font = FontManager.get(12)

        bars = [
            (t("hp"), self.shown_hp, 100, (220, 50, 50), (180, 30, 30)),
            (t("hunger"), self.shown_hunger, 100, (210, 160, 50), (170, 130, 30)),
            (t("thirst"), self.shown_thirst, 100, (50, 140, 220), (30, 110, 180)),
            (t("stress"), self.shown_stress, 100, (180, 50, 200), (150, 30, 170)),
            (t("stamina"), self.shown_stamina, 100, (50, 200, 100), (30, 160, 70)),
        ]

        # 배경 패널
        panel_h = len(bars) * spacing + 15
        draw_rounded_rect(surface, (15, 15, 25, 180), (x - 5, y - 5, bar_w + 55, panel_h), radius=8)

        for i, (label, value, max_val, color, dark_color) in enumerate(bars):
            by = y + i * spacing

            # 라벨
            label_surf = font.render(label, True, Colors.UI_TEXT_DIM)
            surface.blit(label_surf, (x, by))

            # 바 배경
            bx = x + 48
            pygame.draw.rect(surface, (30, 30, 40), (bx, by + 1, bar_w, bar_h), border_radius=3)

            # 바 값
            ratio = max(0, min(1, value / max_val))
            fill_w = int(bar_w * ratio)
            if fill_w > 0:
                draw_gradient_rect(surface, (bx, by + 1, fill_w, bar_h),
                                  color, dark_color, vertical=True, radius=3)

            # 수치 표시
            val_text = font.render(f"{int(value)}", True, Colors.UI_TEXT)
            surface.blit(val_text, (bx + bar_w + 4, by))

    def _draw_time_info(self, surface, time_system, current_day, total_days, raid_time_left=None):
        """시간 정보 및 레이드 타이머 (우측 상단)"""
        font_big = FontManager.get(18)
        font_small = FontManager.get(13)

        # 배경 패널
        panel_w, panel_h = 165, 55
        px = self.sw - panel_w - 15
        py = 15
        draw_rounded_rect(surface, (15, 15, 25, 180), (px, py, panel_w, panel_h), radius=8)

        if raid_time_left is not None:
            minutes = int(raid_time_left) // 60
            seconds = int(raid_time_left) % 60
            time_left_str = f"남은 시간 {minutes:02d}:{seconds:02d}"
            color = (220, 50, 50) if raid_time_left < 60 else Colors.UI_ACCENT_WARM
            timer_text = font_big.render(time_left_str, True, color)
            surface.blit(timer_text, (px + 10, py + 6))
        else:
            day_text = font_big.render(f"{t('day')} {current_day}/{total_days}", True, Colors.UI_ACCENT)
            surface.blit(day_text, (px + 10, py + 5))

        # 시간
        period_key = f"period_{time_system.period_name}"
        time_text = font_small.render(f"{time_system.time_string}  {t(period_key)}", True, Colors.UI_TEXT)
        surface.blit(time_text, (px + 10, py + 32))

    def _draw_extraction_hud(self, surface, extract_target, extract_timer):
        """탈출 카운트다운 타이머 HUD 표시 (화면 중앙 상단)"""
        if not extract_target or extract_timer <= 0:
            return
            
        font = FontManager.get(16)
        
        # 남은 탈출 시간 계산
        remaining = max(0.0, 7.0 - extract_timer)
        text_str = f"구역 이탈 중... {remaining:.1f}초"
        text_surf = font.render(text_str, True, (100, 255, 150))
        
        tw = text_surf.get_width()
        y = self.sh // 3 - 30
        
        # 배경 패널
        panel_w = max(240, tw + 40)
        panel_h = 50
        px = (self.sw - panel_w) // 2
        py = y - 10
        
        draw_rounded_rect(surface, (15, 25, 20, 220), (px, py, panel_w, panel_h), radius=8)
        pygame.draw.rect(surface, (100, 255, 150), (px, py, panel_w, panel_h), 1, border_radius=8)
        
        surface.blit(text_surf, ((self.sw - tw) // 2, y))
        
        # 진행바 그리기
        bar_w = panel_w - 40
        bar_h = 6
        bx = px + 20
        by = py + panel_h - 14
        
        pygame.draw.rect(surface, (30, 30, 40), (bx, by, bar_w, bar_h), border_radius=3)
        ratio = min(1.0, extract_timer / 7.0)
        if ratio > 0:
            pygame.draw.rect(surface, (50, 220, 100), (bx, by, int(bar_w * ratio), bar_h), border_radius=3)

    def _draw_weather_info(self, surface, weather_system):
        """날씨 (우측 상단 아래)"""
        font = FontManager.get(13)
        px = self.sw - 175
        py = 80

        weather_key = f"weather_{weather_system.current_weather}"
        weather_text = font.render(t("weather_label", t(weather_key)), True, Colors.UI_TEXT_DIM)
        surface.blit(weather_text, (px + 10, py))

    def _update_minimap_cache(self, player, world):
        """미니맵 캐시 서피스 갱신"""
        self.minimap_surface.fill((10, 12, 18, 250))  # 기본 안개색 (투명도 조절)

        if player and world:
            grid_size = 4
            px, py = int(player.x), int(player.y)
            start_wx = px - 15
            start_wy = py - 15

            for r in range(30):
                wy = start_wy + r
                cy = wy // 16
                ly = wy % 16
                for c in range(30):
                    wx = start_wx + c
                    cx = wx // 16
                    lx = wx % 16

                    # 탐색된 타일만 지형을 그림
                    if (wx, wy) in player.explored_tiles:
                        chunk_key = (cx, cy)
                        tile_type = None
                        if world and hasattr(world, 'chunks') and chunk_key in world.chunks:
                            tile_type = world.chunks[chunk_key].get_tile(lx, ly)

                        # 지형 타입별 색상 결정
                        color = (35, 75, 40)  # 디폴트 풀밭
                        if tile_type:
                            from world import TileType
                            if tile_type == TileType.ROAD:
                                color = (70, 70, 75)
                            elif tile_type == TileType.CONCRETE:
                                color = (130, 130, 135)
                            elif tile_type == TileType.WATER:
                                color = (40, 90, 170)
                            elif tile_type == TileType.SAND:
                                color = (200, 180, 130)
                            elif tile_type == TileType.DIRT:
                                color = (120, 95, 65)
                            elif tile_type in (TileType.FLOOR_WOOD, TileType.FLOOR_TILE):
                                color = (160, 110, 80)
                        else:
                            # 로드되지 않은 탐색 타일은 바이옴 추정
                            biome = world.get_biome(wx, wy)
                            if biome == "도시":
                                color = (100, 100, 105)
                            elif biome == "공장단지":
                                color = (75, 75, 80)
                            elif biome == "호수":
                                color = (35, 75, 140)
                            elif biome == "황무지":
                                color = (130, 115, 85)

                        pygame.draw.rect(self.minimap_surface, color, (c * grid_size, r * grid_size, grid_size, grid_size))

    def _draw_minimap(self, surface, player, world=None, dt=0.0):
        """미니맵 (우측 하단) - 캐싱 버전"""
        size = 120
        mx = self.sw - size - 15
        my = self.sh - size - 15

        if player and world:
            self.minimap_timer += dt
            p_tile = (int(player.x), int(player.y))
            if self.minimap_timer >= 1.0 or self.last_player_tile_pos != p_tile:
                self._update_minimap_cache(player, world)
                self.minimap_timer = 0.0
                self.last_player_tile_pos = p_tile

        # 렌더용 임시 복사본 생성하여 마커/오버레이 그리기 (기존 캐시 유지)
        render_surf = self.minimap_surface.copy()

        # 테두리 및 마스크 오버레이
        pygame.draw.rect(render_surf, Colors.UI_BORDER, (0, 0, size, size), 1, border_radius=6)

        # 플레이어 위치 (중앙)
        center = size // 2
        pygame.draw.circle(render_surf, (80, 200, 255), (center, center), 3)
        pygame.draw.circle(render_surf, (80, 200, 255), (center, center), 5, 1)

        # 좌표 표시
        font = FontManager.get(9)
        px_val, py_val = (int(player.x), int(player.y)) if player else (0, 0)
        coord = font.render(f"({px_val}, {py_val})", True, Colors.WHITE)
        # 텍스트 가독성을 위해 작은 검은색 배경 패널
        coord_bg = pygame.Surface((coord.get_width() + 6, coord.get_height() + 2), pygame.SRCALPHA)
        coord_bg.fill((10, 12, 18, 180))
        render_surf.blit(coord_bg, (4 - 3, size - 14 - 1))
        render_surf.blit(coord, (4, size - 14))

        surface.blit(render_surf, (mx, my))

    def _draw_notifications(self, surface):
        """알림 메시지 (화면 상단 중앙)"""
        font = FontManager.get(14)
        y = 60

        for msg, timer, _ in self.notification_queue[:5]:
            alpha = max(0, min(255, int(timer * 255)))
            if alpha <= 0:
                continue
            # 알림 메시지 자체도 t()를 거쳐서 출력(단, dynamic format인 경우 msg 그대로 출력)
            translated_msg = t(msg)
            text_surf = font.render(translated_msg, True, Colors.UI_TEXT)
            text_w = text_surf.get_width()
            x = (self.sw - text_w) // 2

            bg_alpha = max(0, min(180, alpha))
            bg = pygame.Surface((text_w + 20, 28), pygame.SRCALPHA)
            pygame.draw.rect(bg, (20, 22, 30, bg_alpha), (0, 0, text_w + 20, 28), border_radius=6)
            surface.blit(bg, (x - 10, y - 4))
            text_surf.set_alpha(alpha)
            surface.blit(text_surf, (x, y))
            y += 32

    def _draw_equipped_weapon(self, surface, player):
        """장착 무기 (좌측 하단)"""
        wx, wy = 15, self.sh - 60
        draw_rounded_rect(surface, (15, 15, 25, 180), (wx, wy, 50, 50), radius=6)

        weapon = player.equipped.get("weapon")
        if weapon:
            icon = ItemIconRenderer.get_icon(weapon)
            surface.blit(icon, (wx + 9, wy + 9))
        else:
            font = FontManager.get(10)
            text = font.render(t("fist"), True, Colors.UI_TEXT_DIM)
            surface.blit(text, (wx + 12, wy + 18))

    def _draw_quick_info(self, surface, player):
        """빠른 정보 (좌측 하단)"""
        font = FontManager.get(11)
        x, y = 75, self.sh - 55

        # 방어도
        def_text = font.render(t("defense_label", player.shelter_defense), True, Colors.UI_TEXT_DIM)
        surface.blit(def_text, (x, y))

        # 킬 수
        kill_text = font.render(t("kills_label", player.killed_zombies), True, Colors.UI_TEXT_DIM)
        surface.blit(kill_text, (x, y + 16))

        # 조작 안내
        hint = font.render(t("hud_controls_hint"), True, (100, 105, 120))
        surface.blit(hint, (x, y + 32))

    def _draw_crouch_indicator(self, surface, player):
        """은신 상태 표시 (하단 중앙)"""
        if not player.is_crouching:
            return
        font = FontManager.get(14)
        text = font.render(t("stealth_mode"), True, (100, 200, 255))
        tw = text.get_width()
        x = (self.sw - tw) // 2
        y = self.sh - 45
        bg = pygame.Surface((tw + 20, 28), pygame.SRCALPHA)
        pygame.draw.rect(bg, (20, 40, 60, 180), (0, 0, tw + 20, 28), border_radius=6)
        surface.blit(bg, (x - 10, y - 4))
        surface.blit(text, (x, y))


class EventLogUI:
    """이벤트 로그 표시"""

    def __init__(self, screen_w, screen_h):
        self.sw = screen_w
        self.sh = screen_h

    def draw(self, surface, event_log):
        if not event_log:
            return

        font = FontManager.get(12)
        y = self.sh // 2 - len(event_log) * 18

        for msg, timer in event_log:
            alpha = max(0, min(255, int(timer * 80)))
            if alpha <= 0:
                continue
            text_surf = font.render(t(msg), True, Colors.UI_TEXT)
            text_surf.set_alpha(alpha)

            bg_alpha = max(0, min(140, alpha))
            bg = pygame.Surface((text_surf.get_width() + 16, 20), pygame.SRCALPHA)
            bg.fill((10, 12, 20, bg_alpha))
            surface.blit(bg, (8, y - 2))
            surface.blit(text_surf, (16, y))
            y += 20
