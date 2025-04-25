@tool
extends EditorPlugin

const DebugBarOptions = preload("res://addons/tiny_tools/scripts/debug_bar/debug_bar_options.gd")
const ConfigMapper := preload("res://addons/tiny_tools/scripts/config_mapper.gd")

func _enter_tree() -> void:
	var debug_bar_options = DebugBarOptions.new()
	ConfigMapper.load_and_save(debug_bar_options)
	
	addSingletons()
	print("Tiny Tools: Plugin Loaded")

func _exit_tree() -> void:
	removeSingletons()
	print("Tiny Tools Plugin: Unloaded")

var autoLoads = {
	"DebugBar" : "res://addons/tiny_tools/scripts/debug_bar/debug_bar.gd",
	"SaveManager" : "res://addons/tiny_tools/scripts/save_manager.gd"
	}

func addSingletons():
	for key in autoLoads.keys():
		var setting_path : String = "autoload/" + key
		if not ProjectSettings.has_setting(setting_path):
			add_autoload_singleton(key, autoLoads[key])
			print("Added " + key + " from " + autoLoads[key])

func removeSingletons():
	for key in autoLoads.keys():
		var setting_path : String = "autoload/" + key
		if ProjectSettings.has_setting(setting_path):
			remove_autoload_singleton(key)
			print("Removed " + key)

func _forward_3d_draw_over_viewport(overlay):
	# Draw a circle at cursor position.
	overlay.draw_circle(overlay.get_local_mouse_position(), 64, Color.WHITE)
