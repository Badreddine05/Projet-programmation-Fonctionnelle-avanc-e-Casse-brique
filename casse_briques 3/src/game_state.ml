let window = ref None

let get_window () =
  match !window with
  | None -> failwith "Uninitialized window"
  | Some w -> w

let set_window (w : Gfx.window) =
  match !window with
  | None -> window := Some w
  | Some _ -> failwith "Window already initialized"
