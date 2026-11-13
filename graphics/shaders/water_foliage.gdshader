shader_type canvas_item;

// 0 = 수면 (파문 + 반사 + 빗물 동심원), 1 = 수풀/나무 (계단식 바람 흔들림)
uniform int effect_mode = 0;
uniform float rain_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float wind_strength : hint_range(0.0, 2.5) = 0.75;
uniform vec2 tile_v_range = vec2(0.1666667, 0.3333333);
uniform vec4 water_tint : source_color = vec4(0.12, 0.24, 0.32, 0.88);
uniform vec4 shimmer_color : source_color = vec4(0.55, 0.78, 0.88, 1.0);

varying vec2 v_world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	if (effect_mode == 1) {
		float v_span = max(tile_v_range.y - tile_v_range.x, 0.0001);
		float top_w = clamp(1.0 - (UV.y - tile_v_range.x) / v_span, 0.0, 1.0);
		float gust = sin(TIME * (1.8 + wind_strength * 0.9) + v_world_pos.x * 0.032 + v_world_pos.y * 0.024);
		float micro = cos(TIME * 3.4 + v_world_pos.x * 0.09) * 0.35;
		VERTEX.x += round((gust + micro) * wind_strength * 1.6 * top_w);
	}
}

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	if (base.a < 0.01) {
		discard;
	}

	if (effect_mode == 0) {
		// 픽셀 그리드 스냅 월드 좌표
		vec2 wpx = floor(v_world_pos);

		// 픽셀 수면 파동 & 하늘/달빛 반사 쉬머
		float wave_a = sin(wpx.x * 0.22 + TIME * 2.1 + sin(wpx.y * 0.16) * 2.0);
		float wave_b = cos(wpx.y * 0.25 - TIME * 1.4 + wpx.x * 0.08);
		float wave = wave_a * 0.55 + wave_b * 0.45;

		vec3 col = mix(base.rgb, water_tint.rgb, 0.28);
		if (wave > 0.58) {
			col = mix(col, shimmer_color.rgb, 0.32);
		} else if (wave < -0.45) {
			col *= 0.84;
		}

		// 우천 시 동심원 빗방울 파문 (Raindrop Concentric Pixel Ripples)
		if (rain_intensity > 0.04) {
			vec2 cell = floor(wpx / 20.0);
			vec2 local_px = mod(wpx, 20.0);
			float seed = hash21(cell);
			float speed = 1.45 + seed * 0.8;
			float phase = fract(TIME * speed + seed * 6.2831);
			vec2 drop_center = vec2(4.0 + hash21(cell + vec2(3.1, 7.2)) * 12.0,
			                        4.0 + hash21(cell + vec2(9.4, 2.7)) * 12.0);
			float dist = length(local_px - drop_center);
			float radius = phase * 7.5;
			if (phase < 0.85 && abs(dist - radius) < 0.95) {
				float ripple_alpha = (1.0 - phase / 0.85) * rain_intensity * 0.72;
				col = mix(col, shimmer_color.rgb * 1.25, ripple_alpha);
			}
		}

		COLOR = vec4(col, base.a);
	} else {
		// 수풀/나무 바람 하이라이트 얼룩 (미세한 명암 맥동)
		vec2 wpx = floor(v_world_pos * 0.5);
		float dapple = sin(wpx.x * 0.15 + TIME * 1.7 + wpx.y * 0.12);
		if (dapple > 0.75) {
			base.rgb *= 1.07;
		}
		COLOR = base;
	}
}
