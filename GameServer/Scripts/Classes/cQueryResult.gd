class_name QueryResult extends RefCounted


var err: int = OK
var res: Dictionary # response for inserts, updates, delete, etc
var rows: Array[Dictionary] # response for select
