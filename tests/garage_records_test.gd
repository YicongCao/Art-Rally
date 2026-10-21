extends "res://tests/profile_ghost_test.gd"
func _run() -> void:
 var fixed:=RallyProfileStore.new()
 fixed.path="user://garage-records-%d/profile.json"%Time.get_ticks_usec()
 var store:=RallyGarageStore.new()
 store.path=fixed.path.get_base_dir()+"/garage.json"
 var challenge:=RallyContentCatalog.challenge("redrock_canyon","P7")
 var setup:=RallyGarageCatalog.stock(challenge.vehicle)
 challenge.vehicle=RallyGarageCatalog.resolve(challenge.vehicle,setup)
 var key:=RallyGarageStore.key(challenge)
 var outcome:=store.record(challenge,result(100),ghost(key,100),false)
 check(outcome.saved and outcome.new_best,"Modified record and annotated ghost commit together")
 check(fixed.data.challenges.is_empty() and fixed.unlocked_power_tier()==0,"Modified time awards no fixed score or unlock")
 var loaded:=store.load_ghost(challenge,false)
 check(loaded.get("fingerprint")==RallyGarageCatalog.fingerprint(setup),"Ghost carries complete setup identity")
 check(loaded.get("vehicle")=="P7" and loaded.get("stage")=="redrock_canyon" and loaded.get("physics")=="exp1","Ghost pins vehicle stage and physics version")
 setup.tune.height=20
 challenge.vehicle=RallyGarageCatalog.resolve(RallyContentCatalog.vehicle("P7"),setup)
 outcome=store.record(challenge,result(105),ghost(key,105),false)
 check(outcome.saved and not outcome.new_best,"Slower alternate setup keeps previous best")
 check(store.bucket(challenge,false).last.setup.tune.height==20 and store.bucket(challenge,false).best.setup.tune.height==0,"Recent and best retain distinct configuration snapshots")
 var test_outcome:=store.record(challenge,result(98),ghost(key,98),true)
 check(test_outcome.saved and store.bucket(challenge,false).best.total_time==100,"Trial results isolated from modified time trial")
 var ai:=result(); ai.source="autopilot_vgamepad"
 check(not store.record(challenge,ai,ghost(key),false).saved,"AI trajectories cannot enter modified records")
 var before:=store.data.duplicate(true)
 store.path="res://project.godot/garage.json"
 check(not store.record(challenge,result(90),ghost(key,90),false).saved and store.data==before,"Failed modified save preserves all earlier results")
 var old:=RallyProfileStore.new()
 old.data.challenges["sunset_ridge@7|F160@fp5|time-trial-4"]={"best":result(),"medal":3,"recent":[result()]}
 old._migrate_stage_access()
 check(old.stage_unlocked("redrock_canyon"),"Existing qualifying Sunset gold unlocks new stage")
 finish()
