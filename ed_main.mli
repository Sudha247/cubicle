val root : Ed_graph.G.vertex option ref

(* val quit : unit -> unit *)

val reset_table_and_canvas : unit -> unit
 
val var_l : (* (GText.iter * GText.iter) Var_L.t *) string list ref

(* list ref (\* Var_L.t *\) *)

(* val open_graph : string -> int ->  unit *)

val graph_trace : string Queue.t

val refresh_display : unit -> unit

val refresh_draw : unit -> unit

val init : string -> int -> unit

val model_reset : unit -> unit 

val cpt : int ref
