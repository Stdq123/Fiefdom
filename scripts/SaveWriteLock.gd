extends RefCounted

const LOCK_DIR := "user://.save-write"
const OWNER_FILE := "owner"

var _owner: FileAccess

func acquire() -> Error:
	var cleared := _remove_inactive_lock(LOCK_DIR)
	if cleared != OK:
		return cleared
	var token := str(OS.get_process_id())
	var stage := "%s.%s" % [LOCK_DIR, token]
	cleared = _remove_inactive_lock(stage)
	if cleared != OK:
		return cleared
	var result := DirAccess.make_dir_absolute(stage)
	if result != OK:
		return result
	result = _place_lock(stage, token)
	if result != OK:
		_remove_inactive_lock(stage)
		return result

	# An open Windows file handle keeps the owner file from being removed.
	# Recheck the token in case another writer cleared it before we opened it.
	_owner = FileAccess.open(LOCK_DIR.path_join(OWNER_FILE), FileAccess.READ)
	if _owner == null or _owner.get_as_text() != token:
		if _owner:
			release()
		return ERR_BUSY
	return OK

func release() -> void:
	_owner.close()
	_owner = null

func _place_lock(stage: String, token: String) -> Error:
	var file := FileAccess.open(stage.path_join(OWNER_FILE), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var written := file.store_string(token)
	file.close()
	if not written:
		return ERR_FILE_CANT_WRITE
	# The destination is a directory. Windows cannot replace another published lock.
	return OK if DirAccess.rename_absolute(stage, LOCK_DIR) == OK else ERR_BUSY

func _remove_inactive_lock(directory: String) -> Error:
	if not DirAccess.dir_exists_absolute(directory):
		return OK
	var marker := directory.path_join(OWNER_FILE)
	if FileAccess.file_exists(marker) and DirAccess.remove_absolute(marker) != OK:
		return ERR_BUSY
	if DirAccess.remove_absolute(directory) != OK and DirAccess.dir_exists_absolute(directory):
		return ERR_BUSY
	return OK
