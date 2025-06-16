extends Node3D

enum func_id {
	zero,
	one,
	two,
	three,
	four,
	five,
	six,
	seven,
	eight,
	nine,
	last
}

var _func_dispatch: Dictionary = {
	func_id.zero:	Callable(self, "_test_callable"),
	func_id.one:	Callable(self, "_test_callable"),
	func_id.two:	Callable(self, "_test_callable"),
	func_id.three:	Callable(self, "_test_callable"),
	func_id.four:	Callable(self, "_test_callable"),
	func_id.five:	Callable(self, "_test_callable"),
	func_id.six:	Callable(self, "_test_callable"),
	func_id.seven:	Callable(self, "_test_callable"),
	func_id.eight:	Callable(self, "_test_callable"),
	func_id.nine:	Callable(self, "_test_callable"),
}

# Called when the node enters the scene tree for the first time.
func _ready():
	#var some_class := TestFree.new()
	#some_class.queue_free()
	var start_us: int = Time.get_ticks_usec()
	for j:int in 100000:
		for i:int in func_id.last:
			var cb: Callable = _func_dispatch.get(i, null)
			if cb.is_valid():
				cb.call(true)
	print("time us:", Time.get_ticks_usec() - start_us)
	start_us = Time.get_ticks_usec()
	for j:int in 100000:
		for i:int in func_id.last:
			match i:
					func_id.zero: 
						_test_callable(true)
					func_id.one: 
						_test_callable(true)
					func_id.two: 
						_test_callable(true)
					func_id.three: 
						_test_callable(true)
					func_id.four: 
						_test_callable(true)
					func_id.five: 
						_test_callable(true)
					func_id.six: 
						_test_callable(true)
					func_id.seven: 
						_test_callable(true)
					func_id.eight: 
						_test_callable(true)
					func_id.nine: 
						_test_callable(true)
					_:
						_test_callable(true)
	print("time us:", Time.get_ticks_usec() - start_us)
	
	pass


func _test_callable(p: bool) -> void:
	if p:
		pass
