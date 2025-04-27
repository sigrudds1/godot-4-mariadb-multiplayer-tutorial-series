extends Node


func _ready() -> void:
	var tasks: Array[DbTask] = []
	
	var task := DbTask.new(
		DbTask.Types.SELECT,
		"SELECT * FROM players",
		func(res):
			print("Query successful:", res),
		func(err):
			print("Query failed with error:", err)
	)
	tasks.push_back(task)
	
	task = DbTask.new(
	DbTask.Types.COMMAND,
		"DELETE FROM players WHERE id = 5",
		func():
			print("Command executed successfully."),
		func():
			print("Command failed.")
	)
	tasks.push_back(task)
	
	#var db_conn: DbConn = 
	#db_conn.do_tasks([task])
