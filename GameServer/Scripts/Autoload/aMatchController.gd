extends Node

# This script would be on a controller server

var _match_semaphore: Semaphore = Semaphore.new()
var _match_thread: Thread = Thread.new()
var _running: bool = true


func _ready() -> void:
	if TimeLapse.sOneSecondLapsed.connect(_post_awaiting_match_thread) != OK:
		pass
	
	var err_code: Error = _match_thread.start(_awaiting_match_thread_func.bind(_match_thread))
	if err_code != OK:
		printerr("MessageIface _block_plyer_thread start error code:" + str(err_code))


func _exit_tree() -> void:
	_running = false
	_match_semaphore.post()


func _awaiting_match_thread_func(p_this_thread: Thread) -> void:
	while _running:
		_match_semaphore.wait()
	
	Callable(Utils, "thread_wait_stop").call_deferred(p_this_thread)


func _post_awaiting_match_thread() -> void:
	_match_semaphore.post()
