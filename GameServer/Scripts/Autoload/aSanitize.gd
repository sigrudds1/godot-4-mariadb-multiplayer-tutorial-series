extends Node

var _display_name: RegEx = RegEx.new()
var _email: RegEx = RegEx.new()
var _hex: RegEx = RegEx.new()
var _ipv4: RegEx = RegEx.new()
var _ipv6: RegEx = RegEx.new()
var _password_hash: RegEx = RegEx.new()
var _password_plain: RegEx = RegEx.new()

var _url: RegEx = RegEx.new()
var _username: RegEx = RegEx.new()
var _versioning: RegEx = RegEx.new()


func _ready() -> void :
	var err: Error = _display_name.compile("^[a-zA-Z]{3}[a-zA-Z0-9_.#&$-]{0,61}$")
	if err: print("RegEx compile error display_name")
	var any_err: int = err

	err = _email.compile("[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:" +
			"[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?")
	if err: print("RegEx compile error email")
	any_err |= err

	err = _hex.compile("^[a-fA-F0-9]*$")
	if err: print("RegEx compile error hex")
	any_err |= err

	err = _ipv4.compile("^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4]" +
			"[0-9]|[01]?[0-9][0-9]?)$")
	if err: print("RegEx compile error ipv4", err)
	any_err |= err

	err = _ipv6.compile("(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|" +
			"([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]" +
			"{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|" +
			"([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]" +
			"{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}" +
			"(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4})" +
			"{1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4})" +
			"{0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|" +
			"(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\\.){3,3}(25[0-5]|(2[0-4]|1" +
			"{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|"+
			"(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\\.){3,3}(25[0-5]|(2[0-4]|1" +
			"{0,1}[0-9]){0,1}[0-9]))")
	if err: print("RegEx compile error ipv6", err)
	any_err |= err

	err = _password_hash.compile("^[a-zA-Z0-9+/=]*$")
	if err: print("RegEx compile error password_hash", err)
	any_err |= err

	err = _password_plain.compile("^[ -~]{8,64}$")
	if err: print("RegEx compile error password_hash", err)
	any_err |= err

	err = _url.compile("[-a-zA-Z0-9@:%._\\+~#=]{1,256}\\.[a-zA-Z0-9()]{1,6}\\b([-a-zA-Z0-9()@:" + 
			"%_\\+.~#?&//=]*)")
	if err: print("RegEx compile error url", err)
	any_err |= err

	err = _username.compile("^[a-zA-Z0-9_-]{3,64}$")
	if err: print("RegEx compile error username", err)
	any_err |= err

	err = _versioning.compile("^[ 0-9A-Za-z_.-]*$")
	if err: print("RegEx compile error check_versioning", err)
	any_err |= err

	if any_err :
		get_tree().quit()


func check_display_name(p_str: String) -> bool:
	var regex: RegExMatch = _display_name.search(p_str)
	print(regex.get_string())
	if regex == null:
		return false
	return regex.get_string() == p_str


func check_email(p_str: String) -> bool:
	var regex: RegExMatch = _email.search(p_str)
	if regex == null:
		return false
	return regex.get_string() == p_str


func check_hex(p_str: String) -> bool:
	var regex: RegExMatch = _hex.search(p_str)
	if regex == null:
		return false
	return regex.get_string() == p_str


func check_ipv4(p_str: String) -> bool:
	var regex: RegExMatch = _ipv4.search(p_str)
	if regex == null:
		return false
	return regex.get_string() == p_str


func check_ipv6(p_str: String) -> bool:
	var regex: RegExMatch = _ipv6.search(p_str)
	if regex == null:
		return false
	return regex.get_string() == p_str


func check_password_hash(p_str: String) -> bool:
	var regex: RegExMatch = _password_hash.search(p_str)
	if regex == null:
		return false
	return regex.get_string() == p_str


func check_password_plain(p_str: String) -> bool:
	var regex: RegExMatch = _password_plain.search(p_str)
	if regex == null:
		return false
	return regex.get_string() == p_str


func check_url(p_str: String) -> bool:
	var regex: RegExMatch = _url.search(p_str)
	if regex == null:
		return false
	return regex.get_string() == p_str


func check_username(p_str: String) -> bool:
	var regex: RegExMatch = _username.search(p_str)
	if regex == null:
		return false
	return regex.get_string() == p_str


func check_versioning(p_str: String) -> bool:
	var regex: RegExMatch = _versioning.search(p_str)
	if regex == null:
		return false
	return regex.get_string() == p_str
