module Main exposing (Msg,Model,init,update,view)
import Browser
import Json.Decode as D
import Json.Encode as E
import Html exposing (Html, button, div, text, input)
import Html.Attributes exposing (placeholder, value)
import Html.Events exposing (onClick, onInput)

import Pushfight

port requestNewGame : String -> Cmd msg
port receiveNewGame : (String -> msg) -> Sub msg

port requestJoinGame : String -> Cmd msg
--port receiveJoinGame : (String -> msg) -> Sub msg

port sendPushfight : Pushfight.Model -> Cmd msg
port receivePushfight : (Pushfight.Model -> msg) -> Sub msg

port notifyExit : () -> Cmd msg


type alias Game =
    { gameID: String
    , pushfight: Pushfight.Model
    }

type Msg
    = TryNewGame  
    | TryJoinGame
    | UpdateNewGameID String
    | UpdateJoinGameID String
    | PushfightFromServer Game
    | ExitGame
    | PushfightMsg Pushfight.Msg

type alias Model =
    { game: Maybe Game
    , newGameID: String
    , joinGameID: String
    }

view : Model -> Html Msg
view model =
    case model.game of
        Just game ->
            div []
                [ div [] [ Pushfight.view game.pushfight |> Html.map PushfightMsg ]
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


init : () -> ( Model, Cmd Msg )
init _ =
    ( { game = Nothing , newGameID = "", joinGameID = ""}
    , Cmd.none
    )

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
                        (pushfight, cmdMsg) = Pushfight.init ()
                        game = { gameID = gameID, pushfight = pushfight}
                    in
                        ( { model | pushfight = Just pushfight}
                        , Cmd.batch
                            [ Cmd.map PushfightMsg cmdMsg
                            , sendPushfight pushfight
                            ]
                        )
            TryJoinGame ->
                if String.length model.joinGameID > 0 then
                    ( model
                    , requestJoinGame model.joinGameID
                    )
                else
                    noop
            ExitGame ->
                ( { model | game = Nothing }
                , notifyExit
                )
            UpdateNewGameID gameID ->
                ( { model | newGameID = gameID }
                , Cmd.none
                )
            UpdateJoinGameID gameID ->
                ( { model | joinGameID = gameID }
                , Cmd.none
                )
            PushfightMsg pfmsg ->
                case model.game of
                    Just game ->
                        let
                            (pushfight, cmdMsg) = Pushfight.update pfmsg game.pushfight
                        in
                            ( { model | pushfight = Just pushfight}
                            , Cmd.map PushfightMsg cmdMsg
                            )
                    Nothing ->
                        noop
            PushfightFromServer game ->
                ( { model | game = Just game }
                , Cmd.none
                )


subscriptions : Model -> Sub Msg
subscriptions model =
    case model.game of
        Just game ->
            Pushfight.subscriptions game.pushfight |> Sub.map PushfightMsg
        Nothing ->
            Sub.batch []

main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
