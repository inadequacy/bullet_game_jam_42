class_name View
extends RefCounted

## The visible world, for everything that has to ask "where does the screen end".
##
##     if not View.holds(self, global_position, despawn_margin):
##         queue_free()
##
## Read off the camera rather than assuming 1152x648, so a viewport or camera
## zoom change still gets the right answer. Five files worked this out for
## themselves before it lived here: both projectiles culling themselves, the
## spawner picking an off-screen edge, the fire ultimate sizing its wash, and
## Enemy.is_on_screen.


## The arena in world space. `margin` widens it on every side - pass the slack a
## caller wants before it calls something gone.
static func world_rect(of: CanvasItem, margin: float = 0.0) -> Rect2:
	var to_world := of.get_canvas_transform().affine_inverse()
	var screen := of.get_viewport_rect()
	var world := Rect2(to_world * screen.position, to_world.basis_xform(screen.size))
	return world.grow(margin) if margin != 0.0 else world


## True while `point` is inside the visible world, `margin` of slack included.
static func holds(of: CanvasItem, point: Vector2, margin: float = 0.0) -> bool:
	return world_rect(of, margin).has_point(point)
