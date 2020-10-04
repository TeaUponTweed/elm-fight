module PushfightCoding exposing (encodePushfight, decodePushfight, pushfightDecoderImpl)

import Dict exposing (Dict)
import Json.Decode as Decode exposing (Decoder)
--import Json.Decode as Decode exposing (Decoder, decodeString, float, int, nullable, string)
import Json.Decode.Pipeline as DecodePipeline

import Json.Encode as Encode


import PFTypes exposing (..)
import Pushfight exposing (Model, checkForGameOver)

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


encodePushfight: String -> Model -> Encode.Value
encodePushfight gameID model =
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
        --pushes =
        --    case model.currentTurn.push of
        --        Just push ->
        --            [push]
        --        Nothing ->
        --            [] 
        codedMoves = model.currentTurn.moves |> List.map moveToCodedMove



    in
        case ((wps, bps), (wms, bms)) of
            (([wp1, wp2, wp3], [bp1, bp2, bp3]), ([wm1, wm2], [bm1, bm2])) ->
                Encode.object (
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
                    , ("gameID", Encode.string gameID)
                    ] ++ case model.currentTurn.push of
                        Just push ->
                            [("push", moveToCodedMove push |> encodeMove)]
                        Nothing ->
                            [("push", Encode.null)]
                    )
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
    , push: Maybe CodedMove
    , gameID : String
    }

moveDecoder: Decode.Decoder CodedMove
moveDecoder =
    Decode.succeed CodedMove
        |> DecodePipeline.required "from_x" Decode.int
        |> DecodePipeline.required "from_y" Decode.int
        |> DecodePipeline.required "to_x" Decode.int
        |> DecodePipeline.required "to_y" Decode.int

pushfightDecoderImpl: Decode.Decoder DecodedBoard
pushfightDecoderImpl =
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
        |> DecodePipeline.required "anc" Decode.int
        |> DecodePipeline.required "wasSetup" Decode.bool
        |> DecodePipeline.required "wasWhitesTurn" Decode.bool
        |> DecodePipeline.required "moves" (Decode.list moveDecoder)
        |> DecodePipeline.required "push" (Decode.nullable moveDecoder)
        |> DecodePipeline.required "gameID" Decode.string

splitLast: List a -> (List a, Maybe a)
splitLast l =
    --let
    --    r = 
    --    --h, t = List.tail r
    --in
    case List.reverse l of
        [] ->
            ([], Nothing)
        [x] ->
            ([], Just x)
        x :: xs ->
            (List.reverse xs, Just x)

decodePushfight : Int -> Int -> Bool -> DecodedBoard -> Model
decodePushfight windowWidth gridSize endTurnOnPush decoded =
    let
        ixToKey: Int -> PositionKey
        ixToKey ix =
            (modBy 10 ix, ix // 10)

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

        --(moves, push) = (, Nothing)
        anchor =
            if decoded.anchor == 0 then
                Nothing
            else
                let
                    (x,y) = ixToKey decoded.anchor
                in
                    Just {x = x , y = y}
        moves = List.map codedMoveToMove decoded.moves
        push = Maybe.map codedMoveToMove decoded.push

        --(moves, push) =
        --    case List.map codedMoveToMove decoded.moves |> splitLast of
        --        (someMoves, Just lastMove) ->
        --            case anchor of
        --                Just {x, y} ->
        --                    let
        --                        (tox, toy) = lastMove.to
        --                    in
        --                        if x == tox && y == toy then
        --                            (someMoves, Just lastMove)
        --                        else
        --                            (someMoves ++ [lastMove], Nothing)
        --                Nothing ->
        --                    (someMoves ++ [lastMove], Nothing)
        --        (someMoves, Nothing) ->
        --            (someMoves, Nothing)

        --    case (List.map codedMoveToMove decoded.moves) of
        --        [m] ->
        --            ([], Just m)
        --        [m1, m2] ->
        --            ([m1], Just m2)
        --        [m1, m2, m3] ->
        --            ([m1, m2], Just m3)
        --        _ ->
        --            ([], Nothing)


        board =
            Board pieces anchor

        gameStage =
            case checkForGameOver board of
                Just gameOver ->
                    gameOver
                Nothing ->
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
        in
            { windowWidth = windowWidth
            , gridSize = gridSize
            , endTurnOnPush = endTurnOnPush
            , currentTurn = turn
            , dragState = NotDragging
            , gameStage = gameStage
            }

            --update EndTurn decodedModel
            --|> Tuple.first
--decodePushfight: Int -> Int -> Bool -> DecodedBoard -> Model
--decodePushfight windowWidth gridSize endTurnOnPush decodedBoard  =
    --decodedBoard
    --case modelDecoder json of
    --    Ok decodedModel ->
    --        Ok (updateModelFromDecode windowWidth gridSize endTurnOnPush decodedModel)
    --    Err e ->
    --        Err "Failed to decode"
