port module Firebase exposing (..)

import Json.Decode exposing (Value)

port updateBoardToFirebase : Value -> Cmd msg
port didUploadBoard : (Bool -> msg) -> Sub msg

port updateBoardFromFirebase : (Value -> msg) -> Sub msg
