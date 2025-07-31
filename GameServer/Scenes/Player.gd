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
var display_name: String
var msg_blocked_plyrs: Array = Array()
var inventory: Dictionary = Dictionary()
var match_state: DataTypes.PlayerMatchStates = DataTypes.PlayerMatchStates.IDLE
# TODO when player is awaiting or playig a match do not allow match setup changes

var _connection_state: ConnectionStates =  ConnectionStates.ONLINE

func _ready() -> void:
	if MessagingIface.sPlayerSentMsg.connect(_send_msg) != OK:
		pass # TODO handle error
	
	if TimeLapse.sFiveMinutesLapsed.connect(_update_containers) != OK:
		pass # TODO handle error
	
	var thr: Thread = Thread.new()
	var err_code: Error = thr.start(_update_db_thread_func.bind(thr, UpdateStates.CONNECT))
	if err_code != OK:
		printerr("player _update_thread start error code:" + str(err_code))


func _exit_tree() -> void:
	print(self, " exiting tree")

# You may be asking why not queue_free from outside and _exit_tree instead
# Thread can't be started once the Node is flagged for deletion and DB functions have to be threaded
func remove_player(p_thread: Thread) -> void:
	_connection_state = ConnectionStates.OFFLINE
	_update_db_thread_func(p_thread, UpdateStates.DISCONNECT)
	queue_free()


func _fetch_db_blocked_plyrs(p_thread: Thread) -> void:
	var stmt_id: DB.StmtIDs = DB.StmtIDs.QRY_MSG_BLOCKED_DISPLAY_NAMES
	var sql_params: Array[Dictionary] = [{MariaDBConnector.FT_INT_U: plyr_id}]
	var qr: QueryResult = QueryResult.new()
	
	DB.do_threaded_select_task(stmt_id, sql_params, qr, p_thread)
	
	if qr.err == MariaDBConnector.ErrorCode.OK:
		for row: Dictionary in qr.rows:
			var blocked: String = row.get("display_name")
			if blocked != null and msg_blocked_plyrs.find(blocked) == -1:
				msg_blocked_plyrs.push_back(blocked)
			else:
				printerr("Player._get_msg_block null value or duplicate in rows:", qr.rows)
		
		if msg_blocked_plyrs.size() > 0:
			MessagingIface.srvr_send_blocked_players.rpc_id.call_deferred(
				peer_id, msg_blocked_plyrs)


func _fetch_db_inventory(_thread: Thread) -> void:
	# TODO Update plyer client inventory from DB
	pass


func _send_msg(p_from_plyr: String, p_msg: String) -> void:
	if msg_blocked_plyrs.find(p_from_plyr) > -1:
		return
	MessagingIface.srvr_send_msg.rpc_id(peer_id, p_from_plyr, p_msg)


func _update_containers() -> void:
	var thr: Thread = Thread.new()
	var err_code: Error = thr.start(_update_db_thread_func.bind(thr, UpdateStates.UPDATE))
	if err_code != OK:
		printerr("player _update_db_thread_func start error code:" + str(err_code))


func _update_db_blocked_plyrs(_thread: Thread) -> void:
	pass


func _update_db_inventory(_thread: Thread) -> void:
	pass


func _update_db_thread_func(p_this_thread: Thread, p_update_state: UpdateStates) -> void:
	if p_update_state != UpdateStates.UPDATE:
		_update_plyr_status(p_this_thread)
	
	if p_update_state == UpdateStates.CONNECT:
		_fetch_db_blocked_plyrs(p_this_thread)
		_fetch_db_inventory(p_this_thread)
	else:
		_update_db_blocked_plyrs(p_this_thread)
		_update_db_inventory(p_this_thread)
	
	Callable(Utils, "thread_wait_stop").call_deferred(p_this_thread)


func _update_plyr_status(p_thread: Thread) -> void:
	if p_thread == null:
		return
	
	var stmt_id: DB.StmtIDs = DB.StmtIDs.CMD_INSERT_UPDATE_PLAYER
	var sql_params: Array[Dictionary] = [
		{MariaDBConnector.FT_INT_U: plyr_id},
		{MariaDBConnector.FT_VARCHAR: display_name},
		{MariaDBConnector.FT_TINYINT_U: _connection_state}
	]
	var qr: QueryResult = QueryResult.new()
	
	DB.do_threaded_cmd_task(stmt_id, sql_params, qr, p_thread)
	
	if qr.err != MariaDBConnector.ErrorCode.OK:
		printerr("CMD_INSERT_UPDATE_PLAYER err:", qr.err)
