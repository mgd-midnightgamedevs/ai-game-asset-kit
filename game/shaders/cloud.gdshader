shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// 가스 구름 한 덩이(scripts/ground_cloud.gd). 카메라를 보는 판(입자 회전 포함)에 가장자리가 흐린 둥근 연기를 그린다.
// 입자 색의 밝기는 0.7 아래로 내려가지 않게 한다: GL 호환 렌더러에서 막 생긴 입자 하나가 색 0(검정)으로 그려져
// DAY 1 리프트 착지 때 바닥에 검은 원이 1초 넘게 남았다(10/23). 투명도는 입자 색의 알파(시간에 따라 옅어짐)를 그대로 쓴다.

uniform sampler2D soft : source_color, filter_linear, repeat_disable;

void vertex() {
	mat4 mat_world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	mat_world = mat_world * mat4(vec4(cos(INSTANCE_CUSTOM.x), -sin(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(sin(INSTANCE_CUSTOM.x), cos(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat_world;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	ALBEDO = max(COLOR.rgb, vec3(0.7));
	ALPHA = texture(soft, UV).a * clamp(COLOR.a, 0.0, 1.0);
}
