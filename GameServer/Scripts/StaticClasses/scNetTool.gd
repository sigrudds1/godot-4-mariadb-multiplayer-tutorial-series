# "res://Scripts/StaticClasses/scNetTool.gd"
class_name NetTool extends Object

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

static func tcp_connect(p_url: String, p_port: int, p_timeout: int = 2000) -> StreamPeerTCP:
	var tcp_peer: StreamPeerTCP = StreamPeerTCP.new()
	var err: int = tcp_peer.connect_to_host(p_url, p_port)
	if err != OK:
		printerr("NetTool.tcp_connect error %d for URL:%s, PORT:%d" % [err, p_url, p_port])
		return null
	
	var conn_timeout: int = Time.get_ticks_msec() + p_timeout
	while (
		err == OK and
		tcp_peer.get_status() == StreamPeerTCP.STATUS_CONNECTING and
		Time.get_ticks_msec() < conn_timeout
	):
		err = tcp_peer.poll()
	
	if tcp_peer.get_status() != StreamPeerTCP.STATUS_CONNECTED and err == OK:
		printerr("NetTool.tcp_connect cannot connect to tcp host", p_url, ":", p_port)
		tcp_peer = tcp_disconnect(tcp_peer)
	elif err != OK:
		printerr("NetTool.tcp_connect error connecting to %s:%d with error code:%d" % [
			p_url, p_port, err])
		tcp_peer = tcp_disconnect(tcp_peer)
	
	return tcp_peer


static func tcp_disconnect(p_tcp_peer: StreamPeerTCP) -> StreamPeerTCP:
	if tcp_status(p_tcp_peer) == StreamPeerTCP.STATUS_CONNECTED: p_tcp_peer.disconnect_from_host()
	
	p_tcp_peer = null
	return p_tcp_peer


static func tcp_is_connected(p_tcp_peer: StreamPeerTCP) -> bool:
	return tcp_status(p_tcp_peer) == StreamPeerTCP.STATUS_CONNECTED


static func tcp_srvr_create(p_port: int, p_bind_addr: String = "*") -> TCPServer:
	var tcp_srvr: TCPServer = TCPServer.new()
	var error: Error = tcp_srvr.listen(p_port, p_bind_addr)
	if error != OK:
		printerr("Cannot create TCP Server with error code:", error)
		tcp_srvr = null
	
	return tcp_srvr


static func tcp_srvr_is_running(p_tcp_srvr: TCPServer) -> bool:
	if p_tcp_srvr == null:
		return false
	return p_tcp_srvr.is_listening()


static func tcp_status(p_tcp_peer: StreamPeerTCP) -> StreamPeerTCP.Status:
	if p_tcp_peer == null: return StreamPeerTCP.STATUS_NONE
	
	var poll_status: Error = p_tcp_peer.poll()
	if poll_status != OK:
		printerr("StreamPeerTCP.poll error code:", poll_status)
		return StreamPeerTCP.STATUS_ERROR
	
	return p_tcp_peer.get_status()
