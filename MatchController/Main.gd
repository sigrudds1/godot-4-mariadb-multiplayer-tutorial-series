# "res://script_templates/Node/minimal.gd"
extends Node

enum FuncCode {
	ADD_PLYR,
	REMOVE_PLYR
}

const kExpireMsec: int = 20000
const kTcpFlushDelay: int = 50

var func_lookup: Dictionary = {
	FuncCode.ADD_PLYR: Callable(self, "_add_plyr"),
	FuncCode.REMOVE_PLYR: Callable(self, "_remove_plyr")
}

var _listening: bool = false
var _tcp_srvr: TCPServer
var _tcp_max_conns: int = 5
var _tcp_conn_timeout: int = 2000
var _tcp_conns: int = 0
var _tcp_listen_port: int
var _bind_address: String = "*" # Bind Address is * (all), multiple game servers will be connecting.

var _awaiting_match: Array[MatchPlyr] = []

var _match_semaphore: Semaphore = Semaphore.new()
var _running: bool = true


func _ready() -> void:
	if Cfg.sCfgChanged.connect(_change_cfg): pass
	_listening = true
	
	if TimeLapse.sOneSecondLapsed.connect(_post_awaiting_match_thread) != OK: pass
	
	var thr: Thread = Thread.new()
	var err_code: Error = thr.start(_check_awaiting_match_thr_func.bind(thr))
	if err_code != OK: 
		printerr("MatchController _check_awaiting_match_thr_func start error code:" + str(err_code))


func _process(_delta: float) -> void:
	if not _listening:
		return
	
	if NetTool.tcp_srvr_is_running(_tcp_srvr):
		_chk_incomming()
	else:
		_srvr_start()


func _exit_tree() -> void:
	#print("MatchController _exit_tree")
	_listening = false
	_running = false
	_match_semaphore.post()


func _add_plyr(p_tcp_peer: StreamPeerTCP) -> void:
	var plyr_id: int = p_tcp_peer.get_u32()


func _change_cfg() -> void:
	_listening = false
	var base_port: int = Cfg.data.get("listen_port")
	if base_port == null or base_port < 1024:
		printerr("bad listen port:", base_port)
		return
	
	_tcp_max_conns = Cfg.data.get("max_conns", 5)
	_tcp_listen_port = base_port + Cfg.server_id
	
	_srvr_start()
	_listening = true
	if NetTool.tcp_srvr_is_running(_tcp_srvr):
		print("Listening on port:", _tcp_listen_port)
	else:
		print("TCP Server failed to start")


func _check_awaiting_match_thr_func(p_this_thread: Thread) -> void:
	#print("_check_awaiting_match_thr_func thread:", p_this_thread)
	while _running:
		OS.delay_msec(33)
		_match_semaphore.wait()
		var awaiting_match: int = _awaiting_match.size()
	
	#print("_check_awaiting_match_thr_func, exiting")
	Callable(Utils, "thread_wait_stop").call_deferred(p_this_thread)


func _chk_incomming() -> void:
	if _tcp_srvr.is_connection_available():
		var tcp_peer: StreamPeerTCP = _tcp_srvr.take_connection()
		print("incomming tcp peer:", tcp_peer)
		if _tcp_conns < _tcp_max_conns:
			var thr: Thread = Thread.new()
			var err_code: Error = thr.start(_tcp_thread.bind(tcp_peer, thr))
			if err_code != OK:
				printerr("srvr thread start error code:" + str(err_code))
				tcp_peer = NetTool.tcp_disconnect(tcp_peer)
		else:
			tcp_peer = NetTool.tcp_disconnect(tcp_peer)


func _post_awaiting_match_thread() -> void:
	_match_semaphore.post()


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
