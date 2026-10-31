shader_type spatial;
// 그래픽 없는 프로토타입용 월드 좌표 격자. 속도·높이 감각을 주려고 모든 면에 2m 격자를 그린다.

uniform vec3 base_color : source_color = vec3(0.62, 0.64, 0.7);
uniform vec3 line_color : source_color = vec3(0.42, 0.44, 0.5);
uniform float cell = 2.0;
uniform float line_width = 0.05;
uniform float major_every = 5.0;

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float grid_line(vec2 uv, float size, float width) {
	vec2 g = abs(fract(uv / size - 0.5) - 0.5) * size;
	float d = min(g.x, g.y);
	float aa = fwidth(d) * 1.2;
	return 1.0 - smoothstep(width - aa, width + aa, d);
}

void fragment() {
	vec3 n = abs(world_nrm);
	vec2 uv = n.y > 0.5 ? world_pos.xz : (n.x > 0.5 ? world_pos.zy : world_pos.xy);
	float minor = grid_line(uv, cell, line_width);
	float major = grid_line(uv, cell * major_every, line_width * 2.0);
	vec3 col = mix(base_color, line_color, max(minor * 0.6, major));
	ALBEDO = col;
	ROUGHNESS = 0.92;
}
