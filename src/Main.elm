import Browser
import Browser.Navigation as Nav

import Html
import Html.Attributes as Attributes

import List

import Board
import Lobby


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
  { page : Page
  }

type Page
  = Board Board.Model
  | Lobby Lobby.Model


-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none



-- VIEW


view : Model -> Html.Html Msg
view model =
    case model.page of
      Lobby lobby ->
        Html.map LobbyMsg (Lobby.view lobby)

      Board board ->
         Html.map BoardMsg (Board.view board)

-- INIT


init : () -> ( Model, Cmd Msg )
init _ =
  let
    (lobby, _) = Lobby.init ()
  in
    (Model (Lobby lobby)
    , Cmd.none
    )



-- UPDATE


type Msg
  = GoToLobby
  | GoToBoard String
  | BoardMsg Board.Msg
  | LobbyMsg Lobby.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
  case message of
    GoToLobby ->
      stepLobby model (Lobby.init ())
    GoToBoard gameID ->
      stepBoard model (Board.init gameID)
    BoardMsg msg ->
      case model.page of
        Board board -> stepBoard model (Board.update msg board)
        _         -> ( model, Cmd.none )

    LobbyMsg msg ->
      case model.page of
        Lobby lobby -> stepLobby model (Lobby.update msg lobby)
        _         -> ( model, Cmd.none )

stepBoard : Model -> ( Board.Model, Cmd Board.Msg ) -> ( Model, Cmd Msg )
stepBoard model (board, cmds) =
  ( { model | page = Board board }
  , Cmd.map BoardMsg cmds
  )


stepLobby : Model -> ( Lobby.Model, Cmd Lobby.Msg ) -> ( Model, Cmd Msg )
stepLobby model (lobby, cmds) =
  ( { model | page = Lobby lobby }
  , Cmd.map LobbyMsg cmds
  )
