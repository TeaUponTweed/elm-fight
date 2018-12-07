--import Browser
import Debug
import Dict exposing (Dict)
import Set exposing (Set)
--import Html
--import Html.Attributes
--import Html.Events exposing (on)
--import Html.Events.Extra.Mouse as Mouse
--import Json.Decode as Decode


import Browser
import Browser.Events
import Html
import Html.Events
import Html.Events.Extra.Mouse as Mouse
import Svg
import Svg.Attributes
import Json.Decode as Decode

import Draw




main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type PieceKind
    = Pusher
    | Mover



type PieceColor
    = Black
    | White


type Direction
    = Up
    | Left
    | Right
    | Down

type alias Piece =
    { kind : PieceKind
    , color : PieceColor
    }

type alias MovingPiece =
    { piece : Piece
    , from : Position
    , mouseDrag : Maybe MouseDrag
    }

type alias Position =
    { x : Int
    , y : Int
    }
    
type alias PositionKey = (Int, Int)

type alias Board =
    Dict PositionKey Piece

type alias MouseDrag =
    { dragStart   : Position
    , dragCurrent : Position
    }

type DragState
    = NotDragging
    | DraggingNothing MouseDrag
    | DraggingPiece MovingPiece
-- TODO store grid coordinates or pixels explicitly
type alias Model =
    { board : Board
    , dragState : DragState
    , anchor : Maybe Position
    }


init : () -> ( Model, Cmd Msg )
init _ =
    let
        startingPieces =
            [ ( (3, 2), Piece Mover  White )
            , ( (4, 0), Piece Pusher White )
            , ( (4, 1), Piece Mover  White )
            , ( (4, 2), Piece Pusher White )
            , ( (4, 3), Piece Pusher White )
            , ( (5, 0), Piece Pusher Black )
            , ( (5, 1), Piece Mover  Black )
            , ( (5, 2), Piece Pusher Black )
            , ( (5, 3), Piece Pusher Black )
            , ( (6, 2), Piece Mover  Black )
            ] |> Dict.fromList
    in
        ( Model startingPieces NotDragging Nothing
        , Cmd.none
        )



-- UPDATE


type Msg
    = DragAt Position
    | DragEnd Position
    | MouseDownAt (Float, Float)



update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        DragAt mousePos ->
            ( handleDrag model mousePos
            , Cmd.none
            )

        DragEnd mousePos ->
            ( handleDragEnd model
            , Cmd.none
            )

        MouseDownAt (x, y) ->
            ( handleClick model (fromPxToGrid x, fromPxToGrid y)
            , Cmd.none
            )

popPiece : PositionKey -> Board -> (Board, Maybe Piece)
popPiece key board = 
    case Dict.get key board of
        Just piece ->
            (Dict.remove key board, Just piece)
        Nothing ->
            (board, Nothing)

handleDrag : Model -> Position -> Model
handleDrag model mousePos =
    case model.dragState of
        NotDragging ->
            { model | dragState = DraggingNothing <| MouseDrag mousePos mousePos }

        DraggingNothing previousMouseDrag ->
            let
                updatedMouseDrag =
                    {previousMouseDrag | dragCurrent = mousePos}
            in
                { model | dragState = DraggingNothing updatedMouseDrag }

        DraggingPiece previousMovingPiece ->
            let
                updatedMouseDrag = case previousMovingPiece.mouseDrag of
                    Just {dragStart, dragCurrent} ->
                        MouseDrag dragStart mousePos
                    Nothing ->
                        MouseDrag mousePos mousePos
                updatedMovingPiece =
                    { previousMovingPiece | mouseDrag = Just  <| (Debug.log "drag pos: " updatedMouseDrag) }
            in
                { model | dragState = DraggingPiece updatedMovingPiece }


sign : Int -> Int
sign n =
    if n < 0 then
        -1
    else
        1

