extends Node
## 세워 둔 차 모델의 충돌 모양(볼록 껍질)을 미리 구워 assets/models/<이름>/<이름>_hull.tres로 저장한다.
## 실행할 때 메시에서 껍질을 만들면 DAY 1에서만 0.3초(웹은 몇 배) 걸렸다(10/24).
##   Godot --headless --path . res://tests/bake_hulls.tscn

const CARS := ["sedan", "hatchback", "suv", "van", "pickup"]


func _ready() -> void:
	for m: String in CARS:
		var node: Node3D = (load(AssetCache.model_path(m)) as PackedScene).instantiate()
		var points := PackedVector3Array()
		for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			var xf := Transform3D.IDENTITY
			var n: Node = mi
			while n != node:
				xf = (n as Node3D).transform * xf
				n = n.get_parent()
			var hull := mi.mesh.create_convex_shape(true, true) as ConvexPolygonShape3D
			for p in hull.points:
				points.append(xf * p)
		node.free()
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		var err := ResourceSaver.save(shape, AssetCache.hull_path(m))
		print("HULL %s points=%d err=%d" % [m, points.size(), err])
	get_tree().quit()
