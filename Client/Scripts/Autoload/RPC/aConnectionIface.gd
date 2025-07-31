#"res://Scripts/Autoload/RPC/aConnectionIface.gd"                                                                                                                                     
extends Node

signal sLoginSucceeded

var game_srvr_url: String
var game_srvr_port: int
var display_name: String
var login_token: String


func _ready() -> void:
	if multiplayer.connection_failed.connect(_on_connected_fail):
		pass
	if  multiplayer.connected_to_server.connect(_on_connected_ok):
		pass
	if multiplayer.server_disconnected.connect(_on_server_disconnected):
		pass
	if sLoginSucceeded.connect(_on_login_success):
		pass


func _on_connected_fail() -> void:
	print("Failed connection to game server")
	multiplayer.multiplayer_peer = null


func _on_connected_ok() -> void:
	print("Connected to game server")
	client_validate_token.rpc_id(1, login_token)


func _on_login_success() -> void:
	var ip: String = IP.resolve_hostname(game_srvr_url)
	print("connectin to url %s as ip %s and port %d" % [game_srvr_url, ip, game_srvr_port])
	if not game_srvr_url.is_valid_ip_address():
		print("ConnectionIface._on_login_success invalid IP:")
		return
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: int = peer.create_client(game_srvr_url, game_srvr_port)
	if error:
		# TODO handle 
		print("ConnectionIface._on_login_success create client error:", error)
		return
	
	print("Connecting to game server url:%s, port:%d, diaplay_name:%s, hash:%s" % [
		game_srvr_url, game_srvr_port, display_name, login_token])
	multiplayer.multiplayer_peer = peer


func _on_server_disconnected() -> void:
	print("Disconnected from game server")
	multiplayer.multiplayer_peer = null
	if get_tree().change_scene_to_file("res://Login.tscn"):
		pass


@rpc("any_peer", "reliable")
func client_cancel_match() -> void:
	pass


@rpc("any_peer", "reliable")
func client_request_match(_side:DataTypes.PlaySide, _type:DataTypes.MatchType) -> void:
	pass


# RPC function signatures have to match, create dummy signatures on caller side
@rpc("any_peer", "reliable")
func client_validate_token(_token: String) -> void:
	pass


@rpc("authority", "reliable")
func server_validation_status(p_code: int) -> void:
	if p_code == OK:
		if get_tree().change_scene_to_file("res://Scenes/Lobby.tscn"):
			pass
	else:
		print("ConnectionIface server validation status:", p_code)


@rpc("authority", "reliable")
func server_status(p_code: int) -> void:
	print("ConnectionIface.server_status code:", p_code)
