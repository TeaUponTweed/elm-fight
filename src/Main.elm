module Main exposing (init, update, view, Msg, Model)

--import Debug

import Dict exposing (Dict)
import Set exposing (Set)

import Browser
import Browser.Events
import Browser.Dom

import Html
import Html.Attributes
import Html.Events
import Html.Events.Extra.Mouse as Mouse

import Svg
import Svg.Attributes

import Task

import Json.Decode as Decode exposing (Decoder)
--import Json.Decode as Decode exposing (Decoder, decodeString, float, int, nullable, string)
import Json.Decode.Pipeline as DecodePipeline

import Json.Encode as Encode

import Draw
import PFTypes exposing (..)
import PFUtils exposing (doMove, doPush, isValidMove, isValidPush, isPositionInBoard)

type alias Model =
    { currentTurn : Turn
    , gameStage : GameStage
    , dragState : DragState
    , windowWidth : Int
    , gridSize : Int
    , endTurnOnPush : Bool
    }

main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }

moveWrapper : Move -> Board -> Board
moveWrapper {from, to} board =
    doMove board from to

getBoard : Model -> Board
getBoard model =
    let
        board =
            List.foldl moveWrapper model.currentTurn.startingBoard model.currentTurn.moves
    in
        case model.currentTurn.push of
            Just {from, to} ->
                doPush board from to
            Nothing ->
                board
getAnchor : Model -> Maybe Position
getAnchor model =
    case model.currentTurn.push of
        Just push ->
            let
                (x,y) = push.to
            in
                Just {x=x, y=y}

        Nothing ->
            model.currentTurn.startingBoard.anchor

-- subscriptions

position : Decode.Decoder Position
position =
    Decode.map2 Position
        (Decode.field "pageX" Decode.int)
        (Decode.field "pageY" Decode.int)

getWidthFromResize : Int -> Int -> Msg
getWidthFromResize width height =
    --WindowWidth (Debug.log "width" width)
    WindowWidth width

subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
    [ mouseSubsrciptions model
    , Browser.Events.onResize getWidthFromResize-- (Decode.map WindowWidth windowWidth)
    ]

mouseSubsrciptions : Model -> Sub Msg
mouseSubsrciptions model =
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


fromPxToGrid : Float -> Int -> Int
fromPxToGrid x gridSize =
    (floor x)//gridSize


view : Model -> Html.Html Msg
view model =
    let
        size = model.gridSize
        width = String.fromInt (10*size)
        height = String.fromInt (4*size)
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
                        , drawPiece size False ((getGridPos from mouseDrag model.gridSize), piece)
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
                    "WhiteTurn, " ++ String.fromInt(2 - List.length model.currentTurn.moves) ++ " moves left"
                BlackTurn ->
                    "BlackTurn, " ++ String.fromInt(2 - List.length model.currentTurn.moves) ++ " moves left"
                WhiteWon ->
                    "WhiteWon"
                BlackWon ->
                    "BlackWon"

    in
    Html.div []
    [ Html.div [] [Html.text title]
    , Html.div [Mouse.onDown (\event -> MouseDownAt event.offsetPos)]
        [ Svg.svg 
            [ Svg.Attributes.width width
            , Svg.Attributes.height height
            , Svg.Attributes.viewBox <| "0 0 " ++ width ++ " " ++ height
            ]
            ( List.concat
                [ Draw.board size
                , List.concat (List.map (drawPiece size False) <| Dict.toList board.pieces)
                , anchorSVGs
                , movingPiece
                ]
            )
        ]
    , Html.div []
        [ Html.button [ Html.Events.onClick EndTurn ] [ Html.text "End Turn" ]
        , Html.button [ Html.Events.onClick Undo ] [ Html.text "Undo" ]
        ]
    , Html.div []
        [ Html.label []
            [ Html.input [ Html.Attributes.type_ "checkbox", Html.Events.onClick ToggleEndTurnOnPush ] []
            , Html.text "End Turn on Push"
            ]
        ]
    ]

-- util

sign : Int -> Int
sign n =
    if n < 0 then
        -1
    else
        1

