class_name BossFightArea
extends Area2D

signal enter(hurtbox)

func _init() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(hurtbox: Hurtbox) -> void:
	print("enter boss area")
	enter.emit(hurtbox)