getGridPos : Position -> Maybe MouseDrag -> PositionKey
getGridPos {x, y} mouseDrag =
    case mouseDrag of
        Just {dragStart, dragCurrent} ->
            let
                dxpx =
                    (dragCurrent.x - dragStart.x)
                dypx =
                    (dragCurrent.y - dragStart.y)
                dx = ( (sign dxpx) * (abs dxpx + (grid_size // 2)) ) // grid_size
                dy = ( (sign dypx) * (abs dypx + (grid_size // 2)) ) // grid_size
            in
                ( x + (Debug.log "dx " dx)
                , y + (Debug.log "dy " dy)
                )
        Nothing ->
            ( x, y )

handleDragEnd : Model -> Model
handleDragEnd model =
    case model.dragState of
        DraggingPiece {piece, from, mouseDrag} ->
            let
                (toX, toY) = getGridPos from mouseDrag
            in
                case move model.board (from.x, from.y) (toX, toY) of
                    Just updatedBoard ->
                        { model | board = updatedBoard, dragState = NotDragging}
                    Nothing ->
                        { model | dragState = NotDragging }
        _ ->
            { model | dragState = NotDragging }

handleClick : Model -> PositionKey -> Model
handleClick model (x, y) =
    case Dict.get (x, y) model.board of
        Just piece ->
            case model.dragState of
                NotDragging ->
                    let
                        lastMovedPiece =
                            MovingPiece piece (Position x y) Nothing
                    in
                        { model | dragState = DraggingPiece lastMovedPiece }
                DraggingNothing previousMouseDrag ->
                    let
                        lastMovedPiece =
                            MovingPiece piece (Position x y) (Just previousMouseDrag)
                    in
                        { model | dragState = DraggingPiece lastMovedPiece }
                _ ->
                    model

        Nothing ->
            model


--isConnected : Position -> Position -> Bool
--isConnected pos1 pos2 =
--    abs(pos1.x - pos2.x) + (pos1.y - pos2.y) /= 1

isPositionInBoard : (Int, Int) -> Bool
isPositionInBoard (x, y) = 
    Draw.isInBoard x y

getNeighbors : PositionKey -> Set PositionKey
getNeighbors (x, y) = 
    List.filter
        isPositionInBoard
        [ ((x + 1),  y     )
        , ((x - 1),  y     )
        , ( x     , (y + 1))
        , ( x     , (y - 1))
        ]
    |> Set.fromList


breadthFirstSearchImpl : List PositionKey -> Set PositionKey -> List PositionKey -> Set PositionKey
breadthFirstSearchImpl unexplored occupied explored =
    case unexplored of
        [] ->
            Set.fromList explored
        x :: xs ->
            let
                neighbors = getNeighbors x
                unexploredNeighbors = Set.diff (Set.diff neighbors (Set.fromList explored)) occupied
                toExplore = unexploredNeighbors
                    |> Set.toList
                    |> List.append xs
            in
                breadthFirstSearchImpl toExplore occupied (x :: explored)


breadthFirstSearch : PositionKey -> Set PositionKey -> Set PositionKey
breadthFirstSearch start occupied =
    breadthFirstSearchImpl [start] occupied []

isValidMove : Board -> PositionKey -> PositionKey -> Bool
isValidMove board from to =
    if Dict.member to board then
        False
    else if not (Dict.member from board) then
        False
    else
        let
            occupied = Set.fromList <| Dict.keys board
            validMoves = breadthFirstSearch from occupied
        in
            Set.member to validMoves

getPushedPieces : Board -> PositionKey -> PositionKey -> List PositionKey -> List PositionKey
getPushedPieces board from to pushed =
    let
        (toX, toY) = to
        (fromX, fromY) = from
        dx = toX - fromX
        dy = toY - fromY
        next = (toX + dx, toY + dy)
        havePushed = to :: pushed
    in
        if Dict.member to board then
            getPushedPieces board to next havePushed
        else
            pushed

move : Board -> (Int, Int) -> (Int, Int) -> Maybe Board
move board from to =
    case Dict.get from board of
        Just piece ->
            if isValidMove board from to then
                Dict.remove from board
                |> Dict.insert to piece
                |> Just

            else
                Nothing
        Nothing ->
            Nothing



position : Decode.Decoder Position
position =
    Decode.map2 Position
        (Decode.field "pageX" Decode.int)
        (Decode.field "pageY" Decode.int)

subscriptions : Model -> Sub Msg
subscriptions model =
    case model.dragState of
        NotDragging ->
            Browser.Events.onMouseDown (Decode.map DragAt position)
        _ ->
            Sub.batch
                [ Browser.Events.onMouseMove (Decode.map DragAt position)
                , Browser.Events.onMouseUp (Decode.map DragEnd position)
                ]

drawPiece : Int -> Bool -> (PositionKey, Piece) -> List (Svg.Svg Msg)
drawPiece size isMoving ( (x, y), {kind, color} ) =
    let
        colorString =
            if isMoving then
                "#888888"
            else
                case color of
                    White ->
                        "#ffffff"
                    Black ->
                        "#000000"
    in
        case kind of
            Pusher ->
                Draw.pusher size x y colorString
            Mover ->
                Draw.mover size x y colorString

grid_size = 200

fromPxToGrid : Float -> Int
fromPxToGrid x =
    (floor x)//grid_size


view : Model -> Html.Html Msg
view model =
    let
        size = grid_size
        totalSize = String.fromInt (10*size)
        anchor =
            case model.anchor of
                Just {x, y} ->
                    Draw.anchor size x y
                Nothing ->
                    []
        movingPiece =
            case model.dragState of
                DraggingPiece {piece, from, mouseDrag} ->
                    List.concat
                        [ drawPiece size True ((from.x, from.y), piece)
                        , drawPiece size False ((getGridPos from mouseDrag), piece)
                        ]
                _ ->
                    []
    in
    Html.div [Mouse.onDown (\event -> MouseDownAt event.offsetPos)]
    [ Svg.svg 
        [ Svg.Attributes.width totalSize
        , Svg.Attributes.height totalSize
        , Svg.Attributes.viewBox <| "0 0 " ++ totalSize ++ " " ++ totalSize
        ]
        ( List.concat
            [ Draw.board size
            , List.concat (List.map (drawPiece size False) <| Dict.toList model.board)
            , anchor
            , movingPiece
            ]
        )
    ]
