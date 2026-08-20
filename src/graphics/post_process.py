"""
post_process.py - ModernGL GLSL 셰이더 및 Pygame-ce 하이브리드 포스트 프로세싱 파이프라인
비네팅, 컬러 그레이딩, 블룸/글로우, 색수차, 필름 그레인, 빈사 왜곡 효과 제공
"""
import math
import random
import time
import pygame
import numpy as np

# ModernGL 임포트 시도 (C-extension 미설치 환경 대비 Graceful Fallback)
try:
    import moderngl
    HAS_MODERNGL = True
except ImportError:
    moderngl = None
    HAS_MODERNGL = False


# ============================================================
# GLSL 셰이더 코드 (ModernGL 지원 시 사용)
# ============================================================
VERTEX_SHADER = """
#version 330 core
in vec2 in_vert;
in vec2 in_uv;
out vec2 uv;

void main() {
    uv = in_uv;
    gl_Position = vec4(in_vert, 0.0, 1.0);
}
"""

FRAGMENT_SHADER = """
#version 330 core
uniform sampler2D game_texture;
uniform float u_time;

// 효과 강도 파라미터 (0.0 = 끔, 1.0 = 기본/최대)
uniform float u_vignette;
uniform float u_bloom;
uniform float u_color_grade;
uniform vec3  u_grade_color;
uniform float u_chromatic;
uniform float u_grain;
uniform float u_low_hp_pulse;
uniform float u_flash;

in vec2 uv;
out vec4 fragColor;

// 난수 생성 (필름 그레인)
float random(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 tex_coord = uv;

    // 1. 색수차 (Chromatic Aberration) & 피격 펄스
    float chrom_dist = u_chromatic * 0.008;
    vec2 offset = (tex_coord - 0.5) * chrom_dist;
    float r = texture(game_texture, tex_coord + offset).r;
    float g = texture(game_texture, tex_coord).g;
    float b = texture(game_texture, tex_coord - offset).b;
    float a = texture(game_texture, tex_coord).a;
    vec3 color = vec3(r, g, b);

    // 2. 블룸/발광 근사 (Radial Glow)
    if (u_bloom > 0.01) {
        vec3 bloom_sample = vec3(0.0);
        float bloom_weight = 0.0;
        for (int i = -2; i <= 2; i++) {
            for (int j = -2; j <= 2; j++) {
                vec2 b_offset = vec2(float(i), float(j)) * 0.003 * u_bloom;
                vec3 s = texture(game_texture, tex_coord + b_offset).rgb;
                float brightness = dot(s, vec3(0.299, 0.587, 0.114));
                if (brightness > 0.6) {
                    bloom_sample += s * (brightness - 0.6) * 1.5;
                    bloom_weight += 1.0;
                }
            }
        }
        if (bloom_weight > 0.0) {
            color += (bloom_sample / 25.0) * u_bloom * 1.8;
        }
    }

    // 3. 컬러 그레이딩 (시간대/날씨 톤 매핑)
    if (u_color_grade > 0.01) {
        vec3 graded = color * u_grade_color;
        color = mix(color, graded, u_color_grade);
    }

    // 4. 비네팅 (Vignette)
    if (u_vignette > 0.01) {
        vec2 vig_pos = (tex_coord - 0.5) * 1.4;
        float len = dot(vig_pos, vig_pos);
        float vig = 1.0 - len * u_vignette;
        color *= clamp(vig, 0.0, 1.0);
    }

    // 5. 저체력(Low HP) 붉은 비네팅 펄스
    if (u_low_hp_pulse > 0.01) {
        vec2 pulse_pos = (tex_coord - 0.5) * 1.2;
        float pulse_len = dot(pulse_pos, pulse_pos);
        float pulse_intensity = pulse_len * u_low_hp_pulse * (0.6 + 0.4 * sin(u_time * 6.0));
        color.r += pulse_intensity * 0.6;
        color.gb -= pulse_intensity * 0.3;
    }

    // 6. 총구 화염 및 플래시
    if (u_flash > 0.01) {
        color += vec3(u_flash * 0.3, u_flash * 0.25, u_flash * 0.15);
    }

    // 7. 필름 그레인 (Film Grain / Noise)
    if (u_grain > 0.01) {
        float noise = (random(tex_coord + vec2(u_time * 0.1, u_time * 0.2)) - 0.5) * u_grain * 0.12;
        color += noise;
    }

    fragColor = vec4(clamp(color, 0.0, 1.0), a);
}
"""


