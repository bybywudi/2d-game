class_name Player
extends CharacterBody2D

enum Direction {
	LEFT = -1,
	RIGHT = +1,
}

enum State {
	IDLE,
	RUNNING,
	JUMP,
	SECOND_JUMP,
	FALL,
	LANDING,
	WALL_SLIDING,
	WALL_JUMP,
	GROUND_ATTACK,
	JUMP_ATTACK,
	ATTACK_3,
	HURT,
	DYING,
	SLIDING_START,
	SLIDING_LOOP,
	SLIDING_END,
}

const GROUND_STATES := [
	State.IDLE, State.RUNNING, State.LANDING,
	State.GROUND_ATTACK,
]
const WALL_STATES := [
	State.WALL_JUMP, State.WALL_SLIDING
]
const RUN_SPEED := 160.0
const FLOOR_ACCELERATION := RUN_SPEED / 0.2
const AIR_ACCELERATION := RUN_SPEED / 0.1
const JUMP_VELOCITY := -320.0
const WALL_JUMP_VELOCITY := Vector2(380, -340)
const KNOCKBACK_AMOUNT := 512.0
const SLIDING_DURATION := 0.3
const SLIDING_SPEED := 256.0
const SLIDING_ENERGY := 4.0
const LANDING_HEIGHT := 100.0
const WALL_EDGE_ACCELERATION := -80
const TIME_BETWEEN_JUMP_AND_SECOND_JUMP := 0.2

@export var can_combo := false
@export var direction := Direction.RIGHT:
	set(v):
		direction = v
		if not is_node_ready():
			await ready
		graphics.scale.x = direction

var default_gravity := ProjectSettings.get("physics/2d/default_gravity") as float
var wall_slide_gravity := default_gravity / 10
var is_first_tick := false
#var is_combo_requested := false
var pending_damage: Damage
var fall_from_y: float
var interacting_with: Array[Interactable]
var can_second_jump := false

@onready var slide_jump_coyote_timer: Timer = $SlideJumpCoyoteTimer
@onready var graphics: Node2D = $Graphics
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_request_timer: Timer = $JumpRequestTimer
@onready var hand_checker: RayCast2D = $Graphics/HandChecker
@onready var foot_checker: RayCast2D = $Graphics/FootChecker
@onready var state_machine: Node = $StateMachine
@onready var stats: Node = Game.player_stats
@onready var jump_wall_edge_acceleration_timer: Timer = $JumpWallEdgeAccelerationTimer
@onready var wall_jump_wall_edge_acceleration_timer: Timer = $WallJumpWallEdgeAccelerationTimer
@onready var second_jump_wait_timer: Timer = $SecondJumpWaitTimer
@onready var invincible_timer: Timer = $InvincibleTimer
@onready var slide_request_timer: Timer = $SlideRequestTimer
@onready var interaction_icon: AnimatedSprite2D = $InteractionIcon
@onready var game_over_screen: Control = $CanvasLayer/GameOverScreen
@onready var pause_screen: Control = $CanvasLayer/PauseScreen
@onready var wall_slide_min_timer: Timer = $WallSlideMinTimer
@onready var wall_jump_hand_checker: RayCast2D = $Graphics/WallJumpHandChecker
@onready var wall_jump_foot_checker: RayCast2D = $Graphics/WallJumpFootChecker


func _ready() -> void:
	stand(default_gravity, 0.01)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_request_timer.start()

	if event.is_action_released("jump"):
		jump_request_timer.stop()
		if velocity.y < JUMP_VELOCITY / 2:
			velocity.y = JUMP_VELOCITY / 2
	
	#if event.is_action_pressed("attack") and can_combo:
		#is_combo_requested = true
	
	if event.is_action_pressed("slide"):
		slide_request_timer.start()
	
	if event.is_action_pressed("interact") and interacting_with:
		interacting_with.back().interact()
	
	if event.is_action_pressed("pause"):
		pause_screen.show_pause()


