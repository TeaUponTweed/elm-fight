import Debug

import Dict exposing (Dict)
import Set exposing (Set)

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

type Moves
    = NoMoves Board
    | OneMove (Board, Move)
    | TwoMoves (Board, Move, Move)

type Push
    = NotYetPushed Position
    | HavePushed (Board, Position, Position)
    | FirstPush (Board, Position)
    | BeforeFirstPush

type GameStage
    = WhiteSetup
    | BlackSetup
    | WhiteTurn
    | BlackTurn
    | WhiteWon
    | BlackWon

type alias Turn =
    { moves : Moves
    , push  : Push
    }

type DragState
    = NotDragging
    | DraggingNothing MouseDrag
    | DraggingPiece MovingPiece

type alias Model =
    { currentTurn : Turn
    , gameStage : GameStage
    , dragState : DragState
    }

getMoveBoard : Model -> Board
getMoveBoard model =
    case model.currentTurn.moves of
        NoMoves board->
            board
        OneMove (_, {board}) ->
            board
        TwoMoves (_, _, {board}) ->
            board

getBoard : Model -> Board
getBoard model =
    case model.currentTurn.push of
        HavePushed (board, _, _) ->
            board
        FirstPush (board, _) ->
            board
        BeforeFirstPush ->
            getMoveBoard model
        NotYetPushed _ ->
            getMoveBoard model

getAnchor : Model -> Maybe Position
getAnchor model =
    case model.currentTurn.push of
        HavePushed (_, _, anchorPos) ->
            Just anchorPos
        FirstPush (_, anchorPos) ->
            Just anchorPos
        NotYetPushed anchorPos ->
            Just anchorPos
        BeforeFirstPush ->
            Nothing

-- TODO
-- * store grid coordinates vs pixels explicitly
-- * Refactor board/piece movement to not allow invalid states

-- init

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
        ( Model turn WhiteSetup NotDragging
        , Cmd.none
        )

-- UPDATE

type Msg
    = DragAt Position
    | DragEnd Position
    | MouseDownAt (Float, Float)
    | EndTurn
    | Undo

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
        EndTurn ->
            let
                board =
                    getBoard model
                anchor =
                    getAnchor model
                nextTurn = case anchor of
                    Just anchorPos ->
                        Turn (NoMoves board) (NotYetPushed anchorPos)
                    Nothing ->
                        Turn (NoMoves board) BeforeFirstPush
            in
                case model.gameStage of
                    WhiteSetup ->
                        ( { model | gameStage = BlackSetup }
                        , Cmd.none
                        )
                    BlackSetup ->
                        ( { model | gameStage = WhiteTurn }
                        , Cmd.none
                        )
                    WhiteTurn ->
                        if gameOver model then
                            ( { model | gameStage = WhiteWon }
                            , Cmd.none
                            )
                        else
                            ( { model | gameStage = BlackTurn, currentTurn = nextTurn}
                            , Cmd.none
                            )
                    BlackTurn ->
                        if gameOver model then
                            ( { model | gameStage = BlackWon }
                            , Cmd.none
                            )
                        else
                            ( { model | gameStage = WhiteTurn, currentTurn = nextTurn}
                            , Cmd.none
                            )
                    WhiteWon ->
                        ( model
                        , Cmd.none
                        )
                    BlackWon ->
                        ( model
                        , Cmd.none
                        )
        Undo ->
            case model.currentTurn.push of
                HavePushed (_, lastAnchorPos, _) ->
                    let
                        turn =
                            model.currentTurn
                        updatedTurn =
                            { turn | push = NotYetPushed lastAnchorPos }
                    in
                        ( { model | currentTurn = updatedTurn }
                        , Cmd.none
                        )
                FirstPush _ ->
                    let
                        turn =
                            model.currentTurn
                        updatedTurn =
                            { turn | push = BeforeFirstPush }
                    in
                        ( { model | currentTurn = updatedTurn }
                        , Cmd.none
                        )
                _ ->
                    case model.currentTurn.moves of
                        NoMoves _ ->
                            ( model
                            , Cmd.none
                            )
                        OneMove (board, _) ->
                            let
                                turn =
                                    model.currentTurn
                                updatedTurn =
                                    { turn | moves = NoMoves board }
                            in
                                ( { model | currentTurn = updatedTurn }
                                , Cmd.none
                                )
                        TwoMoves (board, firstMove, _) ->
                            let
                                turn =
                                    model.currentTurn
                                updatedTurn =
                                    { turn | moves = OneMove (board, firstMove) }
                            in
                                ( { model | currentTurn = updatedTurn }
                                , Cmd.none
                                )

