import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (on)
--import Json.Decode exposing (Decoder)
import Json.Decode as Decode
--import Json.Decode exposing (Decoder)
import Mouse exposing (Position)
import Debug exposing (log)


main =
  Html.program
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }


-- MODEL


type alias Model =
    { position : Position
    , drag : Maybe Drag
    , id: Maybe Int
    }


type alias Drag =
    { start : Position
    , current : Position
    }


init : ( Model, Cmd Msg )
init =
  ( Model (Position 200 200) Nothing Nothing, Cmd.none )



-- UPDATE


type Msg
    = DragStart Position Int
    | DragAt Position
    | DragEnd Position


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  ( updateHelp msg model, Cmd.none )


updateHelp : Msg -> Model -> Model
updateHelp msg ({position, drag, id} as model) =
  case msg of
    DragStart xy newid ->
      Model position (Just (Drag xy xy)) (Just newid)

    DragAt xy ->
      Model position (Maybe.map (\{start} -> Drag start xy) drag) id

    DragEnd _ ->
      Model (getPosition model) Nothing Nothing



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
  case model.drag of
    Nothing ->
      Sub.none

    Just _ ->
      Sub.batch [ Mouse.moves DragAt, Mouse.ups DragEnd ]



-- VIEW


(=>) = (,)


view : Model -> Html Msg
view model =
  let
    realPosition =
      getPosition model
  in
    div []
      [ div
          [ makeMouseDown 1
          , style
              [ "background-color" => "#3C8D2F"
              , "cursor" => "move"

              , "width" => "100px"
              , "height" => "100px"
              , "border-radius" => "4px"
              , "position" => "absolute"
              , "left" => px realPosition.x
              , "top" => px realPosition.y

              , "color" => "white"
              , "display" => "flex"
              , "align-items" => "center"
              , "justify-content" => "center"
              ]
          ]
          [ text "Drag Me!"
          ]
      , div
          [ makeMouseDown 3
          , style
              [ "background-color" => "#3C8D2F"
              , "cursor" => "move"

              , "width" => "100px"
              , "height" => "100px"
              , "border-radius" => "4px"
              , "position" => "absolute"
              , "left" => px (realPosition.x + 100)
              , "top" => px (realPosition.y+100)

              , "color" => "white"
              , "display" => "flex"
              , "align-items" => "center"
              , "justify-content" => "center"
              ]
          ]
          [ text "Drag You!"
          ]
      , div [] [text (toString model.id)]
      ]


px : Int -> String
px number =
  toString number ++ "px"


getPosition : Model -> Position
getPosition {position, drag} =
  case drag of
    Nothing ->
      position

    Just {start,current} ->
      Position
        (position.x + current.x - start.x)
        (position.y + current.y - start.y)


makeMouseDown: Int -> Attribute Msg
makeMouseDown id =
  let
    stupid = \p -> DragStart p id
  in
    on "mousedown" (Decode.map stupid Mouse.position)
