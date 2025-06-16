# "res://Scripts/Autoload/Servers/aCFG.gd"
extends Node

signal sChanged

const kJsonCfgFile: String = "game_srvr_cfg.json"
const kUpdateTime: float = 10.0
const kCfgJsonKeys: Array = [
	"backend_base_port",
	"backend_bind_address",
	"backend_max_conns",
	"backend_conn_timeout",
	"db_conn_timeout",
	"db_buffer_conns",
	"db_url",
	"db_max_conns",
	"db_name",
	"db_port",
	"db_user",
	"db_pwd_sha512_to_b64",
	"gateway_backend_url",
	"gateway_backend_port",
	"plyr_conn_timeout",
	"plyr_base_port",
	"plyr_max_conns"
]

var exe_dir: String
var data: Dictionary = {}
var server_id: int = 1

var _update_tmr: float = kUpdateTime


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
			print("server starting")
			sChanged.emit()
	if !data.has_all(kCfgJsonKeys):
		print("Auth Server Cfg Missing, QUITTING!")
		get_tree().quit(-1)
