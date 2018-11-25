#!/usr/bin/env bash

set -e
# elm make src/Board.elm --output=elm.js
elm make src/Main.elm --output=elm.js
open index.html
