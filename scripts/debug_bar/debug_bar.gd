extends CanvasLayer

var _panel : PanelContainer
var _bar : HBoxContainer
var _items : Array[Dictionary] = []
var _top_buttons : Dictionary = {}

var _custom_category_order: Dictionary = {}
var _custom_category_list: Array[String] = []

const THEME_DEFAULT : Theme = preload("res://addons/tiny_tools/res/tools_theme.tres")

const ConfigMapper := preload("res://addons/tiny_tools/scripts/config_mapper.gd")
const DebugBarOptions = preload("res://addons/tiny_tools/scripts/debug_bar/debug_bar_options.gd")

var _options : DebugBarOptions
var is_dirty : bool = false

# === Open / Close Variables ===
var _is_open : bool = false
var _open_t : float = 0.0
var _open_speed : float = 5.0

var enabled : bool = true:
	set(value):
		enabled = value
		set_process_input(enabled)
		if not enabled and visible:
			_is_open = false
			set_process(false)
			hide()

#TODO: Swap For Config Theme
#TODO: Fix radios
#TODO: Improve performance, a lot to still be fixed
#TODO: Integrate with Tiny Console, possibly make TinyManager, that if detected, takes control over other plugins and sorts out dependency etc

#TODO: TinyManager: have it control plugin order (of defined plugins), check plugins if they have a tinymanager implementation, and the dependency chain
# Have TinyManager be a git submodule, that can drag in it's other submodules.

#TODO: Add console variable esc behaviour to tiny console, so that something like "exec='command'" or exec='godmode = true', 

####################
### --- INIT --- ###
####################

func _init() -> void:
	layer = 9999
	process_mode = ProcessMode.PROCESS_MODE_ALWAYS	
	
	_options = DebugBarOptions.new()
	ConfigMapper.load_and_save(_options)
	
	_build_gui()

func _ready() -> void:
	_demo()
	open_debug_bar()

func _build_gui() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0
	_panel.anchor_right = 1
	_panel.anchor_top = 0
	_panel.anchor_bottom = 0
	_panel.offset_bottom = 28
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.theme = THEME_DEFAULT
	add_child(_panel)

	_bar = HBoxContainer.new()
	_bar.name = "BarContainer"
	_bar.anchor_right = 1
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.theme = THEME_DEFAULT
	_panel.add_child(_bar)

##############################
### --- PUBLIC | USAGE --- ###
##############################

func add_button(name: String, callback: Callable, category: String = "") -> void:
	_items.append({ "type": "button", "name": name, "category": category, "callback": callback })
	is_dirty = true
	set_process(true)

## Returns a bool
func add_toggle(name: String, bind: Callable, category: String = "") -> void:
	_items.append({ "type": "toggle", "name": name, "category": category, "bind": bind })
	is_dirty = true
	set_process(true)

func add_radio(name: String, group: String, bind: Callable, value: Variant, category: String = "") -> void:
	_items.append({ "type": "radio", "name": name, "category": category, "group": group, "bind": bind, "value": value })
	is_dirty = true
	set_process(true)

## Not explicitly required, hard reserves category order. [br]
## Categories without items, will not appear
func add_root_category(name: String, index: int) -> void:
	_custom_category_order[name] = index
	
	# Properly rebuild _custom_category_list
	_custom_category_list = []
	for k in _custom_category_order.keys():
		_custom_category_list.append(k as String)

	_custom_category_list.sort_custom(func(a, b): return _custom_category_order[a] < _custom_category_order[b])
	is_dirty = true
	set_process(true)

##############################
### --- PUBLIC | USAGE --- ###
##############################

func open_debug_bar() -> void:
	if enabled:
		_is_open = true
		set_process(true)
		show()
		
func close_debug_bar() -> void:
	if enabled:
		_is_open = false
		set_process(true)

func toggle_debug_bar() -> void:
	if _is_open:
		close_debug_bar()
	else:
		open_debug_bar()

func is_visible() -> bool:
	return _is_open


#######################
### --- PRIVATE --- ###
#######################

