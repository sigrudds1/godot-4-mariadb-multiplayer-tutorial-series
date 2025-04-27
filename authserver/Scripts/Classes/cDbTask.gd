class_name DbTask extends RefCounted

enum Types {
	SELECT,
	COMMAND
}

var type: Types
var stmt: String
var success_func: Callable
var fail_func: Callable

func _init(p_type: Types, 
	p_stmt: String, 
	p_success_func := Callable(), 
	p_fail_func := Callable()) -> void:
	type = p_type
	stmt = p_stmt
	success_func = p_success_func
	fail_func = fail_func
