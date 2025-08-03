class_name DbConn extends Node

const kConnStaleTicks: int = 600000
const kForgotMsec: int = 5000 # 5 sec

var issued: bool = false: set = _set_issued
var last_error: MariaDBConnector.ErrorCode = MariaDBConnector.ErrorCode.OK

var _busy: bool = false
var _ctx: MariaDBConnectContext
var _db_conn: MariaDBConnector
var _last_active_msec: int
var _prep_stmts: Dictionary = {"Global_statement_id": "connection_statement_id"}


func _notification(p_what: int) -> void:
	if p_what == NOTIFICATION_PREDELETE:
		if _db_conn != null:
			_db_conn.disconnect_db()


func _init(p_ctx: MariaDBConnectContext) -> void:
	_prep_stmts = {} # clear info
	_db_conn = MariaDBConnector.connection_instance(p_ctx)
	if _db_conn == null:
		printerr("DbConn", self, ": failed to connect")
		queue_free()
		return
	#print("DbConn", self, ": initialized")
	
	_ctx = p_ctx
	_last_active_msec = Time.get_ticks_msec()
	
	# cannot connect signals inside of threads so we call_deferred which will connect on main loop
	call_deferred("_connect_signal")


func add_prepared_stmt(p_glb_id: int, p_stmt: String, p_overwrite:bool = false) -> void:
	if _db_conn == null:
		printerr("DbConn", self, ": is null")
		return
	
	if _prep_stmts.has(p_glb_id):
		if !p_overwrite:
			print("Overwrite not set for prepared statement glb id:%d stmt:%s" % [p_glb_id,
				p_stmt])
			return
		else:
			var conn_stmt_id: int = _prep_stmts[p_glb_id]
			if _db_conn.prep_stmt_close(conn_stmt_id) == MariaDBConnector.ErrorCode.OK:
				if !_prep_stmts.erase(p_glb_id):
					printerr("%s failed to remove prepared glb_stmt_id %d"% [str(self), p_glb_id])
					return
	
	var status: Dictionary = _db_conn.prep_stmt(p_stmt)
	if _db_conn.last_error != MariaDBConnector.ErrorCode.OK:
		printerr("%s unable to add prepared statement with ErrorCode: %d!" % [
			self, _db_conn.last_error])
		return
	
	_prep_stmts[p_glb_id] = status["statement_id"]


func do_command_stmt(p_stmt: String) -> Dictionary:
	if not issued: _set_issued(true)
	
	_last_active_msec = Time.get_ticks_msec()
	_busy = true
	var result: Dictionary = _db_conn.execute_command(p_stmt)
	last_error = _db_conn.last_error
	_busy = false
	
	if issued: _set_issued(false)
	
	return result


func do_command_stmt_continue(p_stmt: String) -> Dictionary:
	if not issued: _set_issued(true)
	
	_last_active_msec = Time.get_ticks_msec()
	_busy = true
	var result: Dictionary = _db_conn.execute_command(p_stmt)
	last_error = _db_conn.last_error
	_busy = false
	
	return result


func do_select_stmt(p_stmt: String) -> Array[Dictionary]:
	if not issued: _set_issued(true)
	
	_last_active_msec = Time.get_ticks_msec()
	_busy = true
	var result: Array[Dictionary] = _db_conn.select_query(p_stmt)
	last_error = _db_conn.last_error
	_busy = false
	if issued: _set_issued(false)
	
	return result


func do_select_stmt_continue(p_stmt: String) -> Array[Dictionary]:
	if not issued: _set_issued(true)
	
	_last_active_msec = Time.get_ticks_msec()
	_busy = true
	var result: Array[Dictionary] = _db_conn.select_query(p_stmt)
	last_error = _db_conn.last_error
	_busy = false
	return result


func do_task_release(p_task: DbTask) -> void:
	do_task_keep_issued(p_task)
	if issued: _set_issued(false)


func do_task_keep_issued(p_task: DbTask) -> void:
	if not issued: _set_issued(true)
	
	if not _check_task(p_task): return
	
	_do_task(p_task)


func do_tasks_release(p_tasks: Array[DbTask]) -> void:
	do_tasks_keep_issued(p_tasks)
	if issued: _set_issued(false)


func do_tasks_keep_issued(p_tasks: Array[DbTask]) -> void:
	if not issued: _set_issued(true)
	
	for task: DbTask in p_tasks:
		do_task_keep_issued(task)


func _check_task(p_task: DbTask) -> bool:
	_last_active_msec = Time.get_ticks_msec()
	if p_task.params.is_empty():
		printerr("DbTask missing params")
		return false
	if p_task.query_result == null:
		printerr("DbTask QueryResult not initialized")
		return false
	if not _prep_stmts.has(p_task.stmt_glb_id):
		printerr("DbConn:", self, " Missing Statement for Global DB Stmt ID:", p_task.stmt_glb_id)
		return false
	
	if not DB.prepared_statements.has(p_task.stmt_glb_id):
		printerr("DbConn Error - Missing Global DB STMT ID:", p_task.stmt_glb_id)
		return false
	return true


func _connect_signal() -> void:
	# More efficient then timers, coupling ok since TimeLapse is an autoload
	var error: int = TimeLapse.sOneSecondLapsed.connect(_update_connection)
	if error: printerr(self, "Can not connect to TimeLapse.sFiveSecondsLapsed")


func _do_prepared_cmd(p_task: DbTask) -> void:
	var db_conn_stmt_id: int = _prep_stmts[p_task.stmt_glb_id]
	p_task.query_result.cmd_res = _db_conn.prep_stmt_exec_cmd(db_conn_stmt_id, p_task.params)
	# Have to run the exec before checking MariaDBConnector.last_error
	p_task.query_result.error = _db_conn.last_error


func _do_prepared_select(p_task: DbTask) -> void:
	var db_conn_stmt_id: int = _prep_stmts[p_task.stmt_glb_id]
	p_task.query_result.select_res = _db_conn.prep_stmt_exec_select(db_conn_stmt_id, p_task.params)
	# Have to run the exec before checking MariaDBConnector.last_error
	p_task.query_result.error = _db_conn.last_error


func _do_task(p_task: DbTask) -> void:
	_busy = true
	var stmt: Dictionary = DB.prepared_statements[p_task.stmt_glb_id]
	var stmt_type: DB.StmtTypes = stmt.keys()[0]
	if stmt_type == DB.StmtTypes.SELECT:
		_do_prepared_select(p_task)
	elif stmt_type == DB.StmtTypes.COMMAND:
		_do_prepared_cmd(p_task)
	_busy = false

func _set_issued(p_issued: bool) -> void:
	issued = p_issued
	DB.call_deferred("emit_signal", "sDbConnsChanged")


func _update_connection() -> void:
	if not _busy:
		# MariaDB conections timeout after about 20 min, so we reconnect at 10 min idle
		if Time.get_ticks_msec() - _last_active_msec > kConnStaleTicks:
			_db_conn.ping_srvr()
			_last_active_msec = Time.get_ticks_msec()
			#print(self, "Ping")
		if issued:
			if Time.get_ticks_msec() - _last_active_msec > kForgotMsec:
				queue_free()
				DB.call_deferred("emit_signal", "sDbConnsChanged")