func tick_physics(state: State, delta: float) -> void:
	interaction_icon.visible = not interacting_with.is_empty()
	
	if invincible_timer.time_left > 0:
		graphics.modulate.a = sin(Time.get_ticks_msec() / 20) * 0.5 + 0.5
	else:
		graphics.modulate.a = 1
	
	match state:
		State.IDLE:
			move(default_gravity, delta)
		State.RUNNING:
			move(default_gravity, delta)
		
		State.JUMP:
			move(0.0 if is_first_tick else default_gravity, delta)
			if not hand_checker.is_colliding() and foot_checker.is_colliding() and jump_wall_edge_acceleration_timer.time_left == 0 and velocity.y > -100:
				jump_wall_edge_acceleration_timer.start()
				velocity.y += WALL_EDGE_ACCELERATION
				
		State.SECOND_JUMP:
			move(0.0 if is_first_tick else default_gravity, delta)
			if not hand_checker.is_colliding() and foot_checker.is_colliding() and jump_wall_edge_acceleration_timer.time_left == 0 and velocity.y > -100:
				jump_wall_edge_acceleration_timer.start()
				velocity.y += WALL_EDGE_ACCELERATION
		
		State.FALL:
			move(default_gravity, delta)
		
		State.LANDING:
			stand(default_gravity, delta)
		
		State.WALL_SLIDING:
			move(default_gravity / 15, delta)
			direction = Direction.LEFT if get_wall_normal().x < 0 else Direction.RIGHT
		
		State.WALL_JUMP:
			if state_machine.state_time < 0.1:
				stand(0.0 if is_first_tick else default_gravity, delta)
				direction = Direction.LEFT if get_wall_normal().x < 0 else Direction.RIGHT
			else:
				move(default_gravity, delta)
		
		State.GROUND_ATTACK:
			stand(default_gravity, delta)
		
		State.JUMP_ATTACK:
			move(default_gravity, delta)
			
		State.HURT, State.DYING:
			stand(default_gravity, delta)
		
		State.SLIDING_END:
			stand(default_gravity, delta)
		
		State.SLIDING_START, State.SLIDING_LOOP:
			slide(delta)
	
	is_first_tick = false
	

func move(gravity: float, delta: float) -> void:
	var movement := Input.get_axis("move_left", "move_right")
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	if movement * velocity.x < 0:
		velocity.x = 0
	velocity.x = move_toward(velocity.x, movement * RUN_SPEED, acceleration * delta)
	velocity.y += gravity * delta
	
	if not is_zero_approx(movement):
		direction = Direction.LEFT if movement < 0 else Direction.RIGHT
	
	move_and_slide()


func stand(gravity: float, delta: float) -> void:
	var acceleration := FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.y += gravity * delta
	
	move_and_slide()


func stop(gravity: float, delta: float) -> void:
	velocity.x = 0
	velocity.y = 0
	
	move_and_slide()


func slide(delta: float) -> void:
	velocity.x = graphics.scale.x * SLIDING_SPEED
	velocity.y += default_gravity * delta
	
	move_and_slide()


func die() -> void:
	game_over_screen.show_game_over()


func register_interactable(v: Interactable) -> void:
	if state_machine.current_state == State.DYING:
		return
	if v in interacting_with:
		return
	interacting_with.append(v)


func unregister_interactable(v: Interactable) -> void:
	interacting_with.erase(v)


func can_wall_slide() -> bool:
	return is_on_wall() and hand_checker.is_colliding() and foot_checker.is_colliding()


func should_slide() -> bool:
	return false	
	#if slide_request_timer.is_stopped():
		#return false
	#if stats.energy < SLIDING_ENERGY:
		#return false
	#return not foot_checker.is_colliding()



func get_next_state(state: State) -> int:
	if stats.health == 0:
		return StateMachine.KEEP_CURRENT if state == State.DYING else State.DYING
	
	if pending_damage:
		return State.HURT
	
	var can_jump := is_on_floor() or coyote_timer.time_left > 0
	var should_jump := can_jump and jump_request_timer.time_left > 0
	if should_jump:
		return State.JUMP
		
	
	if state in GROUND_STATES and not is_on_floor():
		return State.FALL
	
	var movement := Input.get_axis("move_left", "move_right")
	var is_still := is_zero_approx(movement) and is_zero_approx(velocity.x)
	
	match state:
		State.IDLE:
			if Input.is_action_just_pressed("attack"):
				return State.GROUND_ATTACK
			if should_slide():
				return State.SLIDING_START
			if not is_still:
				return State.RUNNING
		
		State.RUNNING:
			if Input.is_action_just_pressed("attack"):
				return State.GROUND_ATTACK
			if should_slide():
				return State.SLIDING_START
			if is_still:
				return State.IDLE
		
		State.JUMP:
			if state_machine.state_time > TIME_BETWEEN_JUMP_AND_SECOND_JUMP:
				can_second_jump = true
			if can_second_jump and jump_request_timer.time_left > 0:
				return State.SECOND_JUMP
			if velocity.y >= 0:
				return State.FALL
			if Input.is_action_just_pressed("attack"):
				return State.JUMP_ATTACK
		
		State.SECOND_JUMP:
			can_second_jump = false
			if velocity.y >= 0:
				return State.FALL
			if Input.is_action_just_pressed("attack"):
				return State.JUMP_ATTACK
				
		State.FALL:
			if is_on_floor():
				var height := global_position.y - fall_from_y
				return State.LANDING if height >= LANDING_HEIGHT else State.RUNNING
			if can_wall_slide():
				return State.WALL_SLIDING
			if jump_request_timer.time_left > 0 and slide_jump_coyote_timer.time_left > 0 and wall_slide_min_timer.time_left == 0:
				return State.WALL_JUMP
			if can_second_jump and jump_request_timer.time_left > 0:
				return State.SECOND_JUMP
			if Input.is_action_just_pressed("attack"):
				return State.JUMP_ATTACK
		
		State.LANDING:
			if not animation_player.is_playing():
				return State.IDLE
		
		State.WALL_SLIDING:
			if jump_request_timer.time_left > 0 and wall_slide_min_timer.time_left == 0:
				return State.WALL_JUMP
			if is_on_floor():
				return State.IDLE
			if not is_on_wall():
				return State.FALL
		
		State.WALL_JUMP:
			if state_machine.state_time > TIME_BETWEEN_JUMP_AND_SECOND_JUMP:
				can_second_jump = true
			if can_second_jump and jump_request_timer.time_left > 0:
				return State.SECOND_JUMP
			if can_wall_slide() and not is_first_tick:
				return State.WALL_SLIDING
			if velocity.y >= 0:
				return State.FALL
		
		State.GROUND_ATTACK:
			if not animation_player.is_playing():
				return State.IDLE
		
		State.JUMP_ATTACK:
			if not animation_player.is_playing():
				return State.FALL
		#
		#State.ATTACK_3:
			#if not animation_player.is_playing():
				#return State.IDLE
		
		State.HURT:
			if not animation_player.is_playing():
				return State.IDLE
		
		State.SLIDING_START:
			if not animation_player.is_playing():
				return State.SLIDING_LOOP
		
		State.SLIDING_END:
			if not animation_player.is_playing():
				return State.IDLE
		
		State.SLIDING_LOOP:
			if state_machine.state_time > SLIDING_DURATION or is_on_wall():
				return State.SLIDING_END
	
	return StateMachine.KEEP_CURRENT


