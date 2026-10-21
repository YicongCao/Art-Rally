extends SceneTree
func _initialize() -> void:
	for id: String in RallyContentCatalog.STAGES:
		var route := RallyStageRoute.new();route.build(RallyContentCatalog.stage(id))
		print(id)
		for s: float in range(100,int(route.length)-100,50):
			var curvature := route.tangent_at(s-10).angle_to(route.tangent_at(s+10))/20
			if curvature<.008 and route.width_at(s)>5.8:
				print("s ",s," width ",snappedf(route.width_at(s),.1)," radius ",roundi(1/maxf(curvature,.0001))," surface ",route.definition.surface_id(s))
	quit()