gameOver : Model -> Bool
gameOver model =
    let
        board = getBoard model
    in
        Dict.keys board
        |> List.all isPositionInBoard
        |> not


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


type MoveResult
    = ValidMove
    | ValidSetupMove
    | InvalidMove
    | NoPieceToMove
    | Occupied
    | Unreachable
    | WrongColor
    | GameOver

isReachable : Board -> PositionKey -> PositionKey -> MoveResult
isReachable board from to =
    let
        occupied = Set.fromList <| Dict.keys board
        validMoves = breadthFirstSearch from occupied
    in
        if Set.member to validMoves then
            ValidMove
        else
            Unreachable

isValidMove : Model -> PositionKey -> PositionKey -> MoveResult
isValidMove model from to =
    let
        board = getBoard model
        pieceToMove = Dict.get from board
        (toX, toY) = to
    in
        if Dict.member to board then
            case model.gameStage of
                WhiteSetup ->
                    InvalidMove
                BlackSetup ->
                    InvalidMove
                _ ->
                    Occupied
        else
            case pieceToMove of
                Just {kind, color} ->
                    case (color, model.gameStage) of
                        (Black, WhiteTurn) ->
                            WrongColor
                        (Black, WhiteSetup) ->
                            WrongColor
                        (White, BlackTurn) ->
                            WrongColor
                        (White, BlackSetup) ->
                            WrongColor
                        (_, WhiteWon) ->
                            GameOver
                        (_, BlackWon) ->
                            GameOver
                        (Black, BlackTurn) ->
                            isReachable board from to
                        (White, WhiteTurn) ->
                            isReachable board from to
                        (White, WhiteSetup) ->
                            if toX <= 4 then
                                ValidSetupMove
                            else
                                InvalidMove
                        (Black, BlackSetup) ->
                            if toX >= 5 then
                                ValidSetupMove
                            else
                                InvalidMove
                Nothing ->
                    NoPieceToMove



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
    case isValidMove model from to of
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
        ValidSetupMove ->
            let
                updatedBoard = doMovePiece (getBoard model) from to
                turn = model.currentTurn
            in
                { turn | moves = NoMoves updatedBoard}
        Occupied ->
            let
                currentTurn = model.currentTurn
            in
                case model.currentTurn.push of
                    HavePushed _ ->
                        Debug.log "Can't push twice" model.currentTurn -- TODO display banner "Can't push twice"
                    FirstPush _ ->
                        Debug.log "Can't push twice" model.currentTurn -- TODO display banner "Can't push twice"
                    NotYetPushed anchorPos ->
                        case push model from to of
                            Just (pushedBoard, newAnchorPos) ->
                                {currentTurn | push = HavePushed (pushedBoard, anchorPos,newAnchorPos)}
                            Nothing ->
                                Debug.log "Invalid Push" model.currentTurn -- TODO display banner "Invalid push"
                    BeforeFirstPush ->
                        case push model from to of
                            Just (pushedBoard, newAnchorPos) ->
                                {currentTurn | push = FirstPush (pushedBoard, newAnchorPos)}
                            Nothing ->
                                Debug.log "Invalid Push" model.currentTurn -- TODO display banner "Invalid push"
        _ ->
            Debug.log "Invalid move" model.currentTurn -- TODO display banner "Invalid move"

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
                if ((y + dy) < 0) || ((y + dy) > 3) then
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

-- subscriptions

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

-- view

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

grid_size = 100

fromPxToGrid : Float -> Int
fromPxToGrid x =
    (floor x)//grid_size


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
        title =
            case model.gameStage of
                WhiteSetup ->
                    "WhiteSetup"
                BlackSetup ->
                    "BlackSetup"
                WhiteTurn ->
                    "WhiteTurn"
                BlackTurn ->
                    "BlackTurn"
                WhiteWon ->
                    "WhiteWon"
                BlackWon ->
                    "BlackWon"
    in
    Html.div []
    [ Html.div [] [Html.text title]
    , Html.div [Mouse.onDown (\event -> MouseDownAt event.offsetPos)]
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
    , Html.div []
        [ Html.button [ Html.Events.onClick EndTurn ] [ Html.text "End Turn" ]
        , Html.button [ Html.Events.onClick Undo ] [ Html.text "Undo" ]
        ]
    ]

-- util

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

isPositionInBoard : (Int, Int) -> Bool
isPositionInBoard (x, y) = 
    Draw.isInBoard x y

getNeighbors : PositionKey -> Set PositionKey
getNeighbors (x, y) =
    List.filter
        isPositionInBoard
        [ (x + 1, y    )
        , (x - 1, y    )
        , (x    , y + 1)
        , (x    , y - 1)
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
