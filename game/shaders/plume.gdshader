shader_type spatial;
// 냉가스 분사 기둥(thruster.gd의 원뿔). 노즐 쪽이 진하고 끝으로 갈수록 사라진다.
// 정면에서 보이는 가운데가 밝고 가장자리는 옅어서 납작한 흰 원뿔(빛줄기)이 아니라 뿜어 나오는 공기처럼 보인다.
// 더해 그리기라 뒤의 수증기·차와 겹치면 빛나 보인다. CylinderMesh의 UV.y는 위(노즐)가 0, 끝이 1.
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

uniform vec3 edge_color : source_color = vec3(0.45, 0.62, 0.95); // 옅은 가장자리는 푸른빛
uniform float falloff = 2.6; // 클수록 끝이 빨리 사라진다

void fragment() {
	float along = clamp(UV.y, 0.0, 1.0);
	float fade = pow(1.0 - along, falloff);
	float core = pow(abs(dot(normalize(NORMAL), VIEW)), 2.2);
	ALBEDO = mix(edge_color, vec3(1.0), core * (1.0 - along * 0.6));
	ALPHA = fade * (0.08 + 0.85 * core);
}
