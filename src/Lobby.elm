module Lobby exposing (init, update, view, Msg, Model)

import Browser

import Html
import Html.Events
import Html.Attributes

import Random
import Browser
import Svg exposing (..)
import Svg.Attributes exposing (..)


import Json.Decode as Decode
import Json.Encode as Encode


-- MAIN


main =
  Browser.element
    { init = init
    , update = update
    , subscriptions = subscriptions
    , view = view
    }



-- MODEL


type alias Model =
  { currentGames : List String
  , nextGameNumber : Int
  }


init : () -> (Model, Cmd Msg)
init _ =
  ( Model [] 2
  , Cmd.none
  )



-- UPDATE


type Msg
  = GoToGame String
  | NewGame

decodeGames : Decode.Decoder (List String)
decodeGames = 
    Decode.list Decode.string


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    GoToGame _ ->
      ( model
      , Cmd.none
      )
    NewGame ->
      ( {model | nextGameNumber = model.nextGameNumber + 1} 
      , Cmd.none
      )


-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none



-- VIEW


view : Model -> Html.Html Msg
view model =
  Html.div [] (List.append (List.map clickableGame model.currentGames) [ Html.button [ Html.Events.onClick NewGame ] [ text ("New Game " ++ String.fromInt model.nextGameNumber) ] ])


clickableGame : String -> Html.Html Msg
clickableGame gameID = 
  Html.button [ Html.Events.onClick (GoToGame gameID) ] [ text ("Go To " ++ gameID) ]
