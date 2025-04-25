extends RefCounted

const CONFIG_PATH = "res://addons/tt_configs/debug_bar_options.ini"

@export_category("Toggles")
@export var disable_in_release : bool = true #TODO: needs to be implemented
@export var pause_when_open: bool = true #TODO: needs to be implemented

@export_category("Visuals")
@export var animation_speed : float = 5.0
@export var opacity : float = 1.0 #TODO: needs to be implemented

#TODO: add custom theme
