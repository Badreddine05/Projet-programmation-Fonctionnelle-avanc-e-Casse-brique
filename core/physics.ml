(** Pure continuous circle/rectangle collision detection. Coordinates are pixels;
    velocities are pixels/second and times are seconds. No rendering dependency. *)
type vec = { x : float; y : float }
type rect = { left : float; top : float; width : float; height : float }
type hit = { time : float; normal : vec; penetration : float }

let epsilon = 1e-8
let v x y = { x; y }
let add a b = v (a.x +. b.x) (a.y +. b.y)
let sub a b = v (a.x -. b.x) (a.y -. b.y)
let scale k a = v (k *. a.x) (k *. a.y)
let dot a b = a.x *. b.x +. a.y *. b.y
let norm a = sqrt (dot a a)
let clamp lo hi value = max lo (min hi value)
let finite a = Float.is_finite a.x && Float.is_finite a.y
let unit a = let n = norm a in if n <= epsilon then v 0. 0. else scale (1. /. n) a
let reflect velocity normal =
  let approach = dot velocity normal in
  if approach < -.epsilon then sub velocity (scale (2. *. approach) normal)
  else velocity

let reflect_many velocity normals =
  (* Project the incoming velocity onto the simultaneous restitution half-planes.
     In 2D, the closest feasible velocity lies on zero, one or two boundaries.
     Canonical ordering makes the result independent of collider storage order. *)
  let compare_vec a b = let order = Float.compare a.x b.x in
    if order = 0 then Float.compare a.y b.y else order in
  let normals = normals |> List.filter (fun n -> finite n && norm n > epsilon)
    |> List.map unit |> List.sort_uniq compare_vec in
  let constraints = List.map (fun n -> n, max 0. (-. dot velocity n)) normals in
  let tolerance = 1e-7 *. max 1. (norm velocity) in
  let feasible candidate = finite candidate &&
    List.for_all (fun (n, target) -> dot candidate n >= target -. tolerance) constraints in
  let candidates = ref [] in
  let consider candidate = if feasible candidate then candidates := candidate :: !candidates in
  consider velocity;
  List.iter (fun (n, target) ->
    consider (add velocity (scale ((target -. dot velocity n) /. dot n n) n))) constraints;
  List.iteri (fun i (a, target_a) -> List.iteri (fun j (b, target_b) ->
    if j > i then begin
      let determinant = a.x *. b.y -. a.y *. b.x in
      if abs_float determinant > epsilon then
        consider (v ((target_a *. b.y -. a.y *. target_b) /. determinant)
                    ((a.x *. target_b -. target_a *. b.x) /. determinant))
    end) constraints) constraints;
  match !candidates with
  | first :: rest -> List.fold_left (fun best candidate ->
      let d = sub candidate velocity and best_d = sub best velocity in
      if dot d d < dot best_d best_d then candidate else best) first rest
  | [] ->
      (* Incompatible overlaps have no feasible elastic solution. Use the most
         approaching normal deterministically; the caller bounds iterations. *)
      (match List.sort (fun a b -> Float.compare (dot velocity a) (dot velocity b)) normals with
       | n :: _ -> reflect velocity n | [] -> velocity)

let overlap p radius r =
  let right = r.left +. r.width and bottom = r.top +. r.height in
  let nearest = v (clamp r.left right p.x) (clamp r.top bottom p.y) in
  let delta = sub p nearest in
  let distance = norm delta in
  if distance >= radius -. epsilon then None
  else if distance > epsilon then
    Some { time = 0.; normal = scale (1. /. distance) delta; penetration = radius -. distance }
  else
    let choices = [p.x -. r.left, v (-1.) 0.; right -. p.x, v 1. 0.;
                   p.y -. r.top, v 0. (-1.); bottom -. p.y, v 0. 1.] in
    let depth, normal = List.fold_left (fun ((best, _) as acc) ((d, _) as candidate) ->
        if d < best then candidate else acc) (List.hd choices) (List.tl choices) in
    Some { time = 0.; normal; penetration = radius +. max 0. depth }

let sweep_circle_rect p velocity radius r duration =
  if not (Float.is_finite duration && Float.is_finite radius) ||
     duration < 0. || radius <= 0. || not (finite p && finite velocity) then None
  else match overlap p radius r with
  | Some hit -> Some hit
  | None ->
    let right = r.left +. r.width and bottom = r.top +. r.height in
    let candidates = ref [] in
    let accept time normal check =
      if time >= -.epsilon && time <= duration +. epsilon &&
         dot velocity normal < -.epsilon && check (add p (scale time velocity)) then
        candidates := { time = max 0. time; normal; penetration = 0. } :: !candidates in
    if velocity.x > epsilon then accept ((r.left -. radius -. p.x) /. velocity.x) (v (-1.) 0.)
        (fun q -> q.y >= r.top -. epsilon && q.y <= bottom +. epsilon);
    if velocity.x < -.epsilon then accept ((right +. radius -. p.x) /. velocity.x) (v 1. 0.)
        (fun q -> q.y >= r.top -. epsilon && q.y <= bottom +. epsilon);
    if velocity.y > epsilon then accept ((r.top -. radius -. p.y) /. velocity.y) (v 0. (-1.))
        (fun q -> q.x >= r.left -. epsilon && q.x <= right +. epsilon);
    if velocity.y < -.epsilon then accept ((bottom +. radius -. p.y) /. velocity.y) (v 0. 1.)
        (fun q -> q.x >= r.left -. epsilon && q.x <= right +. epsilon);
    let a = dot velocity velocity in
    if a > epsilon then List.iter (fun (corner, sx, sy) ->
      let delta = sub p corner in
      let b = 2. *. dot delta velocity in
      let c = dot delta delta -. radius *. radius in
      let discriminant = b *. b -. 4. *. a *. c in
      if discriminant >= 0. then begin
        let time = (-.b -. sqrt discriminant) /. (2. *. a) in
        let point = add p (scale time velocity) in
        let normal = unit (sub point corner) in
        accept time normal (fun q -> (q.x -. corner.x) *. sx >= -.epsilon &&
                                     (q.y -. corner.y) *. sy >= -.epsilon)
      end)
      [v r.left r.top, -1., -1.; v right r.top, 1., -1.;
       v r.left bottom, -1., 1.; v right bottom, 1., 1.];
    List.fold_left (fun best hit -> match best with
      | None -> Some hit
      | Some current -> if hit.time < current.time then Some hit else best) None !candidates
