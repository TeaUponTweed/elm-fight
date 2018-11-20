import Browser

import Debug exposing (log)

import Dict exposing (Dict)

import Html exposing (..)
import Html.Events exposing (..)
import Html.Attributes
import Html.Events.Extra.Mouse as Mouse

import Json.Decode as Decode
import Json.Encode as Encode

import Svg exposing (..)
import Svg.Attributes exposing (..)

import Firebase

main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type alias Board = Dict Int Bool


type alias Model =
    { board : Board
    , nrows : Int
    , ncols : Int
    , npixels : Int
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( Model Dict.empty 10 10 50
    , Cmd.none
    )


type Msg
    = MouseDownAt ( Float, Float )
    | GetBoard Decode.Value


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    ( updateImpl msg model, Cmd.none )


togglePieceImpl : Maybe Bool -> Maybe Bool
togglePieceImpl val = 
    case val of
        Just _ -> Nothing
        Nothing -> Just True


togglePiece : Board -> Int -> Board
togglePiece d k =
    d |> Dict.update k togglePieceImpl

--     String -> Result Decode.Error (Dict String Bool)
decodeBoard : Decode.Decoder (Dict String Bool)
decodeBoard = 
    Decode.dict Decode.bool

updateImpl : Msg -> Model -> Model
updateImpl msg model =
    case msg of
        MouseDownAt (x, y) ->
            let
                row = (floor y) // model.npixels
                col = (floor x) // model.npixels
            in
                if col < model.ncols && row < model.nrows then
                    {model | board = togglePiece model.board (row * model.ncols + col )}
                else
                    model

        GetBoard board ->
            let
                convertKeysToInts  ( key, value ) = (Maybe.withDefault 0 (String.toInt key), value)
                updatedBoard = board
                    |> Decode.decodeValue decodeBoard
                    |> Result.withDefault Dict.empty
            in
                if updatedBoard /= Dict.empty then
                    {model | board =  updatedBoard
                                   |> Dict.toList
                                   |> List.map convertKeysToInts
                                   |> Dict.fromList
                    }
                else
                    log "Could not update model with received board" model



drawBoardSquares : Int -> Int -> Int -> Board -> Int -> List (Svg Msg) -> List (Svg Msg)
drawBoardSquares nrows ncols npixels board key squares =
    --log ((String.fromInt ncols) ++ " " ++ (String.fromInt ncols) ++ " " ++ (String.fromInt npixels) ++ " " ++ (String.fromInt key))
    let
        px = log "px" (npixels * (modBy ncols key) + npixels // 2)
        py = log "py" (npixels * (key // ncols   ) + npixels // 2)
    in
        if key >= (nrows * ncols) then
            squares
        else
            case Dict.get key board of
                Just piece ->
                    drawBoardSquares nrows ncols npixels board (key + 1) (List.append squares [drawCircle px py (log "radius" (npixels//2)) "black"])
                Nothing ->
                    drawBoardSquares nrows ncols npixels board (key + 1) (List.append squares [drawCircle px py (log "radius" (npixels//2)) "white"])


drawCircle : Int -> Int -> Int -> String -> Svg Msg
drawCircle x y radius color =
    circle [ cx (String.fromInt x), cy (String.fromInt y), r (String.fromInt radius), fill color] []


view : Model -> Html Msg
view model =
    let
        pxwidth  = String.fromInt (model.ncols * model.npixels)
        pxheight = String.fromInt (model.nrows * model.npixels)
    in
      div [Mouse.onDown (\event -> MouseDownAt event.offsetPos)]
        [
          svg
            [ width pxwidth, height pxwidth, viewBox ("0 0" ++ " " ++ pxwidth ++ " " ++ pxheight), fill "gray", stroke "black", strokeWidth "0 "]
            (drawBoardSquares model.nrows model.ncols model.npixels model.board 0 [ rect [ x "0", y "0", width pxwidth, height pxheight] [] ])
        ]


subscriptions : Model -> Sub Msg
subscriptions model =
  firebaseSubscriptions model


firebaseSubscriptions : Model -> Sub Msg
firebaseSubscriptions model =
  Sub.batch
    [ Firebase.updateBoardFromFirebase GetBoard
    ]
