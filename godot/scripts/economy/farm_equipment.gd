## Farm Tools & Equipment Catalogue
## 50 authentic farming items, from luxury to basic
## Used for farmstead decoration and future gameplay mechanics
class_name FarmEquipment
extends RefCounted

enum Kind {
	# Luxury Equipment (₹500k+)
	SOLAR_PANEL_SYSTEM,
	DRIP_IRRIGATION_MOTOR,
	GREENHOUSE_HEATER,
	AGRICULTURAL_DRONE,
	SOIL_TESTING_KIT,

	# Premium Equipment (₹100k - ₹500k)
	MOTOR_PUMP_5HP,
	POWER_TILLER,
	SPRAYER_500L,
	HARVESTER_MACHINE,
	GRAIN_WINNOWER,

	# Mid-Range Equipment (₹50k - ₹100k)
	MOTOR_PUMP_3HP,
	DIESEL_ENGINE,
	FERTILIZER_SPREADER,
	WATER_TANK_1000L,
	ROPE_AND_PULLEY,

	# Standard Equipment (₹10k - ₹50k)
	HAND_PUMP,
	BULLOCK_CART,
	WOODEN_PLOUGH,
	HARROW,
	SEED_DRILL,
	HOSE_PIPE_50M,
	METAL_BUCKET_20L,
	PITCHFORK,
	SPADE,

	# Common Tools (₹1k - ₹10k)
	SHOVEL,
	HOE,
	RAKE,
	BROOM,
	ROPE_BUNDLE,
	CHAIN_LOCK,
	WOODEN_LADDER,
	BAMBOO_LADDER,
	MEASURING_SCALE,
	BASKET_WOVEN,

	# Basic Tools (₹100 - ₹1k)
	AXE,
	PRUNING_SAW,
	HAND_SAW,
	HAMMER,
	PLIERS,
	WRENCH,
	SCREWDRIVER_SET,
	NAILS_BUNDLE,
	ROPE_THIN,
	TWINE,
}


static func equipment_name(kind: int) -> String:
	match kind:
		Kind.SOLAR_PANEL_SYSTEM: return "Solar Panel System"
		Kind.DRIP_IRRIGATION_MOTOR: return "Drip Irrigation Motor"
		Kind.GREENHOUSE_HEATER: return "Greenhouse Heater"
		Kind.AGRICULTURAL_DRONE: return "Agricultural Drone"
		Kind.SOIL_TESTING_KIT: return "Soil Testing Kit"
		Kind.MOTOR_PUMP_5HP: return "Motor Pump 5HP"
		Kind.POWER_TILLER: return "Power Tiller"
		Kind.SPRAYER_500L: return "Sprayer 500L"
		Kind.HARVESTER_MACHINE: return "Harvester Machine"
		Kind.GRAIN_WINNOWER: return "Grain Winnower"
		Kind.MOTOR_PUMP_3HP: return "Motor Pump 3HP"
		Kind.DIESEL_ENGINE: return "Diesel Engine"
		Kind.FERTILIZER_SPREADER: return "Fertilizer Spreader"
		Kind.WATER_TANK_1000L: return "Water Tank 1000L"
		Kind.ROPE_AND_PULLEY: return "Rope & Pulley Set"
		Kind.HAND_PUMP: return "Hand Pump"
		Kind.BULLOCK_CART: return "Bullock Cart"
		Kind.WOODEN_PLOUGH: return "Wooden Plough"
		Kind.HARROW: return "Harrow"
		Kind.SEED_DRILL: return "Seed Drill"
		Kind.HOSE_PIPE_50M: return "Hose Pipe 50m"
		Kind.METAL_BUCKET_20L: return "Metal Bucket 20L"
		Kind.PITCHFORK: return "Pitchfork"
		Kind.SPADE: return "Spade"
		Kind.SHOVEL: return "Shovel"
		Kind.HOE: return "Hoe"
		Kind.RAKE: return "Rake"
		Kind.BROOM: return "Broom"
		Kind.ROPE_BUNDLE: return "Rope Bundle"
		Kind.CHAIN_LOCK: return "Chain Lock"
		Kind.WOODEN_LADDER: return "Wooden Ladder"
		Kind.BAMBOO_LADDER: return "Bamboo Ladder"
		Kind.MEASURING_SCALE: return "Measuring Scale"
		Kind.BASKET_WOVEN: return "Woven Basket"
		Kind.AXE: return "Axe"
		Kind.PRUNING_SAW: return "Pruning Saw"
		Kind.HAND_SAW: return "Hand Saw"
		Kind.HAMMER: return "Hammer"
		Kind.PLIERS: return "Pliers"
		Kind.WRENCH: return "Wrench"
		Kind.SCREWDRIVER_SET: return "Screwdriver Set"
		Kind.NAILS_BUNDLE: return "Nails Bundle"
		Kind.ROPE_THIN: return "Thin Rope"
		Kind.TWINE: return "Twine"
		_: return "Unknown Equipment"


