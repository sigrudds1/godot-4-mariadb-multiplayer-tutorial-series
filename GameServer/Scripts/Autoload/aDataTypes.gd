# Autoload DataTypes
extends Node

enum TargetingModes{ # Server data key - TM
	None = -1,
	Detected = 0,
	Debuff = 1,
	Buff = 2,
	Nearest = 3,
	LowestHitPoints = 4,
}

enum DmgTypes{ # Server data key - DT
	None = -1,
	Energy,
	Kinetic,
}

enum UnitTypes { # Server data key - UT
	None = -1,
	Tank,
	Tower,
}

enum TurretTypes{ # Server data key - UST
	None = -1,
	Vulcan, # kinetic
	Missle, # kinetic
	Railgun, # kinetic
	Microwave, # Energy
	Plasma, # Energy
	Laser, # Energy
}


enum ArmotTypes{
	None = -1,
	Reactive,
	BirdCage,
}

enum ServerDataUnitKeys{
	UnitType = 0,
	TurretType = 1,
	DamageType = 2,
	TargetingMode = 3,
	DamageAmount = 4,
	RateOfFire = 5,
	SensorRange = 6,
	AttackRange = 7,
	GridLocation = 8,
	MoveSpeed = 9,
}
