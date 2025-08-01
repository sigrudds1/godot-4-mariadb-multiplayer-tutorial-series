# "res://Scripts/Autoload/Servers/aCFG.gd"
extends Node

signal sCfgChanged

const kServerName: String = "Authentication Server"

const kJsonCfgFile: String = "auth_srvr_cfg.json"
const kUpdateTime: float = 10.0
const kCfgJsonKeys: Array = [
	"cmd_listen_port",
	"db_pwd_sha512_to_b64",
	"db_max_conns",
	"db_name",
	"db_port",
	"db_url",
	"db_user",
	"gw_listen_port",
	"gw_max_conns"
]

var exe_dir: String
var data: Dictionary = {}

var _update_tmr: float = kUpdateTime


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
			print(kServerName, " starting")
			sCfgChanged.emit()
	if !data.has_all(kCfgJsonKeys):
		print(kServerName, " Cfg Missing, QUITTING!")
		get_tree().quit(-1)
