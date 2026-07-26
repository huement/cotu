# res://Scripts/Utilities/RosterSaveSystem.gd
extends Node
class_name RosterSaveSystem

const POOL_DIR: String = "user://character_pool/"

## Commits a space cat character resource persistently to device local storage
static func save_character_to_pool(character: CatCharacter) -> Error:
	# Ensure folder system directory layout exists on host platform filesystems
	if not DirAccess.dir_exists_absolute(POOL_DIR):
		DirAccess.make_dir_absolute(POOL_DIR)
		
	# Sanitize naming inputs to filter unsafe string characters out of filesystems
	var safe_filename: String = character.name.validate_filename()
	var final_save_path: String = POOL_DIR + safe_filename + ".tres"
	
	var error_code := ResourceSaver.save(character, final_save_path)
	if error_code != OK:
		printerr("Save System Failure: Failed to write data file! Code: ", error_code)
	else:
		print("Save System Success: '", character.name, "' written to path: ", final_save_path)
		
	return error_code

## Discovers and deserializes all custom characters currently stored inside the directory pool
static func load_all_characters_from_pool() -> Array[CatCharacter]:
	var character_pool: Array[CatCharacter] = []
	
	if not DirAccess.dir_exists_absolute(POOL_DIR):
		return character_pool # Returns empty list if no files have been created yet
		
	var dir := DirAccess.open(POOL_DIR)
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var file_path: String = POOL_DIR + file_name
			var char_res := ResourceLoader.load(file_path) as CatCharacter
			if char_res:
				character_pool.append(char_res)
		file_name = dir.get_next()
		
	print("Save System Loaded: Discovered ", character_pool.size(), " characters inside persistent pool.")
	return character_pool
