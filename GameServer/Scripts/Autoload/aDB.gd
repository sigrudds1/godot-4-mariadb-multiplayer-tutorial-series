# "res://Scripts/Autoload/aDB.gd"
# NOTE - See the game_srvr_cfg.json, this examples db plain password is "secret" and is hashed with
#	SHA512, not to	be confused with SHA512/224, SHA512/256, SHA3-512, the MariaDB server user
#	is configured using ED25519 plugin, see the included GameSrvrSetup.sql file for installation.
# The MariaDB addon will except the SHA512 hash because in the steps for authetication via ed25519
#	it hashes the password via SHA512 in several stages before signing, the first time is just
#	hashing SHA512, so with the is_prehashed set as true the first hashing is skipped and a safer,
#	sha512, storage of the password can be kept in a cfg.

# Connection Pooling
#	For a faster query we will hold a min connection pool to be ready, the pools will be refreshed
#		on a given time
#	We have a limited number of connection in the pool, so connections have to be ran in threads 
#	or we will get blocking while the request is waiting for a db connection to free; even though 
#	queries are fast we could get a race condition that arrives to a stalemate and locks the server.
extends Node

signal sDbConnsChanged

enum StmtTypes {
	COMMAND = 1,
	SELECT
}
enum StmtIDs {
	SELECT_PLAYER_BY_ID,
	INSERT_OR_UPDATE_PLYR,
	UPDATE_PLAYER,
	INSERT_MSG_BLOCKED_PLYR,
	DELETE_MSG_BLOCKED_PLYR,
	SELECT_MSG_BLOCKED_BY_DISPLAY_NAMES,
	INSERT_PLYR_INTO_MATCH,
	DELETE_PLYR_FROM_MATCH,
	SELECT_ALL_MATCHES,
	SELECT_MATCHES_BY_PLYR_SIDE_TYPE,
}

const kBufferConns: int = 2
const kDbConnTryMsec: int = 60000 # 1 min
const kThreadLoopDelay: int = 17

var prepared_statements: Dictionary = {
	StmtIDs.SELECT_PLAYER_BY_ID: {
		StmtTypes.SELECT: "SELECT * FROM player WHERE id = ?;"},
	StmtIDs.INSERT_OR_UPDATE_PLYR: {
		StmtTypes.COMMAND: "INSERT INTO player SET id=?, display_name=?, status=? " +
		"ON DUPLICATE KEY UPDATE status=VALUES(status);" },
	StmtIDs.UPDATE_PLAYER: {
		StmtTypes.COMMAND: "UPDATE player SET status=?;"},
	StmtIDs.INSERT_MSG_BLOCKED_PLYR: {
		StmtTypes.COMMAND: "INSERT INTO msg_blocks (plyr_id, blocked_plyr_id) " +
			"SELECT ?, id " +
			"FROM player " +
			"WHERE display_name=?;"},
	StmtIDs.DELETE_MSG_BLOCKED_PLYR: {
		StmtTypes.COMMAND: "DELETE FROM msg_blocks " +
			"WHERE plyr_id=? " +
			"AND blocked_plyr_id = ( " +
				"SELECT id FROM player " +
				"WHERE display_name=? );"},
	StmtIDs.SELECT_MSG_BLOCKED_BY_DISPLAY_NAMES: {
		StmtTypes.SELECT: "SELECT p.display_name " +
			"FROM msg_blocks mb " +
			"JOIN player p ON p.id = mb.blocked_plyr_id " +
			"WHERE mb.plyr_id=?;"},
	StmtIDs.INSERT_PLYR_INTO_MATCH: {
		StmtTypes.COMMAND: "INSERT INTO awaiting_match SET plyr_id=?, side=?, match_type=?;" },
	StmtIDs.DELETE_PLYR_FROM_MATCH: {
		StmtTypes.COMMAND: "DELETE FROM awaiting_match WHERE plyr_id=?;" },
	StmtIDs.SELECT_ALL_MATCHES: {
		StmtTypes.SELECT: "SELECT * FROM awaiting_match " +
			"ORDER BY dt ASC;" }, 
	StmtIDs.SELECT_MATCHES_BY_PLYR_SIDE_TYPE: {
		StmtTypes.SELECT: "SELECT * FROM awaiting_match " +
			"WHERE plyr_id != ? " + 
				"AND match_type IN (?, ?) " +
				"AND side IN (?, ?, ?) " +
			"ORDER BY dt ASC, match_type ASC, side ASC;" }, 
}: set = _set_prepared_statements

