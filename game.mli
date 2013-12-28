type turn = Own | Opp;;
type state = GameOver | Wait | OwnTurn | OppTurn;;

type sendable_message = < xmit_statecall : Message.Message.statecalls >;;
type sm_constr = message_id:int -> Mpl_stdlib.env -> sendable_message;;

type t = <
   tick : Protocol.s -> unit;
   is_server : bool;
   is_ai : bool;
   message_display : string -> unit;
   set_message_display : (string -> unit) -> unit;
   turn_change : turn -> unit;
   set_turn_change : (turn -> unit) -> unit;
   shot : int -> int -> unit;
   set_shot : (int -> int -> unit) -> unit;
   set_state : state -> unit;
   disconnect : ?exc_text:string -> ?raise_exc:bool -> bool -> unit;
   send_message : sm_constr -> Protocol.s;
   receive_message : Message.Message.o * Protocol.s;
   set_exit_on_finish : bool -> unit;
   check_finish : Board.t -> Board.t -> bool;
   >
;;

val init_game : unit -> t;;
