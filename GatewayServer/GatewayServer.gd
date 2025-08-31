# "res://GatewayServer.gd"
extends Node

enum DbReply {
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

enum AcctStatusBit{
	ONLINE = 1,
	BIT2 = 2,
	BIT3 = 4,
	BIT4 = 8,
	BIT5 = 16,
	BIT6 = 32,
	VERIFIED = 64,
	LOCKED = 128
}

enum FuncCode {
	CREATE_ACCOUNT = 1,
	CHANGE_PASSWORD,
	CONNECT_PLYR,
	DISCONNECT_PLYR,
	LOGIN,
	RESET_PASSWORD
}

const kDataStreamTimeout: int = 2000 
const kDbConnTimeout: int = 5000 # need extra time argon2 is slow
const kLoopDelay: = 17
const kTcpFlushDelay: int = 50

var _db_reply_func_lookup: Dictionary = {
	DbReply.UNAME_UNAVAILABLE:			Callable(self, "_send_tls_peer_code"),
	DbReply.DNAME_UNAVAILABLE:			Callable(self, "_send_tls_peer_code"),
	DbReply.CREATED:					Callable(self, "_handle_db_login_success"),
	DbReply.LOCKED:					Callable(self, "_send_tls_peer_code"),
	DbReply.LOGIN_ATTEMPT_EXCEEDED:	Callable(self, "_send_tls_peer_code"),
	DbReply.NOT_EXIST:					Callable(self, "_send_tls_peer_code"),
	DbReply.LOGIN_SUCCESS:				Callable(self, "_handle_db_login_success"),
	DbReply.LOGIN_FAIL:				Callable(self, "_send_tls_peer_code"),
}

var _func_code_func_lookup: Dictionary = {
	FuncCode.CREATE_ACCOUNT:	Callable(self, "_handle_fn_create_account"),
	#FuncCode.CHANGE_PASSWORD:	Callable(self, "_dummy_func"),
	#FuncCode.CONNECT_PLYR:		Callable(self, "_dummy_func"),
	#FuncCode.DISCONNECT_PLYR:	Callable(self, "_dummy_func"),
	FuncCode.LOGIN:			Callable(self, "_handle_fn_login"),
	#FuncCode.RESET_PASSWORD:	Callable(self, "_dummy_func")
}

var _auth_srvr_url: String
var _auth_srvr_port: int
var _game_srvr_url: String
var _game_srvr_port: int
var _game_srvr_be_url: String
var _game_srvr_be_port: int

var _tcp_srvr: TCPServer
var _tcp_port: int
var _tcp_max_conns: int
var _tls_active_conns: int = 0
var _stop: bool = false


func _ready() -> void:
	Cfg.sChanged.connect(_change_cfg)


func _process(_delta: float) -> void:
	if _stop:
		return
	
	if NetTool.tcp_srvr_is_running(_tcp_srvr):
		_chk_incomming()
	else:
		_srvr_start()

func _exit_tree() -> void:
	_stop = true


# TESTING CODE
func _generate_rng_display_name() -> String:
	const ALPHA: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
	const REMAIN: String = ALPHA + " 0123456789_.#&$-"
	randomize()
	
	var d_name := ""
	# First 3 characters: must be letters
	for i in range(3):
		d_name += ALPHA[randi() % ALPHA.length()]
	
	var remain_len := randi() % (61)
	for i in range(remain_len):
		d_name += REMAIN[randi() % REMAIN.length()]
	
	return d_name


func _test_create_acct() -> void:
	var display_name: String = _generate_rng_display_name()
	var cleaned := display_name
	cleaned = cleaned.replace(" ", "_")
	cleaned = cleaned.replace("#", "_")
	cleaned = cleaned.replace("&", "-")
	cleaned = cleaned.replace("$", "-")
	
	cleaned = "bad&display name"
	var email: String = cleaned.to_lower() + "@someplace.nul"
	var pswd: String = "some_password"
	
	email = "some_email@someplace.nul"
	pswd = "some_password"
	display_name = "some_player" 
	
	var tcp_peer: StreamPeerTCP = NetTool.tcp_connect(_auth_srvr_url, _auth_srvr_port)
	if tcp_peer == null:
		return
	tcp_peer.put_u16(FuncCode.CREATE_ACCOUNT)
	tcp_peer.put_utf8_string(email)
	tcp_peer.put_utf8_string(display_name)
	tcp_peer.put_utf8_string(pswd)
	
	_get_auth_srvr_res(tcp_peer, StreamPeerTLS.new())
	tcp_peer = NetTool.tcp_disconnect(tcp_peer)


func _test_login_thread(p_this_thread: Thread = null) -> void:
	while not _stop:
		var email: String = "some_email@someplace.nul"
		var pswd: String = "some_password"
		# lenth encoding = lenc
		# func code<2>, email lenc<2>, email byte count<?>, pswd lenc<2>  pswd byte count<?>
		var tcp_peer: StreamPeerTCP = NetTool.tcp_connect(_auth_srvr_url, _auth_srvr_port)
		if tcp_peer == null:
			return
		tcp_peer.put_u16(FuncCode.LOGIN)
		tcp_peer.put_utf8_string(email)
		tcp_peer.put_utf8_string(pswd)
		
