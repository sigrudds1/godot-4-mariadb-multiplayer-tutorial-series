# "res://AuthServer.gd"
extends Node

enum eDbReply{
	OK,
	UNAME_UNAVAILABLE,
	DNAME_UNAVAILABLE,
	CREATED,
	LOCKED,
	LOGIN_ATTEMPT_EXCEEDED,
	NOT_EXIST,
	LOGIN_SUCCESS,
	LOGIN_FAIL,
}

enum eAcctStatusBit{
	ONLINE = 1,
	BIT2 = 2,
	BIT3 = 4,
	BIT4 = 8,
	BIT5 = 16,
	BIT6 = 32,
	VERIFIED = 64,
	LOCKED = 128
}

enum eFuncCode{
	CREATE_ACCOUNT = 1,
	CHANGE_PASSWORD,
	CONNECT_PLYR,
	DISCONNECT_PLYR,
	LOGIN,
	RESET_PASSWORD
}

var _dispatcher: Dictionary = {
	eFuncCode.LOGIN:           Callable(self, "_handle_login"),
	eFuncCode.CHANGE_PASSWORD: Callable(self, "_handle_change_password"),
	eFuncCode.CONNECT_PLYR:    Callable(self, "_handle_change_status"),
	eFuncCode.DISCONNECT_PLYR: Callable(self, "_handle_change_status"),
	eFuncCode.CREATE_ACCOUNT:  Callable(self, "_handle_create_account"),
	eFuncCode.RESET_PASSWORD:  Callable(self, "_handle_reset_password"),
}

const kConnTimout: int = 2000
const kLoginAttemptsLockout: int = 3
const kLockoutTime: int = 900

var _tcp_srvr: TCPServer
var _tcp_port: int
var _tcp_max_conns: int
var _tcp_active_conns: int = 0
var _stop: bool = false


func _ready() -> void:
	if CFG.sCFG_Changed.connect(self._change_cfg) != OK:
		print_debug("connection failed")
	
	#var email: String = "some_email@someplace.nul"
	#var displayname: String = "some_user"
	#var pswd: String = "some_password"


func _process(_delta: float) -> void:
	if _stop:
		return
	
	if NetTool.tcp_srvr_is_running(_tcp_srvr):
		_chk_incomming()
	else:
		_srvr_start()


func _change_cfg() -> void:
	if !CFG.data.has_all(CFG.kCfgJsonKeys):
		printerr("res://AuthServer.gd:_change_cfg() missing keys")
		await get_tree().create_timer(1.0).timeout
		call_deferred("_change_cfg")
		return
	
	_stop = true
	_tcp_port = CFG.data["gw_listen_port"]
	_tcp_max_conns = CFG.data["gw_max_conns"]
	_srvr_start()
	_stop = false


func _chk_incomming() -> void:
	if _tcp_srvr.is_connection_available():
		var tcp_peer: StreamPeerTCP = _tcp_srvr.take_connection()
		#print("tcp_peer", tcp_peer)
		if _tcp_active_conns < CFG.data["gw_max_conns"]:
			var thr: Thread = Thread.new()
			var err: int = thr.start(_tcp_thread.bind(tcp_peer, thr))
			if err != OK:
				printerr("res://AuthServer.gd:_chk_incomming() thread start err_code:" + str(err))
				tcp_peer = NetTool.tcp_disconnect(tcp_peer)
			else:
				_tcp_active_conns += 1
		else:
			print("res://AuthServer.gd:_chk_incomming() drop peer:", tcp_peer.get_connected_host())
			tcp_peer = NetTool.tcp_disconnect(tcp_peer)


func _dispatch_call(p_code: int, p_peer: StreamPeerTCP) -> void:
	var cb: Callable = _dispatcher.get(p_code, null)
	if cb.is_valid():
		cb.callv([p_peer])
	else:
		p_peer.put_16(-ERR_DOES_NOT_EXIST)


func _srvr_start() -> void:
	if !CFG.data.has_all(CFG.kCfgJsonKeys):
		return
	
	if _tcp_srvr == null:
		_tcp_srvr = NetTool.tcp_srvr_create(_tcp_port)
		return
	
	if _tcp_srvr.is_listening():
		_tcp_srvr.stop()
		await get_tree().physics_frame
	
	if _tcp_srvr.listen(_tcp_port) != OK:
		pass


# Using length-prefixed binary protocol
# First 2 bytes are the function, see functions for coding
func _tcp_thread(p_peer: StreamPeerTCP, p_this_thread: Thread) -> void:
	var avail_bytes: int = 0
	var idle_tm: int = Time.get_ticks_msec() + kConnTimout
	while Time.get_ticks_msec() < idle_tm:
		if  !NetTool.tcp_is_conn(p_peer):
			break
		avail_bytes = p_peer.get_available_bytes()
		if avail_bytes < 4: # need 4 bytes min
			continue
	
	if NetTool.tcp_is_conn(p_peer) and avail_bytes > 3:
		var func_code: int = p_peer.get_u16()
		_dispatch_call(func_code, p_peer)
		#call_deferred("_dispatch_call", func_code, p_peer)
	
	call_deferred("_tcp_thread_stop", p_this_thread)


