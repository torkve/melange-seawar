type result_t = Message.Message.ShotResult.result_t;;

type state_t = [
    |`Missed
    |`Damaged of int
    |`Killed of int
    |`Normal of int
    |`Unknown
];;

type callback_t = int -> int -> string -> unit;;

type t = {
    mutable fields: state_t array array;    
    mutable ships: (int * int * state_t) list array;
    mutable alive: int;
    mutable callback: callback_t;
};;

let label_of_state = function
    | `Missed -> "⋅"
    | `Damaged _ -> "/"
    | `Killed _ -> "x"
    | `Normal _ -> "o"
    | `Unknown -> " "
;;

(* Create new empty board *)
let init cb () = {
    fields = Array.make_matrix 10 10 `Unknown;
    ships = Array.make 10 [];
    alive = 10;
    callback = cb;
};;

let cartesian l1 l2 = List.map (fun e -> List.map (fun e' -> (e, e')) l2) l1 |> List.concat;;

let is_correct (row,col) = row >= 0 && row <= 9 && col >= 0 && col <= 9;;

let aget board row col =
    if is_correct (row, col) then board.fields.(row).(col)
    else `Unknown
;;

let get board row col = aget board row col |> label_of_state;;

let aset board row col v =
    board.fields.(row).(col) <- v;
    board.callback row col (label_of_state v)
;;

(* Shot the field and get the result of shot *)
let shot board row col =
    let noncurrent_point_filter v = (* Left only points of the ship that are not current point *)
        match v with
            | (r, c, _) when r = row && c = col -> false
            | _ -> true
    in
    
    let normal_points_filter v = (* Left only points that have `Normal state *)
        match v with
            | (_, _, `Normal(x)) -> true
            | _ -> false
    in

    let write_new_points index points =
        List.iter (function (r, c, s) -> aset board r c s) points;
        board.ships.(index) <- points;
    in
    
    let update_if_killed index =
        let mark_as_killed sh = List.map (function (r,c,_) -> (r,c,`Killed index)) sh in
        
        let points = board.ships.(index) in
        let new_points = (row, col, `Damaged(index)) :: List.filter noncurrent_point_filter points in
        
        match List.filter normal_points_filter new_points with
            | [] -> write_new_points index (mark_as_killed new_points); board.alive <- board.alive - 1; `Killed
            | _ -> write_new_points index new_points; `Damaged
        in
    
    let state = aget board row col in
    match state with
        | `Missed | `Unknown -> aset board row col `Missed; `Missed
        | `Killed _ -> `Killed
        | `Normal x | `Damaged x -> update_if_killed x
;;

(* Just mark the field of board as missed/damaged/killed *)
let mark board row col result =
    let state = aget board row col in
    let next_sibling points = List.flatten (List.map (function (r,c) -> (cartesian [r+1; r-1] [c]) @ (cartesian [r] [c+1; c-1])) points) in

    let rec update_killed points () =
        let next_points = next_sibling points |> List.filter is_correct in
        let ship_points = List.filter (function (r,c) -> match aget board r c with | `Damaged _ -> true | _ -> false) next_points in

        next_points @ points
            |> List.filter (fun (r,c) -> match aget board r c with | `Damaged _ | `Killed _ -> true | _ -> false)
            |> List.map (function (r,c) -> cartesian [r-1; r; r+1] [c-1; c; c+1])
            |> List.flatten
            |> List.filter is_correct
            |> List.filter (fun (r,c) -> match aget board r c with | `Unknown -> true | _ -> false)
            |> List.iter (fun (r,c) -> aset board r c `Missed);

        List.iter (function (r,c) -> aset board r c (`Killed 0)) ship_points;
        match ship_points with
            | [] -> ()
            | _ -> update_killed ship_points ()
        in
        
    match result with
        | `Killed -> (match state with `Killed x -> ()
                    | _ -> aset board row col (`Killed 0); board.alive <- board.alive - 1; update_killed [(row,col)] ()
                    )
        | `Damaged -> aset board row col (`Damaged 0)
        | `Unknown(x) -> aset board row col `Unknown
        | `Missed -> aset board row col `Missed
;;

let print board =
    let print_el x = print_string (label_of_state x) in
    print_endline "  0 1 2 3 4 5 6 7 8 9";
    Array.iteri (function index -> function row ->
        print_int index; print_string " ";
        Array.iter (function el -> print_el el; print_string " ") row;
        print_newline ()) board.fields
;;

let print2 board board' =
    let print_el x = print_string (label_of_state x) in
    print_endline "  0 1 2 3 4 5 6 7 8 9    0 1 2 3 4 5 6 7 8 9";
    for i = 0 to 9 do
        print_int i; print_string " ";
        Array.iter (function el -> print_el el; print_string " ") board.fields.(i);
        print_string " "; print_int i; print_string " ";
        Array.iter (function el -> print_el el; print_string " ") board'.fields.(i);
        print_newline ();
    done
;;
    
let mklist start length = 
    let rec mklist_ accum start = function 
        | 0 -> accum
        | x when x<0 -> mklist_ (start :: accum) (start-1) (x+1)
        | x -> mklist_ (start :: accum) (start+1) (x-1)
    in
    mklist_ [] start length
;;
let mkrlist index row l = List.map (function x -> (row, x, `Normal index)) l;;
let mkclist index col l = List.map (function x -> (x, col, `Normal index)) l;;

let _ = Random.self_init() ;;
(* generate new board with the ships *)
let generate cb () =
    let board = init cb () in
    let aget_ = aget board in
    let aset_ = aset board in
    
    let valid_place row col = is_correct (row, col) && List.for_all (fun (r, c) -> aget_ r c == `Unknown) (cartesian [row-1; row; row+1] [col-1; col; col+1]) in
    let valid_ship row col length = function
        | 0 -> List.for_all (valid_place row) (mklist col length)
        | 1 -> List.for_all (valid_place row) (mklist col (-length))
        | 2 -> List.for_all (function x -> valid_place x col) (mklist row length)
        | 3 -> List.for_all (function x -> valid_place x col) (mklist row (-length))
        | _ -> raise (Failure "Illegal direction proposed for ship generator")
    in
    let set_ship index row col length = function
        | 0 -> board.ships.(index) <- (mkrlist index row (mklist col length));
                List.iter (function x -> aset_ row x (`Normal index)) (mklist col length)
        | 1 -> board.ships.(index) <- (mkrlist index row (mklist col (-length)));
                List.iter (function x -> aset_ row x (`Normal index)) (mklist col (-length))
        | 2 -> board.ships.(index) <- (mkclist index col (mklist row length));
                List.iter (function x -> aset_ x col (`Normal index)) (mklist row length)
        | 3 -> board.ships.(index) <- (mkclist index col (mklist row (-length)));
                List.iter (function x -> aset_ x col (`Normal index)) (mklist row (-length))
        | _ -> raise (Failure "Illegal direction proposed for ship generator")
        in
    let rec place index length =
        let row = Random.int 10 in
        let col = Random.int 10 in
        let direction = Random.int 4 in
        if valid_ship row col length direction then set_ship index row col length direction else place index length
    in
    place 0 4;
    for i = 1 to 2 do place i 3 done;
    for i = 1 to 3 do place (2+i) 2 done;
    for i = 1 to 4 do place (5+i) 1 done;
    board
;;

let ships_remain board = board.alive > 0;;
