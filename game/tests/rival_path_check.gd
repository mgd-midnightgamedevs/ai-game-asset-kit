extends Node
## 앞차 경로가 세워 둔 차·벽을 뚫고 지나가는지 본다. 앞차는 경로를 그대로 따라가며 부딪히지 않으므로(AnimatableBody3D),
## 경로가 다른 차를 지나면 화면에서 그 차 위로 타고 넘어간다(10/23 사용자: "라이벌 차가 다른 차 위로 넘어간다").
##   Godot --headless --path . res://tests/rival_path_check.tscn -- day=2
## 경로를 0.25m마다 따라가며 앞차 상자(모델 크기, 바닥에서 0.25m 띄움)와 겹치는 충돌체를 찍는다.

var day := 1


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("day="):
			day = int(a.substr(4))
	var level: Node = (load("res://scenes/day%d.tscn" % day) as PackedScene).instantiate()
	add_child(level)
	for i in 3:
		await get_tree().physics_frame
	var r: RivalCar = level.rival
	var space := r.get_world_3d().direct_space_state
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 1.1, 3.0)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.exclude = [r.get_rid(), level.car.get_rid()]
	var length := r.curve.get_baked_length()
	var hits := 0
	var off := 0.0
	var last := ""
	while off < length - 0.5:
		var p := r.curve.sample_baked(off, true)
		var p2 := r.curve.sample_baked(minf(off + 0.5, length), true)
		var fwd := p2 - p
		fwd.y = 0.0
		if fwd.length() < 0.01:
			off += 0.25
			continue
		var b := Basis.looking_at(-fwd.normalized(), Vector3.UP)
		q.transform = Transform3D(b, p + Vector3.UP * (0.25 + 0.55) + b.y * 0.0)
		for h in space.intersect_shape(q, 8):
			var c: Object = h.collider
			var what := "%s(%s)" % [c.get_class(), (c as Node).get_parent().name if c is Node else "?"]
			var key := what + str(Vector3i((c as Node3D).global_position)) if c is Node3D else what
			if key != last:
				last = key
				hits += 1
				print("HIT progress=%.2f pos=(%.1f, %.1f, %.1f) %s at %s" % [off / length, p.x, p.y, p.z, what,
					str((c as Node3D).global_position) if c is Node3D else ""])
		off += 0.25
	print("RIVAL_PATH_CHECK day=%d length=%.1f hits=%d" % [day, length, hits])
	get_tree().quit()
