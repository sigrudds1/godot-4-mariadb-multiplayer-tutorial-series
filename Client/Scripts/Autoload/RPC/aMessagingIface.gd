extends Node

signal sMsgRcvd(from_plyr:String, msg:String)

var msg_blocked_player_list: Array


@rpc("any_peer", "reliable")
func client_block_player(_blocked_display_name: String, _do_block: bool) -> void:
	pass


@rpc("any_peer", "reliable")
func client_report_player(_reported_plyr_display_name: String, _msg: String) -> void:
	pass


@rpc("any_peer")
func client_sent_msg(_msg: String) -> void:
	pass


@rpc("authority", "reliable")
func srvr_send_blocked_players(p_blocked_plyrs: Array) -> void:
	msg_blocked_player_list = p_blocked_plyrs


@rpc("authority")
func srvr_send_msg(p_from_plyr_display_name: String, p_msg: String) -> void:
	sMsgRcvd.emit(p_from_plyr_display_name, p_msg)