getGridPos : Position -> Maybe MouseDrag -> Int -> PositionKey
getGridPos {x, y} mouseDrag gridSize =
    case mouseDrag of
        Just {dragStart, dragCurrent} ->
            let
                dxpx =
                    (dragCurrent.x - dragStart.x)
                dypx =
                    (dragCurrent.y - dragStart.y)
                dx = ( (sign dxpx) * (abs dxpx + (gridSize // 2)) ) // gridSize
                dy = ( (sign dypx) * (abs dypx + (gridSize // 2)) ) // gridSize
            in
                ( x  + dx
                , y  + dy
                )
        Nothing ->
            ( x, y )
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
        --firstMoves = NoMoves startingPieces
        turn = Turn [] Nothing (Board startingPieces Nothing)
    in
        ( Model turn WhiteSetup NotDragging 1000 100 False
        , Task.perform (WindowWidth << getViewportWidth) Browser.Dom.getViewport
        )


getViewportWidth : Browser.Dom.Viewport -> Int
getViewportWidth {scene} =
    floor scene.width

-- UPDATE

type Msg
    = DragAt Position
    | DragEnd Position
    | MouseDownAt (Float, Float)
    | WindowWidth Int
    | EndTurn
    | Undo
    | ToggleEndTurnOnPush

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
            ( handleClick model (fromPxToGrid x model.gridSize, fromPxToGrid y model.gridSize)
            , Cmd.none
            )
        WindowWidth width ->
            ( { model | windowWidth = width, gridSize = width // 10 }
            , Cmd.none
            )
        ToggleEndTurnOnPush ->
            ( { model | endTurnOnPush = not model.endTurnOnPush }
            , Cmd.none
            )
        EndTurn ->
            let
                board =
                    getBoard model
                --anchor =
                    --getAnchor model
                nextTurn = Turn [] Nothing board
                    --case anchor of
                    --Just anchor ->
                    --    Turn [] Nothing board
                    --Nothing ->
                    --    Turn [] Nothing board
            in
                case model.gameStage of
                    WhiteSetup ->
                        ( { model | gameStage = BlackSetup, currentTurn = nextTurn }
                        , Cmd.none
                        )
                    BlackSetup ->
                        ( { model | gameStage = WhiteTurn, currentTurn = nextTurn }
                        , Cmd.none
                        )
                    WhiteTurn ->
                        case model.currentTurn.push of
                            Just push ->
                                ( { model | gameStage = turnTransition (getBoard model) model.gameStage, currentTurn = nextTurn }
                                , Cmd.none
                                )
                            Nothing ->
                                ( model, Cmd.none)
                    BlackTurn ->
                        case model.currentTurn.push of
                            Just push ->
                                ( { model | gameStage = turnTransition (getBoard model) model.gameStage, currentTurn = nextTurn }
                                , Cmd.none
                                )
                            Nothing ->
                                ( model, Cmd.none)
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
                Just push ->
                    let
                        turn =
                            model.currentTurn
                        updatedTurn =
                            { turn | push = Nothing }
                    in
                        ( { model | currentTurn = updatedTurn }
                        , Cmd.none
                        )
                Nothing ->
                    case model.currentTurn.moves of
                        [m1] ->
                            let
                                turn =
                                    model.currentTurn
                                updatedTurn =
                                    { turn | moves = [] }
                            in
                                ( { model | currentTurn = updatedTurn }
                                , Cmd.none
                                )
                        [m1, m2] ->
                            let
                                turn =
                                    model.currentTurn
                                updatedTurn =
                                    { turn | moves = [m1] }
                            in
                                ( { model | currentTurn = updatedTurn }
                                , Cmd.none
                                )
                        _ ->
                            ( model
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



move : Model -> (Int, Int) -> (Int, Int) -> Turn
move model from to =
    let
        board = getBoard model
        moves =
            case (isValidMove board model.gameStage from to, model.currentTurn.push) of
                (True, Nothing) ->
                    case model.currentTurn.moves of
                        [] -> [Move from to]
                        [m1] ->
                            if m1.to == from then
                                [Move m1.from to]
                            else
                                [m1, Move from to]
                        [m1, m2] ->
                            if m2.to == from then
                                [Move m2.from to]
                            else
                                case model.gameStage of
                                    BlackSetup  ->
                                        [m1, m2, Move from to]
                                    WhiteSetup  ->
                                        [m1, m2, Move from to]
                                    _ ->
                                        [m1, m2]
                        m ->
                            case model.gameStage of
                                BlackSetup ->
                                    m ++ [Move from to]
                                WhiteSetup ->
                                    m ++ [Move from to]
                                _ ->
                                    m
                            --model.currentTurn.moves
                _ ->
                    model.currentTurn.moves
        push = 
            case (isValidPush board model.gameStage from to, model.currentTurn.push) of
                (True, Nothing) ->
                    Just (Move from to)
                _ ->
                    model.currentTurn.push
    in
        { moves = moves
        , push = push
        , startingBoard = model.currentTurn.startingBoard
        }


handleDragEnd : Model -> Model
handleDragEnd model =
    case model.dragState of
        DraggingPiece {piece, from, mouseDrag} ->
            let
                (toX, toY) =
                    getGridPos from mouseDrag model.gridSize
                updatedTurn =
                    move model (from.x, from.y) (toX, toY)
                updatedModel =
                    { model | currentTurn = updatedTurn, dragState = NotDragging}
            in
                if model.endTurnOnPush then
                    case updatedTurn.push of
                        Just push ->
                            Tuple.first (update EndTurn updatedModel)
                        Nothing  ->
                            updatedModel
                else
                    updatedModel
        _ ->
            { model | dragState = NotDragging }

handleClick : Model -> PositionKey -> Model
handleClick model (x, y) =
    case Dict.get (x, y) (getBoard model).pieces of
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



pieceOutOfBoard : (PositionKey, Piece) -> Maybe Piece
pieceOutOfBoard (pos, piece) =
    if not (isPositionInBoard pos) then
        Just piece
    else
        Nothing

maybeGet : ( a -> b ) -> Maybe a -> Maybe b
maybeGet func maybe =
    case maybe of
        Just something ->
            Just (func something)
        Nothing ->
            Nothing


turnTransition : Board -> GameStage -> GameStage
turnTransition board gameStage =
    let
        offBoardPiece =
            board
            |> .pieces
            |> Dict.toList
            |> List.filterMap pieceOutOfBoard
            |> List.head
    in
        case maybeGet .color offBoardPiece of
            Just White ->
                BlackWon
            Just Black ->
                WhiteWon
            Nothing ->
                case gameStage of
                    BlackTurn ->
                        WhiteTurn
                    WhiteTurn ->
                        BlackTurn
                    _ ->
                        gameStage

type alias CodedMove =
    { from_x: Int
    , from_y: Int
    , to_x: Int
    , to_y: Int
    }

encodeMove: CodedMove -> Encode.Value
encodeMove cm =
    Encode.object
        [ ("from_x", Encode.int cm.from_x)
        , ("from_y", Encode.int cm.from_y)
        , ("to_x", Encode.int cm.to_x)
        , ("to_y", Encode.int cm.to_y)
        ]


encodeModel: Model -> Encode.Value
encodeModel model =
    let
        wasSetup =
            case model.gameStage of
                BlackSetup ->
                    True
                WhiteSetup ->
                    True
                _ ->
                    False
        wasWhitesTurn =
            case model.gameStage of
                WhiteTurn ->
                    True
                WhiteSetup ->
                    True
                _ ->
                    False
        --gameOver = case model.gameStage of
        --        WhiteWon ->
        --            True
        --        BlackWon ->
        --            True
        --        _ ->
        --            False

        board = model.currentTurn.startingBoard
        isPusher: (PositionKey, Piece) -> Bool
        isPusher (l,p) =
            case p.kind of
                Pusher ->
                    True
                Mover ->
                    False
        isMover: (PositionKey, Piece) -> Bool
        isMover (l,p) = not (isPusher (l,p))

        isWhite: (PositionKey, Piece) -> Bool
        isWhite (l,p) =
            case p.color of
                White ->
                    True
                Black ->
                    False
        isBlack: (PositionKey, Piece) -> Bool
        isBlack (l,p) = not (isWhite (l,p))

        wps =
            Dict.toList board.pieces
            |> List.filter isPusher
            |> List.filter isWhite
            |> List.map Tuple.first

        bps =
            Dict.toList board.pieces
            |> List.filter isPusher
            |> List.filter isBlack
            |> List.map Tuple.first

        wms =
            Dict.toList board.pieces
            |> List.filter isMover
            |> List.filter isWhite
            |> List.map Tuple.first

        bms =
            Dict.toList board.pieces
            |> List.filter isMover
            |> List.filter isBlack
            |> List.map Tuple.first
        keyToIx: (Int, Int) -> Int
        keyToIx (x, y) =
            10*y+x
        anc =
            case board.anchor of
                Just {x,y} ->
                    (x,y)
                    --pos
                Nothing ->
                    (0,0)
                    --{x=0,y=0}
        moveToCodedMove: Move -> CodedMove
        moveToCodedMove {from, to} =
            let
                (from_x, from_y) = from
                (to_x, to_y) = to
            in
                { from_x = from_x
                , from_y = from_y
                , to_x = to_x
                , to_y = to_y
                }
        pushes =
            case model.currentTurn.push of
                Just push ->
                    [push]
                Nothing ->
                    [] 
        codedMoves =
            model.currentTurn.moves ++ pushes
            |> List.map moveToCodedMove                



    in
        case ((wps, bps), (wms, bms)) of
            (([wp1, wp2, wp3], [bp1, bp2, bp3]), ([wm1, wm2], [bm1, bm2])) ->
                Encode.object
                    [ ("wp1", wp1 |> keyToIx |> Encode.int)
                    , ("wp2", wp2 |> keyToIx |> Encode.int)
                    , ("wp3", wp3 |> keyToIx |> Encode.int)
                    , ("wm1", wm1 |> keyToIx |> Encode.int)
                    , ("wm2", wm2 |> keyToIx |> Encode.int)
                    , ("bp1", bp1 |> keyToIx |> Encode.int)
                    , ("bp2", bp2 |> keyToIx |> Encode.int)
                    , ("bp3", bp3 |> keyToIx |> Encode.int)
                    , ("bm1", bm1 |> keyToIx |> Encode.int)
                    , ("bm2", bm2 |> keyToIx |> Encode.int)
                    , ("anc", anc |> keyToIx |> Encode.int)
                    , ("wasSetup",  Encode.bool wasSetup)
                    , ("wasWhitesTurn", Encode.bool wasWhitesTurn)
                    , ("moves", Encode.list encodeMove codedMoves)
                    --, ("gameOver", Encode.bool gameOver)
                    ]
            _ ->
                Encode.null



type alias DecodedBoard =
    { wp1 : Int
    , wp2 : Int
    , wp3 : Int
    , wm1 : Int
    , wm2 : Int
    , bp1 : Int
    , bp2 : Int
    , bp3 : Int
    , bm1 : Int
    , bm2 : Int
    , anchor : Int
    , wasSetup : Bool
    , wasWhitesTurn : Bool
    , moves: List CodedMove
    --, gameOver : Bool
    }

moveDecoder: Decode.Decoder CodedMove
moveDecoder =
    Decode.succeed CodedMove
        |> DecodePipeline.required "from_x" Decode.int
        |> DecodePipeline.required "from_y" Decode.int
        |> DecodePipeline.required "to_x" Decode.int
        |> DecodePipeline.required "to_y" Decode.int

modelDecoder: Decode.Decoder DecodedBoard
modelDecoder =
    Decode.succeed DecodedBoard
        |> DecodePipeline.required "wp1" Decode.int
        |> DecodePipeline.required "wp2" Decode.int
        |> DecodePipeline.required "wp3" Decode.int
        |> DecodePipeline.required "wm1" Decode.int
        |> DecodePipeline.required "wm2" Decode.int
        |> DecodePipeline.required "bp1" Decode.int
        |> DecodePipeline.required "bp2" Decode.int
        |> DecodePipeline.required "bp3" Decode.int
        |> DecodePipeline.required "bm1" Decode.int
        |> DecodePipeline.required "bm2" Decode.int
        |> DecodePipeline.required "anchor" Decode.int
        |> DecodePipeline.required "wasSetup" Decode.bool
        |> DecodePipeline.required "wasWhitesTurn" Decode.bool
        |> DecodePipeline.required "moves" (Decode.list moveDecoder)
        --|> DecodePipeline.required "gameOver" Decode.bool

updateModelFromDecode : Model -> DecodedBoard -> Model
updateModelFromDecode model decoded =
    let
        ixToKey: Int -> PositionKey
        ixToKey ix =
            (modBy ix 10, ix // 10)

        pieces =
            [ (decoded.wp1 |> ixToKey, Piece Pusher White)
            , (decoded.wp2 |> ixToKey, Piece Pusher White)
            , (decoded.wp3 |> ixToKey, Piece Pusher White)
            , (decoded.wm1 |> ixToKey, Piece Mover White)
            , (decoded.wm2 |> ixToKey, Piece Mover White)
            , (decoded.bp1 |> ixToKey, Piece Pusher Black)
            , (decoded.bp2 |> ixToKey, Piece Pusher Black)
            , (decoded.bp3 |> ixToKey, Piece Pusher Black)
            , (decoded.bm1 |> ixToKey, Piece Mover Black)
            , (decoded.bm2 |> ixToKey, Piece Mover Black)
            ]
            |> Dict.fromList

        codedMoveToMove: CodedMove -> Move
        codedMoveToMove {from_x, from_y, to_x, to_y} =
            { from = (from_x, from_y)
            , to = (to_x, to_y)
            }

        (moves, push) =
            case (List.map codedMoveToMove decoded.moves) of
                [m] ->
                    ([], Just m)
                [m1, m2] ->
                    ([m1], Just m2)
                [m1, m2, m3] ->
                    ([m1, m2], Just m3)
                _ ->
                    ([], Nothing)

        anchor =
            if decoded.anchor == 0 then
                Nothing
            else
                let
                    (x,y) = ixToKey decoded.anchor
                in
                    Just {x = x , y = y}
        board =
            Board pieces anchor

        gameStage =
            case (decoded.wasSetup, decoded.wasWhitesTurn) of
                (False, False) ->
                    BlackTurn
                (False, True) ->
                    WhiteTurn
                (True, False) ->
                    BlackSetup
                (True, True) ->
                    WhiteSetup


        turn =
            Turn moves push board
        decodedModel = 
            { model
            | currentTurn = turn
            , gameStage = gameStage
            }
        in
            update EndTurn decodedModel
            |> Tuple.first
