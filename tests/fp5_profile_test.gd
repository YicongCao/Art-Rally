extends "res://tests/profile_ghost_test.gd"
func _run() -> void:
	var store := RallyProfileStore.new()
	store.path="user://fp5-compat-%d/profile.json"%Time.get_ticks_usec()
	store.data=RallyProfileStore.fresh()
	store.data.unlocked_power_tier=2
	store.data.unlocked_stages=RallyContentCatalog.STAGES.duplicate()
	store.data.settings={"abs":false,"tc":"off","esp":"full"}
	for stage: String in RallyContentCatalog.STAGES:
		for id: String in RallyContentCatalog.VEHICLES:
			for tier: int in range(3):
				var current := RallyContentCatalog.challenge(stage,id,tier)
				var old_key := current.key().replace("fp5","fp4" if id=="F160" else "fp3")
				store.data.challenges[old_key]={"best":result(),"medal":3,"recent":[result()],"ghost":"old-ghost.json"}
				check(store.result_for(current.key()).is_empty(),"New calibration cannot read old best or ghost: "+current.key())
	check(store.save_file()==OK,"Old archive and existing unlocks save together")
	var restored := RallyProfileStore.new();restored.path=store.path
	check(restored.load_file()==OK and restored.data.challenges.size()==27,"All old scores remain intact after reload")
	check(restored.unlocked_power_tier()==2 and restored.stage_unlocked("sunlit_cape") and restored.stage_unlocked("misty_highlands"),"Prior track and power unlocks survive the calibration change")
	check(not restored.data.settings.abs and restored.data.settings.tc=="off" and restored.data.settings.esp=="full","Aid preferences persist with the profile")
	finish()
