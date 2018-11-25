port module Firebase exposing (updateBoardToFirebase, didUploadBoard, updateBoardFromFirebase, getGamesFromFirebase)

import Json.Decode as D

port updateBoardFromFirebase : (D.Value -> msg) -> Sub msg
port didUploadBoard : (Bool -> msg) -> Sub msg
port getGamesFromFirebase : (D.Value -> msg) -> Sub msg

port updateBoardToFirebase : D.Value -> Cmd msg
