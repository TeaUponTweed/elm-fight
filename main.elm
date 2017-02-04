import Html exposing (Html, Attribute, div, input, text)
import Html.Attributes exposing (..)
import Html.Events exposing (onInput, on)
import String
import Mouse exposing (Position)
import Keyboard exposing (KeyCode)
import Json.Decode as Decode
import Collage
import Color exposing (Color)
import Element
--import Actions exposing (Action)


main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }

-- MODEL
type Side = Black | White | None
type Piece = Pusher | Peon | Wall | Void | Empty
type Direction = Up | Left | Right | Down

--type alias Position = {x: Int, y: Int}
type alias Cell = {side: Side, peice: Piece, position: Position}
-- TODO use dict grid?
type alias Grid = List Cell

inrange : comparable -> comparable -> comparable -> Bool
inrange val left right = val >= left && val < right

inbounds : Position -> Int -> Int -> Bool
inbounds pos w h = inrange pos.x 0 w && inrange pos.y 0 h


neighbor : Grid -> Cell -> Direction -> Int -> Int -> Maybe Cell
neighbor grid cell side width height =
    let neighborpos =
        case side of
            Up    -> {x=cell.position.x,     y=cell.position.y - 1}
            Down  -> {x=cell.position.x,     y=cell.position.y + 1}
            Left  -> {x=cell.position.x - 1, y=cell.position.y    }
            Right -> {x=cell.position.x + 1, y=cell.position.y    }
    in
        if inbounds neighborpos width height then
            grid
                |> List.filter (\c -> c.position == neighborpos)
                |> List.head
        else
            Nothing


type alias Model = { grid   : Grid,
                     width  : Int,
                     height : Int,
                     size   : Int}

init : (Model, Cmd Msg)
init = (Model [Cell Black Peon (Position 1 3) ] 4 8 30, Cmd.none)

type Msg = ClickAt Position | Clear

---- UPDATE
intdiv : Int -> Int -> Int
intdiv a b = floor ((toFloat a) / (toFloat b))

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model = (updateHelp msg model, Cmd.none)

updateHelp : Msg -> Model -> Model
updateHelp msg model =
    --text (toString (length model.grid))

    case msg of
            --{ model | grid = ((Cell Black Peon (Position (floor ()  (floor (toFloat y/(toFloat model.size))))) :: model.grid )}
        ClickAt {x, y} ->  { model | grid = ((Cell Black Peon (Position (intdiv x model.size) (intdiv y model.size))) :: model.grid )}
        --ClickAt xy -> { model | grid = append model.grid [Cell Black Peon xy])}
        Clear      -> { model | grid = []}

-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
      Sub.batch [ Mouse.clicks ClickAt,
                  Keyboard.downs (key model) ]


key: Model -> KeyCode -> Msg
key {grid} keycode =
    case keycode of
        _ -> Clear
-- View

(=>) = (,)

view : Model -> Html Msg
view model =
    div
        [ style [ "padding" => "30px 0" ] ]
        [ div
            [ style
                [ "height" => "680px"
                , "margin" => "auto"
                , "position" => "absolute"
                , "border-radius" => "4px"
                , "color" => "black"
                , "width" => "480px"
                ]
            ]
            [ renderWell model ]
        ]

renderWell : Model -> Html Msg
renderWell { width, height, grid, size} =
    (Collage.filled (Color.rgb 236 240 241) (Collage.rect (toFloat (width * size)) (toFloat (height * size)))
        :: (grid
            |> List.map (\c->renderBox c.position.x c.position.y size)
        )
    )
        |> Collage.collage (width*size) (height*size)
        |> Element.toHtml

renderBox : Int -> Int -> Int -> Collage.Form
renderBox x y size =
    Collage.rect (toFloat size) (toFloat size)
        |> Collage.filled (Color.rgb 255 0 0)
        |> Collage.move (toFloat (size*x), toFloat (size*y))

--view model =

--    div
--        [ onMouseDown
--        , style
--            [ "background-color" => "#3C8D2F"
--            , "cursor" => "move"

--              , "width" => "100px"
--              , "height" => "100px"
--              , "border-radius" => "4px"
--              , "position" => "relative"
--              , "left" => "400px"
--              , "top" => "400px"

--              , "color" => "white"
--              , "display" => "flex"
--              , "align-items" => "center"
--              , "justify-content" => "center"
--              ]
--          ]
--          [ text "Drag Me!"
--        ]



px : Int -> String
px number =
  toString number ++ "px"

onMouseDown : Attribute Msg
onMouseDown =
  on "mousedown" (Decode.map ClickAt Mouse.position)
--type Msg
--  = Change String

--update : Msg -> Model -> Model
--update msg model =
--  case msg of
--    Change newContent ->
--      { model | content = newContent }


---- VIEW

--view : Model -> Html Msg
--view model =
--  div []
--    [ input [ placeholder "Text to reverse", onInput Change ] []
--    , div [] [ text (String.reverse model.content) ]
--    ]