func _tcp_thread_stop(p_thread: Thread) -> void:
	Utils.thread_wait_stop(p_thread)
	_tcp_active_conns -= 1


func _handle_create_account(p_peer: StreamPeerTCP) -> void:
	print("_handle_create_account")
	# read username (email)
	var email: String = p_peer.get_utf8_string()
	if not Sanitize.check_email(email):
		printerr("Sanity check failed on user email:", email)
		_put_error_to_stream_and_quit(p_peer, -ERR_INVALID_DATA)
		return 
	
	# read display name
	var displayname: String = p_peer.get_utf8_string()
	if not Sanitize.check_display_name(displayname):
		printerr("Sanity check failed on user display name:", email)
		_put_error_to_stream_and_quit(p_peer, -ERR_INVALID_DATA)
		return
	
	# read password
	var pswd: String = p_peer.get_utf8_string()
	if not Sanitize.check_password_plain(pswd):
		printerr("Sanity check failed on user password:", pswd)
		_put_error_to_stream_and_quit(p_peer, -ERR_INVALID_DATA)
		return
	
	# For strict typing and lambda scope we need to use a helper class
	# Can't use self as it's not seen in the lambda scope even though self is the entire script,
	#	classes are global scope type, in this case script scope with a local function instance.
	var qr: QueryResult = QueryResult.new()
	qr.err = OK
	
	var params: Array[Dictionary] = [
		{MariaDBConnector.FT_VARCHAR: email},
		{MariaDBConnector.FT_VARCHAR: displayname}]
	
	var tasks: Array[DbTask] = []
	var task := DbTask.new(
		DB.eStmt.QRY_CHK_IF_PLYR,
		params,
		func(p_res: Array[Dictionary]) -> void:
			qr.rows = p_res, # You need a global container inside lambdas
		func(p_err: int) -> void:
			qr.err = p_err # You need a global container inside lambdas
	)
	tasks = [task]
	
	var db_conn: DbConn = DB.get_db_conn_thread_only()
	var timeout_ms: int = Time.get_ticks_msec() + kConnTimout
	while db_conn == null and Time.get_ticks_msec() < timeout_ms:
		OS.delay_msec(10)
		db_conn = DB.get_db_conn_thread_only()
	
	if db_conn != null:
		db_conn.do_tasks(tasks)
		db_conn.issued = false
		db_conn = null
	else:
		_put_error_to_stream_and_quit(p_peer, -ERR_BUSY)
		return
	if qr.err != OK:
		_put_error_to_stream_and_quit(p_peer, -qr.err)
		return 
	
	if qr.rows.size() > 0:
		if qr.rows[0]["email"] == email:
			_put_error_to_stream_and_quit(p_peer, eDbReply.UNAME_UNAVAILABLE)
			return
		if qr.rows[0]["display_name"] == displayname:
			_put_error_to_stream_and_quit(p_peer, eDbReply.DNAME_UNAVAILABLE)
			return
		_put_error_to_stream_and_quit(p_peer, -ERR_DUPLICATE_SYMBOL)
		return
	
	var hasher: Argon2Hasher = Argon2Hasher.new()
	var salt: String = hasher.generate_b64_salt()
	var pswd_hash: String = hasher.hash_password_with_salt(pswd, salt)
	
	qr.err = OK
	
	params = [
		{MariaDBConnector.FT_TINYINT_U: eAcctStatusBit.ONLINE},
		{MariaDBConnector.FT_VARCHAR: email},
		{MariaDBConnector.FT_VARCHAR: displayname},
		{MariaDBConnector.FT_VARCHAR: pswd_hash},
		{MariaDBConnector.FT_VARCHAR: salt},
		{MariaDBConnector.FT_TINYINT_U: 1}
	]
	
	task = DbTask.new(
		DB.eStmt.CMD_INSERT_PLYR,
		params,
		func(p_res: Dictionary) -> void:
			qr.res = p_res, # You need a global container inside lambdas
		func(p_err: int) -> void:
			qr.err = p_err # You need a global container inside lambdas
	)
	tasks = [task]
	
	timeout_ms = Time.get_ticks_msec() + kConnTimout
	while db_conn == null and Time.get_ticks_msec() < timeout_ms:
		OS.delay_msec(10)
		db_conn = DB.get_db_conn_thread_only()
	if db_conn != null:
		db_conn.do_tasks(tasks)
		db_conn.issued = false
	else:
		_put_error_to_stream_and_quit(p_peer, -ERR_BUSY)
		return
	
	if qr.err != OK:
		_put_error_to_stream_and_quit(p_peer, -qr.err)
		return
	
	p_peer.put_16(eDbReply.CREATED)
	
	var last_insert_id: int = qr.res["last_insert_id"]
	p_peer.put_u32(last_insert_id)
	
	OS.delay_msec(100)
	p_peer = NetTool.tcp_disconnect(p_peer)


