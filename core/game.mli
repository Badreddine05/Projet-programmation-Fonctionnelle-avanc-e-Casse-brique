(** Immutable game state shared by native verification and the browser bridge.
    Records are visible for deterministic test fixtures; runtime clients should
    construct states with [create], [command] and [advance]. *)
open Physics
type difficulty = Calm | Normal | Expert
type paddle_mode = Solid | Split
type phase = Menu | Ready | Playing | Paused | Level_cleared | Won | Lost
type brick = { id : int; box : rect; hp : int; max_hp : int; color : int }
type ball = { pos : vec; velocity : vec }
type input = { axis : float; pointer : float option }
type t = {
  phase : phase; difficulty : difficulty; mode : paddle_mode; level : int;
  lives : int; score : int; combo : int; best_combo : int; broken : int;
  paddle_x : float; ball : ball; bricks : brick list;
  elapsed : float; accumulator : float; tick : int; last_event : string;
}
val width : float
val height : float
val margin : float
val paddle_y : float
val radius : float
val fixed_dt : float
val level_count : int
val level_names : string array
val no_input : input

(** Create a campaign in the menu state. *)
val create : difficulty -> paddle_mode -> t

(** Invalid commands/transitions are no-ops. See FRONTEND_HANDOFF.md for the
    command/state table. Restart preserves difficulty and paddle mode. *)
val command : t -> string -> t

(** Consume positive, finite seconds in fixed 120 Hz steps. At most 0.25 seconds
    is accepted per call. Simulation is frozen outside Ready/Playing. A finite
    pointer has priority over the axis; nonfinite controls are ignored. *)
val advance : t -> float -> input -> t

(** JSON transport with one-based level, logical positions and HUD values. *)
val snapshot : t -> string
