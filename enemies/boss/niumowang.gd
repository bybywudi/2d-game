extends Enemy

enum State {
	IDLE,
	ATTACK_1,
	ATTACK_2,
	ATTACK_4,
	JUMP_TO_PLAYER,
	JUMP_ATTACK,
	JUMP_AWAY_FROM_PLAYER,
	FALL,
	WALK,
	DASH,
	ROTATE,
}

const KNOCKBACK_AMOUNT := 256.0
const FAR_FROM_PLAYER_DISTANCE := 150.0
const NEER_WITH_PLAYER_DISTANCE := 80.0
const WALK_SPEED := -100
const DASH_SPEED := -300
const ROTATE_SPEED := -200
const DASH_TIME := 2
const JUMP_X_SPEED := -200.0
const JUMP_Y_SPEED := -380
@onready var fall_x_speed: float = JUMP_X_SPEED

var pending_damage: Damage
@onready var wall_checker_left: RayCast2D = $Graphics/WallCheckerLeft
@onready var wall_checker_right: RayCast2D = $Graphics/WallCheckerRight
@onready var player_checker_left: RayCast2D = $Graphics/PlayerCheckerLeft
@onready var player_checker_right: RayCast2D = $Graphics/PlayerCheckerRight
@onready var player_distance_checker_left: RayCast2D = $Graphics/PlayerDistanceCheckerLeft
@onready var player_distance_checker_right: RayCast2D = $Graphics/PlayerDistanceCheckerRight
@onready var floor_checker: RayCast2D = $Graphics/FloorChecker
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var hurt_box: CollisionShape2D = $Graphics/Hurtbox/HurtBox
@onready var dash_cool_down_timer: Timer = $DashCoolDownTimer
@onready var rotate_cool_down_timer: Timer = $RotateCoolDownTimer
@onready var jump_attack_cool_down_timer: Timer = $JumpAttackCoolDownTimer
@onready var attack_2_cool_down_timer: Timer = $Attack2CoolDownTimer
@onready var jump_to_player_cool_down_timer: Timer = $JumpToPlayerCoolDownTimer
@onready var jump_away_from_player_cool_down_timer: Timer = $JumpAwayFromPlayerCoolDownTimer
@onready var attack_4_cool_down_timer: Timer = $Attack4CoolDownTimer


#func can_see_player() -> bool:
	#if not player_checker_left.is_colliding() and not player_checker_right.is_colliding() :
		#return false
	#return player_checker_left.get_collider() is Player or  player_checker_right.get_collider() is Player

var can_see_player := false
var player: Player = null
	
func too_near_with_player() -> bool:
	#if not player_distance_checker_left.is_colliding() and not player_distance_checker_right.is_colliding() :
		#return false
	#return player_distance_checker_left.get_collider() is Player or  player_distance_checker_right.get_collider() is Player
	if abs(global_position.x - player.global_position.x) < NEER_WITH_PLAYER_DISTANCE:
		return true
	return false

func far_from_player() -> bool:
	if abs(global_position.x - player.global_position.x) > FAR_FROM_PLAYER_DISTANCE:
		return true
	return false

func get_player_position() -> Vector2:
	if player == null:
		return global_position
	return player.global_position
	#if player_checker_left.get_collider() is Player:
		#return player_checker_left.get_collision_point()
	#if player_checker_right.get_collider() is Player:
		#return player_checker_right.get_collision_point()
	#return Vector2(1512,231)

func jump_direction_if_too_near() -> int:
	if player_distance_checker_left.is_colliding():
		if wall_checker_right.is_colliding():
			return -1
		else:
			return 1
	if player_distance_checker_right.is_colliding():
		if wall_checker_left.is_colliding():
			return 1
		else:
			return -1
	return 1

func tick_physics(state: State, delta: float) -> void:
	if pending_damage:
		SoundManager.play_sfx("EnemyAttacked")
		stats.health -= pending_damage.amount
		pending_damage = null
		
	match state:
		State.IDLE, State.ATTACK_1, State.ATTACK_2, State.ATTACK_4:
			move(0.0, delta)
		
		State.JUMP_TO_PLAYER:
			move(JUMP_X_SPEED, delta)
		
		State.JUMP_AWAY_FROM_PLAYER:
			move(-JUMP_X_SPEED, delta)
		
		State.WALK:
			move(WALK_SPEED, delta)
		
		State.DASH:
			move(DASH_SPEED, delta)
			
		State.ROTATE:
			move(ROTATE_SPEED, delta)
		
		State.FALL, State.JUMP_ATTACK:
			move(fall_x_speed, delta)
		

