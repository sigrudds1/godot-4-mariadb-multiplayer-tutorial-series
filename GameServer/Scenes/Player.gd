# "res://Scenes/Player.gd"
class_name Player extends Node

enum ConnectionStates {
	OFFLINE,
	ONLINE
}

enum UpdateStates {
	CONNECT,
	UPDATE,
	DISCONNECT
}


var peer_id: int
var plyr_id: int
var display_name: String = ""

var inventory: Dictionary = {}
var msg_blocked_plyrs: PackedStringArray = []

var match_state: DataTypes.PlayerMatchStates = DataTypes.PlayerMatchStates.IDLE
# TODO when player is awaiting or playing a match do not allow match setup changes

var _connection_state: ConnectionStates =  ConnectionStates.ONLINE
#var _db_inventory: Dictionary = Dictionary()
var _db_msg_blocked_plyrs: PackedStringArray = []


func _ready() -> void:
	if MessagingIface.sPlayerSentMsg.connect(_send_msg) != OK:
		pass # TODO handle error
	
	if TimeLapse.sFiveMinutesLapsed.connect(_update_db) != OK:
		pass # TODO handle error
	
	var thr: Thread = Thread.new()
	var err_code: Error = thr.start(_update_db_thread_func.bind(thr, UpdateStates.CONNECT))
	if err_code != OK:
		printerr("player _update_thread start error code:" + str(err_code))


func add_msg_blocked_plyr(p_plyr_dname: String) -> void:
	# NEVER Trust the client to send you something clean
	if not Sanitize.check_display_name(p_plyr_dname):
		return
	
	if msg_blocked_plyrs.find(p_plyr_dname) == -1:
		if not msg_blocked_plyrs.push_back(p_plyr_dname): 
			pass


func remove_msg_blocked_plyr(p_plyr_dname: String) -> void:
	var idx: int = msg_blocked_plyrs.find(p_plyr_dname)
	if idx > 0:
		msg_blocked_plyrs.remove_at(idx)


# You may be asking why not queue_free from outside and _exit_tree instead
# Thread can't be started once the Node is flagged for deletion and DB functions have to be threaded
func remove_player(p_thread: Thread) -> void:
	_connection_state = ConnectionStates.OFFLINE
	_update_db_thread_func(p_thread, UpdateStates.DISCONNECT)
	queue_free()


func _fetch_db_blocked_plyrs(p_thread: Thread) -> Array[Dictionary]:
	var qr: QueryResult = QueryResult.new()
	if p_thread != null:
		var stmt_id: DB.StmtIDs = DB.StmtIDs.SELECT_MSG_BLOCKED_BY_DISPLAY_NAMES
		var sql_params: Array[Dictionary] = [{MariaDBConnector.FT_INT_U: plyr_id}]
		var task: DbTask = DbTask.new(stmt_id, sql_params, qr)
		
		DB.do_threaded_task(task, p_thread)
		if qr.error != MariaDBConnector.ErrorCode.OK:
			printerr("Players._fetch_db_blocked_plyrs db error:", qr.error)
	
	return qr.select_res


func _fetch_db_inventory(_thread: Thread) -> void:
	inventory = InventoryIface.get_inventory_template()
	# TODO Update plyer client inventory from DB


func _send_msg(p_from_plyr: String, p_msg: String) -> void:
	if msg_blocked_plyrs.find(p_from_plyr) > -1:
		return
	MessagingIface.srvr_send_msg.rpc_id(peer_id, p_from_plyr, p_msg)


func _update_blocked_plyr_list(p_thread: Thread) -> void:
	msg_blocked_plyrs.clear()
	var blocked_plyr_rows: Array[Dictionary] = _fetch_db_blocked_plyrs(p_thread)
	for row: Dictionary in blocked_plyr_rows:
		var blocked: String = row.get("display_name")
		if blocked != null and msg_blocked_plyrs.find(blocked) == -1:
			if _db_msg_blocked_plyrs.push_back(blocked): pass
		else:
			printerr("Player._get_msg_block null value or duplicate in rows:", blocked_plyr_rows)
	
	msg_blocked_plyrs = _db_msg_blocked_plyrs.duplicate() # must duplicate arrays are passed by ref
	MessagingIface.srvr_send_blocked_players.rpc_id.call_deferred(peer_id, msg_blocked_plyrs)


