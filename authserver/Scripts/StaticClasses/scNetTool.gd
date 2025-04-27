# "res://script_templates/Node/minimal.gd"
class_name NetTool extends Node

static func ssl_disconnect(p_peer: StreamPeerTLS) -> StreamPeerTLS:
	if ssl_is_conn(p_peer):
		p_peer.disconnect_from_stream()
	p_peer = null
	return p_peer


static func ssl_get_dict(p_peer: StreamPeerTLS) -> Dictionary:
	var d: Dictionary = {}
	var pd = p_peer.get_var()
	if typeof(pd) == TYPE_DICTIONARY:
		return pd
	return d


static func ssl_get_dict_timed(p_peer: StreamPeerTLS, p_timeout: int) -> Dictionary:
	var d: Dictionary = {}
	var end_tm := Time.get_ticks_msec() + p_timeout
	while ssl_is_conn(p_peer):
		if end_tm < Time.get_ticks_msec():
			break
		p_peer.poll()
		if p_peer.get_available_bytes() > 0:
			var pd = p_peer.get_var()
			if typeof(pd) == TYPE_DICTIONARY:
				return pd
	return d


static func ssl_is_conn(p_peer: StreamPeerTLS) -> bool:
	if p_peer == null:
		return false
	return p_peer.get_status() == StreamPeerTLS.STATUS_CONNECTED

#TODO make ssl_send_file

static func tcp_disconnect(p_tcp_peer: StreamPeerTCP) -> StreamPeerTCP:
	if tcp_is_conn(p_tcp_peer):
		p_tcp_peer.disconnect_from_host()
	p_tcp_peer = null
	return p_tcp_peer


static func tcp_get_dict_timed(p_tcp_peer: StreamPeerTCP, p_timeout: int) -> Dictionary:
	var d: Dictionary = {}
	var end_tm := Time.get_ticks_msec() + p_timeout
	while tcp_is_conn(p_tcp_peer):
		if end_tm < Time.get_ticks_msec():
#			print("break")
			break
		if p_tcp_peer.get_available_bytes() > 0:
			end_tm = Time.get_ticks_msec() + p_timeout
			print("NetTool.tcp_get_dict_timed() avail bytes:", p_tcp_peer.get_available_bytes())
			var pd = p_tcp_peer.get_var()
			if typeof(pd) == TYPE_DICTIONARY:
				return pd
			else:
				p_tcp_peer.get_data(p_tcp_peer.get_available_bytes())
				break
	return d


static func tcp_is_conn(p_tcp_peer: StreamPeerTCP) -> bool:
	if p_tcp_peer == null:
		return false
	return p_tcp_peer.get_status() == p_tcp_peer.STATUS_CONNECTED


static func tcp_srvr_create(p_port: int, p_bind_addr: String = "*") -> TCPServer:
	var tcp_srvr := TCPServer.new()
	if tcp_srvr.listen(p_port, p_bind_addr) != OK:
		tcp_srvr = null
	return tcp_srvr


static func tcp_srvr_is_running(p_tcp_srvr: TCPServer) -> bool:
	if p_tcp_srvr == null:
		return false
	return p_tcp_srvr.is_listening()