func _rebuild() -> void:
	for child in _bar.get_children():
		_bar.remove_child(child)
		child.queue_free()
	
	_top_buttons.clear()

	var categorized: Dictionary = _categorize()

	# First, add manually specified categories (custom order)
	for category_name in _custom_category_list:
		if categorized.has(category_name):
			var mb: MenuButton = MenuButton.new()
			mb.text = category_name
			mb.size_flags_horizontal = Control.SIZE_FILL
			mb.theme = THEME_DEFAULT
			_bar.add_child(mb)

			var popup: PopupMenu = mb.get_popup()
			popup.theme = THEME_DEFAULT
			_top_buttons[category_name] = mb

			if categorized[category_name] is Dictionary:
				_build_submenu(popup, categorized[category_name], category_name, mb, true)
			else:
				push_warning("Top-level category '" + category_name + "' is not a Dictionary. Got: " + str(typeof(categorized[category_name])))

	# Then, add the remaining categories that weren't manually added
	for top_key in categorized.keys():
		if top_key == "_items" or _custom_category_order.has(top_key):
			continue

		var top: String = str(top_key)
		var mb: MenuButton = MenuButton.new()
		mb.text = top
		mb.size_flags_horizontal = Control.SIZE_FILL
		mb.theme = THEME_DEFAULT
		_bar.add_child(mb)

		var popup: PopupMenu = mb.get_popup()
		popup.theme = THEME_DEFAULT
		_top_buttons[top] = mb

		if categorized[top] is Dictionary:
			_build_submenu(popup, categorized[top], top, mb, true)
		else:
			push_warning("Top-level category '" + top + "' is not a Dictionary. Got: " + str(typeof(categorized[top])))

func _categorize() -> Dictionary:
	var root: Dictionary = {}
	for item: Dictionary in _items:
		var path: String = item.get("category", "")
		var parts: PackedStringArray = path.split("|") if path != "" else []
		var branch := root
		for i in range(parts.size()):
			var part: String = parts[i]
			if not (branch is Dictionary):
				push_warning("Invalid branch at part '" + part + "', replacing with Dictionary")
				branch = {}
				root[part] = branch
			elif not branch.has(part):
				branch[part] = {}
			branch = branch[part]
		if not (branch is Dictionary):
			branch = {}
		if not branch.has("_items"):
			branch["_items"] = []
		branch["_items"].append(item)
	return root

func _build_submenu(popup: PopupMenu, node: Dictionary, path: String, owner_mb: MenuButton, lazy: bool = false) -> void:
	print("[BUILD] Building submenu:", path)
	popup.theme = THEME_DEFAULT
	var id: int = 0

	if node.has("_items"):
		for item in node["_items"]:
			var label: String = item.get("name", "Unnamed")
			match item["type"]:
				"button":
					popup.add_item(label, id)
					popup.id_pressed.connect((func(pressed_id: int) -> void:
						if pressed_id == id:
							print("[CLICK] Button clicked:", label)
							item["callback"].call()
					))
				"toggle":
					var temp = item["bind"].call()
					var state: bool = temp if temp != null else false
					popup.add_check_item(label, id)
					popup.set_item_checked(id, state)
					popup.id_pressed.connect((func(pressed_id: int) -> void:
						if pressed_id == id:
							print("[CLICK] Toggle toggled:", label)
							var temp2 = item["bind"].call()
							var cur = temp2 if temp2 != null else false
							item["bind"].call(!cur)
							popup.set_item_checked(id, !cur)
					))
				"radio":
					var temp = item["bind"].call()
					var selected: bool = temp == item["value"] if temp != null else false
					popup.add_radio_check_item(label, id)
					popup.set_item_checked(id, selected)

					var group_key: String = item.get("group", "default")
					if not popup.has_meta("__radio_groups"):
						popup.set_meta("__radio_groups", {})
					var group_map: Dictionary = popup.get_meta("__radio_groups")
					if not group_map.has(group_key):
						group_map[group_key] = []
					group_map[group_key].append({"id": id, "value": item["value"], "bind": item["bind"]})

					popup.id_pressed.connect((func(pressed_id: int) -> void:
						if pressed_id == id:
							print("[CLICK] Radio selected:", label)
							item["bind"].call(item["value"])
							for entry in popup.get_meta("__radio_groups")[group_key]:
								popup.set_item_checked(entry["id"], entry["value"] == item["value"])
					))
			id += 1

	for sub in node.keys():
		if sub == "_items":
			continue

		var sub_path: String = path + "|" + sub
		var subpopup := PopupMenu.new()
		subpopup.name = "Submenu_" + sub_path.replace("|", "_")
		subpopup.theme = THEME_DEFAULT
		subpopup.hide_on_checkable_item_selection = false
		subpopup.hide_on_item_selection = false
		subpopup.hide_on_state_item_selection = false
		popup.add_submenu_node_item(sub, subpopup)
		if subpopup.get_parent() == null:
			owner_mb.add_child(subpopup)

		if lazy:
			subpopup.about_to_popup.connect((func():
				print("[EVENT] Opening submenu:", subpopup.name)
				if subpopup.get_item_count() == 0:
					print("[LAZY] Building lazy submenu:", sub_path)
					_build_submenu(subpopup, node[sub], sub_path, owner_mb, lazy)
			))
			
			subpopup.popup_hide.connect((func():
				print("[EVENT] Closing submenu:", subpopup.name)
				# Cleanup
				for child in subpopup.get_children():
					print("[CLEANUP] Freeing child node in", subpopup.name)
					child.queue_free()
				print("[CLEANUP] Clearing items from", subpopup.name)
				subpopup.clear()
			))
		else:
			print("[EAGER] Building eager submenu:", sub_path)
			_build_submenu(subpopup, node[sub], sub_path, owner_mb, lazy)

