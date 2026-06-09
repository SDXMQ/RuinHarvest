import pygame
import math
from settings import Colors
from renderer import draw_rounded_rect
from .fonts import FontManager
from i18n import t


class SaveSlotsUI:
    """세이브 파일 선택/관리 화면"""

    SLOTS_PER_PAGE = 4
    MAX_PAGES = 2

    def __init__(self, screen_w, screen_h):
        self.sw = screen_w
        self.sh = screen_h
        self.saves = []
        self.page = 0
        self.hover_index = -1
        self.hover_button = ""  # "delete", "rename", "prev", "next", "back", "slot"

        # 이름 편집 상태
        self.editing_index = -1
        self.edit_text = ""

        # 삭제 확인 다이얼로그
        self.confirm_delete_index = -1

    def refresh(self, saves):
        """세이브 파일 목록 갱신"""
        self.saves = saves
        self.hover_index = -1
        self.hover_button = ""
        self.editing_index = -1
        self.confirm_delete_index = -1

    def _get_layout(self):
        """레이아웃 계산"""
        panel_w = 520
        panel_h = 460
        px = (self.sw - panel_w) // 2
        py = (self.sh - panel_h) // 2
        return panel_w, panel_h, px, py

    def _slot_rect(self, i, px, py):
        """i번째 슬롯의 사각형"""
        card_w = 460
        card_h = 82
        card_x = px + 30
        card_y = py + 60 + i * (card_h + 12)
        return card_x, card_y, card_w, card_h

    def _page_saves(self):
        """현재 페이지의 세이브 리스트"""
        start = self.page * self.SLOTS_PER_PAGE
        end = start + self.SLOTS_PER_PAGE
        return self.saves[start:end]

    def _total_pages(self):
        return max(1, self.MAX_PAGES)

    def handle_event(self, event):
        panel_w, panel_h, px, py = self._get_layout()

        # 삭제 확인 다이얼로그가 열려있으면 그것만 처리
        if self.confirm_delete_index >= 0:
            return self._handle_confirm_dialog(event, px, py, panel_w, panel_h)

        # 이름 편집 중 키 입력
        if self.editing_index >= 0:
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_RETURN:
                    result = ("rename", self.editing_index + self.page * self.SLOTS_PER_PAGE, self.edit_text)
                    self.editing_index = -1
                    return result
                elif event.key == pygame.K_ESCAPE:
                    self.editing_index = -1
                    return None
                elif event.key == pygame.K_BACKSPACE:
                    self.edit_text = self.edit_text[:-1]
                elif event.unicode and len(self.edit_text) < 20:
                    self.edit_text += event.unicode
                return None

        if event.type == pygame.MOUSEMOTION:
            mx, my = event.pos
            self.hover_index = -1
            self.hover_button = ""

            # 뒤로 버튼
            if px + 10 <= mx <= px + 80 and py + 10 <= my <= py + 35:
                self.hover_button = "back"
                return None

            # 페이지 버튼
            nav_y = py + panel_h - 40
            if px + panel_w // 2 - 80 <= mx <= px + panel_w // 2 - 50 and nav_y <= my <= nav_y + 25:
                self.hover_button = "prev"
            elif px + panel_w // 2 + 50 <= mx <= px + panel_w // 2 + 80 and nav_y <= my <= nav_y + 25:
                self.hover_button = "next"

            # 슬롯
            page_saves = self._page_saves()
            for i in range(self.SLOTS_PER_PAGE):
                cx, cy, cw, ch = self._slot_rect(i, px, py)
                if cx <= mx <= cx + cw and cy <= my <= cy + ch:
                    self.hover_index = i
                    # 삭제/이름변경 버튼 영역 체크
                    if i < len(page_saves):
                        btn_y = cy + 6
                        if cx + cw - 45 <= mx <= cx + cw - 10 and btn_y <= my <= btn_y + 20:
                            self.hover_button = "delete"
                        elif cx + cw - 85 <= mx <= cx + cw - 50 and btn_y <= my <= btn_y + 20:
                            self.hover_button = "rename"
                        else:
                            self.hover_button = "slot"
                    break

        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            mx, my = event.pos

            # 뒤로 버튼
            if px + 10 <= mx <= px + 80 and py + 10 <= my <= py + 35:
                return "back"

            # 페이지 버튼
            nav_y = py + panel_h - 40
            if px + panel_w // 2 - 80 <= mx <= px + panel_w // 2 - 50 and nav_y <= my <= nav_y + 25:
                if self.page > 0:
                    self.page -= 1
                    self.editing_index = -1
                return None
            elif px + panel_w // 2 + 50 <= mx <= px + panel_w // 2 + 80 and nav_y <= my <= nav_y + 25:
                if self.page < self._total_pages() - 1:
                    self.page += 1
                    self.editing_index = -1
                return None

            # 슬롯 클릭
            page_saves = self._page_saves()
            for i in range(self.SLOTS_PER_PAGE):
                cx, cy, cw, ch = self._slot_rect(i, px, py)
                if cx <= mx <= cx + cw and cy <= my <= cy + ch:
                    if i < len(page_saves):
                        btn_y = cy + 6
                        # 삭제 버튼
                        if cx + cw - 45 <= mx <= cx + cw - 10 and btn_y <= my <= btn_y + 20:
                            self.confirm_delete_index = i + self.page * self.SLOTS_PER_PAGE
                            return None
                        # 이름변경 버튼
                        elif cx + cw - 85 <= mx <= cx + cw - 50 and btn_y <= my <= btn_y + 20:
                            self.editing_index = i
                            self.edit_text = page_saves[i]["world_name"]
                            return None
                        else:
                            # 슬롯 로드
                            abs_index = i + self.page * self.SLOTS_PER_PAGE
                            return ("load", abs_index)
                    break

        if event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
            return "back"

        return None

    def _handle_confirm_dialog(self, event, px, py, panel_w, panel_h):
        """삭제 확인 다이얼로그 이벤트"""
        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            mx, my = event.pos
            dlg_w, dlg_h = 280, 120
            dx = (self.sw - dlg_w) // 2
            dy = (self.sh - dlg_h) // 2
            btn_w = 80

            # 예 버튼
            if dx + dlg_w // 2 - btn_w - 10 <= mx <= dx + dlg_w // 2 - 10 and dy + 75 <= my <= dy + 105:
                idx = self.confirm_delete_index
                self.confirm_delete_index = -1
                return ("delete", idx)
            # 아니오 버튼
            elif dx + dlg_w // 2 + 10 <= mx <= dx + dlg_w // 2 + btn_w + 10 and dy + 75 <= my <= dy + 105:
                self.confirm_delete_index = -1
                return None

        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                self.confirm_delete_index = -1
            elif event.key == pygame.K_RETURN:
                idx = self.confirm_delete_index
                self.confirm_delete_index = -1
                return ("delete", idx)
        return None

    def draw(self, surface):
        surface.fill(Colors.MENU_BG)

        # 배경 그라데이션
        for y in range(self.sh):
            t_val = y / self.sh
            pygame.draw.line(surface, (30 + int(10 * t_val), 15, 20 + int(15 * t_val)), (0, y), (self.sw, y))

        panel_w, panel_h, px, py = self._get_layout()

        # 패널 배경
        draw_rounded_rect(surface, (20, 22, 35, 240), (px, py, panel_w, panel_h), radius=12)
        pygame.draw.rect(surface, Colors.UI_BORDER, (px, py, panel_w, panel_h), 1, border_radius=12)

        font_title = FontManager.get(22)
        font = FontManager.get(13)
        font_small = FontManager.get(11)
        font_btn = FontManager.get(10)

        # 타이틀
        title = font_title.render(t("save_slots_title"), True, Colors.UI_ACCENT)
        surface.blit(title, (px + (panel_w - title.get_width()) // 2, py + 14))

        # 뒤로 버튼
        back_color = Colors.UI_ACCENT if self.hover_button == "back" else Colors.UI_TEXT_DIM
        back_surf = font_small.render(t("back"), True, back_color)
        surface.blit(back_surf, (px + 15, py + 15))

        # 슬롯 그리기
        page_saves = self._page_saves()

        for i in range(self.SLOTS_PER_PAGE):
            cx, cy, cw, ch = self._slot_rect(i, px, py)
            is_hover = (self.hover_index == i)

            if i < len(page_saves):
                save = page_saves[i]
                self._draw_save_card(surface, save, cx, cy, cw, ch, i, is_hover,
                                     font, font_small, font_btn)
            else:
                self._draw_empty_slot(surface, cx, cy, cw, ch, font, is_hover)

        # 페이지 네비게이션
        nav_y = py + panel_h - 40
        nav_font = FontManager.get(14)

        # 이전 페이지
        prev_color = Colors.UI_ACCENT if self.hover_button == "prev" and self.page > 0 else (
            Colors.UI_TEXT_DIM if self.page > 0 else (40, 42, 55))
        prev_surf = nav_font.render("◀", True, prev_color)
        surface.blit(prev_surf, (px + panel_w // 2 - 70, nav_y))

        # 페이지 표시
        page_text = font.render(t("save_slot_page", self.page + 1, self._total_pages()), True, Colors.UI_TEXT)
        surface.blit(page_text, (px + panel_w // 2 - page_text.get_width() // 2, nav_y + 2))

        # 다음 페이지
        next_color = Colors.UI_ACCENT if self.hover_button == "next" and self.page < self._total_pages() - 1 else (
            Colors.UI_TEXT_DIM if self.page < self._total_pages() - 1 else (40, 42, 55))
        next_surf = nav_font.render("▶", True, next_color)
        surface.blit(next_surf, (px + panel_w // 2 + 60, nav_y))

        # 삭제 확인 다이얼로그
        if self.confirm_delete_index >= 0:
            self._draw_confirm_dialog(surface)

    def _draw_save_card(self, surface, save, cx, cy, cw, ch, local_index, is_hover,
                        font, font_small, font_btn):
        """세이브 슬롯 카드"""
        # 배경
        if is_hover and self.hover_button == "slot":
            bg_color = (Colors.UI_ACCENT[0], Colors.UI_ACCENT[1], Colors.UI_ACCENT[2], 30)
            border_color = Colors.UI_ACCENT
        else:
            bg_color = (30, 33, 48, 200)
            border_color = Colors.UI_BORDER

        draw_rounded_rect(surface, bg_color, (cx, cy, cw, ch), radius=8)
        pygame.draw.rect(surface, border_color, (cx, cy, cw, ch), 1, border_radius=8)

        # 세이브 이름 (또는 편집 중)
        if self.editing_index == local_index:
            # 편집 모드 - 입력 박스
            pygame.draw.rect(surface, Colors.UI_ACCENT, (cx + 12, cy + 8, 250, 22), 1, border_radius=4)
            name_surf = font.render(self.edit_text + "│", True, Colors.UI_ACCENT)
            surface.blit(name_surf, (cx + 16, cy + 11))
        else:
            name_surf = font.render(save["world_name"], True, Colors.UI_TEXT)
            surface.blit(name_surf, (cx + 14, cy + 10))

        # 난이도 태그
        diff_text = save.get("difficulty", "")
        if diff_text:
            diff_surf = font_btn.render(diff_text, True, Colors.UI_TEXT_DIM)
            surface.blit(diff_surf, (cx + 14 + name_surf.get_width() + 10, cy + 13))

        # 일차 + 자금
        day_text = t("save_slot_day", save.get("day", 0))
        funds_text = t("save_slot_funds", save.get("funds", 0))
        info_line = f"{day_text}  |  {funds_text}"
        info_surf = font.render(info_line, True, Colors.UI_TEXT_DIM)
        surface.blit(info_surf, (cx + 14, cy + 34))

        # 생성일자 / 최근 플레이
        created = save.get("created_at", "")
        last_played = save.get("save_time", "")
        # 날짜만 추출 (시간 제외)
        created_short = created[:10] if len(created) >= 10 else created
        last_short = last_played[:16] if len(last_played) >= 16 else last_played

        date_parts = []
        if created_short:
            date_parts.append(t("save_slot_created", created_short))
        if last_short:
            date_parts.append(t("save_slot_last_played", last_short))
        date_line = "  |  ".join(date_parts)
        date_surf = font_btn.render(date_line, True, (70, 75, 90))
        surface.blit(date_surf, (cx + 14, cy + 54))

        # 플레이타임
        pt = save.get("playtime", 0)
        hours = int(pt) // 3600
        minutes = (int(pt) % 3600) // 60
        pt_text = f"{hours}h {minutes}m"
        pt_surf = font_btn.render(pt_text, True, (70, 75, 90))
        surface.blit(pt_surf, (cx + 14, cy + 68))

        # 삭제/이름변경 버튼 (호버 시에만 표시)
        if is_hover:
            btn_y = cy + 6

            # 이름변경 버튼 (Edit)
            rename_x = cx + cw - 85
            rename_rect = (rename_x, btn_y, 35, 20)
            rename_bg = (50, 55, 75) if self.hover_button == "rename" else (30, 33, 48)
            rename_border = Colors.UI_ACCENT if self.hover_button == "rename" else Colors.UI_BORDER
            pygame.draw.rect(surface, rename_bg, rename_rect, border_radius=4)
            pygame.draw.rect(surface, rename_border, rename_rect, 1, border_radius=4)

            rename_surf = font_btn.render("Edit", True, Colors.UI_ACCENT if self.hover_button == "rename" else Colors.UI_TEXT_DIM)
            surface.blit(rename_surf, (rename_x + (35 - rename_surf.get_width()) // 2, btn_y + (20 - rename_surf.get_height()) // 2))

            # 삭제 버튼 (Del)
            delete_x = cx + cw - 45
            delete_rect = (delete_x, btn_y, 35, 20)
            delete_bg = (80, 30, 40) if self.hover_button == "delete" else (30, 33, 48)
            delete_border = Colors.UI_DANGER if self.hover_button == "delete" else Colors.UI_BORDER
            pygame.draw.rect(surface, delete_bg, delete_rect, border_radius=4)
            pygame.draw.rect(surface, delete_border, delete_rect, 1, border_radius=4)

            delete_surf = font_btn.render("Del", True, Colors.UI_DANGER if self.hover_button == "delete" else Colors.UI_TEXT_DIM)
            surface.blit(delete_surf, (delete_x + (35 - delete_surf.get_width()) // 2, btn_y + (20 - delete_surf.get_height()) // 2))

    def _draw_empty_slot(self, surface, cx, cy, cw, ch, font, is_hover):
        """빈 슬롯 표시"""
        draw_rounded_rect(surface, (25, 27, 38, 120), (cx, cy, cw, ch), radius=8)
        pygame.draw.rect(surface, (40, 42, 55), (cx, cy, cw, ch), 1, border_radius=8)

        empty_surf = font.render(t("save_slot_empty"), True, (50, 55, 65))
        surface.blit(empty_surf, (cx + cw // 2 - empty_surf.get_width() // 2,
                                  cy + ch // 2 - empty_surf.get_height() // 2))

    def _draw_confirm_dialog(self, surface):
        """삭제 확인 다이얼로그"""
        # 어두운 오버레이
        overlay = pygame.Surface((self.sw, self.sh), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 160))
        surface.blit(overlay, (0, 0))

        dlg_w, dlg_h = 280, 120
        dx = (self.sw - dlg_w) // 2
        dy = (self.sh - dlg_h) // 2

        draw_rounded_rect(surface, (25, 28, 42, 250), (dx, dy, dlg_w, dlg_h), radius=10)
        pygame.draw.rect(surface, Colors.UI_DANGER, (dx, dy, dlg_w, dlg_h), 2, border_radius=10)

        font = FontManager.get(14)
        font_btn = FontManager.get(12)

        # 메시지
        msg = font.render(t("save_slot_delete_confirm"), True, Colors.UI_TEXT)
        surface.blit(msg, (dx + (dlg_w - msg.get_width()) // 2, dy + 25))

        # 삭제 대상 이름
        if 0 <= self.confirm_delete_index < len(self.saves):
            name = self.saves[self.confirm_delete_index]["world_name"]
            name_surf = FontManager.get(11).render(f'"{name}"', True, Colors.UI_TEXT_DIM)
            surface.blit(name_surf, (dx + (dlg_w - name_surf.get_width()) // 2, dy + 48))

        btn_w = 80
        btn_h = 30

        # 예 버튼
        yes_x = dx + dlg_w // 2 - btn_w - 10
        yes_y = dy + 75
        draw_rounded_rect(surface, Colors.UI_DANGER + (40,), (yes_x, yes_y, btn_w, btn_h), radius=6)
        pygame.draw.rect(surface, Colors.UI_DANGER, (yes_x, yes_y, btn_w, btn_h), 1, border_radius=6)
        yes_surf = font_btn.render(t("save_slot_yes"), True, Colors.UI_DANGER)
        surface.blit(yes_surf, (yes_x + (btn_w - yes_surf.get_width()) // 2,
                                yes_y + (btn_h - yes_surf.get_height()) // 2))

        # 아니오 버튼
        no_x = dx + dlg_w // 2 + 10
        no_y = dy + 75
        draw_rounded_rect(surface, (40, 42, 55, 200), (no_x, no_y, btn_w, btn_h), radius=6)
        pygame.draw.rect(surface, Colors.UI_BORDER, (no_x, no_y, btn_w, btn_h), 1, border_radius=6)
        no_surf = font_btn.render(t("save_slot_no"), True, Colors.UI_TEXT)
        surface.blit(no_surf, (no_x + (btn_w - no_surf.get_width()) // 2,
                               no_y + (btn_h - no_surf.get_height()) // 2))
