class_name DbConn extends Node

const kForgotMsec: int = 5000 # 5 sec

var issued: bool = false: set = _set_issued

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
	# More efficient then timers, coupling ok since TimeLapse is an autoload
	var error: int = TimeLapse.sFiveSecondsLapsed.connect(_update_connection)
	if error:
		printerr(self, "Can not connect to TimeLapse.sTenMinuteLapsed")


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


func do_tasks(p_tasks: Array[DbTask]) -> void:
	issued = true
	_busy = true
	for task:DbTask in p_tasks:
		if _prep_stmts.has(task.stmt_glb_id):
			if DB.prepared_statements.has(task.stmt_glb_id):
				var stmt_d: Dictionary = DB.prepared_statements[task.stmt_glb_id]
				if not stmt_d.is_empty():
					var stmt_type: DB.eStmtType = stmt_d.keys()[0]
					if stmt_type == DB.eStmtType.SELECT:
						_do_query(task)
					elif stmt_type == DB.eStmtType.COMMAND:
						_do_cmd(task)
		else:
			printerr("DbPrep", self, "Missing Global STMT ID:", task.stmt_glb_id)
	_busy = false
	_last_active_msec = Time.get_ticks_msec()


func _do_callable(callable: Callable, arg: Variant = null) -> void:
	if callable.is_null():
		return

	if callable.get_argument_count() == 0:
		callable.call()
	else:
		callable.call(arg)


func _do_cmd(p_task: DbTask) -> void:
	var db_conn_stmt_id: int = _prep_stmts[p_task.stmt_glb_id]
	var res: Dictionary = _db_conn.prep_stmt_exec_cmd(db_conn_stmt_id, p_task.params)
	if _db_conn.last_error == MariaDBConnector.ErrorCode.OK:
		_do_callable(p_task.success_func, res)
	else:
		_do_callable(p_task.fail_func, _db_conn.last_error)


func _do_query(p_task: DbTask) -> void:
	var db_conn_stmt_id: int = _prep_stmts[p_task.stmt_glb_id]
	var res: Array[Dictionary] = _db_conn.prep_stmt_exec_select(db_conn_stmt_id, p_task.params)
	if _db_conn.last_error == MariaDBConnector.ErrorCode.OK:
		_do_callable(p_task.success_func, res)
	else:
		_do_callable(p_task.fail_func, _db_conn.last_error)


func _set_issued(p: bool) -> void:
	issued = p
	DB.call_deferred("emit_signal", "sDbConnsChanged")


func _update_connection() -> void:
	if not _busy:
		# MariaDB conections timeout after about 20 min, so we reconnect at 10 min idle
		if Time.get_ticks_msec() - _last_active_msec > DB.kConnStaleTicks:
			_db_conn.ping_srvr()
			_last_active_msec = Time.get_ticks_msec()
			#print(self, "Ping")
		if issued:
			if Time.get_ticks_msec() - _last_active_msec > kForgotMsec:
				queue_free()
				DB.call_deferred("emit_signal", "sDbConnsChanged")
