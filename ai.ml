open Message;;

let is_correct (row,col) = row >= 0 && row <= 9 && col >= 0 && col <= 9;;

let ai (game:Game.t) =
    let own_board = Board.generate (fun _ _ _ -> ()) () in
    let opp_board = Board.init (fun _ _ _ -> ()) () in

    let shot_candidates = ref [] in

    let not_shotted (r, c) = (Board.get opp_board r c).[0] == ' ' in
    let damaged (r, c) = (Board.get opp_board r c).[0] == '/' in

    (* Return random values as we're AI *)
    let get_shot_coords () =
        let rec random_coords () =
            let r = ref (Random.int 10) in
            let c = ref (Random.int 10) in

            while not (not_shotted (!r,!c)) do
                r := Random.int 10;
                c := Random.int 10
            done;
            !r, !c
        in

        match !shot_candidates with
            | [] -> random_coords ()
            | (r,c) :: y ->
                shot_candidates := y;
                r,c
    in

    let next_siblings r c =
        let candidates = [
            ((r-1, c), (r+1, c));
            ((r+1, c), (r-1, c));
            ((r, c-1), (r, c+1));
            ((r, c+1), (r, c-1));
            ] in
        let siblings = ref [] in
        List.iter (fun ((r1, c1), (r2, c2)) ->
            if is_correct (r1, c1) && is_correct (r2, c2)
                && damaged (r1, c1)
                && not_shotted (r2, c2)
            then siblings := (r2, c2) :: !siblings) candidates;
        match !siblings with
            | [] -> [(r-1, c); (r+1, c); (r, c-1); (r, c+1)] |> List.filter is_correct |> List.filter not_shotted
            | _ -> !siblings
    in

    let update_shot_candidates candidates = 
        if List.length !shot_candidates > 0
        then (match List.hd candidates with
            | (r1, c1) -> shot_candidates := List.filter (fun (r2, c2) -> r1 == r2 || c1 == c2) !shot_candidates
        );
        shot_candidates := !shot_candidates @ candidates
    in

    game#tick `Initialize;

    game#set_message_display prerr_endline;

    let rec shot () = (* make a shot and get result *)
        let row, col = get_shot_coords () in
        send_shot col row
    and send_shot col row =
        ignore(game#send_message (Message.Shot.t ~row:row ~column:col :> Game.sm_constr));
        let result, state = game#receive_message in
        (match result with
            | `ShotResult x ->
                    (match x#result with 
                        |`Damaged -> next_siblings row col |> update_shot_candidates
                        |`Killed -> shot_candidates := []
                        | _ -> ()
                    );
                    Board.mark opp_board row col x#result;
                    next_turn (state:>Protocol.s) x#result
            | `Disconnect _ -> game#disconnect false
            | _ -> game#disconnect ~exc_text:"Unexpected_Message_Type" ~raise_exc:true true
            )
    and catch_shot () = (* receive a shot and send response *)
        let _shot, state = game#receive_message in
        let msg = match _shot with
            | `Shot x -> x
            | `Disconnect _ -> game#disconnect false; raise Exit
            | _ -> game#disconnect ~exc_text:"Unexpected_Message_Type" ~raise_exc:true true; raise Exit
        in
        let result = Board.shot own_board msg#row msg#column in
        let response = (Message.ShotResult.t ~result:result :> Game.sm_constr) in
        let state = game#send_message response in
        next_turn state result
    and next_turn prev_turn success = (* make next turn *)
        Board.print2 own_board opp_board;
        game#tick `Ready;
        ignore(game#check_finish own_board opp_board);
        match (prev_turn, success) with
            | (`Receive_Message_ShotResult, `Missed) -> catch_shot ()
            | (`Receive_Message_ShotResult, _) -> shot ()
            | (`Transmit_Message_ShotResult, `Missed) -> shot ()
            | (`Transmit_Message_ShotResult, _) -> catch_shot ()
            | _ -> game#disconnect ~exc_text:"Unexpected_Message_Type" ~raise_exc:true true
    in

    game#set_shot send_shot;

    game#tick `Ready;

    if game#is_server then catch_shot() else shot ()
;;

