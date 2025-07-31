class_name DbTask extends RefCounted

var stmt_glb_id: DB.StmtIDs
var params: Array[Dictionary]
var success_func: Callable
var fail_func: Callable

func _init(	p_stmt_id: DB.StmtIDs,
			p_parmas: Array[Dictionary],
			p_success_func: Callable = Callable(),
			p_fail_func: Callable = Callable()) -> void:
	stmt_glb_id = p_stmt_id
	params = p_parmas
	success_func = p_success_func
	fail_func = p_fail_func
