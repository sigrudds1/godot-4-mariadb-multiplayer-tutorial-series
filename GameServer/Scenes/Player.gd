# "res://Scenes/Player.gd"
class_name Player extends Node

var peer_id: int
var plyr_id: int
var display_name: String
var msg_blocked_plyrs: Array = Array()

var _in_tree: bool = true


func _ready() -> void:
	if MessagingIface.sPlayerSentMsg.connect(_send_msg) != OK:
		pass # TODO handle error
	
	var thr: Thread = Thread.new()
	var err_code: Error = thr.start(_init_thread.bind(thr))
	if err_code != OK:
		printerr("player _update_thread start error code:" + str(err_code))


func _exit_tree() -> void:
	_in_tree = false


func _init_thread(p_this_thread: Thread) -> void:
	var err: int = _insert_update_plyr()
	if err == OK:
		err = _qry_msg_blocked_plyrs()
	if err == OK:
		call_deferred("_send_msg_blocked_plyr_list")
	
	call_deferred("_thread_stop", p_this_thread)


func _insert_update_plyr(p_db_conn: DbConn = null, p_end: bool = true) -> int:
	var sql_params: Array[Dictionary] = [
		{MariaDBConnector.FT_INT_U: plyr_id},
		{MariaDBConnector.FT_VARCHAR: display_name},
		{MariaDBConnector.FT_TINYINT_U: 1}
	]
	var qr: QueryResult = QueryResult.new()
	var task: DbTask = DbTask.new(
		DB.eStmtID.CMD_INSERT_UPDATE_PLAYER,
		sql_params,
		func(p_res: Dictionary) -> void:
			qr.res = p_res, # You need a global container inside lambdas
		func(p_err: int) -> void:
			qr.err = p_err # You need a global container inside lambdas
	)
	while p_db_conn == null and _in_tree:
		OS.delay_msec(DB.kThreadLoopDelay)
		p_db_conn = DB.get_db_conn_thread_only()
	
	if p_db_conn == null:
		# TODO Handle Error
		return ERR_DATABASE_CANT_READ
	
	p_db_conn.do_tasks([task])
	if p_end:
		p_db_conn.issued = false
		p_db_conn = null
	
	if qr.err != OK:
		# TODO Handle Error
		return qr.err
	
	return OK


func _qry_msg_blocked_plyrs(p_db_conn: DbConn = null, p_end: bool = true) -> int:
	var qr: QueryResult = QueryResult.new()
	var task: DbTask = DbTask.new(
		DB.eStmtID.QRY_MSG_BLOCKED_DISPLAY_NAMES,
		[{MariaDBConnector.FT_INT_U: plyr_id}],
		func(p_res: Array[Dictionary]) -> void:
			qr.rows = p_res, # You need a global container inside lambdas
		func(p_err: int) -> void:
			qr.err = p_err # You need a global container inside lambdas
	)
	while p_db_conn == null and _in_tree:
		OS.delay_msec(DB.kThreadLoopDelay)
		p_db_conn = DB.get_db_conn_thread_only()
	
	if p_db_conn == null:
		# TODO Handle Error
		return ERR_DATABASE_CANT_READ
	
	p_db_conn.do_tasks([task])
	if p_end:
		p_db_conn.issued = false
		p_db_conn = null
	
	if qr.err != OK:
		# TODO Handle Error
		return qr.err
	
	for row:Dictionary in qr.rows:
		var blocked_display_name: String = row.get("display_name")
		if blocked_display_name != null and msg_blocked_plyrs.find(blocked_display_name) == -1:
			msg_blocked_plyrs.push_back(blocked_display_name)
		else:
			printerr("Player._get_msg_block null value or duplicate in rows:", qr.rows)
			return ERR_PARSE_ERROR
	
	return OK


func _send_msg_blocked_plyr_list() -> void:
	if msg_blocked_plyrs.size() > 0:
		MessagingIface.srvr_send_blocked_players.rpc_id(peer_id, msg_blocked_plyrs)
	

func _send_msg(p_from_plyr: String, p_msg: String) -> void:
	if msg_blocked_plyrs.find(p_from_plyr) > -1:
		return
	MessagingIface.srvr_send_msg.rpc_id(peer_id, p_from_plyr, p_msg)


func _thread_stop(p_thread: Thread) -> void:
	Utils.thread_wait_stop(p_thread)