var _db_ctx: MariaDBConnectContext = MariaDBConnectContext.new()
var _max_db_conns: int = 0
var _db_conn_bfr: Array[DbConn] = []
var _db_conn_bfr_mutex: Mutex = Mutex.new()
var _db_conn_issued_bfr: Array[DbConn] = []
var _db_conn_issued_bfr_mutex: Mutex = Mutex.new()
var _srvr_change_cfg: bool = true
var _srvr_running: bool = true
var _check_db_conns_sema: Semaphore = Semaphore.new()
var _check_db_conns_thread: Thread = Thread.new()


func _ready() -> void:
	if CFG.sCfgChanged.connect(_change_cfg) != OK:
		pass
	#_setup_db_ctx()
	if TimeLapse.sMinuteLapsed.connect(_on_check_db_conns) != OK:
		pass
	if sDbConnsChanged.connect(_on_check_db_conns) != OK:
		pass
	
	var error: int = _check_db_conns_thread.start(_check_conns_thread_func)
	if error != OK:
		printerr("Starting _check_db_conns_thread error with ", error)


func _exit_tree() -> void:
	_srvr_running = false
	_check_db_conns_sema.post()
	Utils.thread_wait_stop(_check_db_conns_thread)


func do_threaded_multitask(p_tasks: Array[DbTask], p_thread: Thread) -> int:
	if p_thread == null:
		return ERR_INVALID_PARAMETER
	
	var timeout_msec: int = Time.get_ticks_msec() + DB.kDbConnTryMsec
	var db_conn: DbConn = DB.get_db_conn()
	while db_conn == null and Time.get_ticks_msec() < timeout_msec:
	# Only call inside a thread or it will block main thread, use await inside main thread
		OS.delay_msec(DB.kThreadLoopDelay) 
		db_conn = DB.get_db_conn()
	
	if db_conn == null:
		return ERR_CANT_CONNECT
	else:
		db_conn.do_tasks(p_tasks)
		db_conn = null
	
	return OK


func do_threaded_task(p_task: DbTask, p_thread: Thread) -> void:
	if p_thread == null:
		p_task.query_result.error = ERR_INVALID_PARAMETER
		return 
	
	var timeout_msec: int = Time.get_ticks_msec() + DB.kDbConnTryMsec
	var db_conn: DbConn = DB.get_db_conn()
	while db_conn == null and Time.get_ticks_msec() < timeout_msec:
	# Only call inside a thread or it will block main thread, use await inside main thread
		OS.delay_msec(DB.kThreadLoopDelay) 
		db_conn = DB.get_db_conn()
	
	if db_conn == null:
		p_task.query_result.error =  ERR_CANT_CONNECT
	else:
		db_conn.do_task(p_task)
		db_conn = null


func get_db_conn() -> DbConn:
	if not _srvr_running or _srvr_change_cfg:
		return null
	
	var db_conn: DbConn = null
	_db_conn_bfr_mutex.lock()
	if _db_conn_bfr.size() > 0:
		db_conn = _db_conn_bfr.pop_back()
	_db_conn_bfr_mutex.unlock()

	if db_conn != null:
		_db_conn_issued_bfr_mutex.lock()
		_db_conn_issued_bfr.push_back(db_conn)
		_db_conn_issued_bfr_mutex.unlock()
		db_conn.issued = true
	
	return db_conn


func _change_cfg() -> void:
	_srvr_change_cfg = true
	
	_setup_db_ctx()
	
	_db_conn_bfr_mutex.lock()
	_db_conn_issued_bfr_mutex.lock()
	for conn:DbConn in _db_conn_bfr:
		conn.queue_free()
	for conn:DbConn in _db_conn_issued_bfr:
		conn.queue_free()
	_db_conn_bfr_mutex.unlock()
	_db_conn_issued_bfr_mutex.unlock()

	await get_tree().physics_frame
	_srvr_change_cfg = false
	sDbConnsChanged.emit()
	_test_game_db()


