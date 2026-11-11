(** Deterministic gameplay model shared by native tests and js_of_ocaml. *)
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
type collider = Wall | Paddle of int | Brick of int

let width = 1000.
let height = 640.
let margin = 24.
let paddle_y = 586.
let radius = 8.
let fixed_dt = 1. /. 120.
let level_count = 5
let level_names = [|"Prise d'elan"; "Decalage"; "Onde"; "Bastion"; "Derniere orbite"|]
let no_input = { axis = 0.; pointer = None }
let base_speed = function Calm -> 350. | Normal -> 430. | Expert -> 510.
let max_speed = function Calm -> 600. | Normal -> 760. | Expert -> 900.
let paddle_width difficulty mode = match mode with Split -> 200. | Solid ->
  match difficulty with Calm -> 176. | Normal -> 144. | Expert -> 118.
let phase_name = function Menu -> "menu" | Ready -> "ready" | Playing -> "playing"
  | Paused -> "paused" | Level_cleared -> "level_clear" | Won -> "won" | Lost -> "lost"
let difficulty_name = function Calm -> "calm" | Normal -> "normal" | Expert -> "expert"
let mode_name = function Solid -> "solid" | Split -> "split"

let make_level level =
  let rows = if level = 0 then 4 else if level = 1 then 5 else 6 in
  List.init (rows * 10) (fun id ->
    let row = id / 10 and col = id mod 10 in
    let hp = if level < 2 then 1 else if level = 2 then (if row = 0 then 2 else 1)
      else if level = 3 then (if col = 0 || col = 9 || row = 0 then 2 else 1)
      else 1 + (row + col) mod 3 in
    { id; box = { left = 62. +. float col *. 88.; top = 92. +. float row *. 34.; width = 78.; height = 24. };
      hp; max_hp = hp; color = (row + level) mod 5 })
  |> List.filter (fun b -> let row = b.id / 10 and col = b.id mod 10 in
       match level with 1 -> (row + col) mod 7 <> 0
       | 2 -> not ((row = 2 || row = 3) && (col = 4 || col = 5))
       | 3 -> not (row mod 2 = 1 && (col = 3 || col = 6))
       | _ -> true)

let dock x difficulty mode =
  { pos = v (x +. paddle_width difficulty mode /. 2.) (paddle_y -. radius -. 5.); velocity = v 0. 0. }

let create difficulty mode =
  let paddle_x = (width -. paddle_width difficulty mode) /. 2. in
  { phase = Menu; difficulty; mode; level = 0; lives = 3; score = 0; combo = 0;
    best_combo = 0; broken = 0; paddle_x; ball = dock paddle_x difficulty mode;
    bricks = make_level 0; elapsed = 0.; accumulator = 0.; tick = 0; last_event = "" }

let launch s =
  let speed = base_speed s.difficulty +. float s.level *. 22. in
  { s with phase = Playing; ball = { s.ball with velocity = scale speed (unit (v 0.32 (-1.))) }; last_event = "launch" }

let command s = function
  | "start" | "restart" -> { (create s.difficulty s.mode) with phase = Ready; last_event = "start" }
  | "launch" when s.phase = Ready -> launch s
  | "pause" when s.phase = Playing -> { s with phase = Paused; accumulator = 0.; last_event = "pause" }
  | "resume" when s.phase = Paused -> { s with phase = Playing; accumulator = 0.; last_event = "resume" }
  | "toggle_pause" -> (match s.phase with
      | Playing -> { s with phase = Paused; accumulator = 0.; last_event = "pause" }
      | Paused -> { s with phase = Playing; accumulator = 0.; last_event = "resume" }
      | _ -> s)
  | "next" when s.phase = Level_cleared ->
      let level = s.level + 1 in
      { s with phase = Ready; level; bricks = make_level level; combo = 0; accumulator = 0.;
        ball = dock s.paddle_x s.difficulty s.mode; last_event = "next" }
  | "menu" -> { s with phase = Menu; accumulator = 0.; last_event = "menu" }
  | _ -> s

let paddles s =
  let box left width = { left; top = paddle_y; width; height = 14. } in
  match s.mode with
  | Solid -> [Paddle 0, box s.paddle_x (paddle_width s.difficulty s.mode)]
  | Split -> [Paddle (-1), box s.paddle_x 40.; Paddle 0, box (s.paddle_x +. 70.) 60.;
              Paddle 1, box (s.paddle_x +. 160.) 40.]

