extends Node

enum PlaySide{
	NONE,
	ANY,
	TANKS,
	TOWERS
}

enum MatchType {
	NONE,
	ONLY_PVE,
	TRY_PVP,
	ONLY_PVP
}

var play_side:PlaySide = PlaySide.NONE
var match_type:MatchType = MatchType.NONE

@rpc("any_peer", "reliable")
func client_place_unit(_slot_id: int, _position: Vector2i) -> void:
	pass
