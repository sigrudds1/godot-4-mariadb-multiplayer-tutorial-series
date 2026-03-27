# "res://Main.gd"
extends Node


enum BusStatus {
	TRANSACTION_TIMEOUT = -3,
	MISSING_FUNC = -2,
	COMM_ERROR = -1,
	OK = 0,
	PROCESSING = 1,
}

enum BussFuncCodes {
	DB_INSERT_OR_UPDATE_PLYR,
	DB_INSERT_MSG_BLOCKED_PLYR,
	DB_DELETE_MSG_BLOCKED_PLYR,
	DB_SELECT_MSG_BLOCKED_BY_DISPLAY_NAMES,
	DB_SELECT_PLYR_INVENTORY,
	DB_UPDATE_PLYR_INVENTORY,
	DB_DELETE_FROM_PLYR_INVENTORY,
	ADD_PLYR_TO_MATCH_QUEUE,
	DELETE_PLYR_FROM_MATCH_QUEUE,
}

enum PacketSegments {
	STATUS,
	DATA
}

const kTcpFlushMsecDelay: int = 50
const kMaxTransactionMsecTime: int = 2000
const kMinTcpBytes: int = 6 # need 6 bytes min, 2 for code and 4 for byte count 

var _bus_funcs: Dictionary = {
	BussFuncCodes.DB_INSERT_OR_UPDATE_PLYR: Callable(self, "insert_or_update_plyr"),
}

var _listening: bool = false
var _tcp_srvr: TCPServer
var _tcp_max_conns: int = 5
var _tcp_conns: int = 0
var _tcp_listen_port: int
var _bind_address: String = "*" # Bind Address is * (all), if multiple servers will be connecting.


func _ready() -> void:
	if Cfg.sCfgChanged.connect(_change_cfg): pass


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


func insert_or_update_plyr(p_tcp_peer: StreamPeerTCP, p_data: StreamPeerBuffer) -> void:
	var plyr_id: int = p_data.get_u32()
	print("insert_or_update_plyr plyr_id:", plyr_id)
	p_tcp_peer.put_u16(BusStatus.MISSING_FUNC)


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
	_tcp_listen_port = base_port
	
	_srvr_start()
	
	if NetTool.tcp_srvr_is_running(_tcp_srvr):
		print("Listening on port:", _tcp_listen_port)
		_listening = true
	else:
		print("TCP Server failed to start")


func _chk_incomming() -> void:
	if _tcp_srvr.is_connection_available():
		var tcp_peer: StreamPeerTCP = _tcp_srvr.take_connection()
		print("incomming tcp peer:", tcp_peer)
		if _tcp_conns < _tcp_max_conns:
			var thr: Thread = Thread.new()
			var err_code: Error = thr.start(_tcp_thread_func.bind(tcp_peer, thr))
			if err_code != OK:
				printerr("srvr thread start error code:" + str(err_code))
				# TODO - Send error to client
				tcp_peer = NetTool.tcp_disconnect(tcp_peer)
		else:
			tcp_peer = NetTool.tcp_disconnect(tcp_peer)


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


func _tcp_thread_func(p_tcp_peer: StreamPeerTCP, p_this_thread: Thread) -> void:
	_tcp_conns += 1
	
	var func_code: int = -1
	var expected_bytes: int = 0
	var transaction_time: int = 0
	
	while NetTool.tcp_is_conn(p_tcp_peer) and _listening:
		var avail_bytes: int = p_tcp_peer.get_available_bytes()
		
		if func_code < 0:
			if avail_bytes >= kMinTcpBytes:
				func_code = p_tcp_peer.get_u16()
				expected_bytes = p_tcp_peer.get_u32()
				transaction_time = Time.get_ticks_msec() + kMaxTransactionMsecTime
				#print("Backend._tcp_thread func_code:", func_code)
		else:
			if avail_bytes < expected_bytes and transaction_time < Time.get_ticks_msec():
				OS.delay_msec(kTcpFlushMsecDelay)
				continue
			
			var packet: Array = p_tcp_peer.get_data(avail_bytes)
			if transaction_time < Time.get_ticks_msec():
				# BussFuncCodes dispatching, faster than if-elif and match tree
				var cb: Callable = _bus_funcs.get(func_code, null)
				if not cb.is_valid():
					p_tcp_peer.put_16(BusStatus.MISSING_FUNC)
				
				elif packet[PacketSegments.STATUS] != OK:
					var packet_status: int = packet[PacketSegments.STATUS]
					p_tcp_peer.put_16(BusStatus.COMM_ERROR)
					p_tcp_peer.put_16(packet_status)
				else:
					var spb: StreamPeerBuffer = StreamPeerBuffer.new()
					var pba: PackedByteArray = packet[PacketSegments.DATA]
					spb.set_data_array(pba)
					cb.call(p_tcp_peer, spb)
			else:
				p_tcp_peer.put_16(BusStatus.TRANSACTION_TIMEOUT)
			
			func_code = -1
			expected_bytes = 0
		
		OS.delay_msec(kTcpFlushMsecDelay)
	
	p_tcp_peer = NetTool.tcp_disconnect(p_tcp_peer)
	
	_tcp_conns -= 1
	Callable(Utils, "thread_wait_stop").call_deferred(p_this_thread)
