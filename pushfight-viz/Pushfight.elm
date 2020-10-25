module Pushfight exposing (init, update, view, Model, subscriptions, grabWindowWidth, checkForGameOver)

import Dict exposing (Dict)
import Set exposing (Set)

import Json.Decode as Decode

import Browser
import Browser.Events
import Browser.Dom

import Html
import Html.Attributes
import Html.Events
import Html.Events.Extra.Mouse as Mouse
import Html.Events.Extra.Touch as Touch

import Svg
import Svg.Attributes

import Task


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

touchCoordinates : Touch.Event -> ( Float, Float )
touchCoordinates touchEvent =
    List.head touchEvent.changedTouches
        |> Maybe.map .clientPos
        |> Maybe.withDefault ( 0, 0 )

touchPosition : Touch.Event -> Position
touchPosition touchEvent =
    let
        (x,y) = touchCoordinates touchEvent
    in
        {x=round x,y= round y}

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
    , Html.div
        [ Mouse.onDown ( \event -> (MouseDownAt event.offsetPos) )
        , Touch.onEnd ( DragEnd << touchPosition )
        , Touch.onCancel ( DragEnd << touchPosition )
        , Touch.onMove ( DragAt << touchPosition )
        ]
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

grabWindowWidth : () -> Cmd Msg
grabWindowWidth _ =
    Task.perform (WindowWidth << getViewportWidth) Browser.Dom.getViewport

init : Int -> ( Model, Cmd Msg )
init windowWidth =
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
        ( Model turn WhiteSetup NotDragging windowWidth (windowWidth//10) True
        , grabWindowWidth ()
        --, Cmd.none
        )


getViewportWidth : Browser.Dom.Viewport -> Int
getViewportWidth {scene} =
    floor scene.width

-- UPDATE

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
            ( handleClick model ( fromPxToGrid x model.gridSize, fromPxToGrid y model.gridSize )
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
                noop = ( model, Cmd.none)
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
                                noop
                    BlackTurn ->
                        case model.currentTurn.push of
                            Just push ->
                                ( { model | gameStage = turnTransition (getBoard model) model.gameStage, currentTurn = nextTurn }
                                , Cmd.none
                                )
                            Nothing ->
                                noop
                    WhiteWon ->
                        noop
                    BlackWon ->
                        noop
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

checkForGameOver : Board -> Maybe GameStage
checkForGameOver board =
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
                Just BlackWon
            Just Black ->
                Just WhiteWon
            Nothing ->
                Nothing

turnTransition : Board -> GameStage -> GameStage
turnTransition board gameStage =
    case checkForGameOver board of
        Just gameOver ->
            gameOver
        Nothing ->
            case gameStage of
                BlackTurn ->
                    WhiteTurn
                WhiteTurn ->
                    BlackTurn
                _ ->
                    gameStage