func transition_state(from: State, to: State) -> void:
	#print("[%s] %s => %s" % [
		#Engine.get_physics_frames(),
		#State.keys()[from] if from != -1 else "<START>",
		#State.keys()[to],
	#])
	
	if from not in GROUND_STATES and to in GROUND_STATES:
		coyote_timer.stop()
	
	match to:
		State.IDLE:
			animation_player.play("idle")
		
		State.RUNNING:
			animation_player.play("running")
		
		State.JUMP:
			animation_player.play("jump")
			velocity.y = JUMP_VELOCITY
			coyote_timer.stop()
			jump_request_timer.stop()
			SoundManager.play_sfx("Jump")
		
		State.SECOND_JUMP:
			animation_player.play("jump")
			velocity.y = JUMP_VELOCITY
			jump_request_timer.stop()
			SoundManager.play_sfx("Jump")
		
		State.FALL:
			animation_player.play("fall")
			if from in GROUND_STATES:
				coyote_timer.start()
			if from == State.WALL_SLIDING:
				slide_jump_coyote_timer.start()
			fall_from_y = global_position.y
		
		State.LANDING:
			animation_player.play("landing")
		
		State.WALL_SLIDING:
			velocity.y = 0
			animation_player.play("wall_sliding")
			if from != State.WALL_SLIDING:
				wall_slide_min_timer.start()
		
		State.WALL_JUMP:
			animation_player.play("jump")
			velocity = WALL_JUMP_VELOCITY
			velocity.x *= get_wall_normal().x
			jump_request_timer.stop()
		
		State.GROUND_ATTACK:
			animation_player.play("attack_1")
			#is_combo_requested = false
			SoundManager.play_sfx("Attack")
			
		State.JUMP_ATTACK:
			animation_player.play("attack_1")
			SoundManager.play_sfx("Attack")
		
		#State.JUMP_ATTACK:
			#animation_player.play("JUMP_ATTACK")
			#is_combo_requested = false
		#
		#State.ATTACK_3:
			#animation_player.play("attack_3")
			#is_combo_requested = false
		
		State.HURT:
			animation_player.play("hurt")
			
			stats.health -= pending_damage.amount
			
			var dir := pending_damage.source.global_position.direction_to(global_position)
			velocity = dir * KNOCKBACK_AMOUNT
			
			pending_damage = null
			invincible_timer.start()
		
		State.DYING:
			animation_player.play("die")
			invincible_timer.stop()
			interacting_with.clear()
		
		State.SLIDING_START:
			animation_player.play("sliding_start")
			slide_request_timer.stop()
			stats.energy -= SLIDING_ENERGY
		
		State.SLIDING_LOOP:
			animation_player.play("sliding_loop")
		
		State.SLIDING_END:
			animation_player.play("sliding_end")
	
	is_first_tick = true


func _on_hurtbox_hurt(hitbox: Hitbox) -> void:
	if invincible_timer.time_left > 0:
		return
	
	pending_damage = Damage.new()
	pending_damage.amount = 1
	pending_damage.source = hitbox.owner
