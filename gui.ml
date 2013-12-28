open Unix;;
open Message;;

(* gui elements creation *)

let boarditem_of_data x y state =
    let cppobj = BoardItem.create_BoardItem () in
    object(self)
        inherit BoardItem.base_BoardItem cppobj as super
        val mutable state_ = state
        method cellX () = x
        method cellY () = y
        method cellState () = state_
        method setCellState v = if v <> state_ then (state_ <- v; self#emit_cellStateChanged state_ )
    end
;;

let make_itemlist () = Array.init 100 (fun i -> boarditem_of_data (i mod 10) (i / 10) "");;

let make_model dataItems clickCallback =
    let cppobj = BoardModel.create_BoardModel () in
    BoardModel.add_role cppobj 555 "cellState";
    BoardModel.add_role cppobj 556 "cellX";
    BoardModel.add_role cppobj 557 "cellY";
    BoardModel.add_role cppobj 558 "cell";
    object(self)
        inherit BoardModel.base_BoardModel cppobj as super
        method parent _ = QmlContext.QModelIndex.empty
        method columnCount _ = 1
        method index row column parent =
            if row >= 0 && row < 100 then QmlContext.QModelIndex.make ~row ~column:0
            else QmlContext.QModelIndex.empty
        method hasChildren _ = true
        method rowCount _ = 100
        method data index role =
            let r = QmlContext.QModelIndex.row index in
            if r < 0 || r >= 100 then QmlContext.QVariant.empty
            else begin
                match role with
                    | 0 | 555 -> QmlContext.QVariant.of_string (dataItems.(r)#cellState ())
                    | 556 -> QmlContext.QVariant.of_int (dataItems.(r)#cellX ())
                    | 557 -> QmlContext.QVariant.of_int (dataItems.(r)#cellY ())
                    | 558 -> QmlContext.QVariant.of_object (dataItems.(r)#handler)
                    | _ -> QmlContext.QVariant.empty
            end
        method onMouseClicked x y =
            let item = dataItems.(y * 10 + x) in
            clickCallback (item#cellX()) (item#cellY())
    end
;;

let set_property prop value = QmlContext.set_context_property ~ctx:(QmlContext.get_view_exn ~name:"rootContext") ~name:prop value;;

(* Main *)

let player (game:Game.t) () =
    let own_board_items = make_itemlist () in
    let opp_board_items = make_itemlist () in

    let own_board = Board.generate (fun row col s -> own_board_items.(col + row * 10)#setCellState s) () in
    let opp_board = Board.init (fun row col s -> opp_board_items.(col + row * 10)#setCellState s) () in

    let own_board_model = make_model own_board_items (fun _ _ -> ()) in
    let opp_board_model = make_model opp_board_items game#shot in

    game#tick `Initialize;

    let rec send_shot col row = (* make a shot and get result *)
        ignore(game#send_message (Message.Shot.t ~row:row ~column:col :> Game.sm_constr));
        let result, state = game#receive_message in
        (match result with
            | `ShotResult x -> Board.mark opp_board row col x#result;
                    next_turn state x#result
            | `Disconnect x -> game#disconnect false
            | _ -> game#disconnect ~exc_text:"Unexpected_Message_Type" ~raise_exc:true true)
    and catch_shot () = (* receive a shot and send response *)
        let rec catch_shot' () =
            let _shot, state = game#receive_message in
            let msg = match _shot with
                | `Shot x -> x
                | `Disconnect x -> game#disconnect false; raise Exit
                | _ -> game#disconnect ~exc_text:"Unexpected_Message_Type" ~raise_exc:true true; raise Exit
            in
            let result = Board.shot own_board msg#row msg#column in
            let state = game#send_message (Message.ShotResult.t ~result:result :> Game.sm_constr) in
            next_turn state result
        in
        ignore(Thread.create catch_shot' ());
        Thread.delay 0.01;
        ()
    and next_turn prev_turn success = (* select next state *)
        game#tick `Ready;
        if not (game#check_finish own_board opp_board) then (
            match (prev_turn, success) with
                | (`Receive_Message_ShotResult, `Missed) -> game#set_state Game.OppTurn; catch_shot ()
                | (`Receive_Message_ShotResult, _) -> game#set_state Game.OwnTurn
                | (`Transmit_Message_ShotResult, `Missed) -> game#set_state Game.OwnTurn
                | (`Transmit_Message_ShotResult, _) -> game#set_state Game.OppTurn; catch_shot ()
                | _ -> game#disconnect ~exc_text:"Unexpected_Message_Type" ~raise_exc:true true
        )
    in

    game#set_shot send_shot;
    game#set_exit_on_finish false;

    let game_controller =
        let cppobj = GameController.create_GameController () in
        object(self)
            inherit GameController.base_GameController cppobj as super
            method initBaseState () =
                game#tick `Ready;
                if game#is_server then begin
                    game#set_state Game.OppTurn;
                    catch_shot ()
                end else game#set_state Game.OwnTurn
        end
    in
    game#set_message_display game_controller#emit_noteChanged;
    game#set_turn_change (function
        | Game.Own -> game_controller#emit_turnChanged "own"
        | Game.Opp -> game_controller#emit_turnChanged "opp"
    );

    set_property "ownBoardModel" own_board_model#handler;
    set_property "oppBoardModel" opp_board_model#handler;
    set_property "game" game_controller#handler;
;;
