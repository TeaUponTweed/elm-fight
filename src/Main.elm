port module Main exposing (getGamesFromFirebase)

import Json.Decode as Decode
import Json.Encode as Encode

import Browser
import Browser.Navigation as Nav

import Html
import Html.Attributes as Attributes

import List

import Board
import Lobby

--port updateBoardFromFirebase : (Decode.Value -> msg) -> Sub msg
port getGamesFromFirebase : (Decode.Value -> msg) -> Sub msg

--port updateBoardToFirebase : Decode.Value -> Cmd msg

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
    (lobby, _) = Lobby.init ()
  in
    ( Model Nothing lobby InLobby
    , Cmd.none
    )



-- UPDATE

type CurrentPage
  = InLobby
  | InGame


type Msg
  = GoToLobby
  | GoToBoard String
  | BoardMsg Board.Msg
  | LobbyMsg Lobby.Msg
  | DecodeActiveGamesList Decode.Value
  --| ActiveGames (List String)

update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
  case message of
    GoToLobby ->
      stepLobby model (Lobby.init ())
    GoToBoard gameID ->
      stepBoard model (Board.init gameID)
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


stepBoard : Model -> ( Board.Model, Cmd Board.Msg ) -> ( Model, Cmd Msg )
stepBoard model (b, cmds) =
  ( { model | board = Just b }
  , Cmd.map BoardMsg cmds
  )


stepLobby : Model -> ( Lobby.Model, Cmd Lobby.Msg ) -> ( Model, Cmd Msg )
stepLobby model (l, cmds) =
  ( { model | lobby =  l }
  , Cmd.map LobbyMsg cmds
  )

decodeActiveGamesList : Decode.Decoder (List String)
decodeActiveGamesList = 
    Decode.list Decode.string

firebaseSubscriptions : Model -> Sub Msg
firebaseSubscriptions model =
  Sub.batch
    [ getGamesFromFirebase DecodeActiveGamesList
    --, Firebase.updateBoardFromFirebase GetBoard
    --, Firebase.didUploadBoard DidUploadBoard
    ]

--decodeBoard : Decode.Decoder (Dict String Bool)
--decodeBoard = 
--    Decode.dict Decode.bool


--encodeBoardImpl : (String, Bool) -> (String, Encode.Value)
--encodeBoardImpl (key, val) = 
--    (key, Encode.bool val)

--encodeBoard : Board -> Encode.Value
--encodeBoard board = 
--    Encode.object(List.map encodeBoardImpl (Dict.toList board))