		_get_auth_srvr_res(tcp_peer, StreamPeerTLS.new())
		tcp_peer = NetTool.tcp_disconnect(tcp_peer)
	
	call_deferred("_thread_stop", p_this_thread)


# SRVR CODE
func _change_cfg() -> void:
	if not Cfg.data.has_all(Cfg.kCfgJsonKeys):
		printerr("res://GatewayServer.gd:_change_cfg() missing keys")
		await get_tree().create_timer(1.0).timeout
		call_deferred("_change_cfg")
		return
	
	_stop = true
	_auth_srvr_url = Cfg.data["auth_server_url"]
	_auth_srvr_port = Cfg.data["auth_server_port"]
	# We will keep a list of game servers and gateway association in the auth DB, for now just 1
	_game_srvr_be_port = Cfg.data["game_server_backend_port"]
	_game_srvr_be_url = Cfg.data["game_server_backend_url"]
	_game_srvr_url = Cfg.data["game_server_url"]
	_game_srvr_port = Cfg.data["game_server_port"]
	_tcp_port = Cfg.data["gw_listen_port"]
	_tcp_max_conns = Cfg.data["gw_max_conns"]
	_srvr_start()
	_stop = false
	
	#_test_create_acct()
	#
	#var thr := Thread.new()
	#if thr.start(_test_login_thread.bind(thr)) != OK:
		#printerr("thread failed to start")


func _chk_incomming() -> void:
	if _tcp_srvr.is_connection_available():
		var tcp_peer: StreamPeerTCP = _tcp_srvr.take_connection()
		print("tcp_peer", tcp_peer)
		if _tls_active_conns < Cfg.data["gw_max_conns"]:
			var thr := Thread.new()
			var err: int = thr.start(_tcp_thread.bind(tcp_peer, thr))
			if err != OK:
				printerr(":_chk_incomming() thread start err_code:" + str(err))
				tcp_peer = NetTool.tcp_disconnect(tcp_peer)
		else:
			print("_chk_incomming() drop peer:", tcp_peer.get_connected_host())
			tcp_peer = NetTool.tcp_disconnect(tcp_peer)


func _dummy_func(_plyr_tls_peer: StreamPeerTLS,
		_code: int = DbReply.OK, 
		_db_tcp_peer: StreamPeerTCP = null) -> void:
	return


func _get_auth_srvr_res(p_db_tcp_peer: StreamPeerTCP, p_plyr_tls_peer: StreamPeerTLS) -> void:
	var time_out_ms: int = Time.get_ticks_msec() + kDbConnTimeout
	
	while Time.get_ticks_msec() < time_out_ms and NetTool.tcp_is_connected(p_db_tcp_peer):
		var avail_bytes: int = p_db_tcp_peer.get_available_bytes()
		if avail_bytes < 2: 
			continue
		
		var reply_code: int = p_db_tcp_peer.get_16()
		if reply_code == DbReply.OK:
			time_out_ms = Time.get_ticks_msec() + kDataStreamTimeout
			continue
		
		var cb: Callable = _db_reply_func_lookup.get(reply_code, null)
		if cb.is_valid():
			cb.call(p_plyr_tls_peer, reply_code, p_db_tcp_peer)
		else:
			_send_tls_peer_code(p_plyr_tls_peer, -ERR_DOES_NOT_EXIST)
		break


func _handle_db_login_success(p_plyr_tls_peer: StreamPeerTLS,
		p_code: int = DbReply.OK,
		p_db_tcp_peer: StreamPeerTCP = null) -> void:
	
	var plyr_id: int = p_db_tcp_peer.get_u32()
	var display_name: String = p_db_tcp_peer.get_utf8_string()
	print("_login_success Player ID:%d, Display Name:%s" % [plyr_id, display_name])
	
	if p_plyr_tls_peer == null:
		return
	if not NetTool.tls_is_connected(p_plyr_tls_peer):
		return
	# Send the plyr_id, display name and login hash to game(lobby) srvr, 
	#	lookup will be display name + login hash
	var gmsrvr_peer: StreamPeerTCP = NetTool.tcp_connect(_game_srvr_be_url, _game_srvr_be_port)
	if NetTool.tcp_is_connected(gmsrvr_peer):
		var a2h := Argon2Hasher.new()
		var login_hash: String = a2h.generate_b64_salt()
		
		gmsrvr_peer.put_16(FuncCode.CONNECT_PLYR)
		gmsrvr_peer.put_u32(plyr_id)
		gmsrvr_peer.put_utf8_string(display_name)
		gmsrvr_peer.put_utf8_string(login_hash)
		
		var avail_bytes: int = gmsrvr_peer.get_available_bytes()
		print("Time.get_ticks_msec()", Time.get_ticks_msec())
		var timeout: int = Time.get_ticks_msec() + 20000
		while (NetTool.tcp_is_connected(gmsrvr_peer) and Time.get_ticks_msec() < timeout and 
				avail_bytes == 0):
			avail_bytes = gmsrvr_peer.get_available_bytes()
			OS.delay_msec(kTcpFlushDelay)
		
