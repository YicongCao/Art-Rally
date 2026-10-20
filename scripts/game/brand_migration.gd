class_name RallyBrandMigration
extends RefCounted

# Copy into a staging directory first. Never move or alter the legacy profile.
static func migrate(destination: String = "", legacy: String = "") -> Error:
	if destination.is_empty(): destination = OS.get_user_data_dir()
	if legacy.is_empty(): legacy = destination.get_base_dir().path_join("Art Rally")
	if FileAccess.file_exists(destination.path_join("brand-migration.json")): return OK
	if FileAccess.file_exists(destination.path_join("player/profile.json")) or FileAccess.file_exists(destination.path_join("player/profile.json.bak")): return OK
	if not DirAccess.dir_exists_absolute(legacy): return OK
	var profile: Variant = RallyProfileStore.read_json(legacy.path_join("player/profile.json"))
	if not RallyProfileStore.valid(profile):
		profile = RallyProfileStore.read_json(legacy.path_join("player/profile.json.bak"))
	if not RallyProfileStore.valid(profile):
		if DirAccess.dir_exists_absolute(legacy.path_join("player")): return ERR_FILE_CORRUPT
		return OK
	var staging := destination.path_join("migration-staging")
	var err := _copy_tree(legacy.path_join("player"), staging.path_join("player"))
	if err != OK: return err
	# A valid backup may be the only usable legacy profile.
	err = RallyProfileStore.atomic_json(staging.path_join("player/profile.json"), profile, false)
	if err != OK: return err
	if not RallyProfileStore.valid(RallyProfileStore.read_json(staging.path_join("player/profile.json"))): return ERR_FILE_CORRUPT
	for filename: String in ["driving_settings.cfg", "stage_results.cfg"]:
		var source := legacy.path_join(filename)
		if FileAccess.file_exists(source) and not FileAccess.file_exists(destination.path_join(filename)):
			err = DirAccess.copy_absolute(source,destination.path_join(filename))
			if err != OK: return err
	if DirAccess.dir_exists_absolute(destination.path_join("player")): return ERR_ALREADY_EXISTS
	err = DirAccess.rename_absolute(staging.path_join("player"),destination.path_join("player"))
	if err != OK: return err
	return RallyProfileStore.atomic_json(destination.path_join("brand-migration.json"),{"source":legacy,"completed":true},false)

static func _copy_tree(source: String, destination: String) -> Error:
	var dir := DirAccess.open(source)
	if dir == null: return ERR_CANT_OPEN
	var err := DirAccess.make_dir_recursive_absolute(destination)
	if err != OK: return err
	for entry: String in dir.get_directories():
		if dir.is_link(source.path_join(entry)): return ERR_INVALID_DATA
		err = _copy_tree(source.path_join(entry),destination.path_join(entry))
		if err != OK: return err
	for entry: String in dir.get_files():
		var src := source.path_join(entry)
		var dst := destination.path_join(entry)
		if dir.is_link(src): return ERR_INVALID_DATA
		err = DirAccess.copy_absolute(src,dst)
		if err != OK: return err
		if FileAccess.get_sha256(src) != FileAccess.get_sha256(dst): return ERR_FILE_CORRUPT
	return OK
