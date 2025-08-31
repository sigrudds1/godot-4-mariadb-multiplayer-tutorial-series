# "res://Scripts/Autoload/Servers/aCFG.gd"
extends Node

signal sCfgChanged

const kServerName: String = "TCP Server"

const kJsonCfgFile: String = "srvr_cfg.json"
const kUpdateTime: float = 10.0
const kCfgJsonKeys: Array = [
	"listed_port",
	"bind_address", # Bind Address is * (all), if multiple servers will be connecting.
	"max_conns",
	"conn_timeout",
]

var exe_dir: String
var data: Dictionary = {}
var server_id: int = 1
var cfg_ready: bool = false

var _update_tmr: float = kUpdateTime

# Set ip and port in command args, when server is instanced
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
	cfg_ready = false
	# Export folder contains all the items needd to be included with project export,
	#	 but not included in the pck.
	exe_dir = ProjectSettings.globalize_path("res://Export/")
	if not OS.has_feature("editor"):
		exe_dir = OS.get_executable_path().get_base_dir() + "/"
	var _cfg_path: String = exe_dir + kJsonCfgFile
	var new_cfg: Dictionary = FileTool.json_load(_cfg_path)
	if new_cfg.has_all(kCfgJsonKeys):
		if data.hash() != new_cfg.hash():
			data = new_cfg.duplicate(true)
			print(kServerName, " starting")
			sCfgChanged.emit()
	if not data.has_all(kCfgJsonKeys):
		print(kServerName, " Cfg Missing, QUITTING!")
		get_tree().quit(-1)
		return
	
	cfg_ready = true
