#"res://Scripts/Autoload/RPC/aConnectionIface.gd"                                                                                                                                     
extends Node

const auth_time: float = 10.0

var awaiting_login: Dictionary ={}
var plyrs_online: Dictionary = {}

var _plyr_scene: PackedScene = preload("res://Scenes/Player.tscn")
var _enet_port: int
var _enet_max_conns: int
var _enet_srvr: ENetMultiplayerPeer
var _stop_listening: bool = true

@onready var _main_node: Node = get_node("/root/Main")


func _ready() -> void:
	if CFG.sCfgChanged.connect(_change_cfg) != OK: pass
	
	if multiplayer.peer_connected.connect(_player_connected) != OK: pass
	
	if multiplayer.peer_disconnected.connect(_player_disconnected) != OK: pass
	
	if TimeLapse.sOneSecondLapsed.connect(_check_awaiting_login) != OK: pass


func _change_cfg() -> void:
	_stop_listening = true
	
	if !CFG.data.has_all(CFG.kCfgJsonKeys):
		printerr("aConnectionIface.gd:_change_cfg() missing keys")
		await get_tree().create_timer(1.0).timeout
		call_deferred("_change_cfg")
		return
	
	var base_port: int = CFG.data.get("plyr_base_port")
	if base_port == null or base_port < 1024:
		printerr("aConnectionIface.gd:_change_cfg() missing keys")
		return
	
	_enet_port = base_port + CFG.server_id
	_enet_max_conns = CFG.data.get("plyr_max_conns")
	if _enet_max_conns == null or _enet_max_conns == 0:
		printerr("aConnectionIface.gd:_change_cfg() _enet_max_conns:", _enet_max_conns)
		return
	
	_srvr_start()
	_stop_listening = false


func _check_awaiting_login() -> void:
	var thr: Thread = Thread.new()
	var err_code: Error = thr.start(_check_awaiting_login_thread.bind(thr))
	if err_code != OK: 
		printerr("aConnectionIface._check_wating_thread start error code:" + str(err_code))


func _check_awaiting_login_thread(p_this_thread: Thread) -> void:
	for key:String in awaiting_login:
		var plyr: Dictionary = awaiting_login.get(key)
		var expires: int = plyr.get("expires", -1)
		if expires < Time.get_ticks_msec():
			print("player: %s \n connection time expired!" % [str(plyr)])
			if awaiting_login.erase(key):
				pass
		
	Callable(Utils, "thread_wait_stop").call_deferred(p_this_thread)


func _match_queue_add_plyr_thread(
	p_plyr: Player,
	p_side: int,
	p_match_type: int, 
	p_this_thread: Thread
) -> void:
	
	
	# Contact match controller and add player
	
	Callable(Utils, "thread_wait_stop").call_deferred(p_this_thread)


func _match_queue_remove_plyr_thread(p_plyr_node: Player, p_this_thread: Thread) -> void:
	# Contact match controller and remove player, single server match controlelr is singelton
	
	Callable(Utils, "thread_wait_stop").call_deferred(p_this_thread)


func _player_connected(p_peer_id: int) -> void:
	if _stop_listening:
		server_status.rpc_id(p_peer_id, ERR_UNAVAILABLE)
		multiplayer.multiplayer_peer.disconnect_peer(p_peer_id)
		return
	print("player ", p_peer_id, " connected!")
	await get_tree().create_timer(auth_time).timeout
	var plyr_node: Node = _main_node.get_node_or_null("plyr_" + str(p_peer_id))
	if plyr_node == null and p_peer_id in  multiplayer.get_peers():
		multiplayer.multiplayer_peer.disconnect_peer(p_peer_id)


func _player_disconnected(p_peer_id: int) -> void:
	print("Peer:%d disconnected!"% [p_peer_id])
	var plyr_node: Player = _main_node.get_node_or_null("plyr_" + str(p_peer_id))
	if plyr_node == null:
		print("plyr_node for per_id %d not found!" % p_peer_id)
		return
	var thr: Thread= Thread.new()
	var err_code: Error = thr.start(_player_disconnected_thread.bind(plyr_node, thr))
	if err_code != OK: printerr("plyr disconnected thread start error, code:" + str(err_code))


