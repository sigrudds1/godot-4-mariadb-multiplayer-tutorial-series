# "res://Scripts/Autoload/aSanitize.gd"
extends Node

signal sChanged

const kServerName: String = "Gateway Server"

const kJsonCfgFile: String = "gw_srvr_cfg.json"
const kSSLKeyPath: String = "x509Cert/test.key"
const kSSLCertPath: String = "x509Cert/test.crt"
const kMaxGameServers: int = 8
const kUpdateTime: float = 10.0

const kCfgJsonKeys: Array = [
	"auth_server_url",
	"auth_server_port",
	"auth_max_conns",
	"gw_listen_port",
	"gw_max_conns",
	"backend_listen_port",
	"cmd_listen_port",
	"game_server_backend_url",
	"game_server_backend_port",
	"game_server_url",
	"game_server_port",
	"server_id"
]


var exe_dir: String
var id: int = 0
var data: Dictionary = {}
var tls_server_opts: TLSOptions

var _update_tmr: float = kUpdateTime


# We will eventually set ip and port in command args, when multiple servers are needed
func _ready() -> void:
	var args: Dictionary = {}
	print("Command line args:", OS.get_cmdline_user_args())
	
	for arg:String in OS.get_cmdline_user_args():
		if arg.find("=") > -1:
			var key_value: PackedStringArray = arg.split("=")
			args[key_value[0].lstrip("--")] = key_value[1]
		else:
			args[arg.lstrip("--")] = ""


func _physics_process(p_delta: float) -> void:
	_update_tmr += p_delta
	if _update_tmr > kUpdateTime:
		_update_tmr -= kUpdateTime
		_get_cfg()
		_get_tls_opts()


func _get_cfg() -> void:
	# Export folder contains all the items needd to be included with project export,
	#	 but not included in the pck.
	exe_dir = ProjectSettings.globalize_path("res://Export/")
	if !OS.has_feature("editor"):
		exe_dir = OS.get_executable_path().get_base_dir() + "/"
	var _cfg_path: String = exe_dir + kJsonCfgFile
	var new_cfg: Dictionary = FileTool.json_load(_cfg_path)
	if new_cfg.has_all(kCfgJsonKeys):
		if data.hash() != new_cfg.hash():
			data = new_cfg.duplicate(true)
			print(kServerName, " starting")
			sChanged.emit()
	if !data.has_all(kCfgJsonKeys):
		print(kServerName, " Cfg Missing, QUITTING!")
		get_tree().quit(-1)


func _get_tls_opts() -> void:
	if exe_dir == "":
		return
	var ssl_key: CryptoKey = load(exe_dir + kSSLKeyPath)
	var ssl_crt: X509Certificate = load(exe_dir + kSSLCertPath)
	tls_server_opts = TLSOptions.server(ssl_key, ssl_crt)
