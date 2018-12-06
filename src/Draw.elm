--module Draw exposing (pusher, mover, abyss, empty, isInBoard)
module Draw exposing (board, isInBoard)

import List
import Svg exposing (Svg)
import Svg.Attributes as Attributes

-- TODO implement rails

isInBoard : Int -> Int -> Bool
isInBoard x y =
    if y == 0 then
         2 < x && x < 8
    else if y == 1 || y == 2 then
         0 < x && x < 9
    else if y == 3 then
         1 < x && x < 7
    else
        False


drawBoardSquare : Int -> Int -> Int -> Svg msg
drawBoardSquare size y x =
    let
        (color, extraStyles) =
            if isInBoard x y then
                ("#8B4513", [Attributes.strokeWidth "1", Attributes.stroke "black"])
            else
                 ("#0000ff", [])

    in
        Svg.rect (
            List.append extraStyles
                [ Attributes.x <| String.fromInt (size * x)
                , Attributes.y <| String.fromInt (size * y)
                , Attributes.width <| String.fromInt size
                , Attributes.height <| String.fromInt size
                , Attributes.fill color
                ]
            ) []




drawRow : Int -> List Int -> Int -> List (Svg msg)
drawRow size xs y =
    List.map (drawBoardSquare size y) xs

board : Int -> List (Svg msg)
board size =
    List.map (drawRow size (List.range 0 9)) (List.range 0 3)
    |> List.concat




pusher : Int -> Int -> Int -> String -> Svg msg
--pusher size color isAnchored =
--    let
--        ( posx, posy, totsize ) =
--            ( 0.0, 0.0, 1.0 )

--        anchor =
--            case isAnchored of
--                True ->
--                    circle
--                        [ fill "#ff0000"
--                        , cx (String.fromFloat (posx + (totsize / 2.0)))
--                        , cy (String.fromFloat (posy + (totsize / 2.0)))
--                        , r (String.fromFloat (totsize / 4.0))
--                        ]
--                        []

--                _ ->
--                    circle
--                        [ fill color
--                        , cx (String.fromFloat (posx + (totsize / 2.0)))
--                        , cy (String.fromFloat (posy + (totsize / 2.0)))
--                        , r (String.fromFloat (totsize / 4.0))
--                        ]
--                        []
--    in
--    svg
--        [ x (String.fromFloat 0)
--        , y (String.fromFloat 0)
--        , width (String.fromFloat size)
--        , height (String.fromFloat size)
--        , viewBox
--            ("0 0 "
--                ++ String.fromFloat totsize
--                ++ " "
--                ++ String.fromFloat totsize
--            )
--        ]
--        [ rect
--            [ fill "#333333"
--            , x (String.fromFloat (posx + totsize * 0.02))
--            , y (String.fromFloat (posy + totsize * 0.02))
--            , width (String.fromFloat (totsize * 0.96))
--            , height (String.fromFloat (totsize * 0.96))
--            ]
--            []
--        , rect
--            [ fill color
--            , x (String.fromFloat (posx + totsize * 0.1))
--            , y (String.fromFloat (posy + totsize * 0.1))
--            , width (String.fromFloat (totsize * 0.8))
--            , height (String.fromFloat (totsize * 0.8))
--            ]
--            []
--        , anchor
--        ]


--mover : Float -> String -> Html.Html msg
--mover size color =
--    let
--        ( posx, posy, totsize ) =
--            ( 0.0, 0.0, 1.0 )
--    in
--    svg
--        [ x (String.fromFloat 0)
--        , y (String.fromFloat 0)
--        , width (String.fromFloat size)
--        , height (String.fromFloat size)
--        , viewBox
--            ("0 0 "
--                ++ String.fromFloat totsize
--                ++ " "
--                ++ String.fromFloat totsize
--            )
--        ]
--        [ circle
--            [ fill "#333333"
--            , cx (String.fromFloat (posx + (totsize / 2.0)))
--            , cy (String.fromFloat (posy + (totsize / 2.0)))
--            , r (String.fromFloat (totsize / 2.0))
--            ]
--            []
--        , circle
--            [ fill color
--            , cx (String.fromFloat (posx + (totsize / 2.0)))
--            , cy (String.fromFloat (posy + (totsize / 2.0)))
--            , r (String.fromFloat ((totsize * 0.9) / 2.0))
--            ]
--            []
--        ]


--abyss : Float -> Html.Html msg
--abyss size =
--    let
--        ( posx, posy, totsize ) =
--            ( 0.0, 0.0, 1.0 )
--    in
--    svg
--        [ x (String.fromFloat 0)
--        , y (String.fromFloat 0)
--        , width (String.fromFloat size)
--        , height (String.fromFloat size)
--        , viewBox
--            ("0 0 "
--                ++ String.fromFloat totsize
--                ++ " "
--                ++ String.fromFloat totsize
--            )
--        ]
--        [ rect
--            [ fill "#0000ff"
--            , x (String.fromFloat posx)
--            , y (String.fromFloat posy)
--            , width (String.fromFloat totsize)
--            , height (String.fromFloat totsize)
--            ]
--            []
--        ]


--boardColor =
--    "#8B4513"


--empty : Float -> Html.Html msg
--empty size =
--    let
--        ( posx, posy, totsize ) =
--            ( 0.0, 0.0, 1.0 )
--    in
--    svg
--        [ x (String.fromFloat 0)
--        , y (String.fromFloat 0)
--        , width (String.fromFloat size)
--        , height (String.fromFloat size)
--        , viewBox
--            ("0 0 "
--                ++ String.fromFloat totsize
--                ++ " "
--                ++ String.fromFloat totsize
--            )
--        ]
--        [ rect
--            [ fill boardColor
--            , x (String.fromFloat posx)
--            , y (String.fromFloat posy)
--            , width (String.fromFloat totsize)
--            , height (String.fromFloat totsize)
--            ]
--            []
--        ]
