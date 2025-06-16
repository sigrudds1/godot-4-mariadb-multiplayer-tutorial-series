# "res://Scripts/StaticClasses/scFileTool.gd"
class_name FileTool extends Object


static func directory_check(p_path: String, p_create: bool = false) -> int:
	var dir := DirAccess.open(p_path.get_base_dir())
	var err: Error = OK
	if dir == null:
		if !p_create:
			return ERR_FILE_BAD_PATH
		else:
			err = dir.make_dir_recursive(p_path.get_base_dir())
			if err:
				printerr("FileTool.directory_check() make_dir_recursive ",
						p_path.get_base_dir(), " failed:", err)
	return err


static func json_load(p_path: String) -> Dictionary:
	var d: Dictionary = {}
	var f := FileAccess.open(p_path, FileAccess.READ)
	if f == null:
		printerr("FileTool.read_json() FA open error")
	else:
		var json: JSON = JSON.new()
		var err : Error = json.parse(f.get_as_text())
		if err != OK:
			printerr("FileTool.read_json() json parse error:", err)
		else:
			d = json.get_data()
		f.close()
	
	return d


static func json_save(p_path: String, p_data: Dictionary, p_create_folder: bool = false) -> int:
	var e: int = directory_check(p_path, p_create_folder)
	if e != OK:
		return e

	var f := FileAccess.open(p_path, FileAccess.WRITE)
	if f == null:
		printerr("Error FileTool.json_save cannot open file", p_path)
		return ERR_CANT_OPEN
	
	f.store_string(JSON.stringify(p_data))
	f.close()
	return OK
