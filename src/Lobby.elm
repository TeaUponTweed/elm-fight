module Lobby exposing (init, update, view, Msg, Model)

import Browser
import Html exposing (..)
import Html.Events exposing (..)
import Random
import Browser
import Html.Attributes
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
  }


init : () -> (Model, Cmd Msg)
init _ =
  ( Model ["wakka"]
  , Cmd.none
  )



-- UPDATE


type Msg
  = GoToGame

decodeGames : Decode.Decoder (List String)
decodeGames = 
    Decode.list Decode.string


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    GoToGame ->
      ( model
      , Cmd.none
      )


-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none



-- VIEW


view : Model -> Html Msg
view model =
  div [] (List.map (\x -> Html.text x) model.currentGames)
