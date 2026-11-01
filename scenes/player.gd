extends CharacterBody2D
class_name Player

# Emit when requesting anim layer to play
signal play_anim(anim: StringName)

# The various player poses TODO: add missing states for walk/jump
enum State { STANDING, CROUCHED, PRONE, AIRBORNE, HANGING, CLIMBING }

# Vars for normal movement
@export_group("Movement")
@export var walk_speed      := 70.0
@export var run_speed       := 150.0
@export var crawl_speed     := 35.0
@export var acceleration    := 500.0
@export var gravity         := 900.0
@export var jump_speed      := 300.0
@export var leap_speed_x    := 220.0
@export var leap_speed_y    := 260.0
@export var run_hold_time   := 0.18

# Vars for hanging/climbing on legdes
@export_group("Ledge")
@export var hang_offset     := Vector2(8.0, 24.0)
@export var climb_anim      := "climb"

# Collision shapes for various poses
@onready var standing_shape: CollisionShape2D   = $StandingShape
@onready var crouched_shape: CollisionShape2D   = $CrouchedShape
@onready var prone_shape: CollisionShape2D      = $ProneShape

# Raycasts for various poses, e.g. hanging on ledge
@onready var wall_left: RayCast2D       = $LedgeWallLeft
@onready var wall_right: RayCast2D      = $LedgeWallRight
@onready var top_left: RayCast2D        = $LedgeTopLeft
@onready var top_right: RayCast2D       = $LedgeTopRight

# Shapecast to determine whether room to stand (from crouch)
@onready var standing_clearance: ShapeCast2D = $StandingClearance

# Current player pose state
var state: State = State.STANDING
# Direction player is facing
var facing := 1
# How long a direction was held
var dir_held_for := 0.0
var was_dir_pressed := false
var climb_top := Vector2.ZERO

# TODO: handle walk & jump states
func _physics_process(delta: float) -> void:
    # Get facing direction
    var axis := Input.get_axis("move_left", "move_right")
    if axis != 0.0: facing = int(sign(axis))
    
    var dir_pressed := not is_zero_approx(axis)
    if dir_pressed:
        dir_held_for = dir_held_for + delta if was_dir_pressed else 0.0
    
    # Handle states
    match state:
        State.HANGING:
            velocity = Vector2.ZERO
            if Input.is_action_just_pressed("jump"):
                set_state(State.CLIMBING)
                play_anim.emit(climb_anim)
            elif Input.is_action_just_pressed("crouch"):
                set_state(State.AIRBORNE)
            move_and_slide()
            return
            
        State.CLIMBING:
            # TODO: wait for climbing anim finished signal
            velocity = Vector2.ZERO
            return
            
        State.PRONE:
            velocity.x = move_toward(velocity.x, axis * crawl_speed, acceleration * delta)
            if Input.is_action_just_pressed("crouch"):
                set_state(State.CROUCHED)
            apply_gravity(delta)
            move_and_slide()
            set_landing_state()
            return
            
        State.CROUCHED:
            velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
            if Input.is_action_just_pressed("crouch"):
                set_state(State.PRONE)
            elif not Input.is_action_pressed("crouch") and can_stand():
                set_state(State.STANDING)
            apply_gravity(delta)
            move_and_slide()
            set_landing_state()
            return
            
        State.AIRBORNE:
            velocity.x = move_toward(velocity.x, axis * run_speed, acceleration * delta)
            apply_gravity(delta)
            move_and_slide()
            if is_on_floor():
                set_state(State.STANDING)
            elif try_grab_ledge():
                return
            return
    
    if not is_on_floor():
        set_state(State.AIRBORNE)
        apply_gravity(delta)
        move_and_slide()
        return
        
    if Input.is_action_just_pressed("crouch"):
        set_state(State.CROUCHED)
    elif Input.is_action_just_pressed("jump"):
        jump(axis)
    else:
        var speed := run_speed if dir_held_for >= run_hold_time else walk_speed
        velocity.x = move_toward(velocity.x, axis * speed, acceleration * delta)
        move_and_slide()
    
func jump(axis: float) -> void:
    var is_running := dir_held_for >= run_hold_time and not is_zero_approx(axis)
    if is_running:
        velocity.x = facing * leap_speed_x
        velocity.y = -leap_speed_y
    else:
        velocity.x = 0.0
        velocity.y = -jump_speed
    set_state(State.AIRBORNE)
    
func apply_gravity(delta: float) -> void:
    if not is_on_floor(): velocity.y += gravity * delta
    
func try_grab_ledge() -> bool:
    if velocity.y < 0.0:
        return false
    var wall_ray := wall_right if facing > 0 else wall_left
    var top_ray  := top_right if facing > 0 else top_left
    if not wall_ray.is_colliding() or not top_ray.is_colliding():
        return false
    climb_top = top_ray.get_collision_point()
    global_position = climb_top + Vector2(facing * hang_offset.x, hang_offset.y)
    set_state(State.HANGING)
    return true
    
func can_stand() -> bool:
    standing_clearance.force_shapecast_update()
    return not standing_clearance.is_colliding()
    
func set_landing_state() -> void:
    if is_on_floor() and state == State.AIRBORNE:
        set_state(State.STANDING)

# TODO: handle walk and jump states
# Set state and emit anim events
func set_state(next: State) -> void:
    if state == next:
        return
    state = next
    standing_shape.disabled = state != State.STANDING and state != State.AIRBORNE
    crouched_shape.disabled = state != State.CROUCHED
    prone_shape.disabled    = state != State.PRONE
    # TODO: need to handle the actual "jump" animation (we don't want full jump anim on just any falling situation)
    match state:
        State.STANDING:
            play_anim.emit("idle")
        State.CROUCHED:
            play_anim.emit("crouch")
        State.PRONE:
            play_anim.emit("prone")
        State.AIRBORNE:
            play_anim.emit("airborne")
        State.HANGING:
            play_anim.emit("hang")

# TODO: wire to anim finished signal
func finish_climb() -> void:
    global_position = climb_top + Vector2(facing * hang_offset.x, 0.0)
    velocity = Vector2.ZERO
    set_state(State.STANDING)
