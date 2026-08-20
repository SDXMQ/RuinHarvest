shader_type canvas_item;

uniform float flash_modifier : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	
	// 원래 색상과 플래시 색상을 flash_modifier(0.0 ~ 1.0) 비율에 따라 보간
	// 알파값(투명도)은 유지하여 스프라이트 형태 보존
	color.rgb = mix(color.rgb, flash_color.rgb, flash_modifier);
	
	COLOR = color;
}
