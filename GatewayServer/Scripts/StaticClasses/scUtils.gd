class_name Utils extends Resource


static func thread_wait_stop(p_thr: Thread) -> void:
	if p_thr == null: return
	var delay: int = Time.get_ticks_msec() + 1000
	while p_thr.is_alive():
		if Time.get_ticks_msec() > delay:
			delay = Time.get_ticks_msec() + 1000
			print("Utils.thread_stop() Thread still alive thr:", p_thr)
		
		# You cannot call get_tree() for static classes, they are not instanced,
		# but Engine is global and get_main_loop returns the Scenetree, usually
		await Signal(Engine.get_main_loop(), "physics_frame")
	
	if p_thr.is_started():
		p_thr.wait_to_finish()
