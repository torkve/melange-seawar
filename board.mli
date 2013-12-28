type t

type result_t = Message.Message.ShotResult.result_t

(* Callback that is used to mark cell in gui *)
type callback_t = int -> int -> string -> unit

(* Create new empty board *)
val init : callback_t -> unit -> t

(* Shot the field and get the result of shot *)
val shot : t -> int -> int -> result_t

(* Just mark the field of board as missed/damaged/killed *)
val mark : t -> int -> int -> result_t -> unit

(* Check the state of the field *)
val get : t -> int -> int -> string

(* generate new board with the ships *)
val generate : callback_t -> unit -> t

(* Check if some ships alive remain *)
val ships_remain : t -> bool

(* Print board state *)
val print : t -> unit

(* Print two boards in parallel *)
val print2 : t -> t -> unit
