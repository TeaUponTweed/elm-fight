port module Main exposing (updateBoardFromFirebase, getGamesFromFirebase, getNewGameID, updateBoardToFirebase, createNewGame)

import Json.Decode as Decode
import Json.Encode as Encode

import Browser
import Browser.Navigation as Nav

import Html
import Html.Attributes as Attributes

import List
import Dict

import Router
import Board
import Lobby

port updateBoardFromFirebase : (Decode.Value -> msg) -> Sub msg
port getGamesFromFirebase : (Decode.Value -> msg) -> Sub msg
port getNewGameID : (Decode.Value -> msg) -> Sub msg

port updateBoardToFirebase : Decode.Value -> Cmd msg
port createNewGame : Decode.Value -> Cmd msg

-- MAIN


main : Program () Model Msg
main =
    Browser.document
        { init = init
        , view = \model -> { title = "Elm • TodoMVC", body = [view model] }
        , update = update
        , subscriptions = subscriptions
        }


-- MODEL


type alias Model =
    { board : Maybe Board.Model
    , lobby : Lobby.Model
    , page : CurrentPage
    }


-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    firebaseSubscriptions model



-- VIEW


view : Model -> Html.Html Msg
view model =
    case model.page of
        InLobby ->
            Html.map LobbyMsg (Lobby.view model.lobby)

        InGame ->
            case model.board of
                Just board ->
                    Html.map BoardMsg (Board.view board)
                Nothing ->
                    Html.div [] [ Html.text "Board not instantiated" ]

-- INIT


init : () -> ( Model, Cmd Msg )
init _ =
    let
        (lobby, _, _) = Lobby.init ()
    in
        ( Model Nothing lobby InLobby
        , Cmd.none
        )



-- UPDATE

type CurrentPage
    = InLobby
    | InGame


type Msg
    = RouterMsg (Maybe Router.Msg)
    | BoardMsg Board.Msg
    | LobbyMsg Lobby.Msg
    | DecodeActiveGamesList Decode.Value
    | DecodeBoard Decode.Value
    | DecodeGameID Decode.Value
    --| ActiveGames (List String)

update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        RouterMsg msg ->
            case msg of
                Just Router.GoToLobby ->
                    stepLobby { model | page = InLobby } (Lobby.init ())
                Just (Router.GoToGame gameID) ->
                    stepBoard { model | page = InGame } (Board.init gameID)
                Just Router.CreateNewGame ->
                    stepBoard { model | page = InGame } (Board.init "Pending")
                Nothing ->
                    ( model
                    , Cmd.none
                    )

        BoardMsg msg ->
            case model.board of
                Just board ->
                    stepBoard model (Board.update msg board)
                Nothing ->
                    ( model, Cmd.none )

        LobbyMsg msg ->
            stepLobby model (Lobby.update msg model.lobby)

        DecodeActiveGamesList gamesList ->
            case Decode.decodeValue decodeActiveGamesList gamesList of
                Ok decodedGamesList ->
                    let
                        lobby =
                            model.lobby
                        newLobby =
                            {lobby | currentGames = decodedGamesList}
                    in
                    ( { model | lobby = newLobby }
                    , Cmd.none
                    )
                Err err ->
                    ( model
                    , Cmd.none
                    )

        DecodeBoard codedBoard ->
            case Decode.decodeValue decodeBoard codedBoard of
                Ok {board, gameID} ->
                    let
                        boardState =
                            model.board
                    in
                        case boardState of
                            Just game ->
                                let
                                    updatedGame =
                                        {game | board = board, gameID = gameID}
                                in
                                    ( { model | board = Just updatedGame }
                                    , Cmd.none
                                    )
                            Nothing ->
                                ( model
                                , Cmd.none
                                )

                Err err ->
                    ( model
                    , Cmd.none
                    )

        DecodeGameID gameID ->
            case Decode.decodeValue Decode.string gameID of
                Ok gid ->
                    let
                        boardState =
                            model.board
                    in
                        case boardState of
                            Just board ->
                                let
                                    newBoard =
                                        {board | gameID = gid}
                                in
                                    ( { model | board = Just newBoard }
                                    , Cmd.none
                                    )

                            Nothing ->
                                ( model
                                , Cmd.none
                                )

                Err err ->
                    ( model
                    , Cmd.none
                    )


-- TODO there is a scary logic hole if a router msg is returned, then encodeBoard -> firebase won't happen.
stepBoard : Model -> ( Board.Model, Cmd Board.Msg, Maybe Router.Msg ) -> ( Model, Cmd Msg )
stepBoard model ( b, cmds, routerMsg ) =
    let
        updatedModel = { model | board = Just b }
    in
    case routerMsg of
        Just rMsg ->
            update (RouterMsg (Just rMsg)) updatedModel
        Nothing ->
            ( updatedModel
            , updateBoardToFirebase (encodeGame b)
            )


stepLobby : Model -> ( Lobby.Model, Cmd Lobby.Msg, Maybe Router.Msg ) -> ( Model, Cmd Msg )
stepLobby model (l, cmds, routerMsg) =
    let
        updatedModel = { model | lobby =  l }
    in
        case routerMsg of
            Just rMsg ->
                update (RouterMsg (Just rMsg)) updatedModel
            Nothing ->
                ( updatedModel
                , (Cmd.map LobbyMsg cmds)
                )


decodeActiveGamesList : Decode.Decoder (List String)
decodeActiveGamesList = 
    Decode.list Decode.string


firebaseSubscriptions : Model -> Sub Msg
firebaseSubscriptions model =
    Sub.batch
        [ getGamesFromFirebase DecodeActiveGamesList
        , updateBoardFromFirebase DecodeBoard
        , getNewGameID DecodeGameID
        ]

type alias DecodedBoard =
    { board : Dict.Dict String Bool
    , gameID : String
    }

decodeBoard : Decode.Decoder DecodedBoard
decodeBoard = 
    Decode.map2 DecodedBoard (Decode.dict Decode.bool) (Decode.string)


encodeBoardImpl : (String, Bool) -> (String, Encode.Value)
encodeBoardImpl (key, val) = 
    (key, Encode.bool val)


encodeBoard : Board.Model -> Encode.Value
encodeBoard game =
    game.board
        |> Dict.toList
        |> List.map encodeBoardImpl
        |> Encode.object

encodeGame : Board.Model -> Encode.Value
encodeGame game =
    Encode.object
        [ ( "board", encodeBoard game )
        , ( "gameID", Encode.string game.gameID)
        ]
