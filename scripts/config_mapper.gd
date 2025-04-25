@tool
extends RefCounted
## Store object properties in a true INI-style configuration file (manually written).

const CONFIG_PATH_PROPERTY := &"CONFIG_PATH"
const MAIN_SECTION_PROPERTY := &"MAIN_SECTION"
const MAIN_SECTION_DEFAULT := "main"

enum VerboseLevel {
	NONE,
	INFO,
	ALL
}

static var verbose_level: VerboseLevel = VerboseLevel.INFO
static var write_comments: bool = true ## Set to false if you don't want comments

static func _get_config_file(p_object: Object) -> String:
	var from_object_constant = p_object.get(CONFIG_PATH_PROPERTY)
	return from_object_constant if from_object_constant is String else ""

static func _get_main_section(p_object: Object) -> String:
	var from_object_constant = p_object.get(MAIN_SECTION_PROPERTY)
	return from_object_constant if from_object_constant != null else MAIN_SECTION_DEFAULT

static func _msg_info(p_text: String) -> void:
	if verbose_level >= VerboseLevel.INFO:
		print(p_text)

static func _msg_all(p_text: String) -> void:
	if verbose_level >= VerboseLevel.ALL:
		print(p_text)

######################
### --- PUBLIC --- ###
######################

## Load object properties from ini file and return status.
static func load_from_ini(p_object: Object, p_ini_path: String = "") -> int:
	var ini_path := p_ini_path
	if ini_path.is_empty():
		ini_path = _get_config_file(p_object)
	if ini_path.is_empty():
		printerr("Config Mapper: No config path provided and none defined in object.")
		return ERR_INVALID_PARAMETER

	_msg_info("Config Mapper: Loading from: " + ini_path)

	var file := FileAccess.open(ini_path, FileAccess.READ)
	if file == null:
		printerr("Config Mapper: Failed to open file: ", ini_path)
		return ERR_CANT_OPEN

	var section := _get_main_section(p_object)
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("#") or line.is_empty():
			continue
		if line.begins_with("[") and line.ends_with("]"):
			section = line.substr(1, line.length() - 2)
		else:
			var parts := line.split("=", false, 2)
			if parts.size() == 2:
				var key := parts[0].strip_edges()
				var value_str := parts[1].strip_edges()
				for prop_info in p_object.get_property_list():
					if prop_info.name == key and prop_info.usage & PROPERTY_USAGE_STORAGE:
						var typed_value = _parse_value(value_str, prop_info.type)
						_msg_all("Config Mapper: Loaded setting: %s (section: %s) = %s" % [key, section, typed_value])
						p_object.set(key, typed_value)
	file.close()
	return OK

## Save object properties to ini file and return status.
static func save_to_ini(p_object: Object, p_ini_path: String = "") -> int:
	var ini_path := p_ini_path
	if ini_path.is_empty():
		ini_path = _get_config_file(p_object)
	if ini_path.is_empty():
		printerr("Config Mapper: No config path provided and none defined in object.")
		return ERR_INVALID_PARAMETER

	# Ensure directory exists
	var dir := ini_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var err := DirAccess.make_dir_recursive_absolute(dir)
		if err != OK:
			printerr("Config Mapper: Failed to create directory: ", dir)
			return err

	_msg_info("Config Mapper: Saving to: " + ini_path)

	var file := FileAccess.open(ini_path, FileAccess.WRITE)
	if file == null:
		printerr("Config Mapper: Failed to open file for writing: ", ini_path)
		return ERR_CANT_OPEN

	var current_section := ""
	var section_started := false

	for prop_info in p_object.get_property_list():
		if prop_info.usage & PROPERTY_USAGE_CATEGORY and prop_info.hint_string.is_empty():
			current_section = prop_info.name
			if section_started:
				file.store_line("") # Empty line before new section
			file.store_line("[" + current_section + "]")
			if write_comments:
				file.store_line("# Category: " + current_section)
			section_started = true
		elif prop_info.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop_info.usage & PROPERTY_USAGE_STORAGE:
			# If not in any section yet, use first property to start main section (optional)
			if not section_started:
				current_section = _get_main_section(p_object)
				file.store_line("[" + current_section + "]")
				if write_comments:
					file.store_line("# Category: " + current_section)
				section_started = true

			var value = p_object.get(prop_info.name)
			if write_comments:
				var comment_line: String = "# " + prop_info.name + " (" + type_string(typeof(value)) + ")"
				if prop_info.hint_string.strip_edges() != "":
					comment_line += ": " + prop_info.hint_string.strip_edges()
				file.store_line(comment_line)
			file.store_line("%s=%s" % [prop_info.name, _serialize_value(value)])
			_msg_all("Config Mapper: Saved setting: %s (section: %s) = %s" % [prop_info.name, current_section, value])

	file.close()
	return OK

static func load_and_save(p_object: Object) -> void:
	load_from_ini(p_object)
	save_to_ini(p_object)

#######################
### --- PRIVATE --- ###
#######################

static func _parse_value(value_str: String, type_id: int) -> Variant:
	match type_id:
		TYPE_BOOL:
			return value_str.to_lower() == "true" or value_str == "1"
		TYPE_INT:
			return int(value_str)
		TYPE_FLOAT:
			return float(value_str)
		TYPE_STRING:
			return value_str
		_:
			return value_str

static func _serialize_value(value: Variant) -> String:
	match typeof(value):
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_INT, TYPE_FLOAT:
			return str(value)
		TYPE_STRING:
			return value
		_:
			return str(value)
