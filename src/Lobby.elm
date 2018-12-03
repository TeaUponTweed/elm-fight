module Lobby exposing (init, update, view, Msg, Model)

import Html
import Html.Events
import Html.Attributes

import Random
import Browser
import Svg exposing (..)
import Svg.Attributes exposing (..)


import Json.Decode as Decode
import Json.Encode as Encode

import Router


-- MODEL


type alias Model =
    { currentGames : List String
    }


init : () -> (Model, Cmd Msg, Maybe Router.Msg)
init _ =
    ( Model []
    , Cmd.none
    , Nothing
    )



-- UPDATE


type Msg
    = GoToGame String
    | NewGame

decodeGames : Decode.Decoder (List String)
decodeGames = 
    Decode.list Decode.string


update : Msg -> Model -> (Model, Cmd Msg, Maybe Router.Msg)
update msg model =
    case msg of
        GoToGame gameID ->
            ( model
            , Cmd.none
            , Just (Router.GoToGame gameID)
            )
        NewGame ->
            ( model
            , Cmd.none
            , Just Router.CreateNewGame
            )


-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Model -> Html.Html Msg
view model =
    Html.div []
        ( List.append 
            ( List.map clickableGame model.currentGames )
            [ Html.button [ Html.Events.onClick NewGame ] [ text "Start New Game" ] ]
        )


clickableGame : String -> Html.Html Msg
clickableGame gameID = 
    Html.button [ Html.Events.onClick (GoToGame gameID) ] [ text ("Go To " ++ gameID) ]
