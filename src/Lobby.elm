module Lobby exposing (init, update, view, Msg, Model)

import Browser
import Html exposing (..)
import Html.Events exposing (..)
import Random
import Browser
import Html.Attributes
import Svg exposing (..)
import Svg.Attributes exposing (..)

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
  { dieFace : Int
  , dieFace2 : Int
  }


init : () -> (Model, Cmd Msg)
init _ =
  ( Model 1 1
  , Cmd.none
  )



-- UPDATE


type alias Wakka = 
  { roll1 : Int
  , roll2 : Int
  , doKeepRolling : Bool
  }

type Msg
  = Roll
  | NewFace Wakka

rollWeighted : Random.Generator Int
rollWeighted =
  Random.weighted (50, 1) [ (10, 2), (10, 3), (10, 4), (10, 5), (10, 6)]

keepRolling : Random.Generator Bool
keepRolling =
  Random.weighted (80, True) [(20, False)]

roll2 : Random.Generator (Int, Int)
roll2 =
  Random.pair rollWeighted rollWeighted



update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    Roll ->
      ( model
      , Random.generate NewFace (Random.map3 Wakka rollWeighted rollWeighted keepRolling)
      )

    NewFace x ->
      if x.doKeepRolling then
        ( model
        , Random.generate NewFace (Random.map3 Wakka rollWeighted rollWeighted keepRolling)
        )
      else
        ( Model x.roll1 x.roll2
        , Cmd.none
        )


-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none



-- VIEW


view : Model -> Html Msg
view model =
  div []
    [
      svg 
        [ width "120", height "120", viewBox "0 0 120 120", fill "white", stroke "black", strokeWidth "3", Html.Attributes.style "padding-left" "20px"]
        (drawDie model.dieFace)
    ,
      svg 
        [ width "120", height "120", viewBox "0 0 120 120", fill "white", stroke "black", strokeWidth "3", Html.Attributes.style "padding-left" "20px"]
        (drawDie model.dieFace2)
    , button [ onClick Roll ] [ Html.text "Roll" ]
    ]

drawDie : Int -> List (Svg Msg)
drawDie dieFace =
  List.append
      [ rect [ x "1", y "1", width "100", height "100", rx "15", ry "15" ] [] ]
      (svgCirclesForDieFace dieFace)

svgCirclesForDieFace : Int -> List (Svg Msg)
svgCirclesForDieFace dieFace =
    case dieFace of
        1 ->
            [ circle [ cx "50", cy "50", r "10", fill "black" ] [] ]

        2 ->
            [ circle [ cx "25", cy "25", r "10", fill "black" ] []
            , circle [ cx "75", cy "75", r "10", fill "black" ] []
            ]

        3 ->
            [ circle [ cx "25", cy "25", r "10", fill "black" ] []
            , circle [ cx "50", cy "50", r "10", fill "black" ] []
            , circle [ cx "75", cy "75", r "10", fill "black" ] []
            ]

        4 ->
            [ circle [ cx "25", cy "25", r "10", fill "black" ] []
            , circle [ cx "75", cy "25", r "10", fill "black" ] []
            , circle [ cx "25", cy "75", r "10", fill "black" ] []
            , circle [ cx "75", cy "75", r "10", fill "black" ] []
            ]

        5 ->
            [ circle [ cx "25", cy "25", r "10", fill "black" ] []
            , circle [ cx "75", cy "25", r "10", fill "black" ] []
            , circle [ cx "25", cy "75", r "10", fill "black" ] []
            , circle [ cx "75", cy "75", r "10", fill "black" ] []
            , circle [ cx "50", cy "50", r "10", fill "black" ] []
            ]

        6 ->
            [ circle [ cx "25", cy "20", r "10", fill "black" ] []
            , circle [ cx "25", cy "50", r "10", fill "black" ] []
            , circle [ cx "25", cy "80", r "10", fill "black" ] []
            , circle [ cx "75", cy "20", r "10", fill "black" ] []
            , circle [ cx "75", cy "50", r "10", fill "black" ] []
            , circle [ cx "75", cy "80", r "10", fill "black" ] []
            ]

        _ ->
            [ circle [ cx "50", cy "50", r "50", fill "red", stroke "none" ] [] ]
