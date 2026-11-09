shader_type canvas_item;

// 화면 캡처 텍스처
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// 후처리 파라미터
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float low_hp_pulse : hint_range(0.0, 1.0) = 0.0;
uniform float infection_pulse : hint_range(0.0, 1.0) = 0.0;
uniform float grain_strength : hint_range(0.0, 0.5) = 0.03;
uniform float nvg_active : hint_range(0.0, 1.0) = 0.0;
uniform float lightning_flash : hint_range(0.0, 1.0) = 0.0;

// 난수 생성 함수 (필름 그레인용)
float random(vec2 uv) {
	return fract(sin(dot(uv.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	
	// 기본 화면 텍스처 (선명한 가시성 유지)
	vec3 color = texture(screen_texture, uv).rgb;
	
	// 1. 컬러 그레이딩 (날씨/시간대 틴트)
	color *= tint_color.rgb;
	
	// 1-2. 전술 야간투시경(NVG) 녹색 단색화 + 스캔라인 + 고글 비네팅
	if (nvg_active > 0.01) {
		float lum = dot(color, vec3(0.299, 0.587, 0.114));
		float boosted = pow(clamp(lum * 2.4 + 0.08, 0.0, 1.0), 0.85);
		vec3 nvg_col = vec3(0.12, 0.95, 0.28) * boosted;
		float scanline = sin(uv.y * 420.0) * 0.045;
		nvg_col -= scanline;
		float goggle_dist = distance(uv, vec2(0.5, 0.5));
		float goggle_vig = smoothstep(0.78, 0.36, goggle_dist);
		nvg_col *= mix(0.22, 1.0, goggle_vig);
		color = mix(color, nvg_col, nvg_active);
	}
	
	// 2. 비네팅 (Vignette) - 낮에는 0.0으로 완전 투명, 밤/실내에서만 부드럽게 적용
	if (vignette_intensity > 0.001) {
		float dist = distance(uv, vec2(0.5, 0.5));
		float vignette = smoothstep(0.85, 0.35, dist * (0.8 + vignette_intensity));
		color = mix(color, color * vignette, vignette_intensity);
	}
	
	// 3. 저체력 펄스 (Low HP Pulse) - 체력 위험 시 가장자리 붉은색 점멸
	if (low_hp_pulse > 0.0) {
		float pulse = smoothstep(0.4, 0.8, distance(uv, vec2(0.5, 0.5))) * low_hp_pulse;
		color = mix(color, vec3(0.8, 0.0, 0.0), pulse * 0.7);
	}
	
	// 3-B. 생체 감염 비네팅 (Infection Biohazard Vignette) - 감염 시 가장자리 독성 녹색 맥동
	if (infection_pulse > 0.001) {
		float inf_v = smoothstep(0.38, 0.82, distance(uv, vec2(0.5, 0.5))) * infection_pulse;
		color = mix(color, vec3(0.12, 0.75, 0.22), inf_v * 0.65);
	}
	
	// 4. 필름 그레인 (Film Grain - NVG 가동 시 증폭)
	float eff_grain = grain_strength + (nvg_active * 0.045);
	float grain = random(uv + vec2(TIME, -TIME)) * eff_grain;
	color -= grain;
	
	// 5. 악천후(STORM) 낙뢰 섬광 (Lightning Flash)
	if (lightning_flash > 0.001) {
		color = mix(color, vec3(0.92, 0.96, 1.0), lightning_flash * 0.82);
	}
	
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
