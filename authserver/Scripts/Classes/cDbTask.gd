class_name DbTask extends RefCounted

var stmt_glb_id: DB.eStmtID
var params: Array[Dictionary]
var success_func: Callable
var fail_func: Callable

func _init(	p_stmt_id: DB.eStmtID,
			p_parmas: Array[Dictionary],
			p_success_func := Callable(),
			p_fail_func := Callable()) -> void:
	stmt_glb_id = p_stmt_id
	params = p_parmas
	success_func = p_success_func
	fail_func = p_fail_func
