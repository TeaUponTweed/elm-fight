port module Main exposing (..)

import Browser
--import Debug
import Json.Decode as D
import Json.Encode as E
import Html exposing (Html, button, div, text, input)
import Html.Attributes exposing (placeholder, value)
import Html.Events exposing (onClick, onInput)

import Pushfight
import PFTypes
import PushfightCoding exposing (encodePushfight, decodePushfight, pushfightDecoderImpl)

port requestNewGame : String -> Cmd msg
port receiveNewGame : (String -> msg) -> Sub msg

port requestJoinGame : String -> Cmd msg

port receiveConnectionLost : (String -> msg) -> Sub msg

port sendPushfight : E.Value -> Cmd msg
port receivePushfight : (D.Value -> msg) -> Sub msg

port notifyExit : () -> Cmd msg

type alias Flags =
    { windowWidth : Int }

type alias Game =
    { gameID: String
    , pushfight: Pushfight.Model
    }

type Msg
    = TryNewGame  
    | TryJoinGame
    | ConnectionLost String
    | StartNewGame String
    | UpdateNewGameID String
    | UpdateJoinGameID String
    | PushfightFromServer Game
    | ExitGame
    | PushfightMsg PFTypes.Msg
    | NoOp

type alias Model =
    { game: Maybe Game
    , newGameID: String
    , joinGameID: String
    , windowWidth: Int
    }

view : Model -> Html Msg
view model =
    case model.game of
        Just game ->
            div []
                [ div [] [ "Game ID = " ++ game.gameID |> text]
                , div [] [ Pushfight.view game.pushfight |> Html.map PushfightMsg ]
                , div [] [ button [ onClick ExitGame ] [ text "Leave Game" ] ]
                ]
        Nothing ->
          div []
            [ div []
                [ input [ placeholder "New Game ID", value model.newGameID, onInput UpdateNewGameID ] []
                , button [ onClick TryNewGame ] [ text "Start New Game" ]
                ]
            , div []
                [ input [ placeholder "Join Game ID", value model.joinGameID, onInput UpdateJoinGameID ] []
                , button [ onClick TryJoinGame ] [ text "Join Game" ]
                ]
            ]


init : Flags -> ( Model, Cmd Msg )
init {windowWidth} =
    ( { game = Nothing , newGameID = "", joinGameID = "", windowWidth = windowWidth}
    , Cmd.none
    )

boardChange: Pushfight.Model -> Pushfight.Model -> Bool
boardChange m1 m2 =
    (m1.currentTurn /= m2.currentTurn) || (m1.gameStage /= m2.gameStage)

update: Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        noop = ( model, Cmd.none)
    in
        case msg of
            TryNewGame ->
                if String.length model.newGameID > 0 then
                    ( model
                    , requestNewGame model.newGameID
                    )
                else
                    noop
            StartNewGame gameID ->
                    let
                        (pushfight, cmdMsg) = Pushfight.init model.windowWidth
                        game = { gameID = gameID, pushfight = pushfight}
                    in
                        ( { model | game = Just game}
                        , Cmd.batch
                            [ Cmd.map PushfightMsg cmdMsg
                            , encodePushfight game.gameID pushfight |> sendPushfight
                            ]
                        )
            TryJoinGame ->
                if String.length model.joinGameID > 0 then
                    case model.game of
                        Just _ ->
                            noop
                        Nothing ->
                            ( model
                            , requestJoinGame model.joinGameID
                            )
                else
                    noop
            ExitGame ->
                ( { model | game = Nothing }
                , notifyExit ()
                )
            UpdateNewGameID gameID ->
                ( { model | newGameID = gameID }
                , Cmd.none
                )
            UpdateJoinGameID gameID ->
                ( { model | joinGameID = gameID }
                , Cmd.none
                )
            ConnectionLost _ ->
                ( { model | game = Nothing}
                , Cmd.none
                )
            PushfightMsg pfmsg ->
                case model.game of
                    Just game ->
                        let
                            (updatedPushfight, cmdMsg) = Pushfight.update pfmsg game.pushfight
                            sndUpdateCmdMsg =
                                if boardChange updatedPushfight game.pushfight then --pushfight /= game.pushfight then
                                    [encodePushfight game.gameID updatedPushfight |> sendPushfight]
                                else
                                    []

                        in
                            ( { model | game = Just { pushfight = updatedPushfight, gameID = game.gameID } }
                            , [Cmd.map PushfightMsg cmdMsg] ++ sndUpdateCmdMsg |> Cmd.batch
                            )
                    Nothing ->
                        noop
            PushfightFromServer game ->
                case model.game of
                    Just _ ->
                        ( { model | game = Just game}
                        , Cmd.none
                        )
                    Nothing ->
                        ( { model | game = Just game}
                        , Pushfight.grabWindowWidth () |> Cmd.map PushfightMsg
                        )
                --case decodePushfight codedPushfight of
                --    Ok (gameID, pushfight) ->
                --        ( { model | game = Just {gameID = gameID, pushfight = pushfight} }
                --        , Pushfight.grabWindowWidth ()
                --        )
                --    Err err ->
                --        Debug.log err noop
            NoOp ->
                noop
--windowWidth
--gridSize
--endTurnOnPush
mapPushFightDecode: Int -> Int -> Bool -> D.Value -> Msg
mapPushFightDecode windowWidth gridSize endTurnOnPush json = 
--decodePushfight windowWidth gridSize endTurnOnPush decodedBoard  =
    --decodedBoard
    case D.decodeValue pushfightDecoderImpl json of
        Ok pushfight ->
            PushfightFromServer
            { pushfight = (decodePushfight windowWidth gridSize endTurnOnPush pushfight)
            , gameID = pushfight.gameID
            }
        Err e ->
            NoOp
            --Debug.log "Failed to parse board" NoOp

mapNewGameDecode: D.Value -> Msg
mapNewGameDecode json =
    case D.decodeValue D.string json of
        Ok gameID ->
            StartNewGame gameID
        Err e ->
            NoOp
            --Debug.log "Failed to parse new game ID" NoOp

subscriptions : Model -> Sub Msg
subscriptions model =
    let
        (msgs, (windowWidth, gridSize), endTurnOnPush) =
            case model.game of
                Just game ->
                    ( Pushfight.subscriptions game.pushfight |> Sub.map PushfightMsg
                    , ( game.pushfight.windowWidth , game.pushfight.gridSize )
                    , game.pushfight.endTurnOnPush
                    )
                Nothing ->
                    ( Sub.batch []
                    , ( 1000 , 100 )
                    , False
                    )
    in
        Sub.batch
        [ msgs
        , receivePushfight (mapPushFightDecode windowWidth gridSize endTurnOnPush)
        , receiveNewGame StartNewGame
        , receiveConnectionLost ConnectionLost
        ]
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
