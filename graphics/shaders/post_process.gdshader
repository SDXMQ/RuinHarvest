shader_type canvas_item;

// 화면 캡처 텍스처
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// 후처리 파라미터
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float low_hp_pulse : hint_range(0.0, 1.0) = 0.0;
uniform float grain_strength : hint_range(0.0, 0.5) = 0.03;

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
	
	// 4. 필름 그레인 (Film Grain)
	float grain = random(uv + vec2(TIME, -TIME)) * grain_strength;
	color -= grain;
	
	COLOR = vec4(color, 1.0);
}
