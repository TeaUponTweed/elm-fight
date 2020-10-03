module Main exposing (Msg,Model,init,update,view)
import Browser
import Json.Decode as D
import Json.Encode as E
import Html exposing (Html, button, div, text, input)
import Html.Attributes exposing (placeholder, value)
import Html.Events exposing (onClick, onInput)

import Pushfight

--port requestNewGame : String -> Cmd msg
--port receiveNewGame : (String -> msg) -> Sub msg

--port requestJoinGame : String -> Cmd msg
--port receiveJoinGame : (String -> msg) -> Sub msg

--port sendPushfight : Pushfight.Model -> Cmd msg
--port getPushfight : (Pushfight.Model -> msg) -> Sub msg

--port notifyExit : () -> Cmd msg


--type alias Game =
--    { gameID: String
--    , pushfight: Pushfight.Model
--    }

type Msg
    = NewGame  
    | JoinGame
    | UpdateNewGameID String
    | UpdateJoinGameID String
    | ExitGame
    | PushfightMsg Pushfight.Msg

type alias Model =
    { pushfight: Maybe Pushfight.Model
    , newGameID: String
    , joinGameID: String
    }

view : Model -> Html Msg
view model =
    case model.pushfight of
        Just pushfight ->
            div []
                [ div [] [ Pushfight.view pushfight |> Html.map PushfightMsg ]
                , div [] [ button [ onClick ExitGame ] [ text "Leave Game" ] ]
                ]
        Nothing ->
          div []
            [ div []
                [ input [ placeholder "New Game ID", value model.newGameID, onInput UpdateNewGameID ] []
                , button [ onClick NewGame ] [ text "Start New Game" ]
                ]
            , div []
                [ input [ placeholder "Join Game ID", value model.joinGameID, onInput UpdateJoinGameID ] []
                , button [ onClick JoinGame ] [ text "Join Game" ]
                ]
            ]


init : () -> ( Model, Cmd Msg )
init _ =
    ( { pushfight = Nothing , newGameID = "", joinGameID = ""}
    , Cmd.none
    )

update: Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        noop = ( model, Cmd.none)
    in
        case msg of
            NewGame ->
                if String.length model.newGameID > 0 then
                    let
                        (pushfight, cmdMsg) = Pushfight.init ()
                    in
                        ( { model | pushfight = Just pushfight}
                        , Cmd.map PushfightMsg cmdMsg
                        )
                else
                    noop
            JoinGame ->
                noop
            ExitGame ->
                ( { model | pushfight = Nothing }
                , Cmd.none
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
                case model.pushfight of
                    Just pushfight ->
                        let
                            (updatedPushfight, cmdMsg) = Pushfight.update pfmsg pushfight
                        in
                            ( { model | pushfight = Just updatedPushfight}
                            , Cmd.map PushfightMsg cmdMsg
                            )
                    Nothing ->
                        noop

subscriptions : Model -> Sub Msg
subscriptions model =
    case model.pushfight of
        Just pushfight ->
            Pushfight.subscriptions pushfight |> Sub.map PushfightMsg
        Nothing ->
            Sub.batch []

main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


