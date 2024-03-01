let manager = Hashtbl.create 16


let load_surface src =
  let win = Game_state.get_window () in
  let ctx = Gfx.get_context win in
  let img_res = Gfx.load_image ctx src in
  Hashtbl.replace manager src img_res


let get_surface src =
  try
    let img_res = Hashtbl.find manager src in
    if Gfx.resource_ready img_res then
      Gfx.get_resource img_res
    else
      failwith (src ^ " is not ready")
    with Not_found ->
      failwith (src ^ " is not loaded")


let all_loaded () =
  Hashtbl.fold (fun _ res acc -> acc && Gfx.resource_ready res) 
  manager true
  
  
