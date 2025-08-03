# "res://Scripts/Autoload/RPC/aInventoryIface.gd"
extends Node

# signals
# enums
# constants
# @export variables
# public variables
var inventory_template: Dictionary = {  # slot_id: {"item_id": -1, "ref_id": -1, "qty": 0},
	 1: {"item_id": -1, "ref_id": -1, "qty": 0},  2: {"item_id": -1, "ref_id": -1, "qty": 0}, 
	 3: {"item_id": -1, "ref_id": -1, "qty": 0},  4: {"item_id": -1, "ref_id": -1, "qty": 0},
	 5: {"item_id": -1, "ref_id": -1, "qty": 0},  6: {"item_id": -1, "ref_id": -1, "qty": 0},
	 7: {"item_id": -1, "ref_id": -1, "qty": 0},  8: {"item_id": -1, "ref_id": -1, "qty": 0},
	 9: {"item_id": -1, "ref_id": -1, "qty": 0}, 10: {"item_id": -1, "ref_id": -1, "qty": 0},
	11: {"item_id": -1, "ref_id": -1, "qty": 0}, 12: {"item_id": -1, "ref_id": -1, "qty": 0},
	13: {"item_id": -1, "ref_id": -1, "qty": 0}, 14: {"item_id": -1, "ref_id": -1, "qty": 0},
	15: {"item_id": -1, "ref_id": -1, "qty": 0}, 16: {"item_id": -1, "ref_id": -1, "qty": 0},
} : set = _set_inventory_template, get = get_inventory_template
# friend variables
# private variables
# @onready variables

# optional built-in virtual _init method
# optional built-in virtual _enter_tree() method

# built-in virtual _ready method
#func _ready() -> void:
#	pass


# remaining built-in virtual methods
#func _process(p_delta: float) -> void:
#	pass


#func _physics_process(p_delta: float) -> void:
#	pass


# public methods
func get_inventory_template() -> Dictionary:
	return inventory_template.duplicate(true)


# friend methods
# private methods




func _set_inventory_template(_p: Dictionary) -> void:
	printerr("invalid setter called on InventoryIface.inventory_template")


# signal methods
# subclasses
