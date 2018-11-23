import Browser

import Debug exposing (log, toString)

import Dict exposing (Dict)

import Html exposing (Html, text, div)
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


type alias Board = Dict String Bool


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
    | DidUploadBoard Bool


togglePieceImpl : Maybe Bool -> Maybe Bool
togglePieceImpl val = 
    case val of
        Just _ -> Nothing
        Nothing -> Just True


togglePiece : Board -> String -> Board
togglePiece d k =
    d |> Dict.update k togglePieceImpl


decodeBoard : Decode.Decoder (Dict String Bool)
decodeBoard = 
    Decode.dict Decode.bool


encodeBoardImpl : (String, Bool) -> (String, Encode.Value)
encodeBoardImpl (key, val) = 
    (key, Encode.bool val)

encodeBoard : Board -> Encode.Value
encodeBoard board = 
    Encode.object(List.map encodeBoardImpl (Dict.toList board))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        MouseDownAt (x, y) ->
            let
                row = (floor y) // model.npixels
                col = (floor x) // model.npixels
            in
                if col < model.ncols && row < model.nrows then
                    let
                        updatedBoard = togglePiece model.board (String.fromInt (row * model.ncols + col ))
                    in
                        ( { model | board =  updatedBoard}
                        , Firebase.updateBoardToFirebase (encodeBoard updatedBoard)
                        )
                else
                    ( model
                    , Cmd.none
                    )

        GetBoard board ->
            case Decode.decodeValue decodeBoard board of
                Ok updatedBoard ->
                    ( { model | board =  updatedBoard }
                    , Cmd.none
                    )
                Err err ->
                    ( log ("Could not update model with received board" ++ toString err) model
                    , Cmd.none
                    )
        DidUploadBoard val ->
            case val of
                False ->
                    ( log "Failed to upload board to firestore" model
                    , Cmd.none
                    )
                True ->
                    ( model
                    , Cmd.none
                    )


drawBoardSquares : Int -> Int -> Int -> Board -> Int -> List (Svg Msg) -> List (Svg Msg)
drawBoardSquares nrows ncols npixels board key squares =
    let
        px = (npixels * (modBy ncols key) + npixels // 2)
        py = (npixels * (key // ncols   ) + npixels // 2)
    in
        if key >= (nrows * ncols) then
            squares
        else
            case Dict.get (String.fromInt key) board of
                Just piece ->
                    drawBoardSquares nrows ncols npixels board (key + 1) (List.append squares [drawCircle px py (npixels//2) "black"])
                Nothing ->
                    drawBoardSquares nrows ncols npixels board (key + 1) (List.append squares [drawCircle px py (npixels//2) "white"])


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
        [ svg
            [ width pxwidth, height pxwidth, viewBox ("0 0" ++ " " ++ pxwidth ++ " " ++ pxheight), fill "gray", stroke "black", strokeWidth "0 "]
            (drawBoardSquares model.nrows model.ncols model.npixels model.board 0 [ rect [ x "0", y "0", width pxwidth, height pxheight] [] ])
        , Button.view Mdc
            "my-button"
            model.mdc
            [ Button.ripple
            , Options.onClick Click
            ]
            [ text "Click me!" ]
        ]


subscriptions : Model -> Sub Msg
subscriptions model =
  firebaseSubscriptions model


firebaseSubscriptions : Model -> Sub Msg
firebaseSubscriptions model =
  Sub.batch
    [ Firebase.updateBoardFromFirebase GetBoard
    , Firebase.didUploadBoard DidUploadBoard
    ]
