#"res://Scripts/Autoload/aControllerBus.gd"
extends Node

enum BusStatuses {
	OK = 0, 
	WORKING = 1,
}

enum DbFieldTypes {
	INT_U,
	VARCHAR64,
	TINY_INT_U
}

# NOTE This enum must match the one on the Cluster Controller
enum BussFuncCodes {
	DB_INSERT_OR_UPDATE_PLYR,
	DB_INSERT_MSG_BLOCKED_PLYR,
	DB_DELETE_MSG_BLOCKED_PLYR,
	DB_SELECT_MSG_BLOCKED_BY_DISPLAY_NAMES,
	DB_SELECT_PLYR_INVENTORY,
	DB_UPDATE_PLYR_INVENTORY,
	DB_DELETE_FROM_PLYR_INVENTORY,
	ADD_PLYR_TO_MATCH_QUEUE,
	DELETE_PLYR_FROM_MATCH_QUEUE,
}

enum JobFields {
	TX_BYTES,
	JOB_CALLBACK,
	START_TIME
}

enum PacketSegments {
	STATUS,
	DATA
}

const DB_STMT_PARAMS: Dictionary = {
	BussFuncCodes.DB_INSERT_OR_UPDATE_PLYR: [
		DbFieldTypes.INT_U, 	# player id
		DbFieldTypes.VARCHAR64, # player display name
		DbFieldTypes.TINY_INT_U # Status code 1 = online 
	],
	BussFuncCodes.DB_INSERT_MSG_BLOCKED_PLYR: [
		DbFieldTypes.INT_U, 	# player id
		DbFieldTypes.VARCHAR64, # display name of player to block
	],
	BussFuncCodes.DB_DELETE_MSG_BLOCKED_PLYR: [
		DbFieldTypes.INT_U, 	# player id
		DbFieldTypes.VARCHAR64, # display name of player to unblock
	],
	BussFuncCodes.DB_SELECT_MSG_BLOCKED_BY_DISPLAY_NAMES: [
		DbFieldTypes.INT_U, 	# player id
	],
}

const kJobResponseTimeMsec: int = 2000
const kMinOkPacketLength: int = 5
const kMinPacketLength: int = 2
const kTcpRetryTime: float = 1.0

var _controller_tcp_peer: StreamPeerTCP
var _jobs: Dictionary = {}
var _current_job: Dictionary
var _bus_status: int = BusStatuses.WORKING
var _expected_bytes: int = 5
var _received_byte_count: bool = false
var _retry_delay_timer: float = 0.0


func _ready() -> void:
	var spb: StreamPeerBuffer = StreamPeerBuffer.new()
	spb.put_utf8_string("one")
	spb.put_utf8_string("two")
	spb.put_utf8_string("three")
	spb.put_utf8_string("four")
	spb.seek(0)
	var spb_size: int = spb.get_size()
	print(spb.get_size())
	while spb.get_position() < spb_size:
		print(spb.get_position())
		print(spb.get_utf8_string())


func _process(p_delta: float) -> void:
	if (Cfg.controller_url == "" or Cfg.controller_port == 0 or Cfg.controller_port == null):
		return
	
	if not NetTool.tcp_is_connected(_controller_tcp_peer):
		if not _current_job.is_empty():
			var cb: Callable = _current_job[JobFields.JOB_CALLBACK]
			cb.call(ERR_CONNECTION_ERROR)
			_current_job.clear()
		
		if _retry_delay_timer < 0:
			_controller_tcp_peer = NetTool.tcp_connect(Cfg.controller_url, Cfg.controller_port)
			if not NetTool.tcp_is_connected(_controller_tcp_peer):
				_retry_delay_timer = kTcpRetryTime
		else:
			_retry_delay_timer -= p_delta
	else:
		var avail_bytes: int = _controller_tcp_peer.get_available_bytes()
		if _current_job.is_empty():
			var _flush_bytes: Array = _controller_tcp_peer.get_data(avail_bytes)
			for key: String in _jobs:
				_current_job = _jobs[key]
				_current_job[JobFields.START_TIME] = Time.get_ticks_msec()
				var bytes: PackedByteArray = _current_job[JobFields.TX_BYTES]
				var error: Error = _controller_tcp_peer.put_data(bytes)
				if error != OK:
					var cb: Callable = _current_job[JobFields.JOB_CALLBACK]
					cb.call(error)
					_clear_job()
				if _jobs.erase(key): pass
				
				return
		else:
			var cb: Callable = _current_job[JobFields.JOB_CALLBACK]
			if Time.get_ticks_msec() - _current_job[JobFields.START_TIME] > kJobResponseTimeMsec:
				if cb.is_valid():
					cb.call(ERR_CONNECTION_ERROR)
				_clear_job()
			elif avail_bytes >= kMinPacketLength:
				if _bus_status == BusStatuses.WORKING:
					_expected_bytes = kMinOkPacketLength
					_bus_status = _controller_tcp_peer.get_16()
					_current_job[JobFields.START_TIME] = Time.get_ticks_msec()
					# There will be another status in the stream
					return
				
				if _bus_status != BusStatuses.OK:
					if cb.is_valid():
						cb.call(_bus_status)
					_clear_job()
					return
				
				avail_bytes = _controller_tcp_peer.get_available_bytes()
				if avail_bytes < _expected_bytes:
					return
				
				if not _received_byte_count:
					_expected_bytes = _controller_tcp_peer.get_u32()
					_received_byte_count = true
					_current_job[JobFields.START_TIME] = Time.get_ticks_msec()
					return
				
				var packet: Array = _controller_tcp_peer.get_data(avail_bytes)
				if packet[PacketSegments.STATUS] != OK:
					if cb.is_valid():
						cb.call(packet[PacketSegments.STATUS])
					_clear_job()
					return
				
				var spb: StreamPeerBuffer = StreamPeerBuffer.new()
				var pba: PackedByteArray = packet[PacketSegments.DATA]
				spb.set_data_array(pba)
				if cb.is_valid():
					cb.call(packet[PacketSegments.STATUS], spb)
				_clear_job()


