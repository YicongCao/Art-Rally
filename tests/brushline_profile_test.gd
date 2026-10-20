extends "res://tests/profile_ghost_test.gd"

func _run() -> void:
	var directory := "user://brushline-migration-%d"%Time.get_ticks_usec()
	var store := RallyProfileStore.new()
	store.path=directory+"/new/player/profile.json"
	check(store.stage_unlocked("sunset_ridge"),"New player can challenge Sunset")
	check(not store.stage_unlocked("sunlit_cape"),"New player's coast challenge is locked")
	check(store.stage_unlocked("misty_highlands",true),"Practice bypasses challenge locks")
	check(not store.stage_unlocked("unknown",true),"Unknown content cannot bypass locks")
	var coast := RallyContentCatalog.challenge("sunlit_cape","F160")
	check(not store.record(coast,result(),ghost(coast.key())).eligible,"Direct record cannot bypass a stage lock")
	var challenge := RallyContentCatalog.challenge("sunset_ridge","F160")
	var automated := result()
	automated.source="autopilot_vgamepad"
	check(not store.record(challenge,automated,ghost(challenge.key())).eligible,"Demo cannot unlock stages")
	check(not store.stage_unlocked("sunlit_cape"),"Rejected run leaves unlocks unchanged")
	check(store.record(challenge,result(),ghost(challenge.key())).saved,"Gold record commits successfully")
	check(store.stage_unlocked("sunlit_cape") and store.stage_unlocked("misty_highlands"),"Sunset gold unlocks both challenges")
	var reloaded := RallyProfileStore.new()
	reloaded.path=store.path
	reloaded.load_file()
	check(reloaded.stage_unlocked("misty_highlands"),"Stage unlock survives restart")
	var old := RallyProfileStore.fresh()
	old.erase("unlocked_stages")
	old.challenges[coast.key()]={"best":result(),"medal":1,"recent":[result()]}
	var legacy := directory+"/old"
	RallyProfileStore.atomic_json(legacy+"/player/profile.json",old,false)
	RallyProfileStore.atomic_json(legacy+"/player/gallery/index.json",{"photos":[]},false)
	var destination := directory+"/migrated"
	check(RallyBrandMigration.migrate(ProjectSettings.globalize_path(destination),ProjectSettings.globalize_path(legacy))==OK,"Brand migration succeeds with verified staging")
	check(FileAccess.file_exists(legacy+"/player/profile.json"),"Legacy profile is never removed")
	check(FileAccess.file_exists(destination+"/player/gallery/index.json"),"Gallery migrates with profile")
	reloaded.path=destination+"/player/profile.json"
	check(reloaded.load_file()==OK and reloaded.stage_unlocked("sunlit_cape"),"Existing played coast is grandfathered")
	check(not reloaded.stage_unlocked("misty_highlands"),"Unplayed legacy highland still needs gold")
	var hash_before := FileAccess.get_sha256(reloaded.path)
	check(RallyBrandMigration.migrate(ProjectSettings.globalize_path(destination),ProjectSettings.globalize_path(legacy))==OK and hash_before==FileAccess.get_sha256(reloaded.path),"Migration is idempotent and never overwrites new progress")
	check(RallyContentCatalog.stage("misty_highlands").stage_version=="8","Cliff change separates highland ghosts")
	check(RallyContentCatalog.stage("sunset_ridge").stage_version=="7","Unchanged road challenge keeps compatible records")
	var root_path := ProjectSettings.globalize_path(directory+"/default-roots")
	RallyProfileStore.atomic_json(root_path+"/Art Rally/player/profile.json",old,false)
	check(RallyBrandMigration.migrate(root_path+"/Brushline Rally")==OK and FileAccess.file_exists(root_path+"/Brushline Rally/player/profile.json"),"Default discovery reads the old Art Rally directory")
	var broken := directory+"/corrupt-old"
	RallyProfileStore.atomic_json(broken+"/player/profile.json",{"broken":true},false)
	check(RallyBrandMigration.migrate(ProjectSettings.globalize_path(directory+"/corrupt-new"),ProjectSettings.globalize_path(broken))==ERR_FILE_CORRUPT,"Corrupt legacy data is reported without deleting it")
	RallyProfileStore.atomic_json(broken+"/player/profile.json.bak",old,false)
	check(RallyBrandMigration.migrate(ProjectSettings.globalize_path(directory+"/backup-new"),ProjectSettings.globalize_path(broken))==OK,"Valid legacy backup recovers damaged primary during migration")
	var failed := RallyProfileStore.new()
	failed.path=directory+"/failure/profile.json"
	failed.read_only=true
	check(not failed.record(challenge,result(),ghost(challenge.key())).saved and not failed.stage_unlocked("sunlit_cape"),"Save failure cannot grant either track unlock")
	var mixed := result()
	mixed.source="mixed"
	check(not failed.record(challenge,mixed,ghost(challenge.key())).eligible,"Mixed takeover cannot unlock")
	mixed=result()
	mixed.practice=true
	check(not failed.record(challenge,mixed,ghost(challenge.key())).eligible,"Practice cannot unlock")
	finish()
