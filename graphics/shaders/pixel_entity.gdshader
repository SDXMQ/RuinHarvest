shader_type canvas_item;

uniform float flash_modifier : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float stealth_dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 outline_color : source_color = vec4(0.05, 0.06, 0.08, 0.95);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.22;

float bayer4x4(vec2 frag_xy) {
	ivec2 px = ivec2(floor(frag_xy * 0.5)) & ivec2(3);
	int idx = px.y * 4 + px.x;
	if (idx == 0) return 0.0 / 16.0;
	if (idx == 1) return 8.0 / 16.0;
	if (idx == 2) return 2.0 / 16.0;
	if (idx == 3) return 10.0 / 16.0;
	if (idx == 4) return 12.0 / 16.0;
	if (idx == 5) return 4.0 / 16.0;
	if (idx == 6) return 14.0 / 16.0;
	if (idx == 7) return 6.0 / 16.0;
	if (idx == 8) return 3.0 / 16.0;
	if (idx == 9) return 11.0 / 16.0;
	if (idx == 10) return 1.0 / 16.0;
	if (idx == 11) return 9.0 / 16.0;
	if (idx == 12) return 15.0 / 16.0;
	if (idx == 13) return 7.0 / 16.0;
	if (idx == 14) return 13.0 / 16.0;
	return 5.0 / 16.0;
}

void fragment() {
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	vec2 sample_uv = UV;
	if (tex_size.x >= 32.0 && tex_size.y >= 32.0) {
		// 회전 시 아틀라스 텍셀 떨림 완화 (텍셀 중심 스냅)
		sample_uv = (floor(UV * tex_size) + vec2(0.5)) / tex_size;
	}
	vec4 tex = texture(TEXTURE, sample_uv);
	vec4 base = tex * COLOR;

	// Bayer 4x4 은신 픽셀 디졸브 (야간 추격자 등)
	if (stealth_dissolve > 0.001 && base.a > 0.05) {
		float threshold = bayer4x4(FRAGCOORD.xy);
		if (stealth_dissolve > threshold + 0.04) {
			discard;
		} else if (stealth_dissolve > threshold - 0.06) {
			// 디졸브 경계 청록 스텔스 프린지
			base.rgb = mix(base.rgb, vec3(0.28, 0.85, 0.95), 0.35);
		}
	}

	// 피격 히트 플래시 (기존 hit_flash.gdshader 하위 호환 + HDR 발광)
	if (flash_modifier > 0.001) {
		base.rgb = mix(base.rgb, flash_color.rgb * 1.25, flash_modifier);
	}

	COLOR = base;
}

void light() {
	// 노멀맵 기반 3단계 전술 셀 셰이딩 + 가장자리 림 라이트
	float ndotl = max(dot(NORMAL, LIGHT_DIRECTION), 0.0);
	float cel = 0.44;
	if (ndotl > 0.62) {
		cel = 1.18;
	} else if (ndotl > 0.25) {
		cel = 0.82;
	} else {
		cel = 0.42 + rim_strength * 0.25;
	}
	float rim = pow(clamp(1.0 - max(NORMAL.z, 0.0), 0.0, 1.0), 1.4) * rim_strength * 0.65 * step(0.12, ndotl);
	vec3 lit_rgb = COLOR.rgb * LIGHT_COLOR.rgb * LIGHT_ENERGY * (cel + rim);
	LIGHT = vec4(lit_rgb, LIGHT_COLOR.a * COLOR.a);
}