# Only run with signals so it will only run when ready and not block main loop
func _check_conns_thread_func() -> void:
	while _srvr_running:
		_db_conn_bfr_mutex.lock()
		for i:int in range(_db_conn_bfr.size() - 1, -1, -1):
			var conn: DbConn = _db_conn_bfr[i]
			if conn == null:
				_db_conn_bfr.remove_at(i)
		var dbconns: int = _db_conn_bfr.size()
		_db_conn_bfr_mutex.unlock()

		_db_conn_issued_bfr_mutex.lock()
		for i:int in range(_db_conn_issued_bfr.size() - 1, -1, -1):
			var conn: DbConn = _db_conn_issued_bfr[i]
			if conn == null:
				_db_conn_issued_bfr.remove_at(i)
			elif not conn.issued:
				_db_conn_bfr_mutex.lock()
				_db_conn_issued_bfr.remove_at(i)
				_db_conn_bfr.push_back(conn)
				_db_conn_bfr_mutex.unlock()
		
		var busy_dbconns: int = _db_conn_issued_bfr.size()
		_db_conn_issued_bfr_mutex.unlock()

		if dbconns > kBufferConns:
			_db_conn_bfr_mutex.lock()
			var conn: DbConn = _db_conn_bfr.pop_back()
			conn.queue_free()
			_db_conn_bfr_mutex.unlock()

		var break_msec: int = Time.get_ticks_msec() + 1000
		while (_max_db_conns > dbconns + busy_dbconns and
				dbconns < kBufferConns and
				Time.get_ticks_msec() < break_msec):
			var db_conn: DbConn = DbConn.new(_db_ctx)
			# Every DB connection needs the prepared statements as they are not shared
			for glb_id:int in prepared_statements.keys():
				var stmt_d: Dictionary =  prepared_statements[glb_id]
				var stmt: String = stmt_d.values()[0]
				db_conn.add_prepared_stmt(glb_id, stmt)
				#db_conn.issued = false
			if db_conn != null:
				_db_conn_bfr_mutex.lock()
				_db_conn_bfr.push_back(db_conn)
				_db_conn_bfr_mutex.unlock()
				dbconns += 1
				break_msec = Time.get_ticks_msec() + 1000
		
		_check_db_conns_sema.wait()


func _on_check_db_conns() -> void:
	_check_db_conns_sema.post()


func _setup_db_ctx() -> void:
	_db_ctx.hostname = CFG.data["db_url"]
	_db_ctx.port = CFG.data["db_port"] # default is port 3306
	_db_ctx.db_name = CFG.data["db_name"]
	_db_ctx.username = CFG.data["db_user"]
	_db_ctx.password = CFG.data["db_pwd_sha512_to_b64"]
	_max_db_conns = CFG.data["db_max_conns"]
	#_db_ctx.auth_type = MariaDBConnectContext.AUTH_TYPE_ED25519 # default
	#_db_ctx.encoding = MariaDBConnectContext.ENCODE_BASE64 # default


func _set_prepared_statements(_val: Dictionary) -> void:
	printerr("invalid setter call on DB.prepared_statements")


func _test_game_db() -> void:
	var db_conn: MariaDBConnector = MariaDBConnector.connection_instance(_db_ctx)
	var status: Dictionary = db_conn.prep_stmt("SELECT * FROM player WHERE id = ?;")
	if db_conn.last_error != MariaDBConnector.ErrorCode.OK:
		printerr("%s unable to add prepared statement with ErrorCode: %d!" % [
		self, db_conn.last_error])
		return

	var stmt_id: int = status["statement_id"]
	var params: Array[Dictionary] = [{MariaDBConnector.FT_INT_U: 1}]
	var _res: Array[Dictionary] = db_conn.prep_stmt_exec_select(stmt_id, params)
	if db_conn.last_error == MariaDBConnector.ErrorCode.OK:
		print("DB OK for %s test" % [_db_ctx.db_name])
	else:
		print("DB ERROR: %d for %s test", [db_conn.last_error, _db_ctx.db_name])