#func send_bytes(p_byte: PackedByteArray)

## job_id needs to be unique to the job pool or it will be replaced. [br]
## Tip: Use container_name + calling function name. [br]
## This can be useful to replace a job with an updated version, if not processed yet.
func add_db_job(
	p_func_code: BussFuncCodes,
	p_unique_job_id: String,
	p_sql_params: Array = [],
	p_callback: Callable = Callable()
) -> bool:
	
	var valid_params: Array = DB_STMT_PARAMS.get(p_func_code)
	if valid_params == null:
		printerr("ControllerBus add_db_job STMT_PARAMS ID:%d not found!" % p_func_code)
		return false
	
	if p_sql_params.size() != valid_params.size():
		printerr("ControllerBus add_db_job job params do not match STMT_PARAMS ID:%d!" % 
			[p_func_code])
		return false
	
	var bfr: StreamPeerBuffer = StreamPeerBuffer.new()
	bfr.put_u16(p_func_code)

	for idx: int in p_sql_params.size():
		var val: Variant = p_sql_params[idx]
		var type: DbFieldTypes = valid_params[idx]
		if not _check_parameter_type(val, type):
			printerr("ControllerBus add_db_job job params types do not match STMT_PARAMS ID:%d!" % 
			[p_func_code])
			return false
		else:
			_put_data_by_type(bfr, val, type)
	
	# call_deferred happens at the end of process loop, prevents race conditions on _jobs
	call_deferred("_add_job_deferred", p_unique_job_id, bfr.data_array.duplicate(), p_callback)
	return true


func _add_job_deferred(p_job_id:String, p_data: PackedByteArray, p_callback: Callable) -> void:
	_jobs[p_job_id] = {JobFields.TX_BYTES: p_data, JobFields.JOB_CALLBACK: p_callback}


func _check_parameter_type(p_param: Variant, p_type: DbFieldTypes) -> bool:
	match p_type:
		DbFieldTypes.INT_U:
			if typeof(p_param) != TYPE_INT:
				return false
			if p_param < 0 or p_param > 4294967295:
				return false
		DbFieldTypes.VARCHAR64:
			if typeof(p_param) != TYPE_STRING:
				return false
			if str(p_param).length() > 64:
				return false
		DbFieldTypes.TINY_INT_U:
			if typeof(p_param) != TYPE_INT:
				return false
			if p_param < 0 or p_param > 255:
				return false
	
	return true


func _clear_job() -> void:
	_current_job.clear()
	_expected_bytes = kMinOkPacketLength
	_received_byte_count = false


func _put_data_by_type(p_bfr: StreamPeerBuffer, p_val: Variant, p_type: DbFieldTypes) -> void:
	match p_type:
		DbFieldTypes.INT_U:
			var v: int = p_val
			p_bfr.put_u32(v)
		DbFieldTypes.VARCHAR64:
			p_bfr.put_string(str(p_val))
		DbFieldTypes.TINY_INT_U:
			var v: int = p_val
			p_bfr.put_u8(v)