		print("Time.get_ticks_msec()", Time.get_ticks_msec())
		
		print("_handle_db_login_success avail_bytes:", avail_bytes)
		print("_handle_db_login_success gmsrvr_peer _is_connected:", NetTool.tcp_is_connected(gmsrvr_peer))
		var status: int = OK
		if avail_bytes > 0:
			status = gmsrvr_peer.get_16()
		else:
			status = -ERR_CANT_CONNECT
		print("_handle_db_login_success status:", status)
		if status == OK:
			p_plyr_tls_peer.put_16(p_code)
			p_plyr_tls_peer.put_utf8_string(_game_srvr_url)
			p_plyr_tls_peer.put_u16(_game_srvr_port)
			p_plyr_tls_peer.put_utf8_string(display_name)
			p_plyr_tls_peer.put_utf8_string(login_hash)
		else:
			p_plyr_tls_peer.put_16(status)
		gmsrvr_peer = NetTool.tcp_disconnect(gmsrvr_peer)
	else:
		p_plyr_tls_peer.put_16(-ERR_CANT_CONNECT)
	
	OS.delay_msec(kTcpFlushDelay)


func _handle_fn_create_account(p_plyr_tls_peer: StreamPeerTLS) -> void:
	var email: String = p_plyr_tls_peer.get_utf8_string()
	var display_name: String = p_plyr_tls_peer.get_utf8_string()
	var pswd: String = p_plyr_tls_peer.get_utf8_string()
	var tcp_peer: StreamPeerTCP = NetTool.tcp_connect(_auth_srvr_url, _auth_srvr_port)
	if tcp_peer == null:
		return
	if not NetTool.tcp_is_connected(tcp_peer):
		return
	tcp_peer.put_u16(FuncCode.CREATE_ACCOUNT)
	tcp_peer.put_utf8_string(email)
	tcp_peer.put_utf8_string(display_name)
	tcp_peer.put_utf8_string(pswd)
	_get_auth_srvr_res(tcp_peer, p_plyr_tls_peer) 
	OS.delay_msec(kLoopDelay) # This is OK, normally will be called from inside _tcp_thread
	tcp_peer = NetTool.tcp_disconnect(tcp_peer)


func _handle_fn_login(p_plyr_tls_peer: StreamPeerTLS) -> void:
	var email: String = p_plyr_tls_peer.get_utf8_string()
	var pswd: String = p_plyr_tls_peer.get_utf8_string()
	var tcp_peer: StreamPeerTCP = NetTool.tcp_connect(_auth_srvr_url, _auth_srvr_port)
	if tcp_peer == null:
		return
	if not NetTool.tcp_is_connected(tcp_peer):
		return
	tcp_peer.put_u16(FuncCode.LOGIN)
	tcp_peer.put_utf8_string(email)
	tcp_peer.put_utf8_string(pswd)
	
	_get_auth_srvr_res(tcp_peer, p_plyr_tls_peer) 
	OS.delay_msec(kLoopDelay) # This is OK, normally will be called from inside _tcp_thread
	tcp_peer = NetTool.tcp_disconnect(tcp_peer)

# caveat to using a dispatcher method, all functions need to have the same parameter signature
func _send_tls_peer_code(p_plyr_tls_peer: StreamPeerTLS,
		p_code: int = DbReply.OK,
		_db_tcp_peer: StreamPeerTCP = null) -> void:
	print("_send_tls_peer_code:", p_code )
	if p_plyr_tls_peer == null:
		return
	if not NetTool.tls_is_connected(p_plyr_tls_peer):
		return
	
	p_plyr_tls_peer.put_16(p_code)


func _srvr_start() -> void:
	if !Cfg.data.has_all(Cfg.kCfgJsonKeys):
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
	var tls_peer := StreamPeerTLS.new()
	var tls_err: int =  tls_peer.accept_stream(p_peer, Cfg.tls_server_opts)
	if tls_err != OK:
		printerr("_tcp_thread TLS err:", tls_err)
		Callable(Utils, "thread_wait_stop").call_deferred(p_this_thread)
		return
	
	_tls_active_conns += 1
	var avail_bytes: int = 0
	var idle_tm: int = Time.get_ticks_msec() + kDataStreamTimeout
	while NetTool.tls_is_connected(tls_peer) and Time.get_ticks_msec() < idle_tm and avail_bytes < 2:
		avail_bytes = tls_peer.get_available_bytes()
	
	print("tls_peer avail_bytes:", avail_bytes)
	if NetTool.tls_is_connected(tls_peer) and avail_bytes > 1:
		var func_code: int = tls_peer.get_u16()
		var cb: Callable = _func_code_func_lookup.get(func_code, null)
		if cb.is_valid():
			cb.call(tls_peer)
		else:
			_send_tls_peer_code(tls_peer, -ERR_DOES_NOT_EXIST)
	
	tls_peer = NetTool.tls_disconnect(tls_peer)
	_tls_active_conns -= 1
	Callable(Utils, "thread_wait_stop").call_deferred(p_this_thread)
