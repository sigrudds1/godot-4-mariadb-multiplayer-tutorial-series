# "res://Scripts/StaticClasses/scNetTool.gd"
class_name NetTool extends Node

static func ssl_connect(p_tcp_peer: StreamPeerTCP, p_timeout: int = 2000) -> StreamPeerTLS:
	var ssl_peer := StreamPeerTLS.new()
	var err = ssl_peer.connect_to_stream(p_tcp_peer, "", CFG.tls_client_opt)
	if err:
		print("ssl connection error:", err)
		ssl_peer = null
		return ssl_peer

	var conn_timeout:int = Time.get_ticks_msec() + p_timeout
	while (ssl_peer.get_status() == StreamPeerTLS.STATUS_HANDSHAKING &&
		Time.get_ticks_msec() < conn_timeout && err == 0):
		ssl_peer.poll()

	if (ssl_peer.get_status() == StreamPeerTLS.STATUS_HANDSHAKING ||
			ssl_peer.get_status() != StreamPeerTLS.STATUS_CONNECTED && err == 0):
		print("SSL Not Completing Handshake")
		ssl_peer = null

	return ssl_peer


static func ssl_disconnect(p_peer: StreamPeerTLS) -> StreamPeerTLS:
	if ssl_is_conn(p_peer):
		p_peer.disconnect_from_stream()
	p_peer = null
	return p_peer


static func ssl_is_conn(p_peer: StreamPeerTLS) -> bool:
	if p_peer == null:
		return false
	return p_peer.get_status() == StreamPeerTLS.STATUS_CONNECTED


static func tcp_connect(p_url: String, p_port: int, p_timeout: int = 2000) -> StreamPeerTCP:
	var tcp_peer := StreamPeerTCP.new()
	var err: int = tcp_peer.connect_to_host(p_url, p_port)
	if err :
		print(p_url, ":", p_port, " tcp connection error:", err)

	var conn_timeout: int = Time.get_ticks_msec() + p_timeout
	while (err == OK &&
			tcp_peer.get_status() == StreamPeerTCP.STATUS_CONNECTING &&
			Time.get_ticks_msec() < conn_timeout):
		tcp_peer.poll()

	if (err || tcp_peer.get_status() == StreamPeerTCP.STATUS_CONNECTING ||
			tcp_peer.get_status() != StreamPeerTCP.STATUS_CONNECTED):
		print(p_url, ":", p_port, " cannot connect to host")
		err = ERR_CANT_CONNECT

	if err:
		tcp_peer = tcp_disconnect(tcp_peer)

	return tcp_peer


static func tcp_disconnect(p_tcp_peer: StreamPeerTCP) -> StreamPeerTCP:
	if tcp_is_connected(p_tcp_peer):
		p_tcp_peer.disconnect_from_host()
	p_tcp_peer = null
	return p_tcp_peer


static func tcp_is_connected(p_tcp_peer: StreamPeerTCP) -> bool:
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
