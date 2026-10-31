shader_type spatial;
// 상자 건물의 겉면(commute_day.gd의 _building_material). 층과 창 칸을 세계 좌표로 그려서 상자 크기와 상관없이 같은 축척이다.
// 1층은 상가 유리와 간판 띠, 그 위는 층마다 창. 창 유리는 하늘을 비추고(금속성·매끈) 창마다 밝기가 조금씩 다르다.
// 멀어서 창 칸이 픽셀보다 작아지면 평균 색으로 바꿔 무늬가 지글거리지 않게 한다. 지붕은 거친 방수 시트.

uniform vec3 wall_color : source_color = vec3(0.74, 0.72, 0.67);
uniform vec3 glass_color : source_color = vec3(0.18, 0.24, 0.3);
uniform vec3 frame_color : source_color = vec3(0.26, 0.28, 0.3);
uniform vec3 roof_color : source_color = vec3(0.4, 0.4, 0.41);
uniform float floor_h = 3.4; // 층 높이(m)
uniform float bay_w = 2.4; // 창 칸 너비(m)
uniform vec2 window_frac = vec2(0.6, 0.55); // 칸 안에서 창이 차지하는 가로·세로 비율
uniform float ribbon = 0.0; // 1이면 칸 사이 벽 없이 가로로 이어진 띠창
uniform float ground_h = 4.6; // 1층(상가) 높이
uniform float seed = 0.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 가운데가 0인 좌표 x에서 반폭 hw 안이면 1(경계는 aa만큼 부드럽게)
float inside(float x, float hw, float aa) {
	return smoothstep(hw + aa, hw - aa, abs(x));
}

void fragment() {
	vec3 n = normalize(wnrm);
	vec3 col;
	float rough = 0.85;
	float metal = 0.0;
	if (n.y > 0.5) {
		float g = hash(floor(wpos.xz * 3.0)) * 0.06;
		col = roof_color * (0.94 + g);
		rough = 0.95;
	} else if (n.y < -0.5) {
		col = wall_color * 0.45;
	} else {
		float u = abs(n.x) > abs(n.z) ? wpos.z : wpos.x;
		float y = wpos.y;
		if (y < ground_h) {
			// 상가: 바닥 턱, 큰 유리, 간판 띠
			float su = u / (bay_w * 2.0);
			float aa = fwidth(su) + 0.002;
			float g = inside(fract(su) - 0.5, 0.46, aa) * step(0.45, y) * step(y, ground_h - 0.95);
			vec3 shop = mix(frame_color, glass_color * 0.7, g);
			col = y >= ground_h - 0.95 ? frame_color * 0.75 : shop;
			rough = mix(0.8, 0.08, g);
			metal = 0.5 * g;
		} else {
			float fy = (y - ground_h) / floor_h;
			float bx = u / bay_w;
			float fl = floor(fy);
			float bi = floor(bx);
			vec2 aa = vec2(fwidth(bx), fwidth(fy)) + 0.002;
			float wx = ribbon > 0.5 ? 1.0 : inside(fract(bx) - 0.5, window_frac.x * 0.5, aa.x); // 띠창은 칸 사이 벽 없음(smoothstep 두 끝이 같으면 GL에서 0이 돼 창이 사라졌다)
			float wy = inside(fract(fy) - 0.55, window_frac.y * 0.5, aa.y);
			float w = wx * wy;
			float h = hash(vec2(bi, fl) + seed);
			vec3 glass = glass_color * (0.7 + 0.6 * h);
			glass = mix(glass, vec3(0.72, 0.7, 0.64), step(0.86, h) * step(0.6, fract(fy)) * 0.5); // 블라인드 내린 창
			// 층 사이 띠(슬래브)는 조금 어둡게
			float slab = 1.0 - 0.12 * inside(fract(fy) - 0.03, 0.04, aa.y);
			vec3 wall = wall_color * slab;
			col = mix(wall, glass, w);
			rough = mix(0.85, 0.07, w);
			metal = mix(0.0, 0.65, w);
			// 멀어서 칸이 픽셀보다 작으면 평균으로(지글거림 방지)
			float far_ = smoothstep(0.18, 0.45, max(aa.x, aa.y));
			float cover = (ribbon > 0.5 ? 1.0 : window_frac.x) * window_frac.y;
			col = mix(col, mix(wall_color, glass_color, cover), far_);
			rough = mix(rough, mix(0.85, 0.3, cover), far_);
			metal = mix(metal, 0.3 * cover, far_);
		}
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
}
