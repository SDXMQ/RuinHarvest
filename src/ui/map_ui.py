"""
map_ui.py - M키를 눌렀을 때 나타나는 2D 전체 지도 및 전장의 안개 오버레이 UI
"""
import pygame
import math
from settings import Colors, TILE_SIZE
from ui.fonts import FontManager
from world import TileType
from i18n import t

class MapUI:
    """전체화면 탐색 지도 UI"""

    def __init__(self, screen_w, screen_h):
        self.sw = screen_w
        self.sh = screen_h
        self.grid_tile_size = 8  # 지도 상의 1타일 크기 (픽셀 단위)
        self.pulse_timer = 0.0

    def resize(self, w, h):
        self.sw = w
        self.sh = h

    def draw(self, surface, player, world):
        if not player or not world:
            return

        # 펄스 애니메이션 갱신 (플레이어 표시기 깜빡임용)
        self.pulse_timer += 0.05
        pulse = 120 + int(80 * math.sin(self.pulse_timer))

        # 1. 반투명 뒷배경 오버레이 (블랙 글라스모피즘 느낌)
        overlay = pygame.Surface((self.sw, self.sh), pygame.SRCALPHA)
        overlay.fill((10, 12, 18, 220))
        surface.blit(overlay, (0, 0))

        # 2. 지도 영역 레이아웃 계산
        # 화면 중앙 부근에 맵 프레임 배치
        map_w = min(self.sw - 80, 800)
        map_h = min(self.sh - 120, 600)
        map_x = (self.sw - map_w) // 2
        map_y = (self.sh - map_h) // 2 + 20

        # 지도 상자 테두리 그리기
        pygame.draw.rect(surface, Colors.UI_BORDER, (map_x - 2, map_y - 2, map_w + 4, map_h + 4), 2, border_radius=8)
        pygame.draw.rect(surface, (15, 18, 25), (map_x, map_y, map_w, map_h), border_radius=8)

        # 맵 상의 1타일 크기 결정 (지도 영역에 딱 맞게 스케일링)
        # 플레이어 기준 좌우/상하로 얼마나 보여줄지 설정
        # 80x60 타일 영역을 보여주도록 설정
        view_cols = map_w // self.grid_tile_size
        view_rows = map_h // self.grid_tile_size

        px, py = int(player.x), int(player.y)
        
        # 보여지는 맵의 좌상단 월드 타일 좌표
        start_wx = px - view_cols // 2
        start_wy = py - view_rows // 2

        # 3. 타일 및 전장의 안개 렌더링
        # 최적화: 청크 조회를 빠르게 하기 위해 이미 메모리에 올려진 청크만 체크
        for r in range(view_rows):
            wy = start_wy + r
            cy = wy // 16  # CHUNK_SIZE = 16
            ly = wy % 16
            
            for c in range(view_cols):
                wx = start_wx + c
                cx = wx // 16
                lx = wx % 16

                tx = map_x + c * self.grid_tile_size
                ty = map_y + r * self.grid_tile_size

                # 탐색 완료한 타일인지 검사
                if (wx, wy) in player.explored_tiles:
                    # 해당 청크가 로드되어 있는지 안전하게 검증하여 가져옴
                    chunk_key = (cx, cy)
                    tile_type = None
                    if chunk_key in world.chunks:
                        tile_type = world.chunks[chunk_key].get_tile(lx, ly)
                    
                    if tile_type:
                        # 타일 종류별 지도 색상 맵핑
                        color = Colors.GRASS_1
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
                        
                        pygame.draw.rect(surface, color, (tx, ty, self.grid_tile_size, self.grid_tile_size))
                    else:
                        # 청크가 로드되어 있지 않지만 탐색은 된 경우, 바이옴 예측 색상 칠함
                        biome_name = world.get_biome(wx, wy)
                        color = (55, 100, 50)  # 산림 디폴트
                        if biome_name == "도시":
                            color = (110, 110, 115)
                        elif biome_name == "공장단지":
                            color = (80, 80, 85)
                        elif biome_name == "군사기지":
                            color = (120, 100, 80)
                        elif biome_name == "호수":
                            color = (35, 75, 140)
                        elif biome_name == "황무지":
                            color = (140, 120, 90)
                        elif biome_name == "밀밭":
                            color = (170, 140, 70)
                        
                        pygame.draw.rect(surface, color, (tx, ty, self.grid_tile_size, self.grid_tile_size))
                else:
                    # 탐색하지 않은 곳은 전장의 안개 (검은색)
                    pygame.draw.rect(surface, (5, 5, 8), (tx, ty, self.grid_tile_size, self.grid_tile_size))

        # 4. 발견된 건물 외곽선 렌더링
        # 플레이어 주변 청크의 건물 목록
        for cx, cy in list(world.chunks.keys()):
            chunk = world.chunks[(cx, cy)]
            for b in chunk.buildings:
                # 건물의 네 귀퉁이 월드 좌표
                bx1, by1 = b.x, b.y
                bx2, by2 = b.x + b.width, b.y + b.height

                # 지도 상의 픽셀 좌표로 변환
                cx1 = map_x + (bx1 - start_wx) * self.grid_tile_size
                cy1 = map_y + (by1 - start_wy) * self.grid_tile_size
                cw = b.width * self.grid_tile_size
                ch = b.height * self.grid_tile_size

                # 건물 영역 중 적어도 한 점이 탐색된 범위 안에 있으면 렌더링
                explored_any = False
                for ty_check in range(by1, by2):
                    for tx_check in range(bx1, bx2):
                        if (tx_check, ty_check) in player.explored_tiles:
                            explored_any = True
                            break
                    if explored_any:
                        break

                if explored_any:
                    # 건물 유형에 따른 색상
                    b_color = (180, 80, 60) if b.building_type == "hospital" else (140, 100, 70)
                    if b.building_type == "shelter":
                        b_color = Colors.UI_ACCENT_WARM
                    elif b.building_type == "military":
                        b_color = (80, 130, 80)
                    
                    pygame.draw.rect(surface, b_color, (cx1, cy1, cw, ch), 1)

        # 5. 탈출구 정보 표시
        for point in world.extraction_points:
            ex, ey = point["x"], point["y"]
            # 지도 화면 영역 안에 있는지 검사
            if start_wx <= ex < start_wx + view_cols and start_wy <= ey < start_wy + view_rows:
                # 탐색되지 않은 곳이어도 탈출구 위치 자체는 가이드로 제공 (또는 탐색된 곳만 보여줌)
                # 플레이어가 방향을 알 수 있게 탐색 여부와 상관없이 탈출구는 지도에 표시합니다.
                etx = map_x + (ex - start_wx) * self.grid_tile_size
                ety = map_y + (ey - start_wy) * self.grid_tile_size

                # 탈출구 마크 (초록색 삼각형 또는 원형)
                pygame.draw.circle(surface, (70, 220, 100), (etx + self.grid_tile_size//2, ety + self.grid_tile_size//2), 6)
                pygame.draw.circle(surface, Colors.WHITE, (etx + self.grid_tile_size//2, ety + self.grid_tile_size//2), 7, 1)
                
                # 탈출구 텍스트 라벨 (간략히)
                lbl_font = FontManager.get(9)
                lbl_surf = lbl_font.render(point["name"].split(": ")[-1], True, (150, 255, 170))
                surface.blit(lbl_surf, (etx + self.grid_tile_size + 4, ety - 4))

        # 6. 플레이어 현재 위치 표시 (지도 정중앙)
        ptx = map_x + (px - start_wx) * self.grid_tile_size
        pty = map_y + (py - start_wy) * self.grid_tile_size
        
        # 펄스 광원 효과
        pygame.draw.circle(surface, (80, 200, 255, pulse), (ptx + self.grid_tile_size//2, pty + self.grid_tile_size//2), 8)
        pygame.draw.circle(surface, (255, 255, 255), (ptx + self.grid_tile_size//2, pty + self.grid_tile_size//2), 3)

        # 7. 타이틀 및 안내 텍스트 표시
        title_font = FontManager.get(18)
        title_text = title_font.render("전술 지도 (TACTICAL MAP)", True, Colors.UI_ACCENT)
        surface.blit(title_text, (map_x, map_y - 35))

        hint_font = FontManager.get(11)
        hint_text = hint_font.render("M: 지도 닫기  |  밝은 구역: 탐색 완료  |  초록색 원: 탈출구", True, Colors.UI_TEXT_DIM)
        surface.blit(hint_text, (map_x + map_w - hint_text.get_width(), map_y - 28))
