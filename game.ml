open Unix;;
open Message;;

module M = Mpl_stdlib;;

type turn = Own | Opp;;
type state = GameOver | Wait | OwnTurn | OppTurn;;
type sendable_message = < xmit_statecall : Message.statecalls>;;
type sm_constr = message_id:int -> M.env -> sendable_message;;

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
   receive_message : Message.o * Protocol.s;
   set_exit_on_finish : bool -> unit;
   check_finish : Board.t -> Board.t -> bool;
   >
;;
let message_of_state = function
    | Wait -> "Wait..."
    | GameOver -> "Game over!"
    | OwnTurn -> "Your turn!"
    | OppTurn -> "Opponent's turn"
;;

let turn_of_state = function | OwnTurn -> Own | _ -> Opp;;

let init_game () : t =
    let is_server = ref false in
    let is_ai = ref false in
    let remote_host = ref "127.0.0.1" in
    let port = ref 9999 in
    let ipv6 = ref false in
    let sock = ref (socket PF_INET SOCK_STREAM 0) in

    let args = [("--server", Arg.Set is_server, "Run in server mode (false by default)");
                ("--host", Arg.Set_string remote_host, "IP address of server (only for clients, 127.0.0.1 by default)");
                ("--ipv6", Arg.Set ipv6, "Bind to IPv6 address");
                ("--ai", Arg.Set is_ai, "Use AI instead of player");
                ("--port", Arg.Set_int port, "Port to use (9999 by default)");
    ] in
    Arg.parse args (function x -> raise (Arg.Bad x))
        "Welcome to the seawar!\nStarted as server it operates as AI, while client is controlled by you.\n";

    if !ipv6 then sock := socket PF_INET6 SOCK_STREAM 0;

    if !is_server then begin
        setsockopt !sock SO_REUSEADDR true;
        let addr = ADDR_INET ((if !ipv6 then inet6_addr_any else inet_addr_any), !port) in (* Create 0.0.0.0:9999 addr *)
        bind !sock addr;
        listen !sock 1;
        accept !sock |> fun (s, _) -> sock := s
    end else begin
        let addr = ADDR_INET (inet_addr_of_string !remote_host, !port) in
        connect !sock addr
    end;


    object(self)
        (* Protocol *)
        val mutable tick_ = Protocol.init ();
        method tick s = (*prerr_endline (Proto.string_of_statecall s);*) tick_ <- Protocol.tick tick_ s;
        val mutable msgid_ = 0;
        method private next_msgid = (let x = msgid_ in msgid_ <- msgid_ + 1; x);
        val env_ = M.new_env (String.make 4 '\000');
        (* Net *)
        val sock_ = !sock;
        method is_server = !is_server;
        method is_ai = !is_ai;
        (* Callbacks *)
        val mutable md_cb = (fun _ -> ());
        val mutable tc_cb = (fun _ -> ());
        val mutable s_cb = (fun _ _ -> ());
        (* Misc *)
        val mutable exit_on_finish = true;

        method message_display x = md_cb x;
        method turn_change = tc_cb;
        method shot col row = (
            self#set_state Wait;
            s_cb col row;
        );
        method set_message_display cb = md_cb <- cb;
        method set_turn_change cb = tc_cb <- cb;
        method set_shot cb = s_cb <- cb;
        method set_exit_on_finish v = exit_on_finish <- v;

        method set_state x = (
            turn_of_state x |> self#turn_change;
            message_of_state x |> self#message_display
        );
        (* Network operations *)
        method send_message msg' = (
            let id = self#next_msgid in
            M.reset env_;
            let msg = ((msg' ~message_id:id env_) :> sendable_message) in
            self#tick (msg#xmit_statecall :> Protocol.s);
            if not (Thread.wait_timed_write sock_ 10.) then self#disconnect ~exc_text:"Timeout" ~raise_exc:true false;
            M.flush env_ sock_;
            msg#xmit_statecall :> Protocol.s
        );
        method receive_message = (
            M.reset env_;
            if not (Thread.wait_timed_read sock_ 300.) then self#disconnect ~exc_text:"Timeout" ~raise_exc:true false;
            M.fill env_ sock_;
            let msg = Message.unmarshal env_ in
            ignore(self#next_msgid);
            let state = Message.recv_statecall msg in
            self#tick state;
            msg, state
        );
        method disconnect ?(exc_text="Unknown error") ?(raise_exc=false) send_disconnect = (
            self#set_state GameOver;
            if send_disconnect then ignore(self#send_message (Message.Disconnect.t:>sm_constr));
            if raise_exc then failwith exc_text;
            if exit_on_finish then raise Exit;
        );
        method check_finish own opp =
            match (Board.ships_remain own), (Board.ships_remain opp) with
                | false, _ -> self#disconnect true; self#message_display "You lose"; true
                | _, false -> self#disconnect true; self#message_display "You win"; true
                | _ -> false
    end
;;
