extends "res://tests/test_suite.gd"
func _run() -> void:
	for kind: String in ["checkpoint","balloon","helicopter","sailboat","service_station","marshal","spectator"]+RallyWildlifeModel.KINDS:
		var prop: Node3D=load("res://assets/screenprint/props/"+kind+".glb").instantiate()
		root.add_child(prop)
		check(prop.find_children("*","MeshInstance3D",true,false).size()>0,kind+" imports visible authored meshes")
		check(prop.find_children("*","CollisionObject3D",true,false).is_empty(),kind+" presentation does not alter vehicle physics")
		if kind in RallyWildlifeModel.KINDS:
			var expected := 2 if kind in ["kangaroo","ostrich"] else 4
			var connected := true
			for i: int in range(expected):
				var leg := prop.find_child("Leg%d"%i,true,false) as Node3D
				if leg==null or leg.get_child_count()==0: connected=false
				else:
					for part: MeshInstance3D in leg.find_children("*","MeshInstance3D",true,false):
						var bounds: AABB=part.global_transform*part.get_aabb()
						if bounds.get_center().distance_to(leg.global_position)>1.6: connected=false
			check(connected,kind+" authored limbs stay attached in world space")
		if kind in ["marshal","spectator"]:
			var arm := prop.find_child("FlagArm",true,false) as Node3D
			check(arm!=null and arm.get_child_count()>0,kind+" has an animated shoulder and connected hand/flag")
		prop.free()
	for id: String in RallyContentCatalog.VEHICLES:
		var car := RallyVehicleAppearance.build(RallyContentCatalog.vehicle(id))
		root.add_child(car)
		check(car.find_children("BrakeLamp*","MeshInstance3D",true,false).size()>=3,id+" retains emissive rear lenses at all LODs")
		car.free()
	for path: String in ["wordmark.svg","icon.svg","banner.png","stage-artbook.png","car-artbook.png","road-wear.png"]:
		check(load("res://assets/brushline/"+path) is Texture2D,path+" imports without external dependencies")
	finish()
