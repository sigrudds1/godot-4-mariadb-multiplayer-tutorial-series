extends Control

enum eReply {
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

enum eFuncCode {
	CREATE_ACCOUNT = 1,
	CHANGE_PASSWORD,
	CONNECT_PLYR,
	DISCONNECT_PLYR,
	LOGIN,
	RESET_PASSWORD
}

const kDataStreamTimeout: int = 2000 
const kTcpFlushDelay: int = 50

# Configure a pool to go thru for anti-ddos
var _gateway_srvrs: Array[Dictionary] = [
	{"host": "localhost", "port": 61000},
	{"host": "192.168.2.230", "port": 61000}, 
	{"host": "192.168.2.240", "port": 61000}
]

@onready var _login_panel: PanelContainer = %Login_pnl_cont
@onready var _email_line: LineEdit = %Email
@onready var _display_name_line: LineEdit = %Displayname
@onready var _password_line: LineEdit = %Password
@onready var _registration_btn: CheckBox = %Register
@onready var _popup_msg_panel: Control = %PopupMsg_panel
@onready var _popup_msg_rtl: RichTextLabel = %PopupMsg_RTL


func _ready() -> void:
	_display_name_line.visible = false


func _on_exit_btn_pressed() -> void:
	get_tree().quit()


func _on_popup_msg_close_tbtn_pressed() -> void:
	_popup_msg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_msg_panel.visible = false
	_login_panel.visible = true


func _on_register_toggled(p_toggled_on: bool) -> void:
	_display_name_line.visible = p_toggled_on


func _on_server_option_button_item_selected(p_idx: int) -> void:
	match p_idx:
		0: 
			_gateway_srvrs =[{"host": "localhost", "port": 61000},
				{"host": "192.168.2.230", "port": 61000}, 
				{"host": "192.168.2.240", "port": 61000}
			]
		1:
			_gateway_srvrs =[{"host": "192.168.2.230", "port": 61000},
				{"host": "localhost", "port": 61000},
				{"host": "192.168.2.240", "port": 61000}
			]
		2:
			_gateway_srvrs =[{"host": "192.168.2.240", "port": 61000},
				{"host": "localhost", "port": 61000},
				{"host": "192.168.2.230", "port": 61000}
			]


func _on_submit_btn_pressed() -> void:
	var thr: Thread = Thread.new()
	var err: int = thr.start(_tls_thread.bind(thr))
	if err != OK:
		printerr("Login._on_submit_pressed() thread start err_code:", err)


func _popup_msg(p_text:String) -> void:
	_popup_msg_rtl.text = p_text
	_popup_msg_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_login_panel.visible = false
	_popup_msg_panel.visible = true


func _tls_thread(p_this_thread: Thread) -> void:
	var func_code: int = eFuncCode.LOGIN
	if _registration_btn.button_pressed:
		func_code = eFuncCode.CREATE_ACCOUNT
	
	var gateway_url: String = ""
	var gateway_port: int
	var tcp_peer: StreamPeerTCP
	for srvr:Dictionary in _gateway_srvrs:
		gateway_url = srvr.get("host", "")
		gateway_port = srvr.get("port", 0)
		if gateway_url == "" or gateway_port == 0:
			continue
		tcp_peer = NetTool.tcp_connect(gateway_url, gateway_port)
		if tcp_peer != null:
			break
	
	if tcp_peer == null:
		call_deferred("_popup_msg", "Cannot Connect to the Gateway Server, Check Connection.")
		call_deferred("_thread_stop", p_this_thread)
		return
	
	var tls_peer: StreamPeerTLS = NetTool.tls_client_connect(tcp_peer,
		gateway_url,
		TLSOptions.client_unsafe())
	tls_peer.put_u16(func_code)
	tls_peer.put_utf8_string(_email_line.text)
	if func_code == eFuncCode.CREATE_ACCOUNT:
		tls_peer.put_utf8_string(_display_name_line.text)
	tls_peer.put_utf8_string(_password_line.text)
	
	OS.delay_msec(kTcpFlushDelay)
	var avail_bytes: int = 0
	var idle_tm: int = Time.get_ticks_msec() + kDataStreamTimeout
	while Time.get_ticks_msec() < idle_tm and avail_bytes < 2:
		if not NetTool.tls_is_connected(tls_peer):
			break
		avail_bytes = tls_peer.get_available_bytes()
	if NetTool.tls_is_connected(tls_peer):
		var reply_code: int = tls_peer.get_16()
		if reply_code == eReply.LOGIN_SUCCESS or reply_code == eReply.CREATED:
			ConnectionIface.game_srvr_url = tls_peer.get_utf8_string()
			ConnectionIface.game_srvr_port = tls_peer.get_u16()
			ConnectionIface.display_name = tls_peer.get_utf8_string()
			var salt: String = tls_peer.get_utf8_string()
			ConnectionIface.login_token = ConnectionIface.display_name + salt
			ConnectionIface.call_deferred("emit_signal", "sLoginSucceeded")
		else:
			printerr("login failed with code:", reply_code)
			var msg: String = ""
			match reply_code:
				eReply.UNAME_UNAVAILABLE:
					msg = "Email Not available."
				eReply.DNAME_UNAVAILABLE:
					msg = "Display Name Not available."
				eReply.LOCKED:
					msg = "Account Locked Contact Support."
				eReply.LOGIN_ATTEMPT_EXCEEDED:
					msg = "Failed Login Attempts Exceeded Try Back in 15 Minutes."
				eReply.LOGIN_FAIL:
					msg = "Login Failed Check Username and Password."
				_:
					msg = "Unknown Error Code:%d" % reply_code
			call_deferred("_popup_msg", msg)
	else:
		printerr("TLS not connected")
		call_deferred("_popup_msg", "Cannot create secure connection, " + 
			"are you on a public connection? contact support")
		
	tls_peer = NetTool.tls_disconnect(tls_peer)
	call_deferred("_thread_stop", p_this_thread)


func _thread_stop(p_thread: Thread) -> void:
	Utils.thread_wait_stop(p_thread)
