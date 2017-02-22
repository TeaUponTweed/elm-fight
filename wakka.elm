--import Html exposing (..)
import Svg exposing (..)
import Svg.Attributes exposing (..)
import Html
import Html.Events exposing (on)
import Html.Attributes
import Json.Decode as Decode
import Mouse exposing (Position)
import Debug exposing (log)
import Dict exposing (Dict)


-- TODO
-- * Clean up drawing
-- * Implement moving
-- * Implement pushing
-- * Implement anchoring

main =
  Html.program
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }


-- MODEL
type Piece = Pusher | Mover | Abyss | Empty
type Color = Black | White
type Direction = Up | Left | Right | Down

type alias DragablePiece =
    { drag  : Maybe Drag
    , piece : Piece
    , color : Maybe Color
    }

type alias Drag =
    { start : Position
    , current : Position
    }

type alias Model =
    { board: (Dict (Int, Int) DragablePiece)
    , lastMovedPiece: Maybe ((Int, Int), DragablePiece)
    , gridSize: Int
    , anchor: Maybe (Int, Int)
    }

init : ( Model, Cmd Msg )
init =
    ( Model
        (
        Dict.fromList
            [ ((0, 0), DragablePiece Nothing Abyss Nothing)
            , ((0, 1), DragablePiece Nothing Abyss Nothing)
            , ((0, 2), DragablePiece Nothing Abyss Nothing)
            , ((0, 3), DragablePiece Nothing Abyss Nothing)

            , ((1, 0), DragablePiece Nothing Abyss Nothing)
            , ((1, 1), DragablePiece Nothing Empty Nothing)
            , ((1, 2), DragablePiece Nothing Empty Nothing)
            , ((1, 3), DragablePiece Nothing Abyss Nothing)

            , ((2, 0), DragablePiece Nothing Empty Nothing)
            , ((2, 1), DragablePiece Nothing Empty Nothing)
            , ((2, 2), DragablePiece Nothing Empty Nothing)
            , ((2, 3), DragablePiece Nothing Abyss Nothing)

            , ((3, 0), DragablePiece Nothing Empty Nothing)
            , ((3, 1), DragablePiece Nothing Empty Nothing)
            , ((3, 2), DragablePiece Nothing Mover (Just White))
            , ((3, 3), DragablePiece Nothing Empty Nothing)

            , ((4, 0), DragablePiece Nothing Pusher (Just White))
            , ((4, 1), DragablePiece Nothing Mover (Just White))
            , ((4, 2), DragablePiece Nothing Pusher (Just White))
            , ((4, 3), DragablePiece Nothing Pusher (Just White))

            , ((5, 0), DragablePiece Nothing Pusher (Just Black))
            , ((5, 1), DragablePiece Nothing Mover (Just Black))
            , ((5, 2), DragablePiece Nothing Pusher (Just Black))
            , ((5, 3), DragablePiece Nothing Pusher (Just Black))

            , ((6, 0), DragablePiece Nothing Empty Nothing)
            , ((6, 1), DragablePiece Nothing Empty Nothing)
            , ((6, 2), DragablePiece Nothing Mover (Just Black))
            , ((6, 3), DragablePiece Nothing Empty Nothing)

            , ((7, 0), DragablePiece Nothing Abyss Nothing)
            , ((7, 1), DragablePiece Nothing Empty Nothing)
            , ((7, 2), DragablePiece Nothing Empty Nothing)
            , ((7, 3), DragablePiece Nothing Empty Nothing)

            , ((8, 0), DragablePiece Nothing Abyss Nothing)
            , ((8, 1), DragablePiece Nothing Empty Nothing)
            , ((8, 2), DragablePiece Nothing Empty Nothing)
            , ((8, 3), DragablePiece Nothing Abyss Nothing)

            , ((9, 0), DragablePiece Nothing Abyss Nothing)
            , ((9, 1), DragablePiece Nothing Abyss Nothing)
            , ((9, 2), DragablePiece Nothing Abyss Nothing)
            , ((9, 3), DragablePiece Nothing Abyss Nothing)
            ]
        )
        Nothing
        50
        Nothing
    , Cmd.none
    )


