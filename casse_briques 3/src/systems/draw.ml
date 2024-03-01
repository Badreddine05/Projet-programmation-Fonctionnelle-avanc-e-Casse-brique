open Component_defs


class type drawable =
  object
  inherit box
  inherit position
  inherit texture
end

type t = drawable

let init () = Surface_manager.load_surface "resources/images/wp.png"

let white = Gfx.color 255 255 255 255
let wp = ref None

let update _dt el =
  let win = Game_state.get_window () in
  let ctx = Gfx.get_context win in
  let win_surf = Gfx.get_surface win in
  let w, h = Gfx.get_context_logical_size ctx in
  let () = Gfx.set_color ctx white in
  let () = 
  match !wp with
  | Some s -> Gfx.blit_scale ctx win_surf s 0 0 w h 
  | None -> Gfx.fill_rect ctx win_surf 0 0 w h
            in

  Seq.iter (fun (e : t) ->
    let Vector.{ x; y } = e # position # get in
    let Rect.{width; height} = e # box # get in
    match e # texture # get with
    | Texture.Color color -> 
      Gfx.set_color ctx color;
      Gfx.fill_rect ctx win_surf (int_of_float x) (int_of_float y) width height
    | Texture.Surface surface ->
      Gfx.blit_scale ctx win_surf surface (int_of_float x) (int_of_float y) width height
    (*| _ -> ... *)
    ) el;
    Gfx.commit ctx

let set_wp str =
  wp := Some (Surface_manager.get_surface str)
