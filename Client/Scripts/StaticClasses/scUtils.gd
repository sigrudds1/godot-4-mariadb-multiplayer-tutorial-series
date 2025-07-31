class_name Utils extends Object


static func thread_wait_stop(thr: Thread) -> void:
	if thr == null: return
	var delay: int = Time.get_ticks_msec() + 1000
	while thr.is_alive():
		if Time.get_ticks_msec() > delay:
			delay = Time.get_ticks_msec() + 1000
			printerr("Utils.thread_stop() Thread still alive thr:", thr)
		
		# You cannot call get_tree() for static classes, they are not instanced
		# but Engine is global and get_main_loop returns the Scenetree, usually
		await Signal(Engine.get_main_loop(), "physics_frame")
	
	if thr.is_started():
		thr.wait_to_finish()
