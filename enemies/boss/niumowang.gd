extends Enemy

enum State {
	IDLE,
	ATTCK_1,
}

const KNOCKBACK_AMOUNT := 256.0

var pending_damage: Damage

@onready var wall_checker: RayCast2D = $Graphics/WallChecker
@onready var player_checker: RayCast2D = $Graphics/PlayerChecker
@onready var floor_checker: RayCast2D = $Graphics/FloorChecker
@onready var calm_down_timer: Timer = $CalmDownTimer


func can_see_player() -> bool:
	if not player_checker.is_colliding():
		return false
	return player_checker.get_collider() is Player


func tick_physics(state: State, delta: float) -> void:
	match state:
		State.IDLE, State.ATTCK_1:
			move(0.0, delta)


func get_next_state(state: State) -> int:
	#if stats.health == 0:
		#return StateMachine.KEEP_CURRENT if state == State.DYING else State.DYING
	
	#if pending_damage:
		#return State.HURT
	
	match state:
		State.IDLE:
			if can_see_player():
				return State.ATTCK_1
			if state_machine.state_time > 2:
				return State.ATTCK_1
		
		State.ATTCK_1:
			if not animation_player.is_playing():
				return State.IDLE
	
	return StateMachine.KEEP_CURRENT


func transition_state(from: State, to: State) -> void:
#	print("[%s] %s => %s" % [
#		Engine.get_physics_frames(),
#		State.keys()[from] if from != -1 else "<START>",
#		State.keys()[to],
#	])
	
	if pending_damage:
		SoundManager.play_sfx("EnemyAttacked")
		stats.health -= pending_damage.amount
		var dir := pending_damage.source.global_position.direction_to(global_position)
		velocity = dir * KNOCKBACK_AMOUNT
		if dir.x > 0:
			direction = Direction.LEFT
		else:
			direction = Direction.RIGHT
		pending_damage = null
		
	match to:
		State.IDLE:
			animation_player.play("idle")
			if wall_checker.is_colliding():
				direction *= -1
		
		State.ATTCK_1:
			animation_player.play("attack1")
		


func _on_hurtbox_hurt(hitbox: Hitbox) -> void:
	pending_damage = Damage.new()
	pending_damage.amount = 1
	pending_damage.source = hitbox.owner
