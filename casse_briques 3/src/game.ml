open System_defs

(* On crée une fenêtre *)
let init () =
  let win = Gfx.create (Format.sprintf "game_canvas:%dx%d:" 1000 600) in
  Game_state.set_window win

let main_planche_width = 60
let petite_planche_width = 40
let gap_width = 30
let p_width = 2 * petite_planche_width + 2 * gap_width + main_planche_width

(* Le joueur se compose de trois parties *)

let p1, p2, p3 =
  Entity.Player.make 450.0 550.0 main_planche_width 10 (Texture.Color (Gfx.color 255 121 0 255)) gap_width petite_planche_width

let ball =
    let x = 476. in
    let y = 500. in
    let mass = 20. in
    let s = Entity.Ball.make x y 30 30 (Texture.Color (Gfx.color 255 255 255 255)) mass in
    s#sum_forces#set Vector.{ x = 0.0; y = -0.5 };
    s

let bricks =
  let width = 10 in (* laisser à 10 *)
  let size = 50 in (* multiple de 10 *)
  ref (List.init size
    (fun i ->
      (Entity.Brique.make
                 (60.0 +. 90.0 *. (float_of_int (i mod width)))
                 (100.0 +. 30.0 *. (float_of_int (i / width)))
                 70 20
                 (let r = int_of_float ((float_of_int (i mod width)) /. (float_of_int (width-1)) *. 255.0) in
                  let g = 255 - (int_of_float ((float_of_int i) /. (float_of_int size) *. 255.0)) in
                  let b = int_of_float (255.0 *. ((float_of_int i) /. (float_of_int size))) in
                  Texture.Color (Gfx.color r g b 255))
                 (1.05 -. 0.01 *. (float_of_int (i/width)))
      )
    ))

let load_all_images () =
  List.iter Surface_manager.load_surface [ 
  "resources/images/ball.png";
  "resources/images/wp.png";
  ]

let wait_for_images _dt =
  Format.eprintf "Waiting for images\n%!";
  not (Surface_manager.all_loaded ())

let init_walls () =
  let c = Gfx.color 0 100 100 255 in
  ignore (Entity.Wall.make 0.0 0.0 1000 40 (Texture.Color c));
  ignore (Entity.Wall.make 0.0 40.0 40 490 (Texture.Color c));
  ignore (Entity.Wall.make 960.0 40.0 40 490 (Texture.Color c))

let init_wp _dt =
  ignore(Draw.set_wp "resources/images/wp.png");
  false

let update_bricks _dt =
  bricks := List.filter
             (fun b -> let touched = b#touched#get in
                       if touched then
                         (ignore (Entity.Block.destroy b)); not touched
                       ) !bricks

let keys = Hashtbl.create 16

let out_of_canvas x y =
  not (x >= 0. && x <= 1000. && y >= 0. && y <= 600.)

let print_final () =
  let white = Gfx.color 255 255 255 255 in
  let win = Game_state.get_window () in
  let ctx = Gfx.get_context win in
  let win_surf = Gfx.get_surface win in
  let font = Gfx.load_font "Roboto" "" 50 in
  let color, txt = match !bricks with
    | [] -> (Gfx.color 0 255 0 255, "gagné !!")
    | _ -> (Gfx.color 255 0 0 255, "perdu, bouffon")
  in
  let txt_surf = Gfx.render_text ctx txt font in
  let w, h = Gfx.get_context_logical_size ctx in
  let () = Gfx.set_color ctx color in
  let () = Gfx.fill_rect ctx win_surf 0 0 w h in
  let () = Gfx.set_color ctx white in
  Gfx.blit ctx win_surf txt_surf 500 500;
  Gfx.commit ctx

let update dt =
  let () =
    match Gfx.poll_event () with
    | Gfx.NoEvent -> ()
    | Gfx.KeyDown s ->
        Gfx.debug "%s@\n%!" s;
        Hashtbl.replace keys s ()
    | Gfx.KeyUp s -> Hashtbl.remove keys s
  in
  let Vector.{ x; y } = p1#position#get in
  let x = if Hashtbl.mem keys "ArrowLeft" && x > 0. then x -. 10.0 else x in
  let x = if Hashtbl.mem keys "ArrowRight" && x < 1000. -. (float_of_int p_width) then x +. 10.0 else x in
  p1#position#set Vector.{ x; y };
  p2#position#set Vector.{ x = x +. (float_of_int petite_planche_width) +. (float_of_int gap_width); y };
  p3#position#set Vector.{ x = x +. (float_of_int petite_planche_width) +. 2. *. (float_of_int gap_width) +. (float_of_int main_planche_width) ; y };
  ignore(update_bricks dt);
  let Vector.{x; y} = ball#position#get in
  if (out_of_canvas x y) || !bricks = [] then (
    print_final ();
    false)
  else (
  Collision_system.update dt;
  Force_system.update dt;
  Move_system.update dt;
  Draw_system.update dt;
  true)

let init_ball _dt =
  let surface = Surface_manager.get_surface "resources/images/ball.png" in
  ball#texture#set (Texture.Surface surface);
  false

let chain_functions l =
  let funs = ref l in
  fun dt -> 
    match !funs with
    [] -> false
    | f :: ll ->
      if f dt then true
      else begin
        funs := ll;
        true
      end

  
let run () =
  init ();
  load_all_images ();
  init_walls ();
  Gfx.main_loop ( chain_functions [ 
    wait_for_images;
    init_wp;
    init_ball;
    update ]);
  
