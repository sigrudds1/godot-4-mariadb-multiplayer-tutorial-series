# "res://Scripts/Classes/cQueryResult.gd"
class_name QueryResult extends RefCounted


var error: int = OK
var cmd_res: Dictionary # response for inserts, updates, delete, etc
var select_res: Array[Dictionary] # response for select