# ============================================================
# 포스트 프로세서 메인 클래스
# ============================================================
class PostProcessor:
    """하이브리드 그래픽 후처리 파이프라인 매니저"""

    def __init__(self, width: int, height: int, enable_shaders: bool = True):
        self.width = width
        self.height = height
        self.enable_shaders = enable_shaders
        self.use_moderngl = False
        self.ctx = None
        self.prog = None
        self.texture = None
        self.vao = None
        self.vbo = None

        # 네이티브 렌더링용 캐시 서피스 (성능 최적화)
        self._vignette_surface = None
        self._vignette_cached_w = 0
        self._vignette_cached_h = 0

        self._color_grade_surface = None
        self._last_grade_color = None

        # 초기화 시도
        if HAS_MODERNGL and self.enable_shaders:
            self._init_moderngl()

        if not self.use_moderngl:
            self._init_native_pipeline()

    def _init_moderngl(self):
        """ModernGL 컨텍스트 및 셰이더 프로그램 초기화"""
        try:
            self.ctx = moderngl.get_context()
            if not self.ctx:
                self.ctx = moderngl.create_context()

            self.prog = self.ctx.program(
                vertex_shader=VERTEX_SHADER,
                fragment_shader=FRAGMENT_SHADER,
            )

            # 정점 데이터 (풀스크린 쿼드)
            vertices = np.array([
                # x,    y,    u,   v
                -1.0, -1.0,  0.0, 1.0,
                 1.0, -1.0,  1.0, 1.0,
                -1.0,  1.0,  0.0, 0.0,
                 1.0,  1.0,  1.0, 0.0,
            ], dtype='f4')

            self.vbo = self.ctx.buffer(vertices.tobytes())
            self.vao = self.ctx.vertex_array(
                self.prog,
                [(self.vbo, '2f 2f', 'in_vert', 'in_uv')],
            )

            self.texture = self.ctx.texture((self.width, self.height), 4)
            self.texture.filter = (moderngl.LINEAR, moderngl.LINEAR)
            self.texture.repeat_x = False
            self.texture.repeat_y = False

            self.use_moderngl = True
        except Exception as e:
            self.use_moderngl = False
            self.ctx = None
            self._init_native_pipeline()

    def _init_native_pipeline(self):
        """고성능 Pygame-ce 네이티브 렌더링 캐시 생성"""
        self._create_vignette_cache()

    def _create_vignette_cache(self):
        """부드러운 방사형 비네팅 마스크 생성 (한 번 캐시하여 고속 블렌딩)"""
        w, h = self.width, self.height
        if w <= 0 or h <= 0:
            return

        scale = 4
        dw, dh = max(1, w // scale), max(1, h // scale)
        down_surf = pygame.Surface((dw, dh), pygame.SRCALPHA)
        dcx, dcy = dw / 2.0, dh / 2.0
        d_max_dist = math.hypot(dcx, dcy)

        # 픽셀 배열을 이용해 비네팅 알파 맵 생성
        alpha_map = np.zeros((dw, dh), dtype=np.uint8)
        y_indices, x_indices = np.ogrid[:dh, :dw]
        distances = np.hypot(x_indices - dcx, y_indices - dcy)
        normalized = distances / d_max_dist

        # 비네팅 곡선 (외곽으로 갈수록 알파 증가)
        vignette_curve = np.clip((normalized - 0.45) / 0.55, 0.0, 1.0) ** 1.8
        alpha_values = (vignette_curve * 220).astype(np.uint8).T

        # RGBA 서피스에 적용
        pixels_alpha = pygame.surfarray.pixels_alpha(down_surf)
        pixels_alpha[...] = alpha_values
        del pixels_alpha

        # 원본 해상도로 부드럽게 스케일
        self._vignette_surface = pygame.transform.smoothscale(down_surf, (w, h))
        self._vignette_cached_w = w
        self._vignette_cached_h = h

    def resize(self, width: int, height: int):
        """해상도 변경 시 리소스 리사이즈"""
        if width <= 0 or height <= 0:
            return
        self.width = width
        self.height = height

        if self.use_moderngl and self.ctx:
            try:
                if self.texture:
                    self.texture.release()
                self.texture = self.ctx.texture((self.width, self.height), 4)
                self.texture.filter = (moderngl.LINEAR, moderngl.LINEAR)
            except Exception:
                self.use_moderngl = False
                self._init_native_pipeline()

        self._create_vignette_cache()

    def process(self, source_surface: pygame.Surface, target_surface: pygame.Surface, uniforms: dict):
        """후처리 실행 (ModernGL 또는 네이티브 파이프라인)"""
        if not self.enable_shaders:
            if source_surface != target_surface:
                target_surface.blit(source_surface, (0, 0))
            return

        if self.use_moderngl:
            self._render_moderngl(source_surface, uniforms)
        else:
            self._render_native(source_surface, target_surface, uniforms)

    def _render_moderngl(self, source_surface: pygame.Surface, uniforms: dict):
        """ModernGL GLSL 셰이더 드로우"""
        try:
            tex_data = pygame.image.tobytes(source_surface, 'RGBA', True)
            self.texture.write(tex_data)
            self.texture.use(location=0)

            self.prog['game_texture'] = 0
            self.prog['u_time'] = float(uniforms.get('time', time.time()))
            self.prog['u_vignette'] = float(uniforms.get('vignette', 0.4))
            self.prog['u_bloom'] = float(uniforms.get('bloom', 0.3))
            self.prog['u_color_grade'] = float(uniforms.get('color_grade', 1.0))
            self.prog['u_grade_color'] = tuple(uniforms.get('grade_color', (1.0, 1.0, 1.0)))
            self.prog['u_chromatic'] = float(uniforms.get('chromatic', 0.0))
            self.prog['u_grain'] = float(uniforms.get('grain', 0.2))
            self.prog['u_low_hp_pulse'] = float(uniforms.get('low_hp_pulse', 0.0))
            self.prog['u_flash'] = float(uniforms.get('flash', 0.0))

            self.ctx.clear(0.0, 0.0, 0.0, 1.0)
            self.vao.render(moderngl.TRIANGLE_STRIP)
        except Exception:
            self.use_moderngl = False

    def _render_native(self, source_surface: pygame.Surface, target_surface: pygame.Surface, uniforms: dict):
        """Pygame-ce 고속 네이티브 포스트 프로세싱"""
        w, h = self.width, self.height
        if source_surface != target_surface:
            target_surface.blit(source_surface, (0, 0))

        # 1. 색수차 (Chromatic Aberration) 펄스
        chromatic = uniforms.get('chromatic', 0.0)
        if chromatic > 0.05:
            offset = int(chromatic * 6.0)
            if offset > 0:
                red_tint = source_surface.copy()
                red_tint.fill((255, 0, 0, 0), special_flags=pygame.BLEND_RGBA_MULT)
                target_surface.blit(red_tint, (offset, 0), special_flags=pygame.BLEND_RGBA_ADD)

                blue_tint = source_surface.copy()
                blue_tint.fill((0, 0, 255, 0), special_flags=pygame.BLEND_RGBA_MULT)
                target_surface.blit(blue_tint, (-offset, 0), special_flags=pygame.BLEND_RGBA_ADD)

        # 2. 컬러 그레이딩 (시간대 및 날씨 톤 매핑)
        grade_intensity = uniforms.get('color_grade', 0.0)
        grade_color = uniforms.get('grade_color', (1.0, 1.0, 1.0))
        if grade_intensity > 0.05:
            tint_r = int(min(255, max(0, grade_color[0] * 255)))
            tint_g = int(min(255, max(0, grade_color[1] * 255)))
            tint_b = int(min(255, max(0, grade_color[2] * 255)))

            if (tint_r, tint_g, tint_b) != (255, 255, 255):
                grade_overlay = pygame.Surface((w, h), pygame.SRCALPHA)
                alpha = int(grade_intensity * 60)
                grade_overlay.fill((tint_r, tint_g, tint_b, alpha))
                target_surface.blit(grade_overlay, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)

        # 3. 비네팅 (Vignette)
        vig_intensity = uniforms.get('vignette', 0.0)
        if vig_intensity > 0.05 and self._vignette_surface:
            target_surface.blit(self._vignette_surface, (0, 0))

        # 4. 저체력(Low HP) 붉은 비네팅 펄스
        low_hp = uniforms.get('low_hp_pulse', 0.0)
        if low_hp > 0.05:
            t = uniforms.get('time', time.time())
            pulse = 0.5 + 0.5 * math.sin(t * 6.0)
            red_alpha = int(low_hp * pulse * 140)
            if red_alpha > 0 and self._vignette_surface:
                red_vig = self._vignette_surface.copy()
                red_vig.fill((255, 30, 30, red_alpha), special_flags=pygame.BLEND_RGBA_MULT)
                target_surface.blit(red_vig, (0, 0), special_flags=pygame.BLEND_RGBA_ADD)

        # 5. 총구 화염 / 폭발 플래시
        flash = uniforms.get('flash', 0.0)
        if flash > 0.02:
            flash_surf = pygame.Surface((w, h), pygame.SRCALPHA)
            flash_alpha = int(min(255, flash * 180))
            flash_surf.fill((255, 240, 200, flash_alpha))
            target_surface.blit(flash_surf, (0, 0), special_flags=pygame.BLEND_RGBA_ADD)

        # 6. 필름 그레인 (Film Grain)
        grain = uniforms.get('grain', 0.0)
        if grain > 0.05:
            gw, gh = w // 4, h // 4
            noise_arr = np.random.randint(0, int(grain * 40), (gh, gw), dtype=np.uint8)
            noise_surf = pygame.Surface((gw, gh), pygame.SRCALPHA)
            pixels = pygame.surfarray.pixels_alpha(noise_surf)
            pixels[...] = noise_arr.T
            del pixels
            scaled_noise = pygame.transform.scale(noise_surf, (w, h))
            target_surface.blit(scaled_noise, (0, 0), special_flags=pygame.BLEND_RGBA_ADD)
