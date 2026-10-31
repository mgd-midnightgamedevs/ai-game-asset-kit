shader_type spatial;
render_mode cull_disabled;
// 차 칠 바꾸기(로드스터, 앞차 SUV). Tripo 텍스처(색·금속/거칠기·노멀)를 그대로 쓰고 색만 바꾼다.
// - 원래 칠 색상(src_hue, 기본 빨강) 픽셀만 골라 색상·채도를 새 칠로 바꾸고 밝기(명암)는 원래 비율을 지킨다.
// - 범퍼·미러·옆 치마(trim)는 부품 전체를 다른 색으로 칠할 수 있다. 명암은 그 부품 평균 밝기에 대한 비율.
// 금속/거칠기 텍스처는 손대지 않으므로 광택은 그대로다.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap, repeat_enable; // G 거칠기, B 금속(glTF)
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_scale = 1.0;

uniform bool paint_on = false;
uniform vec3 paint_hsv = vec3(0.0, 0.8, 0.63); // 새 칠(sRGB 기준 HSV)
uniform float paint_ref_v = 0.63; // 원래 칠의 평균 밝기. 이 밝기가 새 칠의 밝기가 된다
uniform float paint_ref_s = 0.8; // 원래 칠의 평균 채도. 이 채도가 새 칠의 채도가 된다
uniform float src_hue = 0.0; // 바꿀 원래 칠의 색상(0 빨강, 0.646 SUV 남색)
uniform float paint_metallic = -1.0; // 0 이상이면 새로 칠한 곳의 금속도. 금속 칠(SUV)은 주변을 비춰 밝은 색이 칙칙해지므로 낮춘다
uniform bool src_white = false; // 원래 칠이 흰색(채도 없음)인 모델: 밝고 채도 낮은 픽셀을 칠로 본다(paint_ref_v = 흰 칠 평균 밝기)
uniform bool mask_wide = false; // 그늘진 어두운 칠까지 덮는다. 덜 덮으면 원래 색이 테두리로 남아 섞인다(남색 + 노랑 = 녹색 얼룩). 세워 둔 차·앞차용

uniform bool trim_on = false;
uniform vec3 trim_color = vec3(1.0); // sRGB
uniform float trim_luma = 0.1; // 이 부품 원래 텍스처의 평균 밝기

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec3 c = pow(texture(albedo_tex, UV).rgb, vec3(1.0 / 2.2)); // 텍스처는 선형으로 읽히므로 sRGB로 돌려 색을 다룬다
	float m = 0.0; // 새로 칠한 정도
	if (trim_on) {
		float luma = dot(c, vec3(0.299, 0.587, 0.114));
		c = trim_color * clamp(luma / max(trim_luma, 0.01), 0.35, 1.8);
	} else if (paint_on && src_white) {
		vec3 hsv = rgb2hsv(c);
		m = smoothstep(0.16, 0.08, hsv.y) * smoothstep(paint_ref_v * 0.62, paint_ref_v * 0.8, hsv.z);
		vec3 painted = hsv2rgb(vec3(paint_hsv.x, paint_hsv.y, clamp(hsv.z * paint_hsv.z / paint_ref_v, 0.0, 1.0)));
		c = mix(c, painted, m);
	} else if (paint_on) {
		vec3 hsv = rgb2hsv(c);
		float hd = abs(fract(hsv.x - src_hue + 0.5) - 0.5); // 원래 칠 색상까지 거리
		if (mask_wide) {
			m = smoothstep(0.11, 0.06, hd) * smoothstep(paint_ref_s * 0.25, paint_ref_s * 0.5, hsv.y) * smoothstep(0.03, 0.08, hsv.z);
		} else {
			m = smoothstep(0.08, 0.04, hd) * smoothstep(paint_ref_s * 0.375, paint_ref_s * 0.625, hsv.y) * smoothstep(0.06, 0.14, hsv.z);
		}
		vec3 painted = hsv2rgb(vec3(paint_hsv.x, paint_hsv.y * clamp(hsv.y / paint_ref_s, 0.0, 1.0),
			clamp(hsv.z * paint_hsv.z / paint_ref_v, 0.0, 1.0)));
		c = mix(c, painted, m);
	}
	ALBEDO = pow(clamp(c, 0.0, 1.0), vec3(2.2));
	vec4 orm = texture(orm_tex, UV);
	ROUGHNESS = orm.g;
	METALLIC = paint_metallic >= 0.0 ? mix(orm.b, paint_metallic, m) : orm.b;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
}
