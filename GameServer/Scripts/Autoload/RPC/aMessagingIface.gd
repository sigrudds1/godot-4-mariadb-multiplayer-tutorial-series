extends Node


signal sPlayerSentMsg(plyr_display_name: String, msg: String)

@onready var _main_node: Node = get_node("/root/Main")


func _block_plyer_thread(
		p_plyr_node: Player,
		p_blocked_display_name: String,
		p_do_block: bool,
		p_this_thread: Thread
	) -> void:
	
	var blocked_plyr_idx: int = p_plyr_node.msg_blocked_plyrs.find(p_blocked_display_name)
	var stmt_id: int = -1
	if p_do_block:
		stmt_id = DB.StmtIDs.CMD_INSERT_MSG_BLOCK
		if blocked_plyr_idx == -1:
			p_plyr_node.msg_blocked_plyrs.push_back(p_blocked_display_name)
	else:
		stmt_id = DB.StmtIDs.CMD_DELETE_MSG_BLOCK
		if blocked_plyr_idx > -1:
			p_plyr_node.msg_blocked_plyrs.remove_at(blocked_plyr_idx)
	
	var sql_params:  Array[Dictionary] = [
		{MariaDBConnector.FT_INT_U: p_plyr_node.plyr_id},
		{MariaDBConnector.FT_VARCHAR: p_blocked_display_name}
	]
	
	var qr: QueryResult = QueryResult.new()
	var task: DbTask = DbTask.new(
		stmt_id,
		sql_params,
		func(p_res: Dictionary) -> void:
			qr.res = p_res, # You need a global container inside lambdas
		func(p_err: int) -> void:
			qr.err = p_err # You need a global container inside lambdas
	)
	
	var timeout_msec: int = Time.get_ticks_msec() + DB.kDbConnTryMsec
	var db_conn: DbConn = DB.get_db_conn()
	while db_conn == null and Time.get_ticks_msec() < timeout_msec:
		# Only call inside a thread or it will block main thread, use await inside main thread
		OS.delay_msec(DB.kThreadLoopDelay) 
		db_conn = DB.get_db_conn()
	
	if db_conn == null:
		pass # TODO handle error
	else:
		db_conn.do_tasks([task])
		db_conn.issued = false
		db_conn = null
	
	Callable(Utils, "thread_wait_stop").call_deferred(p_this_thread)


@rpc("any_peer", "reliable")
func client_block_player(p_blocked_display_name: String, p_do_block: bool) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	var plyr_node: Player = _main_node.get_node_or_null("plyr_" + str(peer_id))
	# create thread, find player by display_name, add them to this player
	var thr: Thread = Thread.new()
	var err_code: Error = thr.start(_block_plyer_thread.bind(plyr_node,
		p_blocked_display_name,
		p_do_block,
		thr))
	if err_code != OK:
		printerr("MessageIface _block_plyer_thread start error code:" + str(err_code))


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
	if plyr_node == null:
		return
	print("client: %s sent_msg: %s" % [plyr_node.display_name, p_msg])
	sPlayerSentMsg.emit(plyr_node.display_name, p_msg)
	# TODO Tell ClusterCore player sent message to distribute to other servers
	# TODO log msg


@rpc("authority", "reliable")
func srvr_send_blocked_players(_blocked_plyrs: Array) -> void:
	pass


@rpc("authority")
func srvr_send_msg(_from_plyr_display_name: String, _msg: String) -> void:
	pass