func _process(delta: float) -> void:
	if is_dirty:
		call_deferred("_rebuild")
		is_dirty = false
	
	var done_sliding := false
	if _is_open:
		_open_t = move_toward(_open_t, 1.0, _options.animation_speed * delta * 1.0 / Engine.time_scale)
		if _open_t == 1.0:
			done_sliding = true
	else: # We close faster than opening.
		_open_t = move_toward(_open_t, 0.0, _options.animation_speed * delta * 1.5 * 1.0 / Engine.time_scale)
		if is_zero_approx(_open_t):
			done_sliding = true

	var eased := ease(_open_t, -1.75)
	var new_y := remap(eased, 0, 1, -_panel.size.y, 0)
	_panel.position.y = new_y

	if done_sliding:
		set_process(false)
		if not _is_open:
			hide()

func _input(p_event: InputEvent) -> void:
	if p_event is InputEventKey:
		if p_event.keycode == KEY_TAB and p_event.is_pressed():
			toggle_debug_bar()

#################################
### --- PRIVATE | UTILITY --- ###
#################################

func _demo() -> void:
	var enabled := false
	var mode := "A"
	var volume := "Medium"
	var fullscreen := false

	add_root_category("File", 1)
	add_root_category("Settings", 2)
	add_root_category("Debug", 3)
	add_root_category("Tools", 4)

	add_button("Run", func(): print("Run"), "Debug")

	# File Menu
	add_button("Run", func(): print("Run"), "File")
	add_toggle("Debug", func(val = null):
		if val == null: return enabled
		enabled = val
		print("Debug enabled:", enabled), "File")
	add_button("Reload", func(): print("Reloaded"), "File|Operations")
	add_button("Export", func(): print("Exported"), "File|Operations")

	# Settings - Display
	add_toggle("Fullscreen", func(val = null):
		if val == null: return fullscreen
		fullscreen = val
		print("Fullscreen:", fullscreen), "Settings|Display")

	# Settings - Audio - Volume Radio
	add_radio("Low", "volume", func(val = null):
		if val == null: return volume
		volume = val
		print("Volume set to:", volume), "Settings|Audio|Volume")

	add_radio("Medium", "volume", func(val = null):
		if val == null: return volume
		volume = val
		print("Volume set to:", volume), "Settings|Audio|Volume")

	add_radio("High", "volume", func(val = null):
		if val == null: return volume
		volume = val
		print("Volume set to:", volume), "Settings|Audio|Volume")

	# Settings - Mode Radio
	add_radio("A", "mode", func(val = null):
		if val == null: return mode
		mode = val
		print("Mode set to:", mode), "Settings|Mode")

	add_radio("B", "mode", func(val = null):
		if val == null: return mode
		mode = val
		print("Mode set to:", mode), "Settings|Mode")

	# Deep nesting
	add_button("Rebuild Shaders", func(): print("Rebuilding..."), "Settings|Advanced|Graphics|Shaders")
	add_toggle("Enable HDR", func(val = null): print("HDR toggled"), "Settings|Advanced|Graphics|PostFX")
	add_button("Reset Camera", func(): print("Camera reset"), "Tools|Camera|Actions")
	add_button("Reset Position", func(): print("Position reset"), "Tools|Camera|Actions")
	add_toggle("Enable Mouse Lock", func(val = null): return false, "Tools|Camera|Input")
	add_button("Spawn Test Entity", func(): print("Entity spawned"), "Tools|Entities|Test")
	add_button("Clear Logs", func(): print("Logs cleared"), "Tools|Logs")