let colliders s =
  [Wall, {left = -1000.; top = -1000.; width = 1024.; height = 3000.};
   Wall, {left = 976.; top = -1000.; width = 1000.; height = 3000.};
   Wall, {left = -1000.; top = -1000.; width = 3000.; height = 1024.}]
  @ paddles s
  @ List.filter_map (fun b -> if b.hp > 0 then Some (Brick b.id, b.box) else None) s.bricks

let bounce_on_paddle s part pos velocity =
  let speed = max (base_speed s.difficulty) (norm velocity) in
  let offset = clamp (-1.) 1. ((pos.x -. (s.paddle_x +. paddle_width s.difficulty s.mode /. 2.))
                              /. (paddle_width s.difficulty s.mode /. 2.)) in
  let direction = match s.mode, part with
    | Split, -1 -> v (-0.6) (-0.8)
    | Split, 1 -> v 0.6 (-0.8)
    | Split, _ -> unit (v (offset *. 0.7) (-1.))
    | Solid, _ -> let angle = offset *. 1.05 in v (sin angle) (-. cos angle) in
  scale (min speed (max_speed s.difficulty)) direction

let damage s ids =
  let ids = List.sort_uniq Int.compare ids in
  let destroyed = ref 0 in
  let bricks = List.map (fun b -> if b.hp > 0 && List.mem b.id ids then
      let hp = b.hp - 1 in
      if hp = 0 then incr destroyed;
      { b with hp } else b) s.bricks in
  let combo = s.combo + !destroyed in
  let points = List.length ids * 25 + !destroyed * (75 + 10 * min combo 10) in
  { s with bricks; combo; best_combo = max s.best_combo combo; score = s.score + points;
           broken = s.broken + !destroyed; last_event = if !destroyed > 0 then "brick" else "armor" }

let keep_vertical_motion velocity normals =
  (* A rounded corner can reflect a vertical ray into a perfectly horizontal
     one. Keep arcade trajectories playable instead of orbiting between walls. *)
  let speed = norm velocity in
  let minimum = speed *. 0.16 in
  if speed <= epsilon || abs_float velocity.y >= minimum then velocity
  else
    let y = (if velocity.y > 0. then minimum else -.minimum) in
    let x = sqrt (max 0. (speed *. speed -. y *. y)) in
    let x = if velocity.x < 0. then -.x else x in
    let first = v x y and second = v x (-.y) in
    let outgoing candidate = List.for_all (fun normal -> dot candidate normal >= -.epsilon) normals in
    if outgoing first then first else if outgoing second then second else velocity

let rec integrate_ball s remaining iterations =
  if remaining <= epsilon || iterations = 0 then s
  else
    let hits = List.filter_map (fun (kind, box) ->
      match sweep_circle_rect s.ball.pos s.ball.velocity radius box remaining with
      | None -> None | Some hit -> Some (kind, hit)) (colliders s) in
    match List.sort (fun (_, a) (_, b) -> Float.compare a.time b.time) hits with
    | [] -> { s with ball = { s.ball with pos = add s.ball.pos (scale remaining s.ball.velocity) } }
    | (_, earliest) :: _ ->
      let contacts = List.filter (fun (_, hit) -> abs_float (hit.time -. earliest.time) < 1e-7) hits in
      let pos = add s.ball.pos (scale earliest.time s.ball.velocity) in
      let ids = List.filter_map (function Brick id, _ -> Some id | _ -> None) contacts in
      let updated = if ids = [] then s else damage s ids in
      let normals = List.map (fun (_, hit) -> hit.normal) contacts in
      let top_paddle = List.find_opt (function
        | Paddle _, hit -> hit.normal.y < -0.5 && s.ball.velocity.y > 0.
        | _ -> false) contacts in
      let paddle_hit = Option.is_some top_paddle in
      let incoming = match top_paddle with
        | Some (Paddle part, _) -> bounce_on_paddle s part pos s.ball.velocity
        | _ -> s.ball.velocity in
      let velocity = reflect_many incoming normals in
      let displacement = List.fold_left (fun shift (_, hit) ->
        add shift (scale (hit.penetration +. 0.001) hit.normal)) (v 0. 0.) contacts in
      let pos = add pos displacement in
      let speed = min (max_speed s.difficulty) (norm velocity *. (if ids = [] then 1. else 1.012)) in
      let velocity = keep_vertical_motion (scale speed (unit velocity)) normals in
      let updated = { updated with ball = { pos; velocity };
        combo = if paddle_hit then 0 else updated.combo;
        last_event = if paddle_hit then "paddle" else if ids = [] then "wall" else updated.last_event } in
      integrate_ball updated (max 0. (remaining -. earliest.time -. 1e-7)) (iterations - 1)

