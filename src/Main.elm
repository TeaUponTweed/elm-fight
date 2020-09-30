port module Main exposing (updateBoardFromFirebase, getGamesFromFirebase, updateBoardToFirebase, createNewGame)

import Json.Decode as Decode
import Json.Encode as Encode
import Json.Decode.Pipeline as Pipeline

import Browser
import Browser.Navigation as Nav

import Html
import Html.Attributes as Attributes

import Debug

import List
import Dict

import Router
import Pushfight
import Lobby

port updateBoardFromFirebase : (Decode.Value -> msg) -> Sub msg
-- TODO only do this on request
port getGamesFromFirebase : (Decode.Value -> msg) -> Sub msg

port requestBoardFromFirebase : Decode.Value -> Cmd msg
port updateBoardToFirebase : Decode.Value -> Cmd msg
port createNewGame : Decode.Value -> Cmd msg

-- MAIN


main : Program () Model Msg
main =
    Browser.document
        { init = init
        , view = \model -> { title = "Pushfight in Elm", body = [view model] }
        , update = update
        , subscriptions = subscriptions
        }


-- MODEL


type alias Model =
    { lobby : Lobby.Model
    , board : Maybe Board.Model
    }


-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    firebaseSubscriptions model



-- VIEW


view : Model -> Html.Html Msg
view model =
    case model.board of
        Just Board board ->
            Html.div []
            [ Html.div [] [Html.button [ Html.Events.onClick RouterMsg Router.GoToLobby ] [ Html.text "Back to Lobby" ]]
            , Html.div [] [Html.map BoardMsg (Board.view board)]
            ]
        Nothing ->
            Html.map LobbyMsg (Lobby.view model.lobby)


-- INIT


init : () -> ( Model, Cmd Msg )
init _ =
    let
        (lobby, _, _) = Lobby.init ()
    in
        ( Model Lobby lobby
        , Cmd.none
        )



-- UPDATE



type Msg
    = RouterMsg Router.Msg
    | BoardMsg Pushfight.Msg
    | LobbyMsg Lobby.Msg
    | DecodeActiveGamesList Decode.Value
    | DecodeBoard Decode.Value

update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        RouterMsg msg ->
            case msg of
                Router.GoToLobby ->
                    ( {model | board = Nothing }
                    , Cmd.none
                    )
                Router.GoToGame gameID ->
                    ( model
                    , requestBoardFromFirebase (Encode.string gameID)
                    )
                Router.CreateNewGame ->
                    ( model
                    , createNewGame Encode.null
                    )
                DoNothing ->
                    ( model
                    , Cmd.none
                    )

        BoardMsg msg ->
            case model.board of
                Just board ->
                    stepBoard model (Board.update msg board)
                Nothing ->
                    ( model, Cmd.none )

        LobbyMsg msg ->
            stepLobby model (Lobby.update msg model.lobby)

        DecodeActiveGamesList gamesList ->
            case Decode.decodeValue decodeActiveGamesList gamesList of
                Ok decodedGamesList ->
                    let
                        lobby =
                            model.lobby
                        newLobby =
                            {lobby | currentGames = decodedGamesList}
                    in
                    ( { model | lobby = newLobby }
                    , Cmd.none
                    )
                Err err ->
                    ( model
                    , Cmd.none
                    )
        -- TODO let board handle it's own updating, don't reach in
        DecodeBoard codedBoard ->
            case Decode.decodeValue decodeBoard (Debug.log ("coded board: " ++ (Debug.toString codedBoard)) codedBoard) of
                Ok {board, gameID} ->
                    case model.board of
                        Just game ->
                            let
                                updatedGame =
                                    {game | board = board, gameID = gameID}
                            in
                                ( { model | board = Just updatedGame }
                                , Cmd.none
                                )

                        Nothing ->
                            let
                                (newGame, cmds, _) =
                                    Board.init gameID board
                            in
                                ( { model | board = Just newGame }
                                , Cmd.map BoardMsg cmds
                                )

                Err err ->
                    ( Debug.log ("failed to decode board: " ++ Debug.toString err)  model
                    , Cmd.none
                    )


-- TODO there is a scary logic hole if a router msg is returned, then encodeBoard -> firebase won't happen.
stepBoard : Model -> ( Board.Model, Cmd Board.Msg, Maybe Router.Msg ) -> ( Model, Cmd Msg )
stepBoard model ( b, cmds, routerMsg ) =
    let
        updatedModel =
            { model | board = Just b }
        boardUpdateCmd =
            updateBoardToFirebase (encodeGame b)
    in
    case routerMsg of
        Just rMsg ->
            let
                ( moreUpdatedModel, moreCmds ) =
                    update (RouterMsg (Just rMsg)) updatedModel
            in
                ( moreUpdatedModel
                , Cmd.batch [boardUpdateCmd, moreCmds]
                )
    
        Nothing ->
            ( updatedModel
            , boardUpdateCmd
            )


