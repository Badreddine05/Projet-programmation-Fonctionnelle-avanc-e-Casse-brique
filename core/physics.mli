(** Continuous collision primitives, independent of the renderer and game state.
    Positions/radii use pixels; velocities use pixels/second; times use seconds. *)
type vec = { x : float; y : float }
type rect = { left : float; top : float; width : float; height : float }
type hit = { time : float; normal : vec; penetration : float }

val epsilon : float
val v : float -> float -> vec
val add : vec -> vec -> vec
val sub : vec -> vec -> vec
val scale : float -> vec -> vec
val dot : vec -> vec -> float
val norm : vec -> float
val clamp : float -> float -> float -> float
val finite : vec -> bool

(** Zero vectors normalize to zero, never NaN. *)
val unit : vec -> vec

(** Reflect only when the velocity approaches the supplied unit normal. *)
val reflect : vec -> vec -> vec

(** Minimum-impulse simultaneous restitution, independent of normal order.
    Feasible output satisfies [dot output n >= max 0 (-dot input n)].
    Contradictory overlap constraints fall back to the most approaching normal. *)
val reflect_many : vec -> vec list -> vec

(** [sweep_circle_rect p velocity radius rect duration] gives the earliest
    approaching contact in the interval, or an immediate overlap to separate.
    [rect] must have finite coordinates and positive dimensions. Nonfinite
    position, velocity, radius or duration is rejected. Corner normals describe
    the rounded Minkowski boundary, not a square expanded rectangle. *)
val sweep_circle_rect : vec -> vec -> float -> rect -> float -> hit option
