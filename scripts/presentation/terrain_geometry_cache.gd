class_name RallyTerrainGeometryCache
extends RefCounted

# Only immutable generated geometry, never Nodes, timers or player state.
# Content keys include all stored stage properties, so edited definitions miss.
const MAX_ENTRIES := 2
const MAX_BYTES := 96*1024*1024
static var entries: Dictionary = {}
static var order: Array[String] = []
static var bytes: int = 0

static func key_for(definition: RallyStageDefinition,points: PackedVector3Array) -> String:
	var state: Array=[points]
	for property: Dictionary in definition.get_property_list():
		if int(property.usage)&PROPERTY_USAGE_STORAGE and property.name!="script":
			state.append([property.name,definition.get(property.name)])
	return var_to_bytes(state).hex_encode().sha256_text()

static func fetch(key: String) -> Dictionary:
	if not entries.has(key): return {}
	order.erase(key)
	order.append(key)
	return entries[key].data

static func remember(key: String,data: Dictionary) -> void:
	var cost: int=data.vertices.size()*12
	for mesh: ArrayMesh in data.meshes: cost+=mesh.surface_get_array_len(0)*24
	if cost>MAX_BYTES: return
	if entries.has(key):
		bytes-=entries[key].bytes
		entries.erase(key)
		order.erase(key)
	while not order.is_empty() and (order.size()>=MAX_ENTRIES or bytes+cost>MAX_BYTES):
		var old: String=order.pop_front()
		bytes-=entries[old].bytes
		entries.erase(old)
	entries[key]={"data":data,"bytes":cost}
	order.append(key)
	bytes+=cost

static func clear() -> void:
	entries.clear()
	order.clear()
	bytes=0
