open Js_of_ocaml
module Game = Breakout_core.Game

let state = ref (Game.create Game.Normal Game.Solid)
let snapshot () = Js.string (Game.snapshot !state)
let () =
  Js.export "BreakoutCore" (Js.Unsafe.obj [|
    "version", Js.Unsafe.inject (Js.string "1.0.0");
    "configure", Js.Unsafe.inject (Js.wrap_callback (fun difficulty mode ->
      let difficulty = match Js.to_string difficulty with "calm" -> Game.Calm | "expert" -> Game.Expert | _ -> Game.Normal in
      let mode = if Js.to_string mode = "split" then Game.Split else Game.Solid in
      state := Game.create difficulty mode; snapshot ()));
    "command", Js.Unsafe.inject (Js.wrap_callback (fun command ->
      state := Game.command !state (Js.to_string command); snapshot ()));
    "step", Js.Unsafe.inject (Js.wrap_callback (fun dt axis pointer ->
      let pointer = if Float.is_finite pointer then Some pointer else None in
      state := Game.advance !state dt Game.{axis; pointer}; snapshot ()));
    "snapshot", Js.Unsafe.inject (Js.wrap_callback snapshot)
  |])
