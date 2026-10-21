extends "res://tests/test_suite.gd"
func _run() -> void:
 var store:=RallyGarageStore.new()
 store.path="user://garage-test-%d/garage.json"%Time.get_ticks_usec()
 check(store.load_file()==OK,"Empty additive archive initializes")
 var car:=RallyContentCatalog.vehicle("P7")
 var setup:=RallyGarageCatalog.stock(car)
 check(store.save_slot("P7",0,setup)==OK,"Save custom slot atomically")
 setup.tune.height=30
 check(store.save_slot("P7",1,setup)==OK,"Three slots keep independent snapshots")
 check(store.slots("P7")[0].tune.height==0,"Saved stock snapshot not mutated")
 var restored:=RallyGarageStore.new()
 restored.path=store.path
 check(restored.load_file()==OK and restored.slots("P7")[1].tune.height==30,"Slot persistence round trip")
 FileAccess.open(store.path,FileAccess.WRITE).store_string("broken")
 check(restored.load_file()==OK and restored.from_backup,"Corrupt primary recovers backup")
 check(restored.save_slot("P7",2,setup)==OK,"Recovered archive saves without replacing valid backup")
 var fingerprint:=RallyGarageCatalog.fingerprint(setup)
 setup.name="重命名"
 check(fingerprint==RallyGarageCatalog.fingerprint(setup),"Cosmetic slot name excluded from config identity")
 setup.tune.lock=0
 check(fingerprint!=RallyGarageCatalog.fingerprint(setup),"Mechanical change changes ghost identity")
 var tuned:=RallyGarageCatalog.resolve(car,setup)
 check(tuned.drivetrain_config().diff_lock_gain==0,"Open diff removes added locking")
 setup.tune.lock=100
 check(RallyGarageCatalog.resolve(car,setup).drivetrain_config().diff_lock_gain>car.drivetrain_config().diff_lock_gain,"Strong lock increases coupling")
 setup.tune.compression=.7
 setup.tune.rebound=1.4
 var physics:=RallyGarageCatalog.resolve(car,setup).physics_config()
 check(physics.compression_damping<car.physics_config().compression_damping and physics.rebound_damping>car.physics_config().rebound_damping,"Compression and rebound independent")
 var previous:=store.data.duplicate(true)
 store.path="res://project.godot/invalid.json"
 check(store.save_slot("P7",2,setup)!=OK and store.data==previous,"Failed write preserves archive in memory")
 setup.tune.height=NAN
 check(not RallyGarageCatalog.valid(setup,car),"Nonfinite tuning rejected")
 setup=RallyGarageCatalog.stock(car)
 setup.parts.tires="sand"
 var sand:=RallyGarageCatalog.resolve(car,setup).tire_config()
 check(sand.grip_factor(4)>1 and sand.grip_factor(0)<1,"Sand tire trades asphalt grip for sand traction")
 setup=RallyGarageCatalog.stock(car)
 setup.tune.height=-30
 check(not RallyGarageCatalog.valid(setup,car),"EV chassis rejects excessive lowering")
 RallyGarageCatalog.fit_ranges(car,setup)
 check(setup.tune.height==-15 and RallyGarageCatalog.valid(setup,car),"EV chassis range clamps safely")
 setup.tune.height=40
 setup.tune.compression=.7
 setup.parts.suspension="road"
 check(not RallyGarageCatalog.valid(setup,car),"Road kit rejects incompatible height and damping")
 RallyGarageCatalog.fit_ranges(car,setup)
 check(setup.tune.height==15 and setup.tune.compression==.85 and RallyGarageCatalog.valid(setup,car),"Part switch fits draft to new limits")
 setup.tune.final_drive=1.15
 check(not RallyGarageCatalog.valid(setup,car),"Single-speed motor gearing has chassis limit")
 var legacy:=RallyProfileStore.fresh()
 check(RallyProfileStore.valid(legacy),"Legacy profile with no garage fields remains valid")
 finish()
