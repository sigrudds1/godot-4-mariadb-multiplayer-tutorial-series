class_name Utils extends Object


static func thread_wait_stop(thr: Thread) -> void:
	if thr == null: return
	var delay: int = Time.get_ticks_msec() + 1000
	while thr.is_alive():
		if Time.get_ticks_msec() > delay:
			delay = Time.get_ticks_msec() + 1000
			print("Utils.thread_stop() Thread still alive thr:", thr)
	if thr.is_started():
		thr.wait_to_finish()
