class_name RallyGarageStore
extends RefCounted

# Separate additive archive keeps legacy profile/ghost bytes and unlocks untouched.
var path := "user://player/garage.json"
var data: Dictionary={"version":1,"slots":{},"modified":{},"tests":{}}
var message := ""
var read_only := false
var from_backup := false

func load_file() -> Error:
 read_only=false
 from_backup=false
 if not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".bak"): return OK
 for file: String in [path,path+".bak"]:
  var candidate: Variant=RallyProfileStore.read_json(file)
  if valid(candidate):
   data=candidate
   from_backup=file.ends_with(".bak")
   message="车库已从备份恢复" if from_backup else ""
   return OK
 read_only=true
 message="车库存档损坏，原文件已保留，本次不会覆盖"
 return ERR_FILE_CORRUPT

static func valid(value: Variant) -> bool:
 if value is not Dictionary or value.get("version")!=1: return false
 for field: String in ["slots","modified","tests"]:
  if value.get(field) is not Dictionary: return false
 for id: String in value.slots:
  var car:=RallyContentCatalog.vehicle(id)
  if car==null or value.slots[id] is not Array or value.slots[id].size()!=3: return false
  for setup: Variant in value.slots[id]:
   if setup!=null and not RallyGarageCatalog.valid(setup,car): return false
 for kind: String in ["modified","tests"]:
  for bucket: Variant in value[kind].values():
   if bucket is not Dictionary or bucket.get("recent") is not Array or bucket.recent.size()>20: return false
   for result: Variant in [bucket.get("best",{}),bucket.get("last",{})]+bucket.recent:
    if result is not Dictionary or not RallyProfileStore.valid_result(result): return false
    var car:=RallyContentCatalog.vehicle(str(result.get("vehicle","")))
    if car==null or not RallyGarageCatalog.valid(result.get("setup"),car): return false
    if result.get("fingerprint")!=RallyGarageCatalog.fingerprint(result.setup): return false
 return true

func _commit(next: Dictionary) -> Error:
 if read_only: return ERR_FILE_CORRUPT
 if not valid(next): return ERR_INVALID_DATA
 var error:=RallyProfileStore.atomic_json(path,next,not from_backup)
 if error==OK:
  data=next
  from_backup=false
  message="已保存"
 else: message="保存失败，原方案与成绩已保留"
 return error

func slots(id: String) -> Array:
 return data.slots.get(id,[null,null,null]).duplicate(true)

func save_slot(id: String,index: int,setup: Dictionary) -> Error:
 if index<0 or index>=3 or not RallyGarageCatalog.valid(setup,RallyContentCatalog.vehicle(id)): return ERR_INVALID_DATA
 var next:=data.duplicate(true)
 var values:=slots(id)
 values[index]=setup.duplicate(true)
 values[index].name="方案 %d"%(index+1)
 next.slots[id]=values
 return _commit(next)

static func key(challenge: RallyChallengeDefinition) -> String:
 return challenge.key()+"|garage-1"

func bucket(challenge: RallyChallengeDefinition,test: bool) -> Dictionary:
 return data["tests" if test else "modified"].get(key(challenge),{}).duplicate(true)

func load_ghost(challenge: RallyChallengeDefinition,test: bool) -> Dictionary:
 var result: Dictionary=bucket(challenge,test).get("last" if test else "best",{})
 var file: String=str(result.get("ghost",""))
 if file.is_empty() or file!=file.get_file() or not file.begins_with(key(challenge).sha256_text()+"-"): return {}
 var ghost: Variant=RallyProfileStore.read_json(path.get_base_dir()+"/garage_ghosts/"+file)
 if ghost is not Dictionary or not RallyGhostRecording.valid(ghost,key(challenge)): return {}
 if ghost.get("fingerprint")!=result.get("fingerprint") or ghost.get("physics")!=challenge.vehicle.revision: return {}
 if ghost.get("vehicle")!=challenge.vehicle.vehicle_id or ghost.get("stage")!=challenge.stage.stage_id: return {}
 if not RallyGarageCatalog.valid(ghost.get("setup"),RallyContentCatalog.vehicle(challenge.vehicle.vehicle_id)): return {}
 if RallyGarageCatalog.fingerprint(ghost.setup)!=str(ghost.fingerprint): return {}
 return ghost

func record(challenge: RallyChallengeDefinition,result: Dictionary,ghost: Dictionary,test: bool) -> Dictionary:
 if not RallyProfileStore.valid_result(result): return {"saved":false,"reason":"自动跑段与练习不写入改装纪录"}
 var setup:=challenge.vehicle.garage_setup
 if not RallyGarageCatalog.valid(setup,RallyContentCatalog.vehicle(challenge.vehicle.vehicle_id)): return {"saved":false,"reason":"配置无效"}
 var id:=key(challenge)
 if not RallyGhostRecording.valid(ghost,id): return {"saved":false,"reason":"轨迹不完整，保留原纪录"}
 var next:=data.duplicate(true)
 var kind: String="tests" if test else "modified"
 var previous: Dictionary=next[kind].get(id,{})
 var entry:=result.duplicate(true)
 entry.erase("outcome")
 entry.setup=setup.duplicate(true)
 entry.fingerprint=RallyGarageCatalog.fingerprint(setup)
 entry.vehicle=challenge.vehicle.vehicle_id
 entry.physics=challenge.vehicle.revision
 entry.ghost=id.sha256_text()+"-"+str(Time.get_ticks_usec())+".json"
 ghost=ghost.duplicate(true)
 ghost["fingerprint"]=entry.fingerprint
 ghost["setup"]=entry.setup
 ghost["physics"]=entry.physics
 ghost["vehicle"]=entry.vehicle
 ghost["stage"]=challenge.stage.stage_id
 var filename:=path.get_base_dir()+"/garage_ghosts/"+str(entry.ghost)
 if RallyProfileStore.atomic_json(filename,ghost,false)!=OK: return {"saved":false,"reason":"幽灵保存失败，保留原纪录"}
 var better: bool=previous.is_empty() or float(entry.total_time)<float(previous.best.total_time)
 var recent: Array=previous.get("recent",[])
 recent.append(entry)
 while recent.size()>20: recent.pop_front()
 next[kind][id]={"best":entry if better else previous.best,"last":entry,"recent":recent}
 var error:=_commit(next)
 if error!=OK: DirAccess.remove_absolute(filename)
 else: _cleanup_ghosts()
 return {"saved":error==OK,"new_best":better and error==OK,"reason":message,"previous":previous.get("last",{}),"medal":0}

func _cleanup_ghosts() -> void:
 var keep: Array[String]=[]
 for archive: Variant in [data,RallyProfileStore.read_json(path+".bak")]:
  if not valid(archive): continue
  for kind: String in ["modified","tests"]:
   for entry: Dictionary in archive[kind].values():
    for result: Dictionary in [entry.best,entry.last]+entry.recent: keep.append(str(result.get("ghost","")))
 var directory:=path.get_base_dir()+"/garage_ghosts"
 var folder:=DirAccess.open(directory)
 if folder==null: return
 var owned:=RegEx.new()
 owned.compile("^[a-f0-9]{64}-[0-9]+[.]json$")
 for file: String in folder.get_files():
  if owned.search(file)!=null and file not in keep: DirAccess.remove_absolute(directory+"/"+file)
