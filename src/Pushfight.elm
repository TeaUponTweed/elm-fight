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

type alias Move =
    { board : Board
    , lastMovedPiece : PositionKey
    }

--type alias NoMoves =
--        { initialBoard: Board
--        }
--type alias OneMove =
--        { initialBoard: Board
--        , firstBoard : Board
--        , firstMoved : PositionKey
--        }
--type alias TwoMoves =
--        { initialBoard: Board
--        , firstBoard : Board
--        , firstMoved : PositionKey
--        , secondBoard : Board
--        , secondMoved : PositionKey
--        }
type Moves
    = NoMoves Board
    | OneMove (Board, Move)
    | TwoMoves (Board, Move, Move)

type Push
    = NotYetPushed Position
    | HavePushed (Board, Position)
    | BeforeFirstPush


type alias Turn =
    { moves : Moves
    , push  : Push
    }

type DragState
    = NotDragging
    | DraggingNothing MouseDrag
    | DraggingPiece MovingPiece
-- TODO
-- * store grid coordinates vs pixels explicitly
-- * Refactor board/piece movement to not allow invalid states

type alias Model =
    { currentTurn : Turn
    , dragState : DragState
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
        firstMoves = NoMoves startingPieces
        turn = Turn firstMoves BeforeFirstPush
    in
        ( Model turn NotDragging
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
                    { previousMovingPiece | mouseDrag = Just updatedMouseDrag }
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
                ( x  + dx
                , y  + dy
                )
        Nothing ->
            ( x, y )

handleDragEnd : Model -> Model
handleDragEnd model =
    case model.dragState of
        DraggingPiece {piece, from, mouseDrag} ->
            let
                (toX, toY) = getGridPos from mouseDrag
                updatedTurn = move model (from.x, from.y) (toX, toY)
            in
                { model | currentTurn = updatedTurn, dragState = NotDragging}
        _ ->
            { model | dragState = NotDragging }

handleClick : Model -> PositionKey -> Model
handleClick model (x, y) =
    case Dict.get (x, y) (getBoard model) of
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
                breadthFirstSearchImpl (Debug.log "toExplore: " toExplore) occupied (x :: explored)


breadthFirstSearch : PositionKey -> Set PositionKey -> Set PositionKey
breadthFirstSearch start occupied =
    breadthFirstSearchImpl [start] occupied []

type MoveResult
    = ValidMove
    | NoPieceToMove
    | Occupied
    | Unreachable


isValidMove : Board -> PositionKey -> PositionKey -> MoveResult
isValidMove board from to =
    if Dict.member to board then
        Occupied
    else if not (Dict.member from board) then
        NoPieceToMove
    else
        let
            occupied = Set.fromList <| Dict.keys board
            validMoves = breadthFirstSearch from occupied
        in
            if Set.member to validMoves then
                ValidMove
            else
                Unreachable

getPushedPieces : Board -> PositionKey -> PositionKey -> List PositionKey -> List PositionKey
getPushedPieces board from to pushed =
    let
        (toX, toY) = to
        (fromX, fromY) = from
        dx = toX - fromX
        dy = toY - fromY
        next = (toX + dx, toY + dy)
    in
        if dx == 0 && dy == 0 then
            pushed
        else
            if Dict.member to board then
                getPushedPieces board to next (to::pushed)
            else
                pushed

doMovePiece : Board -> (Int, Int) -> (Int, Int) -> Board
doMovePiece board from to =
    case Dict.get from board of
        Just piece ->
            Dict.remove from board
            |> Dict.insert to piece
        Nothing ->
            board

move : Model -> (Int, Int) -> (Int, Int) -> Turn
move model from to =
    case isValidMove (getBoard model) from to of
        ValidMove ->
            let
                updatedBoard = doMovePiece (getBoard model) from to
                turn = model.currentTurn
            in
                case model.currentTurn.push of
                    HavePushed _->
                        Debug.log "Can't move after pushing" model.currentTurn -- TODO display banner "Can't move after pushing"
                    _ ->
                        case turn.moves of
                            NoMoves initialBoard ->
                                {turn | moves = OneMove (initialBoard, Move updatedBoard to) }
                            OneMove (initialBoard, {board, lastMovedPiece}) ->
                                if from == lastMovedPiece then
                                    {turn | moves = OneMove (initialBoard, Move updatedBoard to) }
                                else
                                    {turn | moves = TwoMoves (initialBoard, Move board lastMovedPiece, Move updatedBoard to) }
                            TwoMoves (initialBoard, firstMove, {board, lastMovedPiece}) ->
                                if from == lastMovedPiece then
                                    {turn | moves = TwoMoves (initialBoard, firstMove, Move updatedBoard to) }
                                else
                                    Debug.log "Too may moves" model.currentTurn -- TODO display banner "Too many moves"
        Occupied ->
            let
                currentTurn = model.currentTurn
            in
                case model.currentTurn.push of
                    HavePushed _ ->
                        Debug.log "Can't push twice" model.currentTurn -- TODO display banner "Can't push twice"
                    _ ->
                        case push model from to of
                            Just (pushedBoard, newAnchorPos) ->
                                {currentTurn | push = HavePushed (pushedBoard, newAnchorPos)}
                            Nothing ->
                                Debug.log "Invalid Push" model.currentTurn -- TODO display banner "Invalid push"


        _ ->
            Debug.log "Invalid move" model.currentTurn -- TODO display banner "Invalid move"


doPushPieces : Board -> (Int, Int) -> List PositionKey -> Board
doPushPieces board (dx, dy) piecesToPush =
    case piecesToPush of
        [] ->
            board
        (x, y) :: pieces ->
            doPushPieces (doMovePiece board (x, y) (x + dx, y + dy)) (dx, dy) pieces

type PushResult
    = ValidPush
    | InvalidPush
    | NotAdjacent
    | AgainstRails
    | ThroughAnchor
    | NotPusher

isValidPush : Model -> List PositionKey -> Int -> Int -> PushResult
isValidPush model pushedPieces dx dy =
    if (abs dx) + (abs dy) == 1 then
        case pushedPieces of
            [] ->
                NotPusher
            [ p ] ->
                NotAdjacent
            (x, y) :: ps ->
                if ((Debug.log "dy-" (y + dy)) < 0) || ((y + dy) > 3) then
                    AgainstRails
                else
                    case getAnchor model of
                        Just anchorPos ->
                            if List.member (anchorPos.x, anchorPos.y) ((x, y) :: ps ) then
                                ThroughAnchor
                            else
                                ValidPush
                        Nothing ->
                            ValidPush
    else
        NotAdjacent

push : Model -> (Int, Int) -> (Int, Int) -> Maybe (Board, Position)
push model from to =
    let
        pushedPieces =
            getPushedPieces (getBoard model) from to [from]
        (toX, toY) = to
        (fromX, fromY) = from
        dx = toX - fromX
        dy = toY - fromY
    in
        case Dict.get from (getBoard model) of
            Just {kind} ->
                case kind of
                    Pusher ->
                        case isValidPush model pushedPieces dx dy of
                            ValidPush ->
                                Just 
                                ( doPushPieces (getBoard model) (dx, dy) pushedPieces
                                , Position (fromX + dx) (fromY + dy)
                                )
                            _ ->
                                Nothing
                    Mover ->
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


getBoard : Model -> Board
getBoard model =
    case model.currentTurn.push of
        HavePushed (board, anchorPos) ->
            board
        _ ->
            case model.currentTurn.moves of
                NoMoves board->
                    board
                OneMove (_, {board}) ->
                    board
                TwoMoves (_, _, {board}) ->
                    board

getAnchor : Model -> Maybe Position
getAnchor model =
    case model.currentTurn.push of
        HavePushed (_, anchorPos) ->
            Just anchorPos
        NotYetPushed anchorPos ->
            Just anchorPos
        BeforeFirstPush ->
            Nothing


view : Model -> Html.Html Msg
view model =
    let
        size = grid_size
        totalSize = String.fromInt (10*size)
        board = getBoard model
        anchor = getAnchor model
        anchorSVGs =
            case anchor of
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
            , List.concat (List.map (drawPiece size False) <| Dict.toList board)
            , anchorSVGs
            , movingPiece
            ]
        )
    ]
