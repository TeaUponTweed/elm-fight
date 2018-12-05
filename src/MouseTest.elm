import Browser
import Browser.Events
import Html
import Json.Decode as Decode
import String

main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
type alias Model =
    { dragPos : Maybe Position
    }
init : () -> ( Model, Cmd Msg )
init _ =
    ( Model Nothing
    , Cmd.none
    )

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        DragStart pos ->
            ( { model | dragPos = Just pos }
            , Cmd.none
            )
        DragAt pos ->
            ( { model | dragPos = Just pos }
            , Cmd.none
            )
        DragEnd pos ->
            ( { model | dragPos = Nothing }
            , Cmd.none
            )

view : Model -> Html.Html Msg
view model =
    case model.dragPos of
        Just pos ->
            Html.div [] [Html.text <| "Drag at x=" ++ (String.fromInt pos.x) ++ " y=" ++ (String.fromInt pos.y)]
        Nothing ->
            Html.div [] [Html.text <| "Not Dragging"]


type alias Position =
    { x : Int
    , y : Int
    }

type Msg
    = DragStart Position
    | DragAt Position
    | DragEnd Position

position : Decode.Decoder Position
position =
    Decode.map2 Position
        (Decode.field "pageX" Decode.int)
        (Decode.field "pageY" Decode.int)

subscriptions : Model -> Sub Msg
subscriptions model =
    case model.dragPos of
        Nothing ->
            Browser.Events.onMouseDown (Decode.map DragStart position)

        _ ->
            Sub.batch
                [ Browser.Events.onMouseMove (Decode.map DragAt position)
                , Browser.Events.onMouseUp (Decode.map DragEnd position)
                ]
