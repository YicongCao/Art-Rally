class_name RallyScreenprintProps
extends RefCounted

static func add(parent: Node3D,kind: String,position: Vector3 = Vector3.ZERO) -> Node3D:
 var path := "res://assets/screenprint/props/"+kind+".glb"
 if not ResourceLoader.exists(path): return null
 var visual: Node3D=load(path).instantiate()
 visual.name="Screenprint"+kind.capitalize()
 visual.position=position
 parent.add_child(visual)
 RallyVehicleAppearance._style(visual,0,Vector3.ZERO)
 return visual
