module Draw exposing (board, isInBoard, pusher, mover, anchor)

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



pusher : Int -> Int -> Int -> String -> List (Svg msg)
pusher size x y color =
    let
        (posx, posy, fsize) =
            (toFloat (size * x), toFloat (size * y), toFloat size)
    in
        [ Svg.rect
            [ Attributes.fill "#333333"
            , Attributes.x <| String.fromInt <| round (posx + fsize * 0.02)
            , Attributes.y <| String.fromInt <| round (posy + fsize * 0.02)
            , Attributes.width <| String.fromInt <| round (fsize * 0.96)
            , Attributes.height <| String.fromInt <| round (fsize * 0.96)
            ]
            []
        , Svg.rect
            [ Attributes.fill color
            , Attributes.x <| String.fromInt <| round (posx + fsize * 0.1)
            , Attributes.y <| String.fromInt <| round (posy + fsize * 0.1)
            , Attributes.width <| String.fromInt <| round (fsize * 0.8)
            , Attributes.height <| String.fromInt <| round (fsize * 0.8)
            ]
            []
        ]

mover : Int -> Int -> Int -> String -> List (Svg msg)
mover size x y color =
    let
        (posx, posy, fsize) =
            (toFloat (size * x), toFloat (size * y), toFloat size)
    in
        [ Svg.circle
            [ Attributes.fill "#333333"
            , Attributes.cx <| String.fromInt <| round (posx + (fsize / 2.0))
            , Attributes.cy <| String.fromInt <| round (posy + (fsize / 2.0))
            , Attributes.r <| String.fromInt <| round (fsize / 2.0)
            ]
            []
        , Svg.circle
            [ Attributes.fill color
            , Attributes.cx <| String.fromInt <| round (posx + (fsize / 2.0))
            , Attributes.cy <| String.fromInt <| round (posy + (fsize / 2.0))
            , Attributes.r <| String.fromInt <| round ((fsize * 0.9) / 2.0)
            ]
            []
        ]


anchor : Int -> Int -> Int -> List (Svg msg)
anchor size x y =
    let
        (posx, posy, fsize) =
            (toFloat (size * x), toFloat (size * y), toFloat size)
    in
        [
            Svg.circle
                [ Attributes.fill "#ff0000"
                , Attributes.cx <| String.fromInt <| round (posx + (fsize / 2.0))
                , Attributes.cy <| String.fromInt <| round (posy + (fsize / 2.0))
                , Attributes.r <| String.fromInt <| round (fsize / 4.0)
                ]
                []
        ]