static func equipment_cost(kind: int) -> int:
	match kind:
		# Luxury (₹500k+)
		Kind.SOLAR_PANEL_SYSTEM: return 800_000
		Kind.AGRICULTURAL_DRONE: return 750_000
		Kind.DRIP_IRRIGATION_MOTOR: return 650_000
		Kind.GREENHOUSE_HEATER: return 600_000
		Kind.SOIL_TESTING_KIT: return 500_000

		# Premium (₹100k - ₹500k)
		Kind.HARVESTER_MACHINE: return 450_000
		Kind.MOTOR_PUMP_5HP: return 400_000
		Kind.POWER_TILLER: return 350_000
		Kind.GRAIN_WINNOWER: return 300_000
		Kind.SPRAYER_500L: return 250_000

		# Mid-Range (₹50k - ₹100k)
		Kind.MOTOR_PUMP_3HP: return 120_000
		Kind.WATER_TANK_1000L: return 90_000
		Kind.DIESEL_ENGINE: return 85_000
		Kind.FERTILIZER_SPREADER: return 75_000
		Kind.ROPE_AND_PULLEY: return 45_000

		# Standard (₹10k - ₹50k)
		Kind.HAND_PUMP: return 35_000
		Kind.BULLOCK_CART: return 30_000
		Kind.WOODEN_PLOUGH: return 25_000
		Kind.HOSE_PIPE_50M: return 18_000
		Kind.SEED_DRILL: return 16_000
		Kind.HARROW: return 15_000
		Kind.METAL_BUCKET_20L: return 12_000
		Kind.PITCHFORK: return 10_000
		Kind.SPADE: return 9_000

		# Common (₹1k - ₹10k)
		Kind.SHOVEL: return 8_000
		Kind.HOE: return 7_000
		Kind.RAKE: return 6_000
		Kind.WOODEN_LADDER: return 5_500
		Kind.BAMBOO_LADDER: return 5_000
		Kind.MEASURING_SCALE: return 4_500
		Kind.BASKET_WOVEN: return 3_500
		Kind.CHAIN_LOCK: return 3_000
		Kind.ROPE_BUNDLE: return 2_500
		Kind.BROOM: return 2_000

		# Basic (₹100 - ₹1k)
		Kind.AXE: return 1_200
		Kind.PRUNING_SAW: return 1_000
		Kind.HAMMER: return 800
		Kind.HAND_SAW: return 700
		Kind.PLIERS: return 600
		Kind.WRENCH: return 500
		Kind.SCREWDRIVER_SET: return 400
		Kind.ROPE_THIN: return 300
		Kind.NAILS_BUNDLE: return 200
		Kind.TWINE: return 100

		_: return 0


static func equipment_emoji(kind: int) -> String:
	match kind:
		Kind.SOLAR_PANEL_SYSTEM: return "☀️"
		Kind.AGRICULTURAL_DRONE: return "🚁"
		Kind.DRIP_IRRIGATION_MOTOR: return "💧"
		Kind.GREENHOUSE_HEATER: return "🔥"
		Kind.SOIL_TESTING_KIT: return "🧪"
		Kind.HARVESTER_MACHINE: return "🚜"
		Kind.MOTOR_PUMP_5HP: return "⚙️"
		Kind.POWER_TILLER: return "🚜"
		Kind.GRAIN_WINNOWER: return "🌾"
		Kind.SPRAYER_500L: return "💦"
		Kind.MOTOR_PUMP_3HP: return "⚙️"
		Kind.DIESEL_ENGINE: return "🔧"
		Kind.FERTILIZER_SPREADER: return "🌱"
		Kind.WATER_TANK_1000L: return "🛢️"
		Kind.ROPE_AND_PULLEY: return "🔗"
		Kind.HAND_PUMP: return "🚰"
		Kind.BULLOCK_CART: return "🐂"
		Kind.WOODEN_PLOUGH: return "🪡"
		Kind.HARROW: return "🪓"
		Kind.SEED_DRILL: return "🌾"
		Kind.HOSE_PIPE_50M: return "🔄"
		Kind.METAL_BUCKET_20L: return "🪣"
		Kind.PITCHFORK: return "🔱"
		Kind.SPADE: return "🗡️"
		Kind.SHOVEL: return "⛏️"
		Kind.HOE: return "🪛"
		Kind.RAKE: return "🧹"
		Kind.WOODEN_LADDER: return "🪜"
		Kind.BAMBOO_LADDER: return "🎋"
		Kind.MEASURING_SCALE: return "📏"
		Kind.BASKET_WOVEN: return "🧺"
		Kind.CHAIN_LOCK: return "🔐"
		Kind.ROPE_BUNDLE: return "🧵"
		Kind.BROOM: return "🧹"
		Kind.AXE: return "🪓"
		Kind.PRUNING_SAW: return "🔨"
		Kind.HAND_SAW: return "🔩"
		Kind.HAMMER: return "🔨"
		Kind.PLIERS: return "🔧"
		Kind.WRENCH: return "🔩"
		Kind.SCREWDRIVER_SET: return "🔧"
		Kind.NAILS_BUNDLE: return "📌"
		Kind.ROPE_THIN: return "📍"
		Kind.TWINE: return "📎"
		_: return "❓"


