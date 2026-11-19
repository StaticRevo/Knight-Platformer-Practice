extends Resource

# Each entry keeps its reward icon and damage together.
@export var item_name: String = "Sword"
@export var icon: Texture2D
@export_range(0, 20) var weapon_damage: int = 2

# Optional sound for this weapon. Empty uses the player's sword sound.
@export var attack_sound: AudioStream


# Tune how this icon sits in the player's hand. Coordinates are texture pixels.
@export_range(0.1, 2.0) var held_scale: float = 0.5
@export var grip_position: Vector2 = Vector2(8, 24)
@export_range(-180, 180) var resting_angle: float = -35.0


# Choose the category when configuring a chest reward.
@export_enum("Weapon", "Helmet", "Chestplate", "Pants", "Boots", "Ability") var item_type: String = "Weapon"
