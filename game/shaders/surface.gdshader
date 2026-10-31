shader_type spatial;
// 아스팔트·보도·콘크리트 바닥(commute_day.gd의 _material). 프로토타입 격자 대신 세계 좌표 잡음으로 알갱이와 얼룩을 그린다.
// tile > 0이면 그 크기의 보도블록 줄눈을 긋는다(속도감은 줄눈과 차선이 준다). 멀어지면 잡음을 평균으로 줄여 지글거리지 않게.

uniform vec3 base_color : source_color = vec3(0.16, 0.17, 0.19);
uniform vec3 stain_color : source_color = vec3(0.12, 0.13, 0.14);
uniform float grain = 0.06; // 알갱이 밝기 폭
uniform float tile = 0.0; // 블록 크기(m). 0이면 줄눈 없음
uniform float roughness = 0.9;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec3 n = abs(wnrm);
	vec2 uv = n.y > 0.5 ? wpos.xz : (n.x > 0.5 ? wpos.zy : wpos.xy);
	float px = fwidth(uv.x) + fwidth(uv.y);
	// 큰 얼룩(5~20m) + 중간 얼룩
	float stain = vnoise(uv * 0.07) * 0.6 + vnoise(uv * 0.31) * 0.4;
	vec3 col = mix(base_color, stain_color, smoothstep(0.35, 0.8, stain));
	// 알갱이: 가까울 때만
	float g = vnoise(uv * 9.0) - 0.5;
	col *= 1.0 + g * grain * 2.0 * (1.0 - smoothstep(0.05, 0.2, px));
	if (tile > 0.0) {
		vec2 t = abs(fract(uv / tile) - 0.5) * tile;
		float d = tile * 0.5 - max(t.x, t.y);
		float joint = 1.0 - smoothstep(0.012, 0.012 + px * 1.5 + 0.004, d);
		col *= 1.0 - 0.35 * joint * (1.0 - smoothstep(0.05, 0.25, px));
		col *= 0.97 + 0.06 * hash(floor(uv / tile)); // 블록마다 조금 다른 밝기
	}
	ALBEDO = col;
	ROUGHNESS = roughness;
}
