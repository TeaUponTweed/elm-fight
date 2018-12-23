port module Main exposing (updateBoardFromFirebase, getGamesFromFirebase, updateBoardToFirebase, createNewGame)

import Json.Decode as Decode
import Json.Encode as Encode
import Json.Decode.Pipeline as Pipeline

import Browser
import Browser.Navigation as Nav

import Html
import Html.Attributes as Attributes

import Debug

import List
import Dict

import Router
import Pushfight
import Lobby

port updateBoardFromFirebase : (Decode.Value -> msg) -> Sub msg
-- TODO only do this on request
port getGamesFromFirebase : (Decode.Value -> msg) -> Sub msg

port requestBoardFromFirebase : Decode.Value -> Cmd msg
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
    { lobby : Lobby.Model
    , board : Maybe Board.Model
    }


-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    firebaseSubscriptions model



-- VIEW


view : Model -> Html.Html Msg
view model =
    case model.board of
        Just Board board ->
            Html.div []
            [ Html.div [] [Html.button [ Html.Events.onClick RouterMsg Router.GoToLobby ] [ Html.text "Back to Lobby" ]]
            , Html.div [] [Html.map BoardMsg (Board.view board)]
            ]
        Nothing ->
            Html.map LobbyMsg (Lobby.view model.lobby)


-- INIT


init : () -> ( Model, Cmd Msg )
init _ =
    let
        (lobby, _, _) = Lobby.init ()
    in
        ( Model Lobby lobby
        , Cmd.none
        )



-- UPDATE



type Msg
    = RouterMsg Router.Msg
    | BoardMsg Pushfight.Msg
    | LobbyMsg Lobby.Msg
    | DecodeActiveGamesList Decode.Value
    | DecodeBoard Decode.Value

update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        RouterMsg msg ->
            case msg of
                Router.GoToLobby ->
                    ( {model | page =  }
                    , Cmd.none
                    )
                Router.GoToGame gameID ->
                    ( model
                    , requestBoardFromFirebase (Encode.string gameID)
                    )
                Router.CreateNewGame ->
                    ( model
                    , createNewGame Encode.null
                    )
                DoNothing ->
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
        -- TODO let board handle it's own updating, don't reach in
        DecodeBoard codedBoard ->
            case Decode.decodeValue decodeBoard (Debug.log ("coded board: " ++ (Debug.toString codedBoard)) codedBoard) of
                Ok {board, gameID} ->
                    case model.board of
                        Just game ->
                            let
                                updatedGame =
                                    {game | board = board, gameID = gameID}
                            in
                                ( { model | board = Just updatedGame }
                                , Cmd.none
                                )

                        Nothing ->
                            let
                                (newGame, cmds, _) =
                                    Board.init gameID board
                            in
                                ( { model | board = Just newGame }
                                , Cmd.map BoardMsg cmds
                                )

                Err err ->
                    ( Debug.log ("failed to decode board: " ++ Debug.toString err)  model
                    , Cmd.none
                    )


-- TODO there is a scary logic hole if a router msg is returned, then encodeBoard -> firebase won't happen.
stepBoard : Model -> ( Board.Model, Cmd Board.Msg, Maybe Router.Msg ) -> ( Model, Cmd Msg )
stepBoard model ( b, cmds, routerMsg ) =
    let
        updatedModel =
            { model | board = Just b }
        boardUpdateCmd =
            updateBoardToFirebase (encodeGame b)
    in
    case routerMsg of
        Just rMsg ->
            let
                ( moreUpdatedModel, moreCmds ) =
                    update (RouterMsg (Just rMsg)) updatedModel
            in
                ( moreUpdatedModel
                , Cmd.batch [boardUpdateCmd, moreCmds]
                )
    
        Nothing ->
            ( updatedModel
            , boardUpdateCmd
            )


stepLobby : Model -> ( Lobby.Model, Cmd Lobby.Msg, Maybe Router.Msg ) -> ( Model, Cmd Msg )
stepLobby model (l, cmds, routerMsg) =
    let
        updatedModel = { lobby =  l, board = Nothing }
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
        ]


type alias DecodedBoard =
    { wp1 : Int
    , wp2 : Int
    , wp3 : Int
    , wm1 : Int
    , wm2 : Int
    , bp1 : Int
    , bp2 : Int
    , bp3 : Int
    , bm1 : Int
    , bm2 : Int
    , anc : Int
    , gameID : String
    }


decodeBoard : Decode.Decoder DecodedBoard
decodeBoard = 
    Decode.succeed ProperBoard
        |> Pipeline.required "wp1" Decode.int
        |> Pipeline.required "wp2" Decode.int
        |> Pipeline.required "wp3" Decode.int
        |> Pipeline.required "wm1" Decode.int
        |> Pipeline.required "wm2" Decode.int
        |> Pipeline.required "bp1" Decode.int
        |> Pipeline.required "bp2" Decode.int
        |> Pipeline.required "bp3" Decode.int
        |> Pipeline.required "bm1" Decode.int
        |> Pipeline.required "bm2" Decode.int
        |> Pipeline.required "anc" Decode.int
        |> Pipeline.required "gameID" Decode.string

encodeBoardImpl : List ((Int, Int), (Pushfight.Piece)) -> Dict String Int -> Int -> Int -> Int -> Int -> Dict String Int
encodeBoardImpl pieces transformedBoard blackMoverCounter whiteMoverCounter whitePusherCounter blackPusherCounter =
    case pieces of
        [((x, y), {piece, kind}] :: otherPieces ->
            let
                (name, updatedblackMoverCounter, updatedwhiteMoverCounter, updatedwhitePusherCounter, updatedblackPusherCounter) =
                    case (piece, kind) of
                        (Black, Pusher) ->
                            ( "bp" ++ <| String.fromInt <| blackPusherCounter + 1
                            , blackMoverCounter, whiteMoverCounter, whitePusherCounter, blackPusherCounter + 1
                            )
                        (White, Pusher) ->
                            ( "wp" ++ <| String.fromInt <| whitePusherCounter + 1
                            , blackMoverCounter, whiteMoverCounter, whitePusherCounter + 1, blackPusherCounter
                            )
                        (Black, Mover) ->
                            ( "bm" ++ <| String.fromInt <| blackMoverCounter + 1
                            , blackMoverCounter + 1, whiteMoverCounter, whitePusherCounter, blackPusherCounter
                            )
                        (White, Mover) ->
                            ( "wm" ++ <| String.fromInt <| whiteMoverCounter + 1
                            , blackMoverCounter, whiteMoverCounter + 1, whitePusherCounter, blackPusherCounter
                            )
                pos =
                    x+y*10
            in
                encodeBoardImpl otherPieces <| Dict.insert name pos
                    <| blackMoverCounter
                    <| updatedblackMoverCounter updatedwhiteMoverCounter updatedwhitePusherCounter updatedblackPusherCounter

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
