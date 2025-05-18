# "res://Scripts/Autoload/aGameServer.gd"
extends Node

# signals
signal cfg_changed

# enums
# constants
const kSSLKeyPath: String = "x509Cert/test.key"
const kSSLCertPath: String = "x509Cert/test.crt"
const kMaxGameServers: int = 8
const kUpdateTime: float = 10.0

const kCfgTemplate: Dictionary = {
	"auth_server_url": "192.168.2.230",
	"auth_server_port": 60100,
	"auth_max_conns": 1000,
	"listen_port": 61000,
	"max_conns": 1000,
	"backend_listen_port": 61100,
	"cmd_listen_port": 61200,
	"game_servers_baseport": 62000,
	"server_id": 1
}

# @export variables
# public variables
var exe_dir: String
var id: int = 0
var data: Dictionary = {}
var tls_server_opts: TLSOptions

# friend variables
# private variables
var _cfg_path: String
var _update_tmr: float = kUpdateTime

# @onready variables
#@onready var _main_node = get_node("/root/Main")


# optional built-in virtual _init method
# optional built-in virtual _enter_tree() method

# built-in virtual _ready method
#func _ready() -> void:


# remaining built-in virtual methods
func _physics_process(p_delta: float) -> void:
	_update_tmr += p_delta
	if _update_tmr > kUpdateTime:
		_update_tmr -= kUpdateTime
		_get_cfg()
		_get_tls_opts()

# public methods

# friend methods
# private methods
func _get_cfg() -> void:
	var cfg_hash: int = data.hash()
	exe_dir = ProjectSettings.globalize_path("res://Export/")
	if !OS.has_feature("editor"):
		exe_dir = OS.get_executable_path().get_base_dir() + "/"
	_cfg_path = exe_dir + "gw_srvr_cfg.json"
	var new_cfg: Dictionary = FileTool.load_json(_cfg_path)
	if !new_cfg.has_all(kCfgTemplate.keys()):
		return
	data = new_cfg.duplicate(true)
	if cfg_hash != data.hash():
		print("Gateway server starting")
		cfg_changed.emit()


func _get_tls_opts() -> void:
	if exe_dir == "":
		return
	var ssl_key: CryptoKey = load(exe_dir + kSSLKeyPath)
	var ssl_crt: X509Certificate = load(exe_dir + kSSLCertPath)
	tls_server_opts = TLSOptions.server(ssl_key, ssl_crt)
#	tls_client_opt = TLSOptions.client_unsafe(ssl_crt) # testing with self signed

# signal methods
