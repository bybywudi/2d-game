extends World


func _on_boar_died() -> void:
	await get_tree().create_timer(1).timeout
	GameGlobal.change_scene("res://ui/game_end_screen.tscn", {
		duration=1,
	})
