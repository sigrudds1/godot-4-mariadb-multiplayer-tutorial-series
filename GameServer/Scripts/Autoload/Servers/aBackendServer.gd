# "res://script_templates/Node/minimal.gd"
extends Node

enum FuncCode {
	CREATE_ACCOUNT = 1,
	CHANGE_PASSWORD,
	CONNECT_PLYR,
	DISCONNECT_PLYR,
	LOGIN,
	RESET_PASSWORD
}

const kExpireMsec: int = 20000
const kTcpFlushDelay: int = 50

var func_lookup: Dictionary = {
	FuncCode.CONNECT_PLYR: Callable(self, "_connect_player")
}

var _stop_listening: bool = false
var _tcp_srvr: TCPServer
var _tcp_max_conns: int = 5
var _tcp_conn_timeout: int = 2000
var _tcp_conns: int = 0
var _tcp_listen_port: int
var _bind_address: String


func _ready() -> void:
	if CFG.sCfgChanged.connect(_change_cfg):
		pass


func _process(_delta: float) -> void:
	if _stop_listening:
		return
	
	if NetTool.tcp_srvr_is_running(_tcp_srvr):
		_chk_incomming()
	else:
		_srvr_start()


func _change_cfg() -> void:
	_stop_listening = true
	var base_port: int = CFG.data.get("backend_base_port")
	if base_port == null or base_port < 1024:
		printerr("bad backend listen port:", base_port)
		return
	
	_tcp_listen_port = base_port + CFG.server_id
	_bind_address = CFG.data.get("backend_bind_address")
	if _bind_address == null or _bind_address == "":
		_bind_address = "*"
	
	_srvr_start()
	_stop_listening = false
	if NetTool.tcp_srvr_is_running(_tcp_srvr):
		print("Backend listening on port:", _tcp_listen_port)
	else:
		print("Backend not listening")
	


func _chk_incomming() -> void:
	if _tcp_srvr.is_connection_available():
		var tcp_peer: StreamPeerTCP = _tcp_srvr.take_connection()
		print("Backend._chk_incomming tcp_peer:", tcp_peer)
		if _tcp_conns < _tcp_max_conns:
			var thr: Thread = Thread.new()
			var err_code: Error = thr.start(_tcp_thread.bind(tcp_peer, thr))
			if err_code != OK:
				printerr("backend srvr thread start error code:" + str(err_code))
				tcp_peer = NetTool.tcp_disconnect(tcp_peer)
		else:
			tcp_peer = NetTool.tcp_disconnect(tcp_peer)

# plyr connect credentials from gateway
# var token: String = displaY_name + login_hash from gateway
# var plyr_id: int = 1  from gateway
# awaiting_login[token_example] = {"plyr_id": plyr_id, "display_name": display_name}
func _connect_player(p_tcp_peer: StreamPeerTCP) -> void:
	var plyr_id: int = p_tcp_peer.get_u32()
	if ConnectionIface.plyrs_online.get(plyr_id) != null:
		# You could disconnect player and reconnect, in case they forgot to log off elsewhere
		p_tcp_peer.put_16(-ERR_ALREADY_EXISTS)
		return
	var display_name: String = p_tcp_peer.get_utf8_string()
	var login_hash: String = p_tcp_peer.get_utf8_string()
	var connection_token: String = display_name + login_hash
	ConnectionIface.awaiting_login[connection_token] = {
		"plyr_id": plyr_id, 
		"display_name": display_name,
		"expires": Time.get_ticks_msec() + kExpireMsec
	}
	#print("BackendServer ConnectionIface.awaiting_login:", ConnectionIface.awaiting_login)
	p_tcp_peer.put_16(OK)


func _srvr_start() -> void:
	if _tcp_srvr == null:
		_tcp_srvr = NetTool.tcp_srvr_create(_tcp_listen_port, _bind_address)
		return
	
	if _tcp_srvr.is_listening():
		_tcp_srvr.stop()
		await get_tree().physics_frame
	
	var error: int = _tcp_srvr.listen(_tcp_listen_port, _bind_address)
	if error != OK:
		_stop_listening = true
		printerr("BackendServer listen error:", error)
		await get_tree().create_timer(1.0).timeout
		_stop_listening = false
		


func _tcp_thread(p_tcp_peer: StreamPeerTCP, p_this_thread: Thread) -> void:
	_tcp_conns += 1
	
	var avail_bytes: int = 0
	var idle_tm: int = Time.get_ticks_msec() + _tcp_conn_timeout
	while NetTool.tcp_is_conn(p_tcp_peer) and Time.get_ticks_msec() < idle_tm and avail_bytes < 4:
		avail_bytes = p_tcp_peer.get_available_bytes()
		if avail_bytes < 2: # need 4 bytes min
			# Only call inside a thread or it will block main thread, use await inside main thread
			OS.delay_msec(kTcpFlushDelay)
			continue
	
	if NetTool.tcp_is_conn(p_tcp_peer) and avail_bytes > 1:
		var func_code: int = p_tcp_peer.get_u16()
		#print("Backend._tcp_thread func_code:", func_code)
		# FuncCode dispatching, faster than if-elif and match tree
		var cb: Callable = func_lookup.get(func_code, null)
		if cb.is_valid():
			cb.call(p_tcp_peer)
		else:
			p_tcp_peer.put_16(-ERR_DOES_NOT_EXIST)
	
	_tcp_conns -= 1
	# Only call inside a thread or it will block main thread, use await inside main thread
	OS.delay_msec(kTcpFlushDelay)
	p_tcp_peer = NetTool.tcp_disconnect(p_tcp_peer)
	
	Callable(Utils, "thread_wait_stop").call_deferred(p_this_thread)
