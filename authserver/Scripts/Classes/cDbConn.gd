class_name DbConn extends Node

const kIssuedTimeoutSec: float = 0.5

var issued: bool = false: set = _set_issued

var _busy: bool = false
var _ctx: MariaDBConnectContext
var _db_conn: MariaDBConnector
var _last_active_msec: int


func _notification(p_what: int) -> void:
	if p_what == NOTIFICATION_PREDELETE:
		print("p_what == NOTIFICATION_PREDELETE")
		_db_conn.disconnect_db()


func _init(p_ctx: MariaDBConnectContext) -> void:
	print(self, ": initialized")
	_db_conn = MariaDBConnector.connection_instance(p_ctx)
	if _db_conn == null:
		queue_free()
	
	_ctx = p_ctx
	_last_active_msec = Time.get_ticks_msec()
	# More efficient then timers, coupling ok since TimeLapse is an autoload
	var error: int = TimeLapse.sTenMinuteLapsed.connect(_update_connection)
	if error:
		printerr(self, "Can not connect to TimeLapse.sTenMinuteLapsed")


func do_tasks(p_tasks: Array[DbTask]) -> void:
	_busy = true
	print(p_tasks)
	
	_last_active_msec = Time.get_ticks_msec()
	for task:DbTask in p_tasks:
		print("task stmt:", task.stmt)
		if task.type == DbTask.Types.SELECT:
			_do_query(task)
		else:
			_do_cmd(task)
	_busy = false


func _do_callable(callable: Callable, arg: Variant = null) -> void:
	if callable.is_null():
		return
	
	if callable.get_argument_count() == 0:
		callable.call()
	else:
		callable.call(arg)


func _do_cmd(p_task: DbTask) -> void:
	var res: Dictionary = _db_conn.execute_command(p_task.stmt)
	if _db_conn.last_error == MariaDBConnector.ErrorCode.OK:
		_do_callable(p_task.success_func, res)
	else:
		_do_callable(p_task.fail_func, _db_conn.last_error)


func _do_query(p_task: DbTask) -> void:
	var res: Array[Dictionary] = _db_conn.select_query(p_task.stmt)
	if _db_conn.last_error == MariaDBConnector.ErrorCode.OK:
		_do_callable(p_task.success_func, res)
	else:
		_do_callable(p_task.fail_func, _db_conn.last_error)


func _set_issued(p_state: bool) -> void:
	issued = p_state
	print(self, ":  issued:", issued)
	if issued:
		call_deferred("_watch_issued_timeout")


func _update_connection() -> void:
	if not _busy:
		# MariaDB conections timeout after about 20 min, so we reconnect at 10 min idle
		if Time.get_ticks_msec() - _last_active_msec > 600000:
			_db_conn.disconnect_db()
			DB.sConnectionUpdated.emit()
			queue_free()


func _watch_issued_timeout() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	await tree.create_timer(kIssuedTimeoutSec).timeout
	if issued:
		if not _busy:
			DB.sConnectionUpdated.emit()
			queue_free()
		else:
			call_deferred("_watch_issued_timeout")
	print("left _watch_issued_timeout")
