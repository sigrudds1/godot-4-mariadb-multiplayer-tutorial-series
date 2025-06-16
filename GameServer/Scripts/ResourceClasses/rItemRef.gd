extends Node

var stat_ref_json: Dictionary = {
	1: "TR_KinDmg",
	2: "TR_KinRes"
}
var rarity_ref_json: Dictionary = {
	0: "TR_Common",
	1: "TR_Uncommon"
}

var item_ref_json: Dictionary = {
   2001: {
		"desc": "VulcanCannonR0T0",
		"tr_name": "TR_Vulcan_Cannon",
		"rarity": 0,
		"tier": 0,
		"stats": {
			"TR_KinDmg": {"min": 10, "max": 20}, 
			"TR_KinRes": {"min": 40, "max": 60}
		}
	}
}

static var starter_items: Dictionary = {
	
}

static var items_lookup: Dictionary = {
	1:
		{
			
		}
}
