class_name BlockedPlyrLine extends HBoxContainer

var remove_btn_func: Callable
var plyr_name: String

@onready var _plyr_name_label: Label = %PlyrName_label


func _ready() -> void:
	_plyr_name_label.text = plyr_name


func _on_remove_btn_pressed() -> void:
	if remove_btn_func.is_valid():
		remove_btn_func.call(plyr_name)
	self.queue_free()
