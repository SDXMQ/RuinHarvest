import pygame
from settings import Colors, TILE_SIZE
from .fonts import FontManager
from utils import ease_out_cubic
from renderer import draw_rounded_rect
from i18n import t

class RadioScannerUI:
    def __init__(self, screen_w, screen_h):
        self.sw = screen_w
        self.sh = screen_h
        self.visible = False
        self.animation_progress = 0
        
        # 병원을 제외한 특수건물 및 탈출구
        self.targets = [
            {"id": "police", "name": "경찰서"},
            {"id": "military", "name": "군사기지"},
            {"id": "radio_tower", "name": "통신탑"},
            {"id": "escape", "name": "탈출구"}
        ]
        self.selected_idx = 0
        self.hover_idx = -1

    def open(self):
        self.visible = True
        self.animation_progress = 0
        self.selected_idx = 0

    def close(self):
        self.visible = False

    def update(self, dt):
        if self.visible and self.animation_progress < 1:
            self.animation_progress = min(1, self.animation_progress + dt * 6)

    def handle_event(self, event, player):
        if not self.visible:
            return None

        panel_w = 300
        panel_h = 240
        px = (self.sw - panel_w) // 2
        py = (self.sh - panel_h) // 2
        
        if event.type == pygame.MOUSEMOTION:
            mx, my = event.pos
            self.hover_idx = -1
            for i, target in enumerate(self.targets):
                rect = pygame.Rect(px + 20, py + 60 + i * 40, panel_w - 40, 32)
                if rect.collidepoint(mx, my):
                    self.hover_idx = i
                    break

        elif event.type == pygame.MOUSEBUTTONDOWN:
            if event.button == 1:
                if self.hover_idx != -1:
                    self.selected_idx = self.hover_idx
                    # 선택 완료 시
                    target_id = self.targets[self.selected_idx]["id"]
                    player.radio_scan_timer = 5.0
                    player.radio_scan_target = target_id
                    self.close()
                    return ("radio_scan_start", target_id)
                else:
                    mx, my = event.pos
                    if not (px <= mx <= px + panel_w and py <= my <= py + panel_h):
                        self.close()

        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                self.close()
            elif event.key == pygame.K_UP:
                self.selected_idx = (self.selected_idx - 1) % len(self.targets)
            elif event.key == pygame.K_DOWN:
                self.selected_idx = (self.selected_idx + 1) % len(self.targets)
            elif event.key == pygame.K_RETURN:
                target_id = self.targets[self.selected_idx]["id"]
                player.radio_scan_timer = 5.0
                player.radio_scan_target = target_id
                self.close()
                return ("radio_scan_start", target_id)

        return None

    def draw(self, surface):
        if not self.visible:
            return

        t_val = ease_out_cubic(self.animation_progress)
        
        overlay = pygame.Surface((self.sw, self.sh), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, int(150 * t_val)))
        surface.blit(overlay, (0, 0))

        panel_w = 300
        panel_h = 240
        px = (self.sw - panel_w) // 2
        py = int((self.sh - panel_h) // 2 + (1 - t_val) * 20)

        # 패널 배경
        draw_rounded_rect(surface, Colors.UI_BG, (px, py, panel_w, panel_h), radius=12)
        draw_rounded_rect(surface, Colors.UI_BORDER, (px, py, panel_w, panel_h), radius=12)

        font_title = FontManager.get(16)
        font_item = FontManager.get(14)
        
        # 타이틀
        title_surf = font_title.render("통신할 건물을 선택하세요", True, Colors.UI_ACCENT)
        surface.blit(title_surf, (px + (panel_w - title_surf.get_width()) // 2, py + 20))

        # 리스트
        for i, target in enumerate(self.targets):
            rect = pygame.Rect(px + 20, py + 60 + i * 40, panel_w - 40, 32)
            
            is_hover = (i == self.hover_idx)
            is_selected = (i == self.selected_idx)
            
            if is_selected:
                draw_rounded_rect(surface, (Colors.UI_ACCENT[0], Colors.UI_ACCENT[1], Colors.UI_ACCENT[2], 100), rect, radius=6)
                pygame.draw.rect(surface, Colors.UI_ACCENT, rect, 1, border_radius=6)
            elif is_hover:
                draw_rounded_rect(surface, (Colors.UI_PANEL[0], Colors.UI_PANEL[1], Colors.UI_PANEL[2], 150), rect, radius=6)
            
            color = Colors.UI_TEXT if (is_selected or is_hover) else Colors.UI_TEXT_DIM
            name_surf = font_item.render(target["name"], True, color)
            surface.blit(name_surf, (rect.x + 15, rect.y + 6))
