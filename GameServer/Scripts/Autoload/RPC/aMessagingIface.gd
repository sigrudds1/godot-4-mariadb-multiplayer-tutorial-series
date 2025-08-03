extends Node


signal sPlayerSentMsg(plyr_display_name: String, msg: String)

@onready var _main_node: Node = get_node("/root/Main")


@rpc("any_peer", "reliable")
func client_block_player(p_blocked_display_name: String, p_do_block: bool) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	var plyr_node: Player = _main_node.get_node_or_null("plyr_" + str(peer_id))
	if plyr_node == null: return
	
	# NOTE - Due to array.find, you could increase main loop performance if this is put in a thread.
	if p_do_block:
		plyr_node.add_msg_blocked_plyr(p_blocked_display_name)
	else:
		plyr_node.remove_msg_blocked_plyr(p_blocked_display_name)


@rpc("any_peer", "reliable")
func client_report_player(p_reported_plyr_display_name: String, p_msg: String) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	var plyr_node: Player = _main_node.get_node_or_null("plyr_" + str(peer_id))
	print("Player %s reported %s for messagfe %s" % [
		plyr_node.display_name, p_reported_plyr_display_name, p_msg])
	# TODO log and alert GM


@rpc("any_peer")
func client_sent_msg(p_msg: String) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	var plyr_node: Player = _main_node.get_node_or_null("plyr_" + str(peer_id))
	if plyr_node == null: return
	
	sPlayerSentMsg.emit(plyr_node.display_name, p_msg)
	# TODO Tell ClusterCore player sent message to distribute to other servers
	# TODO log msg
	#print("client: %s sent_msg: %s" % [plyr_node.display_name, p_msg])


@rpc("authority", "reliable")
func srvr_send_blocked_players(_blocked_plyrs: Array) -> void: pass


@rpc("authority")
func srvr_send_msg(_from_plyr_display_name: String, _msg: String) -> void: pass