stepLobby : Model -> ( Lobby.Model, Cmd Lobby.Msg, Maybe Router.Msg ) -> ( Model, Cmd Msg )
stepLobby model (l, cmds, routerMsg) =
    let
        updatedModel = { lobby =  l, board = Nothing }
    in
        case routerMsg of
            Just rMsg ->
                update (RouterMsg (Just rMsg)) updatedModel
            Nothing ->
                ( updatedModel
                , (Cmd.map LobbyMsg cmds)
                )


decodeActiveGamesList : Decode.Decoder (List String)
decodeActiveGamesList = 
    Decode.list Decode.string


firebaseSubscriptions : Model -> Sub Msg
firebaseSubscriptions model =
    Sub.batch
        [ getGamesFromFirebase DecodeActiveGamesList
        , updateBoardFromFirebase DecodeBoard
        ]


type alias DecodedBoard =
    { wp1          : Int
    , wp2          : Int
    , wp3          : Int
    , wm1          : Int
    , wm2          : Int
    , bp1          : Int
    , bp2          : Int
    , bp3          : Int
    , bm1          : Int
    , bm2          : Int
    , anchor       : Maybe Int
    , move1from    : Maybe Int
    , move1to      : Maybe Int
    , move2from    : Maybe Int
    , move2to      : Maybe Int
    , pushFrom     : Maybe Int
    , pushTo       : Maybe Int
    , gameID       : String
    , isSetup      : Bool
    , isWhitesTurn : Bool
    }


decodeBoard : Decode.Decoder DecodedBoard
decodeBoard = 
    Decode.succeed ProperBoard
        |> Pipeline.required "wp1"          Decode.int
        |> Pipeline.required "wp2"          Decode.int
        |> Pipeline.required "wp3"          Decode.int
        |> Pipeline.required "wm1"          Decode.int
        |> Pipeline.required "wm2"          Decode.int
        |> Pipeline.required "bp1"          Decode.int
        |> Pipeline.required "bp2"          Decode.int
        |> Pipeline.required "bp3"          Decode.int
        |> Pipeline.required "bm1"          Decode.int
        |> Pipeline.required "bm2"          Decode.int
        |> Pipeline.optional "anchor"       Decode.int Nothing
        |> Pipeline.optional "move1from"    Decode.int Nothing
        |> Pipeline.optional "move1to"      Decode.int Nothing
        |> Pipeline.optional "move2from"    Decode.int Nothing
        |> Pipeline.optional "move2to"      Decode.int Nothing
        |> Pipeline.optional "pushFrom"     Decode.int Nothing
        |> Pipeline.optional "pushTo"       Decode.int Nothing
        |> Pipeline.required "gameID"       Decode.string
        |> Pipeline.required "isSetup"      Decode.bool
        |> Pipeline.required "isWhitesTurn" Decode.bool


