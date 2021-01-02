port module Main exposing (..)

import Browser
--import Debug
import Json.Decode as D
import Json.Encode as E
import Html exposing (Html, button, div, text, input)
import Html.Attributes exposing (placeholder, value, type_, style)
import Html.Events exposing (onClick, onInput)
import Validate exposing (isValidEmail)
import Pushfight exposing (backgroundColor,buttonColor,black,white)

import PFTypes exposing (Orientation(..), Msg(..), OutMsg(..), GameStage(..))
import PushfightCoding exposing (encodePushfight, decodePushfight, pushfightDecoderImpl)

import Element exposing (Element, el, text, row, alignRight, fill, width, rgb255, spacing, centerY, centerX, padding, column, alignBottom)
import Element.Background as Background
import Element.Border as Border
import Element.Input as Input
import Element.Font as Font


port requestNewGame : String -> Cmd msg
port receiveNewGame : (String -> msg) -> Sub msg

port requestJoinGame : String -> Cmd msg

port receiveConnectionLost : (String -> msg) -> Sub msg

port sendPushfight : E.Value -> Cmd msg
port receivePushfight : (D.Value -> msg) -> Sub msg

port notifyExit : () -> Cmd msg

port sendNotificationEmail: String -> Cmd msg
port registerEmail : E.Value -> Cmd msg

type alias Flags =
    { windowWidth : Int
    , windowHeight : Int
    , email: String
    }

type alias Game =
    { gameID: String
    , pushfight: Pushfight.Model
    }

type alias EmailNotification =
    { email: String
    , notifyOnWhiteTurn: Bool
    , notifyOnBlackTurn: Bool
    }

type Msg
    = TryNewGame  
    | TryJoinGame
    | ConnectionLost String
    | StartNewGame String
    | UpdateGameID String
    --| UpdateNewGameID String
    --| UpdateJoinGameID String
    | PushfightFromServer Game
    | ExitGame
    | PushfightMsg PFTypes.Msg
    | NoOp
    --| RegisterEmail
    --| UpdateNotificationEmail String
    | ToggleNotifyOnWhiteTurn Bool
    | ToggleNotifyOnBlackTurn Bool
    --| ToggleNotify Bool

type alias Model =
    { game: Maybe Game
    , gameID: String
    --, joinGameID: String
    , windowDims: (Int,Int)
    , email: EmailNotification
    }

--checkbox : msg -> String -> Html msg
--checkbox msg name =
--    Html.label
--        []
--        [ input [ type_ "checkbox", onClick msg ] []
--        , text name
--        ]
--backgroundColor =
--    Element.rgb255 255 244 181
--buttonColor =
--    Element.rgb255 164 36 69
--black =
--    Element.rgb255 25 24 10
--white = 
--    Element.rgb255 255 250 255

bigButton: Msg -> String -> Element Msg
bigButton msg txt =
    Input.button
    [ Font.color white
    , centerX
    , Border.color white
    , Border.solid
    --, Border.width 10
    , Border.rounded 15
    , padding 20
    --, width "fill"
    , Background.color buttonColor
    ]
    { onPress = Just msg
    , label = Element.text txt
    }

smallButton: Msg -> String -> Element Msg
smallButton msg txt =
    Input.button
    [ Font.color white
    , centerX
    , Border.color white
    , Border.solid
    --, Border.width 10
    , Border.rounded 15
    , padding 15
    --, width "fill"
    , Background.color buttonColor
    ]
    { onPress = Just msg
    , label = Element.text txt
    }
leaveGameButton: Msg -> String -> Element Msg
leaveGameButton msg txt =
    Input.button
    [ Font.color white
    , centerX
    , Border.color white
    , Border.solid
    --, Border.width 10
    , Border.rounded 15
    , padding 15
    --, width "fill"
    , Background.color black
    --, alignBottom
    ]
    { onPress = Just msg
    , label = Element.text txt
    }
