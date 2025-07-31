# Autoload DataTypes
extends Node

enum MatchType {
	NONE,
	ONLY_PVE,
	ONLY_PVP,
	TRY_PVP,
}

enum PlaySide{
	NONE,
	ONLY_TANKS,
	ONLY_TOWERS,
	PREFER_TANKS,
	PREFER_TOWERS,
	ANY,
}

# THINKING OUTLOUD
enum TargetingModes{ # Server data key - TM
	NONE,
	DETECTED,
	DEBUFF,
	BUFF,
	NEAREST,
	LOWEST_HP
}

enum DmgTypes{ # Server data key - DT
	NONE,
	ENERGY,
	KINETIC,
}

enum UnitTypes { # Server data key - UT
	NONE,
	TANK,
	TOWER
}

enum TurretTypes{ # Server data key - UST
	NONE,
	VULCAN, # kinetic
	MISSILE, # kinetic
	RAILGUN, # kinetic
	MICROWAVE, # Energy
	PLASMA, # Energy
	LASER, # Energy
}


enum ArmotTypes{
	NONE,
	REACTIVE,
	BIRDCAGE,
	notdone
}

enum ServerDataKeys{
	UNIT_TYPE = 0,
	TURRET_TYPE = 1,
	DAMAGE_TYPE = 2,
	TARGETTING_MODE = 3,
	DAMAGE_AMOUNT = 4,
	RATE_OF_FIRE = 5,
	SENSOR_RANGE = 6,
	ATTACK_RANGE = 7,
	GRID_LOCATION = 8,
	MOVE_SPEED = 9,
	not_done
}
