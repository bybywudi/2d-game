extends Enemy

enum State {
	IDLE,
	ATTACK_1,
	ATTACK_4,
	JUMP_TO_PLAYER,
	JUAM_AWAY_FROM_PLAYER
}

const KNOCKBACK_AMOUNT := 256.0

var pending_damage: Damage
@onready var wall_checker_left: RayCast2D = $Graphics/WallCheckerLeft
@onready var wall_checker_right: RayCast2D = $Graphics/WallCheckerRight
@onready var player_checker_left: RayCast2D = $Graphics/PlayerCheckerLeft
@onready var player_checker_right: RayCast2D = $Graphics/PlayerCheckerRight
@onready var player_distance_checker_left: RayCast2D = $Graphics/PlayerDistanceCheckerLeft
@onready var player_distance_checker_right: RayCast2D = $Graphics/PlayerDistanceCheckerRight
@onready var floor_checker: RayCast2D = $Graphics/FloorChecker

@onready var calm_down_timer: Timer = $CalmDownTimer


#func can_see_player() -> bool:
	##if not player_checker_left.is_colliding() and not player_checker_right.is_colliding() :
		##return false
	##return player_checker_left.get_collider() is Player or  player_checker_right.get_collider() is Player
	#return false
	#
#func too_near_with_player() -> bool:
	#if not player_distance_checker_left.is_colliding() and not player_distance_checker_right.is_colliding() :
		#return false
	#return player_distance_checker_left.get_collider() is Player or  player_distance_checker_right.get_collider() is Player
#
#func get_player_position() -> Vector2:
	#if player_checker_left.get_collider() is Player:
		#return player_checker_left.get_collision_point()
	#if player_checker_right.get_collider() is Player:
		#return player_checker_right.get_collision_point()
	#return Vector2(1512,231)
#
#func jump_direction_if_too_near() -> int:
	#if player_distance_checker_left.is_colliding():
		#if wall_checker_right.is_colliding():
			#return -1
		#else:
			#return 1
	#if player_distance_checker_right.is_colliding():
		#if wall_checker_left.is_colliding():
			#return 1
		#else:
			#return -1
	#return 1

func tick_physics(state: State, delta: float) -> void:
	if pending_damage:
		SoundManager.play_sfx("EnemyAttacked")
		stats.health -= pending_damage.amount
		pending_damage = null
		
	match state:
		State.IDLE, State.ATTACK_1:
			print("idle")
			move(0.0, delta)
		
		#State.JUMP_TO_PLAYER:
			#var dir := global_position.direction_to(get_player_position())
			#move(200.0 * dir.x, delta)
		#
		#State.JUAM_AWAY_FROM_PLAYER:
			#var dir := global_position.direction_to(get_player_position())
			#move(-200.0 * dir.x, delta)

func get_next_state(state: State) -> int:
	#if stats.health == 0:
		#return StateMachine.KEEP_CURRENT if state == State.DYING else State.DYING
	#if not can_see_player():
	return State.IDLE
		
	#match state:
		#State.IDLE:
			#if not can_see_player():
				#return StateMachine.KEEP_CURRENT
			#if can_see_player():
				#return State.JUMP_TO_PLAYER
			#if state_machine.state_time > 1 and not too_near_with_player():
				#return State.JUMP_TO_PLAYER
			#if state_machine.state_time > 1 and too_near_with_player():
				#return State.JUAM_AWAY_FROM_PLAYER
		#
		#State.JUMP_TO_PLAYER:
			#if is_on_floor():
				#return State.ATTACK_1
			#
		#State.ATTACK_1:
			#if not animation_player.is_playing():
				#return State.IDLE
	
	#return StateMachine.KEEP_CURRENT


func transition_state(from: State, to: State) -> void:
#	print("[%s] %s => %s" % [
#		Engine.get_physics_frames(),
#		State.keys()[from] if from != -1 else "<START>",
#		State.keys()[to],
#	])	
	#var dir := global_position.direction_to(get_player_position())
	#print(dir)
	#direction = int(dir.x)
	match to:
		State.IDLE:
			animation_player.play("idle")
		
		State.ATTACK_1:
			animation_player.play("attack1")
		
		State.ATTACK_4:
			animation_player.play("attack4")
		
		State.JUMP_TO_PLAYER and State.JUAM_AWAY_FROM_PLAYER:
			velocity.y += -380
			animation_player.play("jump")
		


func _on_hurtbox_hurt(hitbox: Hitbox) -> void:
	pending_damage = Damage.new()
	pending_damage.amount = 1
	pending_damage.source = hitbox.owner