func _handle_login(p_peer: StreamPeerTCP) -> void:
	# read username  (email)
	var email: String = p_peer.get_utf8_string()
	#print("email:", email)
	
	var params: Array[Dictionary] = [
		{MariaDBConnector.FT_VARCHAR: email}]
	
	# For strict typing and lambda scope we need to use a helper class
	# We could use self but then that is not seen in the function scope, self is the entire script,
	#	classes are global scope type, in this case script scope with a local function intance.
	var qr: QueryResult = QueryResult.new()
	qr.err = OK
	
	var tasks: Array[DbTask] = []
	var task: DbTask = DbTask.new(
		DB.eStmt.QRY_PLYR_BY_EMAIL,
		params,
		func(p_res: Array[Dictionary]) -> void:
			qr.rows = p_res, # You need a global container inside lambdas
		func(p_err: int) -> void:
			qr.err = p_err # You need a global container inside lambdas
	)
	tasks.push_back(task)
	
	var db_conn: DbConn = DB.get_db_conn_thread_only()
	var timeout_ms: int = Time.get_ticks_msec() + kConnTimout
	while db_conn == null and Time.get_ticks_msec() < timeout_ms:
		OS.delay_msec(10)
		db_conn = DB.get_db_conn_thread_only()
	
	if db_conn != null:
		db_conn.do_tasks(tasks)
		db_conn.issued = false
		db_conn = null
	else:
		_put_error_to_stream_and_quit(p_peer, -ERR_BUSY)
		return
	if qr.err != OK:
		_put_error_to_stream_and_quit(p_peer, -qr.err)
		return
	
	if qr.rows.size() != 1:
		_put_error_to_stream_and_quit(p_peer, eDbReply.NOT_EXIST)
		return
	
	var row: Dictionary = qr.rows[0]
	var status: int = row["status"]
	if status & eAcctStatusBit.LOCKED == eAcctStatusBit.LOCKED:
		_put_error_to_stream_and_quit(p_peer, eDbReply.LOCKED)
		return
	
	var login_attempts: int = row["login_attempts"]
	var time_diff: int = row["time_diff"]
	if login_attempts >= kLoginAttemptsLockout and kLockoutTime > time_diff:
		_put_error_to_stream_and_quit(p_peer, eDbReply.LOGIN_ATTEMPT_EXCEEDED)
		return
	
	var pswd: String = p_peer.get_utf8_string()
	#print("pswd:", pswd)
	var salt: String = row["argon2_salt"]
	var pswd_hash: String = row["argon2_hash"]
	var hasher: Argon2Hasher = Argon2Hasher.new()
	var verified: bool = hasher.verify_password_with_salt(pswd, salt, pswd_hash)
	var plyr_id: int = row["plyr_id"]
	

	if not verified:
		_put_error_to_stream_and_quit(p_peer, eDbReply.LOGIN_FAIL)
		login_attempts += 1
		_update_plyr_login(qr, 0, login_attempts, plyr_id)
		return
	else:
		_update_plyr_login(qr, 0, 0, plyr_id)
	#print( "after pswd check",  Time.get_ticks_msec())
	p_peer.put_u32(plyr_id)
	var displayname: String = row["display_name"]
	p_peer.put_utf8_string(displayname)
	OS.delay_msec(100)
	p_peer = NetTool.tcp_disconnect(p_peer)


func _put_error_to_stream_and_quit(p_peer:StreamPeerTCP, p_error_code:int) -> void:
	print("_put_error_to_stream_and_quit error:", p_error_code)
	if p_peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		print("_put_error_to_stream_and_quit peer not connected")
		return
	# Maybe put in extra logging info like IP, account info, etc.
	p_peer.put_16(p_error_code)
	if p_peer.poll() != OK:
		pass
	OS.delay_msec(100)
	p_peer = NetTool.tcp_disconnect(p_peer)


# DbConn and QueryResult are passed by reference and instance is updated everywhere
func _update_plyr_login(p_qr: QueryResult, p_status: int,
		p_login_attempts: int, p_plyr_id: int) -> void:

	p_qr.err = OK
	var params: Array[Dictionary] = [
		{MariaDBConnector.FT_TINYINT_U: p_status},
		{MariaDBConnector.FT_TINYINT_U: p_login_attempts},
		{MariaDBConnector.FT_INT_U: p_plyr_id},
	]
	var task := DbTask.new(
		DB.eStmt.CMD_UPDATE_PLYR_LOGIN,
		params,
		func(p_res: Dictionary) -> void:
			p_qr.res = p_res,
		func(p_err: int) -> void:
			p_qr.err = p_err
	)
	var tasks: Array[DbTask] = [task]
	
	var db_conn: DbConn = DB.get_db_conn_thread_only()
	var timeout_ms: int = Time.get_ticks_msec() + kConnTimout
	while db_conn == null and Time.get_ticks_msec() < timeout_ms:
		OS.delay_msec(10)
		db_conn = DB.get_db_conn_thread_only()
	
	if db_conn != null:
		db_conn.do_tasks(tasks)
		db_conn.issued = false
		db_conn = null
	else:
		p_qr.err = ERR_DATABASE_CANT_READ


# Helper class for lambda scope
class QueryResult:
	var err: int
	var res: Dictionary # response for inserts, updates, delete, etc
	var rows: Array[Dictionary] # response for select
