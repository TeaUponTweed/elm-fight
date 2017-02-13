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
import Window
--import Task
--import Maybe exposing (..)
--import Result exposing (..)
--import Task exposing (toResult)

main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }

-- DATA

type Side = Black | White | None
type Piece = Pusher | Peon | Wall | Void | Empty
type Direction = Up | Left | Right | Down

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


-- MODEL

type alias Model = { grid   : Grid,
                     width  : Int,
                     height : Int,
                     size   : Int,
                     log    : String,
                     cameraposx : Float,
                     cameraposy : Float,
                     camerazoom : Float,
                     width : Int,
                     height : Int
                    }

init : (Model, Cmd Msg)
init =  (Model [Cell Black Peon (Position 2 5) ] 4 8 30 "" 0.0 0.0 1.0 -1 -1, Cmd.none)

--init =
--    let
--        windowSize = Task.toMaybe (Window.size)
--    in
--        case windowSize of
--            Some {width, height} -> ((Model [Cell Black Peon (Position 2 5) ] 4 8 30 "" 0.0 0.0 1.0 width height), Cmd.none)
--            Nothing -> ((Model [Cell Black Peon (Position 2 5) ] 4 8 30 "" 0.0 0.0 1.0 width height), Cmd.none)

type Msg = ClickAtMsg Position | ClearMsg | WindowResizedMsg Window.Size

---- UPDATE

intdiv : Int -> Int -> Int
intdiv a b = floor ((toFloat a) / (toFloat b))

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model = (updateHelp msg model, Cmd.none)

updateHelp : Msg -> Model -> Model
updateHelp msg model =
    case msg of
        ClickAtMsg {x, y} ->
            let (xpos, ypos) =
                (intdiv x model.size, intdiv y model.size)
            in
                if True then -- inbounds (Position xpos ypos) model.width model.height then
                    { model | grid = ((Cell Black Peon (Position xpos (model.height - ypos - 1))) :: model.grid)
                            , log = toString ((x, y), (xpos, ypos)) }
                else
                    model
        ClearMsg -> { model | grid = [], log=""}

        WindowResizedMsg {width, height} -> {model | width=width, height=height}

-- SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
      Sub.batch [ Mouse.clicks ClickAtMsg,
                  Keyboard.downs (key model),
                  Window.resizes WindowResizedMsg ]


key: Model -> KeyCode -> Msg
key {grid} keycode =
    case keycode of
        _ -> ClearMsg
-- View

(=>) = (,)

view : Model -> Html Msg
view model =
    div
        []
        [
            div
            [ style
                [ "height" => "680px"
                , "margin" => "auto"
                , "position" => "absolute"
                , "color" => "black"
                , "width" => "480px"
                ]
            ]
            [ renderWell model ],
        div
        [ style
            [ "height" => "680px"
            , "width" => "480px"
            , "position" => "absolute"
            ]
        ]
        [ text ((toString model.width) ++ " " ++ (toString model.height))
        , text model.log]
        ]

renderWell : Model -> Html Msg
renderWell { width, height, grid, size} =
    let (xoff, yoff) =
        ( -(toFloat (width - 1)) * (toFloat size) / 2.0, -(toFloat (height-1)) * (toFloat size) / 2.0)
    in
        (Collage.filled (Color.rgb 236 240 241) (Collage.rect (toFloat (width * size)) (toFloat (height * size)))
            :: (grid
                |> List.map (\c->renderBox xoff yoff (toFloat c.position.x) (toFloat c.position.y) (toFloat size))
            )
        )
            |> Collage.collage (width*size) (height*size)
            |> Element.toHtml


renderBox : Float -> Float -> Float -> Float -> Float -> Collage.Form
renderBox xoff yoff x y size =
    Collage.rect size size
        |> Collage.filled (Color.rgb 255 0 0)
        |> Collage.move ( (size*x + xoff) ,  (size*y + yoff))


px : Int -> String
px number =
  toString number ++ "px"
