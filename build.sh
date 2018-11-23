#!/usr/bin/env bash

set -e
# elm make src/Board.elm --output=elm.js
elm make src/Main.elm --output=elm.js
# open page.html
firebase serve &
sleep 3
open http://localhost:5000

