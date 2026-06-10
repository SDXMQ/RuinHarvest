import pygame
import math
from settings import Colors, RESOLUTION_OPTIONS, DIFFICULTY_PRESETS, DEFAULT_WORLD_SETTINGS, GameSettings, TILE_SIZE
from renderer import draw_rounded_rect, draw_gradient_rect, draw_glow, ItemIconRenderer
from items import ITEM_DATABASE, ItemCategory
from crafting import CRAFTING_RECIPES, RECIPE_CATEGORIES
from utils import wrap_text, ease_out_cubic, lerp


class CachedFont:
    """pygame.font.Font 객체를 래핑하여 텍스트 렌더링 및 크기 연산 결과를 캐싱하는 클래스"""
    def __init__(self, font_obj):
        self.font = font_obj
        self._render_cache = {}
        self._size_cache = {}

    def render(self, text, antialias, color, background=None):
        # pygame.Color 객체는 해시 불가능하므로 튜플로 변환
        if isinstance(color, pygame.Color):
            color_key = (color.r, color.g, color.b, color.a)
        elif isinstance(color, (list, tuple)):
            color_key = tuple(color)
        else:
            color_key = color

        if background is not None:
            if isinstance(background, pygame.Color):
                bg_key = (background.r, background.g, background.b, background.a)
            elif isinstance(background, (list, tuple)):
                bg_key = tuple(background)
            else:
                bg_key = background
        else:
            bg_key = None

        key = (text, antialias, color_key, bg_key)
        if key not in self._render_cache:
            # 캐시 크기 관리 (메모리 누수 방지)
            if len(self._render_cache) > 1000:
                self._render_cache.clear()
            self._render_cache[key] = self.font.render(text, antialias, color, background)
        return self._render_cache[key]

    def size(self, text):
        if text not in self._size_cache:
            if len(self._size_cache) > 1000:
                self._size_cache.clear()
            self._size_cache[text] = self.font.size(text)
        return self._size_cache[text]

    def __getattr__(self, name):
        return getattr(self.font, name)


class FontManager:
    """폰트 관리"""
    _fonts = {}
    _initialized = False

    @classmethod
    def init(cls):
        if cls._initialized:
            return
        cls._initialized = True
        try:
            # 한국어 지원 폰트
            font_candidates = [
                "malgun gothic", "맑은 고딕", "gulim", "dotum",
                "NanumGothic", "arial", None
            ]
            cls._base_font = None
            for font_name in font_candidates:
                try:
                    test = pygame.font.SysFont(font_name, 16)
                    if test:
                        cls._base_font = font_name
                        break
                except Exception:
                    continue
        except Exception:
            cls._base_font = None

    @classmethod
    def get(cls, size):
        if not cls._initialized:
            cls.init()
        if size not in cls._fonts:
            try:
                raw_font = pygame.font.SysFont(cls._base_font, size)
            except Exception:
                raw_font = pygame.font.Font(None, size)
            cls._fonts[size] = CachedFont(raw_font)
        return cls._fonts[size]

