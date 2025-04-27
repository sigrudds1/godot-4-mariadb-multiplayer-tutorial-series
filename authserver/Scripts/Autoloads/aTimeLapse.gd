extends Node

signal sSecondLapsed
signal sMinuteLapsed
signal sTenMinuteLapsed

const kMaxMinutes: int = 10

var _lapsed: float = 0.0
var _secs: int = 0
var _minutes: int = 0

func _physics_process(p_delta: float) -> void:
	_lapsed += p_delta
	if _lapsed >= 1.0:
		_secs += 1
		sSecondLapsed.emit()
		_lapsed -= 1.0
	
		if _secs >= 60:
			sMinuteLapsed.emit()
			_secs -= 60
			_minutes += 1
			
			if _minutes % 10 == 0:
				sTenMinuteLapsed.emit()
				
			if _minutes >= kMaxMinutes:
				_minutes -= kMaxMinutes
			
	