let move_paddle s input =
  let pw = paddle_width s.difficulty s.mode in
  let step = 740. *. fixed_dt in
  let x = match input.pointer with
    | Some target when Float.is_finite target ->
        s.paddle_x +. clamp (-.step) step (target -. pw /. 2. -. s.paddle_x)
    | _ -> let axis = if Float.is_finite input.axis then input.axis else 0. in
        s.paddle_x +. clamp (-1.) 1. axis *. step in
  let paddle_x = clamp margin (width -. margin -. pw) x in
  { s with paddle_x }

let fixed_step s input =
  let s = move_paddle s input in
  if s.phase = Ready then { s with ball = dock s.paddle_x s.difficulty s.mode; tick = s.tick + 1 }
  else if s.phase <> Playing then s
  else
    let s = integrate_ball { s with tick = s.tick + 1; elapsed = s.elapsed +. fixed_dt } fixed_dt 8 in
    if List.for_all (fun b -> b.hp = 0) s.bricks then
      { s with phase = (if s.level = level_count - 1 then Won else Level_cleared);
        accumulator = 0.; score = s.score + 500; last_event = "clear" }
    else if s.ball.pos.y -. radius > height then
      let lives = s.lives - 1 in
      { s with lives; phase = (if lives <= 0 then Lost else Ready); combo = 0;
        ball = dock s.paddle_x s.difficulty s.mode; accumulator = 0.; last_event = "life" }
    else s

let advance s dt input =
  if (s.phase <> Playing && s.phase <> Ready) || not (Float.is_finite dt) || dt <= 0. then s
  else
    let accumulator = s.accumulator +. min 0.25 dt in
    let rec loop state accumulator count =
      if accumulator +. 1e-10 < fixed_dt || count = 30 ||
         (state.phase <> Playing && state.phase <> Ready) then
        { state with accumulator = if state.phase = Playing || state.phase = Ready then max 0. accumulator else 0. }
      else
        let next = fixed_step state input in
        (* Stop on life/level transitions, so a ready ball never consumes the rest of a long frame. *)
        if next.phase <> state.phase then { next with accumulator = 0. }
        else loop next (accumulator -. fixed_dt) (count + 1)
    in loop { s with last_event = "" } accumulator 0

let snapshot s =
  let brick_json b = Printf.sprintf "{\"id\":%d,\"x\":%.2f,\"y\":%.2f,\"w\":%.2f,\"h\":%.2f,\"hp\":%d,\"maxHp\":%d,\"color\":%d}"
      b.id b.box.left b.box.top b.box.width b.box.height b.hp b.max_hp b.color in
  Printf.sprintf "{\"engine\":\"ocaml\",\"version\":\"1.0.0\",\"phase\":\"%s\",\"difficulty\":\"%s\",\"mode\":\"%s\",\"level\":%d,\"levelCount\":%d,\"lives\":%d,\"score\":%d,\"combo\":%d,\"bestCombo\":%d,\"broken\":%d,\"paddleX\":%.4f,\"paddleWidth\":%.2f,\"paddleY\":%.2f,\"ball\":{\"x\":%.5f,\"y\":%.5f,\"vx\":%.5f,\"vy\":%.5f,\"radius\":%.1f},\"elapsed\":%.5f,\"tick\":%d,\"event\":\"%s\",\"bricks\":[%s]}"
    (phase_name s.phase) (difficulty_name s.difficulty) (mode_name s.mode) (s.level + 1) level_count s.lives s.score s.combo s.best_combo s.broken
    s.paddle_x (paddle_width s.difficulty s.mode) paddle_y s.ball.pos.x s.ball.pos.y s.ball.velocity.x s.ball.velocity.y radius s.elapsed s.tick s.last_event
    (String.concat "," (List.map brick_json s.bricks))
