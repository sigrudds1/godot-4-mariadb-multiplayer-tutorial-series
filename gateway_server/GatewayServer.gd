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

enum eFuncCode{
	CREATE_ACCOUNT = 1,
	CHANGE_PASSWORD,
	CONNECT_PLYR,
	DISCONNECT_PLYR,
	LOGIN,
	RESET_PASSWORD
}

const kDbConnTimeout: int = 5000 # need a decent timer argon2 is slow on purpose
const kPlyrConnTimeout: int = 2000 # need a decent timer argon2 is slow on purpose


var _db_url: String
var _db_port: int

var _tcp_srvr: TCPServer
var _tcp_port: int
var _tcp_max_conns: int
var _tcp_active_conns: int = 0
var _stop: bool = false


func _ready() -> void:
	randomize()
	CFG.cfg_changed.connect(_change_cfg)


#func _process(p_delta: float) -> void:
	#pass

# TESTING CODE
func _generate_rng_display_name() -> String:
	const ALPHA: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
	const REMAIN: String = ALPHA + " 0123456789_.#&$-"
	
	var d_name := ""
	# First 3 characters: must be letters
	for i in range(3):
		d_name += ALPHA[randi() % ALPHA.length()]
	
	var remain_len := randi() % (61)
	for i in range(remain_len):
		d_name += REMAIN[randi() % REMAIN.length()]
	
	return d_name


func _test_acct_create() -> void:
	#var display_name: String = _generate_rng_display_name()
	#var cleaned := display_name
	#cleaned = cleaned.replace(" ", "_")
	#cleaned = cleaned.replace("#", "_")
	#cleaned = cleaned.replace("&", "-")
	#cleaned = cleaned.replace("$", "-")
	
	#cleaned = "bad&display name"
	#var email: String = cleaned.to_lower() + "@someplace.nul"
	var email: String = "some_email@someplace.nul"
	var display_name: String = "some_email"
	var pswd: String = "some_password"
	var tcp_peer: StreamPeerTCP = NetTool.tcp_connect(CFG.data["auth_server_url"],
		CFG.data["auth_server_port"])
	if tcp_peer == null:
		return
	tcp_peer.put_u16(eFuncCode.CREATE_ACCOUNT)
	tcp_peer.put_utf8_string(email)
	tcp_peer.put_utf8_string(display_name)
	tcp_peer.put_utf8_string(pswd)
	
	var res: PackedByteArray = await _get_auth_srvr_res(tcp_peer)
	print(res)
	tcp_peer = NetTool.tcp_disconnect(tcp_peer)
	


func _test_login() -> void:
	var email: String = "some_email@someplace.nul"
	var pswd: String = "some_password"
	# lenth encoding = lenc
	# func code<2>, email lenc<2>, email byte count<?>, pswd lenc<2>  pswd byte count<?>
	var tcp_peer: StreamPeerTCP = NetTool.tcp_connect(CFG.data["auth_server_url"],
		CFG.data["auth_server_port"])
	tcp_peer.put_u16(eFuncCode.LOGIN)
	tcp_peer.put_utf8_string(email)
	tcp_peer.put_utf8_string(pswd)
	
	var res: PackedByteArray = await _get_auth_srvr_res(tcp_peer)
	print(res)
	tcp_peer = NetTool.tcp_disconnect(tcp_peer)


# SRVR CODE
func _change_cfg() -> void:
	_db_url = CFG.data["auth_server_url"]
	_db_port = CFG.data["auth_server_port"]
	_test_acct_create()
	_test_login()


func _get_auth_srvr_res(p_tcp_peer: StreamPeerTCP) -> PackedByteArray:
	var rx_bfr := PackedByteArray() 
	var time_out_ms: int = Time.get_ticks_msec() + kDbConnTimeout
	while Time.get_ticks_msec() < time_out_ms and NetTool.tcp_is_connected(p_tcp_peer):
		var avail_bytes: int = p_tcp_peer.get_available_bytes()
		if avail_bytes >= 2:
			var packet: Array = p_tcp_peer.get_data(avail_bytes)
			print("packet:", packet)
			rx_bfr.append_array(packet[1])
			# little endian 16bit signed negative value second byte first bit is always 1 
			if rx_bfr[1] > 128: # negative is an error
				return rx_bfr
			time_out_ms = Time.get_ticks_msec() + kDbConnTimeout
			var reply_code: int = rx_bfr.decode_s16(0)
			if reply_code == eDbReply.OK: # OK packets are just for keep alive
				if avail_bytes > 2:
					rx_bfr = rx_bfr.slice(2)
					reply_code = rx_bfr.decode_s16(0)
				else:
					rx_bfr = []
					continue
			await get_tree().physics_frame
			avail_bytes = p_tcp_peer.get_available_bytes()
			if avail_bytes > 0:
				packet = p_tcp_peer.get_data(avail_bytes)
				rx_bfr.append_array(packet[1])
			break
		await get_tree().physics_frame # wait for more bytes
	return rx_bfr


func _login_success() -> void:
	pass


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