view : Model -> Html Msg
view model =
    let
        (windowWidth, windowHeight) =
            model.windowDims
    in
        case model.game of
            Just game ->
                Element.layout [Background.color backgroundColor] <|
                    Element.el [Font.size (windowHeight//40), centerX]
                    (
                        column [spacing 5]
                        [ Element.el [centerX] (Element.text ("Game ID = " ++ game.gameID))
                        , Pushfight.view game.pushfight |> Html.map PushfightMsg |> Element.html
                        , Element.row 
                            [ centerX
                            , spacing 15
                            ]
                            [ Element.column [spacing 10]
                                [ Element.row  [spacing 20]
                                    [ Input.checkbox []
                                    { onChange = \v -> ToggleNotifyOnWhiteTurn v
                                    , icon = myCheckbox (windowHeight//50)
                                    , checked = model.email.notifyOnWhiteTurn
                                    , label =
                                        Input.labelRight []
                                            (Element.text "Notify For White")
                                    }
                                    , Input.checkbox []
                                        { onChange = \v -> ToggleNotifyOnBlackTurn v
                                        , icon = myCheckbox (windowHeight//50)
                                        , checked = model.email.notifyOnBlackTurn
                                        , label =
                                            Input.labelRight []
                                                (Element.text "Notify For Black")
                                        }
                                    ]
                                ]
                            --, smallButton RegisterEmail "Get Notified"
                            ]
                            --, Input.text [] {onChange = UpdateNotificationEmail, text = model.email.email, label = Input.labelHidden "", placeholder=Nothing}
                        --, hline--Element.el [padding 2000] Element.none
                        , leaveGameButton ExitGame "Leave Game"
                        ]
                    )
                --div [] []
                    --[ div [] [ "Game ID = " ++ game.gameID |> text]
                    --, div [] [ Pushfight.view game.pushfight |> Html.map PushfightMsg ]
                    --, div []
                    --    [ input [ placeholder "Notification Email", value model.email.email, onInput UpdateNotificationEmail ] []
                    --    , div [] [ checkbox ToggleNotifyOnWhiteTurn "Notify On White's turn" ]
                    --    , div [] [ checkbox ToggleNotifyOnBlackTurn "Notify On Black's turn" ]
                    --    , div [] [ button [ onClick RegisterEmail ] [text "Get Notified" ] ]
                    --    ]
                    --, div [] [ button [ onClick ExitGame ] [ text "Leave Game" ] ]
                    --]
            Nothing ->
                Element.layout [Background.color backgroundColor] <|
                    Element.el [Font.size (windowHeight//30), centerX, centerY]
                    (
                        column [centerY, spacing 30]
                        [ bigButton TryNewGame "Start New Game"
                        --[ Input.button [Font.color black, centerX, Border.color black, Border.solid, Border.width 3, Background.color buttonColor] { onPress = Just TryNewGame, label = Element.text "Start New Game"}
                        , Input.text [] {onChange = UpdateGameID, text= model.gameID, label= Input.labelHidden "", placeholder=Nothing} --Just (Input.placeholder [] Element.text "Enter Game ID")}
                        --, Input.button [Font.color black, centerX, Border.color black, Border.solid, Border.width 3, Background.color buttonColor] { onPress = Just TryJoinGame, label = Element.text "Join Game"}
                        , bigButton TryJoinGame "Join Game"
                        ]
                    )
                    --(
                    --    (Element.text "Howdy!")
                    --    --row [ width fill, centerY, spacing 30 ]
                    --    --[Element.el [centerX] (Element.text "Howdy!")]
                    --)

              --div []
              --  [ div []
              --      [ input [ placeholder "New Game ID", value model.newGameID, onInput UpdateNewGameID ] []
              --      , button [ onClick TryNewGame ] [ text "Start New Game" ]
              --      ]
              --  , div []
              --      [ input [ placeholder "Join Game ID", value model.joinGameID, onInput UpdateJoinGameID ] []
              --      , button [ onClick TryJoinGame ] [ text "Join Game" ]
              --      ]
              --  ]


init : Flags -> ( Model, Cmd Msg )
init {windowWidth, windowHeight, email} =
    (
        { game = Nothing
        , gameID = ""
        --, joinGameID = ""
        , windowDims = (windowWidth, windowHeight)
        , email = EmailNotification email True True
        }
        , Cmd.none
    )

boardChange: Pushfight.Model -> Pushfight.Model -> Bool
boardChange m1 m2 =
    (m1.currentTurn /= m2.currentTurn) || (m1.gameStage /= m2.gameStage)

notificationMsgs: Model -> List (Cmd Msg)
notificationMsgs model =
    case model.game of
        Just game ->
            case (game.pushfight.gameStage, model.email.notifyOnBlackTurn, model.email.notifyOnWhiteTurn) of
                --(WhiteSetup, True, False) ->
                --    [sendNotificationEmail game.gameID]
                (WhiteTurn, True, False) ->
                    [sendNotificationEmail game.gameID]
                --(WhiteSetup, True, True) ->
                --    [sendNotificationEmail game.gameID]
                (WhiteTurn, True, True) ->
                    [sendNotificationEmail game.gameID]
                --(BlackSetup, False, True) ->
                --    [sendNotificationEmail game.gameID]
                (BlackTurn, False, True) ->
                    [sendNotificationEmail game.gameID]
                --(BlackSetup, True, True) ->
                --    [sendNotificationEmail game.gameID]
                (BlackTurn, True, True) ->
                    [sendNotificationEmail game.gameID]
                _ ->
                    []
        Nothing ->
            []

update: Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        noop = ( model, Cmd.none)
    in
        case msg of
            TryNewGame ->
                if String.length model.gameID > 0 then
                    ( model
                    , requestNewGame model.gameID
                    )
                else
                    noop
            StartNewGame gameID ->
                    let
                        (windowWidth, windowHeight) = model.windowDims
                        (pushfight, cmdMsg) = Pushfight.init windowWidth windowHeight
                        game = { gameID = gameID, pushfight = pushfight}
                    in
                        ( { model | game = Just game}
                        , Cmd.batch
                            [ Cmd.map PushfightMsg cmdMsg
                            , encodePushfight game.gameID pushfight |> sendPushfight
                            ]
                        )
            TryJoinGame ->
                if String.length model.gameID > 0 then
                    case model.game of
                        Just _ ->
                            noop
                        Nothing ->
                            ( model
                            , requestJoinGame model.gameID
                            )
                else
                    noop
            ExitGame ->
                ( { model | game = Nothing }
                , notifyExit ()
                )
            UpdateGameID gameID ->
                ( { model | gameID = gameID }
                , Cmd.none
                )
            --UpdateJoinGameID gameID ->
            --    ( { model | joinGameID = gameID }
            --    , Cmd.none
            --    )
            ConnectionLost _ ->
                ( { model | game = Nothing}
                , Cmd.none
                )
            PushfightMsg pfmsg ->
                case model.game of
                    Just game ->
                        let
                            (updatedPushfight, cmdMsg, outMsg) = Pushfight.update pfmsg game.pushfight
                            sndUpdateCmdMsg =
                                if boardChange updatedPushfight game.pushfight then --pushfight /= game.pushfight then
                                    [encodePushfight game.gameID updatedPushfight |> sendPushfight]
                                else
                                    []
                            newMsgs =
                                case outMsg of
                                    PFNoOp ->
                                        []
                                    PFTurnEnded ->
                                        notificationMsgs model

                        in

                            ( { model | game = Just { pushfight = updatedPushfight, gameID = game.gameID } }
                            ,  [Cmd.map PushfightMsg cmdMsg] ++ sndUpdateCmdMsg ++ newMsgs |> Cmd.batch
                            )
                    Nothing ->
                        noop
            PushfightFromServer game ->
                case model.game of
                    Just _ ->
                        ( { model | game = Just game}
                        --, Pushfight.grabWindowDims () |> Cmd.map PushfightMsg
                        , Cmd.none
                        )
                    Nothing ->
                        ( { model | game = Just game}
                        --, Pushfight.grabWindowDims () |> Cmd.map PushfightMsg
                        , Cmd.none
                        )
                --case decodePushfight codedPushfight of
                --    Ok (gameID, pushfight) ->
                --        ( { model | game = Just {gameID = gameID, pushfight = pushfight} }
                --        , Pushfight.grabWindowWidth ()
                --        )
                --    Err err ->
                --        Debug.log err noop
            --RegisterEmail ->
            --    if isValidEmail model.email.email && ( model.email.notifyOnBlackTurn || model.email.notifyOnWhiteTurn ) then
            --        case model.game of
            --            Just game ->
            --                let
            --                    registerMsg =
            --                        encodeEmail game.gameID model.email |> registerEmail
            --                in
            --                    ( { model | email = EmailNotification "" False False }
            --                    , registerMsg
            --                    )
            --            Nothing ->
            --                noop
            --    else
            --        noop
            ToggleNotifyOnBlackTurn v ->
                --let
                    --newEmail = {model.email | notifyOnBlackTurn = !model.email.notifyOnBlackTurn}
                --in
                ( { model | email = EmailNotification model.email.email model.email.notifyOnWhiteTurn v }
                , Cmd.none
                )
            ToggleNotifyOnWhiteTurn v ->
                --let
                    --newEmail = {model.email | notifyOnWhiteTurn = !model.email.notifyOnWhiteTurn}
                --in
                ( { model | email = EmailNotification model.email.email v model.email.notifyOnBlackTurn }
                , Cmd.none
                )
            --UpdateNotificationEmail s ->
            --    let
            --        newEmail =
            --            EmailNotification s model.email.notifyOnWhiteTurn model.email.notifyOnBlackTurn
            --    in
            --        ( { model | email = newEmail }
            --        , Cmd.none
            --        )
            NoOp ->
                noop
--windowWidth
--gridSize
--endTurnOnPush
mapPushFightDecode: PFTypes.Orientation -> (Int,Int) -> Int -> Bool -> D.Value -> Msg
mapPushFightDecode orientation windowDims gridSize endTurnOnPush json = 
--decodePushfight windowDims gridSize endTurnOnPush decodedBoard  =
    --decodedBoard
    case D.decodeValue pushfightDecoderImpl json of
        Ok pushfight ->
            PushfightFromServer
            { pushfight = (decodePushfight orientation windowDims gridSize endTurnOnPush pushfight)
            , gameID = pushfight.gameID
            }
        Err e ->
            NoOp
            --Debug.log "Failed to parse board" NoOp

mapNewGameDecode: D.Value -> Msg
mapNewGameDecode json =
    case D.decodeValue D.string json of
        Ok gameID ->
            StartNewGame gameID
        Err e ->
            NoOp
            --Debug.log "Failed to parse new game ID" NoOp

subscriptions : Model -> Sub Msg
subscriptions model =
    let
        (msgs, (orientation, windowDims, gridSize), endTurnOnPush) =
            case model.game of
                Just game ->
                    ( Pushfight.subscriptions game.pushfight |> Sub.map PushfightMsg
                    , ( game.pushfight.orientation, game.pushfight.windowDims , game.pushfight.gridSize )
                    , game.pushfight.endTurnOnPush
                    )
                Nothing ->
                    let
                        (windowWidth, windowHeight) = model.windowDims
                        (pushfight, _) = Pushfight.init windowWidth windowHeight
                    in
                        ( Sub.batch []
                        , ( pushfight.orientation, (windowWidth, windowHeight) , pushfight.gridSize )
                        , pushfight.endTurnOnPush
                        )
    in
        Sub.batch
        [ msgs
        , receivePushfight (mapPushFightDecode orientation windowDims gridSize endTurnOnPush)
        , receiveNewGame StartNewGame
        , receiveConnectionLost ConnectionLost
        ]
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }

encodeEmail: String -> EmailNotification -> E.Value
encodeEmail gameID e =
    E.object
        [ ("gameID", E.string gameID)
        , ("email", E.string e.email)
        , ("notifyOnBlackTurn", E.bool e.notifyOnBlackTurn)
        , ("notifyOnWhiteTurn", E.bool e.notifyOnBlackTurn)
        ]

myCheckbox : Int -> Bool -> Element msg
myCheckbox size checked =
    Element.el
        [Element.width
            (Element.px size)
        , Element.height (Element.px size)
        , Font.color white
        , Element.centerY
        , Font.size 9
        , Font.center
        , Border.rounded 3
        , Border.color <|
            if checked then
                buttonColor
                --Element.rgb (252 / 255) (153 / 255) (59 / 255)

            else
                black
                --Element.rgb (211 / 255) (211 / 255) (211 / 255)
        , Border.shadow
            { offset = ( 0, 0 )
            , blur = 1
            , size = 1
            , color =
                if checked then
                    Element.rgba (238 / 255) (238 / 255) (238 / 255) 0

                else
                    Element.rgb (238 / 255) (238 / 255) (238 / 255)
            }
        , Background.color <|
            if checked then
                --Element.rgb (252 / 255) (153 / 255) (59 / 255)
                buttonColor
            else
                white
        , Border.width <|
            if checked then
                0

            else
                1
        , Element.inFront
            (Element.el
                [ Border.color white
                , Element.height (Element.px 6)
                , Element.width (Element.px 9)
                , Element.rotate (degrees -45)
                , Element.centerX
                , Element.centerY
                , Element.moveUp 1
                , Element.transparent (not checked)
                , Border.widthEach
                    { top = 0
                    , left = 2
                    , bottom = 2
                    , right = 0
                    }
                ]
                Element.none
            )
        ]
        Element.none

hline : Element Msg
hline =
    Element.el [Element.width fill, Element.height (Element.px 5), Background.color black] Element.none