static func equipment_description(kind: int) -> String:
	match kind:
		Kind.SOLAR_PANEL_SYSTEM: return "Renewable energy for farm operations"
		Kind.AGRICULTURAL_DRONE: return "Monitor crops from above"
		Kind.DRIP_IRRIGATION_MOTOR: return "Automated water delivery system"
		Kind.GREENHOUSE_HEATER: return "Climate control for polyhouse"
		Kind.SOIL_TESTING_KIT: return "Analyze soil quality & nutrients"
		Kind.HARVESTER_MACHINE: return "Mechanical crop harvesting"
		Kind.MOTOR_PUMP_5HP: return "Heavy-duty water pumping"
		Kind.POWER_TILLER: return "Motorized soil preparation"
		Kind.GRAIN_WINNOWER: return "Separate grain from chaff"
		Kind.SPRAYER_500L: return "Large-capacity pesticide sprayer"
		Kind.MOTOR_PUMP_3HP: return "Medium water pumping capacity"
		Kind.DIESEL_ENGINE: return "Backup power generator"
		Kind.FERTILIZER_SPREADER: return "Even fertilizer distribution"
		Kind.WATER_TANK_1000L: return "Store water for dry season"
		Kind.ROPE_AND_PULLEY: return "Lifting and load management"
		Kind.HAND_PUMP: return "Manual water pumping"
		Kind.BULLOCK_CART: return "Traditional transport cart"
		Kind.WOODEN_PLOUGH: return "Traditional soil preparation"
		Kind.HARROW: return "Break up soil clods"
		Kind.SEED_DRILL: return "Precise seed spacing"
		Kind.HOSE_PIPE_50M: return "Long-distance water delivery"
		Kind.METAL_BUCKET_20L: return "Heavy-duty water container"
		Kind.PITCHFORK: return "Hay and compost handling"
		Kind.SPADE: return "Digging and turning soil"
		Kind.SHOVEL: return "Scooping and moving soil"
		Kind.HOE: return "Weeding and tilling"
		Kind.RAKE: return "Leveling and gathering"
		Kind.WOODEN_LADDER: return "Safe climbing access"
		Kind.BAMBOO_LADDER: return "Lightweight climbing tool"
		Kind.MEASURING_SCALE: return "Measure distances & heights"
		Kind.BASKET_WOVEN: return "Harvest and carry crops"
		Kind.CHAIN_LOCK: return "Secure equipment storage"
		Kind.ROPE_BUNDLE: return "Heavy-duty binding & tying"
		Kind.BROOM: return "Sweep and clean"
		Kind.AXE: return "Cut wood and branches"
		Kind.PRUNING_SAW: return "Trim tree branches"
		Kind.HAND_SAW: return "Precise cutting work"
		Kind.HAMMER: return "Drive nails and stakes"
		Kind.PLIERS: return "Gripping and bending"
		Kind.WRENCH: return "Tighten bolts and nuts"
		Kind.SCREWDRIVER_SET: return "Assembly and repairs"
		Kind.NAILS_BUNDLE: return "Fastening materials"
		Kind.ROPE_THIN: return "Light binding and tying"
		Kind.TWINE: return "Bundling crops and hay"
		_: return "Farm equipment"


static func all_equipment() -> Array[int]:
	return [
		Kind.SOLAR_PANEL_SYSTEM,
		Kind.AGRICULTURAL_DRONE,
		Kind.DRIP_IRRIGATION_MOTOR,
		Kind.GREENHOUSE_HEATER,
		Kind.SOIL_TESTING_KIT,
		Kind.HARVESTER_MACHINE,
		Kind.MOTOR_PUMP_5HP,
		Kind.POWER_TILLER,
		Kind.GRAIN_WINNOWER,
		Kind.SPRAYER_500L,
		Kind.MOTOR_PUMP_3HP,
		Kind.WATER_TANK_1000L,
		Kind.DIESEL_ENGINE,
		Kind.FERTILIZER_SPREADER,
		Kind.ROPE_AND_PULLEY,
		Kind.HAND_PUMP,
		Kind.BULLOCK_CART,
		Kind.WOODEN_PLOUGH,
		Kind.HOSE_PIPE_50M,
		Kind.SEED_DRILL,
		Kind.HARROW,
		Kind.METAL_BUCKET_20L,
		Kind.PITCHFORK,
		Kind.SPADE,
		Kind.SHOVEL,
		Kind.HOE,
		Kind.RAKE,
		Kind.WOODEN_LADDER,
		Kind.BAMBOO_LADDER,
		Kind.MEASURING_SCALE,
		Kind.BASKET_WOVEN,
		Kind.CHAIN_LOCK,
		Kind.ROPE_BUNDLE,
		Kind.BROOM,
		Kind.AXE,
		Kind.PRUNING_SAW,
		Kind.HAMMER,
		Kind.HAND_SAW,
		Kind.PLIERS,
		Kind.WRENCH,
		Kind.SCREWDRIVER_SET,
		Kind.ROPE_THIN,
		Kind.NAILS_BUNDLE,
		Kind.TWINE,
	]
