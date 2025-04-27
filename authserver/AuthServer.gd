# "res://AuthServer.gd"
extends Node


func _ready() -> void:
	CFG.sCFG_Changed.connect(self._change_cfg)


func  test_db() -> void:
	var val: int = randi() % 256
	var byte_array := PackedByteArray()
	byte_array.resize(4)
	byte_array.encode_u32(0, val)
	var hash: String = Marshalls.raw_to_base64(byte_array)
	
	var tasks: Array[DbTask] = []
	var task := DbTask.new(
	DbTask.Types.COMMAND,
		"INSERT INTO Test (Column1, Column2) VALUES (%d, '%s');" % [val, hash],
		func(res):
			print("Command executed successfully:", res),
		func(err):
			print("Command failed:", err)
	)
	tasks.push_back(task)
	
	task = DbTask.new(
		DbTask.Types.SELECT,
		"SELECT * FROM Test",
		func(res):
			print("Query successful:", res),
		func(err):
			print("Query failed with error:", err)
	)
	tasks.push_back(task)
	
	var db_conn: DbConn = DB.get_db_conn()
	while db_conn == null:
		print("not ready")
		await get_tree().create_timer(2.0).timeout
		db_conn = DB.get_db_conn()
	
	if db_conn != null:
		db_conn.do_tasks(tasks)
		db_conn.issued = false


func _change_cfg() -> void:
	test_db()
