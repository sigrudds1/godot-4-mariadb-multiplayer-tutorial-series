# "res://script_templates/Node/minimal.gd"
extends Node

enum FuncCode {
	DB_INSERT_OR_UPDATE_PLYR,
	DB_INSERT_MSG_BLOCKED_PLYR,
	DB_DELETE_MSG_BLOCKED_PLYR,
	DB_SELECT_MSG_BLOCKED_BY_DISPLAY_NAMES,
	#DB_SELECT_PLYR_INVENTORY,
	#DB_UPDATE_PLYR_INVENTORY,
	#DB_DELETE_FROM_PLYR_INVENTORY,
	ADD_PLYR_TO_MATCH_QUEUE,
	DELETE_PLYR_FROM_MATCH_QUEUE,
}

const kExpireMsec: int = 20000
const kTcpFlushDelay: int = 50

var func_lookup: Dictionary = {
	FuncCode.DB_INSERT_OR_UPDATE_PLYR: Callable(self, "insert_or_update_plyr"),
}

var _listening: bool = false
var _tcp_srvr: TCPServer
var _tcp_max_conns: int = 5
var _tcp_conn_timeout: int = 2000
var _tcp_conns: int = 0
var _tcp_listen_port: int
var _bind_address: String = "*" # Bind Address is * (all), if multiple servers will be connecting.
var _semephore: Semaphore = Semaphore.new()
var _running: bool = true


func _ready() -> void:
	if Cfg.sCfgChanged.connect(_change_cfg): pass
	_listening = true


# Using _process to poll as fast as posible
func _process(_delta: float) -> void:
	if not _listening:
		return
	
	if NetTool.tcp_srvr_is_running(_tcp_srvr):
		_chk_incomming()
	else:
		_srvr_start()


func _exit_tree() -> void:
	#print("_exit_tree")
	_listening = false
	_running = false
	_semephore.post()


func insert_or_update_plyr(p_tcp_peer: StreamPeerTCP, p_this_thread: Thread) -> void:
	var plyr_id: int = p_tcp_peer.get_u32()
	print("insert_or_update_plyr plyr_id:", plyr_id)
	Callable(Utils, "thread_wait_stop").call_deferred(p_this_thread)


func _change_cfg() -> void:
	_listening = false
	var base_port: int = Cfg.data.get("listen_port")
	if base_port == null or base_port < 1024:
		printerr("bad listen port:", base_port)
		return
	
	_bind_address = Cfg.data.get("bind_address")
	if _bind_address == null or _bind_address == "":
		printerr("bad bind address:", _bind_address)
		return
	
	_tcp_max_conns = Cfg.data.get("max_conns", 5)
	_tcp_listen_port = base_port + Cfg.server_id
	
	_srvr_start()
	_listening = true
	if NetTool.tcp_srvr_is_running(_tcp_srvr):
		print("Listening on port:", _tcp_listen_port)
	else:
		print("TCP Server failed to start")


func _chk_incomming() -> void:
	if _tcp_srvr.is_connection_available():
		var tcp_peer: StreamPeerTCP = _tcp_srvr.take_connection()
		print("incomming tcp peer:", tcp_peer)
		if _tcp_conns < _tcp_max_conns:
			var thr: Thread = Thread.new()
			var err_code: Error = thr.start(_tcp_thread.bind(tcp_peer, thr))
			if err_code != OK:
				printerr("srvr thread start error code:" + str(err_code))
				# TODO - Send error to client
				tcp_peer = NetTool.tcp_disconnect(tcp_peer)
		else:
			tcp_peer = NetTool.tcp_disconnect(tcp_peer)


func _func_two(p_tcp_peer: StreamPeerTCP, p_this_thread: Thread) -> void:
	var plyr_id: int = p_tcp_peer.get_u32()
	print("_func_two plyr_id:", plyr_id)
	Callable(Utils, "thread_wait_stop").call_deferred(p_this_thread)


func _srvr_start() -> void:
	if _tcp_srvr == null:
		_tcp_srvr = NetTool.tcp_srvr_create(_tcp_listen_port, _bind_address)
		return
	
	if _tcp_srvr.is_listening():
		_tcp_srvr.stop()
		await get_tree().physics_frame
	
	var error: int = _tcp_srvr.listen(_tcp_listen_port, _bind_address)
	if error != OK:
		_listening = false
		printerr("TCP listen error:", error)
		await TimeLapse.sOneSecondLapsed
		_listening = true


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
	
	# Only call inside a thread or it will block main thread, use await inside main thread
	OS.delay_msec(kTcpFlushDelay)
	p_tcp_peer = NetTool.tcp_disconnect(p_tcp_peer)
	
	_tcp_conns -= 1
	Callable(Utils, "thread_wait_stop").call_deferred(p_this_thread)
