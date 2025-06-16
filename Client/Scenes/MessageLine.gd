class_name MessageLine extends PanelContainer

var msg_text: String
var plyr_name: String
var plyr_name_pressed_func: Callable

@onready var _plyr_name_btn: Button = %PlyrName_btn
@onready var _msg_rtl: RichTextLabel = %Message_rtl


func _ready() -> void:
	_plyr_name_btn.text = plyr_name
	_msg_rtl.text = msg_text
	
	
func _set_msg_text(p_text: String) -> void:
	_msg_rtl.text = p_text


func _on_plyr_name_btn_pressed() -> void:
	if plyr_name == ConnectionIface.display_name:
		return
	# TODO - Create block/report popup
	if plyr_name_pressed_func.is_valid():
		plyr_name_pressed_func.call(plyr_name)
	
	
