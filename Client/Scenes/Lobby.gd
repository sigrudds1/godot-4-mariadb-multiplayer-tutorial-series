extends Control

signal sPlyrMsgLineSelected

const kMaxMessages: int = 100

var _msg_line_scn: PackedScene = preload("res://Scenes/MessageLine.tscn")
var _blocked_plyr_line_scn: PackedScene = preload("res://Scenes/BlockledPlyrLine.tscn")

var _option_menu_open: bool = false

@onready var _messages_scroll: ScrollContainer = %Messages_scroll
@onready var _messages_box: VBoxContainer = %Messages_vbc
@onready var _msg_line: LineEdit = %LineEdit
@onready var _block_report_plyr_name_label: Label = %BlockReportPlayerName_label
@onready var _block_report_plyr_panel: PanelContainer = %BlockReportPlyr_panel
@onready var _blocked_plyr_list_panel: PanelContainer = %BlockedPlayerList_panel
@onready var _blocked_plyr_box: VBoxContainer = %BlockedPlyr_box


func _ready() -> void:
	if MessagingIface.sMsgRcvd.connect(_on_msg_rcvd):
		pass
	if sPlyrMsgLineSelected.connect(_on_plyr_msg_line_selected):
		pass
	_block_report_plyr_panel.visible = false
 

func _on_add_blocked_plyr_btn_pressed() -> void:
	if MessagingIface.msg_blocked_player_list.find(_block_report_plyr_name_label.text) == -1:
		MessagingIface.msg_blocked_player_list.push_back(_block_report_plyr_name_label.text)
		MessagingIface.client_block_player.rpc_id(1, _block_report_plyr_name_label.text, true)
	_block_report_plyr_panel.visible = false
	var msgs_children: Array = _messages_box.get_children()
	for child:Node in msgs_children:
		if child is MessageLine:
			var msg_line:MessageLine = child
			if msg_line.plyr_name == _block_report_plyr_name_label.text:
				msg_line.queue_free()
		else:
			child.queue_free()


func _on_block_report_plyr_close_tbtn_pressed() -> void:
	_block_report_plyr_panel.visible = false


func _on_blocked_player_list_close_tbtn_pressed() -> void:
	_blocked_plyr_list_panel.visible = false
	_option_menu_open = false


func _on_line_edit_text_submitted(p_new_text: String) -> void:
	if p_new_text == "":
		return
	MessagingIface.client_sent_msg.rpc_id(1, p_new_text)
	_msg_line.text = ""


func _on_msg_rcvd(p_from_plyr_display_name: String, p_msg: String) -> void:
	var plyr_msg_line: MessageLine = _msg_line_scn.instantiate()
	plyr_msg_line.plyr_name = p_from_plyr_display_name
	plyr_msg_line.msg_text = p_msg
	plyr_msg_line.plyr_name_pressed_func = _on_plyr_msg_line_selected
	_messages_box.add_child(plyr_msg_line)
	var excess_msg: int = _messages_box.get_child_count() - kMaxMessages
	for i:int in excess_msg:
		var child: MessageLine = _messages_box.get_child(i)
		child.queue_free()


func _on_options_btn_pressed() -> void:
	_block_report_plyr_panel.visible = false
	
	if _blocked_plyr_list_panel.visible == true:
		_blocked_plyr_list_panel.visible = false
		_option_menu_open = false
	else:
		_update_blocked_plyr_list()
		_blocked_plyr_list_panel.visible = true
		_option_menu_open = true
	

func _on_plyr_msg_line_selected(p_player_name: String) -> void:
	if _option_menu_open:
		return
	_block_report_plyr_name_label.text = p_player_name
	_block_report_plyr_panel.visible = true


func _on_quit_btn_pressed() -> void:
	get_tree().quit()


func _on_remove_blocked_plyr(p_player_name: String) -> void:
	MessagingIface.client_block_player.rpc_id(1, p_player_name, false)
	var idx: int = MessagingIface.msg_blocked_player_list.find(p_player_name)
	if idx > -1:
		MessagingIface.msg_blocked_player_list.remove_at(idx)
	_update_blocked_plyr_list()
	


func _on_report_plyr_btn_pressed() -> void:
	MessagingIface.client_report_player.rpc_id(1, _block_report_plyr_name_label)
	_block_report_plyr_panel.visible = false


func _on_send_msg_btn_pressed() -> void:
	if _msg_line.text == "":
		return
	MessagingIface.client_sent_msg.rpc_id(1, _msg_line.text)
	_msg_line.text = ""


func _update_blocked_plyr_list() -> void:
	_blocked_plyr_list_panel.custom_minimum_size.y = 0.0
	_blocked_plyr_list_panel.size.y = 0.0
	var children: Array[Node] = _blocked_plyr_box.get_children()
	for child:Node in children:
		child.queue_free()
	while _blocked_plyr_box.get_child_count() > 0:
		await get_tree().physics_frame
		
	var needed_height: float = _blocked_plyr_list_panel.size.y
	
	for plyr_name:String in MessagingIface.msg_blocked_player_list:
		if plyr_name == "":
			continue
		var blocked_plyr_line: BlockedPlyrLine = _blocked_plyr_line_scn.instantiate()
		blocked_plyr_line.remove_btn_func = _on_remove_blocked_plyr
		blocked_plyr_line.plyr_name = plyr_name
		_blocked_plyr_box.add_child(blocked_plyr_line)
		needed_height += blocked_plyr_line.size.y
	
	if needed_height > _messages_scroll.size.y:
		needed_height = _messages_scroll.size.y
	
	_blocked_plyr_list_panel.custom_minimum_size.y = needed_height
