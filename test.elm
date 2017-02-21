import Svg exposing (..)
import Svg.Attributes exposing (..)
import Debug exposing (log)
import Html

--(.) : String -> a -> String
--(.) str thing = str ++ " " ++ toString thing
--mlog: a -> b -> b
--mlog thing = log (toString thing)
--view model =
--    Html.div []
--    [ Html.p [] [ text "hello world" ]
--    , main
--    ]

main =
    Html.div [] [pusher 100.0 200.0 100.0 "#ffffff"]

    --let (w, _) = (10, log "width"  (1/10.0)) in
    --svg
    --    [
    --        version "1.1",
    --        x "0",
    --        y "0",
    --        viewBox
    --            ("0 0 " ++
    --            toString w ++
    --            " " ++
    --            toString w),
    --        width "200",
    --        height "200"
    --    ]
    --    (  (pusher 0 0 0.95 "#ffffff")
    --    ++ (pusher 1 0 0.95 "#ffffff")
    --    ++ (pusher 1 1 0.95 "#ffffff")
    --    ++ (mover  3 3 0.95 "#ffffff")
    --    ++ (mover  3 5 0.95 "#ffffff")
    --    ++ (mover  2 0 0.95 "#ffffff")
    --    ++ (mover  3 0 0.95 "#000000")
    --    )

pusher : Float -> Float -> Float -> String -> Html.Html msg
pusher posx posy size color =
    let
        totsize = 10.0 * size
    in
        svg
        [
            version "1.1",
            x (toString 0),
            y (toString 0),
            width (toString totsize),
            height (toString totsize),
            viewBox
                    ("0 0 " ++
                    toString (totsize) ++
                    " " ++
                    toString (totsize))
        ]
        [ rect
            [ fill "#000000"
            , x (toString posx)
            , y (toString posy)
            , width (toString size)
            , height (toString size)
            ]
            []
        , rect
            [ fill color
            , x (toString (posx+size * 0.05))
            , y (toString (posy+size * 0.05))
            , width (toString (size * 0.9))
            , height (toString (size * 0.9))
            ]
            []
        ]

mover : Float -> Float -> Float -> String -> Html.Html msg
mover posx posy size color =
    let
        totsize = 10.0 * size
    in
        svg
        [
                version "1.1",
                x (toString 0),
                y (toString 0),
                width (toString totsize),
                height (toString totsize),
                viewBox
                        ("0 0 " ++
                        toString (totsize) ++
                        " " ++
                        toString (totsize))
        ]
        [ circle
            [ fill "#000000"
            , cx (toString (posx + (size/2.0)))
            , cy (toString (posy + (size/2.0)))
            , r (toString (size/2.0))
            ]
            []
        , circle
            [ fill color
            , cx (toString (posx + (size/2.0)))
            , cy (toString (posy + (size/2.0)))
            , r (toString ((size * 0.9)/2.0))
            ]
            []
        ]
