import Browser

import Html


import Url
import Url.Parser as Parser exposing (Parser, (</>), custom, fragment, map, oneOf, s, top)

import Board
import Lobby


-- MAIN


main =
  Browser.application
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    , onUrlRequest = LinkClicked
    , onUrlChange = UrlChanged
    }


-- MODEL


type alias Model =
  { key : Nav.Key
  , page : Page
  }

type Page
  = NotFound
  | Board Board.Model
  | Lobby Lobby.Model


-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none



-- VIEW


view : Model -> Browser.Document Msg
view model =
  case model.page of
    Lobby lobby ->
      Browser.Document "Lobby" [ Lobby.view lobby ]

    Board board ->
      Browser.Document "Board" [ Board.view board ]

-- INIT


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
  let
    (lobby, _) = Lobby.init 
  stepUrl url
    { key = key
    , page = lobby
    }



-- UPDATE


type Msg
  = NoOp
  | LinkClicked Browser.UrlRequest
  | UrlChanged Url.Url
  | BoardMsg Board.Msg
  | LobbyMsg Lobby.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
  case message of
    NoOp ->
      ( model, Cmd.none )

    LinkClicked urlRequest ->
      case urlRequest of
        Browser.Internal url ->
          ( model
          , Nav.pushUrl model.key (Url.toString url)
          )

        Browser.External href ->
          ( model
          , Nav.load href
          )

    UrlChanged url ->
      stepUrl url model

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


-- ROUTER

type Route
  = GameID String
  | UserID String

stepUrl : Url.Url -> Model -> (Model, Cmd Msg)
stepUrl url model =
  let 
    parser =
      oneOf
        [ map GameID (s "game" </> string)
        ]
  in
    case Parser.parse parser url of
      Just GameID gameID ->
        stepBoard model (Board.init gameID)

      Nothing ->
        stepLobby model (Lobby.init () )
