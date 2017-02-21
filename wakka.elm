--import Html exposing (..)
import Svg exposing (..)
import Svg.Attributes exposing (..)
import Html
import Html.Events exposing (on)
import Html.Attributes
--import Json.Decode exposing (Decoder)
import Json.Decode as Decode
--import Json.Decode exposing (Decoder)
import Mouse exposing (Position)
import Debug exposing (log)
import Dict

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


view : Model -> Html.Html Msg
view model =
  let
    realPosition =
      getPosition model
  in
    Html.div []
      [ Html.div
          [ makeMouseDown 1
          , Html.Attributes.style
            [ "background-color" => "#3C8D2F"
            , "cursor" => "move"

            , "width" => "100px"
            , "height" => "100px"
            --, "border-radius" => "4px"
            , "position" => "absolute"
            , "left" => px (realPosition.x + 100)
            , "top" => px (realPosition.y + 100)

            --, "color" => "white"
            --, "display" => "flex"
            --, "align-items" => "center"
            --, "justify-content" => "center"
            ]
          ]
          [ pusher 0.0 0.0 1.0 "#ffffff"
          ]
      --, Html.div
      --    [ makeMouseDown 3
      --    , Html.Attributes.style
      --        [ "background-color" => "#3C8D2F"
      --        , "cursor" => "move"

      --        , "width" => "100px"
      --        , "height" => "100px"
      --        , "border-radius" => "4px"
      --        , "position" => "absolute"
      --        , "left" => px (realPosition.x + 100)
      --        , "top" => px (realPosition.y+100)

      --        , "color" => "white"
      --        , "display" => "flex"
      --        , "align-items" => "center"
      --        , "justify-content" => "center"
      --        ]
      --    ]
      --    [ text "Drag You!"
      --    ]
      , Html.div [] [ Html.text (toString model.id)]
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

pusher : Float -> Float -> Float -> String -> Html.Html msg
pusher posx posy size color =
    let
        totsize = 1.0 * 1.0
    in
        svg
        [
            version "1.1",
            x (toString 0),
            y (toString 0),
            width (toString 100.0),
            height (toString 100.0),
            viewBox
                    ("0 0 " ++
                    toString (totsize) ++
                    " " ++
                    toString (totsize))
        ]
        [ rect
            [ fill "#000000"
            , x (toString posx)
            , y (toString posy)
            , width (toString size)
            , height (toString size)
            ]
            []
        , rect
            [ fill color
            , x (toString (posx+size * 0.05))
            , y (toString (posy+size * 0.05))
            , width (toString (size * 0.9))
            , height (toString (size * 0.9))
            ]
            []
        ]

mover : Float -> Float -> Float -> String -> Html.Html msg
mover posx posy size color =
    let
        totsize = 10.0 * size
    in
        svg
        [
                version "1.1",
                x (toString 0),
                y (toString 0),
                width (toString totsize),
                height (toString totsize),
                viewBox
                        ("0 0 " ++
                        toString (totsize) ++
                        " " ++
                        toString (totsize))
        ]
        [ circle
            [ fill "#000000"
            , cx (toString (posx + (size/2.0)))
            , cy (toString (posy + (size/2.0)))
            , r (toString (size/2.0))
            ]
            []
        , circle
            [ fill color
            , cx (toString (posx + (size/2.0)))
            , cy (toString (posy + (size/2.0)))
            , r (toString ((size * 0.9)/2.0))
            ]
            []
        ]