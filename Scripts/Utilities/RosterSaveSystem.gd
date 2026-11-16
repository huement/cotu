# res://Scripts/Utilities/RosterSaveSystem.gd
extends Node
class_name RosterSaveSystem
## Old entry point, kept for compatibility. Use CharacterRoster (Scripts/Progression/CharacterRoster.gd).

const POOL_DIR: String = CharacterRoster.DEFAULT_DIR


static func save_character_to_pool(character: CatCharacter) -> Error:
	return CharacterRoster.save(character)


static func load_all_characters_from_pool() -> Array[CatCharacter]:
	return CharacterRoster.list()
