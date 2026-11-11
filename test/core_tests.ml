open Breakout_core
open Physics
open Game

let count = ref 0
let check message condition = if not condition then failwith message
let near a b = abs_float (a -. b) < 1e-5
let test name body = body (); incr count; Printf.printf "PASS %s\n%!" name
let hit = function Some hit -> hit | None -> failwith "Expected a collision"
let ready () = command (create Normal Solid) "start"
let running () = command (ready ()) "launch"
let box = { left = 100.; top = 100.; width = 80.; height = 24. }

let () =
  test "high speed crosses a brick without tunnelling" (fun () ->
    let h = hit (sweep_circle_rect (v 130. 30.) (v 0. 10000.) 8. box 0.02) in
    check "time of impact" (near h.time 0.0062);
    check "top normal" (h.normal = v 0. (-1.)));
  test "exact edge and zero distance stay finite" (fun () ->
    let h = hit (sweep_circle_rect (v 100. 110.) (v 200. 0.) 8. box 0.02) in
    check "finite normal" (finite h.normal && near (norm h.normal) 1.);
    check "separation" (h.penetration > 0.);
    check "finite reflection" (finite (reflect (v 200. 0.) h.normal)));
  test "rounded corner collision uses a diagonal normal" (fun () ->
    let h = hit (sweep_circle_rect (v 80. 80.) (v 100. 100.) 8. box 0.25) in
    check "diagonal" (near h.normal.x h.normal.y && h.normal.x < 0.);
    check "reflected outward" ((reflect (v 100. 100.) h.normal).x < 0.));
  test "expanded AABB false corner contact is rejected" (fun () ->
    (* The segment enters the square-expanded box at x=92,y=93, while its
       distance from the real corner remains greater than the radius. *)
    check "no false square corner" (sweep_circle_rect (v 91. 93.) (v 2. 0.) 8. box 1. = None));
  test "separating contact does not bounce again" (fun () ->
    check "leaving top" (sweep_circle_rect (v 130. 92.) (v 0. (-100.)) 8. box 0.1 = None);
    check "reflection direction" (reflect (v 0. (-100.)) (v 0. (-1.)) = v 0. (-100.)));
  test "simultaneous wall corner resolves both axes" (fun () ->
    let s = { (running ()) with ball = {pos = v 32.4 32.8; velocity = v (-200.) (-400.)} } in
    let s = advance s fixed_dt no_input in
    check "both components reflected without swapping" (near s.ball.velocity.x 200. && near s.ball.velocity.y 400.);
    check "inside board" (s.ball.pos.x >= 32. && s.ball.pos.y >= 32.));
  test "same elapsed time is independent of 30/60/144 Hz" (fun () ->
    let simulate rate = let s = ref (running ()) in
      for _ = 1 to rate do s := advance !s (1. /. float rate) no_input done; !s in
    let a = simulate 30 and b = simulate 60 and c = simulate 144 in
    check "same ticks" (a.tick = 120 && a.tick = b.tick && b.tick = c.tick);
    check "same position" (near a.ball.pos.x c.ball.pos.x && near a.ball.pos.y c.ball.pos.y);
    check "same score" (a.score = b.score && b.score = c.score));
  test "pause freezes position and simulation clock" (fun () ->
    let s = command (running ()) "pause" in
    check "paused" (s.phase = Paused);
    check "frozen" (advance s 10. {axis=1.; pointer=None} = s);
    check "resume" ((command s "resume").phase = Playing));
  test "life loss docks once and preserves score" (fun () ->
    let s = { (running ()) with score=420; ball={pos=v 500. 650.;velocity=v 0. 300.} } in
    let s = advance s 0.2 no_input in
    check "one life" (s.lives=2 && s.phase=Ready);
    check "score" (s.score=420);
    check "docked" (s.ball.velocity=v 0. 0.);
    let s = {s with phase=Playing;lives=1;ball={pos=v 500. 650.;velocity=v 0. 300.}} in
    check "game over" ((advance s fixed_dt no_input).phase=Lost));
  test "armour takes one hit and score is deterministic" (fun () ->
    let brick = {id=0;box;hp=2;max_hp=2;color=0} in
    let s = { (running ()) with bricks=[brick];ball={pos=v 130. 88.;velocity=v 0. 500.} } in
    let s = advance s fixed_dt no_input in
    check "one armour hit" ((List.hd s.bricks).hp=1 && s.score=25 && s.broken=0));
  test "last brick opens progression and next keeps lives" (fun () ->
    let brick = {id=0;box;hp=1;max_hp=1;color=0} in
    let s = { (running ()) with lives=2;bricks=[brick];ball={pos=v 130. 88.;velocity=v 0. 500.} } in
    let s = advance s fixed_dt no_input in
    check "cleared" (s.phase=Level_cleared && s.score=610);
    let next = command s "next" in
    check "progression" (next.level=1 && next.lives=2 && next.score=610 && next.phase=Ready);
    let final = advance {s with phase=Playing;level=4} fixed_dt no_input in
    check "campaign won" (final.phase=Won));
  test "paddle reflection angle follows impact location" (fun () ->
    let s=running () in
    let bounce offset = (advance {s with ball={pos=v (s.paddle_x+.offset) 570.;velocity=v 0. 430.}}
      0.05 no_input).ball.velocity in
    let left=bounce 10. and right=bounce 134. in
    check "directions" (left.x<0. && right.x>0. && left.y<0. && right.y<0.));
  test "heritage split paddle keeps its two genuine gaps" (fun () ->
    let s=command (create Normal Split) "start" |> fun s -> command s "launch" in
    let s={s with ball={pos=v (s.paddle_x+.55.) 570.;velocity=v 0. 430.}} in
    let s=advance s 0.1 no_input in
    check "gap passes through" (s.ball.pos.y>600. && s.ball.velocity.y>0.));
  test "paddle bounds, invalid dt and reset are safe" (fun () ->
    let s=ref (ready ()) in
    for _=1 to 100 do s:=advance !s 0.1 {axis=1.;pointer=None} done;
    check "right bound" (near (!s).paddle_x (976.-.144.));
    check "nan dt ignored" (advance !s nan no_input = !s);
    check "negative dt ignored" (advance !s (-1.) no_input = !s);
    let invalid=advance !s fixed_dt {axis=nan;pointer=Some nan} in
    check "invalid controls ignored" (near invalid.paddle_x (!s).paddle_x);
    let s=command { !s with score=300;lives=1;level=3} "restart" in
    check "fresh game" (s.score=0 && s.lives=3 && s.level=0 && s.phase=Ready));
  test "long frame is capped to thirty fixed steps" (fun () ->
    let s=advance (running ()) 100. no_input in
    check "cap" (s.tick=30 && near s.elapsed 0.25));
  test "horizontal corner trajectories cannot stall between walls" (fun () ->
    let s={ (running ()) with ball={pos=v 967. 400.;velocity=v 430. 0.} } in
    let s=advance s fixed_dt no_input in
    check "vertical progress after contact" (abs_float s.ball.velocity.y >= 430.*.0.16-.epsilon);
    check "speed conserved" (near (norm s.ball.velocity) 430.));
  test "anti-stall remains outgoing from an armoured rounded corner" (fun () ->
    let normal=v 0.1 (sqrt 0.99) in
    let outgoing=v (sqrt (430.*.430.-.36.)) (-6.) in
    let incoming=sub outgoing (scale (2.*.dot outgoing normal) normal) in
    let contact=add (v 180. 124.) (scale 8. normal) in
    let start=sub contact (scale 0.004 incoming) in
    let brick={id=0;box;hp=3;max_hp=3;color=0} in
    let s={ (running ()) with bricks=[brick];ball={pos=start;velocity=incoming}} in
    let s=advance s fixed_dt no_input in
    check "one hit only" ((List.hd s.bricks).hp=2 && s.score=25);
    check "outgoing correction" (dot s.ball.velocity normal>=0.));
  test "simultaneous neighbouring corners are invariant to brick order" (fun () ->
    let first={id=0;box;hp=3;max_hp=3;color=0} in
    let second={id=1;box={box with left=190.};hp=3;max_hp=3;color=1} in
    let simulate bricks = advance { (running ()) with bricks;
      ball={pos=v 185. 133.;velocity=v 0. (-430.)}} fixed_dt no_input in
    let a=simulate [first;second] and b=simulate [second;first] in
    check "same velocity" (near a.ball.velocity.x b.ball.velocity.x && near a.ball.velocity.y b.ball.velocity.y);
    check "symmetric vertical exit" (near a.ball.velocity.x 0. && a.ball.velocity.y>0.);
    check "same position" (near a.ball.pos.x b.ball.pos.x && near a.ball.pos.y b.ball.pos.y);
    check "one hit per brick" (a.score=50 && b.score=50 && List.for_all(fun brick->brick.hp=2) a.bricks));
  test "nonfinite collision arguments are rejected" (fun () ->
    check "nan radius" (sweep_circle_rect (v 0. 0.) (v 1. 1.) nan box 1. = None);
    check "nan duration" (sweep_circle_rect (v 0. 0.) (v 1. 1.) 8. box nan = None));
  test "seeded long simulation preserves state invariants" (fun () ->
    let rng=Random.State.make [|2024;120|] in
    let s=ref (running ()) in
    for _=1 to 30000 do
      if (!s).phase=Ready then s:=command !s "launch";
      if (!s).phase=Level_cleared then s:=command !s "next";
      if (!s).phase=Lost || (!s).phase=Won then s:=command !s "restart";
      s:=advance !s (Random.State.float rng 0.04) {axis=Random.State.float rng 2.-.1.;pointer=None};
      check "finite ball" (finite (!s).ball.pos && finite (!s).ball.velocity);
      check "lives range" ((!s).lives>=0 && (!s).lives<=3);
      check "nonnegative bricks" (List.for_all(fun b->b.hp>=0 && b.hp<=b.max_hp) (!s).bricks);
      check "paddle range" ((!s).paddle_x>=24. && (!s).paddle_x+.144.<=976.+.epsilon)
    done);
  Printf.printf "%d core tests passed\n" !count
