extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
 var scene: Node3D=load("res://scenes/game/challenge.tscn").instantiate()
 scene.managed_flow=true
 scene.challenge=RallyContentCatalog.challenge("redrock_canyon","R200")
 scene.challenge.stage=load("res://resources/stages/redrock_sample.tres").duplicate(true)
 scene.profile=RallyProfileStore.new()
 scene.profile.path="user://redrock-sample/profile.json"
 scene.free_practice=true
 var stage: RallyStageGenerator=scene.get_node("Stage")
 stage.auto_build=false
 stage.definition=scene.challenge.stage
 root.add_child(scene)
 await stage.build_incremental(func(_value: float,_message: String): pass)
 scene.start()
 scene.controls.resume()
 scene.return_requested.connect(quit)
