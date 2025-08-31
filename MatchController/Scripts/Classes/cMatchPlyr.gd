class_name MatchPlyr extends Object

var plyr_id: int
var srvr_ip: String
var srvr_port: int
var peer_id: int
var type: Match.Types
var side: Match.Sides


func _inti(
	p_plyr_id: int,
	p_srvr_ip: String,
	p_srvr_port: int,
	p_peer_id: int,
	p_type: Match.Types,
	p_side: Match.Sides
) -> void:
	
	plyr_id = p_plyr_id
	srvr_ip = p_srvr_ip
	srvr_port = p_srvr_port
	peer_id = p_peer_id
	type = p_type
	side = p_side
