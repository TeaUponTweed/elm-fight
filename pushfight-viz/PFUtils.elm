module PFUtils exposing (doMove, doPush, isValidMove, isValidPush, isPositionInBoard)

import Dict exposing (Dict)
import Set exposing (Set)

import PFTypes exposing (..)
import Draw


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
            if Dict.member to board.pieces then
                getPushedPieces board to next (to::pushed)
            else
                pushed

doMovePiece : Pieces -> (Int, Int) -> (Int, Int) -> Pieces
doMovePiece pieces from to =
    case Dict.get from pieces of
        Just piece ->
            Dict.remove from pieces
            |> Dict.insert to piece
        Nothing ->
            pieces

doPushPieces : Pieces -> (Int, Int) -> List PositionKey -> Pieces
doPushPieces pieces (dx, dy) piecesToPush =
    case piecesToPush of
        [] ->
            pieces
        (x, y) :: otherPieces ->
            doPushPieces (doMovePiece pieces (x, y) (x + dx, y + dy)) (dx, dy) otherPieces

type PushResult
    = ValidPush
    | InvalidPush
    | NotAdjacent
    | AgainstRails
    | ThroughAnchor
    | NotPusher

isValidPushImpl : Board -> List PositionKey -> Int -> Int -> PushResult
isValidPushImpl board pushedPieces dx dy =
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
                    case board.anchor of
                        Just anchorPos ->
                            if List.member (anchorPos.x, anchorPos.y) ((x, y) :: ps ) then
                                ThroughAnchor
                            else
                                ValidPush
                        Nothing ->
                            ValidPush
    else
        NotAdjacent

pushImpl : Board -> (Int, Int) -> (Int, Int) -> Maybe (Pieces, Position)
pushImpl board from to =
    let
        pushedPieces =
            getPushedPieces board from to [from]
        (toX, toY) = to
        (fromX, fromY) = from
        dx = toX - fromX
        dy = toY - fromY
    in
        case Dict.get from board.pieces of
            Just {kind} ->
                case kind of
                    Pusher ->
                        case isValidPushImpl board pushedPieces dx dy of
                            ValidPush ->
                                Just 
                                ( doPushPieces (board.pieces) (dx, dy) pushedPieces
                                , Position (fromX + dx) (fromY + dy)
                                )
                            _ ->
                                Nothing
                    Mover ->
                        Nothing
            Nothing ->
                Nothing

doPush : Board -> (Int, Int) -> (Int, Int) -> Board
doPush board from to =
    case pushImpl board from to of
        Just (pieces, anchor) ->
            { pieces = pieces
            , anchor = Just anchor
            }
        Nothing ->
            board

doMove : Board -> (Int, Int) -> (Int, Int) -> Board
doMove board from to =
    let
        fromPieceRes = Dict.get from board.pieces
        toPieceRes = Dict.get to board.pieces
    in
        case (fromPieceRes, toPieceRes) of
            (Just fromPiece, Nothing) ->
                { board
                | pieces = Dict.remove from board.pieces |> Dict.insert to fromPiece
                }
            (Just fromPiece, Just toPiece) ->
                doPush board from to
            _ ->
                board -- TODO panic!



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
        occupied = Set.fromList <| Dict.keys board.pieces
        validMoves = breadthFirstSearch from occupied
    in
        if Set.member to validMoves then
            ValidMove
        else
            Unreachable

isValidMoveImpl : Board -> GameStage -> PositionKey -> PositionKey -> MoveResult
isValidMoveImpl board gameStage from to =
    let
        --board = getBoard model
        pieceToMove = Dict.get from board.pieces
        (toX, toY) = to
    in
        if Dict.member to board.pieces then
            case gameStage of
                WhiteSetup ->
                    InvalidMove
                BlackSetup ->
                    InvalidMove
                _ ->
                    Occupied
        else
            case pieceToMove of
                Just {kind, color} ->
                    case (color, gameStage) of
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
                            if toX <= 4 && toX >= 0  && toY >= 0 && toY <= 3 then
                                ValidSetupMove
                            else
                                InvalidMove
                        (Black, BlackSetup) ->
                            if toX >= 5 && toX <= 10 && toY >= 0 && toY <= 3 then
                                ValidSetupMove
                            else
                                InvalidMove
                Nothing ->
                    NoPieceToMove


isValidMove : Board -> GameStage -> PositionKey -> PositionKey -> Bool
isValidMove board gameStage from to =
    case (isValidMoveImpl board gameStage from to, gameStage) of
        (ValidMove, WhiteTurn) ->
            True
        (ValidMove, BlackTurn) ->
            True
        (ValidSetupMove, WhiteSetup) ->
            True
        (ValidSetupMove, BlackSetup) ->
            True
        _ ->
            False

isValidPush : Board -> GameStage -> PositionKey -> PositionKey -> Bool
isValidPush board gameStage from to =
    case pushImpl board from to of
        Just _ ->
            case gameStage of
                WhiteTurn ->
                    True
                BlackTurn ->
                    True
                _ ->
                    False
        Nothing ->
            False
