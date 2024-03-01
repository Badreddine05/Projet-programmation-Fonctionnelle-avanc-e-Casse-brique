open Component_defs
open System_defs

module Block = 
struct
let make x y width height text mass =
  let b =
    object
      inherit position
      inherit box
      inherit texture
      (* Question 2 *)

      inherit mass
      inherit velocity
      inherit sum_forces
      inherit resistance
      inherit touched
      inherit nature
    end
  in
  b#touched#set false;
  b#position#set Vector.{ x; y };
  b#box#set Rect.{ width; height };
  b#texture#set text;
  b#nature#set Type.Wall;
  Draw_system.register (b :> Draw_system.t);
  (* Question 2 *)
  b#mass#set mass;
  (* Question 4 *)
  Move_system.register (b :> Move_system.t);
  (* Question 5 *)
  Force_system.register (b :> Force_system.t);
  (* Question 8*)
  Collision_system.register (b :> Collision_system.t);
  b

let destroy b =
  Draw_system.unregister (b :> Draw_system.t);
  Move_system.unregister (b :> Move_system.t);
  Force_system.unregister (b :> Force_system.t);
  Collision_system.unregister (b :> Collision_system.t);
end

module Brique =
  struct
    let make x y width height text res =
      let b =
        Block.make x y width height text infinity
      in
      b#nature#set Type.Block;
      b#resistance#set res;
      Move_system.unregister (b :> Move_system.t);
      b

    let destroy b = Block.destroy b
  end

module Wall =
  struct
    let make x y width height text =
      let b =
        Block.make x y width height text infinity
      in
      b#nature#set Type.Wall;
      Move_system.unregister (b :> Move_system.t);
      b

    let destroy b = Block.destroy b
  end

module Player =
  struct
    let make x y width height text gap planche =
      let b1 =
        Block.make x y planche height text infinity in
      let b2 =
        Block.make (x +. (float_of_int planche) +. (float_of_int gap)) y width height text infinity in
      let b3 =
        Block.make (x +. (float_of_int planche) +. 2. *. (float_of_int gap) +. (float_of_int width)) y planche height text infinity in
      b1#nature#set Type.(Player (Type.Left));
      b2#nature#set Type.(Player (Type.Middle));
      b3#nature#set Type.(Player (Type.Right));
      (b1, b2, b3)

    let destroy b = Block.destroy b
  end

module Ball =
  struct
    let make x y width height text mass =
      let b =
        Block.make x y width height text mass
      in
      b#nature#set Type.Ball;
      b

    let destroy b = Block.destroy b
  end
