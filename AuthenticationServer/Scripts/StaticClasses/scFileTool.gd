# "res://Scripts/StaticClasses/scFileTool.gd"
class_name FileTool extends Node


static func directory_check(p_path: String, p_create: bool = false) -> int:
	var dir: DirAccess = DirAccess.open(p_path.get_base_dir())
	var err: Error = OK
	if dir == null:
		if !p_create:
			return ERR_FILE_BAD_PATH
		else:
			err = dir.make_dir_recursive(p_path.get_base_dir())
			if err:
				print("FileTool.directory_check() make_dir_recursive ",
						p_path.get_base_dir(), " failed:", err)
	return err


static func json_load(p_path: String) -> Dictionary:
	var d: Dictionary = {}
	var f: FileAccess = FileAccess.open(p_path, FileAccess.READ)
	if f != null:
		var json: JSON = JSON.new()
		var err : Error = json.parse(f.get_as_text())
		if err != OK:
			print("FileTool.json_load() json parse error:", err)
		else:
			d = json.get_data()
		f.close()
	else:
		printerr("FileTool.json_load() FileAccess open error for", p_path)
	return d


static func json_save(p_path: String, p_data: Dictionary, p_create_folder: bool = false) -> int:
	var e: int = directory_check(p_path, p_create_folder)
	if e != OK:
		return e

	var f: FileAccess = FileAccess.open(p_path, FileAccess.WRITE)
	if f == null:
		print("Error FileTool.json_save FileAccess open error for", p_path)
	if not f.store_string(JSON.stringify(p_data)):
		pass
	f.close()
	return OK
