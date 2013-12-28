packet message {
    message_type: byte;
    message_id: uint16;
    classify (message_type) {
        | 0:"Shot" ->
            row: bit[4];
            column: bit[4];
        | 1:"ShotResult" ->
            result: byte variant { |0 -> Missed |1 -> Damaged |2 -> Killed };
        | 2:"Disconnect" -> ();
    };
}
