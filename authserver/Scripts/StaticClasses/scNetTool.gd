# "res://Scripts/StaticClasses/scNetTool.gd"
class_name NetTool extends Node

static func ssl_disconnect(p_peer: StreamPeerTLS) -> StreamPeerTLS:
	if ssl_is_conn(p_peer):
		p_peer.disconnect_from_stream()
	p_peer = null
	return p_peer


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