-- UPDATE


type Msg
    = DragStart Position (Int, Int)
    | DragAt Position
    | DragEnd Position


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  ( updateHelp msg model, Cmd.none )


updateHelp : Msg -> Model -> Model
updateHelp msg model =
    case msg of
        DragStart xy key ->
            let
                maybePiece = Dict.get key model.board
            in
                case maybePiece of
                    Just piece ->
                        case piece.piece of
                            Empty ->
                                model
                            Abyss ->
                                model
                            _ ->
                                { model
                                | board = Dict.insert key (DragablePiece Nothing Empty Nothing) model.board
                                , lastMovedPiece = Just (key, {piece | drag = Just (Drag xy xy)} )
                                }

                    _ ->
                        log ("bad key for board " ++ (toString key)) model

        DragAt xy -> -- TODO handle intermediate push?
            case model.lastMovedPiece of
                Just (key, piece) ->
                    { model
                    | lastMovedPiece = Just (key, { piece | drag = (Maybe.map (\{start} -> Drag start xy) piece.drag) } )
                    }
                _ ->
                    model

        DragEnd _ ->
            handleMove model

handleMove: Model -> Model
handleMove model =
    case model.lastMovedPiece of
        Just ((row, col), movedPiece) ->
            let
                (c, r) =
                    case movedPiece.drag of
                        Just {start, current} ->
                            ( col + getDelta current.x start.x
                            , row + getDelta current.y start.y
                            )
                        Nothing ->
                            (row, col)

                getDelta c s =
                    let
                        absDelta = abs (c - s)
                        deltaCols = (absDelta + (model.gridSize//2))//model.gridSize
                    in
                        if c < s then
                            -deltaCols
                        else
                            deltaCols

                revertedModel =
                    { model
                    | board = Dict.insert (row, col) {movedPiece | drag = Nothing} model.board
                    , lastMovedPiece = Nothing
                    }
                maybeDir = case (c - col, r-row) of
                    (1, 0) -> Just Right
                    (-1, 0) -> Just Left
                    (0, 1) -> Just Up
                    (0, -1) -> Just Down
                    _ -> Nothing
            in
                if Dict.member (r, c) model.board then
                    case Dict.get (r, c) model.board of
                        Just movedToPiece ->
                            case movedToPiece.piece of
                                Empty ->
                                    {model
                                    | board = Dict.insert (r, c) {movedPiece | drag = Nothing} model.board
                                    , lastMovedPiece = Nothing
                                    }
                                Abyss ->
                                    revertedModel
                                _ ->
                                    case maybeDir of
                                        Just dir ->
                                            if log "can push? " (canPush model (col, row) dir) then
                                                executePush {model | anchor = Nothing} (col, row) dir
                                            else
                                                revertedModel
                                        _ ->
                                            revertedModel
                        Nothing ->
                            revertedModel
                else
                    revertedModel
        Nothing ->
            model


executePush: Model -> (Int, Int) -> Direction -> Model
executePush model (startX, startY) direction =
    case model.lastMovedPiece of
        Just (_, piece) ->
            case direction of
                Up    -> executePushImpl {model| lastMovedPiece = Nothing, anchor = Just (startY+1, startX  )} (startX  , startY+1) (0 , 1) {piece | drag = Nothing}
                Down  -> executePushImpl {model| lastMovedPiece = Nothing, anchor = Just (startY-1, startX  )} (startX  , startY-1) (0 ,-1) {piece | drag = Nothing}
                Left  -> executePushImpl {model| lastMovedPiece = Nothing, anchor = Just (startY  , startX-1)} (startX-1, startY  ) (-1, 0) {piece | drag = Nothing}
                Right -> executePushImpl {model| lastMovedPiece = Nothing, anchor = Just (startY  , startX+1)} (startX+1, startY  ) (1 , 0) {piece | drag = Nothing}
        _ -> model


executePushImpl: Model -> (Int, Int) -> (Int, Int) -> DragablePiece -> Model
executePushImpl model (currentX, currentY) (deltaX, deltaY) toMove =
    case Dict.get (currentY, currentX) model.board of
        Just nextPiece ->
            case nextPiece.piece of
                Abyss ->
                    { model
                    | lastMovedPiece = Nothing
                    }
                Empty ->
                    { model
                    | board = Dict.insert (currentY, currentX) toMove model.board
                    , lastMovedPiece = Nothing}
                _ ->
                    executePushImpl
                        {model | board = Dict.insert (currentY, currentX) toMove model.board }
                        (currentX + deltaX, currentY + deltaY)
                        (deltaX, deltaY)
                        nextPiece
        Nothing ->
            log "bad mojo in push " model

-- TODO consolidate copy paste
canPush: Model -> (Int, Int) -> Direction -> Bool
canPush model (startX, startY) direction =
    let
        isPusher =
            case model.lastMovedPiece of
                Just (key, piece) ->
                    piece.piece == Pusher
                _ -> False
    in
        case direction of
            Up    -> isPusher && (canPushImpl model (startX, startY+1) (0 , 1))
            Down  -> isPusher && (canPushImpl model (startX, startY-1) (0 ,-1))
            Left  -> isPusher && (canPushImpl model (startX-1, startY) (-1, 0))
            Right -> isPusher && (canPushImpl model (startX+1, startY) (1 , 0))


canPushImpl: Model -> (Int, Int) -> (Int, Int) -> Bool
canPushImpl model (currentX, currentY) (deltaX, deltaY) =
    case Dict.get (currentY, currentX) model.board of
        Just piece ->
            case (piece.piece, (Just (currentY, currentX) == model.anchor)) of
                (Abyss, _) ->
                    True
                (Empty, _) ->
                    True
                (Pusher, True) ->
                    False
                _ ->
                    canPushImpl model (currentX + deltaX, currentY + deltaY) (deltaX, deltaY)
        Nothing ->
            False


-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch [ Mouse.moves DragAt, Mouse.ups DragEnd ]



-- VIEW
drawBoardSquare: Model -> (Int, Int) -> Html.Html Msg
drawBoardSquare model key =
    case Dict.get key model.board of
        Just piece ->
            drawBoardSquareImpl model key piece
        Nothing ->
            Html.div [] [Html.text "wtf man?"]

drawBoardSquareImpl: Model -> (Int, Int) -> DragablePiece -> Html.Html Msg
drawBoardSquareImpl model key piece =
    let
        realPosition = getPosition model key piece
        attributes =
            Html.Attributes.style
                [ "cursor" => "move"
                , "background-color" => "rgba(139,69,19,1)"
                , "width" => px model.gridSize
                , "height" => px model.gridSize
                , "position" => "absolute"
                , "left" => px (realPosition.x)
                , "top" => px (realPosition.y)
                ]
    in
        case piece.piece of
            Mover ->
                Html.div
                    [ makeMouseDown key, attributes]
                    [ drawMover (toFloat model.gridSize) (getColorString piece.color) ]
            Pusher ->
                Html.div
                    [ makeMouseDown key, attributes]
                    [ drawPusher (toFloat model.gridSize) (getColorString piece.color) (model.anchor == Just key)]
            Empty ->
                Html.div
                    [ makeMouseDown key, attributes]
                    [ drawEmpty (toFloat model.gridSize) ]
            Abyss ->
                Html.div
                [ attributes, makeMouseDown key
                ]
                [ drawAbyss (toFloat model.gridSize) ]


getColorString: Maybe Color -> String
getColorString color =
    case color of
        Just White -> "#ffffff"
        Just Black -> "#000000"
        _          -> "#ff00ff"


(=>) = (,)


view : Model -> Html.Html Msg
view model =
  let
    doDraw = drawBoardSquare model
    movingDrawBiz =
        case model.lastMovedPiece of
            Just (key, piece) ->
                [drawBoardSquareImpl model key piece]
            Nothing -> []
  in
    Html.div [Html.Attributes.style ["background-color" => boardColor]] ((List.map doDraw (Dict.keys model.board)) ++ movingDrawBiz)


px : Int -> String
px number =
  toString number ++ "px"


getPosition : Model -> (Int, Int) -> DragablePiece -> Position
getPosition model (row, col) piece =
    case piece.drag of
        Just {start, current} ->
            Position
                ((model.gridSize * col) + (current.x - start.x))
                ((model.gridSize * row) + (current.y - start.y))
        Nothing ->
            Position
                ((model.gridSize * col))
                ((model.gridSize * row))


makeMouseDown: (Int, Int) -> Attribute Msg
makeMouseDown key =
  let
    stupid = \p -> DragStart p key
  in
    on "mousedown" (Decode.map stupid Mouse.position)


drawPusher : Float -> String -> Bool -> Html.Html msg
drawPusher size color isAnchored =
    let
        (posx, posy, totsize) = (0.0, 0.0, 1.0)
        anchor = case isAnchored of
            True ->
                circle
                    [ fill "#ff0000"
                    , cx (toString (posx + (totsize/2.0)))
                    , cy (toString (posy + (totsize/2.0)))
                    , r (toString (totsize/4.0))
                    ]
                    []
            _ ->
                circle
                    [ fill color
                    , cx (toString (posx + (totsize/2.0)))
                    , cy (toString (posy + (totsize/2.0)))
                    , r (toString (totsize/4.0))
                    ]
                    []
    in
        svg
        [
            version "1.1",
            x (toString 0),
            y (toString 0),
            width (toString size),
            height (toString size),
            viewBox
                    ("0 0 " ++
                    toString (totsize) ++
                    " " ++
                    toString (totsize))
        ]
        [ rect
            [ fill "#333333"
            , x (toString (posx+totsize * 0.02))
            , y (toString (posy+totsize * 0.02))
            , width (toString (totsize * 0.96))
            , height (toString (totsize * 0.96))
            ]
            []
        , rect
            [ fill color
            , x (toString (posx+totsize * 0.1))
            , y (toString (posy+totsize * 0.1))
            , width (toString (totsize * 0.8))
            , height (toString (totsize * 0.8))
            ]
            []
        , anchor
        ]

drawMover : Float -> String -> Html.Html msg
drawMover size color =
    let
        (posx, posy, totsize) = (0.0, 0.0, 1.0)
    in
        svg
        [
                version "1.1",
                x (toString 0),
                y (toString 0),
                width (toString size),
                height (toString size),
                viewBox
                        ("0 0 " ++
                        toString (totsize) ++
                        " " ++
                        toString (totsize))
        ]
        [ circle
            [ fill "#333333"
            , cx (toString (posx + (totsize/2.0)))
            , cy (toString (posy + (totsize/2.0)))
            , r (toString (totsize/2.0))
            ]
            []
        , circle
            [ fill color
            , cx (toString (posx + (totsize/2.0)))
            , cy (toString (posy + (totsize/2.0)))
            , r (toString ((totsize * 0.9)/2.0))
            ]
            []
        ]


drawAbyss : Float -> Html.Html msg
drawAbyss size =
    let
        (posx, posy, totsize) = (0.0, 0.0, 1.0)
    in
        svg
        [
            version "1.1",
            x (toString 0),
            y (toString 0),
            width (toString size),
            height (toString size),
            viewBox
                    ("0 0 " ++
                    toString (totsize) ++
                    " " ++
                    toString (totsize))
        ]
        [ rect
            [ fill "#0000ff"
            , x (toString (posx))
            , y (toString (posy))
            , width (toString (totsize))
            , height (toString (totsize))
            ]
            []
        ]

boardColor =
    "#8B4513"

drawEmpty : Float -> Html.Html msg
drawEmpty size =
    let
        (posx, posy, totsize) = (0.0, 0.0, 1.0)
    in
        svg
        [
            version "1.1",
            x (toString 0),
            y (toString 0),
            width (toString size),
            height (toString size),
            viewBox
                    ("0 0 " ++
                    toString (totsize) ++
                    " " ++
                    toString (totsize))
        ]
        [ rect
            [ fill boardColor
            , x (toString (posx))
            , y (toString (posy))
            , width (toString (totsize))
            , height (toString (totsize))
            ]
            []
        ]