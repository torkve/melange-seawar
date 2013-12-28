let _ =
    let game = Game.init_game () in
    if not game#is_ai then
        QmlContext.run_with_QQmlApplicationEngine Sys.argv (Gui.player game) "gui.qml"
    else
        Ai.ai game
;;
