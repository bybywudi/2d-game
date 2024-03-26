class_name TrapHitbox
extends EnemyHitbox


func _init() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(hurtbox: Hurtbox) -> void:
	print("[Hit] %s => %s" % [owner.name, hurtbox.owner.name])
	hit.emit(hurtbox)
	hurtbox.hurt.emit(self)
	if hurtbox.owner is Player:
		hurtbox.owner.set_global_position(hurtbox.owner.last_on_floor_position)
