
# Tiny Tools
Currently In Early Development

![Static Badge](https://img.shields.io/badge/Godot-4.4-blue?style=flat)
[![GitHub License](https://img.shields.io/github/license/limbonaut/limbo_console)](https://github.com/limbonaut/limbo_console/blob/master/LICENSE.md)

---

# Overview

A simple and easy-to-use tool framework for Godot Engine 4.

Current Features:
- [Debug Bar](#debug-bar)
- [Config Mapper](#config-mapper)

Road Map:
- Save Manager
- Debug Framework
- Optimization Overlay
- Native Tiny Console Support
- Plugin Dependency Manager 

This plugin is currently in extremely early development, so expect breaking changes.

## How To Use

> 🛈 Tiny Tools can be added as a Git submodule

Place the source code in the `res://addons/tiny_tools/` directory, and enable this plugin in the project settings, then reload the project. 

Toggle the console with the `TAB` key. (Will eventually have interlocked functionality with Tiny Console, so that both appear and disappear with same key)

## Configuration
Config `.ini` Files are automatically generated in `res://addons/tt_configs/` directory. They are stored outside of the plugin's directory to support the plugin as a Git submodule.

---

# Debug Bar 
Adding a new debug bar items is quite simple:

```gdscript
# Direct Callable Declaration
func _ready() -> void:
    DebugBar.add_button("Button Example", Callable(self, "method"))
    DebugBar.add_toggle("Toggle Example", Callable(self, "toggle_method"))

# In Line Declaration
    DebugBar.add_button("Run", func(): print("Run"))

func method() -> void:
    print("Example Pressed")

func toggle_method(state: bool) -> void:
    print("Example State: " + state)
```

The example above shows the main ways of adding new items. Additionally, you can specify a category (which can also be nested):

Base Category
```gdscript
DebugBar.add_button("Run", func(): print("Run"), "Example")
```

Nested Category
```gdscript
DebugBar.add_button("Run", func(): print("Run"), "Example|Nested Example")
```

Additionally, you can declare categories to be sorted at specific spots. These slots will appear before any unsorted categories.
```gdscript
DebugBar.add_root_category("Example", 1)
```

### Methods and properties

Some notable methods and properties:

- DebugBar.enabled
- DebugBar.add_button(name, callback, category)
- DebugBar.add_toggle(name, bind, category)
- DebugBar.add_radio(name, group, bind, value, category)
- DebugBar.add_root_category(name, index)
- DebugBar.toggle_debug_bar

This is not a complete list. For the rest, check out `debug_bar.gd`.

### Keyboard Shortcuts
- `Tab` — Toggle debug bar.