indexToXY : Int -> (Int, Int)
indexToXY ix =
    (modBy ix 10, ix // 10)


xyToIndex : (Int, Int) -> Int
xyToIndex (x, y) =
    x + y * 10


posToIndex : Position -> Int
posToIndex {x, y} =
    x + y * 10


decodedBoardToBoard : DecodedBoard -> Board
decodedBoardToBoard decodedBoard =
    let
        board =
            Dict.empty
            |> Dict.insert (indexToXY decodedBoard.wp1) Piece Pusher White 
            |> Dict.insert (indexToXY decodedBoard.wp2) Piece Pusher White 
            |> Dict.insert (indexToXY decodedBoard.wp3) Piece Pusher White 
            |> Dict.insert (indexToXY decodedBoard.wm1) Piece Mover  White 
            |> Dict.insert (indexToXY decodedBoard.wm2) Piece Mover  White 
            |> Dict.insert (indexToXY decodedBoard.bp1) Piece Pusher Black 
            |> Dict.insert (indexToXY decodedBoard.bp2) Piece Pusher Black 
            |> Dict.insert (indexToXY decodedBoard.bp3) Piece Pusher Black 
            |> Dict.insert (indexToXY decodedBoard.bm1) Piece Mover  Black 
            |> Dict.insert (indexToXY decodedBoard.bm2) Piece Mover  Black 
        move =
            case (decodedBoard.move1from, decodedBoard.move1to, decodedBoard.move2from, decodedBoard.move2to) of
                (Some m1from, Some m1to, Some m2from, Some m2to) ->
                    TwoMoves(board, Move(m1from, m1to), Move(m2from, m2to))
                (Some m1from, Some m1to, Nothing, Nothing)
                    OneMove(board, Move(m1from, m1to))
                _ ->
                    NoMoves board
        push = HavePushed()
                --(Nothing, Nothing, Nothing, Nothing)
    in


encodeBoardImpl : List ((Int, Int), (Pushfight.Piece)) -> Dict String Int -> Int -> Int -> Int -> Int -> Dict String Int
encodeBoardImpl pieces transformedBoard blackMoverCounter whiteMoverCounter whitePusherCounter blackPusherCounter =
    case pieces of
        [((x, y), {piece, kind}] :: otherPieces ->
            let
                (name, updatedblackMoverCounter, updatedwhiteMoverCounter, updatedwhitePusherCounter, updatedblackPusherCounter) =
                    case (piece, kind) of
                        (Black, Pusher) ->
                            ( "bp" ++ <| String.fromInt <| blackPusherCounter + 1
                            , blackMoverCounter, whiteMoverCounter, whitePusherCounter, blackPusherCounter + 1
                            )
                        (White, Pusher) ->
                            ( "wp" ++ <| String.fromInt <| whitePusherCounter + 1
                            , blackMoverCounter, whiteMoverCounter, whitePusherCounter + 1, blackPusherCounter
                            )
                        (Black, Mover) ->
                            ( "bm" ++ <| String.fromInt <| blackMoverCounter + 1
                            , blackMoverCounter + 1, whiteMoverCounter, whitePusherCounter, blackPusherCounter
                            )
                        (White, Mover) ->
                            ( "wm" ++ <| String.fromInt <| whiteMoverCounter + 1
                            , blackMoverCounter, whiteMoverCounter + 1, whitePusherCounter, blackPusherCounter
                            )
                pos =
                    x+y*10
            in
                encodeBoardImpl 
                    <| otherPieces
                    <| Dict.insert transformedBoard name pos
                    <| blackMoverCounter
                    <| updatedblackMoverCounter updatedwhiteMoverCounter updatedwhitePusherCounter updatedblackPusherCounter


encodeGame : Board.Model -> String -> Encode.Value
encodeGame game gameId=
    let
        encodedBoard =
            encodeBoardImpl (Dict.toList getBoard game) Dict.empty 0 0 0 0
        moveList =
            case game.turn.moves of
                NoMoves ->
                    []
                OneMove (_, {from, to}) ->
                    [ ("move1from", Encode.int <| xyToIndex from)
                    , ("move1to"  , Encode.int <| xyToIndex to)
                    ]
                TwoMoves (_, move1, move2) ->
                    [ ("move1from", Encode.int <| xyToIndex move1.from)
                    , ("move1to"  , Encode.int <| xyToIndex move1.to)
                    , ("move2from", Encode.int <| xyToIndex move2.from)
                    , ("move2to"  , Encode.int <| xyToIndex move2.to)
                    ]
        pushList =
            case game.turn.push of
                FirstPush {board, anchorPos, from, to} ->
                    [ ("pushFrom", Encode.int <| xyToIndex from)
                    , ("pushTo"  , Encode.int <| xyToIndex to)
                    , ("anchor"  , Encode.int <| xyToIndex anchorPos)
                    , ("isSetup" , False)
                    ]
                HavePushed {board, anchorPos, from, to} ->
                    [ ("pushFrom", Encode.int <| xyToIndex from)
                    , ("pushTo"  , Encode.int <| xyToIndex to)
                    , ("anchor"  , Encode.int <| xyToIndex anchorPos)
                    , ("isSetup" , Encode.bool False)
                    ]
                BeforeFirstPush ->
                    [ ("isSetup", Encode.bool True)
                    ]
                NotYetPushed -> -- We shoudn't be here (maybe this should live in some sort of interface layer, bleh)
                    []
        turnList =
            case game.gameStage of
                WhiteSetup ->
                    [ ("isWhitesTurn", Encode.bool True)
                    ]
                BlackSetup ->
                    [ ("isWhitesTurn", Encode.bool False)
                    ]
                WhiteTurn ->
                    [ ("isWhitesTurn", Encode.bool True)
                    ]
                BlackTurn ->
                    [ ("isWhitesTurn", Encode.bool False)
                    ]
                WhiteWon ->
                    [ ("isWhitesTurn", encode.bool True)
                    ]
                BlackWon ->
                    [ ("isWhitesTurn", encode.bool False)
                    ]
    in
        
    Encode.object
            <| encodedBoard ++ pushList ++ turnList ++ [ ("gameID"      , gameID) ]