func _player_disconnected_thread(p_plyr_node: Player, p_this_thread: Thread) -> void:
	var plyr_id: int = p_plyr_node.plyr_id
	var display_name: String = p_plyr_node.display_name
	if plyrs_online.erase(plyr_id): pass
	
	print("Plyr_id:%d, Display Name:%s disconnected!"% [plyr_id, display_name])
	
	p_plyr_node.remove_player(p_this_thread)
	Callable(Utils, "thread_wait_stop").call_deferred(p_this_thread)


func _srvr_start() -> void:
	_enet_srvr = ENetMultiplayerPeer.new()
	var error: Error = _enet_srvr.create_server(_enet_port, _enet_max_conns)
	if error != OK:
		printerr("Can't create Enet Server with Error:", error)
		await TimeLapse.sOneSecondLapsed
		call_deferred("_change_cfg")
		return
	
	multiplayer.set_multiplayer_peer(_enet_srvr)
	print("multiplayer port %d max conns %d" % [_enet_port, _enet_max_conns])
	

@rpc("any_peer", "reliable")
func client_cancel_match() -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	var plyr_node: Player = _main_node.get_node_or_null("plyr_" + str(peer_id))
	
	var thr: Thread= Thread.new()
	var err_code: Error = thr.start(_match_queue_remove_plyr_thread.bind(plyr_node, thr))
	if err_code != OK:
		printerr("_match_queue_remove_plyr_thread start error, code:" + str(err_code))


@rpc("any_peer", "reliable")
func client_request_match(p_side: Match.Sides, p_type: Match.Types) -> void:
	if p_side == Match.Sides.NONE or p_type == Match.Types.NONE: return
	
	# We still add to the queue even if ONLY_PVE, in case of server overloading
	var peer_id: int = multiplayer.get_remote_sender_id()
	var plyr_node: Player = _main_node.get_node_or_null("plyr_" + str(peer_id))
	print("client_request_match side:%d, type:%d, plyr:%s" % [p_side, p_type, plyr_node])
	
	var thr: Thread= Thread.new()
	var err_code: Error = thr.start(
		_match_queue_add_plyr_thread.bind(
			plyr_node, 
			p_side, 
			p_type, 
			thr
		)
	)
	
	if err_code != OK: printerr("_match_queue_add_plyr_thread start error, code:" + str(err_code))


# plyr connect credentials from gateway
# var token_example: String = displaY_name + "argon2 base64 salt" from gateway
# awaiting_login[token_example] = {"plyr_id": plyr_id, "display_name": display_name}
@rpc("any_peer", "reliable")
func client_validate_token(p_token: String) -> void:
	#print("ConnectionIface.validate_token awaiting login:", awaiting_login)
	#print("ConnectionIface.validate_token token:", p_token)
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not awaiting_login.has(p_token):
		server_validation_status.rpc_id(peer_id, ERR_UNAVAILABLE)
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	
	var plyr_info: Dictionary = awaiting_login.get(p_token, {})
	if awaiting_login.erase(p_token):
		pass
	
	var plyr_id: int = plyr_info.get("plyr_id")
	if plyrs_online.get(plyr_id) != null:
		server_validation_status.rpc_id(peer_id, ERR_ALREADY_EXISTS)
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	
	var plyr_node: Player = _plyr_scene.instantiate()
	plyr_node.set_name("plyr_" + str(peer_id))
	plyr_node.peer_id = peer_id
	plyr_node.plyr_id = plyr_id
	plyr_node.display_name =  plyr_info.get("display_name")
	if plyr_node.plyr_id == null or plyr_node.display_name == null:
		server_validation_status.rpc_id(peer_id, ERR_CANT_ACQUIRE_RESOURCE)
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		plyr_node.queue_free()
		return
	
	server_validation_status.rpc_id(peer_id, OK)
	plyrs_online[plyr_id] = plyr_node
	_main_node.add_child(plyr_node)
	print("plyr validated peer_id:%d info:%s" % [peer_id, str(plyr_info)])
	print(plyr_node)
	print(_main_node.get_children())


@rpc("authority", "reliable")
func server_validation_status(_code: int) -> void: pass


@rpc("authority", "reliable")
func server_status(_code: int) -> void: pass
