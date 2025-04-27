# "res://Scripts/Autoload/aDB.gd"
# NOTE - See the auth_srvr_cfg.json, this examples db plain password is "secret" and is hashed with
#	SHA512, not to	be confused with SHA512/224, SHA512/256, SHA3-512, the MariaDB server user
#	is configured using ED25519 plugin, see the included AuthSrvrSetup.sql file for installation.
# The MariaDB addon will except the SHA512 hash because in the steps for authetication via ed25519
#	it hashes the password via SHA512 in several stages before signing, the first time is just 
#	hashing SHA512, so with the is_prehashed set as true the first hashing is skipped and a safer,
#	sha512, storage of the password can be kept in a cfg.

# Connection Pooling
#	For a faster query we will hold a min connection pool to be ready, the pools will be refreshed 
#		on a given time
extends Node

signal sConnectionUpdated

var kConnStaleTicks: int = 600000 
var kBufferConns: int = 2

var is_ready: bool = false

var _db_ctx := MariaDBConnectContext.new()
var _max_db_conns: int = 0
var _db_conns: Array[DbConn] = []
var _db_conn_buffer_mutex := Mutex.new()


func _ready() -> void:
	CFG.sCFG_Changed.connect(_change_cfg)
	#_setup_db_ctx()
	TimeLapse.sMinuteLapsed.connect(_check_conns)


func get_db_conn() -> DbConn:
	_db_conn_buffer_mutex.lock()
	var db_conn: DbConn
	for conn:DbConn in _db_conns:
		if conn.issued == false:
			db_conn = conn
			conn.issued = true
			break
	_db_conn_buffer_mutex.unlock()
	sConnectionUpdated.emit()
	return db_conn


func _change_cfg() -> void:
	_setup_db_ctx()
	_check_conns()
	sConnectionUpdated.connect(_check_conns)
	
	is_ready = true


func _setup_db_ctx() -> void:
	_db_ctx.hostname = CFG.data["db_url"]
	_db_ctx.port = CFG.data["db_port"] # default is port 3306
	_db_ctx.db_name = CFG.data["db_name"]
	_db_ctx.db_name = CFG.data["db_name"]
	_db_ctx.username = CFG.data["db_user"]
	_db_ctx.password = CFG.data["db_sha512_pwd_b64"]
	_max_db_conns = CFG.data["db_max_conns"]
	#_db_ctx.auth_type = MariaDBConnectContext.AUTH_TYPE_ED25519 # default
	#_db_ctx.encoding = MariaDBConnectContext.ENCODE_BASE64 # default


func _check_conns() -> void:
	_db_conn_buffer_mutex.lock()
	
	var conns_unissued: int = 0
	for i in range(_db_conns.size() - 1, -1, -1):
		var conn: DbConn = _db_conns[i]
		if not is_instance_valid(conn):
			_db_conns.remove_at(i)
		elif not conn.issued:
			if conns_unissued >= kBufferConns:
				_db_conns.remove_at(i)
			else:
				conns_unissued += 1
	
	var conns_available: int =  _max_db_conns - _db_conns.size()
	while conns_available > 0 and conns_unissued < kBufferConns:
		var  db_conn := DbConn.new(_db_ctx)
		_db_conns.push_back(db_conn)
		conns_unissued += 1
		conns_available -= 1
	
	_db_conn_buffer_mutex.unlock()