func _update_db() -> void:
	var thr: Thread = Thread.new()
	var err_code: Error = thr.start(_update_db_thread_func.bind(thr, UpdateStates.UPDATE))
	if err_code != OK:
		printerr("player _update_db_thread_func start error code:" + str(err_code))


func _update_db_blocked_plyrs(p_thread: Thread) -> void:
	if p_thread == null:
		return
	
	var db_del_params_list: Array = []
	
	for plyr_dname:String in _db_msg_blocked_plyrs:
		if msg_blocked_plyrs.find(plyr_dname) == -1:
			var sql_params: Array[Dictionary] = [
				{MariaDBConnector.FT_INT_U: plyr_id},
				{MariaDBConnector.FT_VARCHAR: plyr_dname}
			]
			db_del_params_list.push_back(sql_params)
	
	var db_insert_params_list: Array = []
	for plyr_dname: String in msg_blocked_plyrs:
		if _db_msg_blocked_plyrs.find(plyr_dname) == -1:
			var sql_params: Array[Dictionary] = [
				{MariaDBConnector.FT_INT_U: plyr_id},
				{MariaDBConnector.FT_VARCHAR: plyr_dname}
			]
			db_insert_params_list.push_back(sql_params)
	
	if db_del_params_list.size() == 0 and db_insert_params_list.size() == 0:
		return
	
	var qr: QueryResult = QueryResult.new()
	var task: DbTask = DbTask.new(DB.StmtIDs.DELETE_MSG_BLOCKED_PLYR, [], qr)
	var timeout_msec: int = Time.get_ticks_msec() + DB.kDbConnTryMsec
	var db_conn: DbConn = DB.get_db_conn()
	while db_conn == null and Time.get_ticks_msec() < timeout_msec:
		# Only call inside a thread or it will block main thread, use await inside main thread
		OS.delay_msec(DB.kThreadLoopDelay) 
		db_conn = DB.get_db_conn()
	
	if db_conn == null:
		return
	
	for params:Array[Dictionary] in db_del_params_list:
		task.params = params
		db_conn.do_task_continue(task)
		if qr.error != MariaDBConnector.ErrorCode.OK:
			printerr("Error processiong DELETE_MSG_BLOCKED_PLYR with params ", params)
	
	task.stmt_glb_id = DB.StmtIDs.INSERT_MSG_BLOCKED_PLYR
	
	for params:Array[Dictionary] in db_insert_params_list:
		task.params = params
		db_conn.do_task_continue(task)
		if qr.error != MariaDBConnector.ErrorCode.OK:
			printerr("Error processiong INSERT_MSG_BLOCKED_PLYR with params ", params)
	
	db_conn.issued = false
	db_conn = null


func _update_db_inventory(_thread: Thread) -> void:
	pass


func _update_db_thread_func(p_this_thread: Thread, p_update_state: UpdateStates) -> void:
	if p_update_state != UpdateStates.UPDATE:
		_update_plyr_status(p_this_thread)
	
	if p_update_state == UpdateStates.CONNECT:
		_update_blocked_plyr_list(p_this_thread)
		_fetch_db_inventory(p_this_thread)
	else:
		_update_db_blocked_plyrs(p_this_thread)
		_update_db_inventory(p_this_thread)
	
	Callable(Utils, "thread_wait_stop").call_deferred(p_this_thread)


func _update_plyr_status(p_thread: Thread) -> void:
	if p_thread == null:
		return
	
	var stmt_id: DB.StmtIDs = DB.StmtIDs.INSERT_OR_UPDATE_PLYR
	var sql_params: Array[Dictionary] = [
		{MariaDBConnector.FT_INT_U: plyr_id},
		{MariaDBConnector.FT_VARCHAR: display_name},
		{MariaDBConnector.FT_TINYINT_U: _connection_state}
	]
	var qr: QueryResult = QueryResult.new()
	var task: DbTask =  DbTask.new(stmt_id, sql_params, qr)
	DB.do_threaded_task(task, p_thread)
	
	if qr.error != MariaDBConnector.ErrorCode.OK:
		printerr("INSERT_OR_UPDATE_PLYR error:", qr.error)
