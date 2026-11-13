shader_type canvas_item;

// 화면 캡처 텍스처
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// 후처리 파라미터 (기존 유니폼 하위 호환 유지)
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float low_hp_pulse : hint_range(0.0, 1.0) = 0.0;
uniform float infection_pulse : hint_range(0.0, 1.0) = 0.0;
uniform float grain_strength : hint_range(0.0, 0.5) = 0.03;
uniform float nvg_active : hint_range(0.0, 1.0) = 0.0;
uniform float lightning_flash : hint_range(0.0, 1.0) = 0.0;

// 신규 전술 픽셀 후처리 파라미터
uniform float chromatic_aberration : hint_range(0.0, 1.0) = 0.0;
uniform float rain_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float shadow_tint_strength : hint_range(0.0, 1.0) = 0.16;

// 난수 생성 함수 (필름 그레인 및 빗방울 시드용)
float random(vec2 uv) {
	return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	vec2 base_uv = SCREEN_UV;
	vec2 centered = base_uv - vec2(0.5);
	float dist_center = length(centered);

	// 0. NVG 어안(Barrel Distortion) 곡률 적용
	vec2 uv = base_uv;
	if (nvg_active > 0.01) {
		float r2 = dot(centered, centered);
		uv = vec2(0.5) + centered * (1.0 + 0.14 * r2 * nvg_active);
		uv = clamp(uv, vec2(0.001), vec2(0.999));
	}

	// 0-B. 우천 시 화면 외곽 렌즈 빗방울 굴절 (Rain Lens Droplets - 드문드문 맺히는 자연스러운 굴절)
	float drop_glint = 0.0;
	if (rain_intensity > 0.02) {
		float edge_mask = smoothstep(0.32, 0.72, dist_center);
		if (edge_mask > 0.01) {
			vec2 grid = vec2(12.0, 7.0);
			vec2 gv = uv * grid;
			vec2 cell_id = floor(gv);
			float cell_seed = random(cell_id);
			if (cell_seed > (1.0 - rain_intensity * 0.24)) {
				float slide = fract(TIME * (0.14 + cell_seed * 0.16) + cell_seed * 6.13);
				vec2 drop_center = vec2(
					0.22 + fract(cell_seed * 19.7) * 0.56,
					0.15 + slide * 0.70
				);
				vec2 local_pos = fract(gv) - drop_center;
				local_pos.y *= 0.85; // 세로로 살짝 길쭉한 물방울 형태
				float d = length(local_pos);
				float radius = 0.075 + 0.065 * fract(cell_seed * 41.3);
				if (d < radius) {
					float lens_falloff = (radius - d) / max(radius, 0.001);
					vec2 refr_dir = normalize(local_pos + vec2(0.0001));
					uv = clamp(uv - refr_dir * lens_falloff * 0.0065 * rain_intensity * edge_mask, vec2(0.001), vec2(0.999));
					float arc = max(dot(refr_dir, normalize(vec2(-0.4, 0.85))), 0.0);
					drop_glint = smoothstep(radius * 0.50, radius * 0.95, d) * arc * rain_intensity * edge_mask * 0.22;
				}
			}
		}
	}

	// 1. 피격/폭발 색수차 (Chromatic Aberration) + 기본 화면 텍스처 샘플
	vec3 color;
	if (chromatic_aberration > 0.001) {
		float radial = clamp(dist_center * 1.45, 0.0, 1.0);
		vec2 ca_dir = normalize(centered + vec2(0.0001));
		vec2 ca_off = ca_dir * chromatic_aberration * radial * 0.014;
		float r = texture(screen_texture, clamp(uv + ca_off, vec2(0.001), vec2(0.999))).r;
		float g = texture(screen_texture, uv).g;
		float b = texture(screen_texture, clamp(uv - ca_off, vec2(0.001), vec2(0.999))).b;
		color = vec3(r, g, b);
	} else {
		color = texture(screen_texture, uv).rgb;
	}

	// 빗방울 굴절 테두리 반짝임
	if (drop_glint > 0.001) {
		color += vec3(0.45, 0.62, 0.78) * drop_glint;
	}

	// 2. 컬러 그레이딩 (날씨/시간대 틴트)
	color *= tint_color.rgb;

	// 2-B. 다크 택티컬 차가운 청록/남색 섀도우 스플릿 토닝 & 미세 대비
	if (shadow_tint_strength > 0.001 && nvg_active < 0.5) {
		float lum = dot(color, vec3(0.299, 0.587, 0.114));
		float shadow_mask = 1.0 - smoothstep(0.04, 0.42, lum);
		vec3 cool_shadow = color * vec3(0.88, 0.98, 1.14) + vec3(0.0, 0.008, 0.018);
		color = mix(color, cool_shadow, shadow_mask * shadow_tint_strength);
	}

	// 2-C. 전술 야간투시경(NVG) 인광 단색화 + 수평 싱크 노이즈 바 + 고글 비네팅
	if (nvg_active > 0.01) {
		float lum = dot(color, vec3(0.299, 0.587, 0.114));
		float boosted = pow(clamp(lum * 2.4 + 0.08, 0.0, 1.0), 0.85);
		vec3 nvg_col = vec3(0.13, 0.96, 0.30) * boosted;
		// 밝은 피크 인광 화이트-그린 하이라이트
		if (lum > 0.68) {
			nvg_col += vec3(0.18, 0.25, 0.18) * ((lum - 0.68) * 1.4);
		}
		float scanline = sin(uv.y * 420.0) * 0.045;
		nvg_col -= scanline;
		// 수평 롤링 싱크 노이즈 라인
		float sync_y = fract(TIME * 0.17);
		float sync_bar = exp(-abs(uv.y - sync_y) * 65.0);
		float sync_noise = (random(vec2(floor(uv.y * 240.0), floor(TIME * 24.0))) - 0.5) * 0.14;
		nvg_col += (vec3(0.05, 0.22, 0.08) * sync_bar) + (sync_noise * sync_bar);
		// 쌍안 고글 원형 비네팅
		float goggle_dist = distance(uv, vec2(0.5, 0.5));
		float goggle_vig = smoothstep(0.76, 0.34, goggle_dist);
		nvg_col *= mix(0.14, 1.0, goggle_vig);
		color = mix(color, nvg_col, nvg_active);
	}

	// 3. 비네팅 (Vignette) - 낮에는 0.0으로 완전 투명, 밤/실내에서만 부드럽게 적용
	if (vignette_intensity > 0.001) {
		float dist = distance(uv, vec2(0.5, 0.5));
		float vignette = smoothstep(0.85, 0.35, dist * (0.8 + vignette_intensity));
		color = mix(color, color * vignette, vignette_intensity);
	}

	// 4. 저체력 펄스 (Low HP Pulse) - 체력 위험 시 가장자리 붉은색 점멸
	if (low_hp_pulse > 0.0) {
		float pulse = smoothstep(0.4, 0.8, distance(uv, vec2(0.5, 0.5))) * low_hp_pulse;
		color = mix(color, vec3(0.8, 0.0, 0.0), pulse * 0.7);
	}

	// 4-B. 생체 감염 비네팅 (Infection Biohazard Vignette) - 감염 시 가장자리 독성 녹색 맥동
	if (infection_pulse > 0.001) {
		float inf_v = smoothstep(0.38, 0.82, distance(uv, vec2(0.5, 0.5))) * infection_pulse;
		color = mix(color, vec3(0.12, 0.75, 0.22), inf_v * 0.65);
	}

	// 5. 필름 그레인 (Film Grain - NVG 가동 시 증폭)
	float eff_grain = grain_strength + (nvg_active * 0.045);
	float grain = random(uv + vec2(TIME, -TIME)) * eff_grain;
	color -= grain;

	// 6. 악천후(STORM) 낙뢰 섬광 (Lightning Flash)
	if (lightning_flash > 0.001) {
		color = mix(color, vec3(0.92, 0.96, 1.0), lightning_flash * 0.82);
	}

	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