func get_next_state(state: State) -> int:
	#if stats.health == 0:
		#return StateMachine.KEEP_CURRENT if state == State.DYING else State.DYING
	if not can_see_player:
		return StateMachine.KEEP_CURRENT
		
	match state:
		State.IDLE:
			if not state_machine.state_time > 1:
				return StateMachine.KEEP_CURRENT
			if not can_see_player:
				return StateMachine.KEEP_CURRENT
			if far_from_player():
				if dash_cool_down_timer.time_left == 0:
					return State.DASH
				else:
					return State.WALK
			if not too_near_with_player():
				if jump_to_player_cool_down_timer.time_left == 0:
					return State.JUMP_TO_PLAYER
				if rotate_cool_down_timer.time_left == 0:
					return State.ROTATE
			if too_near_with_player():
				if attack_4_cool_down_timer.time_left == 0:
					return State.ATTACK_4
				if jump_away_from_player_cool_down_timer.time_left == 0:
					return State.JUMP_AWAY_FROM_PLAYER
			
		
		State.JUMP_TO_PLAYER:
			if jump_attack_cool_down_timer.time_left == 0:
				return State.JUMP_ATTACK
			if velocity.y >= 0:
				return State.FALL
		
		State.JUMP_AWAY_FROM_PLAYER:
			if velocity.y >= 0:
				return State.FALL
		
		State.FALL:
			if is_on_floor():
				if attack_4_cool_down_timer.time_left == 0:
					return State.ATTACK_4
				return State.IDLE
		
		State.JUMP_ATTACK:
			if not animation_player.is_playing():
				return State.IDLE
				
		State.WALK:
			if not far_from_player():
				if jump_to_player_cool_down_timer.time_left == 0:
					return State.JUMP_TO_PLAYER
				else:
					return State.IDLE
			
		State.ATTACK_1:
			if not animation_player.is_playing():
				if attack_2_cool_down_timer.time_left == 0:
					return State.ATTACK_2
				return State.IDLE
		
		State.ATTACK_2:
			if not animation_player.is_playing():
				return State.IDLE
		
		State.ATTACK_4:
			if not animation_player.is_playing():
				return State.IDLE
		
		State.DASH, State.ROTATE:
			if not animation_player.is_playing():
				return State.IDLE
	
	return StateMachine.KEEP_CURRENT


func face_to_player() -> void:
	var dir := global_position.direction_to(get_player_position())
	if dir.x > 0.0:
		direction = -1
	else:
		direction = 1
		
func transition_state(from: State, to: State) -> void:
#	print("[%s] %s => %s" % [
#		Engine.get_physics_frames(),
#		State.keys()[from] if from != -1 else "<START>",
#		State.keys()[to],
#	])	
	match to:
		State.IDLE:
			face_to_player()
			animation_player.play("idle")
		
		State.ATTACK_1:
			animation_player.play("attack1")
		
		State.ATTACK_2:
			attack_2_cool_down_timer.start()
			animation_player.play("attack2")
		
		State.ATTACK_4:
			attack_4_cool_down_timer.start()
			animation_player.play("attack4")
		
		State.JUMP_TO_PLAYER:
			jump_to_player_cool_down_timer.start()
			face_to_player()
			fall_x_speed = JUMP_X_SPEED
			velocity.y = JUMP_Y_SPEED
			animation_player.play("jump")
		
		State.JUMP_AWAY_FROM_PLAYER:
			jump_away_from_player_cool_down_timer.start()
			face_to_player()
			fall_x_speed = -JUMP_X_SPEED
			velocity.y = JUMP_Y_SPEED
			animation_player.play("jump")
		
		State.WALK:
			face_to_player()
			animation_player.play("walk")
			
		State.FALL:
			animation_player.play("fall")
		
		State.JUMP_ATTACK:
			jump_attack_cool_down_timer.start()
			animation_player.play("jump_attack")
		
		State.DASH:
			dash_cool_down_timer.start()
			face_to_player()
			animation_player.play("dash")
		
		State.ROTATE:
			rotate_cool_down_timer.start()
			face_to_player()
			animation_player.play("rotate")
		


func _on_hurtbox_hurt(hitbox: Hitbox) -> void:
	pending_damage = Damage.new()
	pending_damage.amount = 1
	pending_damage.source = hitbox.owner
	

func _on_boss_fight_area_enter(hurtbox: Variant) -> void:
	if hurtbox.owner is Player:
		player = hurtbox.owner
		can_see_player = true
