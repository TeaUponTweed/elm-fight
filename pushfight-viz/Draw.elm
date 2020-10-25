module Draw exposing (board, isInBoard, pusher, mover, anchor, mapXY)

import List
import Svg exposing (Svg)
import Svg.Attributes as Attributes
import Html.Events.Extra.Touch as Touch
import PFTypes exposing (Msg(..), Orientation(..))

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

mapXY: Orientation -> Int -> Int -> (Int, Int)
mapXY orientation x y =
    case orientation of
        Zero ->
            (x, y)
        Ninety ->
            (y, x)
        OneEighty ->
            (9 - x, 3 - y)
        TwoSeventy ->
            (y, 3 - x)

drawBoardSquare : Int -> (Int -> Int -> (Int, Int)) -> Int -> Int -> Svg Msg
drawBoardSquare size rotateXY y x =
    let
        (xr, yr) =
            rotateXY x y
        (color, extraStyles) =
            if isInBoard x y then
                ("#8B4513", [Attributes.strokeWidth "1", Attributes.stroke "black"])
            else
                 ("#aaaaaa", [])

    in
        Svg.rect (
            List.append extraStyles
                [ Attributes.x <| String.fromInt (size * xr)
                , Attributes.y <| String.fromInt (size * yr)
                , Attributes.width <| String.fromInt size
                , Attributes.height <| String.fromInt size
                , Attributes.fill color
                ]
            ) []




drawRow : Orientation -> Int -> List Int -> Int -> List (Svg Msg)
drawRow orientation size xs y =

    List.map (drawBoardSquare size (mapXY orientation) y) xs

board : Orientation -> Int -> List (Svg Msg)
board orientation size =
    List.map (drawRow orientation size (List.range 0 9)) (List.range 0 3)
    |> List.concat



pusher : Int -> Int -> Int -> String -> List (Svg Msg)
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
            , Touch.onStart ( \e -> MouseDownAt (x*size + size//2 |> toFloat, y*size + size//2 |> toFloat) )
            ]
            []
        ]

mover : Int -> Int -> Int -> String -> List (Svg Msg)
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
            , Touch.onStart ( \e -> MouseDownAt (x*size + size//2 |> toFloat, y*size + size//2 |> toFloat) )
            ]
            []
        ]


anchor : Int -> Int -> Int -> List (Svg Msg)
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
