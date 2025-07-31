extends Control

signal sPlyrMsgLineSelected

enum MenuWindow {
	NONE,
	REPORT_PLYR,
	INVENTORY,
	CRAFT,
	MATCH,
	AWAIT_MATCH,
	OPTIONS
}

const kMaxMessages: int = 100

var _msg_line_scn: PackedScene = preload("res://Scenes/MessageLine.tscn")
var _blocked_plyr_line_scn: PackedScene = preload("res://Scenes/BlockledPlyrLine.tscn")

@onready var _messages_scroll: ScrollContainer = %Messages_scroll
@onready var _messages_box: VBoxContainer = %Messages_vbc
@onready var _msg_line: LineEdit = %LineEdit

@onready var _report_plyr_panel: PanelContainer = %ReportPlyr_panel
@onready var _report_plyr_name_lbl: Label = %ReportPlayerName_label

@onready var _match_panel: PanelContainer = %Match_panel
@onready var _side_tanks_chkbx: CheckBox = %SideTanks_CheckBox
@onready var _side_any_chkbx: CheckBox = %SideAny_CheckBox
@onready var _side_towers_chkbx: CheckBox = %SideTowers_CheckBox
@onready var _side_pref_tanks_chkbx: CheckBox = %SidePrefTanks_CheckBox
@onready var _side_pref_towers_chkbx: CheckBox = %SidePrefTowers_CheckBox

@onready var _match_type_pve_chkbx: CheckBox = %MatchTypePVE_CheckBox
@onready var _match_type_try_pvp_chkbx: CheckBox = %MatchTypeTryPVP_CheckBox
@onready var _match_type_pvp_chkbx: CheckBox = %MatchTypePVP_CheckBox

@onready var _await_match_panel: PanelContainer = %AwaitMatch_panel


@onready var _options_panel: PanelContainer = %Options_panel
@onready var _blocked_plyr_box: VBoxContainer = %Options_BlockedPlyr_box



func _ready() -> void:
	if MessagingIface.sMsgRcvd.connect(_on_msg_rcvd):
		pass
	if sPlyrMsgLineSelected.connect(_on_plyr_msg_line_selected):
		pass
	_close_other_menus(MenuWindow.NONE)


func _close_other_menus(p_menu:MenuWindow) -> void:
	_report_plyr_panel.visible = false
	_match_panel.visible = false
	_options_panel.visible = false
	_await_match_panel.visible = false
	
	match p_menu:
		MenuWindow.REPORT_PLYR:
			_report_plyr_panel.visible = true
		
		MenuWindow.INVENTORY:
			pass
		
		MenuWindow.CRAFT:
			pass
		
		MenuWindow.MATCH:
			_match_panel.visible = true
		
		MenuWindow.AWAIT_MATCH:
			_await_match_panel.visible = true
		
		MenuWindow.OPTIONS:
			_options_panel.visible = true


func _on_add_blocked_plyr_btn_pressed() -> void:
	if MessagingIface.msg_blocked_player_list.find(_report_plyr_name_lbl.text) == -1:
		MessagingIface.msg_blocked_player_list.push_back(_report_plyr_name_lbl.text)
		MessagingIface.client_block_player.rpc_id(1, _report_plyr_name_lbl.text, true)
	
	_close_other_menus(MenuWindow.NONE)
	
	var msgs_children: Array = _messages_box.get_children()
	for child:Node in msgs_children:
		if child is MessageLine:
			var msg_line:MessageLine = child
			if msg_line.plyr_name == _report_plyr_name_lbl.text:
				msg_line.queue_free()
		else:
			child.queue_free()


func _on_line_edit_text_submitted(p_new_text: String) -> void:
	if p_new_text == "":
		return
	MessagingIface.client_sent_msg.rpc_id(1, p_new_text)
	_msg_line.text = ""


func _on_match_btn_pressed() -> void:
	if _match_panel.visible == true:
		_close_other_menus(MenuWindow.NONE)
	else:
		_close_other_menus(MenuWindow.MATCH)


func _on_menu_window_x_btn() -> void:
	_close_other_menus(MenuWindow.NONE)


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
	if _options_panel.visible == true:
		_close_other_menus(MenuWindow.NONE)
	else:
		_update_blocked_plyr_list()
		_close_other_menus(MenuWindow.OPTIONS)


func _on_plyr_msg_line_selected(p_player_name: String) -> void:
	_report_plyr_name_lbl.text = p_player_name
	_close_other_menus(MenuWindow.REPORT_PLYR)


func _on_quit_btn_pressed() -> void:
	get_tree().quit()


func _on_remove_blocked_plyr(p_player_name: String) -> void:
	MessagingIface.client_block_player.rpc_id(1, p_player_name, false)
	var idx: int = MessagingIface.msg_blocked_player_list.find(p_player_name)
	if idx > -1:
		MessagingIface.msg_blocked_player_list.remove_at(idx)
	_update_blocked_plyr_list()


func _on_report_plyr_btn_pressed() -> void:
	MessagingIface.client_report_player.rpc_id(1, _report_plyr_name_lbl)
	_close_other_menus(MenuWindow.NONE)


func _on_send_msg_btn_pressed() -> void:
	if _msg_line.text == "":
		return
	MessagingIface.client_sent_msg.rpc_id(1, _msg_line.text)
	_msg_line.text = ""


func _on_start_match_button_pressed() -> void:
	var side: DataTypes.PlaySide = DataTypes.PlaySide.NONE
	if _side_any_chkbx.pressed:
		side = DataTypes.PlaySide.ANY
	elif _side_tanks_chkbx.pressed:
		side = DataTypes.PlaySide.ONLY_TANKS
	elif _side_towers_chkbx.pressed:
		side = DataTypes.PlaySide.ONLY_TOWERS
	elif _side_pref_tanks_chkbx.pressed:
		side = DataTypes.PlaySide.PREFER_TANKS
	elif _side_pref_towers_chkbx.pressed:
		side = DataTypes.PlaySide.PREFER_TOWERS
	
	var match_type: DataTypes.MatchType = DataTypes.MatchType.NONE
	if _match_type_pve_chkbx.pressed:
		match_type = DataTypes.MatchType.ONLY_PVE
	elif _match_type_try_pvp_chkbx.pressed:
		match_type = DataTypes.MatchType.TRY_PVP
	elif _match_type_pvp_chkbx.pressed:
		match_type = DataTypes.MatchType.ONLY_PVP
	
	if side == DataTypes.PlaySide.NONE or match_type == DataTypes.MatchType.NONE:
		return
	
	ConnectionIface.client_request_match.rpc_id(1, side, match_type)
	# Close the match panel
	# open the awaitng match panel


func _update_blocked_plyr_list() -> void:
	_options_panel.custom_minimum_size.y = 0.0
	_options_panel.size.y = 0.0
	var children: Array[Node] = _blocked_plyr_box.get_children()
	for child:Node in children:
		child.queue_free()
	while _blocked_plyr_box.get_child_count() > 0:
		await get_tree().physics_frame
		
	var needed_height: float = _options_panel.size.y
	
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
	
	_options_panel.custom_minimum_size.y = needed_height
